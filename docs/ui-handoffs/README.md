# UI handoffs

Frames built by a UI session (the `ui-building` skill, `.claude/skills/ui-building/`) and approved by Redpillars, waiting
for a scripting session to wire them up. Each Frame sits in the **disabled** ScreenGui `StarterGui.UIStaging` in the dev
place named in CLAUDE.md until it is moved into the live ScreenGui.

**Scripting session:** before wiring a Frame, read its note here. It maps every element to its purpose, lists the
states, templates and placeholders, and ends with a wiring checklist. Move the Frame into the live ScreenGui (same
container), then delete the staged copy. When it's wired, set its row below to "Wired" with the date and the callback
module.

Approved screenshots live in `img/` (`<Frame>-pc.jpg`, `<Frame>-phone.jpg`).

| Frame | Staged at | Goes to | Status | Note |
|---|---|---|---|---|
