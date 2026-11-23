# UI and input

> Harvested from Pillow Battles (2026-11-23). Patterns are proven there; verify against the live Ragdoll Battlegrounds place before relying on a specific path.

Controller specifics are in `console-support.md`. Engine-level traps are collected in `roblox-gotchas.md`.

## Framework architecture

- **One ScreenGui, `StarterGui.Main`, with three containers:**
  - `HUD`: always-on pieces (top bar, currencies, combat controls, tasks, bottom button bar).
  - `Frames`: full panels that toggle (Inventory, Shop, Settings, Daily Rewards...).
  - `System`: overlays, popups, reveals, round messages. HUD-hiding logic never touches it.
  - A separate ScreenGui only when a layer needs `ScreenInsets.None` (full-screen dims, transitions, crate reel) or its own DisplayOrder (the Tutorial arrow over panels). On a notched phone `DeviceSafeInsets` gives 749x361 of an 873x401 screen, so anything that must reach the true edge moves its Frame into its own `ScreenInsets.None` ScreenGui at Init.
- **`ScreenUI` class (OOP):** `ScreenUI.New(InitCallback)` → `:Init()` (the callback wires `self.MainFrame` etc.) → `:Open()` / `:Close()`, slid with `UIAnimations.ScreenSlide`, gated by a 0.55s cooldown.
  - **Gotcha:** `Open()` inside the cooldown is silently ignored. Anything that opens panels automatically (walk-in zones) must retry once after the cooldown. See `onboarding-and-lobby.md`.
  - `ScreenSlide` restores the cached authored Position (`UICache.LogOriginProperty`) before every slide. Anything that moves a panel (a drag handle) must update that cached origin too, or the next Close snaps it back to centre.
