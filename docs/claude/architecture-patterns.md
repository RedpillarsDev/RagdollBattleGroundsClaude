# Architecture patterns

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Data/save design is in `data-and-saves.md`; library specifics in `libraries.md`; engine quirks in `roblox-gotchas.md`.

## Folder layout template

Service-oriented, ReplicatedStorage-centric, strict Client/Server split per module. PB's tree, generalised:

```
ReplicatedStorage
├── _GameConfig              -- one ModuleScript of global tunables
├── System
│   ├── Libs                 -- generic vendored/reusable libs (Signal, Promise, Replica, ByteNet, DataService, Base)
│   ├── Services             -- gameplay services (Server/Client split, see below)
│   ├── Classes              -- OOP classes (Player/, Lobby/, ...)
│   ├── Combat               -- client attack/ability entry points + configs
│   ├── Utils                -- small shared helpers (VFXUtils, Preloader, InventoryItems, ...)
│   └── Misc                 -- ChatCommands, Dev tools
├── Communication
│   ├── Networking           -- ByteNet packet namespaces (*Packets modules)
│   └── Signals/{Server,Client} -- same-side GoodSignal buses (never cross the network)
├── Data
│   ├── DataTemplates        -- PlayerDataTemplate (saved), NPDataTemplate (session), ClientNPDataTemplate (local)
│   └── DataLibrarys         -- catalogs: {[Id]: Record} + exported Id union type
├── Types                    -- type-only modules mirroring catalogs/templates
├── Storage                  -- SFX/, VFX/, Models/, Animations/
└── Design                   -- style tokens

ServerScriptService
├── ServerStart              -- the one server bootstrap Script
├── OnJoin                   -- server LifeCycle dispatcher Script
├── LifeCycle/{OnJoin,OnLeave,OnCharacterAdded,OnCharacterDied}/<Concern>  -- one ModuleScript per concern
└── ServerStartModules       -- PlayerDataInit, BytenetInit, ServicesInit, PacketsInit/<Namespace>

ServerStorage                -- never replicated: put anything clients must not read here
├── System/Main              -- round loop, death handler, session grants
├── System/Security          -- packet guards, RateLimiter
├── System/Data              -- DataMigration, DataTemplateHistory
└── Storage/Maps             -- map templates (cloned in by the map picker)

StarterPlayer
├── StarterPlayerScripts/OnJoin               -- client dispatcher, mirrors the server one
├── StarterPlayerScripts/LifeCycle/OnJoin/... -- client init modules (PlayerDataInit, BytenetInit, PacketsInit, ServicesInit, ...)
├── StarterPlayerScripts/Keybinds/            -- InputContext/InputAction assets
├── StarterPlayerScripts/UI/GameUI            -- UIController, ScreenUI class, per-screen init callbacks
└── StarterCharacterScripts/Animate           -- custom (not stock) Animate
```

- `DataLibrarys` is PB's (misspelt) name; it also has `ColisionGroups`, `KillReciepts`, `StatuseffectUtils`. Ported modules hard-code those paths, so either keep the names or fix every require when porting. Decide once.
- Assets that exist only in ServerStorage (e.g. map VFX) cannot be preloaded by the client.

## Service module pattern

```lua
local RunService = game:GetService("RunService")
local MyService = {}
if RunService:IsServer() then MyService.Server = require(script.Server) end
if RunService:IsClient() then MyService.Client = require(script.Client) end
return MyService
```

- Call sites use `MyService.Server.Foo(...)` / `MyService.Client.Foo(...)`. Follow the split even when one side is trivial: other modules `require(Services.X)` expecting this shape.
- Code needed by both sides goes in a `Shared` child (PB: `LeaderboardService.Shared`, `CombatService` Shared).
- Acceptable exceptions: a flat one-sided module (client-only music player, server-only data editor helper) or a flat module branching on RunService inside `Init()` (TagService). PB's nested `_Main.Server` variant (PermissionService) just adds confusion; don't copy it.
- Each side exposes `Init()`, called once from the side's `ServicesInit` in dependency order.
- **Requiring a module can install listeners.** Some modules hook Replica watchers or signals at require time; a require is not always a passive import. Keep that to self-registering modules that say so at the top.
- House conventions (PascalCase everything, section skeleton, `--[[NO YIELD// ]]`/`--[[CAN YIELD// ]]` annotations, `DevPrint` gated by `DevPrintsEnabled`) are in the root `CLAUDE.md`. New code logs through `DevPrint`, never bare `print`; PB did a release sweep to get a boot + round printing nothing from game code.

