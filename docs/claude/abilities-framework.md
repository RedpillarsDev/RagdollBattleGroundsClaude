# Abilities framework

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

The ability architecture, how to add one (with Redpillars' request form), and a catalogue of reusable ability
techniques with the Pillow Battles (PB) ability that proved each. Combat choke points, CombatGuard and status effects:
`combat-and-ragdoll.md`. VFX rigs: `vfx.md`. Leveled config reads: `progression.md`.

## Architecture

```
ReplicatedStorage.Data.DataLibrarys.Abilities            -- catalog: {[AbilityId]: Record} + export type AbilityId = "A" | "B" | ...
  AbilityCallbacks.<Id>
    Client         -- returns the client cast function (anim, local VFX/sound, aim, packets)
    Server         -- resolves every hit itself (targets, damage, effects, kill credit)
    Shared?        -- logic both machines must compute identically (line of sight, an outbound path plan)
    AbilityConfig  -- EVERY number (Cooldown included) + Animations / VFX / SFX refs
    LevelingConfig -- per-level curve + Buffs (progression.md)
    Assets         -- Animations the game doesn't already have
```

- **Catalog record:** `Id, Name, Rarity, UIImageId, Cooldown, ClientCallback, Description, ObtainmentText`, optional
  `InstaBuyProductId`, plus the optional hooks below. `Cooldown = require(AbilityConfig).Cooldown`: **edit cooldowns in
  the config, never in the catalog.** Add the entry **and** its `AbilityId` union member.
- **Client flow, `AbilityClient.BaseAbility()`:** Ability permission → equipped Id from save data →
  `ClientRecast` (if present; returns true = press consumed, no cast, no cooldown) → `ClientCanCast` (if present;
  false = nothing happens, no cooldown) → local cooldown (skipped for `DeferredCooldown`) → send
  `ClientAbilityStarted` → `ClientCallback`.
- **Server flow:** `AbilityServer` listens to `ClientAbilityStarted`, runs `CombatGuard.ValidateAbilityStart`, applies
  the server cooldown (skipped for `DeferredCooldown`), fires `CastStarted` (EXP etc.). Ability-specific packets are
  declared in one `AbilityPackets` module and listened to in one server file (`PacketsInit.AbilityPackets`), each
  behind a CombatGuard validator, then dispatched to `AbilityCallbacks.<Id>.Server`.
  Reference impl (Pillow Battles): `ReplicatedStorage.System.Combat.Ability.AbilityClient`,
  `ServerScriptService.ServerStartModules.PacketsInit.AbilityPackets`, `ServerStorage.System.Security.CombatGuard`.
- **Don't** build a separate global transport or one `AbilityServer` per skill. A `ClientAbilityStarted` notification
  alone never validates an effect packet.
- **Optional record hooks (all proven):**
  - `ClientRecast(...) -> boolean`: two-step abilities (the second press is a recast, not a new cast).
  - `DeferredCooldown = true`: Client and Server skip the cast-time cooldown; the ability applies it itself (on recall,
    fizzle, landing...).
  - `ClientCanCast(...) -> boolean`: "no target = no cast, no cooldown". The check picks and stores the target for the
    cast that runs straight after.
- **NPC use:** an NPC has no Client, so an `NPC.Abilities.<Id>` module does the Client half on the Server (anim,
  sound, VFX, hitbox) and then calls the Player's own `AbilityCallbacks.<Id>.Server`. An ability is NPC-usable only once
  it has that module + an entry in the NPC ability-use config. See `npcs.md`.
- **Keep authored timing separate from authoritative windows.** VFX/animation lengths are presentation; the Server's
  hit window and timeline come from config numbers on the Server clock.

## Adding a new ability

### Redpillars' request form

Redpillars copies this, fills in what they know and sends it. Blanks get the **[default]**; the summary must say which
defaults were used. Ask about a blank only when there's no sensible default. (Economy/obtainment lines are trimmed to
a generic slot here: fill them in once Ragdoll Battlegrounds has its own shop/crate design.)

