--!nocheck
-- Ragdoll Park 02 (NE, realistic materials): sunken pool (basin x46..86 z-77..-51, 7.6 deep) in a plank deck, slab coping, ladder,
-- high-dive tower (stairs -> low board at 8, truss -> high board at 22), loungers + umbrellas. Static props.
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local function BMM(P, N, A, B, C) return K.BoxMM(P, N, V(A[1], A[2], A[3]), V(B[1], B[2], B[3]), C) end
local F = K.Clear(K.Folder(workspace.Map.RagdollPark.Content, "Pool")); F:SetAttribute("Station", "Pool")
local NAVY, CORAL, WHITE, ORANGE = Color3.fromRGB(62, 66, 72), Color3.fromRGB(158, 163, 168), Color3.fromRGB(205, 208, 212), Color3.fromRGB(54, 78, 120) -- dark steel, galvanized, stainless, cushion blue
local WT = Color3.new(1, 1, 1)
-- deck (planks run along X) with a navy trim band on its outer edge
for _, R in K.SubRects({ 38, -90, 94, -43 }, { { 46, -77, 86, -51 } }) do
	K.Tex(BMM(F, "Deck", { R[1], -0.15, R[2] }, { R[3], 0.45, R[4] }), "r_wood_h", 6, 6, "topsides")
end
for _, E in { { 37.94, -90.06, 94.06, -89.56 }, { 37.94, -43.44, 94.06, -42.94 }, { 37.94, -89.56, 38.44, -43.44 }, { 93.56, -89.56, 94.06, -43.44 } } do
	K.Detail(BMM(F, "DeckTrim", { E[1], 0, E[2] }, { E[3], 0.51, E[4] }, NAVY))
end
-- coping (single painted slabs), lip 0.2 over the water
for _, C in { { 44.4, -78.6, 87.6, -76.8, 3.2, 1.8 }, { 44.4, -51.2, 87.6, -49.4, 3.2, 1.8 }, { 44.4, -76.8, 46.2, -51.2, 1.8, 3.2 }, { 85.8, -76.8, 87.6, -51.2, 1.8, 3.2 } } do
	K.Tex(BMM(F, "Coping", { C[1], 0, C[2] }, { C[3], 0.62, C[4] }), "r_slab1", C[5], C[6], "topsides", WT)
end
-- basin: tiled walls 0.1 inside the grass cut (no coplanar faces), floor, lane lines, deep-water tint, water surface
local PT = Color3.new(0.95, 1, 1)
for _, W in { { 45, -78, 87, -76.9 }, { 45, -51.1, 87, -50 }, { 45, -76.9, 46.1, -51.1 }, { 85.9, -76.9, 87, -51.1 } } do
	K.Tex(BMM(F, "PoolWall", { W[1], -8.6, W[2] }, { W[3], -0.02, W[4] }), "r_pool", 8, 8, "sides", PT)
end
K.Tex(BMM(F, "PoolFloor", { 46.1, -8.6, -76.9 }, { 85.9, -7.6, -51.1 }), "r_pool", 8, 8, "top", Color3.new(0.85, 0.95, 1))
for _, Z in { -70.4, -64, -57.6 } do K.Detail(BMM(F, "LaneLine", { 49, -7.6, Z - 0.5 }, { 83, -7.54, Z + 0.5 }, NAVY)) end
local Deep = K.Detail(BMM(F, "WaterBody", { 46.12, -7.5, -76.88 }, { 85.88, -0.78, -51.12 }, Color3.fromRGB(40, 120, 190))); Deep.Transparency = 0.82
local Water = K.Detail(BMM(F, "Water", { 46.12, -1.0, -76.88 }, { 85.88, -0.7, -51.12 }, Color3.fromRGB(60, 140, 190)))
Water.Transparency = 0.45; K.Tex(Water, "r_water", 20, 20, "top", nil, 0.15); Water:SetAttribute("Water", true)
-- ladder on the east wall
for _, Z in { -65.2, -62.8 } do
	K.CylBetween(F, "LadderRail", 0.4, V(85.5, -5.5, Z), V(85.5, 1.9, Z), WHITE)
	K.CylBetween(F, "LadderRail", 0.4, V(85.5, 1.9, Z), V(88.6, 1.9, Z), WHITE)
	K.CylBetween(F, "LadderRail", 0.4, V(88.6, 1.9, Z), V(88.6, 0.45, Z), WHITE)
