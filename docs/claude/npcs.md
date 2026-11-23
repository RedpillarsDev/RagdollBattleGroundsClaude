# NPCs and bots

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

PB filled rounds with server-run combat NPCs ("Round NPCs") that used the same weapons, passives and abilities as
Players, plus a 1v1 bot. Module paths below are PB's, all under `ServerStorage.System.NPC` unless noted (verify).

## Architecture

| Module | Role |
|---|---|
| `NPCService` | How many NPCs a round wants; spawns/removes them (staggered) |
| `NPCAgent` | One NPC's body lifecycle: spawn, equip, respawn, death, removal; holds its `RoundContext` |
| `NPCBrain` | Decisions: target choice, held check, floor checks, roam/heal behaviours |
| `NPCCombat` | Movement + fighting: `SafeMoveTo`, attack runs, dodges, `HasRoomFor` |
| `NPCCatalog` | Archetypes (weights, skill numbers, weapon pool, ability arsenal) |
| `NPCGlobalConfig` | Every tunable number (incl. `AbilityUse` entries) |
| `NPC.Abilities.Modules.<Id>` + `NPCAbilityUtils` | The Client half of each ability, run on the Server |

## Population

- **Count rule:** `MaxNPCs - (Players - 1)`, clamped to `0..MaxNPCs` (PB: 4). Each extra Player takes one NPC's spot.
- Runtime override from the admin panel (this server only, never saved, capped at `MaxNPCsLimit`). The live round
  follows at once: missing NPCs spawn staggered; **extra NPCs are marked `Leaving` and removed at their next death**
  (never despawned mid-fight). The panel reads the current/default values from attributes on ReplicatedStorage.
- Each life rolls a random archetype by `Weight` (a weight-0 entry is never picked: used for the tutorial NPC), a
  random weapon from the pool, and a random ability from its arsenal (`AbilityId` body attribute).

## Round contexts (one NPC codebase, many arenas)

An `NPCAgent` fights inside a `RoundContext`:
`ArenaId, IsActive, GetSpawnCFrame, GetMap, GetPlayers, AddNPC, RemoveNPC`, optional `MaxHealth, RespawnDelay,
MaxNPCsPerPlayer, TargetsNPCs, OnBodySpawned`.
- Passing none gives `LiveRoundContext` (the live round). Tutorial rounds and the 1v1 bot pass their own.
- The body carries `ArenaId` (nil = live). The brain gets its map (floor rays, roam points, heal pads) and Players from
  the context and **only sees NPC bodies with its own `ArenaId`**, so arenas never see each other.
  `TargetsNPCs = false` = fight Players only.
- **1v1 bot** = an `NPCAgent` with a custom context: held until FIGHT, every respawn at the SpawnPoint furthest from
  the opponent, sudden-death speed applied to its Humanoid directly.
- Kill credit can name an NPC by id (`LastAttackerNPCId`), so lookups by id (`FindNPCById`) search every arena's list.

## Wielder abstraction (so NPCs run Player code)

Weapon passives take a **Wielder** (`Player | Model`) through a small adapter: `GetCharacter`, `IsInRound`,
`IsPassiveReady` / `AddPassiveCooldown` (PermissionService for a Player, a plain clock for an NPC body),
`GetHitSignal` (the per-Player signal for a Player; for an NPC, the server swing code fires the adapter's NPC hit on
every landed swing).
- **A passive must never touch `Player.Character`, PermissionService or the per-Player signals directly.** PB's
  legendary passives still did, so they stayed out of the NPC pool.
- `NPCAgent` runs the weapon's server equip callback once the body is in the world, and the unequip on death **and**
  when the body goes (no Died on a destroyed body).
- Reference impl (Pillow Battles): `ReplicatedStorage.Data.DataLibrarys.Pillows.PillowWielder`.

