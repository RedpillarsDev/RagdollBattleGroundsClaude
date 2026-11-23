# Round loop and world

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Round state machine, registration, transitions, settlement, private arenas / 1v1, return-to-lobby, maps,
out-of-bounds kill heights, collision groups and pads.
Reference impl (Pillow Battles): `ServerStorage.System.Main.RoundSystem` (+ `MapPicker`).

## State machine

- **Owner:** `RoundSystem` owns `RegisteredPlayers`, `PlayersInRound`, `RoundPhase`, `RoundTimer`, `RoundActive`,
  `CurrentMapId`, registered map objects and the `RoundSettled` guard, all public on the module. Change round state
  through its helpers, never by flipping the replicated `Round.InRound` flag alone.
- **`Init()`** backfills current Players, connects join/leave, then enters an infinite loop. Call it **last** in boot
  (it never returns).
- **Cycle** (`RunOneRoundCycle`, each wrapped in `pcall`; on failure it attempts `EndRound` and waits before retrying):
  `Intermission` → `WaitingForPlayers` (only if nobody registered; yields until a registration) → `StartRound` →
  `EndRound` → repeat. The server's **first** cycle skips the Intermission.
- Every second the active phase sends `{Phase, TimeLeft}` to Clients (TopBar: "Intermission" / map name /
  "Waiting for players...", clock `-MM:SS-`).
- PB phase strings were `Intermission`, `WatingForPlayers` [sic], `InRound`, `""`. Pick clean names in the new game.
- **Admin Force End** = set `RoundTimer = 0` on a live round; the loop runs the normal `EndRound` (payout, winner,
  everyone to lobby). Reuse the real path instead of a parallel teardown.

## Registration

- **Registration window:** registering for the next round only works while `IsRegistrationOpen()`: the last
  `RoundRegistrationWindow` seconds of the Intermission (window kept as its own number from the Intermission length)
  plus all of Waiting.
- **Everyone re-registers every round** (`EndRound` empties `RegisteredPlayers`). Carrying it over pulled last round's
  Players straight into the next.
- **Queue box** (walk-in zone): outside the window it does nothing (no message). `Touched` only fires on entry, so a
  once-a-second `SweepQueueBoxes` registers anyone standing inside. Joining a *running* round on touch is allowed.
  Show "Registered!" only when it actually happened.
- **Auto Play** (opt-in, saved setting): once a second during the window, register every Player with it on through
  the normal `RegisterPlayerForRound`, so AFK/busy/tutorial refusals still apply. Turning it off removes only a queue
  Auto Play made.
- **Busy Players** (opening a crate, spinning a wheel) are refused by registration and `SetPlayerInRound`; a 30s safety
  timeout clears a stuck busy flag. The Server also marks busy when it accepts the busy-making request.
