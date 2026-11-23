# VFX

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Dispatch architecture, the VFX Forge rig contract, placing/aiming rigs, and presentation tricks (impact frame,
velocity trails, shared-clock visuals). Sound dispatch is at the end because it follows the same rules.

## Architecture

- **`VFXService`** (Server/Client halves) owns replication and the Forge runtime's `init()`.
  - `VFXService.Client.ForgeEmit(Inst)`: emit locally, replicate nothing.
  - `VFXService.Server.ReplicateForgeEmit(Inst, IgnoredPlayers?)`: sends the **instance reference** to every Client
    (minus ignored), each emits locally. The instance must be one Clients can resolve.
  - Sequence replication (`RepliacteSequencetoClients` / `RepliacteSequence` [sic]): name a sequence + args; each
    Client runs it.
- **`VFXSequences`**: a registry of named sequence modules (`<Id>AbilityVFX`, `PillowHitVFX`, ...). A sequence clones,
  places and emits rigs from args.
  - **A sequence module must never require `VFXService`**: `VFXService.Client` requires `VFXSequences`, so that's a
    cycle. Sequences require the Forge runtime (`EmitModule`), `VFXUtils` and Promise directly.
- **StreamingEnabled:** an instance reference to something a Client hasn't streamed in (a far character) arrives as
  **nil**. Every Client listener must return on nil.