- **`UIController.SetCurrentUI` / `CloseCurrentUI`:** only one panel open at a time. Opening one closes the other.
- **Per-screen wiring** lives in `UIInitCallBacks/<Name>`: one module per screen, passed to `ScreenUI.New`. They're registered in a `GameUI.ScreenUIs.<Name>` table, typed by a `ScreenUITypes` union. Other systems (the Tutorial guide) read panel state off that table, requiring GameUI lazily to avoid require cycles.
- **HUD systems** are `GameUI.Systems.<Name>` modules, each with `Init()` called in order from `GameUI.Init`. Build tables of authored buttons defensively: a missing button warns, never crashes `GameUI.Init`.
- **Per-screen behaviour without touching the base class:** a screen can shadow `Open` on its own instance and call through to the base (Daily Rewards scrolls to the owed day on open).
- **Don't assume design tokens exist.** Pillow Battles had Studio `StyleSheet` instances that turned out to be unused stock defaults. The real GUI was hand-authored per instance.
- **Redpillars authors the art; code fills it.** Code clones authored templates and writes text, images and colours. It doesn't invent new visual elements.
- Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI` (`Classes.ScreenUI`, `UIController`, `UIInitCallBacks.*`, `Systems.*`, `Utils.UIUtils`), `ReplicatedStorage.System.Services.UIService` (`UIAnimations`, `UICache`, `UIEffects`).

## UI sessions: building Frames separately from wiring them

The full process is in this project's `.claude/skills/ui-building/` skill (already ported, along with ClaudeUIKit). The parts the *wiring* session needs to know:
- UI sessions build Frames with no scripts, in a **disabled** `StarterGui.UIStaging` ScreenGui with Main's containers. It ships with every publish, which is harmless while it stays disabled. Never enable it.
- Each approved Frame gets a note in `docs/ui-handoffs/<FrameName>.md`. **Wiring session:** read the note, move the Frame into the same container under Main, wire it, delete the staged copy, and mark it Wired in `docs/ui-handoffs/README.md`.
- A `StarterGui.TEMP_UIPreview` found in the place is a leftover preview copy. Delete it, because it would cover every player's screen after a publish.

## Style rules (Redpillars)

- **No "AI dashboard card" look (2026-10-01: "you can easily tell its ai made").** That means no dark rounded panel with a coloured accent bar down one edge, no white flash overlays, no pill-shaped tag chips, and no thin sans-serif text without outlines. The first compact kill receipt was built that way and stripped back to bare text the same day.
- **Default to bare outlined text.** GothamSSm (Heavy / ExtraBold / Bold, sometimes Italic), white, with a thick black `UIStroke` and the game's colour gradients. Let animation carry it. Notifications, kill receipts and HUD readouts are bare text, never HUD panels. If a design needs more than text, ask Redpillars or let them author the art. Don't invent a panel style.
- **No blanket mobile UIScale.** A `MobileScaling` system (x1.4 on phones) was built and reverted the same day (2026-09-28): it didn't look right. Panels just scale down with the screen. For a genuinely different phone layout, use the hidden layout-template pattern (Mobile control layout, below). Ask first.
- **Don't restyle Redpillars' values when fixing layout.** A Shop grid fix that also "cleaned up" padding was reverted. Keep their spacing pixel-identical and change only what the bug needs.
- **Don't grey things out by default.** Redpillars repeatedly kept buttons green in states Claude would have greyed (Claimed group reward, a Spin button at its cooldown, an OWNED shop price). Ask before greying.
- **One state per sibling.** CLAIM / LOCKED / CLAIMED, or ON / OFF, are separate authored buttons at the same spot and Size, and code toggles `Visible`. Don't build one button that code recolours.
- **No hard-coded input hints** ("Press E", "[Q]", "Click") in authored UI. Key hints are drawn at runtime per device (`console-support.md`).
- GothamSSm only, no emoji in text, no flat or line icons, no new images.
- **Pillow Battles house look, for reference:** near-black dotted panels with a themed rim, glossy "split chrome" italic titles, 3D key-cap buttons, and checkered item slots. The recipes are in `.claude/skills/ui-building/` (`UIKit.luau`). Whether Ragdoll Battlegrounds keeps that look is still to be confirmed with Redpillars.

## Layout rules

- **Scale, not Offset.** Hold shapes with `UIAspectRatioConstraint`. Use Offset only for a measured pixel value, and say why. Text is `TextScaled`, capped with `UITextSizeConstraint` where it would grow silly.
- **No Scale height inside a Frame that grows** (AutomaticSize Y, or a section inside an auto canvas): it grows with every row. A Shop grid's cells went from 103px to 271px tall as items were added. Make it width-driven instead: a `UIAspectRatioConstraint` under the UIGridLayout, plus `CellSize` Y `{0, 10000}` as a ceiling. Direct children of a ScrollingFrame are fine, since their Scale is of the window, not the canvas.
- **A centre-anchored AutomaticSize TextBox stopped growing at 96px.** Anchor it at the top (AnchorPoint 0.5,0) and let it grow downward.
- **AutomaticCanvasSize runs 1-4px short** and clipped the last row. End lists with a `Bottom` spacer Frame, and tell the wiring code to skip spacers.
- **Size text off a stable ancestor** (the panel's height), never off a box that grows with its text, or it feeds back.
- **TextScaled + TextWrapped splits lines between words** on narrow screens ("Diamond / Crate"). Non-breaking spaces don't help (Roblox breaks inside the "word"). The fix: a code-made `UITextSizeConstraint` capped at the largest size where each line fits on its own. Measure it on a hidden probe copy of the label with `TextService:GetTextBoundsAsync`, since width isn't linear in size, and refit on AbsoluteSize changes.
- **Stroke order:** a black outline plus a coloured rim needs the rim at ZIndex 2 and the black at ZIndex 1. At equal ZIndex the draw order is undefined (3 of 6 test slots lost their rim).
- **A UIGradient multiplies the colour under it.** A dark colour under any gradient stays dark. When code dyes a stroke that carries a coloured gradient, first convert the gradient to the same shading in greys, or non-matching colours go black at the ends.
- **Hover tweens capture Size once and tween back to it.** So sibling state buttons must share one Size, and a button whose Size a layout owns must grow through a `UIScale` instead (`AddHoverConnections(Frame, {UseUIScale = true})`). To show a button in a second shape, clone a second button rather than resizing the first.
- **Fade a whole group by tweening every transparency** to its recorded authored value (`CollectFadeTargets`). Use that rather than a CanvasGroup when children overhang the frame, because a CanvasGroup clips them.
- **Author popups and templates `Visible = false`,** and hide them at Init too. One authored visible flashed its placeholder text for about 3s at join.
- **Superseded animations:** bump a `ShowToken` / `DisplayToken` on every show, and have late steps of an older run check it and bail. Used by the server message banner, round message, crate displays and prompt billboards.

## HUD visibility: one choke point

`ReplicatedStorage.System.Utils.HUDVisibility` is the only way anything hides HUD elements.
- `Hide(Reason, Keep?)` / `Show(Reason)` act on every `Main.HUD` child (plus the Tutorial ScreenGui), never on `System` or `Frames`. **Reasons stack:** an element stays hidden while any reason hides it.
- `HideOnly(Reason, Names)` hides just the named elements (the Feedback button in a round, combat controls on touch outside play, Auto Play in a round). It stacks with `Hide` reasons.
- **`SetVisible(Element, Visible)` replaces direct `.Visible` writes in game code.** While the element is hidden by a reason, it records the wish and applies it on release. This exists because a `Visible = false` on an already hidden element fires no change event, so Controls came back on after a reward reveal.
- **Deferred signals echo your own writes back.** HUDVisibility read its own re-hide as "the game wants this hidden" and restored the bar hidden after the Tutorial. It now counts its own writes (`PendingOwnWrites`) and skips their events.
- Standard reasons: `"Tutorial"`, `"Reward"` (the whole reveal sequence), `"AbilityPick"`, `"FeedbackInRound"`, `"TouchOutOfPlay"`.
- Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.HUDVisibility`.