## Boot sequence pattern

One bootstrap Script per side calls init modules in a fixed order. Order is the contract.

**Server** (`ServerScriptService.ServerStart`):

1. Dev tools, collision group registration (before anything spawns parts that use a group).
2. `PlayerDataInit`: DataService (ProfileStore) + NPData (Replica). First, because services and packet handlers call `waitForData` / Replica lookups.
3. `BytenetInit`: requires packet-definition modules so namespaces exist (ids are assigned server-side as namespaces are defined).
4. `ServicesInit`: each service's `Server.Init()`, ordered by dependency. PB examples: Stats and Permission before StatusEffect; Leaderboard before receipt processing; Stats before anything that rebuilds Luck. Rule: init a service after everything it calls during its own Init.
5. `PacketsInit`: requires each `PacketsInit.<Namespace>` module, which attaches `.listen()` handlers.
6. Self-registering systems (attack resolver, death handler, out-of-bounds, NPC state setup).
7. Round loop **last**: its Init never returns (owns the intermission/round loop).

**Client** (`StarterPlayerScripts.OnJoin`), after `Players.LocalPlayer`:

1. Preload early pass on its own thread (`PreloadGame.StartEarly()`).
2. `PlayerDataInit`: init NPData, **wait for the local Replica**, then init the DataService mirror.
3. `BytenetInit` (client must require every namespace it will receive), `PacketsInit`, `KeybindsInit`, `ChatCommandsInit`, `ServicesInit`.
4. `GameUI.Init`, then lobby/world prompts (they call screen APIs, so UI first).
5. NPC humanoid state setup, ragdoll init, `PreloadGame.Finish()` (waits for the early pass).
6. Fire a local `ClientReady` BindableEvent (loading screen). It is local only, not a server message.

- Connect client `CharacterAdded` **before** the boot body runs, and backfill an existing character. A `BindCharacter` guard prevents double binding.
- Keybind init is not idempotent (session-scoped connections, no teardown): call once.
- Scratch/test Scripts (`ServerTestCaller`, `ClientTestCaller`) run outside the dispatcher and interleave with real boot output. Disable them for release.

Reference impl (Pillow Battles): `ServerScriptService.ServerStart`, `StarterPlayer.StarterPlayerScripts.OnJoin`

## LifeCycle dispatchers

`ServerScriptService.OnJoin` (a separate Script, not called by ServerStart) connects `PlayerAdded`, `CharacterAdded`, `Humanoid.Died`, `PlayerRemoving` and calls one ModuleScript per concern under `LifeCycle.<Event>`. The client mirrors it.

- **Existence is not wiring.** PB had LifeCycle modules that were never required by their dispatcher (dead code that looked live). The dispatcher must explicitly require each, or auto-require all children; pick one and document it.
- **Backfill.** PB's dispatcher had no catch-up loop for players/characters already present when it connected; systems that needed it (DataService, death handler) backfilled themselves. New dispatchers: connect, then loop `Players:GetPlayers()` and existing characters.
- **Order within an event matters.** E.g. making the character `Persistent` for streaming runs first in OnCharacterAdded (see `roblox-gotchas.md`).
- **Resolve `Player.Character` at callback time** in data-changed callbacks, never capture it at setup (stale after respawn).
- **Player-lifetime vs character-lifetime.** Per-player effects (passives, signal hooks) set up on join must not be re-applied every respawn, or listeners and Heartbeat work stack.
- Per-player signal groups: `PlayerSignalRegistry.New{"CharacterHit", ...}` builds a group per player, backfills, cleans up on PlayerRemoving; survives respawn, not rejoin; `Get` asserts if missing.

