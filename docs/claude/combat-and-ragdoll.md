# Combat and ragdoll

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Covers hit detection, the damage/velocity choke points, the ragdoll system, knockdown i-frames, kill credit, death,
spawn protection, status effects, hit feel, dash blocking, cooldown authority and the anti-exploit guard. Ability
architecture is in `abilities-framework.md`; VFX dispatch in `vfx.md`.

## Authority model (the shape everything else hangs off)

- **Client-authoritative hit detection, server-validated resolution.** The attacker's Client runs the hitbox and
  reports `CharacterHit {AttackerCharacter, DefenderCharacter, AttackerLookVector}`. The Server never re-runs the
  hitbox geometry; it validates the packet (`CombatGuard`, below) and then owns everything with consequences:
  damage, knockback, status effects, kill credit, hit VFX/sound.
- **Server stat math is not geometric validation.** Don't mistake "the Server computes the damage" for "the Server
  checked the hit was possible". The range/window checks in CombatGuard are the only geometry guard.
- **Four choke points touch bodies:** `CombatService.Server.ApplyDamage`, `CombatService.Server.ApplyVelocity`,
  `StatusEffectService.Server.AddEffect`, and `CombatGuard`'s victim check. Every protection rule (spawn protection,
  teammates, ragdoll immunity, kill credit) is enforced inside them, so ordinary abilities get it for free.
  **Code that touches a body outside these four must re-check the rules itself** (this was the source of most
  "X ignores spawn protection" bugs).
- Per-machine physics: a Player's own Client simulates their character, so **their knockback, ragdoll and hit freeze
  run on their Client** (the Server sends a packet). NPCs and Dummies are simulated, launched and frozen by the Server.

## Hit detection

**Hitboxes are spatial queries, not `.Touched`.** `HitBoxClass.New("Block" | "Ball")` wraps a Part and
`workspace:GetPartBoundsInBox/Radius`; `GetTouchingCharacters(Excluded?)` searches the character folders
(`InGame.PlayerCharacters`, `InGame.LiveNPCs`) and de-duplicates Humanoid models. The box is projected forward from
the attacker's HumanoidRootPart, **not** the weapon's pivot (the weapon swings around; the root is stable).
Reference impl (Pillow Battles): `HitBoxClass` (under `ReplicatedStorage.System.Services.CombatService`).

**Whole-swing window, not a one-shot query.** The first version checked once at `HitboxDelay` and missed bodies that
walked in a frame later. Now `AttackClient.RunHitWindow`:
- re-checks every Heartbeat from `HitboxDelay` (0.15s) for `HitboxActiveDuration` (0.2s, ending about when the weapon
  visibly connects), at least once;
- reports each victim **once per swing** (`HitCharacters` set);
- a body skipped because it is down / hit-proof / spawn protected is re-checked next frame (it may become valid);
- **skips on the Client any body the Server will refuse** (ragdolled, stand-up grace tag, spawn protected), so the
  one report per victim isn't spent on a hit that does nothing.
- Measured: a Dummy moved into the box at 0.32s was hit; at 0.59s (control) it wasn't.

**Aim assist + facing hold.** `GetSwingAim` = the camera's flat heading, or the in-reach enemy nearest it within
`AimAssistAngle` (20 deg). `HoldSwingFacing` turns the root **before** the animation plays and holds it until the
check ends (+0.05s): `AutoRotate` off, yaw re-applied every frame at `RenderPriority.Camera + 2` (after the mobile
shift-lock bind at +1, so it wins the frame). Restore `AutoRotate` only if *you* turned it off, and only if the body
isn't ragdolled/dead and shift lock is off. Candidates exclude spawn protected / down / hit-proof bodies.

**Reach check for non-cube hitboxes:** the far corner of the box, `(X/2, Y/2, Z)` magnitude x 1.02, plus a 20-stud
lag tolerance on the Server.

**Pitfalls found:**
- **A server-side hitbox Part parented inside an NPC replicates** and lingers; `GetTouchingCharacters` takes any Part
  whose Parent has a Humanoid, so *Player* swings touching that box counted as hitting the NPC (~12 studs in front
  of it). Parent hitboxes under `workspace.InGame`, name them `HitBox` (debug-transparency tooling finds them by
  name), and set `CanQuery = false` on helper parts.