- **Join lock at round start** (`RoundJoinLockTime` 3s): blocks mid-round joins while the starters land. Turned off by
  a `task.delay` **guarded by a token** (an older round's timer can't open a newer round's lock), and also at FIGHT and in
  `EndRound`.

## Round transitions

- **`MoveBehindTransition(Player, Move)`**: send the wipe packet, move the character `SlideTime + 0.15s` later while the
  screen is covered (wipe = 0.5 in + 2 hold + 0.5 out). Plays on round entry, round exit, tutorial exit; not on first
  lobby spawn or death respawns.
- The Client anchors **its own** root for the wipe (no walking/falling); a Client-side `Anchored` doesn't replicate, so
  the Server's teleport still lands.
  - **Only undo your own write.** If the root was already anchored (by a Server hold), leave it alone, release included.
    PB restored the captured `true` after a thaw had landed mid-wipe; the Client write stuck and the Player stayed
    frozen in the lobby forever. A Client write sticks until the Server next changes that property.
- **An anchored root still takes input**, so the walk animation plays in place. Freeze guards also switch the
  PlayerModule controls off and zero `Humanoid:Move` / `Jump`.
- The wipe Frame is moved into its own ScreenGui (`DisplayOrder` 1000, `ScreenInsets.None`) so nothing draws over it.
- Pre-FIGHT countdown holds everyone; starters are spawn protected through it.
  Reference impl (Pillow Battles): `StarterPlayerScripts.UI.GameUI.Systems.ScreenTransition`, `...Systems.RoundCountdown`.

## EndRound and settlement

- **Order matters:** take Players out **before** cleaning the map, then wait out the slide before deleting it
  (otherwise exiting Players fall through the vanished map for a second).
- Iterate over `table.clone(PlayersInRound)`: `SetPlayerOutOfRound` does `table.remove`, and mutating while iterating
  skipped Players (left stuck "in round").
- **`RoundSettled` is set BEFORE payouts** so a cleanup retry can't pay twice. It isn't a transaction: a failure mid
  payout is not retried.
- **Winner:** highest positive `RoundKills`; ties go to the earlier `LastKillTimeStamp`.
- A `RoundSettling` signal fires once at the top of the settle block so round-scoped systems (bounties) pay out before
  the winner screen.
- Heal everyone to full **after** the exit transition moved them (a last hit / DoT tick on the map can't undo it);
  skip dead characters (respawn comes back full).
- Registered map objects (spawned hazards, projectiles) are destroyed with per-object protection. **Every round-scoped
  object needs a cleanup owner**, and its `Destroy` must be idempotent.
- `PlayerRemoving` must dequeue/unregister too (PB once had an empty stub there).

## Return to Lobby (channeled)

Pressing it starts a 3s channel: refused out of round / ragdolled / already returning / on cooldown. Combat
permissions off, the Client freezes movement off a server-time `ReturnToLobbyEndsAt` attribute, a billboard over the
head shows everyone. A real hit (`ConnectCancellingDamage`) or a ragdoll interrupts it → 10s cooldown. Finishing returns
and dequeues → 30s cooldown (the first return has none). Death / leaving / round end just stop it. Cooldown =
`ReturnToLobbyReadyAt` attribute the button counts down. In an arena with a `Forfeit` hook, finishing forfeits.
Reference impl (Pillow Battles): `ServerStorage.System.Main.ReturnToLobbyChannel`.

## Private rounds: `RoundSystem.Arenas`

A leaf registry for rounds beside the live round (tutorial round, 1v1 matches): `Register / Unregister / Get(Id) /
OfPlayer / IsInArena / UnregisterPlayer / GetAll`. An arena object carries `Id, Player | Players, Map` and hooks:
`BroadcastLeaderBoard()`, `SendKillFeed(Data)`, optional `CountsAsLiveRound`, `GetEXPMultiplier(Player, Event)`,
`Forfeit(Player)`, `AllowsMapEvents`, `RegisterMapObject`.
- **Every live-round broadcast skips arena Players** (`SendToLivePlayers`, a per-Player send loop), or it overwrites
  their private TopBar / board / winner screen. Applies to the kill feed too.
- NPC records with an `ArenaId` live in the arena's list; live-round helpers stay live-only; id lookups search all.
- Arena maps are cloned into their own container at `SlotOrigin + Slot * Spacing` (PB: 1000-stud spacing, same Y as
  the live map so fall depths match), streamed `PersistentPerPlayer`.
- Spawn allocation leaves arena Players alone; the arena places its own respawns.
- `CountsAsLiveRound` decides whether stats/EXP/leaderboards count. Registration and `SetPlayerInRound` refuse arena
  Players and anyone standing on a 1v1 pad.

### 1v1 on top of Arenas (PB pattern)
- **Lobby pads:** walking onto a pad (CanTouch walls with `CanCollide = false`, plus the pad parts) stands the Player
  on its centre, **Root anchored on the Server**, facing the other pad; Client controls off so no walk animation.
  Wall parts must be **Anchored** (unanchored ones fell and re-captured Players). A 2s re-entry cooldown after leaving.
- An Exit button (shown off a `Can1V1Leave` attribute) works until a second Player steps on; a VS-BOT button
  (`Can1V1Bot`) starts a bot match. Both set from one `RefreshPadOffers`.
- Start `StartDelay` (2s) after the second Player lands; guard double-starts with a `Starting` flag set before spawning
  the match (a forged second press is refused).
- Match: `Fighters` = Player or bot participant record, so kills/winner/board read one list and the bot can win.
  Most kills at time wins; tie at 0 = sudden death (speed boost, next kill wins). Leaving / return-to-lobby = forfeit.
- Spawns: the two SpawnPoints furthest apart, facing each other; every respawn at the one furthest from the opponent.
- Level gate (`RequiredLevel`) checked on the Server at pad touch, refusal notification rate-limited.
- **Packet field gotcha:** a "hide board" packet missing new struct fields threw in ByteNet mid-exit, leaving the
  Player on the map. Send every field; book cleanup first and `pcall` each exit step.
- Reference impl (Pillow Battles): `ServerStorage.System.Main.OneVOne`, config `ReplicatedStorage._1V1Config`.

## Maps

- **Catalog + template:** `DataLibrarys.Maps` (`{[MapId]: {MapModel, RollWeight, ...}}` + `MapId` union); templates in
  `ServerStorage.Storage.Maps` (split `Regular` / `Other` (tutorial) / `1V1`). Adding a map = Model in the right folder
  **and** a catalog entry.
- **`ConstructMap`:** clone, set streaming `Persistent`, `PivotTo(MapAnchor.CFrame)`, parent to
  `workspace.InGame.CurrentMap`, run the map's init callback, hide spawn markers (`HideSpawnPoints`: parts under
  `SpawnPoints` and SpawnLocations go transparent, decals/GUIs off; authored copies stay visible for editing), mark
  the kill height.
- A map needs a `SpawnPoints` folder of BaseParts, and a sensible **pivot** (one map's pivot was 800 studs under its
  floor).
- **A missing map Model killed the whole boot:** the catalog hard-indexed `MapModels.<Name>`, so requiring it errored
  and took down the round system, the join handler (no spawn allocation: Players fell from the origin forever) and the
  server boot chain (Clients then logged a ByteNet "attempt to index nil with 'read'"). **Check the first console
  error**, and make the catalog tolerate a missing Model (warn and skip).
- First-map pool for a fresh server (`FirstRoundMapPool`), skipping bad ids with a warning; later rounds pick from all
  by `RollWeight`. `GetClearSpawnCFrameOnMap(Map, Clearance?)` finds an unobstructed spawn.
- **Floor raycasts include every round-map container** (`Utils.RoundMaps.NewFloorParams()` = live map + arenas +
  tutorial rounds; `GetMapAt(Position)` by footprint). Including only the live map made every aim ray on a 1v1 map fall
  back to "straight down". Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.RoundMaps`.

## Out of bounds / kill height

- **Ring-outs are the kill.** The handler sweeps every 0.2s and sets `Humanoid.Health = 0` directly (bypassing the
  damage floor); the death is credited to `LastAttacker` like any kill. Hold-frozen bodies are exempt. NPC bodies are
  checked too.
- **Kill height per area** (Redpillars: "they should only be able to fall 100 studs"): each area's kill height =
  `FallDepth` (100) under its lowest spawn marker. The Server marks the area's own Instance with an `OutOfBoundsArea`
  tag + `KillHeight` / `AreaMin` / `AreaMax` attributes (runtime only), so Server and Clients read the same values.
  Marked at build time: the live map, arena copies, the Lobby.
  - **A body takes the nearest area's height** (flat distance to footprint), but any other area within 100 studs also
    counts and the **lowest** wins. Otherwise a Player knocked 20 studs off a low map toward the higher Lobby died in
    mid-air.
  - A global `OutOfBoundsHeight` is only the fallback when nothing is marked. A map with no SpawnPoints gets no height
    (warned) and takes its neighbours'.
  - Expect up to ~30 studs of overshoot from the 0.2s sweep (and ~160 studs per sweep at 800 studs/s).
  - Keep `Workspace.FallenPartsDestroyHeight` at least ~300 studs below the lowest kill height, or the engine deletes
    a fast body before the handler kills it (no credit). PB's `MarkArea` warns.
  - Never read the global height directly: call `OutOfBounds.IsOutOfBounds` / `GetKillHeight`.
- **Lobby proximity kill:** an in-round body within `LobbyKillDistance` (15) of the Lobby footprint (flat, any height)
  dies, so knockback can't land anyone in the Lobby. **Armed only after 1s seen away from the Lobby**, because the
  in-round flag is set while the Player still stands in the Lobby before the transition moves them.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.OutOfBounds` + `OutOfBoundsHandler`.

## Collision groups

- `Players` never collides with `NoPlayerCollide` (projectiles, debris, hazards roll through bodies).
- **Group every character, every respawn:** `CharacterAdded` + `DescendantAdded` + a backfill of Players already joined.
  PB grouped only the first character's initial parts, so respawned bodies were Default and collided with everything.
- A tag handler that only recolours parts tagged at boot misses spawned objects: **spawned objects set
  `CollisionGroup = "NoPlayerCollide"` on their own parts.**
- Wall checks for gameplay (projectile/grab line of sight) use the `Players` group + `RespectCanCollide`, so
  NoPlayerCollide parts don't count as walls.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Misc.ColisionGroups` [sic].

## Pads

**Jump pads** (Client tag `JumpPadHitBox`): touching launches the LocalPlayer along the Part's `UpVector` (tilted pad =
diagonal), **replacing** velocity along that axis and keeping the rest. Client-side on purpose: per-Player cooldown and
emitter state. Bounce sound replicated so others hear it. Batch constants (`LAUNCH_VELOCITY`, `COOLDOWN`) at the top
of the module; per-pad optional emitter that is on while ready. (PB observed Instance-type attributes reading back as a
handle needing `:Get()`, pcall'd: verify on the current engine.)

**Heal pads** (tag the pad's `HitBox`): one config module for all pads. **Server** heals and owns a **shared** cooldown
(used = used for everyone), publishes `HealPadReady` on the HitBox, skips full-health Players, and on coming back heals
anyone still standing on it with a `GetPartsInPart` sweep (Touched only fires on new contact). **Client** is visual only
(spins/hides the cross off the attribute). Clones keep their tag, so pads inside maps wire themselves when the map loads.

Debug tooling (hitbox transparency) must skip pad hitboxes even if they're named `HitBox`.
