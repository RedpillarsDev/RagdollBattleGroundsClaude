--!nocheck
--[[ ClaudeUIKit: builds Pillow Battles UI Frames out of Redpillars' own recipes.

Source of truth: .claude/skills/ui-building/UIKit.luau in the PillowBattlesClaude repo. The copy in PillowBattles PROD
lives at ServerStorage.ClaudeUIKit (a ModuleScript, never required at runtime).

Load it inside execute_luau with:
	local Kit = loadstring(game.ServerStorage.ClaudeUIKit.Source)()
loadstring, not require: require caches across execute_luau calls, so an edited kit would not reload.

Every value below was measured off Redpillars' authored Gui in StarterGui.Main on 2026-10-21 (Settings, DailyRewards,
Statistics, Feedback, GroupReward, Inventory, Shop, RobuxShop, HUD.Levels / HUD.Tasks). The kit only re-creates that
look; it never invents a new one. If Redpillars restyles a panel, re-measure and update the recipe here.

Conventions every helper follows:
- Sizes and positions are Scale, never Offset, so a Frame looks the same on every screen. Shapes are held by
  UIAspectRatioConstraint. Text is TextScaled.
- UIStrokes use StrokeSizingMode ScaledSize, so outlines stay in proportion on a phone. When an element has a black
  outline AND a coloured rim, the rim is ZIndex 2 and the black ZIndex 1 (as authored). With equal ZIndex the draw
  order is undefined and the rim vanishes on some copies (measured: 3 of 6 slots).
- Decor children keep Redpillars' lowercase names (addons, highlight, texture, shadow, whiteGlow, title, seperator);
  anything a script will look up is PascalCase and unique among its siblings.
- Nothing the kit makes has a script, a behaviour tag or a ProductId in it.
]]

local Kit = {}
-- Bump on every change to this file. The skill compares it with the copy installed in PROD.
Kit.Version = "2026-10-21.4"

local StarterGui = game:GetService("StarterGui")

local function rgb(R, G, B) return Color3.fromRGB(R, G, B) end
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(0, 0, 0)

-- Seq({0, 255,0,0}, {1, 255,255,255}) -> ColorSequence
local function Seq(...)
	local Points = {}
	for _, K in ipairs({ ... }) do
		table.insert(Points, ColorSequenceKeypoint.new(K[1], rgb(K[2], K[3], K[4])))
	end
	return ColorSequence.new(Points)
end
Kit.Seq = Seq

-- NSeq({0, 0}, {1, 1}) -> NumberSequence
local function NSeq(...)
	local Points = {}
	for _, K in ipairs({ ... }) do table.insert(Points, NumberSequenceKeypoint.new(K[1], K[2])) end
	return NumberSequence.new(Points)
end
Kit.NSeq = NSeq

--------------------------------------------------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------------------------------------------------
Kit.FontFamily = "rbxasset://fonts/families/GothamSSm.json"

