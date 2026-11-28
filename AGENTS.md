# AGENTS.md

Always refer to me as "Redpillars" and say my name at least once per response.

Guidance for Codex when acting as a scripting assistant for **Ragdoll Battlegrounds**, a Roblox
ragdoll-physics combat game built in Roblox Studio.

Much of this file and `docs/Codex/` was harvested on 2026-11-23 from **Pillow Battles**, Redpillars' earlier combat
game. Its patterns are proven there, but this is a new place: **verify a path or system exists in Ragdoll
Battlegrounds before relying on it**, and update the notes when the new game diverges.

## Which place to work in

**Only ever edit the Studio place named `Ragdoll Battlegrounds`.**

- Always match the place by the `name` in `list_roblox_studios`, re-queried fresh each session. Never trust a
  remembered `studio_id`: ids are per-connection and the same id has been seen to report a different place after a switch.
- If Ragdoll Battlegrounds isn't connected, say so and wait. Don't fall back to whatever place is connected.
- Other Studios are often connected at the same time (Pillow Battles places such as `PillowBattles PROD` and
  `☁️Pillow Battles☁️ [BETA]`, `GPT Playground`, `SCE1`, `VFX Corner`, ...). **Never edit them** from this project, even
  if one is the only place listed. Reading one for reference is fine when Redpillars asks for it.
- **Building place: not decided yet.** Part-built maps/props use the `building` skill
  (`.Codex/skills/building/SKILL.md`). Ask Redpillars which place building happens in before the first build, then
  record it here. (In Pillow Battles it was `GPT Playground`, never the game place. If Redpillars picks that again,
  it becomes the one exception to the rule above, for building only.)

## No local source — everything lives inside Roblox Studio

This directory holds notes, skills and agent-coordination files, not game source. It is **live-synced to GitHub**
(`RedpillarsDev/RagdollBattleGroundsClaude`) by `.Codex/hooks/git-sync.sh`: SessionStart pulls, every Write/Edit
and every Stop commits and pushes everything (`Auto-sync: ...` commits). Don't hand-commit these files, and keep
secrets and `settings.local.json` out of the folder (it is gitignored).

The game code (Scripts,
ModuleScripts, LocalScripts, all instances) lives in the open Studio place and is only reachable through the
**Roblox Studio MCP tools** (`Roblox_Studio` server, local scope, added 2026-11-23), not Read/Edit/Grep/Bash:

- `search_game_tree` explores the DataModel; `inspect_instance` returns properties, attributes and children.
- `script_search` / `script_grep` find scripts by name or content; `script_read` reads one by dot-path.
- `multi_edit` edits scripts; `execute_luau` runs ad-hoc Luau in Studio, for inspection or one-off fixes.
- `get_console_output` shows the Output window; `start_stop_play` / `get_studio_state` start and stop Play mode
  and report which mode Studio is in; `screen_capture` takes a screenshot.
- `list_roblox_studios` / `set_active_studio`: tool calls apply to whichever Studio is active, so confirm the active
  Studio before every batch of edits.

Studio MCP gotchas: `docs/Codex/agent-workflow.md`. The most important one: **during a playtest, `script_read` and
`execute_luau` hit the play-mode DataModel and return stale source with no error.** Stop play and confirm Edit
mode with `get_studio_state` before verifying an edit landed.

## Work log

Every session keeps a running record of what it does. After each meaningful step (a script or Studio edit, a decision,
a new gotcha, anything left half-done), append an entry to `docs/worklog/<author>.md`, where `<author>` is the GitHub
login in `git config user.name`. One file per person, so two people's sessions never write the same file. Append-only,
newest at the bottom; never edit someone else's file. Entry format:

    ## YYYY-MM-DD | <short title>
    What changed and where (place, instance dot-path, file). What was verified and what was not. What's pending, and whose call.

The repo is public: no secrets, emails or local machine paths in entries. The log says what happened and why; lasting
knowledge about a system still goes in the matching `docs/Codex/` note.

## Prompt prefix: "CoWork"

When a prompt starts with **"CoWork"**, Redpillars is editing the place at the same time as you. Edit scripts as
usual, but **ask permission before starting a playtest** (`start_stop_play`, or anything that enters or leaves Play
mode). Entering Play mode mid-edit interrupts their work and can lose changes.

- Ask once per playtest. A "yes" covers that run, not later ones. Don't stop a playtest you didn't start.
- Since you can't freely playtest, verify by reading the live scripts back, and say plainly in the summary that
  the change is unverified at runtime.

## Coding Buddy Mode

An opt-in mode where Redpillars types `--Codex <task> #` directives into scripts and you watch the editor and act on
them. **Never on by default, never self-enabled**: only Redpillars turns it on or off. When they do, read
`docs/Codex/coding-buddy-mode.md` first. It grants no playtest rights.

## Other agents in the same Studio

Redpillars often runs **several Codex sessions plus Codex CLI** against one Studio DataModel, so edits and
playtests can collide. Codex is not in `ListAgents` and announces nothing. The full protocol (playtest
exclusivity, PLAYTEST START/STOPPED messages, claiming dot-paths, the `.coop/` channel with Codex) is in
`docs/Codex/agent-workflow.md`. The short version:

