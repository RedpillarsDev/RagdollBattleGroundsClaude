--!nocheck
-- Ragdoll Park 05 (SW): sunken lava pit (x-100..-56 z30..44) with a plank bridge, sunken acid pit (x-44..-24 z70..90),
-- stepped concrete bleachers facing the lava, warning signs. Hazard surfaces carry attribute Hazard = "Lava"/"Acid".
-- Pit walls sit 0.1 inside the grass cut and stop 0.3 under grass top (no coplanar faces); copings cover the edges.
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local function BMM(P, N, A, B, C) return K.BoxMM(P, N, V(A[1], A[2], A[3]), V(B[1], B[2], B[3]), C) end
local F = K.Clear(K.Folder(workspace.Map.RagdollPark.Content, "Hazards")); F:SetAttribute("Station", "Hazards")
local STEEL, ALU = Color3.fromRGB(74, 79, 87), Color3.fromRGB(178, 182, 186)
local function Sign(P, X, Z, Yaw)
	local Sg = K.Model(P, "WarningSign"); local CF = CFrame.new(V(X, 0, Z)) * CFrame.Angles(0, Yaw, 0)
	K.Part(Sg, "Post", Vector3.new(0.4, 5.2, 0.4), CF * CFrame.new(0, 2.6, 0), STEEL)
	for _, S in { -1, 1 } do K.Detail(K.Wedge(Sg, "Tri", Vector3.new(0.2, 3.4, 1.9), CF * CFrame.new(0, 6.9, S * 0.95) * CFrame.Angles(0, S > 0 and math.pi or 0, 0), Color3.fromRGB(230, 182, 30))) end
	K.Detail(K.Part(Sg, "Mark", Vector3.new(0.36, 1.5, 0.4), CF * CFrame.new(0, 6.95, 0), Color3.fromRGB(25, 25, 25)))
	K.Detail(K.Part(Sg, "Dot", Vector3.new(0.36, 0.35, 0.4), CF * CFrame.new(0, 5.78, 0), Color3.fromRGB(25, 25, 25)))
end
local function Pit(Name, X0, Z0, X1, Z1, Tex, Surf, Light, HighSides)
	local P = K.Model(F, Name)
	for _, W in { { X0 - 1, Z0 - 1, X1 + 1, Z0 + 0.1 }, { X0 - 1, Z1 - 0.1, X1 + 1, Z1 + 1 }, { X0 - 1, Z0 + 0.1, X0 + 0.1, Z1 - 0.1 }, { X1 - 0.1, Z0 + 0.1, X1 + 1, Z1 - 0.1 } } do
		K.Tex(BMM(P, "PitWall", { W[1], -5, W[2] }, { W[3], -0.3, W[4] }), "r_stone", 6, 6, "sides")
	end
	local S = K.Tex(BMM(P, Name .. "Surface", { X0 + 0.1, -5, Z0 + 0.1 }, { X1 - 0.1, Surf, Z1 - 0.1 }), Tex, 14, 14, "top")
	S:SetAttribute("Hazard", Name == "LavaPit" and "Lava" or "Acid")
	for I = 1, 3 do local L = Instance.new("PointLight"); L.Color = Light; L.Range = 16; L.Brightness = 0.55
		local A = Instance.new("Attachment"); A.Position = Vector3.new((I - 2) * S.Size.X / 3, S.Size.Y / 2 + 3, 0); A.Parent = S; L.Parent = A end
	-- copings: High sides get a 1.7 tall concrete curb with a hazard top, the rest a low curb 0.12 above the grass
	local Sides = { N = { X0 - 1.6, Z0 - 1.6, X1 + 1.6, Z0 + 0.3 }, S = { X0 - 1.6, Z1 - 0.3, X1 + 1.6, Z1 + 1.6 },
		W = { X0 - 1.6, Z0 + 0.3, X0 + 0.3, Z1 - 0.3 }, E = { X1 - 0.3, Z0 + 0.3, X1 + 1.6, Z1 - 0.3 } }
	for Side, C in Sides do
		local High = HighSides[Side]; local Top = High and 1.4 or 0.12
		K.Tex(BMM(P, "Coping", { C[1], -0.3, C[2] }, { C[3], Top, C[4] }), "r_slab1", 3.2, 3.2, "topsides")
		if High then K.Tex(K.Detail(BMM(P, "CopingHazard", { C[1] + 0.06, Top, C[2] + 0.06 }, { C[3] - 0.06, Top + 0.06, C[4] - 0.06 })), "hazard", 2.4, 2.4, "top") end
	end
	return P
end
local Lava = Pit("LavaPit", -100, 30, -56, 44, "lava", -1.2, Color3.fromRGB(255, 120, 40), { N = true, S = true })
K.Tex(BMM(Lava, "PlankBridge", { -78.8, 1.4, 28.4 }, { -77.2, 1.8, 45.6 }), "r_wood", 1.6, 6, "all")
for _, Z in { 30.6, 43.4 } do K.Detail(BMM(Lava, "BridgeCleat", { -79.1, 1.4, Z - 0.3 }, { -76.9, 1.9, Z + 0.3 }, STEEL)) end
local Acid = Pit("AcidPit", -44, 70, -24, 90, "acid", -1.0, Color3.fromRGB(120, 255, 70), { S = true, W = true, E = true })
Sign(F, -103.5, 36.5, 0); Sign(F, -52.5, 36.5, 0); Sign(F, -34, 66.4, math.pi / 2)
-- bleachers x-98..-58 z54..66, 4 concrete tiers rising south, aluminium seat planks; tiers shrink 0.06 per level so no
-- two tiers share a side or back face
local B = K.Model(F, "Bleachers")
for I = 1, 4 do
	local D = 0.06 * (I - 1); local Z0 = 54 + 3 * (I - 1); local Top = 1.4 * I
	K.Tex(BMM(B, "Tier", { -98 + D, -0.3, Z0 }, { -58 - D, Top, 66 - D }), "r_slab1", 4, 4, "topsides")
	BMM(B, "Seat", { -97, Top + 0.55, Z0 + 0.5 }, { -59, Top + 0.9, Z0 + 1.9 }, ALU).Reflectance = 0.15
	for X = -95, -61, 6.8 do K.Detail(BMM(B, "SeatBracket", { X - 0.2, Top, Z0 + 0.9 }, { X + 0.2, Top + 0.55, Z0 + 1.5 }, STEEL)) end
end
for _, X in { -98.6, -57.4 } do -- end rails
	K.Detail(K.BeamBetween(B, "Rail", V(X, 4.4, 54.5), V(X, 9.6, 65.5), 0.3, 0.3, ALU))
	for _, Z in { 54.5, 60, 65.5 } do local H = 4.4 + (Z - 54.5) / 11 * 5.2; K.Part(B, "RailPost", Vector3.new(0.3, H, 0.3), CFrame.new(V(X, H / 2, Z)), ALU) end
end
local Cnt = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then Cnt += 1 end end
return "hazard parts " .. Cnt