```
NEW ABILITY  (fill in what you know, leave the rest blank: blanks get the [default] and I'll tell you which)

== BASICS ==
Name (shown in game):
Rarity:
Description (one line):
Icon image id:
Robux insta-buy DevProduct id: [none]
Cooldown in seconds: [placeholder for its rarity]

== HOW PLAYERS GET IT ==
Sources (shop / crate / reward / bundle) + price or chance: [none yet]

== ASSETS ==
Animation id(s), and when each plays (wind-up / cast / loop / end):
   one-shot or looped?  [one-shot]
Sounds folder, and when each sound plays:
VFX folder, and when + where each rig plays (on the caster / on each target / at a point / down a lane):
Models or meshes (projectile, object), and where they are: [none]
Flash / Highlight colour on targets: [none]

== WHAT IT DOES ==
In your own words, step by step:
Timings: wind-up ___s   active ___s   end lag ___s
Targeting: self / aimed with the camera / in front (lane or cone) / circle around the caster / whole map
   Range: ___ studs    Max targets: [all]
   Through walls? [no]
Who it hits: Players + round NPCs [yes]   (teammates and spawn-protected: never)
Through knockdown (hits ragdolled / getting-up bodies)? [no]
On targets: damage ___ / knockback ___ (which way? lift?) / ragdoll ___s / stun ___s / freeze ___s / burn ___s / slow ___% for ___s
On the caster during the cast: moves freely / slowed ___% / rooted     jump? [no]     swing? [no]
Cancelled if the caster is hit during the wind-up? [no]
Nothing in range: [still plays, cooldown used]

== EXTRAS (optional) ==
NPCs can use it: [no]
Gets better with Level (what, by max Level): [cooldown x0.8 + its main effect x1.25]
Anything special on mobile / controller:
Reference (a video, another game, an ability here it is like):
```

### Build checklist (where each answer goes)

1. **Code:** `AbilityCallbacks.<Id>` with `Client`, `Server`, `AbilityConfig`, `LevelingConfig` (+ `Shared`, `Assets`).
   Every number in `AbilityConfig`, read through the leveled view at use time (never at module load).
2. **Catalog:** entry + `AbilityId` union member.
3. **Packets:** a Start packet (plus a follow-up, or a Server→Client draw packet, if needed) in `AbilityPackets`;
   listener behind `ValidateAbilityStart` / `Hit` / `FollowUp`; a `CAST_WINDOWS` entry if a follow-up comes >3s in.
4. **VFX:** a `VFXSequences.<Id>AbilityVFX` module + registration. Place **every** nested BasePart by its offset; never
   stamp Forge attributes on authored rigs (`vfx.md`).
5. **Sounds:** through the caster-aware sound API (caster hears their own at full volume, everyone else positionally),
   parented to a BasePart/Attachment.
6. **Status effects:** a new effect = a `StatusEffectCallBacks` module; its Stat modifier ids go in the respawn sweep
   lists; a new hold goes in the NPC brain's held list.
7. **NPC use** (only if asked): `NPC.Abilities.<Id>` + ability-use config entry.
8. **Run the hard rules:** kill credit, SpawnProtected / teammates, DashBlocker, hitboxes under `workspace.InGame`,
   cooldown guards from `GetFinalCooldown`.
9. **Test** in a dev arena with Dummies in the NPC folder; undo any test grants to the profile; write a notes section.

## Technique catalogue

Each entry: the reusable technique, the gotchas that made it work, and the PB ability that proved it.

### Client-drawn projectile, Server-clock damage (PB: Divine Spear)
- Nothing physical replicates. Every Client flies its own copy: the caster at release, everyone else on a
  `<Id>Thrown` broadcast (`sendToAllExcept` the caster). Straight line, tip first, trail on, removed shortly after impact.
