# Ragdoll Battlegrounds: Game Principles

**Status:** v1 draft, 2026-11-28. The four calls under "Decisions" are Redpillars'. The pillars, tie-breakers and
non-goals were drafted by Claude from those calls and stand until Redpillars edits them. Change this file only on
Redpillars' say-so. Roadmap: `docs/game/roadmap.md`.

## Pitch

A drop-in physics playground. The fun is flinging other players, getting flung, and watching ragdolls fly off the toys
built into the world.

## Decisions (Redpillars, 2026-11-28)

| Question | Call |
|---|---|
| Core game | **Physics chaos sandbox**, the Ragdoll Park direction. Not a moveset brawler, not round-based. |
| Combat feel | **Easy + chaotic**: few buttons, physics decides a lot, funny over fair. |
| Money and power | **Earn power, buy style.** |
| Next milestone | **Fun-first prototype**, no date. |

## Pillars

### 1. Getting flung is the fun

Getting ragdolled pays off for both players. It isn't a punishment. A player who just got launched into the shark tank
should be laughing.

- Ragdolls are short and getting up is quick. Nobody watches their own body lie still.
- Every big fling gets a payoff: an impact sound, a little camera shake, a VFX puff, a funny voice line.
- Losing a scrap costs almost nothing: fast respawn, no death-screen tax.
- **Test:** would a clip of this be funny?

### 2. The world is the weapon

The map's toys and hazards do more of the flinging than fists do: cannon, press, trampoline, punch machine, fan,
bowling pins, sharks.

- New content is mostly new toys and stations, not stat changes.
- A station explains itself on sight. No text tutorial (the building style already bans words in maps).
- Players can use stations on each other: lure someone under the press, throw them onto the lane.
- Stations and breakables reset themselves, so the park is always ready.

### 3. Ten seconds to fun

- A handful of verbs (target: three) that anyone learns without a tutorial.
- Identical on phone, PC and controller. Every control gets a gamepad binding and per-device key hints (existing hard
  rule).
- No combos, no frame windows. Physics decides more than execution: getting better means knowing the toys, not
  having faster fingers.
- Spawn to action in seconds: no queue, no lobby, no menu between the player and the park.

### 4. Chaos, not cruelty

Chaos is only fun while nobody can be farmed.

- A short ragdoll immunity after getting up, so nobody gets chain-locked (Pillow Battles ragdoll-immunity pattern).
- Spawn protection. No spawn camping.
- Every fling, from a player or a station, goes through the server's velocity and ragdoll choke points (existing
  server-authority hard rule).
- New players are never the easy target.

### 5. Smooth on a phone

A physics game lives or dies on how a fling looks on every screen.

- Budget for low-end phones: parts, simultaneous ragdolls, effects.
- A fling looks the same to the flinger, the victim and spectators, with no rubber-banding. Settle the ownership
  model early in the prototype, before anything is built on top of it.
- The server decides who gets flung. Clients only render it.

### 6. Earn the toys, buy the style

- Anything that changes what a player can **do** (gadgets, throwables, abilities, station access) can be earned by
  playing.
- Robux buys **looks and time**: cosmetics, trails, ragdoll effects, scream/voice packs, emotes, currency boosts.
- Never sold: exclusive power, an item that wins encounters, immunity from being flung.

### 7. Fun first, systems second

- The meta systems ported from Pillow Battles (levels, shops, dailies, tasks, codes) stay dormant until the
  prototype passes its gate.
- No progression goes on top of a loop nobody enjoys.
- Every roadmap phase ends at a playtest gate, not a date.

## Tie-breakers

When pillars pull against each other:

- **The victim's fun beats the flinger's.** Chain-flinging is funny once; immunity wins.
- **Simple beats deep.** If a mechanic needs explaining, cut it or make it a station.
- **Phone beats PC.** If it can't be done well on touch, it doesn't ship as a core verb.
- **Fun beats a system.** When in doubt, playtest before wiring more meta.

## Not making

- **A moveset fighter:** no character kits, no ability bars with ultimates, no combo trees.
- **A competitive or ranked game:** no ELO, no tournament balance.
- **A round-based game:** the park is always open. Timed events can run on top later, but nobody ever waits in a
  queue.
- **Pay-to-win** of any kind.
- **A long tutorial.**

## How to use this

- Check a feature against the pillars before building it. If it fights one, raise it with Redpillars first.
- A proposal for a new station, toy or verb says in one line how it serves pillars 1-3.
- The `docs/claude/` notes were harvested from Pillow Battles, a combat game. Where they assume movesets, M1 combos
  or a round loop, these principles win. The engineering rules there (server authority, choke points, save rules,
  sound parenting, ...) still apply.
