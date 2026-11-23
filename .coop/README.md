# .coop: cross-agent channel for Ragdoll Battlegrounds

Several agents can work this project at once, and they do **not** share a process, a transcript or a discovery
mechanism. Full etiquette (playtests, claims, stale reads): `docs/claude/agent-workflow.md`.

| Agent | Owns | Reachable by |
|---|---|---|
| **Claude Code** (one or more sessions) | Scripting (everything inside the Studio DataModel), data catalogs and wiring, part-built maps, staged UI Frames | `ListAgents` + `SendMessage`, Claude-to-Claude only |
| **Codex CLI** (if used) | 3D modeling: Blender, `assets/`, FBX/glb/rbxm export, mesh imports | `to-codex.md`, or `codex queue --thread <id> --message` |
| **Redpillars** | Everything, live, in Studio | Chat |

Claude sessions can message each other directly and never need these files for that. **Codex can't see those messages
and never appears in `ListAgents`.** These files exist so Codex isn't invisible, and so a session that doesn't exist yet
can still read what happened.

## Files

- `to-codex.md`: Claude appends, Codex reads. Handoffs *to* modeling; heads-ups about where Claude is building.
- `to-claude.md`: Codex appends, Claude reads. Import reports and handoffs *to* scripting. **Claude reads the tail at
  session start.**
- `STUDIO.md`: claimed dot-paths (current state) and the Play-mode log (history). **Read before touching Studio.**

Both inboxes are **append-only, newest at the bottom.** Never rewrite or delete another agent's entry; add below it.
Separate inboxes rather than one shared log, so two agents writing at once can't clobber each other.

## Entry format (inboxes)

```
## YYYY-MM-DD | <Agent> (<session name>) | <short title>

What was done or is asked, in a few dense lines. Where: place name, instance path, area / X range, file paths.
What was NOT touched (other places, catalogs, Play mode). What's pending, and whose call it is.
```

An import report (Codex -> Claude) always names: the instance path, the intended catalog, recolor groups, parts meant to
move separately, collision setup, and which checks ran vs which are unverified (`docs/claude/asset-pipeline.md`).

## Sending

Claude -> Codex, live session (lands in its queue; minutes of latency):

    ~/.codex/plugins/.plugin-appserver/codex.exe queue --thread <uuid-or-session-name> --message "text"

Claude -> Codex, fresh one-shot (no session):

    ~/.codex/plugins/.plugin-appserver/codex.exe exec "task"

Session ids are in `~/.codex/session_index.jsonl` and change across restarts. **Only a reply in `to-claude.md` confirms
delivery**: the queue database and writer-lock mtimes both misreport it. Use `to-codex.md` for anything load-bearing.

Codex -> Claude: append to `to-claude.md`. `claude -p "..."` spawns a *fresh headless* Claude, not a live session; to
reach a live one it must relay (`claude -p "SendMessage to <session-name>: <text>"`).

## The rule that actually matters

All agents drive the **same Roblox Studio MCP bridge** (Codex's `.codex/config.toml` and Claude's MCP config run the
identical `%LOCALAPPDATA%\Roblox\mcp.bat`). One DataModel, one Play mode.

`script_read` and `execute_luau` during someone else's playtest return **plausible-looking stale source with no error**.
So **`get_studio_state` is the only ground truth.** An all-clear from another agent means "not me", never "nobody".
Check state; don't infer it.

## The handoff that matters

**An imported mesh is inert until a catalog entry names it** (and, for typed catalogs, its Id union member). That wiring
is Claude's; Codex reports the import here so it doesn't sit unused. Whether an asset enters the game at all is
Redpillars' call, never self-authorized by either agent.
