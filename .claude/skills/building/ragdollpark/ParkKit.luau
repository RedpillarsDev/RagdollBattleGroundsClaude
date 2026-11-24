--!nocheck
--[[ ClaudeParkKit: compact part helpers for the Ragdoll Park map (2026-11-23, Guts' session).
Same conventions as ClaudeBuildKit (Anchored, Smooth surfaces, SmoothPlastic default, Detail = no collide/query/touch/
shadow, Ghost = no collide but casts shadow, outlines stand 0.06 proud) plus hand-painted Textures.

TEXTURES ARE LOCAL FILES, NOT UPLOADS: K.TexDir points at rbxasset://ragdollpark3/, a folder inside THIS PC's Studio
install (content/ragdollpark3/). They show only in Studio on that PC and vanish when Studio updates its version folder;
every textured part keeps a fallback Color (the texture's average x tint), so other PCs see clean flat colours.
When the PNGs are uploaded, set K.TexIds[name] = "rbxassetid://..." and rerun K.Retexture(root) (or the chunks).

Install (execute_luau, Edit):  paste into a ModuleScript ServerStorage.ClaudeParkKit, then in every chunk:
	local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
]]
local K = {}
K.Version = "2026-11-24.3"
local M = Enum.Material
K.TexDir = "rbxasset://ragdollpark3/"
K.TexIds = {} -- name -> uploaded rbxassetid, overrides TexDir when set
K.TexAvg = { acid = {123,221,54}, hazard = {140,117,51}, lava = {138,81,38}, r_bark = {86,67,53}, r_galv = {167,172,177},
	r_leaves = {42,70,26}, r_leaves2 = {49,71,23}, r_olive = {85,95,67}, r_olive2 = {110,109,55}, r_pine = {28,55,33}, r_plaza = {157,157,153},
	r_pool = {135,177,191}, r_sand = {205,182,138}, r_steel = {74,79,87}, r_stone = {130,127,123}, r_tread = {104,109,114},
	r_water = {80,161,200}, r_white = {195,195,191}, r_wood = {116,84,58}, r_wood_h = {116,84,58}, r_yellow = {211,167,34},
	r_slab = {156,156,150}, r_slab1 = {159,159,154},
	w_lane = {183,136,86}, w_birch = {204,176,137}, w_dark = {71,46,29}, w_ramp = {188,172,112} }

function K.Part(Parent, Name, Size, CF, Color, Material, ClassName)
	local Pt = Instance.new(ClassName or "Part")
	Pt.Name = Name; Pt.Anchored = true; Pt.Size = Size; Pt.CFrame = CF; Pt.Color = Color or Color3.new(1, 1, 1)
	Pt.Material = Material or M.SmoothPlastic; Pt.TopSurface = Enum.SurfaceType.Smooth; Pt.BottomSurface = Enum.SurfaceType.Smooth
	Pt.Parent = Parent
	return Pt
end
function K.Box(Parent, Name, Size, Pos, Color, Material) return K.Part(Parent, Name, Size, CFrame.new(Pos), Color, Material) end
function K.BoxMM(Parent, Name, Min, Max, Color, Material) return K.Part(Parent, Name, Max - Min, CFrame.new((Min + Max) / 2), Color, Material) end
function K.Wedge(Parent, Name, Size, CF, Color, Material) return K.Part(Parent, Name, Size, CF, Color, Material, "WedgePart") end -- tall face +Z, slope falls to -Z
function K.Cyl(Parent, Name, D, L, CF, Color, Material) -- along X
	local Pt = K.Part(Parent, Name, Vector3.new(L, D, D), CF, Color, Material); Pt.Shape = Enum.PartType.Cylinder; return Pt
end
function K.VCyl(Parent, Name, D, H, Pos, Color, Material) return K.Cyl(Parent, Name, D, H, CFrame.new(Pos) * CFrame.Angles(0, 0, math.pi / 2), Color, Material) end
function K.CylBetween(Parent, Name, D, A, B, Color, Material)
	return K.Cyl(Parent, Name, D, (B - A).Magnitude, CFrame.lookAt((A + B) / 2, B) * CFrame.Angles(0, math.pi / 2, 0), Color, Material)
end
function K.BeamBetween(Parent, Name, A, B, TX, TY, Color, Material)
	return K.Part(Parent, Name, Vector3.new(TX, TY, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), Color, Material)
end
function K.Ball(Parent, Name, D, Pos, Color, Material)
	local Pt = K.Part(Parent, Name, Vector3.new(D, D, D), CFrame.new(Pos), Color, Material); Pt.Shape = Enum.PartType.Ball; return Pt
end
function K.Detail(Pt) Pt.CanCollide = false; Pt.CanTouch = false; Pt.CanQuery = false; Pt.CastShadow = false; return Pt end
function K.Ghost(Pt) Pt.CanCollide = false; Pt.CanTouch = false; Pt.CanQuery = false; return Pt end
function K.Folder(Parent, Name)
	local F = Parent:FindFirstChild(Name)
	if not F then F = Instance.new("Folder"); F.Name = Name; F.Parent = Parent end
	return F
end
function K.Clear(C) for _, Ch in C:GetChildren() do Ch:Destroy() end return C end
function K.Model(Parent, Name) local Mo = Instance.new("Model"); Mo.Name = Name; Mo.Parent = Parent; return Mo end
function K.Shade(C, F) if F >= 0 then return C:Lerp(Color3.new(0, 0, 0), F) end return C:Lerp(Color3.new(1, 1, 1), -F) end
function K.RGB(T) return Color3.fromRGB(T[1], T[2], T[3]) end

-- Hand-painted Texture on faces. Faces: "top" | "all" | "sides" | "topsides" | {NormalId...}. U/V = studs per tile.
local FaceSets = {
	top = { Enum.NormalId.Top }, bottom = { Enum.NormalId.Bottom },
	sides = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right },
	all = Enum.NormalId:GetEnumItems(),
	topsides = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right },
}
function K.Tex(Pt, Name, U, V, Faces, Tint, Transp)
	Tint = Tint or Color3.new(1, 1, 1)
	local A = K.TexAvg[Name] or { 200, 200, 200 }
	Pt.Color = Color3.new(A[1] / 255 * Tint.R, A[2] / 255 * Tint.G, A[3] / 255 * Tint.B) -- fallback when the image is missing
	Faces = typeof(Faces) == "table" and Faces or FaceSets[Faces or "all"]
	for _, F in Faces do
		local T = Instance.new("Texture")
		T.Name = "PT_" .. Name; T.Face = F; T.Texture = K.TexIds[Name] or (K.TexDir .. Name .. ".png")
		T.StudsPerTileU = U; T.StudsPerTileV = V or U; T.Color3 = Tint; T.Transparency = Transp or 0
		T:SetAttribute("PaintedTex", Name)
		T.Parent = Pt
	end
	return Pt
