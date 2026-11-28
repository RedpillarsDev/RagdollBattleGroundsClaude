# Ragdoll Battlegrounds: Roadmap

**Status:** v1 draft, 2026-11-28. Each phase ends at a playtest **gate**, not a date (Redpillars: fun-first
prototype, no date). Redpillars decides when a gate has passed. The why behind every item: `docs/game/principles.md`.
Tick boxes as work lands, and log the details in `docs/worklog/`.

## Where we are (2026-11-28)

- [x] Foundation and meta ported from Pillow Battles: 25 services (data, leveling, shops, RNG, daily rewards, tasks,
  codes, leaderboards, admin, analytics, UI framework, ...) in the place. Whether they boot clean was not checked in a
  playtest this session.
- [x] Ragdoll Park map (Guts' sessions): stations, 4 outer zones, and hero rigs (pins, mousetrap, dartboard, punch
  machine, sharks, pteranodon) with break and animate contracts. All static, no scripts yet.
- [ ] No ragdoll, no player verbs, no station scripts, no round or session logic.
- **Blocker:** the park's hand-painted textures and Blender meshes are local files on Guts' PC. On every other PC the
  textures show as flat colours and the hero props are invisible.

## Phase 0: Ready to prototype

**Goal:** nothing blocks a multi-person playtest.

- [ ] Upload the park textures and import the hero meshes, so every machine sees the same park. *(Guts' call: his
  no-upload rule.)*
- [ ] Playtest the Pillow Battles port: clean console, and a list of which services stay dormant until Phase 3.
- [ ] Confirm the R6 rig (the park is sized for R6).
- [ ] Choose the building place (still open in `CLAUDE.md`).
- [ ] Ragdoll networking spike: who owns a flung body's physics, and how one fling looks on the flinger's, victim's
  and spectator's screens. Result goes in `docs/claude/combat-and-ragdoll.md`.

**Gate:** Redpillars and Guts join one server and see the same park.

## Phase 1: Fun-first prototype (next milestone)

**Goal:** 2-4 players have fun for 15 minutes in Ragdoll Park, with no meta at all.

Core:

- [ ] Ragdoll core: one server choke point for ragdoll and fling velocity, quick get-up, ragdoll immunity after getting
  up, a safety net for stuck or fallen-through bodies. *Reference impl: Pillow Battles (see
  `docs/claude/combat-and-ragdoll.md`).*
- [ ] Three player verbs. Proposal: **Shove** (short-range push that ragdolls), **Grab and Throw**, **Flop**
  (self-ragdoll / dive). Keyboard, touch and gamepad from day one.
- [ ] Respawn: per-area kill height, hazard deaths (lava and acid pits have the `Hazard` attribute; shark water),
  spawn protection, fast respawn.

First five stations, chosen because their rigs exist and they play differently:

- [ ] **Cannon** (`Cannon.Barrel`): climb in, get fired across the park.
- [ ] **Trampoline** (`Bounce` mat).
- [ ] **Hydraulic press** (`Press.Ram` + `PressButton`): a trap one player springs on another.
- [ ] **Punch machine** (`PunchSlide`, `PunchGlove`).
- [ ] **Bowling lane** (`Pin`): a player is the ball.

Feel:

- [ ] Fling feedback: impact sounds parented to parts, light camera shake, impact VFX, voice lines.
- [ ] A minimal HUD only. No meta UI.

**Gate (all must hold):**

- In a 15-minute session, players keep going back to the stations without being told to.
- Every session has laughing, clip-worthy moments (Redpillars' judgement).
- Nobody quits from being chain-flung.
- Flings look right from all three viewpoints and run well on a mid-range phone.

Then Redpillars calls it: on to Phase 2, or iterate.

## Phase 2: Deeper sandbox (still no money)

**Goal:** reasons to stay 20+ minutes and to come back.

- [ ] The remaining stations go live: rocket yard (rocket chair, `RocketLift`, giant fan `FanSpin` into the foam pit),
  rodeo (mechanical bull), shark pier (walk the plank), dartboard, mousetrap, tumble stairs, ski jump, dive tower,
  boxing ring.
- [ ] Animals with behaviour: sharks, pteranodon, bull (`LogicPoints/AnimalSpot`).
- [ ] Breakables break and respawn (`Break` welds).
- [ ] The first 2-3 holdable toys or throwables.
- [ ] Fling stats: distance, height, airtime, "best fling" callouts, fling-record leaderboards (LeaderboardService is
  ported).
- [ ] Server events every few minutes, an optional layer on the sandbox. Proposal: low gravity, giant fan, meteor
  shower, bouncy floor.
- [ ] Anti-grief pass with real players.

**Gate:** average session length reaches a target Redpillars sets, measured in friends tests.

## Phase 3: Meta and monetization

**Goal:** an earn, unlock, show-off loop that keeps to pillar 6 (earn the toys, buy the style). Most of the systems are
already ported and only need wiring.

- [ ] Currency earned from play: fling stats, challenges (TaskService), dailies.
- [ ] Toys and gadgets unlocked with earned currency.
- [ ] Cosmetic shop: trails, ragdoll effects, scream packs, emotes, skins. Gamepasses and dev products sell cosmetics
  and time-savers only.
- [ ] Leveling tied to play (LevelingService).
- [ ] Save template with `DataVersion` and `Repair`, separate dev and live keys (`docs/claude/data-and-saves.md`).
- [ ] Analytics funnels and custom events through the tracking module.
- [ ] Onboarding: contextual hints, no long tutorial.
- [ ] Shop and inventory screens (`ui-building` skill, then wiring).

**Gate:** the whole loop works end to end on dev keys, and nothing on sale breaks pillar 6.

## Phase 4: Public beta

- [ ] Performance pass on low-end phones; console pass.
- [ ] Exploit pass: every Client-to-Server packet validated and rate-limited.
- [ ] Admin and moderation tools, rank-checked on the server.
- [ ] Store page: icon, thumbnails, description.
- [ ] Live data keys separate; save layout reviewed before it freezes.
- [ ] Analytics dashboards ready to read beta data.

**Gate:** Redpillars' launch call.

## After beta: live ops

New stations and toys on a steady cadence, themed events, seasonal cosmetics, new parks or biomes, live tuning and A/B
tests through ConfigService.

## Open questions (Redpillars' calls)

1. **Health and KOs:** is there HP at all? Proposal: player hits only fling, and the only deaths come from hazards and
   the void. That fits pillars 1 and 4 and removes kill farming.
2. **Name:** on Roblox, "Battlegrounds" signals the moveset-fighter genre this game rules out. Keep it, or rename
   before beta?
3. **Verbs:** confirm Shove / Grab and Throw / Flop, or pick others.
4. **Server size:** proposal 16 players (the park has 16 spawns). Physics cost to be measured in the Phase 0 spike.
5. **Paid RNG for cosmetics** (RNGService and Rarities are ported): allowed, or direct purchase only?
6. **Building place:** still undecided.