- `VFXUtils`: `EmitDescendants` (honours `EmitCount` attributes), `SetDescendantEmittersEnabled`, `Weld`,
  `SmoothDestroy` (disable emitters, destroy after the visual tail; the tail is not gameplay duration).
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.VFXService`,
  `ReplicatedStorage.Data.DataLibrarys.VFXSequences`, `ReplicatedStorage.System.Libs.EmitModule`,
  `ReplicatedStorage.System.Utils.VFXUtils`.

## Who plays what (dispatch patterns)

| Pattern | When | Example |
|---|---|---|
| **Server-driven to everyone** (attacker included) | Feedback for something only the Server can confirm | Hit spark + hit sound only on validated hits, so refused hits show nothing |
| **Local-first + relay to others** | Caster-initiated cosmetics where latency matters | Ability cast VFX; check exclusion so the caster doesn't get it twice |
| **Every Client simulates from a broadcast** | Moving things (projectiles, pulls, drags) | Each Client flies its own spear / lerps the pulled root; Server resolves on its own clock |
| **Seeded per-Client randomness** | Random layouts that must match | Server sends a seed; each Client rolls identical rod placements |
| **Client-only, never replicated** | Indicators for one viewer, or derived from replicated attributes | Landing discs from Server-stamped `ImpactY`; caster-only target marker |
| **Attribute-driven** | Persistent state visuals | Indicator follows an `Invisible` attribute; i-frame flicker follows a CollectionService tag |

Level-up pattern (Server, everyone sees it): clone the rig onto the anchor part, **wait ~0.1s for it to replicate**,
then `ReplicateForgeEmit(Rig)`; destroy after `max(EmitDelay + EmitDuration + Lifetime.Max) + 1s`.

## VFX Forge rig contract

Most rigs are authored in **VFX Forge** (zilibobi, VFX-DL v1.0); runtime = `EmitModule` (`api.init/emit/deinit`).
A rig is **data, not code**: behaviour comes from Attributes on its instances, which is what lets a config number
become a VFX timing.

`api.emit(...)` walks the descendants of what you pass and dispatches by class/tag:

| Instance | Runs |
|---|---|
| `ParticleEmitter` | particle (attributes below) |
| `RayValue` tagged `CameraShake` | camera shake |
| `RayValue` untagged | tweens the **parent's property named after the RayValue** |
| `Beam` | beam |
| `Trail` | sets `Enabled = true` |
| `Model` with `Start` + `End` BaseParts | mesh effect |
| any other `Model` | **spin** (does NOT recurse) |
| tagged `BezierParticle` | bezier |
| `Part` under an Attachment tagged `Shockwave` | ring / line / debris by parent folder name (`Rings`/`Lines`/`Debris`) |
| `BasePart` with an `Enabled` attribute | screen effect |

- **Pass the Attachment at the top of the rig, never the Model** (a Model takes the spin branch and its emitters never
  fire).
- A rig needn't be in `workspace`: Forge clones an out-of-workspace emitter's ancestry into `workspace.Terrain` and
  emits the clone, leaving the template untouched.
- `emit` returns `{Finished = Promise}`: `:await()` it to sequence off the real end instead of guessing a duration.

**Particle attributes:** `EmitDelay` (0, wait before emitting: staggers wind-up vs payoff), `EmitCount` (1),
`EmitDuration` (0; >0 also holds `Enabled` for that long = a sustained stream), `TimeScale_Start/End/Duration/Curve`.
One emitter's life ≈ `EmitDelay + EmitDuration + Lifetime.Max`. **`Enabled` is Forge's**: it force-disables the source
and drives it itself; authored rigs ship `Enabled = false`.

**CameraShake** (`RayValue` with the **tag**, not the name; untagged silently becomes a property tween): `Amplitude`
2.5, `Frequency` 0.2, `Falloff` 30 studs (measured from the rig's nearest ancestor Attachment/BasePart, so the rig must
be placed in the world), `FadeInTime/SustainTime/FadeOutTime`, `EmitDuration`, `Position/RotationInfluence`. Yields
until done.

**TweenProperty** (untagged `RayValue`): `_END_VALUE` (required; a type mismatch is skipped silently), `_START_VALUE`,
`Duration` (NumberRange rolled per emit), `EmitDelay`, `ResetOnFinish` (true), speed/easing curves.

**Reading/writing from code:**
- Forge's `getAttribute(obj, name, default)` **writes the default back** onto the instance unless `soft = true`, so an
  attribute on a rig may be Forge's default, not authored.
- Values are accepted only if `typeof(value) == typeof(default)` (a NumberRange where a number is expected is ignored).
- **To drive a rig from config: clone it, `SetAttribute` on the clone, emit the clone.** Never mutate the template
  (shared by everyone). Redpillars' rule for authored rigs: **clone, place, emit; don't rewrite their timings/scales.**

## Placing and aiming rigs

1. **Neuter clones before parenting.** Rig carriers are ordinary Parts and clone in `Anchored = false`,
   `CanCollide/CanTouch/CanQuery = true`: welded to a character, that's an invisible collidable part riding the Player.
2. **Place EVERY nested BasePart by its offset from the carrier.** A Part parented under another Part keeps its own
   world CFrame; moving the carrier left PB's particle box and line parts at the template's spot in ReplicatedStorage.
   Compute each clone's offset from the template's carrier and re-apply it (measured within 0.003 studs).
3. **Aim the emitters' `EmissionDirection`, not the Part's LookVector.** Emitters default to `Top` (+Y) and Forge rigs
   are usually authored that way; `CFrame.lookAt` points **−Z** at the target. For Top emitters:
   `CFrame.lookAt(Origin, Origin + Dir) * CFrame.Angles(-math.pi/2, 0, 0)`.
   - Don't trust a rig's authored rotation as a forward convention (PB's beam rig had incidental `0,0,-90` posing; using
     it put the beam exactly perpendicular).
   - Straight up/down breaks `lookAt`: build with `CFrame.fromMatrix`.
   - Settle it numerically: compute candidate frames' `UpVector:Dot(Dir)` against a deliberately non-axis-aligned
     direction and keep the one that returns 1.0. Pure maths, no playtest.
4. **Stretch a rig to a gameplay range** (PB `GravityLaneRig.Place(Template, LaneCFrame, Range?)`): place by the
   rig's `Begin` attachment, then scale by `Range / authoredLength`: each piece's distance down the axis, the length of
   Parts lying along it, their Attachments, and every emitter's `Speed` (with drag, reach scales with speed). Clamp the
   scale (0.5..3) because Range also arrives from other Clients through the relay.
   Reference impl (Pillow Battles): `ReplicatedStorage.System.Combat.GravityLaneRig`.
5. Keep the hitbox volume and the drawn volume aligned (rig origin vs centre offsets caused a 2-stud mismatch in PB).
   VFX don't grow with a leveled hitbox unless you stretch them.

## Presentation tricks

**Impact frame (PB finisher, Redpillars kept it simple):** white `ColorCorrectionEffect` (Brightness 3; 1 left a grey
ghost) for the freeze with both fighters as black silhouettes, then a black frame with white silhouettes for 0.08s,
then off; HUD stays on top.
- **Silhouettes are NOT Highlights:** a Highlight's fill is colour-corrected with the world (a black Highlight turned
  white under the white frame). Use clones in a full-screen `ViewportFrame` (parts stripped to white, full Ambient,
  `ImageColor3` black or white), each following its real part every frame.
- **World text that survives colour correction:** a `SurfaceGui` with `AlwaysOnTop` is drawn after the correction
  (without it, it washed out). Placed on a local Part ~400 studs from the held camera, square-on, sized by angle so it
  looks the same on every screen. Being a SurfaceGui, it sits under ScreenGuis.
- **Camera lock:** re-assert the CFrame after the camera step every frame; keep `CameraType = Custom` (a death-camera
  lock captures the type it finds; Scriptable would be stranded). The default camera reads its look direction back
  off `Camera.CFrame`, so it carries on from wherever the lock left it. Apply shakes via `Humanoid.CameraOffset`.
- Tried and removed: FOV push-in, following the victim with the camera (victim position arrives in steps: 40° jumps
  without smoothing), lingering text. Short and stark read best.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Combat.Attack.FinisherClient`.

