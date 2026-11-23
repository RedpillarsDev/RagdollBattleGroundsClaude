# Work log: gutsontopp2

Append-only, newest at the bottom. Format and rules: "Work log" in `CLAUDE.md`.

## 2026-11-23 | Cloned the repo and got live sync working on this machine

- Cloned `RedpillarsDev/RagdollBattleGroundsClaude` (main at `9485782`) and read `CLAUDE.md`, `.claude/settings.json`,
  `.claude/hooks/git-sync.sh`, the `.coop/` files and `docs/claude/agent-workflow.md`. The live-sync hook already
  existed in the repo, so nothing new was built for it.
- Set a repo-local git identity (GitHub noreply address). There was none, and `git-sync.sh` swallows commit errors, so
  every sync would have silently done nothing. Global git config untouched.
- Checked line endings: `git-sync.sh` is checked out as CRLF on Windows, but Git Bash runs it fine (tested with a CRLF
  script), so no change was needed.
- Observed that the PostToolUse hook did **not** fire when this session edited files: the session's workspace was the
  parent folder, not this repo, so `.claude/settings.json` was never loaded. Until a session is opened with this repo
  as its workspace, sync is run by hand with `bash .claude/hooks/git-sync.sh push`.
- Docs: added the "Work log" section to `CLAUDE.md`, created this file, and rewrote the stale "Auto-commit hooks (not
  ported)" section of `docs/claude/agent-workflow.md` (it said the project had no git repo and no hook).
- Verified end to end: ran `git-sync.sh push` once with `bash -x`. It committed the three files above as
  `Auto-sync: ...` under this identity, pushed, and local `HEAD` matched `git ls-remote origin main`. Push access for
  the stored GitHub login is confirmed.
- Not touched: Roblox Studio (nothing connected, nothing edited), game scripts, the `.coop/` files, Play mode.
- Open: the hook's commit trailer is hard-coded to `Co-Authored-By: Claude Opus 5.5`, which names the wrong model for
  sessions running on another one. Left as is because the script is shared with the other machine.