- The Server resolves damage on **its own clock**: flight time = distance / speed from the throw, then a ball query at
  the impact point. No projectile-hit packets to validate.
- Multi-stage payloads stack cleanly as separate queries (burning ball, then an explosion with blast knockback).
  Choose deliberately whether a stage skips ragdolled bodies (PB's explosion did NOT, so it flung the first stage's
  victims).

### Ground-targeted strike with scheduled impact (PB: Sky Crash)
- Aim = camera ray onto the floor, clamped flat to `MaxTargetRadius` around the **cast origin the Server recorded**;
  aiming at the sky clamps along the camera heading; no floor = come straight back down.
- The Server detonates **on schedule** (`CrashTime` after the dive packet) and does **not** wait to see the caster
  arrive: its view of a client-pinned character stalls (a whole rise replicated as one jump) and an arrival check
  skipped ~1 in 3 impacts. Only a gone/dead/ragdolled caster skips the impact.
- Caster-only landing marker: a client-created Part never replicates.
- Phase VFX fire at each phase's start; the dive trail is aimed with `CFrame.fromMatrix` (`lookAt` breaks on a
  straight-down dive).

### Interruptible wind-up (PB: Sky Crash, Arm Cannon)
- Server opens a session at the start packet and watches the wind-up with `ConnectCancellingDamage`; a real hit sends
  `<Id>Cancel` to everyone. Once airborne/committed the cast always completes.
- Known quirk: the Client starts its motion on its own clock, so a cancel that lands late shows a small hop.
- Prefer **slowing** the caster with a temporary WalkSpeed Stat modifier over rooting, and lock only the jump
  (PB Arm Cannon: −50% speed, jump off).

### Uninterruptible wind-up (PB: TimeStop)
- Setting `Invincible` alone failed: only some systems checked it. Set the generic untouchable flag
  (`SpawnProtected`, set directly, no Highlight) for the wind-up only; every choke point refuses on it.

### Targeted teleport / backstab (PB: Blink)
- Target = living, visible character closest to the **flat camera heading** inside a tall box (pitch ignored, so
  airborne targets can be picked by aiming level). Land `BehindDistance` behind, facing their back; fall back to their
  sides, then front, when walls or a missing floor block the spot; refuse the void. No target = blink forward.
- The start packet goes **before** the teleport so the Server can range-check destination vs origin (horizontal and
  vertical limits matching the targeting box). A failed check only denies the bonus.
- Backstab window: the first **landed** hit within N seconds gets x1.5; the Server spends it only after the
  Ragdoll/Invincible/Parry gates, and for a brief 0.5s lets that hit through Ragdoll/Invincible (never Parry).
- **Shift-lock fix:** when `UserInputService.MouseBehavior == LockCenter`, also turn the camera to the landing heading
  (keep pitch), or the character snaps straight back to the old camera direction. Writing `Camera.CFrame` under the
  Custom camera sticks.