- A visible debug hitbox is not proof of a continuous hit window.
- **Testing:** a landed hit throws a healthy target ~35 studs, so a follow-up swing at a Client-only re-pivoted Dummy
  is refused "out of range". Pin test Dummies on the Server. In PB the camera followed the body, so place Dummies
  relative to the *current* camera heading.

## Damage

- **Health floor by design.** `ApplyDamage` floors Health at `MinimumHealthFromDamage` (2): **only knockouts/ring-outs
  kill** (the out-of-bounds handler sets `Health = 0` directly). Decide this early for Ragdoll Battlegrounds: with a
  floor, a "killed by damage" signal can never fire, and all death attribution must go through the death handler.
  Don't "fix" a floor as an immortality bug.
- **`ApplyDamage(Attacker, Defender, Amount, CanCancelAbilities = true)`.** Damage-over-time (Burning) passes `false`:
  it doesn't break stealth, shatter freezes, or interrupt wind-ups.
- **Interruptible wind-ups listen to `CombatService.Server.ConnectCancellingDamage(Humanoid, OnDamaged)`, never raw
  `HealthChanged`** (regen, heals and DoT ticks would cancel them).
- One scaling function (`GetScaledDamage`) shared by `ApplyDamage` and anything that must predict the result (the
  finisher decision), so the two never disagree.
- Stats: `Value = max(0, Base * (1 + Σ Multiplier) + Σ Flat)`. A Multiplier of `0.25` means **+25%**, and two of them
  give 1.5x, not 1.5625x. **Modifier ids replace**: reusing an id overwrites that slot (a kill-stacking buff only ever
  refreshed one stack until each stack got a unique id). Never remove another subsystem's id.
  Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.StatsService` (`StatUtils.StatClass`).

## Knockback / velocity

**One force pipeline**, shared by both machines: `VelocityUtils.ScaleForce` composes **attacker's outgoing multiplier
→ defender's incoming resistance → low-health amplifier**. Server and Client `ApplyVelocity` are thin wrappers over the
one shared `VelocityUtils.ApplyVelocity`. Measured: a −0.25 resistance modifier turned a 100 stud/s launch into 75.
Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.CombatService.CombatUtils.VelocityUtils`.

- **Low-health amplifier** (the battlegrounds "% damage" feel): `1 + (1 - clamp(Health/MaxHealth)) * (Max - 1)`, Max
  `HealthVelocityScalingFactor` 3. An optional per-call `MaxHealthAmplifier` lets one ability scale less (PB's Gravity
  Push used 1.5).
- **`Launch(Defender, Direction, TotalForce, BeforeWrite?, SpeedCap?)`**: caps speed (`MaxKnockbackSpeed` 800 default,
  optional per-launch cap, e.g. 1600 for a finisher), rejects NaN, calls `BeforeWrite` (take network ownership) before
  writing, writes velocity to **every assembly** of the rig (not just the root), then adds a tumble spin.
- **Direction is multiplied unnormalised.** `LookVector + (0, UpBias, 0)` keeps the flat speed and adds lift, so raising
  the bias adds height without slowing the push. `GetBlastDirection(Center, Defender, UpBias)` normalises the
  *horizontal* part only, so a body dead-centre in a blast goes straight up.
- **Who writes the velocity:** for a Player victim the Server computes the final scaled force and sends
  `ApplyLocalKnockback {TotalForce, SpeedCap}`; their own Client only calls `Launch` (so server-side caps reach real
  Players). For NPCs/Dummies the Server takes network ownership for a simulation hold (1.5s), launches, then hands it
  back. **Never restore ownership before the authoritative launch.**
- Kill credit is stamped inside `ApplyVelocity`, so every launch credits its caster.
- **Measured physics facts:** distance grows much faster than force (1.45x force went 2.4x as far: more airtime, then
  sliding). A limp ragdolled body launched with the same force travelled ~58% as far (floor friction on the limp rig).
  A body at 800 studs/s covers ~160 studs per 0.2s server sweep.

## Ragdoll system

