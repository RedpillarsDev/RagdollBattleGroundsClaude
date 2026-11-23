# Data and saves

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Library-level details (ProfileStore, Replica, Networker) are in `libraries.md`. Engine-level DataStore quirks are in `roblox-gotchas.md`.

## Pick the state owner first

Three separate systems. Most data bugs in Pillow Battles came from putting state in the wrong one or confusing them.

| Data | Owner | Client side |
| --- | --- | --- |
| Saved: inventory, equipped, currency, purchases, settings, progression, receipts log | `DataService.server` over ProfileStore | Server writes push into a `DataService.client` mirror |
| Session, replicated: round flags, stats, permissions, status effects, queue/AFK flags | `NPDataService.Server`, one Replica per player | Read the Replica, subscribe to paths |
| Local only: key presses, combo index, "is walking" | `NPDataService.Client.ClientNPData` (deep copy of a template) | Never replicated anywhere |

- Templates: `ReplicatedStorage.Data.DataTemplates.{PlayerDataTemplate, NPDataTemplate, ClientNPDataTemplate}`.
- Modifier-derived values (speed, damage multipliers) belong to a stats service, not a second hand-written value. Round lists/phase belong to the round system, not just a Replica flag.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.DataService`
Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.NPDataService`

## Persistent data: DataService over ProfileStore

Server API (paths are arrays, e.g. `{"Equipped","CurrentWeapon"}`):

- `server:get(Player, Path)`, `set(Player, Path, Value, DontReplicate?)`, `update(Player, Path, Callback, DontReplicate?)`
- `server:arrayInsert(Player, Path, Value, Index?, DontReplicate?)`, `arrayRemove(Player, Path, Index, DontReplicate?)`
- `server:getChangedSignal(Player, Path)`; `server:waitForData(Player)` yields (init backfills players already present)
- `server:addPlayerRemovingCallback(Callback)` runs before the profile session ends: last chance to write
- Client mirror omits `Player`. `client:fetch(Path, DontSet?)` asks the server for the current value.

Rules:

- **Client `set/update/arrayInsert/arrayRemove` only touch the local mirror.** No remote fires. Anything that must persist goes through a validated request packet; the server writes. Use client writes only for optimistic UI.
- **Templates must be JSON-safe.** No Instance, Model, Vector3, CFrame, Color3. Store numbers/strings/bools/tables.
- **Removing a dictionary key:** don't rely on a `nil` write replicating cleanly; rebuild and set the parent table (PB did this for a named-source dictionary).
- **Changing a template default only affects new profiles.** Existing players keep their saved value. Say so whenever you change one.
- ProfileStore owns session lifetime: PlayerRemoving ends the session; a forced session loss (another server took the lock) kicks.
- Data-dependent UI must wait for the client data gates (Replica + DataService mirror) before starting.

## Reconcile semantics (ProfileStore)

- `profile:Reconcile()` adds every template key missing from the save, nested too, with the template default.
- It **never rewrites an existing value**. A key whose type changed in the template keeps its **old** type in old saves. This is why "just change the template" is unsafe for existing keys.
- It fills a missing `DataVersion` with the template's current number, which would make every old save look upgraded. **Migration must run before Reconcile.**
- Verified on 6 real old saves: Reconcile only added keys, changed no value, found no type mismatch. JSON `[]` for an empty dictionary decodes to `{}`, which is fine.
- **Adding a brand new key needs no migration.** Reconcile handles it.

## The frozen-layout rule (applies from first public release)

Once real players have saves:

- **Never change an existing saved key:** no rename, remove, move, re-nest; no change of type (number to table, array to dictionary) or meaning (seconds to minutes, Id to UniqueId).
- **New keys are fine** (Reconcile).
- **DataStores are frozen too:** the ProfileStore index/store name, leaderboard store names, any key format (day keys, audit logs). Renaming the live index starts every player from zero.
- **An existing key changes only through the data version system below.**

## Data version system

Design, all server-side except the live template:

- `PlayerDataTemplate.DataVersion`: the current layout number. In PB a save without the key counted as V1 (the system was added after launch).
- `ServerStorage.System.Data.DataMigration` (server-only, never replicated):
  - `Migrate(Data)` works on a **deep copy**: runs every `Steps.V<n>` the save is missing, then `Repair`. Returns `"Ok"`, `"Failed"` or `"TooNew"`.
  - `Steps.V<n>` takes a save from V`n-1` to V`n`. **A shipped step is frozen**, never edited.
  - `Repair` runs on **every** load. Re-checks the current layout's invariants and mends what it can, which also fixes anything an out-of-date server wrote into an already-upgraded save. Must be **idempotent** and must **never delete owned items**. Update it whenever the layout changes.