- Animation priority `Movement` (below the swing's `Action`) so a swing out of the blink overrides it instead of
  blending.

### Recast / two-step (PB: Rewind Anchor)
- `ClientRecast` + `DeferredCooldown`; the follow-up is a `ValidateAbilityFollowUp` inside a `CAST_WINDOWS` entry of
  `Duration + 2`. Placing is free; the cooldown starts on recall or fizzle.
- Automatic triggers (past max range, or near the kill height = void save) still fire while ragdolled; a *pressed*
  recall is refused while ragdolled/frozen.
- Snap the saved point to the ground (+1 stud lift) so the warp lands on the floor instead of clipping.
- Pause automatic checks while the root is anchored by a screen transition; drop the anchor when round state changes
  so a round exit can't recall the Player into the map.

### No target, no cooldown + refusal refund (PB: Judgement)
- `ClientCanCast` picks the target (smallest angle to the crosshair within range, line-of-sight ray, skip protected /
  invisible / anchored / held bodies).
- Server re-validates (`ValidateAbilityStart` then `ValidateAbilityHit` with range) and re-runs the targeting rules and
  wall ray. On refusal: send `<Id>Ended {Refused}` (Client unroots, stops the anim) and refund the whole cooldown.

### Lane targeting with the Client's lane (PB: Gravity Pull / Gravity Push, shared `GravityLane`)
- Server picks targets in a box down the caster's flat facing: width x height x `Range`, closest first, optional
  `MaxTargets`, skipping protected / teammates / Invincible / Parrying / already anchored / knocked down (unless
  `ThroughKnockdown`).
- **Use the Client's lane.** The Server's view of the caster's root lags, so a fast turn during a 0.35s wind-up sent
  the hitbox down the old heading while the VFX went the new way. Fix: the Client sends the lane it drew
  (`<Id>Fire {Lane}`); the Server waits up to 0.25s past its own wind-up for it, flattens it, clamps its origin
  (≤5 across, ≤3 vertical), and falls back to its own view if none arrives. Walls are still cast from the Server's view.
- **Wall checks against lying bodies:** a standing-size box (3x4x2) carried from root to root sinks into the floor when
  the target's root is <2 studs up (a lying body's root is ~0.5 up; standing ~3) and counts the floor as a wall. Aim the
  wall check `KNOCKDOWN_WALL_CHECK_LIFT` (2.5) above a knocked-down target's root.
- Match the hitbox volume to the VFX volume (rig origin vs centre offsets bit PB: raise the box and extend it to the
  floor under a standing root so lying bodies stay inside).
- Test trap: 8s effects ran out during tool round trips before the cast; check the states *at* the cast.
- Reference impl (Pillow Battles): `System.Combat.GravityLane` (`ExpectClientLane` / `ReceiveClientLane` /
  `WaitForClientLane` / `ResolveLane` / `FindTargets` / `GetTargetableRoot`).

### Pull / grab with Client-drawn movement (PB: Gravity Pull, Judgement lift)
- Server: take the root's ownership, anchor it, **write nothing** until the move ends; then set the final CFrame,
  unanchor, and hand ownership back a frame later (Players to Auto, NPCs to the Server).
- Every Client lerps the root itself on a `<Id>Pulled` broadcast, bound before the Camera (smoothstep/ease-out).
- A root something else moved mid-pull (a round end) is only let go, never dragged back.
- Landing spots: N studs ahead of the caster, spaced sideways, facing the caster, short of any wall.

