# Agent workflow: several Claude sessions, Codex and Redpillars in one Studio

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Redpillars routinely runs **two or more Claude Code sessions at once**, sometimes **Codex CLI** too, and edits the place
live. None of them share a process, a transcript or a discovery mechanism. This file is how they avoid stepping on each
other. The `.coop/` folder at the repo root is the shared channel; `.coop/README.md` has the file formats.

## Who's who

| Agent | Owns | Reached by |
|---|---|---|
| **Claude Code** (one or more sessions) | Scripting: everything inside the Studio DataModel. Data catalogs and wiring. Part-built maps (`building` skill). Staged UI Frames (`ui-building` skill) | `ListAgents` + `SendMessage`, Claude-to-Claude only |
| **Codex CLI** (if used on this project) | 3D modeling: Blender, `assets/`, FBX/glb/rbxm export, importing meshes into Studio | `.coop/to-codex.md`, or `codex queue` into a live session |
| **Redpillars** | Everything, live, in Studio | Chat |

In Pillow Battles Codex's role grew beyond modeling: native-part prop kits in the building place, a read-only codebase
deep dive, and its own coding-buddy mode (`-- GPT ... #` directives). Whatever Codex does here, it is a full participant
in the shared-DataModel problem below.

## The one fact everything else follows from

**Every agent drives the same Roblox Studio MCP bridge.** Claude's MCP config and Codex's `.codex/config.toml` both
launch the identical `%LOCALAPPDATA%\Roblox\mcp.bat`. So there is **one DataModel and one Play mode** shared by all of
them.

- **Reads during someone else's playtest are silently wrong.** `script_read` and `execute_luau` hit the play-mode
  DataModel and return plausible-looking **stale source with no error**. There is nothing to notice: you get a confident
  wrong answer. Edits fail more visibly (`multi_edit` returns "Edit datamodel is not available in Play mode" and lands
  nothing), so hold pending edits until Edit returns.
- **`get_studio_state` is the only ground truth.** Call it before reads. An all-clear from another agent means "not me",
  never "nobody": Codex announces nothing to Claude's channels, and Redpillars presses Play whenever they like.