end
for _, Y in { -1.6, -3.1, -4.6 } do BMM(F, "LadderRung", { 85.1, Y - 0.15, -65.0 }, { 85.75, Y + 0.15, -63.0 }, WHITE) end
-- high-dive tower x60..72 z-90..-80
local T = K.Folder(F, "DiveTower")
for _, X in { 60.7, 71.3 } do for _, Z in { -89.3, -80.7 } do
	K.Tex(BMM(T, "Leg", { X - 0.7, 0.45, Z - 0.7 }, { X + 0.7, 25.6, Z + 0.7 }), "r_galv", 6, 6, "sides")
	K.Detail(BMM(T, "LegFoot", { X - 1.06, 0.45, Z - 1.06 }, { X + 1.06, 1.25, Z + 1.06 }, NAVY))
end end
for _, Y in { 8, 22 } do
	K.Tex(BMM(T, "Platform", { 60.1, Y - 0.8, -89.9 }, { 71.9, Y, -80.1 }), "r_tread", 4, 4, "top") -- inset 0.1: legs' outer faces are at 60/72
	K.Detail(BMM(T, "PlatformEdge", { 59.94, Y - 0.9, -90.06 }, { 72.06, Y - 0.5, -79.94 }, CORAL))
	K.Tex(K.Detail(BMM(T, "BoardStripe", { 60.2, Y, -80.9 }, { 71.8, Y + 0.06, -80.1 })), "hazard", 2, 2, "top")
end
local function Rail(P, A, B) -- top rail + mid rail + posts every ~4 studs, A/B = ground-level points on the platform
	K.Detail(K.BeamBetween(P, "Rail", A + Vector3.new(0, 3.2, 0), B + Vector3.new(0, 3.2, 0), 0.35, 0.35, CORAL))
	K.Detail(K.BeamBetween(P, "MidRail", A + Vector3.new(0, 1.7, 0), B + Vector3.new(0, 1.7, 0), 0.25, 0.25, CORAL))
	local N = math.max(1, math.floor((B - A).Magnitude / 4))
	for I = 0, N do local Q = A:Lerp(B, I / N); K.Part(P, "RailPost", Vector3.new(0.35, 3.2, 0.35), CFrame.new(Q + Vector3.new(0, 1.6, 0)), CORAL) end
end
Rail(T, V(60.3, 8, -89.7), V(60.3, 8, -80.3)); Rail(T, V(71.7, 8, -89.7), V(71.7, 8, -80.3))
Rail(T, V(60.3, 8, -89.7), V(63.7, 8, -89.7)); Rail(T, V(68.3, 8, -89.7), V(71.7, 8, -89.7))
Rail(T, V(60.3, 22, -89.7), V(71.7, 22, -89.7)); Rail(T, V(60.3, 22, -89.7), V(60.3, 22, -80.3))
Rail(T, V(71.7, 22, -89.7), V(71.7, 22, -86.3)); Rail(T, V(71.7, 22, -83.7), V(71.7, 22, -80.3))
for _, S in { { 60.7, 71.3, "X" } } do -- X bracing on the west and east faces
	for _, X in { 60.7, 71.3 } do
		for _, Seg in { { 1.2, 7.2 }, { 8.6, 21.2 } } do
			K.Detail(K.BeamBetween(T, "Brace", V(X, Seg[1], -89.3), V(X, Seg[2], -80.7), 0.45, 0.45, CORAL))
			K.Detail(K.BeamBetween(T, "Brace", V(X, Seg[1], -80.7), V(X, Seg[2], -89.3), 0.45, 0.45, CORAL))
		end
	end
