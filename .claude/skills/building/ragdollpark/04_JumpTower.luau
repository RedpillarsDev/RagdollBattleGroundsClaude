--!nocheck
-- Ragdoll Park 04 (SE): ski-jump tower (deck x108..120 z92..114, top 36), plank ramp west down to a kicker lip at
-- x44 h6.4, open steel stairs beside it, sand landing pit x10..40, one big round trampoline (mat attr Bounce).
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local function BMM(P, N, A, B, C) return K.BoxMM(P, N, V(A[1], A[2], A[3]), V(B[1], B[2], B[3]), C) end
local F = K.Clear(K.Folder(workspace.Map.RagdollPark.Content, "JumpTower")); F:SetAttribute("Station", "JumpTower")
local GALV, STEEL, PAD, MAT = Color3.fromRGB(150, 155, 160), Color3.fromRGB(74, 79, 87), Color3.fromRGB(40, 78, 150), Color3.fromRGB(28, 30, 34)
local function Beam(P, A, B, T, C, Det) local Pt = K.BeamBetween(P, "Beam", A, B, T, T, C or GALV); if Det ~= false then K.Detail(Pt) end return Pt end
-- tower ---------------------------------------------------------------------------------------------------------
local T = K.Model(F, "Tower")
for _, X in { 108.6, 114, 119.4 } do for _, Z in { 92.6, 113.4 } do
	BMM(T, "Leg", { X - 0.6, 0, Z - 0.6 }, { X + 0.6, 35, Z + 0.6 }, GALV)
	K.Detail(BMM(T, "Foot", { X - 1, 0, Z - 1 }, { X + 1, 0.4, Z + 1 }, STEEL))
end end
for _, Y in { 12, 24 } do -- ring beams + X bracing between the levels
	for _, S in { { 108.6, 92.6, 119.4, 92.6 }, { 108.6, 113.4, 119.4, 113.4 }, { 108.6, 92.6, 108.6, 113.4 }, { 119.4, 92.6, 119.4, 113.4 } } do
		Beam(T, V(S[1], Y, S[2]), V(S[3], Y, S[4]), 0.7)
	end
end
for _, X in { 108.6, 119.4 } do for _, Seg in { { 0.5, 12 }, { 12, 24 }, { 24, 34.4 } } do
	Beam(T, V(X, Seg[1], 92.6), V(X, Seg[2], 113.4), 0.45); Beam(T, V(X, Seg[1], 113.4), V(X, Seg[2], 92.6), 0.45)
end end
K.Tex(BMM(T, "Deck", { 108, 35, 92 }, { 120, 36, 114 }), "r_tread", 4, 4, "top")
K.Detail(BMM(T, "DeckEdge", { 107.94, 34.8, 91.94 }, { 120.06, 35.4, 114.06 }, STEEL))
local function Rail(A, B)
	Beam(T, A + Vector3.new(0, 3.2, 0), B + Vector3.new(0, 3.2, 0), 0.3); Beam(T, A + Vector3.new(0, 1.7, 0), B + Vector3.new(0, 1.7, 0), 0.22)
	local N = math.max(1, math.floor((B - A).Magnitude / 4))
	for I = 0, N do K.Part(T, "RailPost", Vector3.new(0.3, 3.2, 0.3), CFrame.new(A:Lerp(B, I / N) + Vector3.new(0, 1.6, 0)), GALV) end