**Ragdoll is a status effect.** `StatusEffectCallBacks.Ragdoll` calls `RagdollService.Ragdoll/Unragdoll/IsRagdolled`
and owns the `IsRagdolled` Character attribute plus a recovery token.
Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.CombatService.CombatUtils.RagdollService` and
`ReplicatedStorage.System.Services.StatusEffectService.StatusEffectCallBacks.Ragdoll`.

- **Stand up on landing, not on a timer.** `OnEnd` spawns `WaitForGround`: floor within 8 studs (ray) and
  `|vy| <= 15`, capped at 5s, then `Unragdoll` and clear the attribute. Token-checked after every wait, so a newer
  ragdoll isn't ended by an older one's recovery.
  - Consequence: **the attribute outlives the effect** on a long knockback. "Knocked down" must mean
    *Ragdoll effect active OR `IsRagdolled`*.
  - Trick: a tiny `RagdollDuration` (0.1) means "limp for the whole fall, up on touchdown" (measured ~0.55s after
    landing). Great for a launch that should end with the body getting up the moment it lands.
- **`PersistOnDeath = true`**: a corpse stays limp. Death clears every other effect.
- **Client half (Players):** the owner's Client puts its Humanoid into `Physics` and builds the limp rig.
  - **The ragdoll message must carry the target Character**, and the Client ignores messages for any body but its
    current one. Bug: a corpse ragdolled just before respawn put the NEW character into Physics, and nothing ever
    un-ragdolls a corpse → "lying on the floor on normal animations, barely moving".
  - The Server refuses a fresh Ragdoll on a dead Humanoid.
  - **Safety-net watchdog:** `Physics` state + `IsRagdolled ~= true` + alive for 1s (`STRANDED_PHYSICS_GRACE`) →
    recover through the normal Deactivate (and warn). This only works because **nothing but the ragdoll ever enters
    `Physics`**: other systems (e.g. dev fly) use `PlatformStand`, or the watchdog "recovers" them.
  - Not reproducible in solo Studio (needs latency); verified by forcing the state.
- **Animation tracks during ragdoll:**
  - **Never stop a Player's tracks from the Server.** The Server's copy of their Animator is what every *other* Client
    sees; a server-side Stop killed that Player's idle for everyone else until they next moved. Server stops tracks
    only on server-run rigs (NPCs, Dummies); the owner's Client pauses and resumes its own.
  - The Client saves each track's `Speed` and restores it on recovery. **Release any hit freeze first**, or it saves
    the freeze's 0 and the body gets up with frozen animations.
  - Anything keeping its own "track is playing" flag (an NPC animator did) must re-check `IsPlaying` after a ragdoll.
- **`RagdollImmune` attribute** (e.g. a shield passive): `AddEffect` refuses every Ragdoll and stamps
  `RagdollBlockedAt`. **Code that ragdolls without `AddEffect` must check it.**
- **Hold effects refuse ragdoll:** a body under an anchoring hold (Impaled) is refused Ragdoll/TimeStopped, because the
  other effect's restore would put the hold's anchor back and pin the body forever.
- `Humanoid:SetStateEnabled` does not replicate: disable states on **both** Server and Client at CharacterAdded.
- PB also has an older physical stand-up module (`CombatUtils.Ragdoll`: settle → AlignPosition/AlignOrientation
  handoff, ownership tokens). It is **not** the live path; worth a look only if Ragdoll Battlegrounds wants an
  animated physical get-up rather than a state flip.

## Knockdown i-frames ("hit-proof while down")

- A landed swing: Ragdoll (`BaseRagdollDuration` 1s) + Invincible for the same 1s **only if the Ragdoll took**. Then
  `WatchForStandUp` → `GrantStandUpGrace`: Invincible 0.3s + a `StandUpGrace` CollectionService tag for as long.
- **Why:** a flat 1.5s Invincible outlasted a short knockdown by ~0.5s with nothing visible. Tie i-frames to visible
  state (down → getting up → flicker), never to a bare timer.
- Watches live in token tables (strong keys), give up after 12s, on death or on destroy.
- **Flicker:** a Client tag handler blinks every tagged body's BaseParts + Decals via `LocalTransparencyModifier`
  (0.65 every 0.06s). A part someone else writes mid-blink is dropped from the set, never overwritten back.
- Server gate: `IsKnockedDown` (effect OR attribute) refuses ordinary hits. Abilities can opt in with a
  `ThroughKnockdown` flag (a deliberate OTG/combo lever): they hit bodies that are down or carrying the grace tag,
  but still respect any *other* Invincible, spawn protection and Parry.
- Side effect to remember: a body the Ragdoll never took (immune) was never down, so it only gets the 0.3s grace.

## Hit feel: freeze, finisher, sounds

- **Hit VFX and hit sound are Server-driven, for validated hits only** (Redpillars' call: no local-first). Local-first
  played sparks/sounds on hits the Server then refused (Invincible, Parried, spawn protected). Cost: the swinger hears
  it ~0.21s after the click in Studio. The **swing** sound is local-first for the swinger and relayed to everyone else
  by the Server after it accepts the start packet.
- Hit spark placement: a random spot (80% spread) on the Torso face turned toward the attacker.
- **`HitFreeze`** (leaf module, both machines): welds an invisible Anchored pin to the root and pauses the body's
  tracks. **Never write the rig's own `Anchored`** (it would fight other systems' capture/restore of Anchored).
  Only the machine that simulates the body freezes it. `Release` returns true when a velocity write must wait one
  Heartbeat. Shake = move the pin each Heartbeat.
  Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.CombatService.CombatUtils.HitFreeze`.
