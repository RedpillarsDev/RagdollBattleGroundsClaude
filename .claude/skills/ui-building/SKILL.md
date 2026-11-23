---
name: ui-building
description: Build new Ragdoll Battlegrounds UI Frames (panels, popups, HUD pieces) in Redpillars' house style as authored Gui only, with no scripts, for a separate Claude scripting session to wire up later. Use whenever Redpillars says "start a UI session", "UI session", or asks to build, design, make, lay out or mock up a UI frame, panel, menu, popup, screen, card or HUD element. Covers the ClaudeUIKit helper (measured recipes for black dotted panels with themed rims, glossy split-chrome GothamSSm titles, 3D key-cap buttons, item slots, shop cards, banners, level bars), the disabled StarterGui.UIStaging ScreenGui in the dev place where Frames are built, preview + Audit + PC and phone screenshots for Redpillars' approval, the naming contract scripts rely on, and the handoff note in docs/ui-handoffs/.
---

# UI building

A UI session **builds Frames, nothing else.** Another Claude session (the scripting session) wires them up later. Your
output is two things:
1. An approved Frame in `StarterGui.UIStaging` in **the dev place named in CLAUDE.md**, in Redpillars' look, with no
   scripts in it.
2. A handoff note, `docs/ui-handoffs/<FrameName>.md`, that tells the scripting session what every piece is for.

No LocalScripts, no ModuleScripts, no packets, no data keys, no tweens or animations. If the request needs behaviour,
write it down in the handoff note; don't build it.

> Harvested from Pillow Battles (2026-11-23), where Redpillars set these rules on 2026-10-21 and the kit was
> pixel-diffed against their own panels. The **workflow, layout rules, naming contract and gotchas are generic.**
> The **look** (themes, image ids, fonts) is Pillow Battles' and is marked as such: see "Status" before using it.

## Status (read first)

- **Look: not yet confirmed for Ragdoll Battlegrounds.** `UIKit.luau` rebuilds Pillow Battles' panels exactly. Before
  the first UI session, ask Redpillars: reuse the Pillow Battles look as-is, adapt it (new theme colours, title font),
  or match Ragdoll Battlegrounds' own authored Gui once it exists. Record the answer here.
- **If the look changes, re-measure, don't eyeball.** The kit was built by reading every value off Redpillars' authored
  Gui (strokes, gradients, ZIndex, aspect ratios), rebuilding a panel with the kit, and pixel-diffing the two (see
  "Kit test record"). Repeat that for Ragdoll Battlegrounds' reference panels, update the recipes and `Kit.Version`.
- **Image ids** in `Kit.Images` / `Kit.Icons` are Pillow Battles uploads. They load in another experience only if it is
  owned by the same creator (user or group). Check that before relying on them, and update `references/README.md` with
  this game's own atlases once it has its own art.
- **Kit assumptions to check against this game:** the live ScreenGui is `StarterGui.Main` with `Frames` / `HUD` /
  `System` containers; `Tutorial` and `AdminAbuse` ScreenGuis exist (used by `KnownImages` and the cleanup check);
  `Kit.CopyAuthored` strips the `RbxBuyButton` tag and `Id` attributes (PB's purchase convention). If Ragdoll
  Battlegrounds differs, edit `Kit.Staging`, `Kit.PreviewOn`, `KnownImages` and `BEHAVIOUR_TAGS`, then bump the version.
- `handoff-template.md`'s wiring checklist names Pillow Battles framework modules (`ScreenUI`, `UIInitCallBacks`,
  `UIService`, `UIUtils`, `GamepadMenus`, `Utils.HUDVisibility`, `Utils.InputDevice`). Swap them for this game's
  equivalents once its UI framework exists (`docs/claude/ui-and-input.md`).

## Rules for UI sessions (Redpillars, 2026-10-21)

