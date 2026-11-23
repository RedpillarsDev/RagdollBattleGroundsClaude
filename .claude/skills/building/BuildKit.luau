--!nocheck
--[[ ClaudeBuildKit: shared part-building helpers for Pillow Battles maps.

Source of truth: .claude/skills/building/BuildKit.luau in the PillowBattlesClaude repo. The copy in
GPT Playground lives at ServerStorage.ClaudeBuildKit (a ModuleScript, never required at runtime).

Load it inside execute_luau with:
	local Kit = loadstring(game.ServerStorage.ClaudeBuildKit.Source)()
loadstring, not require: require caches across execute_luau calls, so an edited kit would not reload.

Conventions every helper follows:
- Everything is Anchored, Smooth surfaced, SmoothPlastic unless a material is passed.
- Facade trim, glass, signs and small props are Kit.Detail (no collision, query, touch or shadow). Only
  the bodies Players stand on or bump into collide.
- Sizes are in studs for a ~5 stud tall character (walk 23, jump ~6.4 studs high, ~11 studs far).
]]

local Kit = {}
-- Bump on every change to this file. The skill compares it with the copy installed in GPT Playground.
Kit.Version = "2026-10-10.4"
local M = Enum.Material

Kit.Palette = {
	-- Ground
	Road = Color3.fromRGB(64, 68, 82),
	Lot = Color3.fromRGB(80, 84, 98),
	LaneYellow = Color3.fromRGB(255, 204, 64),
	LaneWhite = Color3.fromRGB(244, 244, 240),
	Sidewalk = Color3.fromRGB(206, 201, 194),
	Curb = Color3.fromRGB(160, 156, 152),
	Plaza = Color3.fromRGB(236, 218, 188),
	PlazaAccent = Color3.fromRGB(214, 128, 96),
	Pavers = Color3.fromRGB(198, 190, 214),
	Dirt = Color3.fromRGB(168, 122, 80),
	Grass = Color3.fromRGB(112, 196, 84),
	GrassDark = Color3.fromRGB(80, 164, 70),
	Leaves = { Color3.fromRGB(96, 190, 80), Color3.fromRGB(74, 160, 70), Color3.fromRGB(130, 206, 92) },
	Foundation = Color3.fromRGB(150, 150, 158),
	Soil = Color3.fromRGB(140, 98, 66),
	Rock = {
		Color3.fromRGB(124, 100, 84),
		Color3.fromRGB(110, 88, 76),
		Color3.fromRGB(98, 80, 72),
		Color3.fromRGB(88, 72, 66),
	},
	-- Buildings
	Walls = {
		Coral = Color3.fromRGB(255, 132, 112),
		Mint = Color3.fromRGB(122, 214, 182),
		Butter = Color3.fromRGB(255, 212, 112),
		Sky = Color3.fromRGB(112, 178, 240),
		Lavender = Color3.fromRGB(172, 144, 230),
		Peach = Color3.fromRGB(255, 178, 132),
		Cream = Color3.fromRGB(246, 236, 216),
		Brick = Color3.fromRGB(184, 88, 72),
		Teal = Color3.fromRGB(64, 170, 178),
	},
	TrimLight = Color3.fromRGB(248, 246, 240),
	TrimDark = Color3.fromRGB(46, 52, 74),
	Glass = Color3.fromRGB(132, 206, 255),
	GlassDark = Color3.fromRGB(74, 136, 196),
	Roof = Color3.fromRGB(122, 126, 138),
	Metal = Color3.fromRGB(176, 182, 192),
	MetalDark = Color3.fromRGB(88, 94, 108),
	Wood = Color3.fromRGB(150, 104, 70),
	Trunk = Color3.fromRGB(122, 84, 58),
	-- Accents
	Pink = Color3.fromRGB(255, 92, 168),
	Cyan = Color3.fromRGB(64, 228, 255),
	Orange = Color3.fromRGB(255, 140, 40),
	Red = Color3.fromRGB(232, 64, 64),
	Yellow = Color3.fromRGB(255, 214, 40),
	Green = Color3.fromRGB(64, 200, 96),
	Blue = Color3.fromRGB(60, 120, 230),
	White = Color3.fromRGB(250, 250, 250),
	Black = Color3.fromRGB(32, 34, 42),
	Gold = Color3.fromRGB(255, 196, 56),
	LampGlow = Color3.fromRGB(255, 238, 186),
}
local P = Kit.Palette

----------------------------------------------------------------------------------------------------
-- Primitives
----------------------------------------------------------------------------------------------------

function Kit.Part(Parent, Name, Size, CF, Color, Material, ClassName)
	local Pt = Instance.new(ClassName or "Part")
	Pt.Name = Name
	Pt.Anchored = true
	Pt.Size = Size
	Pt.CFrame = CF
	Pt.Color = Color
	Pt.Material = Material or M.SmoothPlastic
	Pt.TopSurface = Enum.SurfaceType.Smooth
	Pt.BottomSurface = Enum.SurfaceType.Smooth
	Pt.Parent = Parent
	return Pt
end

function Kit.Box(Parent, Name, Size, Pos, Color, Material)
	return Kit.Part(Parent, Name, Size, CFrame.new(Pos), Color, Material)
end

function Kit.BoxMinMax(Parent, Name, Min, Max, Color, Material)
	return Kit.Part(Parent, Name, Max - Min, CFrame.new((Min + Max) / 2), Color, Material)
end

-- WedgePart: the tall flat face is +Z (Back), the slope falls toward -Z (Front).
function Kit.Wedge(Parent, Name, Size, CF, Color, Material)
	return Kit.Part(Parent, Name, Size, CF, Color, Material, "WedgePart")
end

-- Roblox cylinders run along the part's X axis.
function Kit.Cyl(Parent, Name, Diameter, Length, CF, Color, Material)
	local Pt = Kit.Part(Parent, Name, Vector3.new(Length, Diameter, Diameter), CF, Color, Material)
	Pt.Shape = Enum.PartType.Cylinder
	return Pt
end

-- A standing cylinder centred on Pos.
function Kit.VCyl(Parent, Name, Diameter, Height, Pos, Color, Material)
	return Kit.Cyl(Parent, Name, Diameter, Height, CFrame.new(Pos) * CFrame.Angles(0, 0, math.pi / 2), Color, Material)
end

-- A cylinder from point A to point B (pipes, beams, cables).
function Kit.CylBetween(Parent, Name, Diameter, A, B, Color, Material)
	local Len = (B - A).Magnitude
	local CF = CFrame.lookAt((A + B) / 2, B) * CFrame.Angles(0, math.pi / 2, 0)
	return Kit.Cyl(Parent, Name, Diameter, Len, CF, Color, Material)
end

-- A box from point A to point B (beams, rails, girders). Thickness is {X, Y} across the beam.
function Kit.BeamBetween(Parent, Name, A, B, ThickX, ThickY, Color, Material)
	local Len = (B - A).Magnitude
	return Kit.Part(Parent, Name, Vector3.new(ThickX, ThickY, Len), CFrame.lookAt((A + B) / 2, B), Color, Material)
end

-- A true sphere (Ball parts are always round: the smallest Size axis wins).
function Kit.Ball(Parent, Name, Diameter, Pos, Color, Material)
	local Pt = Kit.Part(Parent, Name, Vector3.new(Diameter, Diameter, Diameter), CFrame.new(Pos), Color, Material)
	Pt.Shape = Enum.PartType.Ball
	return Pt
end

-- A squashed sphere (clouds, cushions, bushes): a Part with a Sphere SpecialMesh.
function Kit.Ellipsoid(Parent, Name, Size, CF, Color, Material)
	local Pt = Kit.Part(Parent, Name, Size, CF, Color, Material)
	local Mesh = Instance.new("SpecialMesh")
	Mesh.MeshType = Enum.MeshType.Sphere
	Mesh.Parent = Pt
	return Pt
end

-- Decoration that nothing should touch, stand on, raycast against or shade with.
function Kit.Detail(Pt)
	Pt.CanCollide = false
	Pt.CanTouch = false
	Pt.CanQuery = false
	Pt.CastShadow = false
	return Pt
end

-- Non-colliding but still shadow casting (canopies, awnings you can see from below).
function Kit.Ghost(Pt)
	Pt.CanCollide = false
	Pt.CanTouch = false
	Pt.CanQuery = false
	return Pt
end

function Kit.Folder(Parent, Name)
	local F = Parent:FindFirstChild(Name)
	if not F then
		F = Instance.new("Folder")
		F.Name = Name
		F.Parent = Parent
	end
	return F
end

function Kit.Clear(Container)
	for _, Child in Container:GetChildren() do
		Child:Destroy()
	end
	return Container
end

function Kit.Model(Parent, Name)
	local Mo = Instance.new("Model")
	Mo.Name = Name
	Mo.Parent = Parent
	return Mo
end

----------------------------------------------------------------------------------------------------
-- Facades: a face frame looks OUT of the wall. X runs along the wall, Y is up, -Z is outward.
----------------------------------------------------------------------------------------------------

function Kit.FaceCF(PointOnWall, Normal)
	return CFrame.lookAt(PointOnWall, PointOnWall + Normal)
end

-- A slab stuck on a wall. Along/Up place its centre on the wall; Out is its thickness, standing proud of
-- the wall by that much (Lift pushes it further out first).
function Kit.OnFace(Parent, Name, FCF, Along, Up, W, H, Out, Color, Material, Lift)
	local CF = FCF * CFrame.new(Along, Up, -((Lift or 0) + Out / 2))
	return Kit.Part(Parent, Name, Vector3.new(W, H, Out), CF, Color, Material)
end

-- A cartoon sign label (white text, thick dark outline) on one face of a part.
function Kit.Text(Pt, Face, Text, TextColor, StrokeColor, Font)
	local G = Instance.new("SurfaceGui")
	G.Face = Face or Enum.NormalId.Front
	G.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	G.PixelsPerStud = 40
	G.LightInfluence = 0
	G.Parent = Pt
	local L = Instance.new("TextLabel")
	L.Size = UDim2.fromScale(1, 1)
	L.BackgroundTransparency = 1
	L.Text = Text
	L.TextScaled = true
	L.Font = Font or Enum.Font.FredokaOne
	L.TextColor3 = TextColor or P.White
	L.Parent = G
	local Pad = Instance.new("UIPadding")
	Pad.PaddingTop = UDim.new(0.12, 0)
	Pad.PaddingBottom = UDim.new(0.12, 0)
	Pad.PaddingLeft = UDim.new(0.05, 0)
	Pad.PaddingRight = UDim.new(0.05, 0)
	Pad.Parent = L
	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 5
	Stroke.Color = StrokeColor or P.Black
	Stroke.Parent = L
	return G