- At session start, run `ListAgents`, check `.coop/to-AGENTS.md`, and announce yourself to any peer.
- **Playtests are exclusive**: get a peer's yes before `start_stop_play`, and on a CoWork prompt get Redpillars' yes first.
- `get_studio_state` is the only ground truth for Play/Edit mode. A peer's "all clear" only ever means "not me".
- Re-read before editing anything a peer touched, and never revert someone else's work.
- **Codex owns 3D modeling** (Blender, meshes, imports); Codex owns scripting and part-built maps. An imported mesh
  is inert until a data catalog entry names it, and that wiring is Codex's job.

## Before building a medium or large system — ask first

For anything bigger than a small self-contained change (a new service, a UI screen wired end-to-end, a new data
catalog or save-data field, a change touching more than a couple of modules), **ask clarifying questions before
writing code**. Use `AskUserQuestion` and batch the questions into one round up front.

Ask about what **can't be inferred from the codebase** and changes what gets built: rules and edge cases (cooldowns,
misses, resets, what happens when a sequence runs out), data shape and ownership (catalog vs authored Gui as the
source of truth), and scope (repair malformed data, or build around it?). Don't ask what the code already answers
or what has an obvious house default: pick it, say which way you went, and move on. Tuning values can be sensible
placeholders, flagged in the summary as Redpillars' to tune.

## Saved data

The game is pre-release, so the save layout isn't frozen yet. Still, build it the way it must work once it ships
(details: `docs/Codex/data-and-saves.md`):

- Keep the Player data template JSON-safe (no Vector3/CFrame/Instance).
- Give the template a `DataVersion` and a migration/`Repair` path **from day one**, so freezing at release costs nothing.
- ProfileStore `Reconcile` adds missing template keys to old profiles but **never rewrites an existing value**. A key
  whose type or meaning changes keeps its old shape in old saves, so changing one needs a migration step.
- Keep separate Studio and live DataStore/ProfileStore keys. Read the data init module before reasoning about
  whether test data persisted (a `resetData`-style wipe flag has caused bugs before).
- **Once the game is live** (Redpillars will say so), apply the Pillow Battles freeze rule: never rename, remove,
  re-nest or retype an existing saved key or store name; new keys are fine; an existing key changes only through a
  snapshot → template change + version bump → new migration step → `Repair` → test-on-old-saves sequence.

## Coding conventions (Redpillars' house style)

- `--!strict` at the top of every script.
- Section-comment skeleton, in this order, present even if empty:
  `--Services / --Paths / --Dependencies / --Types / --Cache / --Config / --Databases / --Main`, then
  `--Private functions` and `--Public functions`. Match the header casing the file already uses.
- **PascalCase for everything**, including locals and parameters (`Player`, `Character`, `TotalDamage`).
- `--[[NO YIELD// ]]`, `--[[CAN YIELD// ]]` or `--[[YIELD// ]]` immediately before public functions. Other code relies on them.
- A local `DevPrint(...)` helper gated by `DevPrintsEnabled` / `DevPrintsAreWarnings` instead of raw `print`/`warn`.
- Tabs, double-quoted strings. Match the surrounding file's `require` style (instance path vs string path) rather
  than mixing both in one module.
- Services use a Client/Server split (`MyService.Server` / `MyService.Client`, chosen by `RunService`). Data catalogs
  are `{[Id]: Record}` dictionaries with a parallel `export type FooId = "A" | "B"` union, and **a new entry goes in
  both**. Patterns and the default folder layout: `docs/Codex/architecture-patterns.md`.
- Put tunable numbers in one game config module rather than as magic numbers in services.
- Don't imitate bugs, half-typed code or test text, and don't reformat unrelated code.

## Hard rules for new code

These are generic rules carried over from Pillow Battles. Each one cost a bug there, and the linked notes file has the why.