**Cleanup checklist** for any new listener/timer/effect: name its owner (player session, character, round, UI instance, single cast); keep the handle where removal must be reversible; weak tables are not cleanup; call the existing Destroy path and confirm the caller actually invokes it.

**Tag-driven setup (TagService pattern):** a tag-to-callback table per side; on Init, scan `CollectionService:GetTagged(Tag)` then connect `GetInstanceAddedSignal`. Connect added **and removed** before the initial scan, cache per instance to dedupe, and keep effect handles so removing a tag undoes it (PB's version did neither, so re-tagging stacked effects).

Reference impl (Pillow Battles): `ServerScriptService.OnJoin`, `ReplicatedStorage.System.Libs.PlayerSignalRegistry`, `ReplicatedStorage.System.Services.TagService`, `StarterPlayer.StarterPlayerScripts.Emitter2D` (tag-driven entity loader with Enabled attribute gating)

## Config module

- `ReplicatedStorage._GameConfig`: the single source of truth for tunables (economy, movement per area, round timers, combat scaling, hitbox debug flags, caps like max inventory). Add new tunables there, not as magic numbers in services.
- Dev toggles (a reward cooldown of 0, `DevPrintsEnabled = true`) are explicit settings that need a release decision. List them somewhere they will be reviewed before publish.
- Server cooldown guards derive from the same final-cooldown function the gameplay uses, never fixed seconds: Redpillars tests with cooldowns zeroed, so hardcoded server guards reject legitimate test casts.
- Mark hand-tuned numbers with a searchable tag (PB used `@TUNE`).

## Networking and server authority

**Transports, chosen by owner** (don't assume one universal path):

| Transport | Use |
| --- | --- |
| ByteNet namespaces (`Communication.Networking.*Packets`) | Typed gameplay/UI requests and server-to-client displays |
| Self-contained packet module inside a system (`Attack.AttackPackets`, `RbxPaymentService.Packets`) | A system that owns its own wire format; required directly by both halves |
| DataService Networker (plain RemoteEvent/RemoteFunction) | Saved-data replication only |
| Replica | Session state replication |
| Service-local remotes (VFX/Sound replicators) | Cosmetic relays |

Rules:

- **Player identity comes from the connection argument**, never a payload field.
- **Server picks outcomes; client only controls visual timing.** E.g. a spin result carries the winning index so the client animates to it. Display fields are separate from grant fields (a duplicate can *display* the rolled item while *granting* currency).
- **Client UI gating is UX only.** Admin/dev tools check rank on the server, through a single rank-checked entry packet. Never add a parallel unguarded remote.
- **Guard every client-to-server combat packet** (PB's CombatGuard). On a "started" packet, open a server-side window, then require: the packet names the sender's own live character; the player is eligible (in a round, or admin with a `DevMode` attribute); the permission is enabled and the server's own cooldown clock agrees (0.35s grace); the item is equipped and owned. Hit packets must land inside the window, once per victim, on a live target in the fight, within reach plus lag tolerance (20 studs). Sanitise client direction vectors. A new client-to-server ability packet without the guard calls is an open exploit.
- **Order matters in guards:** re-checking a permission *after* applying its cooldown rejects legitimate casts.
- **Cosmetic relays** (client asks server to replay a Sound/VFX to others) are a trust boundary: rate-limit per player, accept only authored assets under ReplicatedStorage parented on/near the sender, distance-limit map-wide relays.
- **Rate limiting:** a dependency-free token bucket per player per packet (e.g. 4/s, burst 6). Log rejections as `[Security] Rejected <name> (<id>): <reason>`, throttled to once per reason per 5s.

Reference impl (Pillow Battles): `ServerStorage.System.Security.CombatGuard`, `ServerStorage.System.Security.RateLimiter`

## Reusable core services (combat-agnostic semantics)

Worth porting for any battlegrounds game. Exact spellings matter in PB (`OutGoingDamageMultiplier`, `InComingKnockbackMultiplier`).

- **Stats:** `value = max(0, Base * (1 + Σ multiplier mods) + Σ flat mods)`. A multiplier of 0.25 means +25%; two of them give 1.5x, not 1.5625x. Modifiers are keyed by caller-supplied `ModifierId`: same id replaces, distinct ids stack; expiry checks identity so an old timer can't remove a newer modifier with the same id. Never remove another subsystem's id. Server computes; client reads the replicated value.
- **Permissions/cooldowns:** a permission is active when `Enabled` and no cooldown is running. Multiple simultaneous cooldowns; remaining = the **max**, not the sum. `Cancel` stops silently; `ForceEnd` fires the ended signal (cleanup listeners). Client `HasPermission` = local timer AND replicated server boolean.
- **Status effects:** active while any timer remains; `OnStart`/`OnEnd` fire on inactive/active transitions, not per stacked application. Optional `PersistOnDeath` (e.g. Ragdoll) survives death cleanup; character destruction clears all. Server state mirrors into the session Replica.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.StatsService`, `...PermissionService`, `...StatusEffectService`

## Change recipes

### Add a service
1. Folder ModuleScript in `System.Services` with `Server`/`Client` children (pattern above), `--!strict`, section skeleton, `DevPrint`.
2. Expose `Init()` per side; add it to that side's `ServicesInit` after everything it depends on.
3. Decide the state owner (saved / session Replica / local) before adding fields.
4. If it talks over the network, add a packet namespace (below), not ad-hoc RemoteEvents.

### Add a packet or namespace
1. Define in `Communication.Networking.<Name>Packets` with `ByteNet.defineNamespace` (self-registers on require).
2. Require it in `BytenetInit` on **both** sides. The client only learns a namespace's ids when it requires the module; an unrequired namespace means unknown-id errors.
3. Server listeners in `ServerStartModules.PacketsInit.<Name>`; client listeners in the client `PacketsInit.<Name>` (or self-registered inside the owning client module).
4. Change field types at both ends together. Compilation does not catch a writer/reader mismatch; it corrupts the rest of the buffer.
5. Identity from the connection; add guard + rate limiter for client-to-server packets.

### Add a catalog entry (weapon, ability, map, item)
1. Follow the catalog's existing record shape; add to **both** the `{[Id]: Record}` dictionary and the exported `Id` union type.
2. Put assets at the path the catalog references (models need the grip/Handle contract their equip code expects).
3. Add callback modules (`Callbacks.<Name>.Client/.Server`) with explicit cleanup ownership. A catalog entry does not register server behaviour by itself: trace client callback, packet, server listener, authoritative callback.
4. Register preload/VFX references where the pattern requires them; add shop/obtainment entries if it should be obtainable.
5. Maps: template in `ServerStorage.Storage.Maps`, catalog + union + weight, usable `SpawnPoints` BaseParts.

### Add a LifeCycle module
1. ModuleScript under `LifeCycle.<Event>` returning a function of `(Player)` or `(Character, Player)`.
2. Require and call it from the dispatcher (explicitly, unless the dispatcher auto-requires).
3. Make it safe for backfilled players; define its cleanup (OnLeave module or session-end callback).

### Add saved / session / local state
- Saved, new key: add to `PlayerDataTemplate` (Reconcile fills old saves). Existing key: the checklist in `data-and-saves.md`.
- Session: add to `NPDataTemplate`, write with `Replica:Set`, watch on the client.
- Local only: add to `ClientNPDataTemplate`.

## Verification discipline

- Re-read the live script right before editing; Redpillars edits Studio while agents work, so notes and earlier reads go stale.
- Never describe source-only reasoning as a passed runtime test. Say "unverified at runtime" when no playtest ran.
- Static risk observations describe code paths, not proven failures.
- Comments like `NO YIELD` are intent; trace the actual getter before trusting it.
- Studio/MCP testing techniques and their traps: `roblox-gotchas.md` ("Studio and MCP tooling").
