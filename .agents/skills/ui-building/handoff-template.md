# <FrameName> — UI handoff

<!-- Copy this file to docs/ui-handoffs/<FrameName>.md, fill every section, delete these comments, and add a row to
docs/ui-handoffs/README.md. Write for a Claude session that has never seen the conversation with Redpillars. -->

- **Status:** Approved by Redpillars on <YYYY-MM-DD> (<quote their OK>). Not wired yet.
- **Built by:** a UI session with the `ui-building` skill, ClaudeUIKit <Kit.Version>.
- **Staged at:** `StarterGui.UIStaging.<Frames|HUD|System>.<FrameName>`
- **Goes to:** `StarterGui.Main.<Frames|HUD|System>.<FrameName>` <!-- or: replaces Main.Frames.X (edit copy) -->
- **Screenshots:** `docs/ui-handoffs/img/<FrameName>-pc.jpg`, `docs/ui-handoffs/img/<FrameName>-phone.jpg`

## What it is for

<!-- Redpillars' words first (quote them), then one or two plain sentences. What the Player does here. -->

## Element map

<!-- Paste Kit.Describe(<staged Frame>) output, then add a purpose to each line a script touches. Decor (addons, strokes,
gradients, textures) is not listed and must not be scripted. -->

```
<Kit.Describe output>
```

| Path (from the Frame) | Class | What the script does with it |
|---|---|---|
| `CloseButton` | TextButton | Closes the panel (`UIUtils.InitializeCloseButton`) |
| `...` | | |

## States

<!-- Every look the Frame has, and how each is shown. House pattern: one sibling per state, toggled with Visible
(Daily Rewards Claim / Locked, HUD AutoQueue On / Off), never a recolour in code. Sibling states share one Size, because
UIService.AddHoverConnections captures Size once. -->

| State | Shown by | Hidden |
|---|---|---|
| | | |

## Templates and sample content

<!-- Each runtime-cloned template (Assets.<Thing>Template), where clones go, and how they are ordered. Every piece of
placeholder text or image the script must replace ("BASIC", "$5,000", BasicPillow icon...). Spacer Frames the script
must skip when it walks a list (gap, Bottom). -->

## Behaviour Redpillars asked for

<!-- Exactly what they said each button / list should do, cooldowns, edge cases. Mark anything not decided as an open
question for the scripting session to ask. -->

## Wiring checklist (scripting session)

- [ ] Move the Frame from UIStaging into Main (same container), then delete the staged copy. Leave `UIStaging` itself.
- [ ] Panel: `ScreenUI.New(<InitCallback>)` with a `UIInitCallBacks.<Name>` module; `CloseButton` via
      `UIUtils.InitializeCloseButton`; registered in `GameUI` like the other ScreenUIs.
- [ ] Buttons: `UIService.AddButtonSounds`; hover via `UIService.AddHoverConnections` (`UseUIScale = true` for a
      button a layout sizes).
- [ ] Controller: the first button gets `GamepadMenus.SetFirstButton` (attribute `GamepadFirst`); display-only buttons
      `Selectable = false`.
- [ ] TextBoxes: `UIUtils.AddTouchFocus`.
- [ ] HUD pieces: shown / hidden only through `Utils.HUDVisibility`.
- [ ] Key hints: drawn through `Utils.InputDevice`, never a hard-coded key.
- [ ] Robux buttons: tag `RbxBuyButton` + `Id` attribute (left off in staging on purpose).
- [ ] <anything specific to this Frame>

## Open questions

<!-- Things Redpillars did not decide. -->