## Mobile / touch

- **TextBoxes need help on phones.** "Mobile players can't enter codes" had three suspects: authored boxes with `Active = false` (the touch falls through to the thumbstick or camera), a full-screen transparent Frame over every panel, and a box inside a ScrollingFrame. A GuiButton gets the tap in all three cases. `UIUtils.AddTouchFocus(Input, Area?)` sets the box Active and lays an invisible `TouchFocus` TextButton over it, shown only while touch is the device (live), which calls `Input:CaptureFocus()` to open the keyboard. **Every new TextBox should call it.**
  - When the TextBox is a thin strip inside a bigger box, put an invisible `FocusArea` button behind it covering the whole box.
  - A multi-line box needs `MultiLine = true`, or it shows one line whatever `TextWrapped` says.
- **`GuiObject.InputBegan` fires with `UserInputState.Change` when a finger already on the screen slides onto the object.** Only `Begin` is a real press. A slider that took Change as a press hijacked scroll swipes. Every touch handler built on `InputBegan` needs this check (sliders, custom prompt billboards).
- **A finger never fires `MouseLeave`.** Track the press yourself and end it on release anywhere, or when the target hides.
- **Sliders inside a ScrollingFrame:** leave a touch unclaimed until it moves 8px. Sideways claims it as a slider drag (pause the scroller). Vertical hands it to the scroller and leaves the value alone. A tap jumps the knob on release. Keep one counted lock per ScrollingFrame, not one per slider (two fingers restored "off" last and stuck it), and end a stale touch whose InputEnded never arrived on the next finger down. Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.UIInitCallBacks.SettingsUI.UISliderClass`.
- **Mobile control layout:** Redpillars authors a hidden `HUD.MobileControls`, a *layout template only* (a vertical stack on the right, with nothing wired). `GameUI.Systems.ControlsLayout` copies its Position/Size/AnchorPoint, UIListLayout fill/padding/alignment and each button's LayoutOrder onto the live `HUD.Controls` on touch. Every system that points at `HUD.Controls` (clicks, cooldown fills, icons, tutorial arrows, HUD visibility) keeps working untouched. Re-authoring the template changes the phone layout from the next join.
  - The two layouts must share button Sizes (hover captures Size once).
  - A "CENTERED CONTROLS" Settings row (touch only) lets phone players opt back to the PC row.
  - Hide combat controls on touch while not in play (`HideOnly("TouchOutOfPlay", {Controls = true})`).
  - Watch the lowest button against Roblox's own jump button, and overlap with other HUD on small phones.
- **Mobile shift lock emulation:** `CameraOffset` 1.75 right, plus the body yawed to the camera heading on RenderStep (priority Camera+1). It stands down while ragdolled, dead, seated, anchored or in the Physics state, which matters a lot for a ragdoll game. It's applied only in play (round, tutorial, dev area), never in the lobby. **Anything that special-cases shift lock must also check `MobileShiftLock.IsEnabled()`,** since no mouse is locked. Defaults and saving are in `console-support.md`. Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.MobileShiftLock`.
- **Device detection** follows the device live (a laptop with a touchscreen can switch). See `InputDevice` in `console-support.md`.
- **Readability:** at 1080p equivalent, 24px+ is comfortable and under 18px is hard. The TV pass method is in `console-support.md`.
- **Studio phone emulator:** simulated clicks land about 60px too high (calibrate with a `UserInputService.InputBegan` logger), it can't be switched on from a script, and dragging into the top bar leaves the finger down (send a mouse-up).

