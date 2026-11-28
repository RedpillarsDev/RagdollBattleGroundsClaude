# UI references (captured 2026-10-21 in PillowBattles PROD)

> Carried over to Ragdoll Battlegrounds (2026-11-23). These are **Pillow Battles'** panels and image ids: the look the
> kit currently rebuilds. Whether Ragdoll Battlegrounds reuses this look is Redpillars' call (see SKILL.md, "Status").
> The ids load only in experiences owned by the same creator. Replace or extend this file with Ragdoll Battlegrounds'
> own panels and atlases once they exist.

Open several of these with the Read tool before every UI session. The `panel-*` images are Redpillars' own authored Gui
(previewed from copies, nothing in Main was touched). The `kit-*` images are the ClaudeUIKit rebuilding the same
recipes, to show what the kit produces. All are 1345x801 Studio-view captures unless noted.

## Redpillars' panels (the look to match)

| File | What it shows | Copy this from it |
|---|---|---|
| `panel-settings.jpg` | Settings: the **Silver** classic panel | The shell: near-black body with a faint dot texture and vignette, black outline + thin silver rim, chrome italic title with its icon hanging over the top-left edge, red X over the top-right edge. Rows: left-aligned chrome labels, faint separator lines, green pill switches |
| `panel-inventory.jpg` | Inventory, Pillows tab: the **Cyan** panel | Tab buttons stacked outside the left edge (square 3D buttons with an icon), item slot grid, the darker Info box on the right (name, rarity, slot, description, big green button), small italic counter "5/35" under the title, X centred on the corner |
| `panel-shop.jpg` | Pillow Shop: Cyan panel, smaller (0.5) and shifted left to fit the Info box outside it | Section headings in the yellow -> pink gradient, Shop offer cards (grey card, white rim, white glow, caption on top, slot in the middle, green price button), Info box sitting outside the panel |
| `panel-daily-and-group.jpg` | Daily Rewards (Silver) and Group Reward (**Gold** rim) | Reward cards with a ray glow behind a big icon, "+250" amount, green CLAIM vs grey LOCKED state buttons; Group Reward's orange-yellow italic callouts, a countdown line under the panel |
| `panel-robux-shop.jpg` | Robux Shop: gold-yellow panel without an icon | The loud bundle banner (red -> yellow gradient, halftone, sparkles, coloured glow), item slots with rarity rims, a tilted red timer, the Robux price button |
| `hud-lobby.jpg` | The HUD in the Lobby (Edit mode) | HUD style: no panels at all. Big glossy icons with italic outlined labels underneath, counters as dark rounded bars, task bars, the LV. bar with stripes. New HUD pieces follow this "icons and outlined text on the world" look |

## Image atlases (everything a session may reuse; no new images)

`atlas-textures.jpg`, numbered left to right, top to bottom (the kit names are `Kit.Images.*`):

| # | Kit name | Id | Used as |
|---|---|---|---|
| 1 | PanelDots | 91810447931922 | Tiled dots behind every panel (Tile {1.25,0},{1,0}, tinted, 0.64-0.8 transparent) |
| 2 | PanelVignette | 70540035647575 | Over the dots, ImageColor3 black at 0.75: darkens the panel edges |
| 3 | TitleGlow | 112746778941442 | Soft glow behind a panel title, tinted by theme |
| 4 | Halftone | 93516201443392 | Tiled on cards / banners, faded upward with a transparency gradient |
| 5 | SlotTexture | 74749189123574 | Checker inside an item slot (0.7 transparent, grey -> white -> grey gradient at -45) |
| 6 | SlotBase | 132329824971380 | The slot's own image, ImageColor3 black: a soft-edged dark square |
| 7 | InfoTexture | 133062913773000 | Dot fade on the Inventory hover info box |
| 8 | RewardRays | 124394564298284 | Ray glow behind a reward icon (Daily Rewards, tinted green) |
| 9 | Star | 72310521633513 | Sparkle on banners |
| 10 | Flare | 120663183882968 | Ray burst (Corner upsell) |
| 11 | Stripes | 300134974 | Diagonal stripes on a progress fill (Tile {0.2,20},{1,20}) |
| 12 | ChevronDots | 95336538825707 | Dotted chevron (crate slider) |
| 13 | Stud | 128202495740649 | Studded tile (Fuse button) |
| 14 | MegaTexture | 117705262329196 | Speckle (Robux Shop mega pack) |
| 15 | - | 137205992018476 | The "PILLOW BATTLES!" logo pattern of the intermission transition. Not for panels |
| 16 | Lock | 82896521097415 | Padlock on locked slots |
| 17 | PlayArrow | 137738277785943 | HUD collapse / minimise arrow |
| 18 | Notifier | 108525125108468 | Red "!" badge on a HUD button |

`atlas-icons.jpg` (`Kit.Icons.*` where named). Icons are glossy cartoon art with a thick dark navy outline; never mix in
flat or line icons.