- **Finisher** (a hit that leaves the victim at the floor): decided on the health the hit *found* them on, through the
  shared scaling. Sequence: Invincible at once → wait until the swing visibly connects (`FinisherImpactDelay` 0.105s
  **minus the attacker's `GetNetworkPing()`**) → damage + attacker-only sounds → freeze both bodies 0.2s (victim
  shaking) → launch at 30% for 0.12s then full force (slow-start reads far better than an instant launch) → trail.
  Every stage re-checks the victim is still valid. **Freezing on the hit itself froze the attacker mid swing**: swing
  animations were baked with no markers, so the impact time was read off the animation's frames.
  Reference impl (Pillow Battles): `ServerStorage.System.Combat.AttackServer` (`ResolveFinisher`) +
  `ReplicatedStorage.System.Combat.Attack.FinisherClient` (impact frame; see `vfx.md`).
- A ring-out death can land long after the launch (11s measured on a max-force launch): size the kill-credit window
  and any "knockout" UI with that in mind.

## Kill credit and death

- **Stamp on the victim's HumanoidRootPart:** `LastAttacker` + `LastAttackTimeStamp` (and an NPC id,
  `LastAttackerNPCId`, when the attacker is an NPC). `KillerOf` reads them within `KillCreditWindow` (8s).