- **One reading can be wrong.** In Pillow Battles a single `get_studio_state` read Edit while three back-to-back
  re-queries (and the peer's) read Play. Before acting on a mode change that matters, re-query, or confirm it by a
  successful edit landing.
- **Pick the place by name, fresh, every session.** `list_roblox_studios`, match the `name`, `set_active_studio`. Never
  reuse a remembered `studio_id`: one was seen reporting a different place after a switch, which is a silent way to edit
  the wrong game. Other places are often connected; never touch them even if one is the only place listed.

## More Studio MCP gotchas

General tooling gotchas (`execute_luau` returning nil on print, fresh module copies, undo reverting agent edits, editor
buffer vs Source) are in `docs/claude/roblox-gotchas.md`, "Studio and MCP tooling". The ones the skills depend on:
- **`require` caches across `execute_luau` calls**, so an edited ModuleScript doesn't reload. Tool kits kept in
  ServerStorage (`ClaudeBuildKit`, `ClaudeUIKit`) are loaded with `loadstring(Module.Source)()` instead.
- **Pasting a large file through `execute_luau` can be silently altered.** After installing a kit, compare a length +
  checksum computed in Studio against the repo file (`ui-building` skill has the snippet).
- **`screen_capture`:** the first capture after creating a SurfaceGui comes back without its text (fine from the next
  one on); CoreGui never shows, so preview Guis must live in StarterGui (name them `TEMP_` and always remove them: a
  leftover ships with the next publish).
- **Shared-place hygiene:** anything you change place-wide for a screenshot (Lighting, camera) is stashed and restored
  in the same session (`Kit.PreviewLightingOn/Off`). Other agents are capturing in the same place.

## Several Claude sessions

Run `ListAgents` at session start to see peers (rows marked `interactive`) and talk with `SendMessage` using the name
from that listing (the name is the address). Announce yourself and agree the protocol rather than assuming you're alone.

- **Playtests are exclusive.** Message the peer and wait for a reply before `start_stop_play`. The peer's yes only means
  "no live read of mine is in flight". On a **CoWork** prompt (Redpillars is editing at the same time) that means **two
  yeses, in order: Redpillars first, then the peer.** The peer's yes is never a stand-in for Redpillars'.
- **Signal both ends.** Send "PLAYTEST START" before, and "PLAYTEST STOPPED, all clear" after confirming Edit with
  `get_studio_state` (not assuming the stop landed). Log both ends in `.coop/STUDIO.md` too, for Codex. Peers hold all
  reads between the two.
- **Never stop a run you didn't start.** Not a peer's, not Redpillars', not an unattributed one. If a run looks
  abandoned (its session is offline), check `get_studio_state`; if it reads Edit, log the stale claim as closed. Never
  stop a run to get a source read.
- **A path is claimed at first edit, not in advance.** Announcing where you intend to work is a heads-up, not a lock;
  speculative claims block work nobody is doing. Claim the dot-path the moment you open it, and yield anything a peer is
  already inside.
- **Re-read before editing** anything a peer has announced, and **never revert** their work. Message them and resolve it.
- **Redpillars edits live.** If a script doesn't match what you last wrote, assume a concurrent edit before blaming the
  tooling, and adapt to their version. A zeroed cooldown or timer is a deliberate dev toggle, not a bug; if you must
  change one to verify something, put it back the way they had it.
- **Test scaffolding is `TEMP_`-prefixed.** Harness Scripts, probe dummies and preview Guis are named `TEMP_*`, created
  in the play DataModel where possible (they vanish on stop), and swept with `GetDescendants` before you log "all
  clear". A leftover `TEMP_` object ships with the next publish.

### CoWork prompt prefix (summary)
A prompt starting with **"CoWork"** means Redpillars is editing at the same time. Edit scripts as usual, but **ask before
each playtest** (one yes covers one run), never stop a run you didn't start, and since you can't freely playtest, say
plainly that the change is unverified at runtime.

## Talking to Codex: `.coop/`

Codex can't receive `SendMessage` and never appears in `ListAgents`. The files are how it stops being invisible.

| File | Writer -> reader | Use |
|---|---|---|
| `.coop/to-codex.md` | Claude -> Codex | Handoffs to modeling, heads-ups about areas you're building in |
| `.coop/to-claude.md` | Codex -> Claude | Import reports, Codex's own builds. **Read the tail at session start** |
| `.coop/STUDIO.md` | everyone | Play-mode log and claimed dot-paths. **Read before touching Studio** |

- **Inboxes are append-only, newest at the bottom.** Never rewrite or delete another agent's entry; add below it. Two
  inboxes instead of one shared log so two agents writing at once can't clobber each other.
- **Entry format:** `## YYYY-MM-DD | <Agent (session name)> | <short title>` then a few dense lines: what, where (place +
  instance path + area/X range), what was NOT touched, what's pending and whose call it is.
- **`STUDIO.md` is a courtesy, not a lock.** Entries go stale. Its Play-mode log is append-only history (it's how a later
  agent tells "nobody has played for an hour" from "the file was tidied"); only the claims table is current state, and
  only there does a row get removed on release.
- **Lesson from Pillow Battles:** rows appended "to the log table" ended up after later sections, splitting the log in
  three. This project's `STUDIO.md` puts the log **last**, so appending to the end of the file is always right.

### Queueing into a live Codex session (`codex queue`)

```
~/.codex/plugins/.plugin-appserver/codex.exe queue --thread <uuid-or-session-name> --message "text"
```

- The binary is not on `PATH`. Session names and ids are in `~/.codex/session_index.jsonl`; ids change across
  restarts, so look them up fresh.
- `codex.exe exec "task"` runs a fresh one-shot instead (no session context).
- **Delivery is asynchronous: minutes, not instant.** Measured 2026-09-07: queued 16:29, reply 16:33-16:36. Don't read a
  few minutes of silence as a failed send.
- **Don't try to infer whether it was consumed.** `~/.codex/queue_1.sqlite-wal` still held the message id after it had
  been received, and `~/.codex/thread-writer-locks/*.lock` mtimes never moved across a turn the session demonstrably
  took. **The only confirmation is the reply appearing in `.coop/to-claude.md`.** A background `until` loop on that
  file's byte size watches for it at no cost.
- **Choosing a carrier:** `to-codex.md` for anything load-bearing (read at session start, reaches sessions that don't
  exist yet); `queue` only to reach a session running now.
- **Codex -> Claude:** appending to `to-claude.md` is the reliable path. `claude -p "..."` spawns a *fresh headless*
  Claude, not a live session; to land in a live one it has to relay (`claude -p "SendMessage to <session>: <text>"`).

## Division of labour and the handoff that matters

- **Codex:** Blender sources, `assets/`, FBX/glb/rbxm export, importing meshes into Studio model storage, native-part
  asset kits in the building place. See `docs/claude/asset-pipeline.md` for its conventions.
- **Claude:** Scripts, ModuleScripts, data catalogs, wiring imported models into gameplay, part-built maps (`building`
  skill), staged UI Frames (`ui-building` skill).

**An imported mesh is inert until a catalog entry names it.** A model landing in model storage is not in the game until
a data catalog registers it. Where catalogs have a typed Id union (`export type FooId = "A" | "B"`), the new id goes in
**both** the dictionary **and** the union. That wiring is Claude's, and Claude has no way to know the mesh arrived
unless Codex says so. So:

- **Codex, on import:** appends to `to-claude.md` the instance path, the intended catalog, and anything non-obvious
  (recolor groups, which MeshParts move separately, pivots, collision setup, what's unverified).
- **Claude, at session start:** checks `to-claude.md` for pending handoffs before assuming there's no modeling work
  waiting.
- **Neither self-authorizes registration.** Whether an asset goes into the game (e.g. a new map into the map rotation)
  is Redpillars' call. Pillow Battles precedent: "We have not touched Maps and will not until Redpillars says so."
- **Part-built maps** follow the same rule: built in the building place, moved and wired only when Redpillars asks.

## Flags outside your scope

When you find something dangerous that isn't yours to fix (Pillow Battles: a `resetData = true` flag in the live
branch that would wipe every save on join), **flag it, don't fix it**: tell Redpillars in chat and add a "FLAG, not a
claim" row to `STUDIO.md` naming the path, the line, the consequence, and that you left it unchanged.

## Session-start checklist

1. `list_roblox_studios` fresh; pick the right place by name (dev place for scripting/UI, building place for
   part-building).
2. `get_studio_state`.
3. `ListAgents`; announce yourself to peers.
4. Tail `.coop/to-claude.md` and `.coop/STUDIO.md` (if Codex is in use).
5. Before any playtest: peer yes (and Redpillars' yes on CoWork), `STUDIO.md` row, PLAYTEST START.

## Auto-commit hooks (Pillow Battles setup, not ported)

Pillow Battles' `.claude/settings.json` had a `PostToolUse` hook on `Write|Edit`: if the edited path was `CLAUDE.md` or
a `docs/claude/*.md` file, it ran `git add` + `git commit -m "Auto-update Claude notes"` + `git push origin main`, so
notes were backed up the moment they changed. Codex's `.codex/hooks.json` had the same idea for its notes, but its grep
matched `CLAUDE.md` while its status message said "Pushing AGENTS.md" (a copy-paste bug: AGENTS.md edits weren't
pushed). Not set up here: this project has no git repo yet. If Redpillars wants it, add it with the `update-config`
skill once the repo exists, and make each agent's hook match its own notes files.
