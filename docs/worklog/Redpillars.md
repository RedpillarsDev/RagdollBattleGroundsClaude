# Work log: Redpillars

## 2026-11-23 | Pillow Battles port: scan, scope decisions, staging set up

- Scanned the Ragdoll Battlegrounds place: only Redpillars' folder skeleton (RS.System/Storage/Networking/Configs,
  empty `_GameConfig`, Workspace Map/Live/Dev). No scripts.
- Scanned the local Pillow Battles copy (`PillowBattlesPreV1.rbxl`, read only, nothing edited): 761 scripts. Built a
  text-reference dependency map. Libraries are clean; round loop, admin, analytics, leveling and GameUI touch nearly
  every Pillow system.
- Redpillars' decisions: bring **Foundation + Meta and monetization** (not the combat core, not the round loop);
  **adapt paths to the new skeleton** (Communication.Networking -> RS.Networking, Workspace.InGame.* -> Workspace.Live.*);
  **leave the M1 attack out**; UI = **framework + generic screens**. NPC bots skipped (they need combat + M1).
- My calls: RS.Data and RS.Types stay as Pillow Battles had them (the skeleton has no counterpart); `DataLibrarys`
  keeps its spelling for now.
- Method: one multi-select copy in Pillow Battles (77 roots, ~4000 instances), pasted by Redpillars into
  `ServerStorage.TEMP_PBImport` in Ragdoll Battlegrounds, then moved into place and stripped of Pillow content.
- Claimed the port paths in `.coop/STUDIO.md`.
- Pending: Redpillars' Ctrl+C / Ctrl+Shift+V.