- **Hook:** the DataService wrapper calls `options.migrate` after the session starts and **before** `profile:Reconcile()`.
  - `"Ok"`: `Profile.Data` is replaced by the upgraded copy, then Reconcile.
  - `"Failed"`: end the session with the save **untouched** (only the copy was modified) and kick ("Your data is being updated. Please rejoin!"), warn with the error.
  - `"TooNew"`: save is newer than this server's code (an old server after a publish). End session untouched, kick with "This server is out of date...".
- **Lesson for a new project:** the `TooNew` check only protects saves from the version where it first shipped. PB added it at V2, so V1-era servers could not refuse V2 saves. **Ship `DataVersion = 1`, the migrate hook, `TooNew` and an empty `Repair` in the very first release.**

Sketch of the shape (not a copy of PB's module):

```lua
--!strict
local DataMigration = {}
local CURRENT: number = PlayerDataTemplate.DataVersion

DataMigration.Steps = {} :: {[number]: (Data: any) -> ()} -- [2] = V1 -> V2, FROZEN once shipped

function DataMigration.Repair(Data: any) end -- every load; idempotent; never deletes owned items

function DataMigration.Migrate(Saved: any): ("Ok" | "Failed" | "TooNew", any?)
	local Version = Saved.DataVersion or 1
	if type(Version) ~= "number" then return "Failed", "unreadable DataVersion" end
	if Version > CURRENT then return "TooNew", nil end
	local Data = DeepCopy(Saved)
	local Ok, Err = pcall(function()
		for V = Version + 1, CURRENT do
			DataMigration.Steps[V](Data)
			Data.DataVersion = V
		end
		DataMigration.Repair(Data)
	end)
	if not Ok then return "Failed", Err end
	return "Ok", Data
end
```

Reference impl (Pillow Battles): `ServerStorage.System.Data.DataMigration`
Reference impl (Pillow Battles): `ServerScriptService.ServerStartModules.PlayerDataInit` (`MigrateProfile`, the `migrate` option)

### Changing an existing key: the checklist (in this order, every time)

1. **Snapshot the template as it is now**, frozen, in both places: Studio `ServerStorage.System.Data.DataTemplateHistory.PlayerDataTemplate_V<current>` (server-only) and repo `docs/data-templates/PlayerDataTemplate_V<current>.lua`, plus a row in `docs/data-templates/README.md`. Never edit a snapshot afterwards.
2. Change `PlayerDataTemplate` and bump `DataVersion` by one.
3. Add `DataMigration.Steps.V<new>`. Never edit a shipped step.
4. Update `Repair` (and any item-entry normaliser).
5. Test:
   - Edit-mode unit tests on hand-built old saves. Load a fresh module copy with `require(Module:Clone())`. Compare with a deep-equal, **never `JSONEncode` strings** (key order differs between equal tables).
   - Cases worth covering: duplicates, garbage entries dropped / fields filled, a current-version save with an old-server-style entry (Repair), `TooNew`, an unreadable version, the current template as a no-op, idempotence (second run is a no-op), and a **control** that proves a check can fail.
   - Migrate copies of real saves read via raw `DataStore:GetAsync`, read-only. Simulate Reconcile with a verbatim copy of ProfileStore's `ReconcileTable` against the live template. Assert the source table was not mutated.
   - Real join in a playtest. Test a refusal too: write a too-new version with `UpdateAsync` (pass UserIds and metadata through), join, confirm kick, data deep-equal to before, session lock released; restore the same way.
6. Publish with **Migrate To Latest Update** (or shut down servers). Old servers keep running old code; a new-layout save loaded there can come back half-old. `Repair` mends it on the next load, but migrating servers avoids it.

### Template history README format

```
| Version | File | In use | What changed going to the next version |
|---|---|---|---|
| V1 | `PlayerDataTemplate_V1.lua` | until <date> | V2: <summary>. Step: `DataMigration.Steps.V2` |
| V2 | (live template) | from <date> | - |
```

## Dev vs live store keys

- `PlayerDataInit` picks the ProfileStore index off `RunService:IsStudio()`: one key for Studio, one for live. Studio playtests with API access write to the **real** DataStores of that experience, so the split key is what keeps test junk out of player saves.
- PB's global leaderboards used the same two strings as an environment suffix. Switching them once started every board (and the name store) empty: decide both together.
- **Pick the live key once and freeze it at first release.** PB changed it several times pre-release (each change orphaned every save in the old store); an old save in an abandoned store is simply never loaded, so "it passes migration" means nothing for it.
- DataStores are per experience (universe). A separate testing experience never sees live players' saves; to test on real saves, export copies.

Sketch (option names as in PB's wrapper; verify):

```lua
local IsStudio = RunService:IsStudio()
local Options = {
	profileStoreIndex = if IsStudio then "<StudioKey>" else "<LiveKey>", -- frozen after release
	resetData = false, -- MUST stay false outside Studio
	migrate = PlayerDataInit.MigrateProfile,
}
assert(not (Options.resetData and not IsStudio), "resetData is Studio-only") -- recommended hard guard, PB lacked it
```

## The `resetData` footgun

- What it does: in `DataServiceServer._playerAdded`, `if options.resetData and not options.viewedUserId then playerStore:RemoveAsync(index) end` runs **before** the profile loads. Only `viewedUserId` guards it.
- **It was once found `true` in PB's live branch** (directly under a `--MUST STAY false` comment). As written, every player's profile would be deleted on every join: inventory, currency, purchases, the receipt idempotency log. Caught in source before it mattered.
- The flag was toggled in both branches more than once. **Read `PlayerDataInit` before reasoning about whether test data persisted**; an empty inventory in Studio is not automatically a bug.
- Never use `resetData` on the live store as a migration shortcut.
- Add the assert above so a live `resetData = true` fails loudly at boot instead of wiping saves.

## Owned items as copies (pattern from PB's V2 layout)

Worth adopting up front for weapons/abilities/cosmetics so you never need the V1 to V2 migration PB had to write.

- **Each owned copy is an entry** `{Id, UniqueId, Level, EXP}` (UniqueId = GUID). Always made by a factory `InventoryItems.New(Id)`, never a hand-written table.
- **Equipped slots are pointers** `{Id, UniqueId}`, never a copy. Read through `ResolvePointer(List, Pointer)`, write with `PointerTo`. A pointer at an unowned copy resolves to nil: treat as defaults (Level 1).
- **Store EXP as progress toward the next level**, not EXP remaining: the level curve can be rebalanced without touching saves.
- **One "can they get another copy" rule** (`CanAddCopy`) used by every grant path (shop, drops, rewards, admin). Caps live in config (`MaxItemCopies`, `MaxInventoryItems`).
- **Equip requests carry the UniqueId**; the server resolves the copy, writes only the pointer. A bogus UniqueId changes nothing.
- UI showing one card per catalog Id is a different identity from a saved copy; don't confuse the two.
- Code that only reads `Equipped.X.Id` keeps working when slots become pointers.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.InventoryItems`

## Session-only items (never saved)

- Grant as ordinary inventory entries flagged `Session = true`.
- Before **every** save (ProfileStore `OnSave`), point `profile.Data` at a stripped deep copy (no session entries; an equipped session item re-pointed at a real copy); restore the live table on `OnAfterSave`. The live table is never edited.
- Every "owns this item" check (duplicate refusal, sell, keep-at-least-one) ignores `Entry.Session == true`. A real grant of a held session item clears the flag in place.
- Verified: forced saves stored none of them, the live game kept them, a rejoin loaded none and kept real changes from that session.

Reference impl (Pillow Battles): `ServerStorage.System.Main.SessionGrants`

## Session data: Replica (NPData)

- Server creates one Replica per player (token `"NPPlayerData"`, UserId tag), `:Replicate()`d to all clients.
- `Server.FindPlayerReplica(Player)` is non-yielding, nil when absent. `GetPlayerReplica(Player)` waits up to 10s and can still return nil. `GetReplicaData` can return nil. Prefer the non-waiting lookup in callbacks that may outlive the player.
- Mutate with `Replica:Set({"Round","InRound"}, true)`. PlayerRemoving destroys the Replica.
- Client: `WaitForLocalReplica()` is a boot gate; getters can be nil before it.
- Replica `OnSet`/`OnChange` handlers run sandboxed (see `libraries.md`).
- Server-to-client display packets should carry snapshots of results, not make the client read Replica fields the server may clear a moment later.

## Purchases: receipt idempotency

- `MarketplaceService.ProcessReceipt` handler waits/defers when player data is not loaded, returning `NotProcessedYet`.
- A bounded `GrantedReceipts` list (50 ids) in the profile dedupes retries. PB grants **before** recording the marker, so it is not exactly-once: if the grant lands but the handler errors before the marker is written, a retry can grant again. When porting, review failure/retry ordering (grant + marker in the same profile update, `PurchaseGranted` only after that).
- Client purchase prompts/success UI never authorise a grant; only the receipt does.

Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.RbxPaymentService`