- **Where:** the dev place named in CLAUDE.md, inside the staging ScreenGui `StarterGui.UIStaging`. The scripting
  session moves a Frame into the live ScreenGui when it wires it. UI is not part-building, so the `building` skill's
  building-place rule does not apply.
- **New Frames only. Never edit the live ScreenGuis** (`StarterGui.Main` and friends). To change an existing Frame,
  copy it into UIStaging as `<Name>_Edit` (`Kit.CopyAuthored`, which strips scripts and buy tags but makes the copy
  Visible, so set a panel copy back to `Visible = false`), change the copy, and hand it off with a list of what
  changed. Keep every value of theirs you didn't need to change pixel-identical.
- **Approval on every Frame:** screenshot it (PC and phone), show Redpillars, wait for their OK. Write the handoff note
  only after the OK.
- **Images: reuse existing only.** Every texture and icon must already be in the game (`references/README.md` lists
  them). If nothing fits, use the closest existing one as a placeholder and flag it in the handoff note. Never
  `generate_texture`, `upload_image` or `insert_asset` for UI art.
- **The look is Redpillars'.** Rebuild their recipes exactly; don't invent a new style (see "Don'ts").
- **Ask questions up front, every session** (below). Redpillars wants them in one batch, before building.

## Before you start

1. **Place.** Run `list_roblox_studios` fresh and pick the dev place by name. Check `get_studio_state` is Edit. If it
   isn't connected, say so and wait. Never fall back to another place.
2. **Peers.** Run `ListAgents`; tell any peer Claude you're in a UI session in `StarterGui.UIStaging`. Read the tail of
   `.coop/to-claude.md` and add your Frame (`StarterGui.UIStaging.<Container>.<FrameName>`) to the claimed paths in
   `.coop/STUDIO.md`. Remove the claim at the end. (`docs/claude/agent-workflow.md` has the full protocol.)
3. **Look at the references.** Open `references/README.md` and, with the Read tool, at least `panel-settings.jpg`,
   `panel-inventory.jpg`, `panel-shop.jpg` and the two atlases. Look at the panel closest to what you're building.
4. **Kit.** `UIKit.luau` (next to this file) is the source of truth. Its copy lives at `ServerStorage.ClaudeUIKit`.
   Check the installed version first:
   ```lua
   local M = game.ServerStorage:FindFirstChild("ClaudeUIKit")
   return M and loadstring(M.Source)().Version or "missing"
   ```
   If it's missing or older than `Kit.Version` in the file, install it by pasting the WHOLE file into this (the kit
   contains no `]==]`):
   ```lua
   local Src = [==[ <full contents of UIKit.luau> ]==]
   local F, Err = loadstring(Src)
   if not F then return "COMPILE ERROR: " .. tostring(Err) end
   local K = game.ServerStorage:FindFirstChild("ClaudeUIKit") or Instance.new("ModuleScript")
   K.Name = "ClaudeUIKit"; K.Source = Src; K.Parent = game.ServerStorage
   local Sum = 0
   for I = 1, #Src do Sum = (Sum + string.byte(Src, I) * (I % 251 + 1)) % 2147483647 end
   return "installed " .. F().Version .. " len=" .. #Src .. " sum=" .. Sum
   ```
   Then check it matches the repo file byte for byte (PowerShell, from the repo root):
   ```powershell
   $b = [IO.File]::ReadAllBytes(".claude\skills\ui-building\UIKit.luau"); [long]$s = 0
   for ($i = 0; $i -lt $b.Length; $i++) { $s = ($s + [long]$b[$i] * ((($i + 1) % 251) + 1)) % 2147483647 }; "len=$($b.Length) sum=$s"
   ```
   Why the checksum: pasting a 50 KB file through a tool call can silently drop or alter characters; len + sum proves
   the installed copy is the repo file. For a small kit change, edit the repo file, bump `Kit.Version`, and apply the
   same exact-string replacements to `ServerStorage.ClaudeUIKit.Source` in execute_luau (plain
   `string.find(S, Old, 1, true)`, unique match, then `loadstring` before writing). Then compare checksums. Every call
   loads it with `local Kit = loadstring(game.ServerStorage.ClaudeUIKit.Source)()`. Use loadstring, not require:
   require caches across execute_luau calls.