end
-- After uploading: point every painted Texture under Root at the uploaded ids.
function K.Retexture(Root)
	local N = 0
	for _, T in Root:GetDescendants() do
		if T:IsA("Texture") and T:GetAttribute("PaintedTex") then
			local Name = T:GetAttribute("PaintedTex"); T.Texture = K.TexIds[Name] or (K.TexDir .. Name .. ".png"); N += 1
		end
	end
	return N
end

-- 12-edge cartoon outline; every face 0.06 proud of the box, bottoms 0.06 above the box bottom (ClaudeBuildKit rule).
function K.Outline(Parent, CF, Size, T, Color)
	local H = Size / 2; local Pad = 0.06; local Y0, Y1 = -H.Y + Pad, H.Y + Pad; local YC = (Y0 + Y1) / 2
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		K.Detail(K.Part(Parent, "Edge", Vector3.new(T, Y1 - Y0, T), CF * CFrame.new(SX * (H.X + Pad - T / 2), YC, SZ * (H.Z + Pad - T / 2)), Color))
	end end
	for _, EY in { Y0 + T / 2, Y1 - T / 2 } do
		for _, SZ in { -1, 1 } do K.Detail(K.Part(Parent, "Edge", Vector3.new(Size.X + 2 * Pad, T, T), CF * CFrame.new(0, EY, SZ * (H.Z + Pad - T / 2)), Color)) end
		for _, SX in { -1, 1 } do K.Detail(K.Part(Parent, "Edge", Vector3.new(T, T, Size.Z + 2 * Pad), CF * CFrame.new(SX * (H.X + Pad - T / 2), EY, 0), Color)) end
	end
end

-- Square pyramid from four CornerWedgeParts (tallest at local +X/-Z). Down = point-down.
function K.Pyramid(Parent, Name, BaseCenter, B, H, Color, Material, Down, Yaw)
	local Mo = K.Model(Parent, Name); Yaw = Yaw or 0
	local Up = { [1] = { [1] = math.pi / 2, [-1] = math.pi }, [-1] = { [1] = 0, [-1] = -math.pi / 2 } }
	local Dn = { [1] = { [1] = math.pi, [-1] = -math.pi / 2 }, [-1] = { [1] = math.pi / 2, [-1] = 0 } }
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		local Pos = BaseCenter + CFrame.Angles(0, Yaw, 0) * Vector3.new(SX * B / 4, 0, SZ * B / 4) + Vector3.new(0, Down and -H / 2 or H / 2, 0)
		local CF = Down and (CFrame.new(Pos) * CFrame.Angles(0, Dn[SX][SZ] + Yaw, 0) * CFrame.Angles(math.pi, 0, 0)) or (CFrame.new(Pos) * CFrame.Angles(0, Up[SX][SZ] + Yaw, 0))
		K.Part(Mo, "Facet", Vector3.new(B / 2, H, B / 2), CF, Color, Material, "CornerWedgePart")
	end end
	return Mo
