# STUDIO.md: claimed paths + Play-mode log

One DataModel, one Play mode, several agents. Update your own rows; never edit another agent's.

**`get_studio_state` is the only ground truth.** This file is a courtesy, not a lock: an entry can be stale, and not
every agent announces itself. Check state before every read. An all-clear from another agent only ever means "not me",
never "nobody".

## Division of ownership

- **Codex** (if used): `assets/`, Blender sources, FBX/glb/rbxm export, importing meshes into model storage.
- **Claude**: Scripts, ModuleScripts, data catalogs, wiring imported models into gameplay, part-built maps (building
  place), staged UI Frames (`StarterGui.UIStaging`).
- A mesh landing in model storage is inert until a catalog entry names it. That edit is Claude's, on Redpillars' say-so.

## Claimed dot-paths (current state)

A path is claimed **at first edit, not in advance**. Announcing where you intend to work is a heads-up; speculative
claims block work nobody is doing. Remove your row when you release the path. For part-building, claim the place, the
model name and the X range.

| Path / area | Place | Agent | Since |
|---|---|---|---|
| Pillow Battles port: `ServerStorage.TEMP_PBImport` (staging) and everything it moves into: RS.System, RS.Networking, RS.Data, RS.Types, RS.Design, RS.Storage, RS._GameConfig, SSS, ServerStorage.System, SPS, StarterGui.Main, ReplicatedFirst.LoadingScreen | Ragdoll Battlegrounds | Claude (ragdollengine-42) | 2026-11-23 |
| `Workspace.Map.RagdollPark` (X 2600..3400, Z -400..400) + `ServerStorage.ClaudeParkKit` + `ServerStorage.RagdollParkAssets` | Ragdoll Battlegrounds | Claude (Guts' session, claude-6c) | 2026-11-23 |

Re-read anything another agent has claimed before editing it, and **never revert their work**: raise it instead.
Redpillars also edits live, so a script can differ from what any agent last wrote without any of them touching it.

## Play-mode log (append-only history; ALWAYS append at the very end of this file)

Add a row for each transition and leave old rows in place: the history is what lets a later agent tell "nobody has
played in an hour" from "the file was tidied". Claim a row before `start_stop_play`; clear it after `get_studio_state`
confirms Edit; note any `TEMP_` scaffolding and that a sweep found none left. **Never stop a run you did not start.**
Flags about dangerous code outside your scope go here too, as `FLAG, not a claim` rows.

Statuses: `PLAY MODE STARTING (mine)` · `PLAY MODE ENDED, all clear` · `NOT MINE, observed` · `STALE CLAIM closed` ·
`FLAG, not a claim`

| When | Who | Place | Status |
|---|---|---|---|
