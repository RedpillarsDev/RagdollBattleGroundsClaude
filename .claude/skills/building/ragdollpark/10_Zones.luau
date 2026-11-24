--!nocheck
-- Ragdoll Park 10: the outer zones (Guts 2026-11-24: "make the map bigger add more stuff like places for cool animals or
-- ideas"; picked all four; "Build zones first": animals come later, their spots are LogicPoints/AnimalSpot (attr Animal)).
-- NE rodeo arena (195,-195) | NW shark pier (basin x-235..-155 z-235..-155, cut in 00) | SE boxing ring (172,172) | SW rocket pad x-230..-200 z160..190 + giant fan (-236,215) blowing east over a stage
-- into a foam pit. Refs: RagdollPark/refs/dl/{rodeo_arena,fishing_pier,boxing_ring,gorilla_enclosure,rocket_launch_pad,
-- wind_tunnel_fan}_*. Everything anchored. Animatable: FanSpin, RocketLift (Motor6D on a Root, unanchor to drive).
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local function BMM(P, N, A, B, C) return K.BoxMM(P, N, V(A[1], A[2], A[3]), V(B[1], B[2], B[3]), C) end
local Park = workspace.Map.RagdollPark
local F = K.Clear(K.Folder(Park.Content, "Zones"))
local LP = Park.LogicPoints; for _, C in LP:GetChildren() do if C:GetAttribute("FromChunk") == "10" then C:Destroy() end end
local GALV, STEEL, WHITE, DARK = Color3.fromRGB(150, 155, 160), Color3.fromRGB(74, 79, 87), Color3.fromRGB(226, 226, 222), Color3.fromRGB(34, 36, 40)
local LOG, ROPE, RED = Color3.fromRGB(96, 70, 50), Color3.fromRGB(150, 120, 80), Color3.fromRGB(190, 36, 30)
local function Spot(Pos, Attrs)
	local D = K.Box(LP, "AnimalSpot", Vector3.new(1, 1, 1), Pos, Color3.fromRGB(255, 170, 0)); D.Transparency = 1
	D.CanCollide = false; D.CanQuery = false; D.CanTouch = false; D:SetAttribute("FromChunk", "10")
	for Kk, Vv in Attrs do D:SetAttribute(Kk, Vv) end; return D
end
local function Rig(Mo, CF)
	local R = K.Part(Mo, "Root", Vector3.new(1, 1, 1), CF, Color3.new(1, 1, 1)); R.Transparency = 1; R.CanCollide = false; R.CanQuery = false; R.CanTouch = false
	Mo.PrimaryPart = R; local AC = Instance.new("AnimationController"); AC.Parent = Mo; Instance.new("Animator").Parent = AC; Mo:SetAttribute("Animatable", true); return R
end
local function Motor(Name, A, B, Pivot) local M = Instance.new("Motor6D"); M.Name = Name; M.Part0 = A; M.Part1 = B; M.C0 = A.CFrame:Inverse() * Pivot; M.C1 = B.CFrame:Inverse() * Pivot; M.Parent = A; return M end
local function Weld(A, B) local W = Instance.new("WeldConstraint"); W.Name = "Break"; W.Part0 = A; W.Part1 = B; W.Parent = B; return W end
local function Rail(P, A, B, T, Col) return K.BeamBetween(P, "Rail", A, B, T, T, Col or WHITE) end
local Kit = game.ServerStorage.RagdollParkAssets.Forest
local function Plant(P, Name, X, Z, H, Yaw)
	local M = Kit[Name]:Clone(); local _, S0 = M:GetBoundingBox(); M:ScaleTo(M:GetScale() * H / S0.Y)
	M:PivotTo(M:GetPivot() * CFrame.Angles(0, Yaw, 0)); local C, S = M:GetBoundingBox(); M:PivotTo(M:GetPivot() + (V(X, S.Y / 2 - 0.2 * S.Y, Z) - C.Position))
	for _, D in M:GetDescendants() do if D:IsA("BasePart") then D.Anchored = true; D.CanCollide = false; D.CanQuery = false end end; M.Parent = P
end

do -- NE rodeo arena ------------------------------------------------------------------------------------------------
	local A = K.Model(F, "RodeoArena"); A:SetAttribute("Station", "Rodeo")
	local CX, CZ, R = 195, -195, 30
	K.Tex(K.VCyl(A, "ArenaFloor", 2 * R + 1, 0.6, V(CX, -0.15, CZ), Color3.new(1, 1, 1)), "r_sand", 12, 12, { Enum.NormalId.Right }, Color3.new(0.84, 0.72, 0.58))
	local N = 28
	for I = 0, N - 1 do -- white board fence on galvanized posts, gate gap (I = 10) facing the park centre
		local a0, a1 = I / N * 2 * math.pi, (I + 1) / N * 2 * math.pi
		local p0, p1 = V(CX + math.cos(a0) * R, 0, CZ + math.sin(a0) * R), V(CX + math.cos(a1) * R, 0, CZ + math.sin(a1) * R)
		K.VCyl(A, "FencePost", 0.55, 4.6, p0 + Vector3.new(0, 2.3, 0), GALV)
		if I ~= 10 then for _, Y in { 1.2, 2.5, 3.8 } do Rail(A, p0 + Vector3.new(0, Y, 0), p1 + Vector3.new(0, Y, 0), 0.32) end end
	end
	for K2 = -1, 1 do -- three bucking chutes outside the north fence
		local a = math.rad(270 + K2 * 10); local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local CF = CFrame.lookAt(V(CX, 0, CZ) + d * (R + 3.65), V(CX, 0, CZ))
		K.Tex(K.Part(A, "ChuteFloor", Vector3.new(4.5, 0.3, 6.8), CF), "r_sand", 6, 6, "top", Color3.new(0.84, 0.72, 0.58))
		for _, SX in { -2.25, 2.25 } do for _, SZ in { -3.35, 3.35 } do K.Part(A, "ChutePost", Vector3.new(0.4, 6, 0.4), CF * CFrame.new(SX, 3, SZ), GALV) end end
		for _, Y in { 1.8, 3.6, 5.8 } do
			for _, SX in { -2.25, 2.25 } do K.Part(A, "ChuteRail", Vector3.new(0.25, 0.25, 6.7), CF * CFrame.new(SX, Y, 0), GALV) end
			K.Part(A, "ChuteRail", Vector3.new(4.5, 0.25, 0.25), CF * CFrame.new(0, Y, 3.35), GALV)
		end
		for _, Y in { 1.4, 2.6, 3.8 } do K.Part(A, "ChuteGate", Vector3.new(4.1, 0.6, 0.15), CF * CFrame.new(0, Y, -3.2), WHITE) end
	end
	do -- grandstand on the SE side, facing the arena
		local a = math.rad(45); local S = V(CX, 0, CZ) + Vector3.new(math.cos(a), 0, math.sin(a)) * 39
		local CF = CFrame.lookAt(S, V(CX, 0, CZ))
		for I = 0, 3 do
			local W, D = 24 - 0.12 * I, 10 - 2.5 * I
			K.Tex(K.Part(A, "Tier", Vector3.new(W, 1.2 * (I + 1), D), CF * CFrame.new(0, 0.6 * (I + 1), 5 - D / 2)), "r_slab1", 4, 4, "topsides")
			K.Part(A, "Seat", Vector3.new(W - 2, 0.35, 1.2), CF * CFrame.new(0, 1.2 * (I + 1) + 0.5, -5 + 2.5 * I + 0.9), Color3.fromRGB(178, 182, 186)).Reflectance = 0.15
		end
	end
	for _, Ang in { 0, 180 } do -- two floodlight poles
		local a = math.rad(Ang); local B = V(CX + math.cos(a) * 36, 0, CZ + math.sin(a) * 36)
		K.VCyl(A, "LightPole", 0.8, 22, B + Vector3.new(0, 11, 0), GALV)
		local H = CFrame.lookAt(B + Vector3.new(0, 22.6, 0), V(CX, 22.6, CZ)) * CFrame.Angles(math.rad(-25), 0, 0)
		K.Detail(K.Part(A, "LightHead", Vector3.new(5, 2.4, 1), H, DARK))
		for _, X in { -1.2, 1.2 } do K.Detail(K.Part(A, "Lamp", Vector3.new(2, 1.8, 0.2), H * CFrame.new(X, 0, -0.55), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)) end
	end
	K.VCyl(A, "BullMat", 16, 1.0, V(CX + 11, 0.65, CZ + 4), RED)
	K.Detail(K.VCyl(A, "BullMatCentre", 6, 1.06, V(CX + 11, 0.68, CZ + 4), Color3.fromRGB(40, 80, 170)))
	Spot(V(CX + 11, 1.2, CZ + 4), { Animal = "MechanicalBull", Station = "Rodeo" }); Spot(V(CX - 8, 0.2, CZ - 4), { Animal = "Bull", Station = "Rodeo" })
end

do -- NW shark pier -------------------------------------------------------------------------------------------------
	local S = K.Model(F, "SharkPier"); S:SetAttribute("Station", "SharkPier")
	local X0, Z0, X1, Z1, DEP = -235, -235, -155, -155, 14
	for _, W in { { X0 - 1, Z0 - 1, X1 + 1, Z0 + 0.1 }, { X0 - 1, Z1 - 0.1, X1 + 1, Z1 + 1 }, { X0 - 1, Z0 + 0.1, X0 + 0.1, Z1 - 0.1 }, { X1 - 0.1, Z0 + 0.1, X1 + 1, Z1 - 0.1 } } do
		K.Tex(BMM(S, "BasinWall", { W[1], -DEP - 0.6, W[2] }, { W[3], -0.3, W[4] }), "r_stone", 6, 6, "sides")
	end
	K.Tex(BMM(S, "SeaFloor", { X0 + 0.1, -DEP - 0.6, Z0 + 0.1 }, { X1 - 0.1, -DEP, Z1 - 0.1 }), "r_sand", 12, 12, "top")
	for Side, C in { N = { X0 - 1.6, Z0 - 1.6, X1 + 1.6, Z0 + 0.3 }, S = { X0 - 1.6, Z1 - 0.3, X1 + 1.6, Z1 + 1.6 }, W = { X0 - 1.6, Z0 + 0.3, X0 + 0.3, Z1 - 0.3 }, E = { X1 - 0.3, Z0 + 0.3, X1 + 1.6, Z1 - 0.3 } } do
		K.Tex(BMM(S, "Coping", { C[1], -0.3, C[2] }, { C[3], 0.12, C[4] }), "r_slab1", 3.2, 3.2, "topsides")
	end
	local Deep = K.Detail(BMM(S, "SeaBody", { X0 + 0.12, -DEP + 0.05, Z0 + 0.12 }, { X1 - 0.12, -2.4, Z1 - 0.12 }, Color3.fromRGB(20, 70, 120))); Deep.Transparency = 0.9
	local Wt = K.Detail(BMM(S, "Water", { X0 + 0.12, -2.35, Z0 + 0.12 }, { X1 - 0.12, -2.0, Z1 - 0.12 }, Color3.fromRGB(50, 120, 170)))
	Wt.Transparency = 0.7; K.Tex(Wt, "r_water", 20, 20, "top", nil, 0.55) -- clear enough to see the sharks; Wt:SetAttribute("Water", true)
	local DTop, PX0, PX1 = 1.6, -199, -191
	K.Tex(BMM(S, "PierDeck", { PX0, DTop - 0.6, -215 }, { PX1, DTop, -150 }), "r_wood_h", 6, 6, "topsides")
	K.Tex(BMM(S, "PierHead", { -207, DTop - 0.6, -229 }, { -183, DTop, -215.02 }), "r_wood_h", 6, 6, "topsides")
	K.Tex(BMM(S, "Plank", { -195.8, DTop - 0.35, -234 }, { -194.2, DTop - 0.05, -229.02 }), "r_wood", 1.6, 5, "all")
	for Z = -154, -226, -6 do for _, X in (Z > -215 and { PX0 + 0.6, PX1 - 0.6 } or { -206, -199, -191, -184 }) do
		K.VCyl(S, "Pile", 1.2, DEP + DTop - 0.6, V(X, (DTop - 0.6 - DEP) / 2, Z), LOG)
	end end
	local RC = Color3.fromRGB(70, 48, 32)
	local function WoodRail(A, B)
		Rail(S, A + Vector3.new(0, 3.3, 0), B + Vector3.new(0, 3.3, 0), 0.3, RC); Rail(S, A + Vector3.new(0, 1.8, 0), B + Vector3.new(0, 1.8, 0), 0.22, RC)
		local Nn = math.max(1, math.floor((B - A).Magnitude / 4))
		for I = 0, Nn do K.Part(S, "RailPost", Vector3.new(0.4, 3.4, 0.4), CFrame.new(A:Lerp(B, I / Nn) + Vector3.new(0, 1.7, 0)), RC) end
	end
	WoodRail(V(PX0 + 0.2, DTop, -150.5), V(PX0 + 0.2, DTop, -214.8)); WoodRail(V(PX1 - 0.2, DTop, -150.5), V(PX1 - 0.2, DTop, -214.8))
	WoodRail(V(-206.8, DTop, -215.2), V(-206.8, DTop, -228.8)); WoodRail(V(-183.2, DTop, -215.2), V(-183.2, DTop, -228.8))
	WoodRail(V(-206.8, DTop, -228.8), V(-197, DTop, -228.8)); WoodRail(V(-193, DTop, -228.8), V(-183.2, DTop, -228.8))
	WoodRail(V(-206.8, DTop, -215.2), V(-199.2, DTop, -215.2)); WoodRail(V(-190.8, DTop, -215.2), V(-183.2, DTop, -215.2))
	K.Stairs(S, CFrame.lookAt(V(-195, 0, -146), V(-195, 0, -147)), 8, DTop, 3.5, Color3.fromRGB(150, 150, 146), nil, "r_slab1")
	for I, P in { { -215, -200 }, { -175, -222 }, { -170, -175 }, { -222, -172 } } do -- floating buoys
		K.Detail(K.VCyl(S, "Buoy", 2.4, 0.7, V(P[1], -2.0, P[2]), RED)); K.Detail(K.VCyl(S, "BuoyBand", 2.5, 0.25, V(P[1], -2.0, P[2]), WHITE))
	end
	do -- lifeguard tower on the grass by the SE corner
		local T = K.Model(S, "LifeguardTower"); local B = V(-147, 0, -160)
		for _, SX in { -2, 2 } do for _, SZ in { -2, 2 } do K.Part(T, "Leg", Vector3.new(0.5, 7, 0.5), CFrame.new(B + Vector3.new(SX, 3.5, SZ)), WHITE) end end
		K.Tex(K.Part(T, "Floor", Vector3.new(6, 0.5, 6), CFrame.new(B + Vector3.new(0, 7.25, 0))), "r_wood_h", 4, 4, "topsides")
		for _, W in { { 0, -2.9, 6, 0.3 }, { -2.9, 0, 0.3, 5.5 }, { 2.9, 0, 0.3, 5.5 } } do K.Part(T, "HalfWall", Vector3.new(W[3], 1.5, W[4]), CFrame.new(B + Vector3.new(W[1], 8.25, W[2])), RED) end
		for _, SX in { -2.85, 2.85 } do for _, SZ in { -2.85, 2.85 } do K.Part(T, "RoofPost", Vector3.new(0.3, 3.4, 0.3), CFrame.new(B + Vector3.new(SX, 9.2, SZ)), WHITE) end end
		K.Part(T, "Roof", Vector3.new(7, 0.4, 7), CFrame.new(B + Vector3.new(0, 11.1, 0)) * CFrame.Angles(math.rad(8), 0, 0), RED)
		local Tr = Instance.new("TrussPart"); Tr.Name = "Ladder"; Tr.Anchored = true; Tr.Size = Vector3.new(2, 7.4, 2); Tr.CFrame = CFrame.new(B + Vector3.new(0, 3.7, 4.0)); Tr.Color = WHITE; Tr.Parent = T
	end
	for I, P in { { -175, -195 }, { -215, -210 }, { -185, -170 } } do Spot(V(P[1], -6, P[2]), { Animal = "Shark", Station = "SharkPier", SwimRadius = 18 }) end
end

do -- SE boxing ring + gorilla pen --------------------------------------------------------------------------------
	local Z = K.Model(F, "ZooCorner"); Z:SetAttribute("Station", "Zoo")
	local RX, RZ = 172, 172
	K.Part(Z, "RingBase", Vector3.new(20, 2.6, 20), CFrame.new(V(RX, 1.3, RZ)), DARK)
	K.Part(Z, "Canvas", Vector3.new(18, 0.4, 18), CFrame.new(V(RX, 2.8, RZ)), Color3.fromRGB(40, 92, 170))
	K.Detail(K.Part(Z, "CanvasLogo", Vector3.new(6, 0.06, 6), CFrame.new(V(RX, 3.03, RZ)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(30, 74, 140)))
	local Corners = { { -1, -1, RED }, { 1, 1, Color3.fromRGB(40, 80, 190) }, { -1, 1, WHITE }, { 1, -1, WHITE } }
	for _, C in Corners do
		local P = V(RX + C[1] * 8.6, 0, RZ + C[2] * 8.6)
		K.VCyl(Z, "CornerPost", 0.6, 5.2, P + Vector3.new(0, 5.6, 0), STEEL)
		K.Part(Z, "CornerPad", Vector3.new(1.1, 4.2, 1.1), CFrame.new(P + Vector3.new(0, 5.4, 0)) * CFrame.Angles(0, math.rad(45), 0), C[3])
	end
	local RopeCol = { RED, WHITE, Color3.fromRGB(40, 80, 190) }
	for I, Y in { 7.0, 5.8, 4.6 } do
		for _, E in { { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } } do
			K.CylBetween(Z, "Rope", 0.3, V(RX + E[1] * 8.6, Y, RZ + E[2] * 8.6), V(RX + E[3] * 8.6, Y, RZ + E[4] * 8.6), RopeCol[I])
		end
	end
	K.Stairs(Z, CFrame.lookAt(V(158, 0, 166), V(159, 0, 166)), 3, 3, 4, Color3.fromRGB(60, 62, 68), STEEL)
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do K.VCyl(Z, "TrussPost", 0.7, 16, V(RX + SX * 12, 8, RZ + SZ * 12), GALV) end end
	for _, E in { { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } } do
		K.Detail(Rail(Z, V(RX + E[1] * 12, 16, RZ + E[2] * 12), V(RX + E[3] * 12, 16, RZ + E[4] * 12), 0.6, GALV))
	end
	for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do
		local L = K.Detail(K.Part(Z, "RingLight", Vector3.new(2.2, 1, 2.2), CFrame.new(V(RX + SX * 6, 15.3, RZ + SZ * 6)), DARK))
		K.Detail(K.Part(Z, "RingLamp", Vector3.new(1.8, 0.2, 1.8), CFrame.new(V(RX + SX * 6, 14.75, RZ + SZ * 6)), Color3.fromRGB(255, 240, 210), Enum.Material.Neon))
	end end
	Spot(V(RX + 5.5, 3.1, RZ - 5.5), { Animal = "Kangaroo", Station = "BoxingRing" })
	-- (gorilla pen deleted by Guts 2026-11-24)
end

do -- SW rocket pad + giant fan -------------------------------------------------------------------------------------
	local R = K.Model(F, "RocketYard"); R:SetAttribute("Station", "RocketYard")
	K.Tex(BMM(R, "Pad", { -230, -0.3, 160 }, { -200, 1.0, 190 }), "r_slab1", 6, 6, "topsides")
	K.Detail(BMM(R, "FlameTrench", { -218, 1.0, 160.4 }, { -212, 1.06, 189.6 }, DARK))
	for _, E in { { -229.4, 160.6, -200.6, 161.2 }, { -229.4, 188.8, -200.6, 189.4 }, { -229.4, 161.2, -228.8, 188.8 }, { -201.2, 161.2, -200.6, 188.8 } } do
		K.Tex(K.Detail(BMM(R, "PadStripe", { E[1], 1.0, E[2] }, { E[3], 1.06, E[4] })), "hazard", 2.4, 2.4, "top")
	end
	local TX, TZ = -225, 175 -- lattice launch tower beside the rocket
	for _, SX in { -2.5, 2.5 } do for _, SZ in { -2.5, 2.5 } do K.Part(R, "TowerLeg", Vector3.new(0.7, 32, 0.7), CFrame.new(V(TX + SX, 17, TZ + SZ)), Color3.fromRGB(176, 60, 40)) end end
	for Y = 1, 25, 6 do -- rings at 7..31 (legs end at 33), one X-brace per bay
		for _, E in { { -2.5, -2.5, 2.5, -2.5 }, { 2.5, -2.5, 2.5, 2.5 }, { 2.5, 2.5, -2.5, 2.5 }, { -2.5, 2.5, -2.5, -2.5 } } do
			K.Detail(Rail(R, V(TX + E[1], Y + 6, TZ + E[2]), V(TX + E[3], Y + 6, TZ + E[4]), 0.4, Color3.fromRGB(176, 60, 40)))
			K.Detail(Rail(R, V(TX + E[1], Y, TZ + E[2]), V(TX + E[3], Y + 6, TZ + E[4]), 0.3, Color3.fromRGB(176, 60, 40)))
		end
	end
	K.Tex(BMM(R, "TowerTop", { TX - 3, 32.4, TZ - 3 }, { TX + 3, 33, TZ + 3 }), "r_tread", 3, 3, "top")
	for _, Y in { 20, 28 } do K.Part(R, "ServiceArm", Vector3.new(7.5, 0.8, 2.2), CFrame.new(V(TX + 5.6, Y, TZ)), GALV) end
	local Tr = Instance.new("TrussPart"); Tr.Name = "TowerLadder"; Tr.Anchored = true; Tr.Size = Vector3.new(2, 32, 2); Tr.CFrame = CFrame.new(V(TX - 3.9, 17, TZ)); Tr.Color = GALV; Tr.Parent = R
	do -- the rocket: Root on the pad + RocketLift motor on the body; everything else welded to the body
		local M = K.Model(R, "Rocket"); M:SetAttribute("Breakable", true); local Root = Rig(M, CFrame.new(V(-215, 1, 175)))
		local Body = K.VCyl(M, "Body", 5, 22, V(-215, 13.2, 175), WHITE)
		local Parts = {}
		local function Add(P) table.insert(Parts, P); return P end
		for _, B in { { 7, 1.2 }, { 19, 0.8 } } do Add(K.VCyl(M, "Band", 5.12, B[2], V(-215, B[1], 175), DARK)) end
		local Y = 24.2
		for _, C in { { 4.3, 1.6 }, { 3.4, 1.6 }, { 2.4, 1.4 }, { 1.4, 1.0 } } do Add(K.VCyl(M, "Nose", C[1], C[2], V(-215, Y + C[2] / 2, 175), RED)); Y += C[2] end
		Add(K.Ball(M, "NoseTip", 1.0, V(-215, Y, 175), RED))
		Add(K.VCyl(M, "EngineBell", 3.4, 1.2, V(-215, 1.6, 175), DARK))
		for I = 0, 3 do
			local a = I * math.pi / 2 + math.pi / 4
			Add(K.Wedge(M, "Fin", Vector3.new(0.4, 5, 3.2), CFrame.new(V(-215 + math.cos(a) * 3.9, 4.7, 175 + math.sin(a) * 3.9)) * CFrame.Angles(0, -a + math.pi / 2, 0), RED))
		end
		Add(K.Cyl(M, "Porthole", 1.4, 0.2, CFrame.new(V(-212.45, 17, 175)), Color3.fromRGB(80, 160, 220)))
		for _, P in Parts do Weld(Body, P) end
		Motor("RocketLift", Root, Body, CFrame.new(V(-215, 1, 175)))
	end
	do -- strap-on rocket chair
		local M = K.Model(R, "RocketChair"); M:SetAttribute("RocketChair", true); local CF = CFrame.new(V(-205, 1, 166)) * CFrame.Angles(0, math.rad(-90), 0)
		for _, SX in { -1, 1 } do for _, SZ in { -1, 1 } do K.Part(M, "Leg", Vector3.new(0.3, 1.8, 0.3), CF * CFrame.new(SX, 0.9, SZ), STEEL) end end
		K.Part(M, "Seat", Vector3.new(2.6, 0.5, 2.6), CF * CFrame.new(0, 2.05, 0), Color3.fromRGB(60, 62, 70))
		K.Part(M, "Back", Vector3.new(2.6, 3.2, 0.45), CF * CFrame.new(0, 3.9, 1.1), Color3.fromRGB(60, 62, 70))
		for _, SX in { -0.75, 0.75 } do
			K.Cyl(M, "Booster", 1.3, 5, CF * CFrame.new(SX, 4.2, 2.0) * CFrame.Angles(0, 0, math.rad(90)), WHITE)
			K.Ball(M, "BoosterNose", 1.25, (CF * CFrame.new(SX, 6.75, 2.0)).Position, RED)
			K.Cyl(M, "BoosterBell", 1.0, 0.6, CF * CFrame.new(SX, 1.45, 2.0) * CFrame.Angles(0, 0, math.rad(90)), DARK)
		end
		for _, Y in { 3.0, 5.2 } do K.Detail(K.Part(M, "Strap", Vector3.new(3.0, 0.3, 1.7), CF * CFrame.new(0, Y, 1.75), STEEL)) end
	end
	do -- giant fan blowing east over a wooden stage into a foam pit
		local M = K.Model(R, "GiantFan"); M:SetAttribute("Station", "GiantFan"); local C = V(-236, 11, 215); local Root = Rig(M, CFrame.new(C))
		local RR, Nd = 9, 32
		for I = 0, Nd - 1 do
			local a = I / Nd * 2 * math.pi
			K.Part(M, "Duct", Vector3.new(4, 1, 2 * math.pi * (RR + 0.5) / Nd + 0.08), CFrame.new(C + Vector3.new(0, math.cos(a), math.sin(a)) * (RR + 0.5)) * CFrame.Angles(a, 0, 0), WHITE)
		end
		K.Tex(BMM(M, "Pedestal", { -240, -0.3, 209 }, { -232, 2.2, 221 }), "r_slab1", 4, 4, "topsides")
		local Hub = K.Cyl(M, "Hub", 3.2, 2.2, CFrame.new(C), Color3.fromRGB(120, 40, 30))
		local Parts = { K.Ball(M, "Spinner", 2.6, C + Vector3.new(1.3, 0, 0), WHITE) }
		for I = 0, 7 do
			local a = I / 8 * 2 * math.pi
			table.insert(Parts, K.Part(M, "Blade", Vector3.new(0.3, 6.8, 1.9), CFrame.new(C + Vector3.new(0, math.cos(a), math.sin(a)) * 4.9) * CFrame.Angles(a, 0, 0) * CFrame.Angles(0, math.rad(28), 0), Color3.fromRGB(140, 45, 30)))
		end
		for _, P in Parts do Weld(Hub, P) end
		Motor("FanSpin", Root, Hub, CFrame.new(C))
		K.Part(M, "Strut", Vector3.new(0.6, 0.6, 2 * RR), CFrame.new(C + Vector3.new(-1.6, 0, 0)), STEEL)
		K.Part(M, "Strut", Vector3.new(0.6, 2 * RR, 0.6), CFrame.new(C + Vector3.new(-1.6, 0, 0)), STEEL)
		K.Tex(BMM(R, "Stage", { -230, -0.3, 208 }, { -214, 4, 222 }), "r_wood_h", 6, 6, "topsides")
		K.Stairs(R, CFrame.lookAt(V(-222, 0, 202), V(-222, 0, 203)), 4, 4, 6, Color3.fromRGB(150, 150, 146), STEEL, "r_slab1")
		for _, W in { { -212, 205, -190, 206 }, { -212, 224, -190, 225 }, { -212, 206, -211, 224 }, { -191, 206, -190, 224 } } do
			BMM(R, "PitWall", { W[1], -0.3, W[2] }, { W[3], 3, W[4] }, Color3.fromRGB(40, 80, 170))
		end
		local Fr = Random.new(9); local Cols = { Color3.fromRGB(230, 60, 50), Color3.fromRGB(245, 200, 40), Color3.fromRGB(60, 140, 230), Color3.fromRGB(80, 190, 90), Color3.fromRGB(240, 240, 235) }
		for I = 0, 6 do for J = 0, 6 do
			K.Part(R, "Foam", Vector3.new(2.6, 2.6, 2.6), CFrame.new(V(-209.5 + I * 2.75, 1.3, 207.6 + J * 2.75)) * CFrame.Angles(Fr:NextNumber(-0.15, 0.15), Fr:NextNumber(0, 6.28), Fr:NextNumber(-0.15, 0.15)), Cols[Fr:NextInteger(1, 5)])
		end end
		for I = 1, 18 do K.Part(R, "Foam", Vector3.new(2.6, 2.6, 2.6), CFrame.new(V(Fr:NextNumber(-209, -193), 3.5, Fr:NextNumber(208, 222))) * CFrame.Angles(Fr:NextNumber(0, 6), Fr:NextNumber(0, 6), Fr:NextNumber(0, 6)), Cols[Fr:NextInteger(1, 5)]) end
		Spot(V(-220, 4.2, 215), { Animal = "None", Station = "GiantFan", DummySpot = true })
	end
end
local Cnt = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then Cnt += 1 end end
return "zone parts " .. Cnt