**Stats for NPC bodies:** `StatsService.Server.GetStat/GetStatValue` accept an NPC body (stat objects built on first
use, never replicated, dropped on `Destroying`). `GetStatOwner(Character)` returns Player, NPC body, or nil (Dummy,
neutral); damage, life steal and force scaling use it. NPCs are always Level 1.
- NPC bodies have no WalkSpeed Stat: slows and speed boosts write `Humanoid.WalkSpeed` directly, parking the base in
  an attribute (`SlownessBaseWalkSpeed`) to restore.

## Abilities on NPCs

- `NPC.Abilities.Modules.<Id>` plays the anim/sound/VFX and builds the hitbox on the Server via `NPCAbilityUtils`, then
  calls the Player's `AbilityCallbacks.<Id>.Server`. Reads config at Level 1.
- **NPC-usable only with a module + an `NPCGlobalConfig.AbilityUse` entry.** Template default: not NPC-usable.
- Abilities whose effect depends on the Client (camera aim, client-drawn lanes) need an NPC-specific aim source.

## Held effects

NPCs have no Client, so effects that root through Stats/Permissions (Frozen, Stunned, TimeStopped, Impaled, own
Parrying) do nothing to them on their own. `NPCBrain.IsHeld` stands the NPC still for each of them.
**A new rooting/holding effect must be added to that list** (PB kept a matching `HOLDING_EFFECTS` list in the shared
lane-targeting module too).

## Fight behaviour (what made them feel good)

- **Attack runs, never circling** (Redpillars): run into the target, or overshoot past them and whiff
  (`Skill.OvershootChance`). Innate-dash a lot: jump dashes, dash attacks, mid-air dashes on pad flights.
- **At most `MaxNPCsPerNPC` (1) NPC per target**, so they don't clump on one Player (`NPCCombat.HasRoomFor`, per
  context).
- **Every move is floor-checked strictly** (`IsFlooredStrict`, `SafeMoveTo`): NPCs used to chase launched targets
  straight off the map. Critical in a knockback game.
- Stop at `ContactDistance`; back off after whiffs and while the target is down (they can't be hit anyway); turn on
  whoever hit them.
- Stealth: an NPC only sees an invisible enemy within `InvisibleSpotDistance` (8); an NPC's own swing breaks its own
  stealth.
- Situational behaviours read like personality: e.g. a healing-weapon NPC that is hurt, alone and not recently hit
  stands still to regen for a few seconds.
- Archetypes (PB: Rookie / Brawler / EdgeLord / Trickster / Veteran) vary accuracy, dodge rate, overshoot and ability
  eagerness; swing pacing and dodge reach come from the equipped weapon's stats.

## Lessons / gotchas

- **Ragdoll stops ALL animation tracks on a server-run rig.** An NPC animator that kept its own "is playing" flag
  never restarted its loops: re-check `IsPlaying`.
- **Server swing hitboxes parented inside the NPC replicate** and made the NPC hittable from ~12 studs in front for
  0.25s (`combat-and-ragdoll.md`). Parent hitboxes under `workspace.InGame`.
- **Teams:** bodies sharing an `NPCTeam` attribute never hit, damage, launch, ragdoll or kill-credit each other. Gap:
  attacker-less effects (a dropped slip hazard) can't be filtered, so tutorial NPCs didn't carry hazard weapons.
- **Idempotent `Destroy`** on anything an NPC (or Player) spawns: a dropped hazard could be destroyed by a trigger,
  its lifetime and the round-end cleanup; a `Destroyed` flag made all three safe. Give dropped hazards a lifetime.
- **Stacking buffs need unique modifier ids** (`Buff_<n>`); a repeated id replaces. Clear stacks on `Died` plus
  `CharacterAdded` (a body can go without Died).
- Kills of bots counted like Player kills in PB (a possible farm, flagged, not changed): decide up front for Ragdoll
  Battlegrounds.
- The tutorial used a deliberately weak archetype (slow, inaccurate, overshoots, rarely dodges, uses abilities
  readily) at Weight 0 so the normal picker never rolls it.
