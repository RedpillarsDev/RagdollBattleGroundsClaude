--!nocheck
-- Ragdoll Park 03 (NW): hydraulic press on a concrete plinth (olive frame, yellow ram, hazard border, red button,
-- warning sign) + a field cannon on a pad aimed west at a framed sand landing pit with a square target. Static props;
-- scripted parts are named: Press.Ram, Press.PressButton, Cannon.Barrel.
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local function BMM(P, N, A, B, C) return K.BoxMM(P, N, V(A[1], A[2], A[3]), V(B[1], B[2], B[3]), C) end
local F = K.Clear(K.Folder(workspace.Map.RagdollPark.Content, "Crusher")); F:SetAttribute("Station", "Crusher")
local STEEL, CHROME, OLIVE_D, RED = Color3.fromRGB(74, 79, 87), Color3.fromRGB(200, 204, 208), Color3.fromRGB(64, 72, 50), Color3.fromRGB(200, 40, 36)
-- press ------------------------------------------------------------------------------------------- centre (-60,-62)
local P = K.Model(F, "Press")
K.Tex(BMM(P, "Plinth", { -72, -0.5, -74 }, { -48, 1, -50 }), "r_slab", 8, 8, "topsides")
K.Tex(BMM(P, "Step", { -65, -0.4, -50 }, { -55, 0.55, -48.5 }), "r_slab", 8, 8, "topsides")
K.Tex(BMM(P, "Anvil", { -67, 1, -69 }, { -53, 1.3, -55 }), "r_tread", 4, 4, "all")
for _, S in { { -68.4, -70.4, -51.6, -69.2 }, { -68.4, -54.8, -51.6, -53.6 }, { -68.4, -69.2, -67.2, -54.8 }, { -52.8, -69.2, -51.6, -54.8 } } do
	K.Tex(K.Detail(BMM(P, "HazardBorder", { S[1], 0.9, S[2] }, { S[3], 1.06, S[4] })), "hazard", 2.4, 2.4, "top")
end
for _, X in { -68.5, -51.5 } do for _, Z in { -70.5, -53.5 } do
	K.Tex(BMM(P, "Column", { X - 1.5, 1, Z - 1.5 }, { X + 1.5, 28, Z + 1.5 }), "r_olive2", 6, 6, "sides")
	K.Tex(K.Detail(BMM(P, "ColumnFoot", { X - 2, 1, Z - 2 }, { X + 2, 1.5, Z + 2 })), "r_steel", 4, 4, "topsides")
	K.Tex(K.Detail(BMM(P, "Collar", { X - 1.9, 9.9, Z - 1.9 }, { X + 1.9, 14.1, Z + 1.9 })), "r_steel", 4, 4, "all")
end end
K.Tex(BMM(P, "Crown", { -71, 28, -73 }, { -49, 33, -51 }), "r_olive2", 8, 8, "all")
K.Tex(K.Detail(BMM(P, "CrownBand", { -71.06, 28.6, -73.06 }, { -48.94, 29.6, -50.94 })), "hazard", 2, 2, "sides")
K.VCyl(P, "Cylinder", 6.4, 8, V(-60, 24, -62), STEEL)
K.Detail(K.VCyl(P, "CylinderFlange", 7.6, 0.6, V(-60, 20.3, -62), STEEL))
local Rod = K.VCyl(P, "Rod", 3, 6.4, V(-60, 17, -62), CHROME); Rod.Reflectance = 0.25
local Ram = K.Tex(BMM(P, "Ram", { -67.5, 10, -69.5 }, { -52.5, 14, -54.5 }), "r_yellow", 6, 6, "all")
K.Tex(K.Detail(BMM(P, "RamStripe", { -67.56, 10.5, -69.56 }, { -52.44, 11.5, -54.44 })), "hazard", 2, 2, "sides")
K.Tex(BMM(P, "RamPlate", { -67.6, 9.6, -69.6 }, { -52.4, 10.2, -54.4 }), "r_steel", 4, 4, "all")
-- red button on a pedestal by the step, warning sign on the other side
K.Tex(BMM(P, "ButtonPedestal", { -51.2, 0, -47.6 }, { -49.4, 3.4, -45.8 }), "r_steel", 3, 3, "all")
K.Wedge(P, "ButtonPanel", Vector3.new(1.8, 0.6, 1.8), CFrame.new(V(-50.3, 3.7, -46.7)) * CFrame.Angles(0, math.pi, 0), STEEL)
local Btn = K.Cyl(P, "PressButton", 1.2, 0.4, CFrame.new(V(-50.3, 3.95, -46.6)) * CFrame.Angles(math.rad(18), 0, 0) * CFrame.Angles(0, 0, math.pi / 2), RED)
Btn:SetAttribute("Press", "Button")
local Sg = K.Model(P, "WarningSign")
BMM(Sg, "Post", { -70.2, 0, -47.2 }, { -69.8, 5.2, -46.8 }, STEEL) -- stops at the triangle so the "!" dot shows
for _, S in { -1, 1 } do -- yellow triangle from two wedges, black '!' (symbol only, no words)
	K.Detail(K.Wedge(Sg, "Tri", Vector3.new(0.2, 3.4, 1.9), CFrame.new(V(-70, 6.9, -47 + S * 0.95)) * CFrame.Angles(0, S > 0 and math.pi or 0, 0), Color3.fromRGB(230, 182, 30)))