end

-- Ring of box segments around Center (local Y up). Segments touch at their inner corners; returns the model.
function K.Ring(Parent, Name, Center, R, Width, Height, Count, Color, Material, Phase)
	local Mo = K.Model(Parent, Name); Phase = Phase or 0
	local Len = 2 * math.pi * (R + Width / 2) / Count + 0.02
	for I = 1, Count do
		local A = Phase + (I - 0.5) / Count * 2 * math.pi
		K.Part(Mo, "Seg", Vector3.new(Len, Height, Width), CFrame.new(Center) * CFrame.Angles(0, -A, 0) * CFrame.new(0, 0, -(R + Width / 2)) * CFrame.Angles(0, 0, 0), Color, Material)
	end
	return Mo
end

-- Steps rising along CF.LookVector. CF = ground point at the foot, centre of the width. Tex = painted texture name.
function K.Stairs(Parent, CF, Width, Rise, Run, Color, RailColor, Tex, Tint)
	local Mo = K.Model(Parent, "Stairs")
	local N = math.max(2, math.floor(Rise / 1.2 + 0.5)); local SH, SD = Rise / N, Run / N
	for I = 1, N do
		local Top = I * SH
		local S = K.Part(Mo, "Step", Vector3.new(Width, Top, SD), CF * CFrame.new(0, Top / 2, -(I - 0.5) * SD), Color)
		if Tex then K.Tex(S, Tex, 4, 4, "top", Tint) end
		K.Detail(K.Part(Mo, "Nosing", Vector3.new(Width + 0.12, 0.2, 0.46), CF * CFrame.new(0, Top - 0.04, -(I - 1) * SD - 0.17), K.Shade(Color, 0.25)))
	end
	if RailColor then
		for _, SX in { -1, 1 } do
			local A = (CF * CFrame.new(SX * (Width / 2 - 0.25), 3.2, -0.3)).Position
			local B = (CF * CFrame.new(SX * (Width / 2 - 0.25), Rise + 3.2, -Run + 0.3)).Position
			K.Detail(K.BeamBetween(Mo, "Rail", A, B, 0.35, 0.35, RailColor))
			for _, T in { 0.05, 0.5, 0.95 } do
				local P = A:Lerp(B, T); K.Detail(K.Part(Mo, "RailPost", Vector3.new(0.3, 3.2, 0.3), CFrame.new(P - Vector3.new(0, 1.6, 0)), RailColor))
			end
		end
	end
	return Mo
end

-- BLOCKY trees (owner 2026-11-23: "if u do blocky dont do round, do square with texture"): square bark trunk, square
-- leaf blocks with the painted leaf texture, a little yaw per block. Canopies are Ghost (no collision), trunks collide.
local function LeafBlock(Parent, Name, Size, CF, Tex, R)
	local Pt = K.Ghost(K.Part(Parent, Name, Size, CF))
	local J = R:NextNumber(0.9, 1.08); K.Tex(Pt, Tex, 6, 6, "all", Color3.new(J, J, J))
	return Pt