**Velocity trails on every body** (`VelocityVFX`, Client): each Client clones a generic emitter set into every body part
of every Player/NPC/Dummy and drives it locally from Torso speed (ragdoll flights count), off while invisible or dead.
**Writing `ParticleEmitter.Rate` restarts its spawn timing**, so rewriting it on every speed wobble came out in
bursts. Fix: strength in steps with hysteresis, Rate rewritten at most every N seconds, off below Min x OffRatio.
Measured after: 12s of fast movement = 1 enable, 1 Rate write. Very relevant to a ragdoll-flight game.
Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.VelocityVFX`.

**Hit pulses / marks:** short Highlight presets on victims (`ApplyHitPulseFX(Victim, Preset)`); a flickering
AlwaysOnTop Highlight marks a locked target between press and impact. i-frame flicker writes
`LocalTransparencyModifier` (never `Transparency`) so it never fights other writers.

**Shared-clock visuals:** anything that must look identical on every Client and already be in step after a stream-in
derives from `workspace:GetServerTimeNow()` (RGB hue cycles, rotating ground circles).

**Particles vs images:** a long-lived spinning ground circle is unreliable as a particle (low Rate = up to 40s for the
first particle; `Clear()` + `Emit(1)` lost particles; on a flat `VelocityPerpendicular` particle `RotSpeed` turns
opposite to `Rotation`). Use a flat Part + top-face SurfaceGui ImageLabel rotated by the server clock. A particle's
`Size` is about half its drawn width.

**Camera shake by frames stretches at low FPS** (Studio playtests ran ~16fps: a 14-frame shake took 0.9s instead of
0.23s). Prefer time-based shakes.

## Sound dispatch (same rules)

- **Caster-aware playback:** `SoundService.Client/Server.CasterLoad(Sound, Parent, Caster?, Args)` plays the caster's
  own copy with no roll-off (full volume anywhere) and everyone else's positionally. A Sound the Server places itself is
  tagged with its caster first (`TagCasterSound`). Attacker-only sounds (finisher sting) go to that Player only.
- **Parent world Sounds to a BasePart or Attachment.** Parented to a Model/Player/Character they play 2D, heard
  everywhere (PB heard round combat in the Lobby). PB's Server resolver swaps such parents for the body's root.
- **A nil parent (not streamed in) must be dropped**, not fall back to `SoundService` (= global, full volume).
- Relayed sounds go through the RateLimiter; map-wide relays limited to a radius around the sender.
- Give combat Sounds a `RollOffMaxDistance` at least the biggest map's diagonal if they should carry map-wide.