| # | Id | Kit name / meaning |
|---|---|---|
| 1 | 107524617849727 | Gear (Settings, Group Reward) |
| 2 | 82507204060578 | Blue pillow with a clock (bundle reward) |
| 3 | 80693371362702 | Stopwatch with bars (`Stopwatch`) |
| 4 | 89613664665866 | One cash stack (`Cash`) |
| 5 | 82933223248196 | Magma pillow |
| 6 | 96521319656756 | Ice cube (Ice Zone) |
| 7 | 103389229837436 | Frozen pillow |
| 8 | 73907626507378 | Purple crown (`CrownVIP`) |
| 9 | 126740559322064 | Gold crown with gems (`CrownGold`, Ability Jester) |
| 10 | 71920286971989 | Four-leaf clover (`Clover`, luck) |
| 11 | 131338054346434 | Cash, small (`CashSmall`) |
| 12 | 117781081470227 | Cash stacks (`CashStacks`) |
| 13 | 81610045436678 | Cash pile (`CashPile`) |
| 14 | 124401940778389 | Cash bag (`CashBag`) |
| 15 | 86566584213926 | Cash chest (`CashChest`) |
| 16 | 138049227033777 | Calendar "31" (`Calendar`, Daily) |
| 17 | 98709872971123 | Cash stacks (Daily reward) |
| 18 | 81496818231568 | Red / blue spin arrows (`Spin`, free spin) |
| 19 | 92712437416399 | LR studio logo (`StudioLogo`) |
| 20 | 112788414369784 | Screenshot of the group page (Group Reward only) |
| 21 | 89910554123811 | Blue pillow (`Pillow`, Pillows tab / shop) |
| 22 | 115179436554288 | White basic pillow (`BasicPillow`, placeholder item) |
| 23 | 131113380111298 | Orange flame (`Ability`) |
| 24 | 138797620053232 | Purple flame (`AbilityShop`) |
| 25 | 81242473127316 | Bar chart (`Statistics`, Career) |
| 26 | 9563728434 | White arrowhead (`Arrow`) |
| 27 | 9563732504 | Circled plus (`PlusCircle`) |
| 28 | 14425197841 | White plus (`Plus`; rotated 45 it is an X) |
| 29 | 74859237619535 | Red basket (`Store`) |
| 30 | 99463218236674 | Trophy (`Trophy`, Wins) |
| 31 | 113701009501088 | White pillow (HUD attack control) |
| 32 | 75342708747074 | Blue dash arrow (`Dash`) |
| 33 | 15011943540 | Avatar placeholder (leaderboard) |
| 34 | 94583679587302 | Cash (currencies concept) |
| 35 | 108019077267080 | Cash stack (corner upsell) |
| 36 | 82252138114409 | Purple spiky ball (HUD Pillow level) |
| 37 | 94539448210782 | Red gem pointer (`RedGem`, Lucky Wheel) |
| 38 | 86216771097425 | Pink square (Lucky Wheel close background) |
| 39 | 15961470200 | Colour wheel (`ColorWheel`) |
| 40 | 77319404533832 | Cash stack (wheel slice) |
| 41 | 108336300645944 | Black circle (wheel background) |
| 42 | 97657642612554 | Double arrow (`DoubleArrow`, crate picker) |
| 43 | 91737950920112 | Sword (`Sword`, kills) |
| 44 | 113704665884764 | Skull (`Skull`, deaths) |
| 45 | 8152628560 | Down arrow (`DownArrow`, Tutorial) |

Pillow and Ability icons for real items live in the catalogs (`DataLibrarys.Pillows` / `.Abilities`); the scripting
session fills them in. A staged Frame uses `BasicPillow` or the item art above as a stand-in.

## Kit output (what ClaudeUIKit builds)

| File | Shows |
|---|---|
| `kit-settings.jpg` | `Kit.Panel` (Silver) + `Kit.List` + `Kit.Row` + pill `Kit.Button`s. Pixel-diffed against `panel-settings.jpg`: mean difference 3.3/255 (a different panel measured 45.8), the rest is 1px text-edge shifts |
| `kit-inventory.jpg` | Cyan panel with Corner X, tab buttons (`Cyan` / `Violet` styles with icons), `Kit.Grid` of `Kit.Slot`s (Lock, LV.), `Kit.SubPanel` info box, Green + Purple buttons |
| `kit-inventory-phone.jpg` | The same Frame in the Phone device box (749x361, a notched phone's safe area): the panel is 390x217 there |
| `kit-gallery.jpg` / `kit-gallery-scrolled.jpg` | Gold panel: `Heading` text, `Kit.Card`s tinted by rarity colour, `Kit.Banner` with `Title` + `Callout` text, a `Kit.Row` with a Value, `Kit.Bar` with `Bar` text, a Grey state button |