- **Server authority:** every Client→Server gameplay packet is validated on the Server (live Character, state,
  permission, the server's own cooldown clock, ownership, reach, once-per-victim). An unvalidated packet is an open
  exploit. *(combat-and-ragdoll)*
- **Cooldown guards** derive from the same cooldown function the game uses, never fixed seconds: Redpillars tests with
  cooldowns zeroed. *(combat-and-ragdoll)*
- **Choke points:** damage, knockback velocity and status effects (ragdoll included) each go through one server
  function. Code that touches a body outside them re-checks spawn protection, teams and ragdoll immunity itself.
  *(combat-and-ragdoll)*
- **Never stop a Player's animation tracks from the Server.** A ragdoll stops every track, so anything keeping its own
  "is playing" flag re-checks `IsPlaying`. *(combat-and-ragdoll)*
- **World Sounds** are parented to a BasePart or Attachment. Anything else plays 2D, heard everywhere. *(roblox-gotchas)*
- **Hiding HUD** goes through one visibility module, never by toggling elements directly. *(ui-and-input)*
- **TextBoxes** get the touch-focus helper, or phones may not be able to type into them. *(ui-and-input)*
- **UI look:** no "AI dashboard card" style (dark rounded panel, accent bar, flash, pill chips) and no blanket mobile
  UIScale. Default to bare outlined text, and ask Redpillars before inventing more. *(ui-and-input)*
- **Controls:** every new control gets a Gamepad binding beside its keyboard one, and key hints are drawn per input
  device, never hardcoded. *(console-support)*
- **Analytics custom events** go through one tracking module with a registered event list. Never rename one or move
  its fields, and never put an apostrophe, comma or quote in a field value. *(economy-and-analytics)*
- **Dev/admin tools** check rank on the Server, never only on the Client. *(admin-and-dev-tools)*
- **Kill height is per area:** "out of the world" checks use the per-area kill height, not one global Y. *(round-loop-and-world)*
- **Floor raycasts** include every round-map container, not just the current main map. *(round-loop-and-world)*

## Notes index: `docs/Codex/`

Per-system notes live in `docs/Codex/`, not here: this file loads into every session, those load only when read.
**Before working on a system below, read its file.** All were seeded from Pillow Battles. Rewrite them as Ragdoll
Battlegrounds' own systems take shape.

| File | Covers |
|---|---|
| `architecture-patterns.md` | Service module pattern, boot sequence, LifeCycle dispatchers, folder layout, config module, change recipes |
| `data-and-saves.md` | Persistent vs session data, ProfileStore/DataService, Reconcile, DataVersion/migrations/Repair, dev vs live keys |
| `libraries.md` | Signal, Promise, Replica, ByteNet, ProfileStore and other library notes and gotchas |
| `roblox-gotchas.md` | Engine-level gotchas (deferred signals, sandboxed threads, sound parenting, replication quirks, ...) |
| `combat-and-ragdoll.md` | Hit detection, hitboxes, damage/velocity choke points, ragdoll and its safety net, kill credit, death, spawn protection, status effects, anti-exploit guard, rate limiting |
| `abilities-framework.md` | Ability architecture, the new-ability form, a catalogue of reusable ability techniques |
| `npcs.md` | NPC/bot architecture and lessons |
| `vfx.md` | VFX dispatch/emit patterns, rigs, gotchas |
| `round-loop-and-world.md` | Round state machine, private arenas/1v1, return to lobby, kill height, collision groups, pads, maps |
| `progression.md` | Leveling/EXP and config-by-level pattern |
| `ui-and-input.md` | UI framework, style rules, HUD visibility, mobile, overhead tags, kill feed, settings |
| `console-support.md` | Controller support design and gotchas |
| `onboarding-and-lobby.md` | Tutorial/onboarding, A/B cohorts, new-player protection, lobby patterns, winner display, player inspect |
| `meta-systems.md` | Daily rewards, group reward, tasks, career stats, lucky wheel |
| `economy-and-analytics.md` | Rarities/RNG, shops, gamepasses/dev products/receipts, analytics events and funnels |
| `admin-and-dev-tools.md` | Admin panel, staff gating, dev commands, session-only items |
| `agent-workflow.md` | Multi-session and Codex coordination in one Studio, `.coop/` protocol, MCP gotchas |
| `coding-buddy-mode.md` | The `--Codex ... #` directive mode |
| `documentation-refresh.md` | Doc refresh procedure, Notion write gotchas |
| `asset-pipeline.md` | Blender → FBX/glb → Roblox import conventions (Codex's side, for handoffs) |

Skills: `building` (part-built maps/props with BuildKit/PropKit) and `ui-building` (staged UI Frames with UIKit plus
a handoff note).

**Keep this file small.** New notes go in the matching `docs/Codex/` file, and a genuinely new system gets a new file
and an index row. Stay under ~40k characters, since every character here is paid for in every session.

## Reference: Pillow Battles

When building a system Pillow Battles already has (combat guard, ragdoll, data versioning, UI framework, round
loop, ...), check its implementation first. The notes files carry `Reference impl (Pillow Battles): <dot-path>`
pointers.

- Repo (read-only from here): `C:\Users\betee\Desktop\Codex\PillowBattlesClaude`, with `AGENTS.md`, `docs/Codex/` and
  `docs/codebase/`. Worked map-build scripts live in `.Codex/skills/building/`.
- Notion deep-dive: **Pillow Battles → Docs → Scripting Docs**.
- To read PB live code, Redpillars must have a PB place open in Studio. Read only, then switch back to Ragdoll
  Battlegrounds and confirm the switch before any edit.

## Workflow notes

- Prefer `script_grep`/`script_search` to locate things before reading whole modules blind.
- After edits, `start_stop_play` + `get_console_output` is the fastest runtime sanity check. On a CoWork prompt, ask
  first, and with a peer session open, coordinate first.
- **Redpillars edits the place while you work.** If a script doesn't match what you last wrote, assume a concurrent
  edit: re-read it and adapt rather than revert. A zeroed cooldown or timer is a deliberate dev toggle. Leave it, and
  if you change one to verify something, put it back.
- When adding a gameplay system, mirror the established patterns (Client/Server split service, LifeCycle module, typed
  packet + listener registration, catalog + Id union) rather than inventing a new structure. Ask the up-front
  questions first.
