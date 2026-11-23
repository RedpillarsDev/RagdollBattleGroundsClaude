# Console and controller support

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

**Caveat:** Pillow Battles built phases 1-5 of this plan but **never tested on real controller hardware** (Redpillars had none). Everything below was driven by scripted input in Studio. "Unverified until hardware" is listed at the end.

## The 7-phase plan (reuse it)

1. **Bindings:** InputActions with a keyboard/mouse binding plus a `Gamepad` binding for every combat action.
2. **Combat feel + icons:** hold-to-attack, and controller button icons wherever a key is shown (HUD badges, prompts, tutorial banners).
3. **Menus:** real D-pad navigation through `GuiService.SelectedObject`.
4. **Per-screen pass:** where each panel lands, unselectable display buttons, sliders, list rows, modal skips.
5. **TV pass:** measure text sizes, edge safety and contrast. Apply only what Redpillars picks (no blanket scale-up).
6. **Platform checks:** Group/Favorite prompts and Robux purchases on console.
7. **Enable Console in the Creator Dashboard** and test on hardware.

## Redpillars' decisions (Pillow Battles mapping; re-confirm for Ragdoll Battlegrounds)

- **Combat:** RT attack, LT ability, B dash, X interact (proximity prompts), A jump (Roblox default), Y inspect player, R3 shift lock, LB/RB switch tabs, View/Select opens the menu bar. B means Back whenever a menu has a use for it.
- **Menus:** real D-pad navigation, not the virtual cursor. A selected button gets the hover grow plus a thin white outline.
- **World SurfaceGui leaderboards stay read-only on a controller** (no scrolling). Nothing to build.

## How it's wired

- **Bindings (InputContext / InputAction / InputBinding):** one InputBinding per device under `StarterPlayerScripts.Keybinds.MainGame.<Action>`: the keyboard/mouse one, plus one named `Gamepad`. A rebind is a Studio-only change, and every on-screen label follows it because labels read the binding.
- **`InputDevice` util (client), the one source of truth for the device:**
  - `Get()` returns `"KeyboardAndMouse" | "Gamepad" | "Touch"`, read off `UserInputService.PreferredInput`. `IsTouch()`, `OnChanged(cb)`.
  - `GetGamepadKey(Action)` / `GetKeyboardKey(Action)` read the InputAction's bindings. An action carries two bindings, so always ask for the device-specific one.
  - `GetButtonImage(KeyCode)` returns the plugged-in controller's own art (Xbox or PlayStation).
  - `DressBadge(Badge, KeyLabel, GamepadKey)`: key text on keyboard, a `GamepadIcon` ImageLabel on controller, hidden on touch.
  - Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.InputDevice`.
- **Hold to attack (controller only):** while `AttackAction:GetState()` is true, re-call the attack every Heartbeat. Start it only when the press came from a gamepad (`GetLastInputType`). The attack's own cooldown caps it, so holding is never faster than perfect tapping. Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.LifeCycle.OnJoin.KeybindsInit` (`HoldToSwing`).
- **Proximity prompts:** set `GamepadKeyCode = ButtonX`. A custom-styled prompt swaps its badge the same way: key name on PC, button icon on controller, `TAP` on touch. Reference impl (Pillow Battles): `ReplicatedStorage.System.Libs.ProximityPromptService.PromptClass`.
- **Inline icons in text banners:** text followed by the button icon, placed off the label's `TextBounds`. The label gives up the icon's width while it shows and gets its authored Size back after.

## Menus: `GamepadMenus`