end
K.Detail(BMM(Sg, "Mark", { -70.18, 6.2, -47.2 }, { -69.82, 7.7, -46.8 }, Color3.fromRGB(25, 25, 25)))
K.Detail(BMM(Sg, "Dot", { -70.18, 5.6, -47.2 }, { -69.82, 5.95, -46.8 }, Color3.fromRGB(25, 25, 25)))
-- cannon -------------------------------------------------------------------------------------- pad at (-28,-104)
local C = K.Model(F, "Cannon")
K.Tex(BMM(C, "Pad", { -34, -0.4, -110 }, { -22, 0.8, -98 }), "r_slab", 8, 8, "topsides")
K.VCyl(C, "Turntable", 9, 0.8, V(-28, 1.2, -104), STEEL)
for _, Z in { -106.7, -101.3 } do
	K.Tex(BMM(C, "Cheek", { -31, 1.6, Z - 0.6 }, { -25, 6.2, Z + 0.6 }), "r_olive2", 4, 4, "all")
	K.Outline(C, CFrame.new(V(-28, 3.9, Z)), Vector3.new(6, 4.6, 1.2), 0.22, OLIVE_D)
end
local Dir = Vector3.new(-math.cos(math.rad(25)), math.sin(math.rad(25)), 0); local Piv = V(-28, 5.4, -104)
local Barrel = K.CylBetween(C, "Barrel", 3.6, Piv - Dir * 4.5, Piv + Dir * 9, Color3.fromRGB(78, 88, 60))
local Ring = K.CylBetween(C, "MuzzleRing", 4.4, Piv + Dir * 8.1, Piv + Dir * 9.06, STEEL)
-- owner: "HOLE in cannon" -> CSG bore through the muzzle (barrel + ring), dark plug deep inside so the tube reads
for _, Name in { "Barrel", "MuzzleRing" } do
	local Src = Name == "Barrel" and Barrel or Ring
	local Bore = K.CylBetween(C, "Bore", 2.5, Piv + Dir * 2.5, Piv + Dir * 9.6, Color3.new(0, 0, 0))
	local Ok, U = pcall(function() return Src:SubtractAsync({ Bore }) end); Bore:Destroy()
	if Ok and U then U.Name = Name; U.Anchored = true; U.UsePartColor = true; U.Color = Src.Color; U.Parent = C; Src:Destroy(); if Name == "Barrel" then Barrel = U end end
end
K.Detail(K.CylBetween(C, "BoreShadow", 2.45, Piv + Dir * 2.6, Piv + Dir * 3.0, Color3.fromRGB(18, 18, 20)))
K.Detail(K.CylBetween(C, "BandRing", 4.2, Piv + Dir * 1.2, Piv + Dir * 2.2, STEEL))
K.Detail(K.CylBetween(C, "BreechCap", 4.0, Piv - Dir * 4.56, Piv - Dir * 3.4, STEEL))
Barrel:SetAttribute("Cannon", "Barrel")
K.Cyl(C, "Axle", 1.6, 6.6, CFrame.new(Piv) * CFrame.Angles(0, math.pi / 2, 0), STEEL)
-- ammo crates beside the pad
for I, S in { { -36.5, -99, 3 }, { -36.5, -102.4, 3 }, { -36.3, -100.6, 2.4, 3 } } do
	local Y = S[4] or 0; local Cr = K.Model(C, "Crate")
	local B = K.Tex(K.Box(Cr, "Body", Vector3.new(S[3], S[3], S[3]), V(S[1], Y + S[3] / 2, S[2])), "r_wood", 3, 3, "all")
	K.Outline(Cr, B.CFrame, B.Size, 0.3, Color3.fromRGB(70, 54, 42))
end
-- landing pit x-112..-82 z-116..-92: plank frame, sand, square target frames
local L = K.Model(F, "SandPit")
for _, W in { { -112, -116, -82, -114.8 }, { -112, -93.2, -82, -92 }, { -112, -114.8, -110.8, -93.2 }, { -83.2, -114.8, -82, -93.2 } } do
	K.Tex(BMM(L, "Frame", { W[1], -0.4, W[2] }, { W[3], 1.2, W[4] }), "r_wood_h", 4, 4, "topsides")
end
K.Tex(BMM(L, "Sand", { -110.8, -0.4, -114.8 }, { -83.2, 0.9, -93.2 }), "r_sand", 10, 10, "top")
local function Frame(Cx, Cz, Half, T, Col, Y)
	for _, S in { { -Half, -Half, Half, -Half + T }, { -Half, Half - T, Half, Half }, { -Half, -Half + T, -Half + T, Half - T }, { Half - T, -Half + T, Half, Half - T } } do
		K.Detail(BMM(L, "Target", { Cx + S[1], 0.8, Cz + S[2] }, { Cx + S[3], Y, Cz + S[4] }, Col))
	end
end
Frame(-97, -104, 8, 1, Color3.fromRGB(196, 44, 40), 0.96); Frame(-97, -104, 5, 1, Color3.fromRGB(235, 232, 225), 0.96)
K.Detail(BMM(L, "TargetCentre", { -99, 0.8, -106 }, { -95, 0.96, -102 }, Color3.fromRGB(196, 44, 40)))
local N = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then N += 1 end end
return "crusher parts " .. N