5. **Ask (AskUserQuestion, one batch, before any building).** Only what the code and references can't answer:
   - **What it is for** and what's on it: elements, any lists or grids and roughly how many entries.
   - **Where it lives:** a full panel (`Frames`), a popup or overlay (`System`), or a HUD piece (`HUD`).
   - **Theme:** one of the kit's themes, or "like <existing panel>". Offer the one that fits the content first (in PB:
     Silver for general menus, Gold for rewards and money, one colour per item category).
   - **States:** each look an element can have (CLAIM / LOCKED / CLAIMED, ON / OFF, affordable / not).
   - **Title text and icon** (from the icon atlas).
   - **Phones:** the same layout scaled down (the default), or a separate phone layout.
   - Don't ask about colours, fonts, strokes or spacing: those come from the recipes.

## Workflow

1. **Stage.** `local G = Kit.Staging()` makes (or finds) `StarterGui.UIStaging`: a **disabled** ScreenGui with Main's
   settings and `Frames` / `HUD` / `System` containers. Always leave it disabled: it ships with every publish, and
   disabled is what keeps a draft off Players' screens.
2. **Build in chunks.** Start each chunk with `Kit.Clear(Container, Name)` so it can be rerun. Typical order: shell
   (`Kit.Panel`), layout holders and lists, rows or cards, buttons, text. Name every piece a script will touch
   (contract below). A full panel's root stays `Visible = false`, as all of Redpillars' panels are.