## Button feedback

- **`UIService.AddButtonSounds(Button)`:** a hover tick on MouseEnter **or controller SelectionGained**, and a click on Activated. Ticks are throttled to one per 0.05s and routed through the SFX volume group. It's independent of the hover look, so it works on buttons whose hover is owned elsewhere.
- **`UIService.AddHoverConnections(Frame, Opts)`:** the hover grow, also driven by SelectionGained/Lost, so controller selection looks like mouse hover. Use `UseUIScale` for layout-owned buttons.
- An authored template button that carries its own hover LocalScript gets bound straight to `.Activated`. Don't add UIService hover on top, or you stack two Size bounces.

## Overhead tags

- **Turn off Roblox's built-in health bars:** `StarterPlayer.HealthDisplayDistance = 0` and `NameDisplayDistance = 0`. On the client, also set `Player.HealthDisplayDistance = 0` and `SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)`, retrying while CoreGui starts up. Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.LifeCycle.OnJoin.CoreGuiInit`.
- **One custom billboard per character** (name + health %), built server-side by a shared builder that NPCs and dummies use too. The builder turns the Humanoid's own name tag off. Reference impl (Pillow Battles): `ServerScriptService.LifeCycle.OnCharacterAdded.OverHeadInit`, `ServerStorage.System.NPC.NPCOverhead`.
- **One tag line above the name, by priority:** staff tag (Owner / Admin / Moderator, from `AdminWhitelist`) > custom title > leaderboard rank title. Tag templates live in a Folder inside the billboard template, because a Folder never renders.
- **Custom titles:** set by Admin+ from the admin panel. They're trimmed, capped at 24 chars, and run through `TextService` broadcast filtering before saving. **A filtered title is refused, not saved as hashes.** Titles refresh live off the data changed signal and survive respawns.
- **Leaderboard rank title** (`#5  KILLS`): worked out server-side from each board's cached top 50 after every refresh and on join, so it costs no DataStore call. It's published as Player Attributes (`LeaderboardRank`, `LeaderboardRankMetric`) and the billboard rebuilds on change. The best (lowest) rank wins, with ties broken by a fixed metric order. #1/#2/#3 get gold/silver/bronze gradients. Only boards with a physical Model in the lobby count.
- **Testing trap:** an Owner always shows the staff tag, so a solo Studio test never shows lower-priority titles without a temporary bypass.

## Kill feed

- **The server broadcasts only credited kills** (the same rule as kill rewards) to everyone, lobby included: `{KillerName, VictimName (DisplayNames), KillerIsVIP, WeaponId}`. **In Studio only** (`RunService:IsStudio()`), credited dummy kills show too, so the feed can be tested solo.
- **Client:** the authored row is parked in the Frame's `Assets` at Init and cloned per kill. Names each carry a `UIFlexItem` (Fill) so they share whatever width the icon leaves, on any screen. Use a positive pixel padding: a negative scale padding made the names overlap the icon.
- **Motion:** slides in from the right on Back easing while growing from 0.5 scale (the grow on Quint, because Back on scale bounces). Newest on top, max 3. A 4th shrinks the oldest away in place (rows are centre-anchored), then its slot closes. Each row expires after 6s. Rows sit in a transparent Holder because the UIListLayout owns the Holder's Position.
- Reference impl (Pillow Battles): `StarterPlayer.StarterPlayerScripts.UI.GameUI.Systems.KillFeed`.

## Round message, server message, notifications

- **Round message:** a full-screen 50% dim with one big line over a small source label ("ROUND NEWS"). The packet is `{Message, Duration, Sound?}`. It fades every transparency to authored values while the line pops from 0.6 scale on Back, holds, then fades out. It lives in `System` so HUD hiding never touches it.
  - `Sound.TimeLength` reads 0 before the sound loads, so keep a one-shot 2D sound alive at least 3s rather than destroying it after TimeLength.
