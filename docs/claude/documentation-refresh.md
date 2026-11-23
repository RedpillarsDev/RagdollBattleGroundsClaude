# Documentation Refresh

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

## Where knowledge lives (the layers being refreshed)

| Layer | Holds | Loaded |
|---|---|---|
| `CLAUDE.md` | Rules every session needs, the architecture tree, an index of notes | Every session, so keep it small (Pillow Battles capped it at ~40k characters; Claude Code warns above that and every character is paid for in every session) |
| `docs/claude/<system>.md` | Per-system details, measured results, known bugs | Only when a session works on that system |
| Notion "Scripting Docs" | The full code-verified deep dive: exact signatures, call order, confirmed bugs and dead code flagged inline | Checked before a fresh `script_grep` sweep of a covered system |

All three are **point-in-time snapshots, not ground truth**. The live scripts are ground truth. When a claim looks stale
or Redpillars says they changed something, re-verify against the live script. When writing any note, record the
evidence: the date, and whether the claim came from live source, a runtime test, documentation, or inference. A newer
verified pass supersedes conflicting claims in an older snapshot; say so where both exist.

## Command: "Do a Documentation Refresh"

When Redpillars says **"Do a Documentation Refresh"** (or an obvious variant), re-sync the Notion Scripting Docs (and
these notes) against what has actually changed in the live place since the last pass. It's a **diff-and-update**, not a
from-scratch rewrite: don't regenerate pages whose content is still accurate.

1. **Confirm the active Studio instance** (`list_roblox_studios` / `set_active_studio`, matched by name). Never trust a
   recorded id. Check `get_studio_state` is Edit: reads during a playtest return stale source silently.
2. **Fetch the current docs first.** `notion-fetch` the Scripting Docs index page and each child, so you know what's
   already claimed before spawning research. Pillow Battles had 8 area pages, a good template if this game's docs don't
   exist yet: Architecture & Boot Sequence, Data Systems, Networking, Combat & Abilities, Gameplay Services Reference,
   Round Loop & Map System, UI Framework, Core Libraries & Data Catalogs.
3. **Spawn one background research agent per area** (add one more if a genuinely new system has appeared that fits no
   existing page). Brief each with (a) its page's current content as the baseline claim, and (b) instructions to re-read
   the live scripts for that area through the Roblox Studio MCP tools and report **only what changed**: new modules,
   fields and functions; corrected facts; resolved bugs or gaps (to remove); newly found bugs or gaps. Reporting only the
   diff keeps each pass cheap.
4. **Apply targeted edits** with `notion-update-page`: `update_content` (search-and-replace on the changed passage) or
   `insert_content` (append a genuinely new section). Use `replace_content` on a whole page only when the diff is large
   enough that it's actually simpler. Create a new subpage only for a new system with no existing home.
5. **Watch the Notion write gotchas** (below).
6. **Update `CLAUDE.md` and the matching `docs/claude/` note** if the refresh surfaces something that belongs there: a
   changed architecture tree or service roster goes in `CLAUDE.md`; a system's changed behaviour, or a gap fixed or newly
   found, goes in that system's note. Mirror the existing edit style rather than duplicating the Notion depth.
7. **Report concrete diffs** to Redpillars: list what actually changed, page by page. Never just "done". If nothing
   changed, say so.

## Notion write gotchas

- **Cloudflare WAF false positive on code-like text.** `notion-create-pages` / `notion-update-page` calls were blocked
  by Cloudflare on the literal substring `System.Init(` (it matched e.g. `RoundSystem.Init()`). Split it across two
  inline code spans: `` `RoundSystem` ``.`` `Init()` ``. If a write is blocked with no clear reason, suspect a
  code-call-looking substring in the payload and split it the same way.
- **Large payloads trip the WAF more often.** Don't write a whole page in one `notion-create-pages` call. Create the
  page small, then add content in **~1-3 KB `insert_content` chunks**.
- **Literal `\n` renders as a backslash-n**, not a line break. Put real newlines in the parameter value, never escape
  sequences.
