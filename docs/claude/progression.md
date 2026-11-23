# Progression (levels, EXP, config-by-level)

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

PB levelled three things: each weapon copy, each ability copy (1–20, own curve each) and the Player (1–100). The
reusable part is the **config-by-level view**: every gameplay number lives in the item's config and is read through
one function at the caster's Level, so a new buff needs no extra code.
Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.Leveling` (shared, requires nothing) +
`ReplicatedStorage.System.Services.LevelingService`.

## Data shape

- Per item, a `LevelingConfig` beside its `Config`: `Levels[N]` = EXP needed **at Level N−1** to reach N (per level,
  not cumulative), matching a save that stores `{Level, EXP-toward-next}`. Changing a curve then needs no migration
  (an over-full save rolls over on its next EXP; levels are not retroactively granted).
- **Buffs** pick keys from the item's own Config (numbers and Vector3s only):
  - `{Scale = 1.25, Round = true?}` (default): max Level = the Config's value x Scale, lerped in equal steps. It follows
    the Config, so a retune (or zeroing for a test) keeps its curve. An absolute `Max` didn't: a zeroed cooldown came
    back at Level 20.
  - `{Min = ?, Max = ?}` still supported; Max may be below Min (shorter wind-ups). With both, Scale wins (warn once).
  - A Buff that doesn't fit its key (string, Instance, type mismatch, missing key) is warned once and ignored.
- PB placeholder curves: items `(N−1) * 100`; Player `(N−1) * 50` (Redpillars: "only 50 EXP harder per Level").

## Reading config at a Level

- **`Leveling.ConfigFor(Wielder, Kind, Id, BaseConfig)`** returns a cached proxy view per Level. A buffed key is
  computed **on every read** from the base's current value; everything else reads the base live, so runtime tweaks
  show on both. Writes go through to the base; `for k, v in View` walks merged values. No Buffs → returns the base.
- `Leveling.GetValue(...)` for one number (the catalog Cooldown). `Leveling.ConfigAt(..., Level)` for a fixed Level.
- **Wiring rule:** rename the require to `BaseConfig`, then `local Config = Leveling.ConfigFor(Caster, ...)` at the top
  of each cast/hit/helper. Helpers with no caster take a `Character` param. Concurrent casts by different casters must
  thread their own view (never a module-level cached one).
- **Never read a config key at module load** (it would never level). Instances (rigs, sounds, animations) may be read
  straight off the base.
- **Whose Level:** the Server stamps `WeaponLevel` (PB: `PillowLevel`) / `AbilityLevel` (the **equipped** copy,
  clamped to its curve) and `PlayerLevel` as **Attributes on the Player**, at load and on every equip/inventory/level change. They replicate, so
  other Clients' VFX read the same Level. A Character resolves to its Player; NPCs, Dummies and unstamped Players are
  Level 1.
- **Don't level a timing both machines read when one side can't know the Level** (e.g. Clients draw VFX at Level 1):
  pass the caster's Level/character in the VFX args, or leave it unlevelled. VFX, sound and screen-shake numbers stay
  unlevelled.
- Passives read the Level when they switch on, so a Level attribute change re-applies the passive (unequip → equip;
  restarts its state). Equip sites switch the passive before moving the equipped pointer.

## Default balancing rule (Redpillars: "25% stronger max at Level 20", per stat, all as Scale)

| Stat kind | Scale | Why |
|---|---|---|
| Damage, knockback, effect/ragdoll durations, ranges, a passive's own effect | 1.25 | the full 25% |
| Hitboxes | 1.15 | VFX don't grow with the hitbox |
| Cooldowns | 0.8 | 25% more casts (0.75 would be +33%) |
| Wind-ups, end lag, swing blocks, rooting | 0.8 | 25% faster |
| A self-penalty (caster slow multiplier) | 1.25 | less slowed |

Per-item judgement: level the thing that drives both mesh and hitbox (a scale value), not the hitbox alone; level a
rate, not a duration, when both multiply (25% more, not 56%); a bonus that's a Multiplier modifier levels the bonus
itself (+15% → +18.75%); integers that can't grow 25% stay. Stacked stats make a max item more than 25% stronger
overall; that was accepted.

## EXP

- **One writer:** `AddEXP(Player, Kind, Amount, UniqueId?)` (defaults to the equipped copy). Refuses non-positive/NaN,
  returns levels gained + a `Given` flag, fires `LeveledUp(Player, Kind, Id, NewLevel, OldLevel)`. At max Level extra
  EXP is discarded.
- **Sources** are one table (`EXPConfig`: `Weapon {Kill, Hit, RoundWin, RoundParticipation}`, `Ability {Use, Kill, ...}`,
  `Player {...}`; 0 turns a source off) given through `AwardEvent(Player, Event, Multiplier?)`.
  **The caller decides whether the moment counts** (PB: live rounds only, not tutorial/dev/dummies; arenas apply their
  own `GetEXPMultiplier`).
- Hooks: Kill in the death handler; Hit in server hit resolution past every gate; Use after the cast is accepted;
  round win/participation in round payouts.
- Kill EXP multiplied by the kill receipt's multipliers (streak etc.); other sources by the cash boost multiplier.

## Feedback

- Level-up VFX for everyone (clone rig on the anchor part → wait 0.1s → replicate emit; weapon rig from the held
  weapon's centre, others from the root). Sound + notification to that Player only, debounced 0.3s (a round end can
  level several things at once). Level-up popups are held during a round / winner screen; the reward itself is
  granted immediately.

## Per-weapon swing stats (related pattern)

Every weapon's Config holds `HitDamage`, `SwingCooldown`, `HitboxSize` (Vector3), so a Buff levels them. **One reader**,
`SwingStats.Get(Wielder)`, returns them through the leveled view, and every consumer uses it: client hitbox and
cooldown, server damage and NPC swing hitbox, CombatGuard's reach and cooldown floor, NPC pacing. Global attack config
values are only the fallback; stat multipliers still apply on top. Prefer this over passives that modify swing stats
indirectly. Reference impl (Pillow Battles): `ReplicatedStorage.System.Combat.Attack.SwingStats`.

## UI lessons from the level HUD

- Find authored rows **recursively** (`FindFirstChild(name, true)`): a designer wrapping rows in a `Content` frame
  silently broke direct lookups. Accept ImageLabel **or** ImageButton by name (a re-authored icon changed class and
  stopped repainting / stopped being clickable). Warn by class when a "button" isn't a GuiButton.
- Repaint on data change signals folded to once per frame; a level-up writes *into* an array entry, which fires no
  array signal, so also listen to the list's changed signal.