### Grab-and-carry projectile (PB: Boomerang)
- **Decide the outbound path once, at the throw:** cast the whole straight path and pull the turn point in front of the
  first wall (keeping the mesh's spin radius clear). That turn feeds straight into `TurnTime`, so Clients need no
  extra sync. Pressed against a wall = `TurnTime` 0.
- **One wall check for both machines (`Shared.CastBody`):** a body-sized Blockcast **plus a centre Raycast**, because
  shapecasts ignore anything they start inside. Walls = `RespectCanCollide` in the `Players` collision group (so
  NoPlayerCollide objects don't count); body/VFX/clone folders excluded; other Humanoid models skipped.
- Catches refused through a wall, or when the root is already anchored (another hold).
- **Bug worth remembering:** the sweep's `LastSweptPosition` froze while a victim was held, so the first sweep after a
  drop spanned the whole carry (112 studs) and teleported everyone along it onto the projectile. Keep sweep state
  moving during holds.
- Ownership before anchor; the drag is drawn by each Client (pinned at render priority Camera−1, eased in over 0.12s)
  while the Server pins the body as authority. Client and Server drop points matched to 0.01–0.06 studs.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Classes.GameObjects.Boomerang` (+ `.Shared`, `.Client`).

### Impale / hold status (PB: Judgement's `Impaled`)
- A hold effect: root ownership to the Server, every BasePart anchored (pose frozen), permissions off, WalkSpeed +
  JumpHeight Flat −99999. `OnEnd` restores anchoring and hands the root back a Heartbeat later.
- Holds refuse Ragdoll/TimeStopped (their restore would re-anchor the body forever).
- Seeded per-Client VFX: the Server sends a seed so every Client rolls identical rod placements.
- Long multi-stage timelines: derive every backstop (hold length, VFX cleanup, Client cast end) from the config's
  stage durations so a retune never desyncs them. End early only when caster/target die, leave, or lose their body.
- Finish with a tiny ragdoll (0.1s) so the target falls limp and stands the moment it lands.

### Stun (PB: Stunned via Gravity Pull/Push)
- WalkSpeed + JumpHeight Flat −99999 + combat permissions off; still hittable. NPCs need the held list. Stun after a
  pull = guaranteed combo window (a swing 0.3s after landing hit both pulled dummies).

### Area-denial rain (PB: Piano Crushers)
- Random spots over a map's bounding box lost 12–62% of drops to missed rays and landed on scenery. Fix:
  - play area = SpawnPoints' X/Z footprint + padding, or an authored Part named `PlayArea`;
  - floor rays `RespectCanCollide`; a hit more than N studs above the highest spawn floor is scenery, skip it;
  - box-fit the object's widest footprint so it can't rest on a ledge; retry up to 15 times, then take a plain floor hit.
  - Result: 100% spawned on every map, 1–2.3 tries each.
- Client-only landing indicator: the Server stamps `ImpactY` / `IndicatorSize` attributes on the falling object; each
  Client draws a fading disc locally (nothing replicates).
- Floor rays include **every** round-map container (live map, private arenas), never just the live map (`round-loop-and-world.md`).

### Stealth that breaks on action (PB: Invisibility)
- Break authoritatively in `ApplyDamage` (damage dealt **or** taken; not parried hits, not DoT), plus a Client cancel
  packet on swing to cover misses. Stamp an `Invisible` attribute; indicators/overheads follow the attribute. Both
  packets reject any Character but the sender's own.

### Freeze that shatters (PB: Ice Zone)
- A real hit `ForceDisable`s Frozen; `OnEnd` broadcasts a shatter VFX (client-simulated pieces, NoPlayerCollide) on hit
  AND on timeout, and plays the break sound on the body.

### Borrowing the weapon grip (PB: Divine Spear)
- Reuse the hand's existing grip Motor6D: park the current weapon (`Parent = nil`), swap C0/C1 for the spear's,
  restore on throw, death or a backstop timer. If another system re-took the joint mid-cast, discard the parked weapon
  instead of restoring over it.

## Animation and timing lessons

- **Animations baked without markers:** read impact times off the animation's frames (e.g. frame 5 at 60fps =
  0.083s) and put them in config.
- **An empty upload has `AnimationTrack.Length == 0`** (published before keyframes were baked: one keyframe, no poses).
  Check `Length` after loading a new animation id.
- Playback speed changes real timings: a 0.47s animation peak is 0.36s real at speed 1.3. Keep the Server's hit
  timing in config, not derived from a track at runtime.
- Never level a timing that both machines read when one side draws at Level 1; pass the caster's Level in VFX args or
  don't level it.
- **Luau: a `local function` defined further down the file is nil at the call site** (PB: "attempt to call a nil
  value"). Define helpers above their first use.

## Testing abilities

- Dev arena with Dummies parented to the NPC folder (so the hit pipeline treats them as fight bodies), no round, no NPCs.
  Rounds interfere: NPCs kill the test Dummy, the round ends mid-test, spawn protection silently refuses hits.
- Dev mode zeroing cooldowns + an input left pressed recasts the moment each cast ends.
- After swapping the equipped ability, wait a few seconds: a packet sent too soon is refused as "not the equipped
  ability" and the Server falls back.
- Real-network behaviour (two Players, latency) can't be tested in Studio solo; say so in summaries.