- **Server message banner:** no queue. Every show bumps a `ShowToken`, the newest takes over instantly, and an older show stops without hiding the newer one. Announcements are signed `Name[Rank]`.
- **Notifications** (level ups, purchases, errors): one at a time. A new one first sends the shown one out. The leaving one is lifted out of the UIListLayout onto the exact pixel spot it held, so the new one takes the slot with no jump. In: pop from 0.4 scale on Back Out (0.45s) while text and strokes fade in. Out: shrink to 0.7, rise, fade (0.25s), destroy. A `Leaving` attribute makes a second send-off a no-op.
- **Reward reveal queue:** every reward source (crate, daily reward, wheel, level reward, group reward) goes through one reveal module with one busy flag, so popups never overlap. Hold level-up reward popups while the player is in a state where they'd interrupt (Tutorial) and release them in order afterwards. Grant at once; delay only the display.

## Settings panel patterns

- **Toggle rows are runtime clones of one authored row,** with a shared `CreateToggleView` for the ON/OFF visuals. Rows can be conditional and follow the device live: touch-only rows (Shift Lock, Centered Controls), controller rows, rows hidden until a gamepass is owned.
- **Saving:** one packet, `SaveSettingRequest {SettingName, SettingValue}`. The server keeps a whitelist of names with a value ceiling (0/1 for toggles). The row's look follows the *saved* value through the data changed signal, never the press. The exception is a purely local, optimistic setting, like a layout switch.
- **Changing a default for existing players:** never change what an existing saved key means. Add a new key instead. Shift lock was reset to ON for everyone once through a new `ShiftLockChosenSinceReset` key, so no migration was needed.
- **Local-only visual settings** (hitbox transparency): a `DescendantAdded` watcher on the in-game folder applies it to parts by name, with an opt-out attribute (`IgnoreHitboxSetting`). New hitboxes must follow the naming to obey it.
- **Scroller under a heading:** give the ScrollingFrame its own Position/Size below the title rather than a spacer, and size rows as a fraction of the scroller's height.
- **Auto Play / auto-queue toggle on the HUD** (Redpillars' rules): saved, off for new players, never switches itself off, and switching it on mid-round waits for the next window. AFK lives in Settings only.

## Smaller reusable patterns

- **Player feedback inbox:** a panel with a TextBox. The server re-validates (control chars to spaces, trim, 1-500 chars), allows one send per 300s per UserId per server, and writes with `UpdateAsync` to a DataStore keyed by UTC day (spilling to `_2` past 1000 entries). Each entry carries platform, rounds played, account age and place version. The text is stored unfiltered and never shown in game. Redpillars reads it in Creator Dashboard → Data Stores Manager. Reference impl (Pillow Battles): `ReplicatedStorage.System.Services.FeedbackService`.
- **Generated "where to get it" lines** on locked items ("• Golden Crate (29.6%)", "• Shop ($75K)"), built from the live catalogs, so a drop-rate or price change updates them by itself. Reference impl (Pillow Battles): `ReplicatedStorage.System.Utils.ItemSources`.
- **Horizontal ScrollingFrame + mouse wheel:** the wheel never scrolls a sideways track. While the panel is open, bind the wheel with `ContextActionService` at High priority and sink it (no camera zoom), and unbind on close. Bumpers page it on a controller.
- **Rarity dressing:** one helper styles any label or card by Rarity (`PrimaryColor` fill, two-stop `ColorGradient`), reused by Inventory, Shop, profile and the ability pick.

## Testing tips (Studio + MCP)

- When a click won't land (the mouse is `LockCenter` in a round, or a button sits under the top bar), set `GuiService.SelectedObject` to the button and send Return.
- The first injected click after Play starts is often lost to window focus. Retry once before calling a button dead.
- Some tabs only respond to an explicit mouseButtonDown, a wait, then mouseButtonUp, not a single click event.
- Requiring item catalogs from `execute_luau` in Edit mode can hang for 120s when they pull in networking modules. Test those from a Play-only LocalScript.
- `screen_capture` doesn't show CoreGui or AlwaysOnTop BillboardGuis. Effect tags (animated gradients) look static in Edit-mode captures.
- To fake a device, override `InputDevice.Get` on the shared module table from a TEMP LocalScript. `PreferredInput` can't be set from a script.