end
local Truss = Instance.new("TrussPart"); Truss.Name = "Ladder"; Truss.Anchored = true; Truss.Size = Vector3.new(2, 22, 2)
Truss.CFrame = CFrame.new(V(73.1, 0.45 + 11, -85)); Truss.Color = WHITE; Truss.Material = Enum.Material.SmoothPlastic; Truss.Parent = T
local St = K.Stairs(T, CFrame.lookAt(V(66, 0, -112), V(66, 0, -100)), 4, 8, 22, NAVY, CORAL, "r_white", WT)
-- boards (planks run along Z) on navy roots, braced to the tower
for _, B in { { 8, -66 }, { 22, -64 } } do
	K.Tex(BMM(T, "DivingBoard", { 64.75, B[1], -84 }, { 67.25, B[1] + 0.5, B[2] }), "r_wood", 2.5, 6, "all")
	K.Detail(BMM(T, "BoardRoot", { 64.5, B[1] + 0.5, -84 }, { 67.5, B[1] + 1.3, -81.2 }, NAVY))
	K.Detail(K.BeamBetween(T, "BoardBrace", V(66, B[1] - 3.5, -80.3), V(66, B[1] - 0.05, -76), 0.5, 0.5, NAVY))
end
BMM(T, "LowBoardPost", { 65.3, 0.45, -79.6 }, { 66.7, 7.95, -78.8 }, NAVY)
-- loungers + umbrellas on the east deck
for I, Z in { -82, -72, -62 } do
	local L = K.Model(F, "Lounger")
	K.Tex(BMM(L, "Base", { 89.7, 0.45, Z - 2.8 }, { 92.3, 1.4, Z + 2.8 }), "r_white", 4, 4, "all", WT)
	BMM(L, "Cushion", { 89.85, 1.4, Z - 2.6 }, { 92.15, 1.8, Z + 1.2 }, ORANGE)
	K.Part(L, "Backrest", Vector3.new(2.3, 0.45, 2.6), CFrame.new(V(91, 2.35, Z + 2.1)) * CFrame.Angles(math.rad(40), 0, 0), ORANGE)
	if I < 3 then
		local U = V(91, 0.45, Z + 5)
		K.VCyl(L, "UmbrellaPole", 0.35, 8.6, U + Vector3.new(0, 4.3, 0), NAVY)
		K.VCyl(L, "UmbrellaFoot", 1.6, 0.4, U + Vector3.new(0, 0.2, 0), NAVY)
		for _, Fc in K.Pyramid(L, "Canopy", U + Vector3.new(0, 7.4, 0), 8, 1.8, I == 1 and ORANGE or Color3.fromRGB(222, 224, 222), nil, false, math.pi / 4):GetChildren() do K.Ghost(Fc) end
	end
end
-- two wooden planters with pack bushes on the west deck corners
for I, Z in { -86, -47 } do
	local Pl = K.Model(F, "Planter")
	K.Tex(BMM(Pl, "Box", { 39.4, 0.45, Z - 1.6 }, { 42.6, 2.0, Z + 1.6 }), "r_wood", 3, 3, "topsides")
	K.Outline(Pl, CFrame.new(V(41, 1.225, Z)), Vector3.new(3.2, 1.55, 3.2), 0.25, Color3.fromRGB(70, 54, 42))
	local B = game.ServerStorage.RagdollParkAssets.Forest["Bush2_02"]:Clone(); B:ScaleTo(0.42) -- owner's Enchanted Forest pack bush (no box bushes)
	B:PivotTo(B:GetPivot() * CFrame.Angles(0, I * 1.3, 0)); local Bc, Sz = B:GetBoundingBox(); B:PivotTo(B:GetPivot() + (V(41, 2.0 + Sz.Y / 2 - 0.3, Z) - Bc.Position)); B.Parent = Pl
end
local N = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then N += 1 end end
return "pool parts " .. N
