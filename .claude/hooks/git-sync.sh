#!/usr/bin/env bash
# Live sync between this project folder and its GitHub repo.
#   git-sync.sh pull  -> SessionStart: fast-forward to the remote.
#   git-sync.sh push  -> PostToolUse (Write/Edit) and Stop: commit everything, rebase on the remote, push.
# Safe to call often: it no-ops when nothing changed, and a lock serialises concurrent calls
# (subagents and parallel Claude sessions all fire these hooks).

Mode="${1:-push}"
[ -t 0 ] || cat > /dev/null 2>&1   # drain the hook's stdin JSON; not needed

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 0
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || exit 0
export GIT_TERMINAL_PROMPT=0

LockDir=".git/claude-sync.lock"
Warn() { printf '{"systemMessage":"git-sync: %s"}\n' "$1"; }

AcquireLock() {
	local Tries=0
	until mkdir "$LockDir" 2> /dev/null; do
		# Break a lock left behind by a killed run (older than 2 minutes).
		if [ -n "$(find "$LockDir" -maxdepth 0 -mmin +2 2> /dev/null)" ]; then
			rmdir "$LockDir" 2> /dev/null
			continue
		fi
		Tries=$((Tries + 1))
		[ "$Tries" -ge 40 ] && return 1   # ~20s; the next hook run picks the changes up
		sleep 0.5
	done
	trap 'rmdir "$LockDir" 2> /dev/null' EXIT
}

AcquireLock || exit 0

if [ "$Mode" = "pull" ]; then
	if ! git pull --rebase --autostash -q > /dev/null 2>&1; then
		git rebase --abort > /dev/null 2>&1
		Warn "pull from GitHub failed (offline or conflicting history). Local files were left as they are."
	fi
	exit 0
fi

# ---- push ----
if [ -n "$(git status --porcelain)" ]; then
	git add -A
	Changed=$(git diff --cached --name-only | head -5 | tr '\n' ' ')
	Count=$(git diff --cached --name-only | wc -l | tr -d ' ')
	[ "$Count" -gt 5 ] && Changed="$Changed(+$((Count - 5)) more)"
	git commit -q -m "Auto-sync: ${Changed}" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" > /dev/null 2>&1
fi

# Nothing unpushed? Done.
Ahead=$(git rev-list --count '@{u}..HEAD' 2> /dev/null || echo 1)
[ "$Ahead" = "0" ] && exit 0

if ! git pull --rebase --autostash -q > /dev/null 2>&1; then
	git rebase --abort > /dev/null 2>&1
	Warn "could not rebase onto GitHub (conflict). Commits are kept locally; resolve with git pull."
	exit 0
fi
git push -q > /dev/null 2>&1 || Warn "push to GitHub failed (offline or auth). It will retry on the next edit."
exit 0