-- Kit.Font("Heavy", true) -> GothamSSm Heavy Italic. Weights in use: Heavy (titles, labels, buttons), ExtraBold
-- (body text, section headings), Bold (bar numbers).
function Kit.Font(Weight, Italic)
	return Font.new(Kit.FontFamily, Enum.FontWeight[Weight or "Heavy"], Italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
end

--------------------------------------------------------------------------------------------------------------------
-- Images already in the game (reuse only; see the skill's references/README.md for pictures)
--------------------------------------------------------------------------------------------------------------------
Kit.Images = {
	PanelDots = "rbxassetid://91810447931922", -- tiled dot pattern behind every panel (Tile {1.25,0},{1,0})
	PanelVignette = "rbxassetid://70540035647575", -- edge darkening over the dots (ImageColor3 black, 0.75)
	TitleGlow = "rbxassetid://112746778941442", -- soft glow behind a panel title
	Halftone = "rbxassetid://93516201443392", -- diagonal halftone, tiled on cards and banners
	SlotTexture = "rbxassetid://74749189123574", -- checker texture inside an item slot
	SlotBase = "rbxassetid://132329824971380", -- soft-edged square under an item slot (ImageColor3 black)
	InfoTexture = "rbxassetid://133062913773000", -- dot fade used on the Inventory hover info box
	RewardRays = "rbxassetid://124394564298284", -- sun rays behind a reward icon
	Star = "rbxassetid://72310521633513", -- four-point sparkle
	Flare = "rbxassetid://120663183882968", -- ray burst
	Stripes = "rbxassetid://300134974", -- diagonal stripes on a progress fill
	ChevronDots = "rbxassetid://95336538825707", -- dotted chevron pattern
	Stud = "rbxassetid://128202495740649", -- studded tile
	MegaTexture = "rbxassetid://117705262329196", -- noisy speckle
	Lock = "rbxassetid://82896521097415", -- padlock
	PlayArrow = "rbxassetid://137738277785943", -- rounded play arrow (HUD collapse buttons)
	Notifier = "rbxassetid://108525125108468", -- red "!" badge
}

Kit.Icons = {
	Gear = "rbxassetid://107524617849727",
	Calendar = "rbxassetid://138049227033777",
	Statistics = "rbxassetid://81242473127316", -- bar chart ("Career")
	Pillow = "rbxassetid://89910554123811", -- blue pillow (Pillows tab)
	BasicPillow = "rbxassetid://115179436554288", -- white pillow (placeholder item icon)
	Ability = "rbxassetid://131113380111298", -- orange flame (Abilities tab)
	AbilityShop = "rbxassetid://138797620053232", -- purple flame
	Store = "rbxassetid://74859237619535", -- red basket
	Trophy = "rbxassetid://99463218236674",
	Sword = "rbxassetid://91737950920112",
	Skull = "rbxassetid://113704665884764",
	Dash = "rbxassetid://75342708747074",
	Spin = "rbxassetid://81496818231568", -- red/blue refresh arrows ("free spin")
	ColorWheel = "rbxassetid://15961470200",
	Stopwatch = "rbxassetid://80693371362702",
	CrownVIP = "rbxassetid://73907626507378", -- purple crown
	CrownGold = "rbxassetid://126740559322064",
	Clover = "rbxassetid://71920286971989", -- luck
	Cash = "rbxassetid://89613664665866", -- one stack
	CashSmall = "rbxassetid://131338054346434",
	CashStacks = "rbxassetid://117781081470227",
	CashPile = "rbxassetid://81610045436678",
	CashBag = "rbxassetid://124401940778389",
	CashChest = "rbxassetid://86566584213926",
	Plus = "rbxassetid://14425197841",
	PlusCircle = "rbxassetid://9563732504",
	Arrow = "rbxassetid://9563728434", -- white arrowhead
	DownArrow = "rbxassetid://8152628560",
	DoubleArrow = "rbxassetid://97657642612554",
	RedGem = "rbxassetid://94539448210782",
	StudioLogo = "rbxassetid://92712437416399",
}

--------------------------------------------------------------------------------------------------------------------
-- Colour recipes
--------------------------------------------------------------------------------------------------------------------
-- "Chrome" text gradients: Rotation 270, so Time 0 is the BOTTOM of the text. The hard step at 0.47 -> 0.48 is the
-- glossy split: a tinted lower half under a bright upper half.
Kit.Chrome = {
	Silver = Seq({ 0, 179, 180, 194 }, { 0.47, 179, 180, 194 }, { 0.48, 220, 234, 255 }, { 1, 255, 255, 255 }), -- panel titles
	Row = Seq({ 0, 191, 200, 216 }, { 0.47, 208, 211, 216 }, { 0.48, 221, 253, 255 }, { 1, 255, 255, 255 }), -- row titles / values
	Item = Seq({ 0, 231, 236, 245 }, { 0.47, 210, 210, 216 }, { 0.48, 221, 253, 255 }, { 1, 255, 255, 255 }), -- item names, LV.
	Cyan = Seq({ 0, 82, 218, 255 }, { 0.47, 151, 210, 235 }, { 0.48, 221, 253, 255 }, { 1, 255, 255, 255 }),
	Purple = Seq({ 0, 51, 33, 255 }, { 0.47, 40, 6, 235 }, { 0.65, 221, 253, 255 }, { 1, 255, 255, 255 }),
	Gold = Seq({ 0, 255, 238, 0 }, { 0.47, 240, 181, 31 }, { 0.48, 255, 255, 255 }, { 1, 255, 255, 255 }),
	Blue = Seq({ 0, 25, 163, 255 }, { 0.47, 40, 126, 240 }, { 0.48, 255, 255, 255 }, { 1, 255, 255, 255 }),
}

-- Other text gradients, each with the Rotation it was authored at
Kit.TextGradients = {
	Heading = { Seq({ 0, 255, 238, 0 }, { 1, 231, 142, 255 }), 10 }, -- Shop section titles: yellow -> pink
	Metal = { Seq({ 0, 159, 160, 176 }, { 0.49, 255, 255, 255 }, { 1, 159, 160, 176 }), 0 }, -- rarity line
	Sunset = { Seq({ 0, 255, 122, 34 }, { 0.28, 244, 255, 41 }, { 0.75, 248, 218, 50 }, { 1, 255, 145, 67 }), 90 }, -- Group Reward callouts
	TaskTitle = { Seq({ 0, 228, 229, 243 }, { 0.43, 228, 229, 243 }, { 0.44, 255, 255, 255 }, { 1, 255, 255, 255 }), 270 },
	InProgress = { Seq({ 0, 34, 251, 255 }, { 0.47, 39, 97, 255 }, { 1, 30, 109, 255 }), 90 },
	Completed = { Seq({ 0, 129, 255, 32 }, { 0.53, 38, 107, 37 }, { 1, 179, 255, 38 }), 90 },
}

-- Panel themes: the rim, the dot texture tint, the title glow and the title chrome
Kit.Themes = {
	-- Settings, Daily, Statistics, Feedback
	Silver = {
		PanelTransparency = 0.1,
		RimColor = WHITE,
		Rim = Seq({ 0, 181, 181, 181 }, { 0.5, 255, 255, 255 }, { 1, 181, 181, 181 }),
		Texture = rgb(221, 239, 255), TextureTransparency = 0.8,
		Glow = rgb(226, 253, 255), GlowTransparency = 0.8,
		Title = Kit.Chrome.Silver, TitleColor = WHITE,
	},
	-- Pillows / Pillow Shop
	Cyan = {
		PanelTransparency = 0,
		RimColor = WHITE,
		Rim = Seq({ 0, 15, 141, 238 }, { 0.5, 1, 242, 255 }, { 1, 15, 141, 238 }),
		Texture = rgb(7, 243, 255), TextureTransparency = 0.8,
		Glow = rgb(121, 255, 255), GlowTransparency = 0.75,
		Title = Kit.Chrome.Cyan, TitleColor = WHITE,
	},
	-- Abilities / Ability Shop
	Purple = {
		PanelTransparency = 0,
		RimColor = WHITE,
		Rim = Seq({ 0, 143, 27, 238 }, { 0.5, 174, 61, 255 }, { 1, 34, 7, 238 }),
		Texture = rgb(227, 126, 255), TextureTransparency = 0.8,
		Glow = rgb(196, 20, 255), GlowTransparency = 0.82,
		Title = Kit.Chrome.Purple, TitleColor = WHITE,
	},
	-- Group Reward's gold rim with the Robux Shop's yellow dots and gold title
	Gold = {
		PanelTransparency = 0.1,
		RimColor = rgb(255, 204, 0),
		Rim = Seq({ 0, 181, 181, 181 }, { 0.5, 255, 255, 255 }, { 1, 181, 181, 181 }),
		Texture = rgb(255, 228, 25), TextureTransparency = 0.64,
		Glow = rgb(251, 255, 7), GlowTransparency = 0.8,
		Title = Kit.Chrome.Gold, TitleColor = rgb(255, 236, 30),
	},
}

-- 3D "lip" buttons: a dark Base shows under a Fill that is 0.925 tall, like a key cap.
-- Fill colour x Gradient = what you see (a gradient multiplies the colour under it).
Kit.ButtonStyles = {
	Green = { Base = rgb(3, 89, 0), Fill = WHITE, Gradient = Seq({ 0, 14, 203, 0 }, { 0.58, 4, 255, 0 }, { 1, 200, 255, 0 }), TextStroke = rgb(1, 56, 0), Glow = rgb(26, 255, 0), GlowTransparency = 0.5 },
	Purple = { Base = rgb(47, 4, 89), Fill = WHITE, Gradient = Seq({ 0, 77, 18, 203 }, { 0.58, 71, 38, 255 }, { 1, 208, 133, 255 }), TextStroke = rgb(4, 0, 56), Glow = rgb(247, 17, 255), GlowTransparency = 0.5 },
	Red = { Base = rgb(125, 0, 0), Fill = rgb(255, 98, 98), Gradient = Seq({ 0, 255, 0, 0 }, { 1, 255, 255, 255 }), TextStroke = rgb(56, 0, 0), Glow = rgb(255, 124, 124), GlowTransparency = 0 },
	Grey = { Base = rgb(89, 89, 89), Fill = WHITE, Gradient = Seq({ 0, 156, 156, 156 }, { 1, 227, 227, 227 }), TextStroke = rgb(56, 56, 56), Glow = nil },
	-- Tab buttons (Inventory / Shop Navigation): coloured Fill under a near-white gradient
	Cyan = { Base = rgb(72, 90, 118), Fill = rgb(5, 231, 235), Gradient = Seq({ 0, 211, 215, 240 }, { 1, 255, 255, 255 }), TextStroke = rgb(0, 45, 60), Glow = rgb(29, 168, 255), GlowTransparency = 0 },
	Violet = { Base = rgb(58, 11, 176), Fill = rgb(167, 18, 217), Gradient = Seq({ 0, 211, 215, 240 }, { 1, 255, 255, 255 }), TextStroke = rgb(30, 0, 60), Glow = rgb(182, 11, 255), GlowTransparency = 0 },
}

--------------------------------------------------------------------------------------------------------------------
-- Generic builders
--------------------------------------------------------------------------------------------------------------------
-- Kit.New("Frame", {Name = "X", Parent = P, ...}) -> Instance. Parent is set last.
function Kit.New(ClassName, Props)
	local Inst = Instance.new(ClassName)
	local Parent = nil
	for K, V in pairs(Props or {}) do
		if K == "Parent" then Parent = V else Inst[K] = V end
	end
	if Inst:IsA("GuiObject") then
		if Props == nil or Props.BorderSizePixel == nil then Inst.BorderSizePixel = 0 end
		if Props == nil or Props.BackgroundTransparency == nil then Inst.BackgroundTransparency = 1 end
	end
	if Inst:IsA("TextLabel") or Inst:IsA("TextButton") or Inst:IsA("TextBox") then
		if Props == nil or Props.TextScaled == nil then Inst.TextScaled = true end
	end
	Inst.Parent = Parent
	return Inst
end

-- Kit.Stroke(Parent, {Thickness = 0.06, Color = BLACK, Name, Position = "Outer"|"Inner"|"Center",
--   Mode = "Contextual"|"Border", Transparency, ZIndex})
function Kit.Stroke(Parent, O)
	O = O or {}
	return Kit.New("UIStroke", {
		Name = O.Name or "UIStroke",
		Color = O.Color or BLACK,
		Thickness = O.Thickness or 0.06,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		ApplyStrokeMode = Enum.ApplyStrokeMode[O.Mode or "Contextual"],
		BorderStrokePosition = Enum.BorderStrokePosition[O.Position or "Outer"],
		LineJoinMode = Enum.LineJoinMode.Round,
		Transparency = O.Transparency or 0,
		ZIndex = O.ZIndex or 1,
		Parent = Parent,
	})
end

function Kit.Corner(Parent, Scale)
	return Kit.New("UICorner", { CornerRadius = UDim.new(Scale or 0.1, 0), Parent = Parent })
end

-- Kit.Gradient(Parent, ColorSequence, Rotation, {Name, Transparency = NumberSequence})
function Kit.Gradient(Parent, Color, Rotation, O)
	O = O or {}
	return Kit.New("UIGradient", {
		Name = O.Name or "UIGradient",
		Color = Color,
		Rotation = Rotation or 270,
		Transparency = O.Transparency or NumberSequence.new(0),
		Parent = Parent,
	})
end

-- The UIShadow glow every button, slot and panel carries. Blur is a UDim (Scale of the element, plus pixels).
function Kit.Glow(Parent, Color, Transparency, Blur, Name)
	return Kit.New("UIShadow", {
		Name = Name or "UIShadow",
		Color = Color or BLACK,
		Transparency = Transparency or 0.5,
		BlurRadius = Blur or UDim.new(0.05, 15),
		Parent = Parent,
	})
end

function Kit.Aspect(Parent, Ratio)
	return Kit.New("UIAspectRatioConstraint", { AspectRatio = Ratio or 1, Parent = Parent })
end

-- Removes an earlier build of Name under Container, so every build chunk can be rerun.
function Kit.Clear(Container, Name)
	local Old = Container:FindFirstChild(Name)
	if Old then Old:Destroy() end
end

--------------------------------------------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------------------------------------------
-- Styles: Title (panel title), Heading (section title), Label (row title), Value (row value), Name (item name),
-- Body (description), Small (card caption, "DAY 1"), Callout (orange-yellow promo line), Rarity, Bar (numbers on a
-- progress bar). Every style has the house black outline.
local TextStyles = {
	Title = { Weight = "Heavy", Italic = true, Gradient = "Chrome:Silver", Stroke = 0.06, X = "Left" },
	Heading = { Weight = "ExtraBold", Italic = false, Gradient = "Heading", Stroke = 0.06 },
	Label = { Weight = "Heavy", Italic = false, Gradient = "Chrome:Row", Stroke = 0.06, X = "Left" },
	Value = { Weight = "Heavy", Italic = false, Gradient = "Chrome:Row", Stroke = 0.06 },
	Name = { Weight = "Heavy", Italic = false, Gradient = "Chrome:Item", Stroke = 0.06 },
	Body = { Weight = "ExtraBold", Italic = false, Gradient = nil, Stroke = 0.06 },
	Small = { Weight = "Heavy", Italic = true, Gradient = "Chrome:Silver", Stroke = 0.06 },
	Callout = { Weight = "Heavy", Italic = true, Gradient = "Sunset", Stroke = 0.06 },
	Rarity = { Weight = "Heavy", Italic = false, Gradient = "Metal", Stroke = 0.06, Color = rgb(181, 181, 181) },
	Bar = { Weight = "Bold", Italic = false, Gradient = "Chrome:Gold", Stroke = 0.2, StrokeColor = rgb(66, 30, 16) },
}
Kit.TextStyles = TextStyles

local function ApplyTextGradient(Label, Spec)
	if Spec == nil then return nil end
	if typeof(Spec) == "ColorSequence" then return Kit.Gradient(Label, Spec, 270) end
	local Chrome = string.match(Spec, "^Chrome:(.+)$")
	if Chrome then return Kit.Gradient(Label, Kit.Chrome[Chrome], 270) end
	local G = Kit.TextGradients[Spec]
	return Kit.Gradient(Label, G[1], G[2])
end

-- Kit.Text(Parent, Name, Text, Style, {Size, Position, AnchorPoint, Gradient = "Chrome:Gold" | ColorSequence,
--   Color, Italic, X = "Left"|"Center"|"Right", ZIndex, LayoutOrder, Class = "TextLabel"|"TextBox"})
function Kit.Text(Parent, Name, Text, Style, O)
	O = O or {}
	local S = TextStyles[Style or "Body"]
	local Italic = S.Italic
	if O.Italic ~= nil then Italic = O.Italic end
	local Label = Kit.New(O.Class or "TextLabel", {
		Name = Name,
		Text = Text or "",
		FontFace = Kit.Font(S.Weight, Italic),
		TextColor3 = O.Color or S.Color or WHITE,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment[O.X or S.X or "Center"],
		Size = O.Size or UDim2.fromScale(1, 1),
		Position = O.Position or UDim2.fromScale(0, 0),
		AnchorPoint = O.AnchorPoint or Vector2.zero,
		ZIndex = O.ZIndex or 1,
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Stroke(Label, { Thickness = O.Stroke or S.Stroke, Color = O.StrokeColor or S.StrokeColor or BLACK })
	local GradientSpec = S.Gradient
	if O.Gradient ~= nil then GradientSpec = O.Gradient end
	if GradientSpec ~= false then ApplyTextGradient(Label, GradientSpec) end
	return Label
end

--------------------------------------------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------------------------------------------
-- Kit.Button(Parent, Name, Style, {Text, Icon, Size, Position, AnchorPoint, Square = false, Pill = false,
--   LabelSize = 0.6, Aspect, ZIndex, LayoutOrder, NoGlow})
-- A TextButton (Text "") with a "highlight" Frame on top; the words are highlight.TextLabel, an icon is
-- highlight.ImageLabel. A script sets Button.highlight.TextLabel.Text.
-- Square = the Close / tab button shape (thinner inner sheen). Pill = the Settings switch shape (rounder, 0.9 lip).
function Kit.Button(Parent, Name, Style, O)
	O = O or {}
	local St = Kit.ButtonStyles[Style or "Green"]
	local Corner = O.Pill and 0.2 or 0.1
	local Button = Kit.New("TextButton", {
		Name = Name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = St.Base,
		BackgroundTransparency = 0,
		Size = O.Size or UDim2.fromScale(0.3, 0.12),
		Position = O.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = O.AnchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = O.ZIndex or 2,
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	if O.Aspect then Kit.Aspect(Button, O.Aspect) elseif O.Square then Kit.Aspect(Button, 0.95) end
	local Highlight = Kit.New("Frame", {
		Name = "highlight",
		BackgroundColor3 = St.Fill,
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, O.Pill and 0.9 or 0.925),
		Parent = Button,
	})
	Kit.Corner(Highlight, Corner)
	Kit.Gradient(Highlight, St.Gradient, 270)
	Kit.Stroke(Highlight, { Name = "Inner", Color = WHITE, Thickness = O.Square and 0.03 or 0.05, Mode = "Border", Position = "Inner", Transparency = 0.65 })
	if O.Icon then
		local Img = Kit.New("ImageLabel", {
			Image = O.Icon,
			Size = UDim2.fromScale(O.LabelSize or 0.8, O.LabelSize or 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = Highlight,
		})
		Kit.Aspect(Img, 1)
	end
	if O.Text then
		local Label = Kit.New("TextLabel", {
			Text = O.Text,
			FontFace = Kit.Font("Heavy", false),
			TextColor3 = WHITE,
			TextScaled = true,
			TextWrapped = true,
			Size = UDim2.fromScale(O.LabelSize or 0.6, O.LabelSize or 0.6),
			Position = UDim2.fromScale(0.505, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = Highlight,
		})
		Kit.Stroke(Label, { Color = St.TextStroke, Thickness = 0.085 })
	end
	Kit.Stroke(Button, { Color = BLACK, Thickness = 0.065, Mode = "Border", Position = "Outer" })
	Kit.Corner(Button, Corner)
	if St.Glow and not O.NoGlow then Kit.Glow(Button, St.Glow, St.GlowTransparency, UDim.new(0.05, 15)) end
	return Button
end

-- The red X every panel has. Placement "Classic" (Settings / Daily / Statistics: hangs over the top-right edge) or
-- "Corner" (Inventory / Shop: centred on the corner).
function Kit.CloseButton(Panel, Placement)
	local Corner = Placement == "Corner"
	return Kit.Button(Panel, "CloseButton", "Red", {
		Text = "X",
		Square = true,
		LabelSize = 0.65,
		Size = UDim2.fromScale(0.0667, 0.114),
		Position = Corner and UDim2.fromScale(1, 0) or UDim2.fromScale(0.951, -0.0394),
		AnchorPoint = Corner and Vector2.new(0.5, 0.5) or Vector2.zero,
		ZIndex = 2,
	})
end

--------------------------------------------------------------------------------------------------------------------
-- Panels
--------------------------------------------------------------------------------------------------------------------
-- Kit.Panel(Container, Name, {Theme = "Silver"|"Cyan"|"Purple"|"Gold", Title, Icon, Aspect = 1.8,
--   Size = 0.6, Position, Close = true, ClosePlacement = "Classic"|"Corner", Visible = false})
-- The standard full panel: 0.6 x 0.6 of the screen held at 1.8:1 (807x448 on a 1345x801 Studio view), black body,
-- black outline, a thin themed rim, a dot texture with a vignette, a big italic chrome title with its icon hanging
-- over the top-left edge, and the red X. Content goes straight into the returned Frame.
function Kit.Panel(Container, Name, O)
	O = O or {}
	local T = Kit.Themes[O.Theme or "Silver"]
	local Scale = O.Size or 0.6
	local Panel = Kit.New("Frame", {
		Name = Name,
		BackgroundColor3 = BLACK,
		BackgroundTransparency = T.PanelTransparency,
		Size = UDim2.fromScale(Scale, Scale),
		Position = O.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = O.Visible == true,
		Parent = Container,
	})
	Kit.Corner(Panel, 0.045)
	Kit.Stroke(Panel, { Name = "Outer", Thickness = 0.025, Position = "Center" })
	local Rim = Kit.Stroke(Panel, { Name = "Inner", Color = T.RimColor, Thickness = 0.008, Position = "Center", Transparency = 0.05, ZIndex = 2 })
	Kit.Gradient(Rim, T.Rim, -25)
	Kit.Glow(Panel, BLACK, 0.5, UDim.new(0, 20))
	Kit.Aspect(Panel, O.Aspect or 1.8)

	local Addons = Kit.New("Folder", { Name = "addons", Parent = Panel })
	local HasIcon = O.Icon ~= nil and O.Icon ~= false
	Kit.New("ImageLabel", {
		Name = "whiteGlow",
		Image = Kit.Images.TitleGlow,
		ImageColor3 = T.Glow,
		ImageTransparency = T.GlowTransparency,
		Size = HasIcon and UDim2.fromScale(0.584, 0.172) or UDim2.fromScale(0.322, 0.172),
		Position = HasIcon and UDim2.fromScale(0.236, 0.00707) or UDim2.fromScale(0.122, 0.00707),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 0,
		Parent = Addons,
	})
	if O.Title then
		Kit.Text(Addons, "title", O.Title, "Title", {
			Size = UDim2.fromScale(0.311, 0.128),
			Position = HasIcon and UDim2.fromScale(0.128, -0.0582) or UDim2.fromScale(0.0447, -0.0616),
			Gradient = T.Title,
			Color = T.TitleColor,
			ZIndex = HasIcon and 1 or 3,
		})
	end
	if HasIcon then
		local Icon = Kit.New("ImageLabel", {
			Name = "Icon",
			Image = O.Icon,
			Size = UDim2.fromScale(0.111, 0.181),
			Position = UDim2.fromScale(0.0109, -0.0799),
			Parent = Addons,
		})
		Kit.Aspect(Icon, 1)
	end
	local Texture = Kit.New("ImageLabel", {
		Name = "texture",
		Image = Kit.Images.PanelDots,
		ImageColor3 = T.Texture,
		ImageTransparency = T.TextureTransparency,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(1.25, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = -1,
		Parent = Addons,
	})
	Kit.Corner(Texture, 0.045)
	local Shadow = Kit.New("ImageLabel", {
		Name = "shadow",
		Image = Kit.Images.PanelVignette,
		ImageColor3 = BLACK,
		ImageTransparency = 0.75,
		Size = UDim2.fromScale(1, 1),
		Parent = Texture,
	})
	Kit.Corner(Shadow, 0.045)
	if O.Close ~= false then Kit.CloseButton(Panel, O.ClosePlacement) end
	return Panel
end

-- The darker inset box (Inventory / Shop "Info"): Kit.SubPanel(Parent, Name, {Size, Position, AnchorPoint})
function Kit.SubPanel(Parent, Name, O)
	O = O or {}
	local Box = Kit.New("Frame", {
		Name = Name,
		BackgroundColor3 = rgb(15, 15, 15),
		BackgroundTransparency = 0.5,
		Size = O.Size or UDim2.fromScale(0.329, 0.934),
		Position = O.Position or UDim2.fromScale(0.8, 0.5),
		AnchorPoint = O.AnchorPoint or Vector2.new(0.5, 0.5),
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Stroke(Box, { Name = "Inner", Color = rgb(14, 35, 42), Thickness = 0.0075, Position = "Center", Transparency = 0.05, ZIndex = 2 })
	Kit.Stroke(Box, { Name = "Outer", Thickness = 0.025, Position = "Center" })
	Kit.Corner(Box, 0.035)
	Kit.Glow(Box, BLACK, 0.5, UDim.new(0, 20))
	return Box
end

--------------------------------------------------------------------------------------------------------------------
-- Lists, rows, grids
--------------------------------------------------------------------------------------------------------------------
-- Kit.List(Parent, Name, {Direction = "Vertical"|"Horizontal", Padding = UDim, Size, Position, Align = "Center",
--   ScrollBarColor, Bottom = 0.05}) -> ScrollingFrame with a UIListLayout (LayoutOrder sort). The default sits under a
-- panel's title strip like the Settings list (Position Y 0.11, Size Y 0.89).
-- Bottom adds an empty "Bottom" spacer Frame last (LayoutOrder 1000000), like the Shop list's: AutomaticCanvasSize
-- runs a few pixels short and clipped the last row without it (measured). Bottom = 0 leaves it out.
function Kit.List(Parent, Name, O)
	O = O or {}
	local Horizontal = O.Direction == "Horizontal"
	local Scroller = Kit.New("ScrollingFrame", {
		Name = Name,
		Size = O.Size or UDim2.fromScale(1, 0.89),
		Position = O.Position or UDim2.fromScale(0, 0.11),
		AnchorPoint = O.AnchorPoint or Vector2.zero,
		ScrollBarThickness = O.ScrollBarThickness or 12,
		ScrollBarImageColor3 = O.ScrollBarColor or BLACK,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection = Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Parent = Parent,
	})
	Kit.New("UIListLayout", {
		FillDirection = Horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = O.Padding or UDim.new(0, 0),
		HorizontalAlignment = Enum.HorizontalAlignment[O.Align or (Horizontal and "Left" or "Center")],
		VerticalAlignment = Horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Scroller,
	})
	local Bottom = O.Bottom or 0.05
	if Bottom > 0 then
		Kit.New("Frame", {
			Name = "Bottom",
			Size = Horizontal and UDim2.fromScale(Bottom, 1) or UDim2.fromScale(1, Bottom),
			LayoutOrder = 1000000,
			Parent = Scroller,
		})
	end
	return Scroller
end

-- A Settings / Statistics row: transparent, 0.225 of the list's height, a Label on the left and a faint separator
-- line along the bottom. Kit.Row(List, Name, Title, {Height, LayoutOrder, Value}) - Value adds the Statistics value box.
function Kit.Row(Parent, Name, Title, O)
	O = O or {}
	local Row = Kit.New("Frame", {
		Name = Name,
		Size = UDim2.fromScale(1, O.Height or 0.225),
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Text(Row, "title", Title, "Label", {
		Size = UDim2.fromScale(0.477, 0.6),
		Position = UDim2.fromScale(0.045, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
	})
	if O.Value then
		Kit.Text(Row, "Value", O.Value, "Value", {
			Size = UDim2.fromScale(0.477, 0.6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
		})
	end
	local Line = Kit.New("Frame", {
		Name = "seperator", -- [sic], Redpillars' spelling in every authored row
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.85,
		Size = UDim2.fromScale(0.925, 0.03),
		Position = UDim2.fromScale(0.5, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = Row,
	})
	Kit.Corner(Line, 1)
	return Row
end

-- Kit.Grid(Parent, Name, {Cell = UDim2, Padding = UDim2, Columns, Size, Position, AnchorPoint})
-- -> ScrollingFrame + UIPadding + UIGridLayout. Default = the Inventory grid (4 per row, 0.22 x 0.291 cells).
-- Cell heights here are Scale of the scroll WINDOW, which is stable. Never put a Scale-height grid inside a Frame that
-- grows (AutomaticSize): see the skill's layout rules.
function Kit.Grid(Parent, Name, O)
	O = O or {}
	local Scroller = Kit.New("ScrollingFrame", {
		Name = Name,
		Size = O.Size or UDim2.fromScale(1, 0.9),
		Position = O.Position or UDim2.fromScale(0, 1),
		AnchorPoint = O.AnchorPoint or Vector2.new(0, 1),
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = BLACK,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Parent = Parent,
	})
	Kit.New("UIPadding", {
		PaddingLeft = UDim.new(0.01, 0), PaddingRight = UDim.new(0.01, 0),
		PaddingTop = UDim.new(0.025, 0), PaddingBottom = UDim.new(0, 0),
		Parent = Scroller,
	})
	Kit.New("UIGridLayout", {
		CellSize = O.Cell or UDim2.fromScale(0.22, 0.291),
		CellPadding = O.Padding or UDim2.fromScale(0.035, 0.05),
		FillDirectionMaxCells = O.Columns or 4,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Scroller,
	})
	return Scroller
end

--------------------------------------------------------------------------------------------------------------------
-- Items, cards, bars
--------------------------------------------------------------------------------------------------------------------
-- The item slot (InventorySlotTemplate look): dark square, checker texture, silver rim, icon on top, hidden Lock.
-- Kit.Slot(Parent, Name, {Icon, Size, Position, AnchorPoint, LayoutOrder, Level = "LV. 1"})
-- For slots a script fills with real items, prefer Kit.CopyAuthored of Main.Frames.Inventory.Assets.InventorySlotTemplate:
-- the Inventory / Shop code already knows how to paint that one.
function Kit.Slot(Parent, Name, O)
	O = O or {}
	local Slot = Kit.New("ImageButton", {
		Name = Name,
		Image = Kit.Images.SlotBase,
		ImageColor3 = BLACK,
		BackgroundColor3 = rgb(30, 30, 30),
		BackgroundTransparency = 0,
		AutoButtonColor = false,
		Size = O.Size or UDim2.fromScale(0.291, 0.291),
		Position = O.Position or UDim2.fromScale(0, 0),
		AnchorPoint = O.AnchorPoint or Vector2.zero,
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Corner(Slot, 0.075)
	Kit.Stroke(Slot, { Thickness = 0.05, Position = "Center" })
	local Rim = Kit.Stroke(Slot, { Name = "Main", Color = rgb(176, 176, 176), Thickness = 0.02, Position = "Center", ZIndex = 2 })
	Kit.Gradient(Rim, Seq({ 0, 156, 156, 167 }, { 0.5, 255, 255, 255 }, { 1, 156, 156, 167 }), -25)
	local Icon = Kit.New("ImageLabel", {
		Name = "icon",
		Image = O.Icon or Kit.Icons.BasicPillow,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
		Parent = Slot,
	})
	Kit.Aspect(Icon, 1)
	local Texture = Kit.New("ImageLabel", {
		Name = "texture",
		Image = Kit.Images.SlotTexture,
		ImageTransparency = 0.7,
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.499, 0.497),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = Slot,
	})
	Kit.Gradient(Texture, Seq({ 0, 114, 113, 131 }, { 0.5, 255, 255, 255 }, { 1, 114, 113, 131 }), -45)
	local Lock = Kit.New("Frame", {
		Name = "Lock",
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 2,
		Parent = Slot,
	})
	Kit.New("ImageLabel", {
		Name = "Img",
		Image = Kit.Images.Lock,
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
		Parent = Lock,
	})
	if O.Level then
		Kit.Text(Slot, "Level", O.Level, "Name", {
			Size = UDim2.fromScale(0.5, 0.2),
			Position = UDim2.fromScale(0.425, 0.8),
			ZIndex = 10,
		})
	end
	Kit.Aspect(Slot, 1)
	return Slot
end

-- The Shop offer card (Shop "StockFrame"): a grey card a script tints by rarity, shaded top to bottom, white rim,
-- halftone texture fading upward, a white UIShadow glow, a caption at the top.
-- Kit.Card(Parent, Name, {Caption, Color, Size, LayoutOrder, Decor = true})
function Kit.Card(Parent, Name, O)
	O = O or {}
	local Card = Kit.New("Frame", {
		Name = Name,
		BackgroundColor3 = O.Color or rgb(156, 152, 152),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Size = O.Size or UDim2.fromScale(0.3, 0.8),
		Position = O.Position or UDim2.fromScale(0, 0),
		AnchorPoint = O.AnchorPoint or Vector2.zero,
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Corner(Card, 0.05)
	local Rim = Kit.Stroke(Card, { Color = WHITE, Thickness = 0.015, ZIndex = 2 })
	Kit.Gradient(Rim, Seq({ 0, 203, 203, 203 }, { 1, 203, 203, 203 }), 0)
	Kit.Stroke(Card, { Name = "outer", Thickness = 0.02 })
	Kit.Gradient(Card, Seq({ 0, 126, 126, 126 }, { 1, 255, 255, 255 }), 90)
	local Inner = Kit.Stroke(Card, { Name = "inner", Thickness = 0.02, Position = "Inner", Transparency = 0.75 })
	Kit.Gradient(Inner, Seq({ 0, 255, 255, 255 }, { 1, 255, 255, 255 }), 270, { Name = "transparency", Transparency = NSeq({ 0, 0 }, { 1, 1 }) })
	Kit.Glow(Card, WHITE, 0.25, UDim.new(0.2, 0), "Glow")
	if O.Caption then
		Kit.Text(Card, "title", O.Caption, "Small", {
			Size = UDim2.fromScale(0.595, 0.15),
			Position = UDim2.fromScale(0.5, 0.1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Gradient = Seq({ 0, 229, 229, 229 }, { 1, 229, 229, 229 }),
			ZIndex = 3,
		})
	end
	if O.Decor ~= false then
		local Decor = Kit.New("Folder", { Name = "Decor", Parent = Card })
		local Texture = Kit.New("ImageLabel", {
			Name = "texture",
			Image = Kit.Images.Halftone,
			ImageColor3 = rgb(80, 80, 80),
			ImageTransparency = 0.75,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 1),
			Parent = Decor,
		})
		Kit.Corner(Texture, 0.05)
		Kit.Gradient(Texture, Seq({ 0, 255, 255, 255 }, { 1, 255, 255, 255 }), 270, { Name = "transparency", Transparency = NSeq({ 0, 0 }, { 1, 1 }) })
	end
	return Card
end

-- The Robux Shop bundle banner: a loud gradient card with a halftone texture, sparkles and a coloured glow.
-- Kit.Banner(Parent, Name, {Colors = ColorSequence, Texture = Color3, Glow = Color3, Size, LayoutOrder, Stars = true})
function Kit.Banner(Parent, Name, O)
	O = O or {}
	local Banner = Kit.New("Frame", {
		Name = Name,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Size = O.Size or UDim2.fromScale(0.9, 0.5),
		Position = O.Position or UDim2.fromScale(0, 0),
		AnchorPoint = O.AnchorPoint or Vector2.zero,
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Corner(Banner, 0.05)
	local Rim = Kit.Stroke(Banner, { Color = rgb(244, 238, 255), Thickness = 0.01, ZIndex = 2 })
	Kit.Gradient(Rim, Seq({ 0, 255, 94, 19 }, { 0.5, 198, 201, 26 }, { 1, 255, 152, 49 }), 10)
	Kit.Stroke(Banner, { Name = "outer", Thickness = 0.02 })
	local Inner = Kit.Stroke(Banner, { Name = "inner", Thickness = 0.01, Position = "Inner", Transparency = 0.75 })
	Kit.Gradient(Inner, Seq({ 0, 255, 255, 255 }, { 1, 255, 255, 255 }), 270, { Name = "transparency", Transparency = NSeq({ 0, 0 }, { 1, 1 }) })
	Kit.Gradient(Banner, O.Colors or Seq({ 0, 255, 55, 55 }, { 0.47, 255, 241, 83 }, { 1, 243, 255, 23 }), 90)
	Kit.Glow(Banner, O.Glow or rgb(255, 122, 56), 0.25, UDim.new(0.1, 0))
	local Decor = Kit.New("Folder", { Name = "Decor", Parent = Banner })
	local Texture = Kit.New("ImageLabel", {
		Name = "HalftoneTexture",
		Image = Kit.Images.Halftone,
		ImageColor3 = O.Texture or rgb(255, 112, 41),
		ImageTransparency = 0.34,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = Decor,
	})
	Kit.Corner(Texture, 0.05)
	Kit.Gradient(Texture, Seq({ 0, 255, 255, 255 }, { 1, 255, 255, 255 }), 270, { Name = "transparency", Transparency = NSeq({ 0, 0 }, { 0.6, 0.5 }, { 1, 1 }) })
	if O.Stars ~= false then
		local Stars = Kit.New("Folder", { Name = "Stars", Parent = Decor })
		for _, S in ipairs({ { 0.3, 0.931, 0.227, -81 }, { 0.3, 0.044, 0.123, -81 }, { 0.3, 0.422, 0.123, -81 }, { 1, 0.8, 0.5, -22 } }) do
			local Star = Kit.New("ImageLabel", {
				Name = "Star",
				Image = Kit.Images.Star,
				ImageColor3 = rgb(251, 255, 0),
				ImageTransparency = 0.44,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(S[1], S[1]),
				Position = UDim2.fromScale(S[2], S[3]),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = S[4],
				ZIndex = -1,
				Parent = Stars,
			})
			Kit.Aspect(Star, 1)
		end
	end
	return Banner
end

-- The HUD level bar: dark track, black + grey outline, a fill with a chrome gradient and moving-stripe pattern.
-- Kit.Bar(Parent, Name, {Fill = Color3, FillGradient = ColorSequence, Stripes = Color3|false, Size, Position,
--   AnchorPoint, Progress = 0.5}). A script sets Bar.Fill.Size.X.Scale.
function Kit.Bar(Parent, Name, O)
	O = O or {}
	local Bar = Kit.New("Frame", {
		Name = Name,
		BackgroundColor3 = rgb(15, 15, 15),
		BackgroundTransparency = 0,
		Size = O.Size or UDim2.fromScale(1, 0.5),
		Position = O.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = O.AnchorPoint or Vector2.new(0.5, 0.5),
		LayoutOrder = O.LayoutOrder or 0,
		Parent = Parent,
	})
	Kit.Corner(Bar, 0.1)
	Kit.Stroke(Bar, { Name = "Inner", Thickness = 0.1 })
	Kit.Stroke(Bar, { Name = "Outer", Color = rgb(106, 106, 106), Thickness = 0.04, ZIndex = 2 })
	local Fill = Kit.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = O.Fill or rgb(255, 229, 34),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(O.Progress or 0.5, 1),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = Bar,
	})
	Kit.Corner(Fill, 0.1)
	Kit.Stroke(Fill, { Name = "UIStroke", Color = rgb(106, 106, 106), Thickness = 0.05 })
	Kit.Gradient(Fill, O.FillGradient or Kit.Chrome.Gold, 270)
	if O.Stripes ~= false then
		Kit.New("ImageLabel", {
			Name = "Pattern",
			Image = Kit.Images.Stripes,
			ImageColor3 = O.Stripes or rgb(223, 181, 54),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.new(0.2, 20, 1, 20),
			Size = UDim2.fromScale(1, 1),
			Parent = Fill,
		})
	end
	return Bar
end

--------------------------------------------------------------------------------------------------------------------
-- Copying authored pieces
--------------------------------------------------------------------------------------------------------------------
-- Clones an authored instance (e.g. game.StarterGui.Main.Frames.Inventory.Assets.InventorySlotTemplate) without its
-- scripts, behaviour tags (RbxBuyButton) or product Ids, so a copy in a new Frame can't sell or run anything.
local BEHAVIOUR_TAGS = { RbxBuyButton = true }
function Kit.CopyAuthored(Source, Parent, Name)
	local Copy = Source:Clone()
	for _, D in ipairs(Copy:GetDescendants()) do
		if D:IsA("LuaSourceContainer") then D:Destroy() end
	end
	for _, D in ipairs({ Copy, table.unpack(Copy:GetDescendants()) }) do
		for _, Tag in ipairs(D:GetTags()) do
			if BEHAVIOUR_TAGS[Tag] then D:RemoveTag(Tag) end
		end
		if D:GetAttribute("Id") ~= nil then D:SetAttribute("Id", nil) end
	end
	if Name then Copy.Name = Name end
	if Copy:IsA("GuiObject") then Copy.Visible = true end
	Copy.Parent = Parent
	return Copy
end

--------------------------------------------------------------------------------------------------------------------
-- Staging and preview
--------------------------------------------------------------------------------------------------------------------
-- StarterGui.UIStaging: a DISABLED ScreenGui with Main's settings and the same Frames / HUD / System containers.
-- New Frames are built here; the scripting session moves them into Main. Disabled, so a publish never shows a draft.
function Kit.Staging()
	local Main = StarterGui:FindFirstChild("Main")
	local G = StarterGui:FindFirstChild("UIStaging")
	if not G then
		G = Instance.new("ScreenGui")
		G.Name = "UIStaging"
		G.ResetOnSpawn = false
		-- Main's settings, copied one by one ("Main and X or Default" would turn a false into the default)
		if Main then
			G.IgnoreGuiInset = Main.IgnoreGuiInset
			G.ScreenInsets = Main.ScreenInsets
			G.ZIndexBehavior = Main.ZIndexBehavior
			G.SafeAreaCompatibility = Main.SafeAreaCompatibility
			G.ClipToDeviceSafeArea = Main.ClipToDeviceSafeArea
		else
			G.IgnoreGuiInset = true
			G.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
			G.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		end
		G.Enabled = false
		G.Parent = StarterGui
	end
	G.Enabled = false
	for _, Name in ipairs({ "Frames", "HUD", "System" }) do
		if not G:FindFirstChild(Name) then
			Kit.New("Frame", {
				Name = Name,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Parent = G,
			})
		end
	end
	return G
end

-- The device boxes a preview can render in. PC fills the Studio viewport. Phone is a notched phone's safe area
-- (Main uses DeviceSafeInsets: 749x361 of an 873x401 screen). SmallPhone is a 667x375 phone with no notch.
Kit.Devices = {
	PC = nil,
	Phone = Vector2.new(749, 361),
	SmallPhone = Vector2.new(667, 375),
}

-- Kit.PreviewOn(Target, Mode, {Show = {"Assets.RowTemplate", ...}, Fill = function(Clone) end, Backdrop = Color3})
-- Copies Target (a Frame in UIStaging, or any GuiObject) into a TEMP ScreenGui in StarterGui so screen_capture can
-- see it (CoreGui does not show in captures), over a flat sky-blue backdrop that hides Main's HUD. Mode: "PC",
-- "Phone", "SmallPhone". Show lists hidden descendants (paths relative to Target) to make visible in the copy; Fill
-- can add sample rows. Returns the copy. ALWAYS call Kit.PreviewOff() when the captures are done: the TEMP ScreenGui
-- would otherwise ship with the next publish.
function Kit.PreviewOn(Target, Mode, O)
	O = O or {}
	Kit.PreviewOff()
	local G = Instance.new("ScreenGui")
	G.Name = "TEMP_UIPreview"
	G.IgnoreGuiInset = true
	G.ScreenInsets = Enum.ScreenInsets.None
	G.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	G.DisplayOrder = 1000
	Kit.New("Frame", {
		Name = "Backdrop",
		BackgroundColor3 = O.Backdrop or rgb(70, 110, 150),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = -10,
		Parent = G,
	})
	local DeviceSize = Kit.Devices[Mode or "PC"]
	local Device = Kit.New("Frame", {
		Name = "Device",
		Size = DeviceSize and UDim2.fromOffset(DeviceSize.X, DeviceSize.Y) or UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = G,
	})
	if DeviceSize then
		Kit.New("UIStroke", { Color = rgb(20, 20, 20), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Device })
	end
	-- Same container the Frame lives in under UIStaging / Main, so its Scale sizes resolve the same way
	local ContainerName = "Frames"
	local A = Target.Parent
	while A and A ~= game do
		if A.Parent and (A.Parent.Name == "UIStaging" or A.Parent.Name == "Main") and A.Parent:IsA("ScreenGui") then
			ContainerName = A.Name
			break
		end
		A = A.Parent
	end
	local Container = Kit.New("Frame", {
		Name = ContainerName,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = Device,
	})
	local Copy = Target:Clone()
	if Copy:IsA("GuiObject") then Copy.Visible = true end
	Copy.Parent = Container
	for _, Path in ipairs(O.Show or {}) do
		local Node = Copy
		for Part in string.gmatch(Path, "[^%.]+") do Node = Node and Node:FindFirstChild(Part) end
		if Node and Node:IsA("GuiObject") then Node.Visible = true end
	end
	if O.Fill then O.Fill(Copy) end
	G.Parent = StarterGui
	return Copy
end

function Kit.PreviewOff()
	local Old = StarterGui:FindFirstChild("TEMP_UIPreview")
	if Old then Old:Destroy() end
	return "preview cleared"
end

--------------------------------------------------------------------------------------------------------------------
-- Checks
--------------------------------------------------------------------------------------------------------------------
-- Every image id the shipped UI already uses, plus the kit's lists. Anything else is a NEW image (not allowed).
local function KnownImages()
	local Known = {}
	for _, Id in pairs(Kit.Images) do Known[Id] = true end
	for _, Id in pairs(Kit.Icons) do Known[Id] = true end
	local Main = StarterGui:FindFirstChild("Main")
	for _, Root in ipairs({ Main, StarterGui:FindFirstChild("Tutorial") }) do
		if Root then
			for _, D in ipairs(Root:GetDescendants()) do
				if D:IsA("ImageLabel") or D:IsA("ImageButton") then Known[D.Image] = true end
			end
		end
	end
	return Known
end

local function IsRendered(Obj, Root)
	local N = Obj
	while N and N ~= Root.Parent do
		if N:IsA("GuiObject") and not N.Visible then return false end
		N = N.Parent
	end
	return true
end

-- Kit.Audit(Root) -> report string. Run it on the PREVIEW copy (Kit.PreviewOn's return), where AbsoluteSize is
-- real. Checks: no scripts, nothing rendered at 0x0, no Offset sizes, house fonts, outlined and scaled text, no new
-- images, unique names for scripted elements, no behaviour tags, no Scale heights inside a growing Frame, no
-- hard-coded key hints.
function Kit.Audit(Root)
	local Issues, Notes = {}, {}
	local Known = KnownImages()
	local function Rel(D) return D == Root and Root.Name or (Root.Name .. "." .. D:GetFullName():sub(#Root:GetFullName() + 2)) end
	local All = Root:GetDescendants()
	table.insert(All, 1, Root)
	for _, D in ipairs(All) do
		if D:IsA("LuaSourceContainer") then table.insert(Issues, "SCRIPT inside: " .. Rel(D)) end
		for _, Tag in ipairs(D:GetTags()) do
			if BEHAVIOUR_TAGS[Tag] then table.insert(Issues, "behaviour tag " .. Tag .. ": " .. Rel(D)) end
		end
		if D:IsA("GuiObject") then
			if IsRendered(D, Root) and (D.AbsoluteSize.X < 1 or D.AbsoluteSize.Y < 1) then
				table.insert(Issues, "renders 0x0: " .. Rel(D) .. " (Size " .. tostring(D.Size) .. ")")
			end
			local S = D.Size
			if (S.X.Offset ~= 0 or S.Y.Offset ~= 0) and D.Parent and not D.Parent:IsA("ScreenGui") then
				table.insert(Notes, "Offset size (OK only if measured on purpose): " .. Rel(D) .. " " .. tostring(S))
			end
			local P = D.Parent
			if P and P:IsA("GuiObject") and P.AutomaticSize ~= Enum.AutomaticSize.None and S.Y.Scale ~= 0
				and (P.AutomaticSize == Enum.AutomaticSize.Y or P.AutomaticSize == Enum.AutomaticSize.XY) then
				table.insert(Issues, "Scale height inside a growing Frame (it will grow with every row): " .. Rel(D))
			end
		end
		if (D:IsA("TextLabel") or D:IsA("TextButton") or D:IsA("TextBox")) and (D.Text ~= "" or D:IsA("TextBox")) then
			local Family = D.FontFace.Family
			if not string.find(Family, "GothamSSm") and not string.find(Family, "FredokaOne") then
				table.insert(Issues, "font not GothamSSm: " .. Rel(D) .. " (" .. Family .. ")")
			end
			if not D.TextScaled then table.insert(Notes, "not TextScaled: " .. Rel(D)) end
			if not D:FindFirstChildOfClass("UIStroke") then table.insert(Issues, "text without the black outline: " .. Rel(D)) end
			local T = string.lower(D.Text)
			if string.find(T, "press %a") or string.find(T, "%[%a%]") or string.find(T, "click") or string.find(T, "tap ") then
				table.insert(Notes, "possible hard-coded input hint (scripting draws key hints via InputDevice): " .. Rel(D) .. " \"" .. D.Text .. "\"")
			end
			if D:IsA("TextBox") then table.insert(Notes, "TextBox: the scripting session must call UIUtils.AddTouchFocus on " .. Rel(D)) end
		end
		if (D:IsA("ImageLabel") or D:IsA("ImageButton")) and D.Image ~= "" and not Known[D.Image] then
			table.insert(Issues, "NEW image (reuse existing only): " .. Rel(D) .. " " .. D.Image)
		end
		-- Names a script will look up must be unique among siblings
		if D:IsA("GuiButton") or D:IsA("TextBox") or D:IsA("ScrollingFrame") then
			local Count = 0
			for _, Sib in ipairs(D.Parent and D.Parent:GetChildren() or {}) do
				if Sib.Name == D.Name then Count += 1 end
			end
			if Count > 1 then table.insert(Issues, "duplicate sibling name '" .. D.Name .. "': " .. Rel(D)) end
		end
	end
	local Out = { ("Audit of %s: %d issue(s), %d note(s)"):format(Root.Name, #Issues, #Notes) }
	for _, L in ipairs(Issues) do table.insert(Out, "  ISSUE " .. L) end
	for _, L in ipairs(Notes) do table.insert(Out, "  note  " .. L) end
	return table.concat(Out, "\n")
end

-- Kit.Describe(Root) -> the tree of everything a script will touch, for the handoff note: buttons, text, text boxes,
-- icons, lists and their layouts, Folders (Assets templates), with dot-paths relative to Root. Decor (strokes,
-- gradients, corners, shadows, the addons Folder's art) is left out.
function Kit.Describe(Root)
	local Out = {}
	local function Line(D, Depth)
		local Bits = { D.ClassName }
		if D:IsA("GuiObject") and not D.Visible then table.insert(Bits, "Visible=false") end
		if D:IsA("TextLabel") or D:IsA("TextButton") or D:IsA("TextBox") then
			if D.Text ~= "" then table.insert(Bits, ("Text=%q"):format(D.Text)) end
		end
		if (D:IsA("ImageLabel") or D:IsA("ImageButton")) and D.Name ~= "texture" then table.insert(Bits, "Image=" .. D.Image) end
		if D:IsA("UIListLayout") then table.insert(Bits, D.FillDirection.Name .. ", SortOrder " .. D.SortOrder.Name) end
		if D:IsA("UIGridLayout") then table.insert(Bits, "max " .. D.FillDirectionMaxCells .. " per row") end
		local Attrs = {}
		for K, V in pairs(D:GetAttributes()) do table.insert(Attrs, K .. "=" .. tostring(V)) end
		if #Attrs > 0 then table.insert(Bits, "attrs{" .. table.concat(Attrs, ";") .. "}") end
		table.insert(Out, string.rep("  ", Depth) .. D.Name .. "  (" .. table.concat(Bits, ", ") .. ")")
	end
	local Skip = { UIStroke = true, UIGradient = true, UICorner = true, UIShadow = true, UIAspectRatioConstraint = true, UIPadding = true }
	local function Walk(D, Depth)
		Line(D, Depth)
		for _, C in ipairs(D:GetChildren()) do
			local Decor = Skip[C.ClassName] or (C.Name == "addons" and C:IsA("Folder")) or C.Name == "texture" or C.Name == "shadow" or C.Name == "whiteGlow" or C.Name == "seperator"
			if not Decor then Walk(C, Depth + 1) end
		end
	end
	Walk(Root, 0)
	return table.concat(Out, "\n")
end

return Kit
