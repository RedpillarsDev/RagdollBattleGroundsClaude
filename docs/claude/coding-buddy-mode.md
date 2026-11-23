# Coding Buddy Mode

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

An opt-in mode Redpillars turns **on and off by saying so**. It is never on by default and must never self-enable.
While it is on, you watch the Studio script editor and act on tasks Redpillars types straight into the code.

## The directive format

A comment that begins `--Claude` and ends with a `#`:

```lua
--Claude add a GoldGradient that mirrors RainbowGradient but uses the Gold preset #
```

- **Scope:** the module the directive is written in, unless the directive names another.
- **Nothing runs until the `#` lands.** A `--Claude` with no `#` yet is Redpillars still typing. Never act on a partial
  directive, and never guess where it was going.
- The text may span several lines; everything between `--Claude` and the first `#` is the task.
- **Delete the directive comment as part of doing the task**, so it can't be picked up twice.
- **Reply in chat** about what you did. The comment is the inbox, not the outbox: don't write answers back into the
  module as comments unless the task asks for one.

## How you watch: a long poll

Nothing in the MCP bridge can wake you, so this is polling, not a push. One `execute_luau` call reads the live editor
buffers and can sit for ~100 s, returning the moment a complete directive appears. Re-issue it to keep watching.

- **Read the buffer, not the Source.** `ScriptEditorService:GetScriptDocuments()` -> `Doc:GetText()` is the
  **unsaved** editor buffer. `script_read` and `.Source` show the saved script and can be stale against it.
- **Scan every open tab.** `StudioService.ActiveScript` is only the focused script; a directive can be typed and then
  switched away from. `GetScriptDocuments()` returns every open tab.
- **Dedupe** executed directives in `_G.CLAUDE_BUDDY_SEEN`, keyed by module path + directive text, so the same one never
  fires twice while the mode is on.
- **`_G` and signal connections persist across `execute_luau` calls** (measured 2026-09-21) in Studio's plugin Lua VM.
  That's what makes the dedupe table and an optional focus watcher (`_G.CLAUDE_FOCUS_WATCHER`, a connection on
  `StudioService:GetPropertyChangedSignal("ActiveScript")`) possible, and also why they must be cleaned up (below).
- **Before editing**, re-read the buffer: Redpillars may have kept typing in the same block. Make a targeted edit that
  preserves their concurrent changes.

Sketch of one poll call (the Pillow Battles poll code wasn't saved; this is a reconstruction, untested as written):

```lua
local SES = game:GetService("ScriptEditorService")
_G.CLAUDE_BUDDY_SEEN = _G.CLAUDE_BUDDY_SEEN or {}
local Deadline = os.clock() + 100
while os.clock() < Deadline do
	for _, Doc in SES:GetScriptDocuments() do
		if not Doc:IsCommandBar() then
			local Path = Doc:GetScript():GetFullName()
			for Task in Doc:GetText():gmatch("%-%-Claude(.-)#") do -- '.' spans newlines in Lua patterns
				local Key = Path .. "|" .. Task
				if not _G.CLAUDE_BUDDY_SEEN[Key] then
					_G.CLAUDE_BUDDY_SEEN[Key] = true
					return Path .. "\n" .. Task
				end
			end
		end
	end
	task.wait(1)
end
return "no directive yet"
```

## What it does not grant

This mode reads and edits scripts. It does **not** grant playtest rights: the CoWork gate, the peer-session protocol and
the `get_studio_state` rules (`docs/claude/agent-workflow.md`) all still apply in full. A directive that needs a
playtest still needs the playtest asked for separately. Say plainly when a change was only checked by reading it back.

## Turning it off

Stop the poll **and** clear `_G.CLAUDE_BUDDY_SEEN` and `_G.CLAUDE_FOCUS_WATCHER` (disconnect it first). Both live inside
Studio and outlive the chat session, so they have to be cleared deliberately when the mode ends, not left to lapse.

```lua
if _G.CLAUDE_FOCUS_WATCHER then _G.CLAUDE_FOCUS_WATCHER:Disconnect() end
_G.CLAUDE_FOCUS_WATCHER, _G.CLAUDE_BUDDY_SEEN = nil, nil
```

## Lessons from Codex's variant (Pillow Battles `AGENTS.md`)

Codex ran its own buddy mode (`Start` / `Stop` in chat, `-- GPT <task> #` directives). Worth borrowing if Redpillars wants
more than directive execution:
- **Let typing settle** ~3-5 s of unchanged source before reviewing a changed block; don't flag unfinished typing as a bug.
- **Mark instead of delete** is an alternative: Codex rewrote a finished directive to `-- GPT DONE: <task>`. Pick one
  convention per project; Claude's was delete.
- **Review feedback as notes:** short `-- GPT NOTE:` comments beside real bugs (typos, wrong requires, wrong variables,
  `return` instead of `continue`), one note per issue, removed once fixed, dismissed feedback never repeated. Point out
  bugs without rewriting code unless a completed directive or a chat request asks for the fix.
- **One polling loop only**, never duplicate monitors; ask before every playtest while the mode is on.
- **Stay in the game's codebase.** Don't follow focus into another Studio place.