end
Rail(V(119.7, 36, 92.3), V(119.7, 36, 113.7)); Rail(V(108.3, 36, 92.3), V(119.7, 36, 92.3)); Rail(V(108.3, 36, 113.7), V(119.7, 36, 113.7))
Rail(V(108.3, 36, 92.3), V(108.3, 36, 95.6)); Rail(V(108.3, 36, 104.4), V(108.3, 36, 106.6)); Rail(V(108.3, 36, 111.4), V(108.3, 36, 113.7))
-- ramp: deck top follows the profile; every joint is concave (flattening), so the boxes never stick up at a joint ------
local R = K.Model(F, "Ramp")
local Prof = { { -0.3, 36 }, { 3, 34.2 }, { 28, 16.4 }, { 40, 9.6 }, { 50, 6.0 }, { 58, 4.8 }, { 64, 6.4 } }
for I = 1, #Prof - 1 do
	local A = V(108 - Prof[I][1], Prof[I][2], 100); local B = V(108 - Prof[I + 1][1], Prof[I + 1][2], 100)
	local D = (B - A).Unit; A -= D * 0.2; B += D * 0.2
	local CF = CFrame.lookAt((A + B) / 2, B); local L = (B - A).Magnitude
	K.Tex(K.Part(R, I == #Prof - 1 and "Kicker" or "RampDeck", Vector3.new(8, 0.8, L), CF * CFrame.new(0, -0.4, 0)), "w_ramp", 8, 8, "top")
	for _, S in { -1, 1 } do
		K.Part(R, "Lip", Vector3.new(0.4, 1.4, L), CF * CFrame.new(S * 4.2, 0.3, 0), STEEL)
	end
end
for I = 3, #Prof do -- support frames under every joint
	local U, H = Prof[I][1], Prof[I][2]; local X = 108 - U
	for _, Z in { 96.6, 103.4 } do BMM(R, "Post", { X - 0.5, 0, Z - 0.5 }, { X + 0.5, H - 0.9, Z + 0.5 }, GALV) end
	K.Detail(BMM(R, "CrossBeam", { X - 0.56, H - 1.6, 95.98 }, { X + 0.56, H - 0.84, 104.02 }, STEEL)) -- 0.12 proud of the posts
	if H > 8 then Beam(R, V(X, 0.5, 96.6), V(X, H - 1.7, 103.4), 0.4) end
end
Beam(R, V(80, 0.5, 96.6), V(80, 25.2, 96.6), 1.0, GALV, false); Beam(R, V(80, 0.5, 103.4), V(80, 25.2, 103.4), 1.0, GALV, false)
-- open steel stairs beside the ramp (z107..111): tread-plate steps on two stringers, handrails --------------------------
local St = K.Model(F, "Stairs"); local N, X0, X1 = 30, 44, 108; local Run = (X1 - X0) / N
for I = 1, N do
	K.Tex(BMM(St, "Step", { X0 + (I - 1) * Run, I * 1.2 - 0.5, 107.4 }, { X0 + I * Run + 0.05, I * 1.2, 110.6 }), "r_tread", 3, 3, "top")
end
for _, Z in { 107.2, 110.8 } do
	Beam(St, V(X0, 0.2, Z), V(X1, 35.6, Z), 0.5, STEEL, false)
	Beam(St, V(X0 + 0.5, 3.6, Z), V(X1, 39.2, Z), 0.3)
	for I = 0, 8 do local Q = V(X0, 0, Z):Lerp(V(X1, 36, Z), I / 8); K.Part(St, "RailPost", Vector3.new(0.3, 3.4, 0.3), CFrame.new(Q + Vector3.new(0, 1.9, 0)), GALV) end
end
for _, X in { 60, 76, 92 } do
	local H = (X - X0) / (X1 - X0) * 36
	for _, Z in { 107.2, 110.8 } do BMM(St, "StairPost", { X - 0.45, 0, Z - 0.45 }, { X + 0.45, H - 0.6, Z + 0.45 }, GALV) end
end
-- landing pit -----------------------------------------------------------------------------------------------------
local L = K.Model(F, "LandingPit")
for _, W in { { 10, 86, 40, 87.2 }, { 10, 110.8, 40, 112 }, { 10, 87.2, 11.2, 110.8 }, { 38.8, 87.2, 40, 110.8 } } do
	K.Tex(BMM(L, "Frame", { W[1], -0.4, W[2] }, { W[3], 1.2, W[4] }), "r_wood_h", 4, 4, "topsides")
end
K.Tex(BMM(L, "Sand", { 11.2, -0.4, 87.2 }, { 38.8, 0.9, 110.8 }), "r_sand", 10, 10, "top")
-- ONE big round backyard trampoline (Guts 2026-11-24: "make trampoline round bigg 1 not three"; ref refs/dl/
-- backyard_trampoline_0.jpg: black round mat in a thick padded ring). 26 across, mat top 3.2, W-shaped steel legs.
do
	local Tr = K.Model(F, "Trampoline"); local C = V(82, 0, 45); local R, Nn = 13, 36
	local PAD = Color3.fromRGB(40, 92, 190)
	local Mat = K.VCyl(Tr, "Mat", 2 * (R - 2.4) + 0.4, 0.2, C + Vector3.new(0, 3.1, 0), Color3.fromRGB(26, 27, 30)); Mat:SetAttribute("Bounce", true)
	K.Ring(Tr, "Pad", C + Vector3.new(0, 3.25, 0), R - 2.6, 2.9, 0.5, Nn, PAD)             -- padded spring cover
	for I = 0, Nn - 1 do                                                                     -- steel frame ring under the pad
		local a0, a1 = I / Nn * 2 * math.pi, (I + 1) / Nn * 2 * math.pi
		K.CylBetween(Tr, "Frame", 0.45, C + Vector3.new(math.cos(a0) * (R - 0.1), 2.75, math.sin(a0) * (R - 0.1)), C + Vector3.new(math.cos(a1) * (R - 0.1), 2.75, math.sin(a1) * (R - 0.1)), GALV)
	end
	for I = 0, 5 do                                                                          -- 6 W legs: two posts joined by a curved foot
		local a = I / 6 * 2 * math.pi + 0.26
		local P1 = Vector3.new(math.cos(a - 0.12) * (R - 0.1), 0, math.sin(a - 0.12) * (R - 0.1))
		local P2 = Vector3.new(math.cos(a + 0.12) * (R - 0.1), 0, math.sin(a + 0.12) * (R - 0.1))
		for _, P in { P1, P2 } do K.CylBetween(Tr, "Leg", 0.4, C + P + Vector3.new(0, 0.25, 0), C + P + Vector3.new(0, 2.75, 0), GALV) end
		local M = Vector3.new(math.cos(a) * (R + 0.4), 0, math.sin(a) * (R + 0.4))
		K.CylBetween(Tr, "Foot", 0.4, C + P1 + Vector3.new(0, 0.25, 0), C + M + Vector3.new(0, 0.25, 0), GALV)
		K.CylBetween(Tr, "Foot", 0.4, C + M + Vector3.new(0, 0.25, 0), C + P2 + Vector3.new(0, 0.25, 0), GALV)
	end
	local LCF = CFrame.lookAt(C + Vector3.new(-R - 3.2, 0, 0), C)                           -- small steel step ladder on the path side
	for I, H in { 1.1, 2.2 } do K.Tex(K.Part(Tr, "Step", Vector3.new(2.6, 0.3, 0.9), LCF * CFrame.new(0, H, -0.9 * I + 0.4)), "r_tread", 2, 2, "top") end
	for _, SX in { -1.35, 1.35 } do K.BeamBetween(Tr, "LadderRail", (LCF * CFrame.new(SX, 0, 1.2)).Position, (LCF * CFrame.new(SX, 3.0, -1.6)).Position, 0.25, 0.25, GALV) end
end
local Cnt = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then Cnt += 1 end end
return "jump tower parts " .. Cnt