end

----------------------------------------------------------------------------------------------------
-- Buildings
----------------------------------------------------------------------------------------------------

local FaceNormals = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}
Kit.FaceNormals = FaceNormals

local function FaceInfo(Center, W, D, FaceName)
	local N = FaceNormals[FaceName]
	local Wide = (FaceName == "N" or FaceName == "S")
	local FaceW = Wide and W or D
	local Half = Wide and D / 2 or W / 2
	local Point = Vector3.new(Center.X, Center.Y, Center.Z) + N * Half
	return Kit.FaceCF(Point, N), FaceW
end

-- Stripy sloped awning with a scalloped valance, hung on a face at height Top.
function Kit.Awning(Parent, FCF, Along, Top, Width, ColorA, ColorB)
	local Depth, Drop = 4.6, 2.2
	local Len = math.sqrt(Depth * Depth + Drop * Drop)
	local Angle = math.atan2(Drop, Depth)
	local Count = math.max(2, math.floor(Width / 2.4))
	local StripeW = Width / Count
	for I = 0, Count - 1 do
		local X = Along - Width / 2 + StripeW * (I + 0.5)
		local Color = (I % 2 == 0) and ColorA or ColorB
		local CF = FCF * CFrame.new(X, Top - Drop / 2, -Depth / 2) * CFrame.Angles(-Angle, 0, 0)
		Kit.Ghost(Kit.Part(Parent, "AwningStripe", Vector3.new(StripeW, 0.35, Len), CF, Color))
		Kit.Detail(Kit.OnFace(Parent, "Valance", FCF, X, Top - Drop - 0.45, StripeW, 0.9, 0.2, Color, nil, Depth - 0.2))
	end
	-- side cheeks so the awning reads as a solid canopy from the street
	for _, Side in { -1, 1 } do
		local X = Along + Side * (Width / 2 + 0.1)
		local CF = FCF * CFrame.new(X, Top - Drop / 2, -Depth / 2) * CFrame.Angles(-Angle, 0, 0)
		Kit.Detail(Kit.Part(Parent, "AwningCheek", Vector3.new(0.2, 0.9, Len), CF, ColorA))
	end
end

-- Spec fields:
--   Name, Center (Vector3, Y = ground top), W (along X), D (along Z), Floors (upper floors), GroundH, FloorH
--   Wall, WallMat, Trim, Glass, Frame, Front ("N"/"S"/"E"/"W"), Detail ({faces with punched windows})
--   Shop = {Text, AwningA, AwningB, SignColor, TextColor} (storefront on Front)
--   WindowW, WindowH, WindowGap, NoParapet
function Kit.Building(Parent, S)
	local Mo = Kit.Model(Parent, S.Name)
	local GH, FH = S.GroundH or 14, S.FloorH or 12
	local Floors = S.Floors or 0
	local H = GH + FH * Floors
	local C, W, D = S.Center, S.W, S.D
	local Base = C.Y
	local Top = Base + H
	local Trim = S.Trim or P.TrimLight
	local Glass = S.Glass or P.Glass
	local Frame = S.Frame or P.TrimDark
	local DetailFaces = S.Detail or {}

	local Body = Kit.Box(Mo, "Body", Vector3.new(W, H, D), Vector3.new(C.X, Base + H / 2, C.Z), S.Wall, S.WallMat)
	Kit.Detail(Kit.Box(Mo, "Plinth", Vector3.new(W + 0.8, 1.4, D + 0.8), Vector3.new(C.X, Base + 0.7, C.Z), Frame, M.Concrete))
	for F = 0, Floors - 1 do
		local Y = Base + GH + FH * F
		Kit.Detail(Kit.Box(Mo, "Ledge", Vector3.new(W + 0.8, 0.7, D + 0.8), Vector3.new(C.X, Y, C.Z), Trim))
	end
	Kit.Detail(Kit.Box(Mo, "Cornice", Vector3.new(W + 1.0, 0.8, D + 1.0), Vector3.new(C.X, Top - 1.0, C.Z), Trim))
	Kit.Detail(Kit.Box(Mo, "CorniceTop", Vector3.new(W + 2.0, 0.9, D + 2.0), Vector3.new(C.X, Top - 0.15, C.Z), Trim))
	for _, SX in { -1, 1 } do
		for _, SZ in { -1, 1 } do
			Kit.Detail(Kit.Box(Mo, "Pilaster", Vector3.new(1.3, H - 1.6, 1.3), Vector3.new(C.X + SX * W / 2, Base + (H - 1.6) / 2 + 0.6, C.Z + SZ * D / 2), Trim))
		end
	end

	-- roof: membrane, parapet and cap
	Kit.Box(Mo, "RoofDeck", Vector3.new(W - 2, 0.2, D - 2), Vector3.new(C.X, Top + 0.1, C.Z), P.Roof, M.Concrete)
	if not S.NoParapet then
		local PH = 2.6
		local Sides = {
			{ Vector3.new(W, PH, 1), Vector3.new(0, 0, -D / 2 + 0.5) },
			{ Vector3.new(W, PH, 1), Vector3.new(0, 0, D / 2 - 0.5) },
			{ Vector3.new(1, PH, D - 2), Vector3.new(-W / 2 + 0.5, 0, 0) },
			{ Vector3.new(1, PH, D - 2), Vector3.new(W / 2 - 0.5, 0, 0) },
		}
		for _, Side in Sides do
			Kit.Box(Mo, "Parapet", Side[1], Vector3.new(C.X, Top + PH / 2, C.Z) + Side[2], S.Wall, S.WallMat)
			Kit.Detail(Kit.Box(Mo, "ParapetCap", Side[1] + Vector3.new(0.5, 0.5 - PH, 0.5), Vector3.new(C.X, Top + PH + 0.25, C.Z) + Side[2], Trim))
		end
	end

	local WW, WH, Gap = S.WindowW or 4, S.WindowH or 6, S.WindowGap or 3
	for FaceName in FaceNormals do
		local FCF, FaceW = FaceInfo(Vector3.new(C.X, 0, C.Z), W, D, FaceName)
		FCF = FCF + Vector3.new(0, Base, 0)
		local IsDetail = table.find(DetailFaces, FaceName) ~= nil
		local IsFront = (S.Front == FaceName)
		local Rows = {}
		for F = 0, Floors - 1 do
			table.insert(Rows, GH + FH * F + FH * 0.5 + 0.3)
		end
		if not IsFront and IsDetail then
			table.insert(Rows, 1, GH * 0.5 + 0.6)
		end
		for _, WinY in Rows do
			if IsDetail or IsFront then
				local Count = math.max(1, math.floor((FaceW - 5 + Gap) / (WW + Gap)))
				local Span = Count * WW + (Count - 1) * Gap
				for K = 0, Count - 1 do
					local X = -Span / 2 + WW / 2 + K * (WW + Gap)
					Kit.Detail(Kit.OnFace(Mo, "WinFrame", FCF, X, WinY, WW + 0.9, WH + 0.9, 0.35, Trim))
					local G = Kit.Detail(Kit.OnFace(Mo, "Glass", FCF, X, WinY, WW, WH, 0.45, Glass))
					G.Reflectance = 0.12
					Kit.Detail(Kit.OnFace(Mo, "Sill", FCF, X, WinY - WH / 2 - 0.55, WW + 1.6, 0.45, 0.9, Trim))
					if WW >= 4 then
						Kit.Detail(Kit.OnFace(Mo, "Mullion", FCF, X, WinY + WH * 0.15, WW, 0.3, 0.55, Trim))
					end
				end
			else
				local RW = FaceW - 5
				local G = Kit.Detail(Kit.OnFace(Mo, "Ribbon", FCF, 0, WinY, RW, WH - 1, 0.25, Glass))
				G.Reflectance = 0.12
				local Mullions = math.floor(RW / 7)
				for K = 1, Mullions - 1 do
					Kit.Detail(Kit.OnFace(Mo, "RibbonMullion", FCF, -RW / 2 + K * RW / Mullions, WinY, 0.35, WH - 1, 0.35, Trim))
				end
			end
		end

		if IsFront then
			local SH = GH - 4.8
			local FrameW = FaceW - 3
			Kit.Detail(Kit.OnFace(Mo, "ShopFrame", FCF, 0, 1.4 + SH / 2, FrameW, SH, 0.3, Frame))
			local DoorW = 5
			local PaneW = (FrameW - 1.6 - DoorW - 1.6) / 2
			for _, Side in { -1, 1 } do
				local X = Side * (DoorW / 2 + 0.8 + PaneW / 2)
				local G = Kit.Detail(Kit.OnFace(Mo, "ShopGlass", FCF, X, 1.4 + SH / 2 + 0.3, PaneW, SH - 1.8, 0.4, Glass))
				G.Reflectance = 0.15
				local Bars = math.floor(PaneW / 5)
				for K = 1, Bars - 1 do
					Kit.Detail(Kit.OnFace(Mo, "ShopMullion", FCF, X - PaneW / 2 + K * PaneW / Bars, 1.4 + SH / 2 + 0.3, 0.3, SH - 1.8, 0.5, Frame))
				end
			end
			Kit.Detail(Kit.OnFace(Mo, "Door", FCF, 0, 1.4 + 4.2, DoorW - 0.6, 8.2, 0.36, Frame))
			local DG = Kit.Detail(Kit.OnFace(Mo, "DoorGlass", FCF, 0, 1.4 + 5.0, DoorW - 1.8, 5.2, 0.42, Glass))
			DG.Reflectance = 0.15
			Kit.Detail(Kit.OnFace(Mo, "DoorHandle", FCF, 1.4, 1.4 + 4.0, 0.3, 1.6, 0.6, P.Metal, M.Metal))
			if S.Shop then
				Kit.Awning(Mo, FCF, 0, GH - 2.6, FrameW, S.Shop.AwningA or P.Red, S.Shop.AwningB or P.White)
				local SignW = math.min(FaceW - 6, 26)
				Kit.Detail(Kit.OnFace(Mo, "SignFrame", FCF, 0, GH - 1.15, SignW + 0.8, 2.6, 0.35, Trim))
				local Sign = Kit.Detail(Kit.OnFace(Mo, "Sign", FCF, 0, GH - 1.15, SignW, 2.0, 0.55, S.Shop.SignColor or P.TrimDark))
				Kit.Text(Sign, Enum.NormalId.Front, S.Shop.Text, S.Shop.TextColor or P.White, P.Black)
			else
				Kit.Detail(Kit.OnFace(Mo, "Canopy", FCF, 0, 10.2, DoorW + 4, 0.6, 3, Trim))
			end
		end
	end
	Mo.PrimaryPart = Body
	return Mo, Top