Real navigation through Roblox's own `GuiService.SelectedObject`. Started last in `GameUI.Init`. Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.Systems.GamepadMenus`.
- **View/Select** (a `Gamepad`-only binding on ButtonSelect) puts the selection on the HUD bottom bar, or inside the panel already open. Pressed while anything is selected, it hands the controller back to the game, and an open panel stays open.
- **A panel opened by walking into a zone opens with nothing selected,** so walking through a zone never captures the stick.
- **Opening a panel while something is selected** (A on a bar button) carries the selection into the panel, **after the slide-in finishes** (wait until the MainFrame's AbsolutePosition stops changing). **Roblox throws a selection on an off-screen button straight back:** a pick inside a panel still sliding up landed on the bar's first button instead. For the same reason, a candidate's centre must be inside its ScreenGui.
- **First button:** the one carrying the **`GamepadFirst` attribute**, else the first in reading order (top to bottom, then left to right). A button named `*close*` is only the fallback. **Hard rule for new screens: set `GamepadFirst` on the button the panel should land on.**
- **B:** closes the open panel, or leaves the bar.
  - The Dash action asks `GamepadMenus.HandleBack()` first for a gamepad press. A `UserInputService` listener also calls it, **because a selected GuiButton sinks B** before the InputAction sees it.
  - Inside `SAME_PRESS_WINDOW` (0.15s), a press already taken answers true again, so one B never both closes a panel and dashes.
  - A modal that must not close (a wheel mid-spin) still eats the press.
  - Context buttons can claim B when nothing is selected (Pillow Battles: the 1V1 pad's Exit button).
- **Containment:** the bar and each panel's MainFrame get `SelectionGroup = true` with `SelectionBehavior*` = `Stop` on every side, so the D-pad never wanders onto the HUD behind a panel. In a round, the in-round button group (Return to Lobby) is contained the same way so the D-pad can't slide onto combat buttons.
- **Clean-up:** drop a selection whose button left the screen (a round hid the bar, the Tutorial hid the HUD). Closing a panel drops a selection that was inside it.
- **Look:** `PlayerGui.SelectionImageObject` = a 2px white UIStroke outline with an 8px corner. The grow comes from the shared hover tween hooked to SelectionGained/Lost. Template buttons with their own hover LocalScripts need SelectionGained/Lost hooked too.
- **`GuiService.AutoSelectGuiEnabled = false`.** Roblox's own Select-button auto-pick fights a custom View/Select.

## Per-screen patterns (phase 4)

- **`SetFirstButton(Button, IsFirst)` wherever a screen decides what the player should see:** the slot of a just-received item, the owed day's Claim, Spin, or the spin bundle when out of spins. A button is only selectable while it's actionable; otherwise fall back to Close.
- **Moving onto an item slot previews it** (SelectionGained runs the slot's click), so Equip is one move over.
- **Display-only buttons get `Selectable = false`** (reward icons in a bundle card, item icons on a pick screen). Reading order then lands on the first real action.
- **Sliders:** make the track the selectable part (the knob is a plain Frame). Set `NextSelectionLeft/Right` to the track itself so left/right stays put. D-pad left/right, or a stick push past 0.6, steps the value by 0.1 and saves like a released drag.
- **Dynamic links between groups:** set `NextSelectionUp/Down` on each selection change (bar ↔ the lowest task row, and back to the bar button it came from). Skip rows that are slid off screen.
- **Scrolling lists of non-buttons** (a stats page): give each row a transparent full-row TextButton so the D-pad steps down the list and the ScrollingFrame follows. Mark the first row `GamepadFirst`.
- **Modal choice screens** (a starter pick): the first choice is `GamepadFirst` and is re-selected if B or View drops it. Choice buttons are `Modal = true`, which also frees a shift-locked mouse.
- **Hiding a panel temporarily** (the wheel hides during its reveal): drop its selection, then give it back when the panel shows again.
- **LB / RB:** switch tabs on tabbed panels (with a bounce on the tab), or page a sideways track. They do nothing while the panel is closed.
- **Reveals and result screens:**
  - B = skip, the same as their Close. It only cuts the popup's hold (never a reel), and only after a minimum shown time (0.5s). A press before that is saved and skips once the minimum is reached. B never dashes while a reveal is up.
  - **Tap / click anywhere also skips (Redpillars, 2026-10-20), but an early tap is dropped, not saved up.** An attack still being thrown when the round ends or a reward pops must not wipe it unseen. The result screen accepts taps only once every card is in. Use `gameProcessed`-agnostic `UserInputService.InputBegan` (MouseButton1 or Touch).
  - **A skipped popup closes faster** (slide-out 0.3 → 0.12s, dim fade 0.35 → 0.15s, the reel stays hidden). A popup that times out closes normally.

## Shift lock on controller and console

- **Console detection:** `GuiService:IsTenFootInterface()`.
- **The Settings SHIFT LOCK row follows the device live.** It shows for touch and controller (and every device in Studio). Where it's hidden, the lock is off whatever was saved, and picking the controller back up restores the saved choice. **R3** toggles the same saved setting.
- **Final rules (Redpillars, 2026-10-21):**
  - **Applied only in play** (live round, tutorial, dev area), never in the lobby. The row still shows and switches the setting anywhere.
  - **R3 only toggles in play,** so a stray stick click in the lobby can't flip it with nothing to see.
  - **ON by default for touch AND console**, applied through a new key `Settings.ShiftLockChosenSinceReset`: not chosen since the reset + (console or touch) → ON, otherwise the saved value. A first toggle sets the key.
  - Show it OFF until the save has loaded, so nobody sees a flash of it on while joining.
- Implementation of the lock itself: `ui-and-input.md` → Mobile shift lock emulation.

## TV pass (phase 5) method

- **Measure every visible text's rendered glyph size,** converted to 1080p: `sqrt(TextBounds.X * TextBounds.Y / (k * w))`, with `k` and `w` from `TextService:GetTextBoundsAsync` at size 100. Rule of thumb: 24px+ is comfortable, under 18px is hard.
- **Usual offenders:** TextScaled descriptions in small boxes (long ones shrink to ~17px), and grey-on-dark or highly transparent labels (counters, "DAY n").
- **Outer 5% of the screen:** kill feed, close buttons and HUD bars near the edges. Whether Roblox's console safe area clears them is unknown until hardware, so leave them until a real console test.
- Apply only Redpillars' picks. Pillow Battles made the description box taller and more opaque (transparency 0.65 → 0.35), and brightened grey labels to white.

## Testing without a controller

- `UserInputService.PreferredInput` can't be set from a script. Override the util instead, from a TEMP LocalScript: `InputDevice.Get = function() return "Gamepad" end`, then re-run the badge Init. Every caller follows, because they share the module table.
- `InputAction:Fire(true)` / `Fire(false)` drives `GetState` and fires Pressed (View/Select included).
- Setting `GuiService.SelectedObject` from a script fires SelectionGained like a real controller.
- The test player usually lands in the Tutorial (Studio wipes the profile), where the HUD is hidden. Call `HUDVisibility.Show("Tutorial")` for menu tests.
- **Lesson from a test run:** a local function moved below its caller compiles as a nil global. The error left a busy flag (`IsUnboxing`) stuck true and blocked every later reveal. After moving code around, scan for locals used before their definition, and release busy flags in a `pcall`/finally path.
- **Checklist artifact:** Pillow Battles handed Redpillars a tick-box test page (ticks saved in their browser, plus a "Copy results" text summary to paste back). It's worth repeating for hardware tests.

## Unverified until a controller is plugged in

- The hold-to-attack loop and trigger feel.
- Whether Roblox delivers B to the Dash InputAction while a button is selected (both paths are handled).
- D-pad movement inside each panel.
- Console safe-area clearance of edge UI.
- Group/Favorite prompts and Robux purchase prompts on console (phase 6).
