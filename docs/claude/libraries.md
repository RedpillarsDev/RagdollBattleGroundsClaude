# Libraries

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

PB kept generic libraries under `ReplicatedStorage.System.Libs`. Vendor internals (ProfileStore, Replica, EmitModule) were never fully audited there; notes below are usage contracts and measured behaviour.

## Signal (GoodSignal)

- stravant's "Batched Yield-Safe Signal" (MIT), unmodified. `Connect`, `Fire`, `Wait`, `Once`, `DisconnectAll`.
- In-process only: same-side pub/sub buses (`Communication.Signals.Server/Client`). Never a substitute for a remote.
- Fires handlers immediately on `Fire` in a reused coroutine, so it is **not** affected by the place's Deferred `SignalBehavior` (library design, not measured in PB). Useful when you need same-frame ordering that engine events no longer give.
- For per-player buses use `PlayerSignalRegistry` (below) rather than a flat table of Signals.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.RedpillarsSignal` (GoodSignal)

## PlayerSignalRegistry

- `Registry = PlayerSignalRegistry.New{"CharacterHit", "CharacterKilled", "SelfGotHit"}` creates a named signal group per player.
- Self-registers on `PlayerAdded`, backfills players already present at construction, cleans up on `PlayerRemoving`.
- A group survives respawns but not a rejoin, so a reference captured at equip time stays valid for the session.
- `Registry.Get(Player)` **asserts** on a missing entry; it does not lazily create one.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.PlayerSignalRegistry`

## Promise

- evaera's `roblox-lua-promise` v4.0.0, forked (not Wally) with hand-added Luau types. Marked `--!nonstrict` on purpose: the one exception to the `--!strict` rule.
- `Promise.delay(t)` is **not** a `wait()` wrapper; it runs its own Heartbeat-driven scheduler.
- House pattern: `Promise.delay(t):andThenCall(Fn, ...)`.
- Keep the returned Promise when the timer can outlive its owner (character, screen, round) and `:cancel()` it on cleanup. Cancellation propagates down the chain; an uncancelled delay fires on a destroyed character.
- Promise expiry precision is not display precision: PB's timer classes kept remaining-time bookkeeping with `os.time()` (whole seconds) in some places and `os.clock()` in others. Check which before showing sub-second countdowns.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.Promise`

## ProfileStore

Wrapped by DataService; game code never touches it directly.

- Session-locked profiles. PlayerRemoving ends the session; a forced session loss (another server took the lock) kicks the player.
- `profile:Reconcile()` adds missing template keys (nested) with defaults and never rewrites existing values. Full semantics and the migrate-before-Reconcile rule: `data-and-saves.md`.
- `OnSave` / `OnAfterSave` hooks let you save a different table than the live one (PB strips session-only items this way, then restores the live table).
- Ending a session after a refused migration releases the lock and leaves stored data unchanged (verified deep-equal).
- To simulate Reconcile in Edit-mode tests, copy ProfileStore's `ReconcileTable` verbatim and run it against the live template.

## DataService (persistent data wrapper)

Modules: `ProfileStore`, `Data`, `Networker`, `DataServiceServer`, `DataServiceClient`, `DataServiceUtils`.