end

-- Glass curtain-wall tower: stone lobby, finned glass shaft, setback crown, antenna.
-- Spec: Name, Center, W, D, Floors, Stone, Trim, Glass, Front, LobbyText
function Kit.Tower(Parent, S)
	local Mo = Kit.Model(Parent, S.Name)
	local C, W, D = S.Center, S.W, S.D
	local LobbyH, FH = 16, 10
	local ShaftH = FH * S.Floors
	local Base = C.Y
	local Trim = S.Trim or P.TrimLight
	local Glass = S.Glass or P.GlassDark
	local Stone = S.Stone or P.Walls.Cream

	Kit.Box(Mo, "Lobby", Vector3.new(W + 2, LobbyH, D + 2), Vector3.new(C.X, Base + LobbyH / 2, C.Z), Stone, M.SmoothPlastic)
	Kit.Detail(Kit.Box(Mo, "LobbyCap", Vector3.new(W + 3.2, 1.2, D + 3.2), Vector3.new(C.X, Base + LobbyH, C.Z), Trim))
	local Shaft = Kit.Box(Mo, "Shaft", Vector3.new(W, ShaftH, D), Vector3.new(C.X, Base + LobbyH + ShaftH / 2, C.Z), Glass)
	Shaft.Reflectance = 0.25
	for F = 1, S.Floors do
		Kit.Detail(Kit.Box(Mo, "Band", Vector3.new(W + 0.6, 0.9, D + 0.6), Vector3.new(C.X, Base + LobbyH + F * FH - 0.45, C.Z), Trim))
	end
	for FaceName in FaceNormals do
		local FCF, FaceW = FaceInfo(Vector3.new(C.X, 0, C.Z), W, D, FaceName)
		local Fins = math.floor(FaceW / 5)
		for K = 1, Fins - 1 do
			local X = -FaceW / 2 + K * FaceW / Fins
			Kit.Detail(Kit.OnFace(Mo, "Fin", FCF + Vector3.new(0, Base, 0), X, LobbyH + ShaftH / 2, 0.5, ShaftH, 0.7, Trim))
		end
		-- lobby: tall glass entrance on the front, stone pilasters elsewhere
		local LCF = Kit.FaceCF(Vector3.new(C.X, Base, C.Z) + FaceNormals[FaceName] * (((FaceName == "N" or FaceName == "S") and D or W) / 2 + 1), FaceNormals[FaceName])
		if FaceName == S.Front then
			Kit.Detail(Kit.OnFace(Mo, "EntranceFrame", LCF, 0, 6.5, FaceW * 0.6 + 1, 11, 0.3, P.TrimDark))
			local G = Kit.Detail(Kit.OnFace(Mo, "EntranceGlass", LCF, 0, 6.5, FaceW * 0.6, 10, 0.4, P.Glass))
			G.Reflectance = 0.2
			for K = -2, 2 do
				Kit.Detail(Kit.OnFace(Mo, "EntranceMullion", LCF, K * FaceW * 0.12, 6.5, 0.35, 10, 0.5, P.TrimDark))
			end
			Kit.Detail(Kit.OnFace(Mo, "EntranceCanopy", LCF, 0, 12.6, FaceW * 0.6 + 4, 0.7, 4, Trim))
			if S.LobbyText then
				local Sign = Kit.Detail(Kit.OnFace(Mo, "LobbySign", LCF, 0, 14.4, FaceW * 0.5, 2.2, 0.4, P.TrimDark))
				Kit.Text(Sign, Enum.NormalId.Front, S.LobbyText, P.Gold, P.Black)
			end
		else
			local Pil = math.floor((FaceW + 2) / 7)
			for K = 0, Pil do
				local X = -(FaceW + 2) / 2 + K * (FaceW + 2) / Pil
				Kit.Detail(Kit.OnFace(Mo, "LobbyPilaster", LCF, X, LobbyH / 2, 1.2, LobbyH - 1, 0.5, Trim))
			end
		end
	end
	-- setback crown
	local CrownBase = Base + LobbyH + ShaftH
	Kit.Box(Mo, "CrownLedge", Vector3.new(W + 1.6, 1.2, D + 1.6), Vector3.new(C.X, CrownBase + 0.6, C.Z), Trim)
	local Crown = Kit.Box(Mo, "Crown", Vector3.new(W - 6, 10, D - 6), Vector3.new(C.X, CrownBase + 6.2, C.Z), Glass)
	Crown.Reflectance = 0.25
	for K = 0, 2 do
		Kit.Detail(Kit.Box(Mo, "CrownBand", Vector3.new(W - 5.4, 0.8, D - 5.4), Vector3.new(C.X, CrownBase + 2.5 + K * 3.4, C.Z), Trim))
	end
	Kit.Box(Mo, "CrownCap", Vector3.new(W - 4, 1.2, D - 4), Vector3.new(C.X, CrownBase + 11.8, C.Z), Trim)
	local MastBase = CrownBase + 12.4
	Kit.Detail(Kit.VCyl(Mo, "AntennaBase", 3, 3, Vector3.new(C.X, MastBase + 1.5, C.Z), P.MetalDark, M.Metal))
	Kit.Detail(Kit.VCyl(Mo, "Antenna", 0.6, 18, Vector3.new(C.X, MastBase + 12, C.Z), P.Metal, M.Metal))
	Kit.Detail(Kit.Ball(Mo, "AntennaLight", 1.2, Vector3.new(C.X, MastBase + 21.3, C.Z), P.Red, M.Neon))
	Mo.PrimaryPart = Shaft
	return Mo, CrownBase + 12.4
end

----------------------------------------------------------------------------------------------------
-- Rooftop props (Pos = roof surface point)
----------------------------------------------------------------------------------------------------

function Kit.ACUnit(Parent, Pos, Yaw)
	local CF = CFrame.new(Pos) * CFrame.Angles(0, Yaw or 0, 0)
	local Mo = Kit.Model(Parent, "ACUnit")
	Kit.Part(Mo, "Box", Vector3.new(5, 3, 4), CF * CFrame.new(0, 1.5, 0), P.Metal, M.Metal)
	Kit.Detail(Kit.Cyl(Mo, "Fan", 3, 0.3, CF * CFrame.new(-0.8, 3.1, 0) * CFrame.Angles(0, 0, math.pi / 2), P.MetalDark, M.DiamondPlate))
	Kit.Detail(Kit.Part(Mo, "Grille", Vector3.new(2, 2, 0.2), CF * CFrame.new(1.2, 1.5, -2.05), P.MetalDark, M.DiamondPlate))
	return Mo
end

function Kit.Vent(Parent, Pos)
	Kit.Detail(Kit.VCyl(Parent, "VentPipe", 1.2, 3, Pos + Vector3.new(0, 1.5, 0), P.Metal, M.Metal))
	Kit.Detail(Kit.VCyl(Parent, "VentCap", 2, 0.5, Pos + Vector3.new(0, 3.2, 0), P.MetalDark, M.Metal))
end

function Kit.WaterTower(Parent, Pos)
	local Mo = Kit.Model(Parent, "WaterTower")
	for _, SX in { -1, 1 } do
		for _, SZ in { -1, 1 } do
			Kit.Part(Mo, "Leg", Vector3.new(0.6, 8, 0.6), CFrame.new(Pos + Vector3.new(SX * 3, 4, SZ * 3)), P.MetalDark, M.Metal)
		end
	end
	Kit.Detail(Kit.BeamBetween(Mo, "Brace", Pos + Vector3.new(-3, 1, -3), Pos + Vector3.new(3, 7, -3), 0.3, 0.3, P.MetalDark, M.Metal))
	Kit.Detail(Kit.BeamBetween(Mo, "Brace", Pos + Vector3.new(3, 1, 3), Pos + Vector3.new(-3, 7, 3), 0.3, 0.3, P.MetalDark, M.Metal))
	Kit.VCyl(Mo, "Deck", 9, 0.6, Pos + Vector3.new(0, 8.3, 0), P.MetalDark, M.Metal)
	Kit.VCyl(Mo, "Tank", 8, 8, Pos + Vector3.new(0, 12.6, 0), P.Wood, M.WoodPlanks)
	Kit.Detail(Kit.VCyl(Mo, "Hoop", 8.3, 0.4, Pos + Vector3.new(0, 10.4, 0), P.MetalDark, M.Metal))
	Kit.Detail(Kit.VCyl(Mo, "Hoop", 8.3, 0.4, Pos + Vector3.new(0, 14.8, 0), P.MetalDark, M.Metal))
	Kit.Detail(Kit.VCyl(Mo, "Roof1", 8.8, 1, Pos + Vector3.new(0, 17.1, 0), P.Red))
	Kit.Detail(Kit.VCyl(Mo, "Roof2", 5.6, 1.2, Pos + Vector3.new(0, 18.2, 0), P.Red))
	Kit.Detail(Kit.VCyl(Mo, "Roof3", 2.4, 1.2, Pos + Vector3.new(0, 19.4, 0), P.Red))
	Kit.Detail(Kit.Ball(Mo, "Finial", 1, Pos + Vector3.new(0, 20.3, 0), P.Gold, M.Metal))
	return Mo
end

function Kit.Billboard(Parent, Pos, Yaw, W, H, Text, Bg, TextColor)
	local Mo = Kit.Model(Parent, "Billboard")
	local CF = CFrame.new(Pos) * CFrame.Angles(0, Yaw or 0, 0)
	for _, SX in { -1, 1 } do
		Kit.Part(Mo, "Post", Vector3.new(0.8, 6 + H, 0.8), CF * CFrame.new(SX * W * 0.3, (6 + H) / 2, 0.8), P.MetalDark, M.Metal)
	end
	Kit.Detail(Kit.Part(Mo, "Catwalk", Vector3.new(W, 0.3, 1.6), CF * CFrame.new(0, 5.6, -0.6), P.MetalDark, M.DiamondPlate))
	Kit.Part(Mo, "Frame", Vector3.new(W + 1, H + 1, 0.6), CF * CFrame.new(0, 6 + H / 2, 0.3), P.TrimDark)
	local Board = Kit.Detail(Kit.Part(Mo, "Board", Vector3.new(W, H, 0.4), CF * CFrame.new(0, 6 + H / 2, 0), Bg))
	Kit.Text(Board, Enum.NormalId.Front, Text, TextColor or P.White, P.Black)
	for _, SX in { -0.3, 0.3 } do
		Kit.Detail(Kit.Part(Mo, "SpotArm", Vector3.new(0.3, 0.3, 2), CF * CFrame.new(SX * W, 6 + H + 0.8, -1), P.MetalDark, M.Metal))
		Kit.Detail(Kit.Part(Mo, "Spot", Vector3.new(1, 0.6, 0.6), CF * CFrame.new(SX * W, 6 + H + 0.8, -2), P.LampGlow, M.Neon))
	end
	return Mo