3. **Preview and audit after every chunk:**
   ```lua
   local Kit = loadstring(game.ServerStorage.ClaudeUIKit.Source)()
   local Frame = game.StarterGui.UIStaging.Frames.MyPanel
   local Copy = Kit.PreviewOn(Frame, "PC", {Fill = function(C) --[[clone sample rows into the copy]] end})
   task.wait(0.5)
   return Kit.Audit(Copy)
   ```
   Then `screen_capture`. Do the same with `"Phone"` (749x361, a notched phone's safe area; `"SmallPhone"` is 667x375).
   Fix every Audit ISSUE. Read every note and either fix it or explain it in the handoff note.
   **Always finish with `Kit.PreviewOff()`.** `TEMP_UIPreview` lives in StarterGui, so a leftover one would cover every
   Player's screen after the next publish. Check that StarterGui holds only the game's own ScreenGuis plus UIStaging
   before you stop.
4. **Show Redpillars.** Show the PC and phone screenshots, name the theme and recipes used, and list the placeholders.
   Wait for their OK. They may tweak the staged Frame by hand in Studio: re-read it (`Kit.Describe`, or a fresh preview)
   before your next change, and never revert their edits.
5. **Hand off** once approved:
   - Copy the approved PC and phone captures from the paths `screen_capture` printed to
     `docs/ui-handoffs/img/<FrameName>-pc.jpg` and `-phone.jpg`.
   - Fill `handoff-template.md` (next to this file) as `docs/ui-handoffs/<FrameName>.md`, pasting
     `Kit.Describe(Frame)` into the element map.
   - Add a row to `docs/ui-handoffs/README.md`.
6. **Report:** where the Frame is staged, the handoff file, the placeholders, anything flagged. Remove your
   `.coop/STUDIO.md` claim.

## The kit's current look (Pillow Battles, measured 2026-10-21; every value is in `UIKit.luau`)

**In one line:** near-black panels with a faint dot texture, a black outline and a thin coloured rim. On them sit glossy
"split chrome" italic titles, 3D key-cap buttons with a coloured glow, and dark checkered item slots with silver rims.
Every piece of text has a thick black outline. Colour comes from gradients, not flat fills.

### Panel shell: `Kit.Panel(Container, Name, {Theme, Title, Icon, ClosePlacement})`
- Root Frame: Size `{0.6,0},{0.6,0}` centred, `UIAspectRatioConstraint` 1.8 (807x448 on a 1345x801 view), black,
  BackgroundTransparency 0.1 (Silver / Gold) or 0 (Cyan / Purple), `UICorner` 0.045.
- `UIStroke "Outer"`: black, 0.025 ScaledSize, ZIndex 1. `UIStroke "Inner"`: the rim, 0.008, 0.05 transparent, ZIndex
  2, with a UIGradient at -25 (light in the middle, darker at the ends).
- `UIShadow`: black, 0.5, BlurRadius `{0,20}`.
- `addons` Folder (decor): `whiteGlow` behind the title; `title` (GothamSSm Heavy Italic, left, overhanging the top edge
  at Y -0.058); `Icon` (square, overhanging at Y -0.08); `texture` (the dot tile, ZIndex -1) with a `shadow` vignette.
- `CloseButton`: red, square; "Classic" overhangs the top-right edge, "Corner" is centred on the corner.
- Smaller or wider panels change Size / Aspect only (a shop at 0.5 / 1.9, shifted left to leave room for an info box).

| Theme | Rim | Dots tint | Title chrome | PB used it for |
|---|---|---|---|---|
| Silver | white x grey-white-grey | 221,239,255 @0.8 | grey under white | General menus (Settings, Daily, Statistics) |
| Cyan | blue / cyan / blue | 7,243,255 @0.8 | sky blue under white | One item category + its shop |
| Purple | violet / lilac / indigo | 227,126,255 @0.8 | deep blue-violet under white | Abilities + their shop |
| Gold | 255,204,0 x silver | 255,228,25 @0.64 | yellow-orange under white, text 255,236,30 | Rewards, Robux shop |

### Text: `Kit.Text(Parent, Name, Text, Style, {...})`
- **Font is GothamSSm, always** (Heavy, ExtraBold or Bold, sometimes Italic). Text is white, `TextScaled`, `TextWrapped`.
- **Every text has a black `UIStroke`**: ScaledSize, Contextual, BorderStrokePosition Outer, ~0.06 (0.085 on button
  labels, coloured to match the button; 0.2 on bar numbers).
- **Split chrome:** a UIGradient at Rotation 270, where Time 0 is the bottom of the text. A tinted lower half meets a
  bright upper half at a hard step (0.47 -> 0.48). It makes the text look glossy.

| Style | Font | Gradient | Use |
|---|---|---|---|
| Title | Heavy Italic | theme chrome | Panel title |
| Heading | ExtraBold | yellow 255,238,0 -> pink 231,142,255 at 10 | Section titles inside a panel |
| Label / Value | Heavy | Row chrome | Settings / Statistics rows |
| Name | Heavy | Item chrome | Item names, "LV. 20" |
| Body | ExtraBold | none (white) | Descriptions |
| Small | Heavy Italic | Silver chrome | Card captions, "DAY 1", counters |
| Callout | Heavy Italic | orange-yellow "Sunset" at 90 | Promo lines ("1 FREE SPIN") |
| Rarity | Heavy, 181 grey | metal at 0 | Rarity line (the script recolours it) |
| Bar | Bold | Gold chrome, brown stroke 0.2 | Numbers on a progress bar |

### Buttons: `Kit.Button(Parent, Name, Style, {Text | Icon, Size, Square, Pill, Aspect})`
- A **TextButton with Text ""** whose BackgroundColor3 is the dark Base. A `highlight` Frame covers the top 0.925 (0.9 on
  Pill), so a strip of the Base shows at the bottom like a key cap.
- `highlight` carries the colour gradient (Rotation 270), a white inner sheen stroke (0.05, or 0.03 on Square, 0.65
  transparent, Inner), and the label (`highlight.TextLabel`: Heavy, white, stroke in the button's dark colour) or icon
  (`highlight.ImageLabel`).
- The button carries a black 0.065 Border stroke, `UICorner` 0.1 (0.2 on Pill), and a coloured `UIShadow` glow
  (BlurRadius `{0.05,15}`).
- Styles: **Green** (buy, claim, confirm, equip), **Purple** (Robux), **Red** (close, cancel), **Grey** (locked /
  unavailable, no glow), **Cyan** / **Violet** (square tab buttons with an icon).
- **One state per sibling.** CLAIM and LOCKED are two buttons at the same spot and Size, and a script toggles Visible.
  Same for ON / OFF. Don't build one button meant to be recoloured in code.

### Item slot: `Kit.Slot`, or copy the real template
- A dark 30,30,30 square (`SlotBase` image, black) with `UICorner` 0.075. Black stroke 0.05 at ZIndex 1, and a silver
  rim `Main` 0.02 at **ZIndex 2**. A checker `texture` at 0.9, an `icon` on top (ZIndex 2), a hidden `Lock` overlay.
  Square aspect.
- **If a script will fill it with real items and the game already has an authored slot template, copy that one**
  (`Kit.CopyAuthored(<template>, Parent)`): the inventory/shop code already knows its structure (rarity rim, Lock,
  Level).

### Cards, banners, info boxes, bars
- **`Kit.Card`** (shop offer card): a grey card the script tints by rarity colour, darker at the top, with a white rim
  (ZIndex 2), a white glow (`UIShadow "Glow"` 0.25, Blur `{0.2,0}`), a halftone fading upward, and an italic caption.
- **`Kit.Banner`** (Robux bundle): red -> yellow gradient, halftone, four sparkles, an orange glow, a big white
  Title-style line. Promos only.
- **`Kit.SubPanel`** (info box): 15,15,15 at 0.5, a dark teal rim, a black outline, `UICorner` 0.035.
- **`Kit.Bar`** (HUD level bar): a 15,15,15 track with black + grey outlines (grey ZIndex 2). The `Fill` has a chrome
  gradient and tiled `Stripes`. A script sets `Fill.Size.X.Scale`.
- **`Kit.Row`**: a Settings / Statistics row with a separator line called `seperator`. That's Redpillars' spelling;
  keep it.

### Colour rules
- **A UIGradient multiplies the colour under it** (BackgroundColor3, TextColor3, ImageColor3, UIStroke Color). Two
  equivalent ways: a white base under a coloured gradient, or a coloured base under a near-white gradient. A dark colour
  under any gradient stays dark (a rim went black at the ends when recoloured under a green gradient).
- **Tint sample cards with the game's real rarity colours** (read them from its rarity catalog) so screenshots are
  honest.
- **Effect tags** (animated gradients, rainbow strokes, colour cycles) are only usable if this game's client has
  handlers for them; list them from the tag handler before using any. Never put a purchase tag on a staged Frame.

## Layout rules (hard)

- **Scale, not Offset.** Every Size and Position is Scale; shapes are held by `UIAspectRatioConstraint`. Offset only
  for a measured pixel value, and say why in the handoff note. Text is TextScaled; cap it with a `UITextSizeConstraint`
  where it would grow silly on a big screen.
- **Never use a Scale height inside a Frame that grows** (AutomaticSize Y, or a section of an auto canvas): it grows
  with every row. Use an aspect constraint (width-driven), Offset, or content size. A direct child of a ScrollingFrame is
  fine: its Scale is of the window. Audit flags this.
- **A centre-anchored AutomaticSize box stops growing** (it capped at 96px): anchor it at the top and let it grow down.
- **`FitWithinMaxSize` with a zero-size axis renders 0x0** while its Size reads fine. Audit checks AbsoluteSize; also
  look at the capture.
- **Stroke order:** a black outline plus a coloured rim means the rim is ZIndex 2 and the black ZIndex 1. With equal
  ZIndex the order is undefined: 3 of 6 test slots lost their rim.
- **Lists:** `Kit.List` / `Kit.Grid` sort by LayoutOrder. A list gets a `Bottom` spacer (default 0.05) because
  AutomaticCanvasSize runs short and clipped the last row. Settings-style lists also start with a zero-size `gap`. Tell
  the scripting session about spacer Frames it must skip.
- **ZIndexBehavior is Sibling:** children draw over their parent, and ZIndex only orders siblings. Decor behind content
  (the dot texture) is ZIndex -1.
- **Safe area:** with DeviceSafeInsets, anything that must reach the true screen edge (a full-screen dim, a transition)
  needs its own `ScreenInsets.None` layer at runtime. Flag it in the handoff note; don't stretch past the safe area.
- **Phones:** no blanket UIScale (built once, rejected and reverted). Panels just scale down with the screen. Check the
  phone capture: the smallest text must still be readable. If it isn't, the fix is a bigger element, a
  `UITextSizeConstraint` MinTextSize, or asking Redpillars about a phone layout (pattern: a hidden layout template that
  code copies onto the live Frame on touch devices).
- **Hover that captures Size once** (PB's hover helper did): sibling state buttons must share one Size, and a button
  whose Size a layout owns needs a UIScale-based hover. Note it in the handoff.

## Naming and structure contract (what the scripting session relies on)

- **Containers:** full panels in `Frames`, popups/overlays/reveals in `System`, always-on pieces in `HUD`. Same names in
  UIStaging and the live ScreenGui.
- **Root name:** PascalCase, unique in its container, and the name it will keep when wired (an edit copy is
  `<Name>_Edit`).
- **Scripted pieces are PascalCase and unique among their siblings:** `CloseButton`, `Content`, `Assets`, `Info`,
  `Buttons`, `Claim`, `BuyCash`, `Submit`.
- **Decor keeps Redpillars' lowercase names:** `addons`, `highlight`, `texture`, `shadow`, `whiteGlow`, `title`,
  `seperator`, `gap`. Decor sits under `addons` / `Decor` Folders where it can, so scripts never walk it.
- **A button's words** are `<Button>.highlight.TextLabel`, its icon `<Button>.highlight.ImageLabel`.
- **Templates** a script clones go in an `Assets` Folder (a Folder never renders), named `<Thing>Template`, with
  `Visible = false`. Lists ship empty apart from spacers. Fill sample rows only in the preview copy
  (`Kit.PreviewOn(..., {Fill = ...})`), so screenshots look real and the staged Frame stays clean.
- **Controller:** set the attribute `GamepadFirst = true` on the button the panel should land on. Display-only buttons
  get `Selectable = false`.
- **Nothing executable or sellable:** no scripts, no purchase tags, no product Id attributes. `Kit.Audit` checks this.
- **No hard-coded input hints** ("Press E", "[Q]", "Click"): key hints are drawn at runtime per input device. Leave a
  placeholder label and note it.
- **TextBoxes** need touch-focus handling at runtime (phones can't type otherwise). Note each one.

## Don'ts

- **No "AI dashboard" look** (Redpillars, 2026-10-01: "you can easily tell its ai made"): a dark rounded card with a
  coloured accent bar down one edge, white flash overlays, pill-shaped tag chips, or thin sans-serif text without
  outlines. The house panel is also dark and rounded, but reads as the game's because of the exact recipe: dot texture,
  themed rim, split-chrome italic title with an overhanging icon, key-cap buttons. Use the recipe or ask.
- **No HUD panels.** HUD pieces are icons and outlined text on the world (`hud-lobby.jpg`). Notifications and kill
  receipts are bare text: GothamSSm ExtraBold, black outline, the game's gradients.
- **Don't restyle Redpillars' values.** When copying or extending one of their Frames, keep every spacing
  pixel-identical. A "cleaner" padding is a regression to them (a shop grid fix got reverted for this).
- No new images, no flat or line icons, no fonts other than the house font, no emoji in text.
- Don't touch the live ScreenGuis, and don't playtest. A UI session never needs Play mode: Edit mode lays StarterGui
  out, so AbsoluteSize and captures are real.

## Gotchas (measured 2026-10-21)

- **`screen_capture` doesn't show CoreGui.** A preview ScreenGui in CoreGui rendered nothing. Previews have to live in
  StarterGui, which is why `TEMP_UIPreview` exists and must always be removed (`Kit.PreviewOff`).
- **Edit-mode captures show the whole StarterGui** (`ShowDevelopmentGui` is on): the HUD sits behind anything you
  show. The preview's full-screen backdrop hides it.
- **ScaledSize stroke numbers are tiny** (0.025 on a panel, 0.06 on text). They are fractions, not pixels. A FixedSize
  stroke of 0.06 would be invisible.
- **Pixel checks:** the machine had no Python. Use PowerShell `System.Drawing` (`GetPixel`). Don't name a PowerShell
  function `Diff`: it's an alias for Compare-Object and silently runs that instead. Always measure a control pair that
  should differ (Settings vs Inventory measured 45.8 mean, kit vs original 3.3), so you know the instrument works.
- **Audit and capture the preview copy, never the staged Frame.** AbsoluteSize is computed even in the disabled
  UIStaging and on hidden Frames, but a staged panel is `Visible = false`, so Audit's 0x0 check (visible only) would
  skip everything and a capture shows nothing. PreviewOn makes the copy visible.
- **Effect tags don't animate in Edit mode.** An animated-gradient element looks static in a capture; say so.
- **AlwaysOnTop BillboardGuis never show in `screen_capture`.** For a world-space UI piece, flip a copy's AlwaysOnTop
  to false to look at it, or ask Redpillars to look in Studio.

## Files

- `UIKit.luau`: ClaudeUIKit, the recipes and helpers (`Panel`, `SubPanel`, `Text`, `Button`, `CloseButton`, `List`,
  `Row`, `Grid`, `Slot`, `Card`, `Banner`, `Bar`, `CopyAuthored`, `Staging`, `PreviewOn` / `PreviewOff`, `Audit`,
  `Describe`, plus `Images`, `Icons`, `Chrome`, `TextGradients`, `Themes`, `ButtonStyles`). Installed at
  `ServerStorage.ClaudeUIKit` in the dev place (a ModuleScript nothing requires). Its header still names Pillow Battles;
  update it on first edit.
- `references/`: Redpillars' Pillow Battles panels, the texture and icon atlases with every id, and the kit's test
  builds. `references/README.md` explains each one.
- `handoff-template.md`: the handoff note template (wiring checklist names PB modules; see "Status").
- `docs/ui-handoffs/` (repo root): one note per handed-off Frame, `README.md` (the index), `img/` (approved shots).
- `docs/claude/ui-and-input.md`: the UI framework the scripting session wires into (seeded from Pillow Battles). Read
  it only if a design question depends on how the code works.

## Kit test record (Pillow Battles, 2026-10-21)

The method to repeat if the look is re-measured for this game:
- **Settings rebuilt from the kit** (`kit-settings.jpg`): pixel-diffed against Redpillars' Settings at a mean 3.3/255
  over the panel. The control (Settings vs Inventory) measured 45.8. Leftovers were 1px text-edge shifts.
- **Inventory rebuilt** (`kit-inventory.jpg`): matched by eye after the slot rim fix (ZIndex 2).
- **Phone preview** (`kit-inventory-phone.jpg`): the panel measured 390x217 inside the 749x361 box.
- **Gallery** (`kit-gallery*.jpg`): cards, banner, bar, value row and state button rendered. The list's last item
  clipped until `Bottom` spacers were added (2026-10-21.3).
- **Every test build audited clean** (0 issues, 0 notes) and `TEMP_UIPreview` was removed.