- **Stamped automatically** by `ApplyDamage` and `ApplyVelocity` for every hit that names an attacker. Effects that do
  neither (a freeze, a slip hazard, a grab's drop) call `StampKillCredit` themselves. Ignored: attacker-less DoT ticks
  and self-credit.
- **Death handler** is a self-registering server module (`Init()` from boot) that awards the kill (kills, streak,
  cash/receipt, leaderboard broadcast) and resets the victim's streak / adds a death.
  - **It must backfill `Players:GetPlayers()` in `Init`.** Connecting only `PlayerAdded` silently skipped every death
    in Studio solo, where the LocalPlayer joins before the Script runs. Live servers looked fine.
  - It also registers NPC bodies (`InGame.LiveNPCs`). Dummy kills pay differently on purpose; don't silently unify.
  Reference impl (Pillow Battles): `ServerStorage.System.Main.PlayerDeathHandler`.
- `Humanoid.Died` never fires on a Client for a Server-simulated body; watch `Health` instead.
- **Per-Player signal registry:** `PlayerSignalRegistry.New{"CharacterHit","CharacterKilled","SelfGotHit"}` gives each
  Player their own GoodSignal group (`CombatSignals.Get(Player).SelfGotHit`). Self-registers on `PlayerAdded`,
  backfills, cleans on `PlayerRemoving`, survives respawns (a reference captured at equip time stays valid), and
  `Get` **asserts** on a missing entry rather than lazily creating one.
  Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.PlayerSignalRegistry`.

## Spawn protection

- Granted on **every** spawn into a round (join or respawn): white Highlight + `SpawnProtected` Character attribute.
- Enforced off the attribute at every choke point: invalid victim in CombatGuard; no damage, knockback or kill credit
  in `ApplyDamage`/`ApplyVelocity`; `AddEffect` blocks every effect except the body's own defensive ones
  (Invisible, Parrying, Invincible).
- Ends after 5s, on moving more than a threshold flat from where they *settled* (sampled 0.5s after the grant, so the
  spawn drop doesn't end it), on a swing/cast CombatGuard accepts, on leaving the round, or on death.
- **Reusable as a generic "untouchable" flag:** an uninterruptible wind-up sets `SpawnProtected` directly (no Highlight)
  and clears it after. `SpawnProtection.End` only clears protection it granted, so the two never fight. (Setting
  `Invincible` alone wasn't enough: only some systems checked it.)
  Reference impl (Pillow Battles): `ServerStorage.System.Combat.SpawnProtection`.

## Status effects

`StatusEffectService.Server.AddEffect(Defender, Attacker?, Id, Duration)`. Each effect is a callback module
(`StatusEffectCallBacks.<Id>`: `OnStart`, `OnEnd`, optional `PersistOnDeath`).
Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.StatusEffectService`.

- **Stacked timers, not a bool + duration.** An effect is active while any timer remains; `OnStart`/`OnEnd` run on the
  inactive↔active transitions, not per application. The stored attacker can change on re-application.
- **Gates inside `AddEffect`:** spawn protection, teammates (only when an Attacker is passed: an attacker-less effect
  can't be team-filtered, a known gap), `RagdollImmune`, dead Humanoid (no fresh Ragdoll), holds (no Ragdoll /
  TimeStopped on an Impaled body).
- **Respawn sweep:** the Server removes every effect-owned Stat modifier id (WalkSpeed, JumpHeight lists) on respawn.
  A new effect's modifier id must be added to those lists. Permissions only come back to a Player who is in a round.
- **`Cancel` (silent) vs `ForceEnd` / `ForceDisable` (fires cleanup).** Don't interchange them.
- Patterns worth copying:
  - **Stunned:** Flat −99999 on WalkSpeed **and** JumpHeight (modifier id `Stunned`) + Attack/Ability/Passive
    permissions off. Still hittable and launchable.
  - **Hold (TimeStopped / Impaled):** capture each part's `Anchored`/velocity → take Server ownership
    (`SetNetworkOwner(nil)`) **before** anchoring → anchor every BasePart (pose freezes) → suppress permissions + stat
    roots. `OnEnd`: restore anchoring → **wait a Heartbeat** → restore velocity / release banked hits → hand ownership
    back (Players to Auto, NPCs to the Server).
  - **Break on hit:** a real hit (`ApplyDamage` with `CanCancelAbilities`) `ForceDisable`s Frozen and breaks stealth.
- **NPCs have no Client**, so permission/stat-based roots do nothing to them: the NPC brain keeps a held-effects list
  (see `npcs.md`).

## Dashes never ram walls

Every dash/lunge/burst movement asks `DashBlocker.IsBlocked` each frame: a torso-height box cast just past the next
frame's travel, floors/ramps ignored by hit normal; it stops short with `StopAgainst`, and movers use a finite
`GetMaxForce`. Measured before: a dash into a wall left at 227 studs/s and flew 61 studs; another rose 18 studs over a
wall and shoved a body 7.6 studs. A dash stopped short keeps its animation until the dash would have ended (it still
reads as a dash). Reference impl (Pillow Battles): `ReplicatedStorage.System.Combat.InnateDash.DashBlocker`.

## Cooldown authority

- **Client applies its cooldown instantly** (responsiveness); **the Server keeps its own clock** in CombatGuard
  (`LastSwingAt` / `LastCastAt`) and refuses early packets, with a 0.35s grace for jitter.
- Permissions (`PermissionService`): Active = Enabled AND no running cooldown; several cooldowns can run at once and
  the remaining time is the max. Client `HasPermission` = local timer AND the replicated server flag, so a press 0.016s
  after the Client's cooldown ends can still be refused while the replicated flag catches up.
- **Every server-side cooldown or spam floor derives from `GetFinalCooldown`** (base x the specific multiplier x
  global `CooldownMultiplier`, the same formula the Client runs), never fixed seconds. A fixed floor silently
  rejected every cast once dev mode zeroed cooldowns. Spam floors used half the real final cooldown.
- **Hit refunds** (a landed hit shortens cooldowns): once per swing however many it hits (`ClaimSwingRefund`); move
  **both** CombatGuard's clock and the Permission on Server + Client (which also moves the HUD). Side effect:
  shortening affects every queued cooldown on that Permission.
- A Server refusal of a cast refunds the whole cooldown and tells the Client (`Refused`) so it unroots/stops the
  animation.

## Anti-exploit: CombatGuard + RateLimiter

`CombatGuard` checks every combat packet before it resolves.
Reference impl (Pillow Battles): `ServerStorage.System.Security.CombatGuard`.

- **Start packets** (`ClientAttackStarted` / `ClientAbilityStarted`) open a server-side window. Required: the packet
  names the **sender's own live Character** (identity comes from the connection, never a client field); the Player is
  in a round (or an admin in dev mode, via a server-stamped attribute); the Permission is enabled and the server clock
  agrees; for abilities, the packet matches the **equipped** ability and the Player **owns** it.
- **Hit packets** must land inside that window (`SWING_WINDOW` 1.5s; per-ability `CAST_WINDOWS` for long casts, needed
  for any follow-up more than ~3s in), **once per victim**, onto a live Character in the fight (a Player in the round,
  or an NPC in the NPC folder), within reach + 20 studs lag tolerance. Look vectors go through `SanitizeDirection`
  (NaN/inf rejected, unit length).
- **Every new Client→Server ability packet must call `ValidateAbilityStart` / `ValidateAbilityHit` /
  `ValidateAbilityFollowUp`** (plus `ValidateNear` for a client-supplied point), or it is an open exploit.
- **Client-supplied geometry** (a lane, a destination, an aim point): accept it for responsiveness, but flatten it
  (no pitch/roll), reject NaN/inf, clamp its origin to the Server's view of the root (PB: ≤5 studs across, ≤3 up/down;
  `ValidateNear` alone allowed ~30), and run wall checks from the Server's own view so an origin pushed through a
  wall reaches nobody behind it. Send a teleport's start packet **before** teleporting so the Server can range-check
  the destination against the origin. A failed check denies the bonus only; nobody gets rubber-banded.