end

----------------------------------------------------------------------------------------------------
-- Street furniture (Base = ground point under the prop)
----------------------------------------------------------------------------------------------------

function Kit.Lamp(Parent, Base, Dir)
	local Mo = Kit.Model(Parent, "StreetLamp")
	Dir = Vector3.new(Dir.X, 0, Dir.Z).Unit
	Kit.Detail(Kit.VCyl(Mo, "Foot", 1.6, 1, Base + Vector3.new(0, 0.5, 0), P.TrimDark))
	Kit.VCyl(Mo, "Pole", 0.7, 14, Base + Vector3.new(0, 7.5, 0), P.TrimDark)
	Kit.Detail(Kit.VCyl(Mo, "Collar", 1.0, 0.6, Base + Vector3.new(0, 4, 0), P.Gold, M.Metal))
	local ArmA, ArmB = Base + Vector3.new(0, 14.2, 0), Base + Vector3.new(0, 14.2, 0) + Dir * 4
	Kit.Detail(Kit.BeamBetween(Mo, "Arm", ArmA, ArmB, 0.4, 0.4, P.TrimDark))
	local HeadCF = CFrame.lookAt(ArmB, ArmB + Dir)
	Kit.Detail(Kit.Part(Mo, "Head", Vector3.new(1.8, 0.7, 2.6), HeadCF * CFrame.new(0, -0.1, -0.6), P.TrimDark))
	Kit.Detail(Kit.Part(Mo, "Bulb", Vector3.new(1.3, 0.25, 2.0), HeadCF * CFrame.new(0, -0.5, -0.6), P.LampGlow, M.Neon))
	return Mo
end