end
function K.BlockTree(Parent, Base, H, Seed, Tex)
	local R = Random.new(Seed); local Mo = K.Model(Parent, "Tree"); local Yaw = R:NextNumber(0, math.pi / 2); Tex = Tex or "r_leaves"
	local TW = math.max(1.2, H * 0.09)
	K.Tex(K.Part(Mo, "Trunk", Vector3.new(TW, H * 0.56, TW), CFrame.new(Base + Vector3.new(0, H * 0.28, 0)) * CFrame.Angles(0, Yaw, 0)), "r_bark", 3, 6, "sides")
	for I = 1, 2 do -- two square branches leaning out of the trunk top
		local A = Yaw + I * math.pi + R:NextNumber(-0.5, 0.5)
		K.Tex(K.Detail(K.Part(Mo, "Branch", Vector3.new(TW * 0.6, H * 0.26, TW * 0.6),
			CFrame.new(Base + Vector3.new(math.cos(A) * H * 0.07, H * 0.5, math.sin(A) * H * 0.07)) * CFrame.Angles(0, -A, 0) * CFrame.Angles(0, 0, math.rad(35)))), "r_bark", 3, 6, "sides")
	end
	local C = Base + Vector3.new(0, H * 0.64, 0)
	LeafBlock(Mo, "Leaves", Vector3.new(H * 0.56, H * 0.34, H * 0.56), CFrame.new(C) * CFrame.Angles(0, Yaw + R:NextNumber(-0.2, 0.2), 0), Tex, R)
	for I = 1, 3 do
		local A = Yaw + I / 3 * 2 * math.pi + R:NextNumber(-0.3, 0.3); local S = H * R:NextNumber(0.28, 0.36)
		LeafBlock(Mo, "Leaves", Vector3.new(S, S * 0.8, S), CFrame.new(C + Vector3.new(math.cos(A) * H * 0.24, R:NextNumber(-0.1, 0.08) * H, math.sin(A) * H * 0.24)) * CFrame.Angles(0, R:NextNumber(0, math.pi / 2), 0), Tex, R)
	end
	LeafBlock(Mo, "LeavesTop", Vector3.new(H * 0.34, H * 0.22, H * 0.34), CFrame.new(C + Vector3.new(R:NextNumber(-0.04, 0.04) * H, H * 0.24, R:NextNumber(-0.04, 0.04) * H)) * CFrame.Angles(0, R:NextNumber(0, math.pi / 2), 0), Tex, R)
	return Mo
end
function K.BlockPine(Parent, Base, H, Seed)
	local R = Random.new(Seed); local Mo = K.Model(Parent, "Pine"); local Yaw = R:NextNumber(0, math.pi / 2)
	local TW = math.max(1, H * 0.07)
	K.Tex(K.Part(Mo, "Trunk", Vector3.new(TW, H * 0.5, TW), CFrame.new(Base + Vector3.new(0, H * 0.25, 0)) * CFrame.Angles(0, Yaw, 0)), "r_bark", 3, 6, "sides")
	for I = 0, 4 do
		local W = H * (0.46 - 0.078 * I)
		LeafBlock(Mo, "Tier", Vector3.new(W, H * 0.13, W), CFrame.new(Base + Vector3.new(0, H * (0.24 + 0.15 * I), 0)) * CFrame.Angles(0, Yaw + I * R:NextNumber(0.25, 0.5), 0), "r_pine", R)
	end
	LeafBlock(Mo, "Tip", Vector3.new(H * 0.07, H * 0.12, H * 0.07), CFrame.new(Base + Vector3.new(0, H * 0.98, 0)) * CFrame.Angles(0, Yaw, 0), "r_pine", R)
	return Mo
end
function K.BlockShrub(Parent, Base, S, Seed, Tex)
	local R = Random.new(Seed); local Mo = K.Model(Parent, "Shrub"); Tex = Tex or "r_leaves2"
	LeafBlock(Mo, "Leaves", Vector3.new(S, S * 0.75, S), CFrame.new(Base + Vector3.new(0, S * 0.3, 0)) * CFrame.Angles(0, R:NextNumber(0, math.pi / 2), 0), Tex, R)
	LeafBlock(Mo, "Leaves", Vector3.new(S * 0.62, S * 0.5, S * 0.62), CFrame.new(Base + Vector3.new(R:NextNumber(-0.15, 0.15) * S, S * 0.78, R:NextNumber(-0.15, 0.15) * S)) * CFrame.Angles(0, R:NextNumber(0, math.pi / 2), 0), Tex, R)
	return Mo
end

-- Axis-aligned rectangle minus holes -> list of {X0, Z0, X1, Z1} rectangles (for ground with pits cut out).
function K.SubRects(Rect, Holes)
	local Rects = { Rect }
	for _, H in Holes do
		local Out = {}
		for _, R in Rects do
			local X0, Z0, X1, Z1 = math.max(R[1], H[1]), math.max(R[2], H[2]), math.min(R[3], H[3]), math.min(R[4], H[4])
			if X0 >= X1 or Z0 >= Z1 then table.insert(Out, R) else
				if R[2] < Z0 then table.insert(Out, { R[1], R[2], R[3], Z0 }) end
				if Z1 < R[4] then table.insert(Out, { R[1], Z1, R[3], R[4] }) end
				if R[1] < X0 then table.insert(Out, { R[1], Z0, X0, Z1 }) end
				if X1 < R[3] then table.insert(Out, { X1, Z0, R[3], Z1 }) end
			end
		end
		Rects = Out
	end
	return Rects
end

return K