- Known PB gap: pure movement abilities (dash, step-back) had zero server validation. Harden those from day one.
- `RateLimiter` (no dependencies) limits the Sound/VFX relays and logs each rejection as
  `[Security] Rejected <name> (<id>): <reason>`, at most once per reason per 5s. Relayed Sounds must be authored Sounds
  under ReplicatedStorage, parented on or near the sender.
  Reference impl (Pillow Battles): `ServerStorage.System.Security.RateLimiter`.

## Teams

`NPCTeam.AreTeammates(A, B)` = two different bodies with the same `NPCTeam` attribute. Checked in the server victim
filter, `ApplyDamage`/`ApplyVelocity`/`StampKillCredit`, and `AddEffect` (when an attacker is named; defensive self
effects still land). Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.CombatService.CombatUtils.NPCTeam`.

## Hard rules that generalize

- Bodies: anything touching a body outside the four choke points checks `SpawnProtected` and teammates; anything that
  ragdolls without `AddEffect` checks `RagdollImmune`.
- An effect that neither damages nor launches calls `StampKillCredit` itself.
- Interruptible wind-ups use `ConnectCancellingDamage`; DoT passes `CanCancelAbilities = false`.
- Server cooldown guards come from `GetFinalCooldown`, never fixed seconds.
- Every Client→Server combat packet goes through CombatGuard.
- Dashes/lunges/bursts use DashBlocker.
- Never stop a Player's animation tracks from the Server; anything with its own "playing" flag re-checks `IsPlaying`.
- Only `Ragdoll` enters `HumanoidStateType.Physics`; everything else uses `PlatformStand`.
- Never write a rig's own `Anchored` for a transient effect: pin it with a welded anchored part, or capture/restore
  under a hold effect that owns the body.
- Death/round handlers backfill existing Players at `Init`.