function Kit.Tree(Parent, Base, Scale, Seed)
	local S = Scale or 1
	local R = Random.new(Seed or 1)
	local Mo = Kit.Model(Parent, "Tree")
	Kit.VCyl(Mo, "Trunk", 1.2 * S, 7 * S, Base + Vector3.new(0, 3.5 * S, 0), P.Trunk, M.Wood)
	local Leaves = P.Leaves
	local Blobs = {
		{ 0, 9, 0, 7.5 },
		{ 2.2, 7.6, 1.0, 5.4 },
		{ -2.0, 7.8, -1.2, 5.6 },
		{ 0.6, 11.2, -0.6, 4.6 },
		{ -1.0, 7.4, 2.2, 4.4 },
	}
	for I, B in Blobs do
		local Jit = Vector3.new(R:NextNumber(-0.4, 0.4), R:NextNumber(-0.3, 0.3), R:NextNumber(-0.4, 0.4))
		Kit.Ghost(Kit.Ball(Mo, "Leaves", B[4] * S, Base + Vector3.new(B[1], B[2], B[3]) * S + Jit * S, Leaves[(I + (Seed or 0)) % #Leaves + 1]))
	end
	return Mo
end

function Kit.Planter(Parent, Center, W, D, WithTree, Seed)
	local Mo = Kit.Model(Parent, "Planter")
	Kit.Box(Mo, "Box", Vector3.new(W, 1.6, D), Center + Vector3.new(0, 0.8, 0), P.Curb, M.Concrete)
	Kit.Detail(Kit.Box(Mo, "Rim", Vector3.new(W + 0.4, 0.3, D + 0.4), Center + Vector3.new(0, 1.65, 0), P.TrimLight, M.Concrete))
	Kit.Detail(Kit.Box(Mo, "Soil", Vector3.new(W - 0.8, 0.2, D - 0.8), Center + Vector3.new(0, 1.62, 0), P.Soil, M.Ground))
	if WithTree then
		Kit.Tree(Mo, Center + Vector3.new(0, 1.6, 0), 1, Seed)
	end
	return Mo
end

function Kit.Bush(Parent, Pos, Size, Seed)
	local R = Random.new(Seed or 3)
	for I = 1, 3 do
		local Off = Vector3.new(R:NextNumber(-0.35, 0.35) * Size, 0, R:NextNumber(-0.35, 0.35) * Size)
		Kit.Ghost(Kit.Ball(Parent, "Bush", Size * R:NextNumber(0.7, 1.0), Pos + Off + Vector3.new(0, Size * 0.3, 0), P.Leaves[(I + (Seed or 0)) % #P.Leaves + 1]))
	end
end

-- CF: ground point, LookVector = the way a sitter faces.
function Kit.Bench(Parent, CF)
	local Mo = Kit.Model(Parent, "Bench")
	Kit.Part(Mo, "Seat", Vector3.new(5, 0.4, 1.6), CF * CFrame.new(0, 1.6, 0), P.Wood, M.WoodPlanks)
	Kit.Part(Mo, "Back", Vector3.new(5, 1.4, 0.3), CF * CFrame.new(0, 2.7, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), P.Wood, M.WoodPlanks)
	for _, SX in { -1, 1 } do
		Kit.Detail(Kit.Part(Mo, "Leg", Vector3.new(0.35, 1.5, 1.5), CF * CFrame.new(SX * 2.1, 0.75, 0), P.TrimDark, M.Metal))
		Kit.Detail(Kit.Part(Mo, "ArmRest", Vector3.new(0.35, 0.3, 1.5), CF * CFrame.new(SX * 2.4, 2.4, 0), P.TrimDark, M.Metal))
	end
	return Mo
end

function Kit.Hydrant(Parent, Base)
	local Mo = Kit.Model(Parent, "Hydrant")
	Kit.VCyl(Mo, "Body", 1.1, 2.0, Base + Vector3.new(0, 1.0, 0), P.Red)
	Kit.Detail(Kit.VCyl(Mo, "Collar", 1.4, 0.3, Base + Vector3.new(0, 1.6, 0), P.Red))
	Kit.Detail(Kit.Ball(Mo, "Cap", 1.1, Base + Vector3.new(0, 2.0, 0), P.Red))
	Kit.Detail(Kit.Cyl(Mo, "Nozzle", 0.6, 1.8, CFrame.new(Base + Vector3.new(0, 1.2, 0)), P.Gold, M.Metal))
	return Mo
end

function Kit.TrashCan(Parent, Base)
	local Mo = Kit.Model(Parent, "TrashCan")
	Kit.VCyl(Mo, "Can", 1.8, 2.6, Base + Vector3.new(0, 1.3, 0), Color3.fromRGB(56, 128, 92))
	Kit.Detail(Kit.VCyl(Mo, "Lid", 2.0, 0.35, Base + Vector3.new(0, 2.7, 0), P.TrimDark))
	Kit.Detail(Kit.VCyl(Mo, "Band", 1.9, 0.3, Base + Vector3.new(0, 0.9, 0), P.TrimDark))
	return Mo
end

function Kit.Cone(Parent, Base)
	local Mo = Kit.Model(Parent, "TrafficCone")
	Kit.Detail(Kit.Box(Mo, "Foot", Vector3.new(1.6, 0.2, 1.6), Base + Vector3.new(0, 0.1, 0), P.Orange))
	Kit.Detail(Kit.VCyl(Mo, "C1", 1.1, 0.7, Base + Vector3.new(0, 0.55, 0), P.Orange))
	Kit.Detail(Kit.VCyl(Mo, "C2", 0.85, 0.5, Base + Vector3.new(0, 1.15, 0), P.White))
	Kit.Detail(Kit.VCyl(Mo, "C3", 0.6, 0.6, Base + Vector3.new(0, 1.7, 0), P.Orange))
	return Mo
end

-- CF: ground point, the board runs along X.
function Kit.Barrier(Parent, CF, Length)
	local Mo = Kit.Model(Parent, "Barrier")
	local L = Length or 6
	for _, SX in { -1, 1 } do
		Kit.Detail(Kit.Part(Mo, "LegA", Vector3.new(0.3, 3.0, 0.3), CF * CFrame.new(SX * (L / 2 - 0.4), 1.4, -0.45) * CFrame.Angles(math.rad(-12), 0, 0), P.White))
		Kit.Detail(Kit.Part(Mo, "LegB", Vector3.new(0.3, 3.0, 0.3), CF * CFrame.new(SX * (L / 2 - 0.4), 1.4, 0.45) * CFrame.Angles(math.rad(12), 0, 0), P.White))
	end
	local Stripes = math.max(3, math.floor(L / 1.2))
	for I = 0, Stripes - 1 do
		local X = -L / 2 + L / Stripes * (I + 0.5)
		Kit.Part(Mo, "Board", Vector3.new(L / Stripes, 0.9, 0.25), CF * CFrame.new(X, 2.5, 0), (I % 2 == 0) and P.Orange or P.White)
	end
	Kit.Detail(Kit.Part(Mo, "Light", Vector3.new(0.5, 0.5, 0.5), CF * CFrame.new(L / 2 - 0.5, 3.3, 0), P.Yellow, M.Neon))
	return Mo
end

-- CF: ground point under the car's centre, LookVector = forward. Kind: nil | "Taxi" | "Police"
function Kit.Car(Parent, CF, BodyColor, Kind)
	local Mo = Kit.Model(Parent, Kind or "Car")
	local Body = Kit.Part(Mo, "Body", Vector3.new(6, 2.0, 12), CF * CFrame.new(0, 1.7, 0), BodyColor)
	Kit.Detail(Kit.Part(Mo, "Skirt", Vector3.new(6.1, 0.5, 11.6), CF * CFrame.new(0, 0.9, 0), P.TrimDark))
	local Cabin = Kit.Part(Mo, "Cabin", Vector3.new(5.2, 1.9, 6.2), CF * CFrame.new(0, 3.65, 0.6), P.GlassDark)
	Cabin.Reflectance = 0.2
	Kit.Detail(Kit.Part(Mo, "Roof", Vector3.new(5.5, 0.45, 5.4), CF * CFrame.new(0, 4.75, 0.7), BodyColor))
	for _, SX in { -1, 1 } do
		Kit.Detail(Kit.Part(Mo, "Pillar", Vector3.new(5.45, 1.9, 0.5), CF * CFrame.new(0, 3.65, 0.6 + SX * 3.0), BodyColor))
	end
	Kit.Detail(Kit.Part(Mo, "PillarMid", Vector3.new(5.45, 1.9, 0.4), CF * CFrame.new(0, 3.65, 0.9), BodyColor))
	for _, SZ in { -1, 1 } do
		Kit.Detail(Kit.Part(Mo, "Bumper", Vector3.new(6.3, 0.7, 0.6), CF * CFrame.new(0, 1.1, SZ * 6.05), P.Metal, M.Metal))
		for _, SX in { -1, 1 } do
			Kit.Detail(Kit.Cyl(Mo, "Wheel", 2.5, 1.0, CF * CFrame.new(SX * 2.75, 1.25, SZ * 3.8), P.Black))
			Kit.Detail(Kit.Cyl(Mo, "Hub", 1.2, 1.1, CF * CFrame.new(SX * 2.75, 1.25, SZ * 3.8), P.Metal, M.Metal))
		end
	end
	for _, SX in { -1, 1 } do
		Kit.Detail(Kit.Part(Mo, "Headlight", Vector3.new(1.2, 0.6, 0.2), CF * CFrame.new(SX * 2.1, 2.0, -6.05), P.LampGlow, M.Neon))
		Kit.Detail(Kit.Part(Mo, "Taillight", Vector3.new(1.2, 0.5, 0.2), CF * CFrame.new(SX * 2.1, 2.1, 6.05), P.Red, M.Neon))
	end
	if Kind == "Taxi" then
		local Sign = Kit.Detail(Kit.Part(Mo, "TaxiSign", Vector3.new(2.6, 0.9, 1.2), CF * CFrame.new(0, 5.4, 0.7), P.Yellow))
		Kit.Text(Sign, Enum.NormalId.Front, "TAXI", P.Black, P.Yellow)
		Kit.Detail(Kit.Part(Mo, "Checker", Vector3.new(6.15, 0.4, 7), CF * CFrame.new(0, 2.4, 0), P.Black))
	elseif Kind == "Police" then
		Kit.Detail(Kit.Part(Mo, "LightBar", Vector3.new(4, 0.5, 1), CF * CFrame.new(0, 5.2, 0.7), P.TrimDark))
		Kit.Detail(Kit.Part(Mo, "Red", Vector3.new(1.6, 0.5, 0.8), CF * CFrame.new(-1, 5.5, 0.7), P.Red, M.Neon))
		Kit.Detail(Kit.Part(Mo, "Blue", Vector3.new(1.6, 0.5, 0.8), CF * CFrame.new(1, 5.5, 0.7), P.Blue, M.Neon))
		Kit.Detail(Kit.Part(Mo, "Door", Vector3.new(6.12, 1.2, 4), CF * CFrame.new(0, 2.0, 0.4), P.White))
	end
	Mo.PrimaryPart = Body
	return Mo
end

-- Base: foot of the pole. ArmDir: the way the arm reaches over the road.
function Kit.TrafficLight(Parent, Base, ArmDir)
	local Mo = Kit.Model(Parent, "TrafficLight")
	ArmDir = Vector3.new(ArmDir.X, 0, ArmDir.Z).Unit
	Kit.Detail(Kit.VCyl(Mo, "Foot", 1.6, 0.8, Base + Vector3.new(0, 0.4, 0), P.TrimDark))
	Kit.VCyl(Mo, "Pole", 0.9, 17, Base + Vector3.new(0, 8.5, 0), P.TrimDark)
	local A, B = Base + Vector3.new(0, 16.4, 0), Base + Vector3.new(0, 16.4, 0) + ArmDir * 11
	Kit.Detail(Kit.BeamBetween(Mo, "Arm", A, B, 0.5, 0.5, P.TrimDark))
	for _, T in { 0.55, 0.95 } do
		local Head = Base + Vector3.new(0, 14.2, 0) + ArmDir * (11 * T)
		-- face oncoming traffic: perpendicular to the arm
		local Facing = Vector3.new(-ArmDir.Z, 0, ArmDir.X)
		local HCF = CFrame.lookAt(Head, Head + Facing)
		Kit.Detail(Kit.Part(Mo, "Hanger", Vector3.new(0.25, 1.6, 0.25), HCF * CFrame.new(0, 1.7, 0), P.TrimDark))
		Kit.Detail(Kit.Part(Mo, "Housing", Vector3.new(1.6, 4.2, 1.3), HCF, Color3.fromRGB(240, 196, 40)))
		local Lights = { { 1.3, P.Red }, { 0, P.Orange }, { -1.3, P.Green } }
		for _, L in Lights do
			Kit.Detail(Kit.Cyl(Mo, "Lamp", 1.0, 0.25, HCF * CFrame.new(0, L[1], -0.7) * CFrame.Angles(0, math.pi / 2, 0), L[2], M.Neon))
			Kit.Detail(Kit.Part(Mo, "Visor", Vector3.new(1.2, 0.15, 0.6), HCF * CFrame.new(0, L[1] + 0.6, -0.95), P.Black))
		end
	end
	return Mo
end

function Kit.Mailbox(Parent, Base, Yaw)
	local Mo = Kit.Model(Parent, "Mailbox")
	local CF = CFrame.new(Base) * CFrame.Angles(0, Yaw or 0, 0)
	for _, SX in { -1, 1 } do
		Kit.Detail(Kit.Part(Mo, "Leg", Vector3.new(0.3, 1.0, 0.3), CF * CFrame.new(SX * 0.8, 0.5, 0), P.TrimDark))
	end
	Kit.Part(Mo, "Box", Vector3.new(2.0, 2.4, 1.8), CF * CFrame.new(0, 2.2, 0), P.Blue)
	Kit.Detail(Kit.Cyl(Mo, "Top", 1.8, 2.0, CF * CFrame.new(0, 3.4, 0), P.Blue))
	Kit.Detail(Kit.Part(Mo, "Slot", Vector3.new(1.2, 0.2, 0.1), CF * CFrame.new(0, 3.0, -0.95), P.Black))
	return Mo
end

function Kit.Manhole(Parent, Pos)
	Kit.Detail(Kit.VCyl(Parent, "Manhole", 3, 0.1, Pos + Vector3.new(0, 0.05, 0), P.MetalDark, M.DiamondPlate))
end

----------------------------------------------------------------------------------------------------
-- Industrial / steampunk (added 2026-10-10 for the Train Station): painted pipes with brass flanges,
-- gears, gas lamps, valve wheels, gauges, crates and steam.
----------------------------------------------------------------------------------------------------

P.Brass = Color3.fromRGB(214, 164, 72)
P.Copper = Color3.fromRGB(204, 114, 72)
P.Verdigris = Color3.fromRGB(96, 186, 160)
P.Iron = Color3.fromRGB(54, 60, 78)
P.PipeColors = {
	Red = Color3.fromRGB(230, 74, 62),
	Yellow = Color3.fromRGB(250, 192, 52),
	Teal = Color3.fromRGB(38, 172, 172),
	Purple = Color3.fromRGB(150, 98, 206),
	Blue = Color3.fromRGB(64, 132, 224),
}

-- A pipe run through a list of points: a straight cylinder per leg, a ball elbow at every bend and brass
-- flanges near every joint and every Opts.FlangeEvery studs. Decoration unless Opts.Solid.
-- Opts: Name, Solid, FlangeEvery (default 14), FlangeColor, Material, Caps (ball caps on both ends).
function Kit.Pipe(Parent, Points, Diameter, Color, Opts)
	Opts = Opts or {}
	local Mo = Kit.Model(Parent, Opts.Name or "Pipe")
	local FlangeColor = Opts.FlangeColor or P.Brass
	local Every = Opts.FlangeEvery or 14
	local function Mark(Pt) if not Opts.Solid then Kit.Detail(Pt) end; return Pt end
	for I = 1, #Points - 1 do
		local A, B = Points[I], Points[I + 1]
		local Len = (B - A).Magnitude
		if Len > 0.05 then
			Mark(Kit.CylBetween(Mo, "Pipe", Diameter, A, B, Color, Opts.Material))
			local Dir = (B - A).Unit
			local Stops = { math.min(1, Len / 2) }
			local T = Every
			while T < Len - Every * 0.5 do table.insert(Stops, T); T += Every end
			if Len > 2 then table.insert(Stops, Len - 1) end
			for _, S in Stops do
				local Pos = A + Dir * S
				Kit.Detail(Kit.Cyl(Mo, "Flange", Diameter * 1.35, 0.5, CFrame.lookAt(Pos, Pos + Dir) * CFrame.Angles(0, math.pi / 2, 0), FlangeColor, M.Metal))
			end
		end
		if I > 1 then Mark(Kit.Ball(Mo, "Elbow", Diameter * 1.12, A, Color, Opts.Material)) end
	end
	if Opts.Caps then
		for _, E in { Points[1], Points[#Points] } do Kit.Detail(Kit.Ball(Mo, "Cap", Diameter * 1.2, E, FlangeColor, M.Metal)) end
	end
	return Mo
end

-- A decorative cog. CF is the centre; the gear faces along CF.LookVector.
function Kit.Gear(Parent, CF, Diameter, Thickness, Color, Teeth)
	local Mo = Kit.Model(Parent, "Gear")
	Teeth = Teeth or 12
	local R = Diameter / 2
	local Axis = CF * CFrame.Angles(0, math.pi / 2, 0)
	local Dark = Color:Lerp(Color3.new(0, 0, 0), 0.25)
	Kit.Detail(Kit.Cyl(Mo, "Rim", Diameter, Thickness, Axis, Color, M.Metal))
	Kit.Detail(Kit.Cyl(Mo, "Web", Diameter * 0.74, Thickness + 0.2, Axis, Dark, M.Metal))
	Kit.Detail(Kit.Cyl(Mo, "Hub", Diameter * 0.26, Thickness + 0.6, Axis, Color, M.Metal))
	Kit.Detail(Kit.Cyl(Mo, "Axle", Diameter * 0.1, Thickness + 1.0, Axis, P.Iron, M.Metal))
	for K = 0, Teeth - 1 do
		local ToothCF = CF * CFrame.Angles(0, 0, K / Teeth * math.pi * 2) * CFrame.new(0, R + Diameter * 0.05, 0)
		Kit.Detail(Kit.Part(Mo, "Tooth", Vector3.new(Diameter * 0.11, Diameter * 0.13, Thickness), ToothCF, Color, M.Metal))
	end
	return Mo
end

-- Victorian gas lamp: iron post, brass collars, a crossbar with two glowing lanterns.
function Kit.GasLamp(Parent, Base, Color)
	local Mo = Kit.Model(Parent, "GasLamp")
	Color = Color or P.Iron
	Kit.Detail(Kit.VCyl(Mo, "Foot", 1.9, 1.2, Base + Vector3.new(0, 0.6, 0), Color))
	Kit.Detail(Kit.VCyl(Mo, "FootRing", 1.5, 0.4, Base + Vector3.new(0, 1.4, 0), P.Brass, M.Metal))
	Kit.VCyl(Mo, "Post", 0.6, 11.4, Base + Vector3.new(0, 6.7, 0), Color)
	Kit.Detail(Kit.VCyl(Mo, "Collar", 0.95, 0.5, Base + Vector3.new(0, 9.2, 0), P.Brass, M.Metal))
	Kit.Detail(Kit.Part(Mo, "CrossBar", Vector3.new(4.6, 0.35, 0.35), CFrame.new(Base + Vector3.new(0, 12.2, 0)), Color))
	for _, SX in { -1, 1 } do
		local LP = Base + Vector3.new(SX * 2.2, 11, 0)
		Kit.Detail(Kit.Part(Mo, "LanternCap", Vector3.new(1.5, 0.45, 1.5), CFrame.new(LP + Vector3.new(0, 0.95, 0)), Color))
		Kit.Detail(Kit.Part(Mo, "Lantern", Vector3.new(1.0, 1.4, 1.0), CFrame.new(LP), P.LampGlow, M.Neon))
		Kit.Detail(Kit.Part(Mo, "LanternBase", Vector3.new(1.2, 0.3, 1.2), CFrame.new(LP - Vector3.new(0, 0.85, 0)), P.Brass, M.Metal))
	end
	Kit.Detail(Kit.Ball(Mo, "Finial", 0.8, Base + Vector3.new(0, 12.8, 0), P.Brass, M.Metal))
	return Mo
end

-- A valve handwheel facing along CF.LookVector: 8 rim segments, two spokes and a hub.
function Kit.Valve(Parent, CF, Diameter, Color)
	local Mo = Kit.Model(Parent, "Valve")
	local R = Diameter / 2
	local Seg = 2 * R * math.sin(math.pi / 8) + 0.15
	for K = 0, 7 do
		Kit.Detail(Kit.Part(Mo, "Rim", Vector3.new(Seg, 0.35, 0.35), CF * CFrame.Angles(0, 0, K / 8 * math.pi * 2) * CFrame.new(0, R * math.cos(math.pi / 8), 0), Color))
	end
	for _, A in { 0, math.pi / 2 } do
		Kit.Detail(Kit.Part(Mo, "Spoke", Vector3.new(Diameter, 0.25, 0.25), CF * CFrame.Angles(0, 0, A), Color))
	end
	Kit.Detail(Kit.Cyl(Mo, "Hub", 0.7, 0.6, CF * CFrame.Angles(0, math.pi / 2, 0), P.Brass, M.Metal))
	return Mo
end

-- A round pressure gauge facing along CF.LookVector.
function Kit.Gauge(Parent, CF, Diameter)
	local Mo = Kit.Model(Parent, "Gauge")
	Kit.Detail(Kit.Cyl(Mo, "Bezel", Diameter, 0.4, CF * CFrame.Angles(0, math.pi / 2, 0), P.Brass, M.Metal))
	Kit.Detail(Kit.Cyl(Mo, "Face", Diameter * 0.82, 0.5, CF * CFrame.Angles(0, math.pi / 2, 0), P.White))
	Kit.Detail(Kit.Part(Mo, "Needle", Vector3.new(0.12, Diameter * 0.36, 0.1), CF * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, 0, math.rad(-50)) * CFrame.new(0, Diameter * 0.14, 0), P.Red))
	return Mo
end

-- A wooden crate with iron bands and a stencilled label on two faces. CF: ground point.
function Kit.Crate(Parent, CF, Size, Label, Color)
	local Mo = Kit.Model(Parent, "Crate")
	Kit.Part(Mo, "Body", Size, CF * CFrame.new(0, Size.Y / 2, 0), Color or Color3.fromRGB(196, 150, 96), M.WoodPlanks)
	for _, Y in { 0.18, 0.82 } do
		Kit.Detail(Kit.Part(Mo, "Band", Size + Vector3.new(0.15, -Size.Y + 0.35, 0.15), CF * CFrame.new(0, Size.Y * Y, 0), P.Iron, M.Metal))
	end
	if Label then
		local L = Kit.Detail(Kit.Part(Mo, "Label", Vector3.new(Size.X * 0.8, Size.Y * 0.4, Size.Z + 0.1), CF * CFrame.new(0, Size.Y / 2, 0), Color3.new(1, 1, 1)))
		L.Transparency = 1
		Kit.Text(L, Enum.NormalId.Front, Label, P.White, P.Black)
		Kit.Text(L, Enum.NormalId.Back, Label, P.White, P.Black)
	end
	return Mo
end

-- A puff of steam blowing along Dir (default up). Keep these few: about 8 per map.
function Kit.Steam(Parent, Pos, Dir, Rate, Size)
	local Pt = Kit.Detail(Kit.Part(Parent, "SteamEmitter", Vector3.new(1, 1, 1), CFrame.lookAt(Pos, Pos + (Dir or Vector3.new(0, 1, 0))), P.White))
	Pt.Transparency = 1
	local E = Instance.new("ParticleEmitter")
	E.Name = "Steam"
	E.Texture = "rbxasset://textures/particles/smoke_main.dds"
	E.EmissionDirection = Enum.NormalId.Front
	E.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	local S = Size or 3
	E.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S * 0.6), NumberSequenceKeypoint.new(1, S * 2.6) })
	E.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	E.Lifetime = NumberRange.new(2, 3.2)
	E.Rate = Rate or 6
	E.Speed = NumberRange.new(5, 8)
	E.SpreadAngle = Vector2.new(12, 12)
	E.Acceleration = Vector3.new(0, 2.5, 0)
	E.Rotation = NumberRange.new(0, 360)
	E.RotSpeed = NumberRange.new(-25, 25)
	E.LightEmission = 0.1
	E.Parent = Pt
	return Pt
end

----------------------------------------------------------------------------------------------------
-- Style v2 (2026-10-10): the agreed house style (see SKILL.md "Style guide" and references/).
-- Chunky readable shapes, dark caps over light walls, outlined props, hazard paint, numbers, no words.
----------------------------------------------------------------------------------------------------

-- A colour nudged darker (F > 0) or lighter (F < 0): outlines, rims and subtle panel variation.
function Kit.Shade(Color, F)
	if F >= 0 then return Color:Lerp(Color3.new(0, 0, 0), F) end
	return Color:Lerp(Color3.new(1, 1, 1), -F)
end

-- A slab with rounded corners seen from above. Center = the slab's centre point, R = corner radius.
function Kit.RoundedSlab(Parent, Name, Center, W, D, H, R, Color, Material)
	local Mo = Kit.Model(Parent, Name)
	R = math.min(R, W / 2 - 0.05, D / 2 - 0.05)
	Kit.Box(Mo, "SlabX", Vector3.new(W - 2 * R, H, D), Center, Color, Material)
	Kit.Box(Mo, "SlabZ", Vector3.new(W, H, D - 2 * R), Center, Color, Material)
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		Kit.VCyl(Mo, "SlabCorner", 2 * R, H, Center + Vector3.new(SX * (W / 2 - R), 0, SZ * (D / 2 - R)), Color, Material)
	end end
	return Mo
end

-- A block with its four vertical edges chamfered at 45 degrees (an octagon in plan). CF = centre.
function Kit.ChamferBox(Parent, Name, CF, Size, C, Color, Material)
	local Mo = Kit.Model(Parent, Name)
	C = math.min(C, Size.X / 2 - 0.05, Size.Z / 2 - 0.05)
	Kit.Part(Mo, "Core", Vector3.new(Size.X - 2 * C, Size.Y, Size.Z), CF, Color, Material)
	Kit.Part(Mo, "Core", Vector3.new(Size.X, Size.Y, Size.Z - 2 * C), CF, Color, Material)
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		Kit.Part(Mo, "Chamfer", Vector3.new(C * math.sqrt(2), Size.Y, C * math.sqrt(2)), CF * CFrame.new(SX * (Size.X / 2 - C), 0, SZ * (Size.Z / 2 - C)) * CFrame.Angles(0, math.pi / 4, 0), Color, Material)
	end end
	return Mo
end

-- The 12 edges of a box as thin strips: the cartoon outline that every prop gets. CF = box centre.
-- Every visible outline face stands Pad studs clear of the box's own faces, or the two z-fight from a distance:
-- the sides and top stick out by Pad. The bottom is the other way round: the bottom edges sit Pad ABOVE the box's
-- bottom face, so a box hanging in the air keeps a clean underside, and outlines of stacked boxes only touch.
function Kit.Outline(Parent, CF, Size, T, Color, Material)
	local H = Size / 2
	local Pad = 0.06
	local Y0, Y1 = -H.Y + Pad, H.Y + Pad -- outline spans these heights (box centre = 0)
	local YC = (Y0 + Y1) / 2
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		Kit.Detail(Kit.Part(Parent, "Edge", Vector3.new(T, Y1 - Y0, T), CF * CFrame.new(SX * (H.X + Pad - T / 2), YC, SZ * (H.Z + Pad - T / 2)), Color, Material))
	end end
	for _, EY in { Y0 + T / 2, Y1 - T / 2 } do
		for _, SZ in { -1, 1 } do
			Kit.Detail(Kit.Part(Parent, "Edge", Vector3.new(Size.X + 2 * Pad, T, T), CF * CFrame.new(0, EY, SZ * (H.Z + Pad - T / 2)), Color, Material))
		end
		for _, SX in { -1, 1 } do
			Kit.Detail(Kit.Part(Parent, "Edge", Vector3.new(T, T, Size.Z + 2 * Pad), CF * CFrame.new(SX * (H.X + Pad - T / 2), EY, 0), Color, Material))
		end
	end
end

-- Shipping container (20 ft, stylized): body, darker outline frame, corrugation ribs, door bars.
-- CF = ground point under its centre; the long axis is CF's Z. Returns the model.
function Kit.Container(Parent, CF, Color, Seed)
	local Mo = Kit.Model(Parent, "Container")
	local R = Random.new(Seed or 1)
	local Body = Color:Lerp(Color3.new(1, 1, 1), R:NextNumber(-0.03, 0.05))
	local S = Vector3.new(7, 7.4, 16)
	local C = CF * CFrame.new(0, S.Y / 2, 0)
	Kit.Part(Mo, "Body", S, C, Body)
	Kit.Outline(Mo, C, S + Vector3.new(0.1, 0, 0.1), 0.55, Kit.Shade(Body, 0.38))
	for _, SX in { -1, 1 } do
		for K = 0, 4 do
			Kit.Detail(Kit.Part(Mo, "Rib", Vector3.new(0.25, S.Y - 1.4, 1.3), C * CFrame.new(SX * (S.X / 2 + 0.1), 0, -5.6 + K * 2.8), Kit.Shade(Body, 0.14)))
		end
	end
	for _, X in { -1.2, 1.2 } do
		Kit.Detail(Kit.Part(Mo, "DoorBar", Vector3.new(0.25, S.Y - 1.4, 0.25), C * CFrame.new(X, 0, S.Z / 2 + 0.12), Kit.Shade(Body, 0.4)))
	end
	Kit.Detail(Kit.Part(Mo, "DoorSeam", Vector3.new(0.12, S.Y - 1.2, 0.12), C * CFrame.new(0, 0, S.Z / 2 + 0.06), Kit.Shade(Body, 0.5)))
	Mo.PrimaryPart = Mo.Body
	return Mo
end

-- A crate with a dark outline frame and plank lines. CF = ground point under its centre.
function Kit.OutlinedCrate(Parent, CF, Size, Color)
	local Mo = Kit.Model(Parent, "Crate")
	local C = CF * CFrame.new(0, Size.Y / 2, 0)
	Kit.Part(Mo, "Body", Size, C, Color, M.WoodPlanks)
	Kit.Outline(Mo, C, Size + Vector3.new(0.08, 0, 0.08), math.max(0.4, Size.X * 0.09), Kit.Shade(Color, 0.45))
	return Mo
end

-- White plastic road barrier (Jersey profile). CF = ground point, length along CF's X.
function Kit.JerseyBarrier(Parent, CF, Length, Color)
	local Mo = Kit.Model(Parent, "Barrier")
	Color = Color or Color3.fromRGB(240, 242, 246)
	Kit.Part(Mo, "Base", Vector3.new(Length, 1.2, 2.4), CF * CFrame.new(0, 0.6, 0), Color)
	Kit.Part(Mo, "Top", Vector3.new(Length, 2.0, 1.0), CF * CFrame.new(0, 2.2, 0), Color)
	for _, S in { -1, 1 } do
		Kit.Detail(Kit.Wedge(Mo, "Slope", Vector3.new(Length, 0.9, 0.7), CF * CFrame.new(0, 1.65, S * 0.85) * CFrame.Angles(0, (S > 0) and math.pi or 0, 0), Color))
	end
	Kit.Detail(Kit.Part(Mo, "Notch", Vector3.new(Length * 0.3, 0.6, 1.14), CF * CFrame.new(0, 3.0, 0), Kit.Shade(Color, 0.12))) -- 0.07 proud of Top on every face
	return Mo
end

-- Quay bollard: navy post with a yellow cap.
function Kit.Bollard(Parent, Base, Color, CapColor)
	local Mo = Kit.Model(Parent, "Bollard")
	Kit.VCyl(Mo, "Post", 1.8, 2.6, Base + Vector3.new(0, 1.3, 0), Color)
	Kit.Detail(Kit.VCyl(Mo, "Cap", 2.4, 0.6, Base + Vector3.new(0, 2.9, 0), CapColor))
	Kit.Detail(Kit.VCyl(Mo, "Foot", 2.6, 0.4, Base + Vector3.new(0, 0.2, 0), Kit.Shade(Color, 0.25)))
	return Mo
end

-- A square pyramid from four CornerWedgeParts (a CornerWedge is tallest at its local +X/-Z corner).
-- BaseCenter = centre of the square base; Down = true hangs it point-down below the base. Yaw turns it.
function Kit.Pyramid(Parent, Name, BaseCenter, B, H, Color, Material, Down, Yaw)
	local Mo = Kit.Model(Parent, Name)
	Yaw = Yaw or 0
	local Up = { [1] = { [1] = math.pi / 2, [-1] = math.pi }, [-1] = { [1] = 0, [-1] = -math.pi / 2 } }
	local Dn = { [1] = { [1] = math.pi, [-1] = -math.pi / 2 }, [-1] = { [1] = math.pi / 2, [-1] = 0 } }
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		local Off = CFrame.Angles(0, Yaw, 0) * Vector3.new(SX * B / 4, 0, SZ * B / 4)
		local Pos = BaseCenter + Off + Vector3.new(0, Down and -H / 2 or H / 2, 0)
		local CF = Down and (CFrame.new(Pos) * CFrame.Angles(0, Dn[SX][SZ] + Yaw, 0) * CFrame.Angles(math.pi, 0, 0))
			or (CFrame.new(Pos) * CFrame.Angles(0, Up[SX][SZ] + Yaw, 0))
		Kit.Part(Mo, "Facet", Vector3.new(B / 2, H, B / 2), CF, Color, Material, "CornerWedgePart")
	end end
	return Mo
end

-- Faceted gem shrub (two pyramids point to point, turned 45 degrees) in a small square planter.
function Kit.GemShrub(Parent, Base, Size, Color, PlanterColor, RimColor)
	local Mo = Kit.Model(Parent, "GemShrub")
	local PS = Size * 1.2
	Kit.Box(Mo, "Planter", Vector3.new(PS, 1.2, PS), Base + Vector3.new(0, 0.6, 0), PlanterColor, M.Concrete)
	Kit.Detail(Kit.Box(Mo, "Rim", Vector3.new(PS + 0.3, 0.3, PS + 0.3), Base + Vector3.new(0, 1.25, 0), RimColor))
	local Mid = Base + Vector3.new(0, 1.3 + Size * 0.55, 0)
	local Top = Kit.Pyramid(Mo, "GemTop", Mid, Size, Size * 1.25, Color, nil, false, math.pi / 4)
	local Bot = Kit.Pyramid(Mo, "GemBottom", Mid, Size, Size * 0.55, Kit.Shade(Color, 0.15), nil, true, math.pi / 4)
	for _, Pt in Top:GetChildren() do Kit.Ghost(Pt) end
	for _, Pt in Bot:GetChildren() do Kit.Ghost(Pt) end
	return Mo
end

-- Floodlight mast: chamfered foot, navy pole, a head with glowing panels facing Dir.
function Kit.FloodMast(Parent, Base, Height, Dir, Color, GlowColor)
	local Mo = Kit.Model(Parent, "FloodMast")
	Dir = Vector3.new(Dir.X, 0, Dir.Z).Unit
	Kit.ChamferBox(Mo, "Foot", CFrame.new(Base + Vector3.new(0, 0.8, 0)), Vector3.new(3.2, 1.6, 3.2), 0.6, Kit.Shade(Color, 0.2), M.Concrete)
	Kit.VCyl(Mo, "Pole", 1.0, Height, Base + Vector3.new(0, 1.6 + Height / 2, 0), Color)
	local HeadCF = CFrame.lookAt(Base + Vector3.new(0, Height + 2.6, 0), Base + Vector3.new(0, Height + 2.6, 0) + Dir) * CFrame.Angles(math.rad(-20), 0, 0)
	Kit.Detail(Kit.Part(Mo, "Head", Vector3.new(6, 3, 1.4), HeadCF, Color))
	for _, X in { -1.5, 1.5 } do
		Kit.Detail(Kit.Part(Mo, "Lamp", Vector3.new(2.4, 2.2, 0.3), HeadCF * CFrame.new(X, 0, -0.75), GlowColor, M.Neon))
	end
	return Mo
end

-- A window wall on a face: a glass pane inside a deep frame, with a grid of dark bars. FCF from Kit.FaceCF.
function Kit.WindowWall(Parent, FCF, Along, Up, W, H, Cols, Rows, GlassColor, FrameColor)
	local G = Kit.Detail(Kit.OnFace(Parent, "Glass", FCF, Along, Up, W, H, 0.2, GlassColor))
	G.Reflectance = 0.25
	local T = 0.7
	Kit.Detail(Kit.OnFace(Parent, "Frame", FCF, Along, Up + H / 2 + T / 2, W + 2 * T, T, 0.9, FrameColor))
	Kit.Detail(Kit.OnFace(Parent, "Frame", FCF, Along, Up - H / 2 - T / 2, W + 2 * T, T, 0.9, FrameColor))
	Kit.Detail(Kit.OnFace(Parent, "Frame", FCF, Along - W / 2 - T / 2, Up, T, H, 0.9, FrameColor))
	Kit.Detail(Kit.OnFace(Parent, "Frame", FCF, Along + W / 2 + T / 2, Up, T, H, 0.9, FrameColor))
	for K = 1, Cols - 1 do
		Kit.Detail(Kit.OnFace(Parent, "Bar", FCF, Along - W / 2 + K * W / Cols, Up, 0.35, H, 0.45, FrameColor))
	end
	for K = 1, Rows - 1 do
		Kit.Detail(Kit.OnFace(Parent, "Bar", FCF, Along, Up - H / 2 + K * H / Rows, W, 0.35, 0.45, FrameColor))
	end
end

-- A flight of solid steps rising along CF's LookVector, with dark side rails (decoration).
-- CF = ground point at the foot of the stairs, centre of the width.
function Kit.Stairs(Parent, CF, Width, Rise, Run, Color, RailColor)
	local Mo = Kit.Model(Parent, "Stairs")
	local N = math.max(2, math.floor(Rise / 1.2 + 0.5))
	local SH, SD = Rise / N, Run / N
	for K = 1, N do
		local Top = K * SH
		Kit.Part(Mo, "Step", Vector3.new(Width, Top, SD), CF * CFrame.new(0, Top / 2, -(K - 0.5) * SD), Color, M.Concrete)
		-- nosing stands 0.06 proud of the step's top, front and sides, so the two never share a face
		Kit.Detail(Kit.Part(Mo, "Nosing", Vector3.new(Width + 0.12, 0.2, 0.46), CF * CFrame.new(0, Top - 0.04, -(K - 1) * SD - 0.17), Kit.Shade(Color, 0.18)))
	end
	for _, SX in { -1, 1 } do -- rails 0.25 in: posts' outer faces then sit 0.1 inside the steps' sides, not 0.05
		local A = (CF * CFrame.new(SX * (Width / 2 - 0.25), 3.2, -0.3)).Position
		local B = (CF * CFrame.new(SX * (Width / 2 - 0.25), Rise + 3.2, -Run + 0.3)).Position
		Kit.Detail(Kit.BeamBetween(Mo, "Rail", A, B, 0.35, 0.35, RailColor))
		for _, T in { 0.05, 0.5, 0.95 } do
			local P = A:Lerp(B, T)
			Kit.Detail(Kit.Part(Mo, "RailPost", Vector3.new(0.3, 3.2, 0.3), CFrame.new(P - Vector3.new(0, 1.6, 0)), RailColor))
		end
	end
	return Mo
end

-- Diagonal hazard stripes painted on one face of a part (SurfaceGui + hard-stepped UIGradient).
function Kit.HazardPaint(Pt, Face, ColorA, ColorB, Bands)
	local G = Instance.new("SurfaceGui")
	G.Name = "Hazard"
	G.Face = Face or Enum.NormalId.Front
	G.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	G.PixelsPerStud = 20
	G.LightInfluence = 1
	G.Parent = Pt
	local F = Instance.new("Frame")
	F.Size = UDim2.fromScale(1, 1)
	F.BorderSizePixel = 0
	F.BackgroundColor3 = Color3.new(1, 1, 1)
	F.Parent = G
	local Grad = Instance.new("UIGradient")
	local Keys = {}
	Bands = math.clamp(Bands or 8, 2, 10)
	for I = 0, Bands - 1 do
		local C = (I % 2 == 0) and ColorA or ColorB
		local T0, T1 = I / Bands, (I + 1) / Bands
		table.insert(Keys, ColorSequenceKeypoint.new(I == 0 and 0 or T0 + 0.001, C))
		table.insert(Keys, ColorSequenceKeypoint.new(I == Bands - 1 and 1 or T1, C))
	end
	Grad.Color = ColorSequence.new(Keys)
	Grad.Rotation = 45
	Grad.Parent = F
	return G
end

-- A painted number (digits only, never words) on a face, in a heavy squared font that follows the lighting.
function Kit.PaintNumber(Pt, Face, Text, Color, StrokeColor)
	local G = Kit.Text(Pt, Face, Text, Color or P.White, StrokeColor or P.Black)
	G.LightInfluence = 1
	-- TextScaled caps at 100 px, so at 40 px/stud letters can't exceed 2.5 studs; big numbers need fewer px/stud
	G.PixelsPerStud = 12
	local L = G:FindFirstChildWhichIsA("TextLabel")
	if L then
		L.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy)
		local S = L:FindFirstChildWhichIsA("UIStroke")
		if S then S.Thickness = 3 end
	end
	return G
end

-- Diagonal hazard stripes over any rectangle on a face: square tiles, each with 4 bands, which line up into
-- continuous stripes. (HazardPaint on its own only looks right on a roughly square face.)
function Kit.HazardTiles(Parent, FCF, Along, Up, W, H, Out, ColorA, ColorB)
	local S = math.min(W, H)
	local NW, NH = math.max(1, math.floor(W / S + 0.5)), math.max(1, math.floor(H / S + 0.5))
	local TW, TH = W / NW, H / NH
	for I = 0, NW - 1 do for J = 0, NH - 1 do
		local T = Kit.Detail(Kit.OnFace(Parent, "HazardTile", FCF, Along - W / 2 + TW * (I + 0.5), Up - H / 2 + TH * (J + 0.5), TW, TH, Out, ColorA))
		Kit.HazardPaint(T, Enum.NormalId.Front, ColorA, ColorB, 4)
	end end
end

-- Chain-link fence from A to B (ground points): navy posts with white bands and feet, rails, a clipped
-- diagonal white mesh, a razor-wire zigzag, and one invisible collider per panel.
function Kit.ChainLink(Parent, A, B, Height, PostColor, MeshColor)
	local Mo = Kit.Model(Parent, "ChainLink")
	local Len = (B - A).Magnitude
	local Dir = (B - A).Unit
	local Panels = math.max(1, math.floor(Len / 8 + 0.5))
	local PW = Len / Panels
	local Base = CFrame.lookAt(A, B) -- -Z runs along the fence
	for I = 0, Panels do
		local P = A + Dir * (I * PW)
		Kit.VCyl(Mo, "Post", 0.5, Height + 0.4, P + Vector3.new(0, (Height + 0.4) / 2, 0), PostColor)
		Kit.Detail(Kit.VCyl(Mo, "PostFoot", 0.95, 0.5, P + Vector3.new(0, 0.25, 0), MeshColor))
		Kit.Detail(Kit.VCyl(Mo, "PostBand", 0.62, 0.4, P + Vector3.new(0, Height * 0.62, 0), MeshColor))
	end
	for _, Y in { 0.5, Height } do
		Kit.Detail(Kit.CylBetween(Mo, "Rail", 0.3, A + Vector3.new(0, Y, 0), B + Vector3.new(0, Y, 0), PostColor))
	end
	local Gap = 2.0
	local MH = Height - 0.7
	for I = 0, Panels - 1 do
		local P0 = A + Dir * (I * PW)
		-- clip both diagonal families to the panel rectangle [0, PW] x [0, MH]
		for _, Sgn in { 1, -1 } do
			local C = -MH
			while C < PW do
				local Pts = {}
				local function Try(u, v) if u >= -1e-6 and u <= PW + 1e-6 and v >= -1e-6 and v <= MH + 1e-6 then table.insert(Pts, Vector2.new(u, v)) end end
				if Sgn > 0 then -- v = u - C
					Try(C, 0); Try(C + MH, MH); Try(0, -C); Try(PW, PW - C)
				else -- v = (PW - u) - C  (mirror)
					Try(PW - C, 0); Try(PW - C - MH, MH); Try(PW, -C); Try(0, PW - C)
				end
				if #Pts >= 2 then
					local U1, U2 = Pts[1], Pts[1]
					for _, Q in Pts do
						if Q.X < U1.X or (Q.X == U1.X and Q.Y < U1.Y) then U1 = Q end
						if Q.X > U2.X or (Q.X == U2.X and Q.Y > U2.Y) then U2 = Q end
					end
					if (U2 - U1).Magnitude > 0.3 then
						local W1 = P0 + Dir * U1.X + Vector3.new(0, 0.5 + U1.Y, 0)
						local W2 = P0 + Dir * U2.X + Vector3.new(0, 0.5 + U2.Y, 0)
						Kit.Detail(Kit.BeamBetween(Mo, "Mesh", W1, W2, 0.09, 0.09, MeshColor))
					end
				end
				C += Gap
			end
		end
		local Col = Kit.Part(Mo, "Collider", Vector3.new(0.4, Height, PW), CFrame.lookAt(P0 + Dir * (PW / 2) + Vector3.new(0, Height / 2, 0), P0 + Dir * PW + Vector3.new(0, Height / 2, 0)), MeshColor)
		Col.Transparency = 1
		Col.CastShadow = false
	end
	-- razor wire: a zigzag riding on the top rail
	local Steps = math.floor(Len / 0.9)
	local Prev
	for K = 0, Steps do
		local P = A + Dir * (K * Len / Steps) + Vector3.new(0, Height + ((K % 2 == 0) and 0.2 or 1.1), 0)
		if Prev then Kit.Detail(Kit.BeamBetween(Mo, "Razor", Prev, P, 0.08, 0.08, MeshColor)) end
		Prev = P
	end
	return Mo
end

----------------------------------------------------------------------------------------------------
-- Preview lighting: GPT Playground's own Lighting is grey and hazy, nothing like the game's. These
-- swap in a copy of PillowBattles PROD's Lighting for screenshots and put the original back after.
-- ALWAYS call PreviewLightingOff when the captures are done; the Playground is shared with Codex.
----------------------------------------------------------------------------------------------------

local LIGHTING_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation", "GeographicLatitude" }

function Kit.PreviewLightingOn()
	local L = game:GetService("Lighting")
	local SS = game:GetService("ServerStorage")
	if SS:FindFirstChild("ClaudeLightingStash") then
		return "already on"
	end
	local Stash = Instance.new("Folder")
	Stash.Name = "ClaudeLightingStash"
	for _, Name in LIGHTING_PROPS do
		Stash:SetAttribute(Name, L[Name])
	end
	Stash.Parent = SS
	for _, Child in L:GetChildren() do
		Child.Parent = Stash
	end
	-- PillowBattles PROD values, read 2026-10-09
	L.ClockTime = 10
	L.Brightness = 0.67
	L.Ambient = Color3.new(0.666667, 0.666667, 0.666667)
	L.OutdoorAmbient = Color3.new(1, 0.92549, 0.756863)
	L.ColorShift_Top = Color3.new(0.843137, 0.745098, 0.529412)
	L.ColorShift_Bottom = Color3.new(0, 0, 0)
	L.EnvironmentDiffuseScale = 0.6
	L.EnvironmentSpecularScale = 0.4
	L.ExposureCompensation = 0.2
	L.GeographicLatitude = 144
	local A = Instance.new("Atmosphere")
	A.Name = "ClaudePreview_Atmosphere"
	A.Density, A.Offset, A.Glare, A.Haze = 0.12, 0.1, 0.67, 2
	A.Color, A.Decay = Color3.new(0.784314, 0.941176, 1), Color3.new(0.470588, 0.705882, 1)
	A.Parent = L
	local Sky = Instance.new("Sky")
	Sky.Name = "ClaudePreview_Sky"
	Sky.SkyboxBk, Sky.SkyboxDn, Sky.SkyboxFt = "rbxassetid://6295671271", "rbxassetid://6295671382", "rbxassetid://6295671136"
	Sky.SkyboxLf, Sky.SkyboxRt, Sky.SkyboxUp = "rbxassetid://6295670996", "rbxassetid://6295671509", "rbxassetid://6295671667"
	Sky.SunAngularSize, Sky.CelestialBodiesShown, Sky.StarCount = 10, false, 0
	Sky.Parent = L
	local B = Instance.new("BloomEffect")
	B.Name = "ClaudePreview_Bloom"
	B.Intensity, B.Size, B.Threshold = 0.15, 32, 0.85
	B.Parent = L
	local CC = Instance.new("ColorCorrectionEffect")
	CC.Name = "ClaudePreview_ColorCorrection"
	CC.Contrast, CC.Saturation = 0.2, 0.3
	CC.Parent = L
	local SR = Instance.new("SunRaysEffect")
	SR.Name = "ClaudePreview_SunRays"
	SR.Intensity, SR.Spread = 0.25, 1
	SR.Parent = L
	return "on"
end

function Kit.PreviewLightingOff()
	local L = game:GetService("Lighting")
	local Stash = game:GetService("ServerStorage"):FindFirstChild("ClaudeLightingStash")
	if not Stash then
		return "already off"
	end
	for _, Child in L:GetChildren() do
		if Child.Name:sub(1, 14) == "ClaudePreview_" then
			Child:Destroy()
		end
	end
	for _, Child in Stash:GetChildren() do
		Child.Parent = L
	end
	for Name, Value in Stash:GetAttributes() do
		L[Name] = Value
	end
	Stash:Destroy()
	return "off"
end

return Kit