- `Data` is a small path-based get/set class with per-path `changed` / `indexChanged` / `arrayInserted` / `arrayRemoved` signals, cached in weak tables so unused signals are GC'd.
- `DataServiceUtils.enums.actions` (`set` / `arrayInsert` / `arrayRemove` / `init`) double as the Networker message keys the client dispatches on.
- **Networker is a bespoke RemoteEvent/RemoteFunction wrapper, not ByteNet.** It creates ordinary remotes under its `_remotes` hierarchy keyed by network tag; server `addClientAccess` exposes methods through a lookup; `SET_TAG` has its own replicated-property path. (PB's root `CLAUDE.md` once claimed it was built on ByteNet; two source-verified passes say it is not. Trust the source.)
- **Client `set` / `update` / `arrayInsert` / `arrayRemove` are local-mirror-only** (no remote fires, verified). Anything that should persist needs a server-validated request packet.
- Options seen on `server:init`: `profileStoreIndex`, `resetData`, `viewedUserId`, `migrate`. `resetData` calls `RemoveAsync` before load: see the footgun section in `data-and-saves.md`.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.DataService`

## Replica (`ReplicaServer` / `ReplicaClient` / `ReplicaShared`)

- Server-authoritative replicated tables. PB uses one Replica per player (token `"NPPlayerData"`) `:Replicate()`d to everyone; selective `:Subscribe()` exists but wasn't used.
- Mutate with `Replica:Set(Path, Value)`; clients watch with `OnSet` / `OnChange`.
- **Handlers run on a sandboxed thread** (the Replica modules have `Sandboxed = true`). Requiring a non-sandboxed module from a handler fails with "cannot require ... the calling thread is sandboxed". Everything else measured fine from inside a handler, including `BindToRenderStep`.
  - Fix: build anything that needs a `require` (UI effects, VFX objects) **up front**, and only toggle it (Enabled, Pause/Resume) in the handler. Any library that lazily requires presets on construction (EasyVisuals) cannot be constructed in a handler.
- Destroy the player's Replica on PlayerRemoving; callers that might outlive the player use a non-yielding lookup.
- The library prints its own one-line init message; that's the only output a clean release boot had.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.Replica`

## ByteNet (typed gameplay packets)

- `ByteNet.defineNamespace(Name, function() return { Packet = ByteNet.definePacket({ value = ByteNet.struct({...}) }) } end)`. Types used in PB include `uint8`, `int16`, `vec3`, `cframe`, `struct`, `array`, string/bool types. `Packet.listen(function(Data, Player) ... end)` on the server gets `Player` from the connection. (Call shape per upstream ByteNet; confirm against the vendored copy.)
- **Self-registers on require.** Packet-definition modules have no `Init()`; the namespace body runs at require time. Keep require-time registration (`BytenetInit`) separate from listener attachment (`PacketsInit`).
- **Ids:** the server numbers every packet as namespaces are defined (PB: 1-86 across 14 namespaces) and replicates each namespace's ids as JSON in a StringValue under `ReplicatedStorage.BytenetStorage`. **The client learns a namespace's ids only when it requires that module itself.**
- **Writer/reader mismatch corrupts the stream.** If one side's packet layout disagrees with the other, the reader loses its place and reads a data byte as the next packet id. Symptom: `process.read:40: attempt to index nil with 'reader'`, repeated. Compilation does not catch it; change both ends together.
- PB patched `process.read` to `warn` instead of error: `[ByteNet] unknown packet id N at byte X of Y: ...`, naming the server-side `Namespace.Packet` if the id exists or saying the read lost its place. It still stops reading that buffer. Port the patched copy to keep this diagnostic.
- `execute_luau` gets its own empty copy of `packetIDs`; check client id tables from a LocalScript in Play.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.ByteNet` (with the patched `process.read`)

## RateLimiter

- Dependency-free per-player token bucket (e.g. 4/s, burst 6 on a profile-inspect request). Used on the Sound/VFX relays and request packets.
- Logs every rejection as `[Security] Rejected <name> (<id>): <reason>`, at most once per reason every 5s, so spam can't flood output.

Reference impl (Pillow Battles): `ServerStorage.System.Security.RateLimiter`

## Preloader

- Entry points: `PreloadFull`, `PreloadTag`, `PreloadDescendants`, plus `PreloadUI` and `PreloadVFX`. Traverses catalog asset references and tables with visited-table tracking, so only assets reachable from catalogs/folders preload.
- Two-pass client pattern: `PreloadGame.StartEarly()` first thing in client boot (UI from StarterGui + ReplicatedFirst: images, meshes, fonts via text classes in `PreloadableInstances`; VFX from `Storage.VFX` plus every emitter/Beam/Trail in ReplicatedStorage and Workspace) on its own thread; `PreloadGame.Finish()` last (all of ReplicatedStorage, the player, character, catalogs), waits for the early pass, then `ClientReady` fires.
- Measured: 373 UI instances in 4.7s, 235 VFX in 0.4s. UI is the slow part.
- ServerStorage-only assets can't be preloaded by the client.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.Preloader` and the client OnJoin `PreloadGame` module

## Base utility libs

- `DictionaryLib.DeepCopy` (seeds local state from templates), `DictionaryLib.PathResolve` (walks a dotted-path array the same way DataService/Replica paths do).
- `RNGLib.Roll`: weighted cumulative-sum picker. Weights are explicit per entry; rarity names are not a weight table.
- `MathLib.Bezier.Quadratic/Cubic`. `ArrayLib` is an empty stub. `StringLib` exists.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.Base`

## EasyVisuals (animated UI gradients)

- `EasyVisuals.new(GuiObject, PresetName, Speed?, Size?)` validates the target is a GuiObject and the preset is a ModuleScript. Built-in presets: `Gold`, `Rainbow`, `RainbowStroke` (no `Golden`).
- **No per-Gui dedupe:** repeated calls stack effects. Cleanup only on AncestryChanged out of the game, not on tag removal. Keep the handle (`Pause` / `Resume` / `Destroy`).
- For an **existing UIStroke**: `EasyVisuals.Gradient.new(Target, ColorSequence, Transparency)` (Target GuiObject or UIStroke; numeric transparency becomes a constant NumberSequence) then `Gradient:SetOffsetSpeed(Speed, Acceleration)`. Speed 1 = one colour cycle per second; acceleration is a 0-1 ramp factor, not instant (0 never reaches the target).
- `Stroke.new` creates/reuses a **child** UIStroke under its argument; it does not wrap a passed UIStroke.
- Constructs require presets lazily: do not call from a Replica handler (sandboxed).

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.EasyVisuals`

## Smaller notes

- **ColorLib.RGBStreamClass:** one Heartbeat drives `Color3.fromHSV(tick()*Speed % 1, 1, 1)`. `AddPropertyToColor(Instance, PropertyName)` stores targets **by property name**, so a second instance for the same property silently replaces the first; an empty property name errors every frame. No per-registration removal. Fix before porting.
- **EmitModule** (VFX emitter lib) is large; VFX sequence modules require it directly. A sequence registry required by the VFX service must never require that service back (recursive require).
- **Custom prompt classes** (PB built its own client-side ProximityPrompt-like `PromptClass`) are a project choice, not evidence that engine ProximityPrompt events are client-only.
