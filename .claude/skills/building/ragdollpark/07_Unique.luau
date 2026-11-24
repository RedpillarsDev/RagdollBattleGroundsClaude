--!nocheck
-- Ragdoll Park 07: our own stations, not in the reference (owner: "add a little uniqueness, not 1-1").
-- NW: giant bowling lane (players are the ball), real proportions for 7.2-stud pins: lane 20 wide (x-116..-96),
--     z-88..-14, steel gutters, 10 Blender pins (GiantBowlingPin, local mesh rbxasset://rp_mesh1/pin.mesh: shows only on
--     the PC that has the file until it is imported with Import 3D), backstop + masking beam, slab approach.
-- SW: tumble stairs: 20 wide concrete steps (12 wide) up to a 24-stud platform tower x-124..-110 z84..100.
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local function BMM(P, N, A, B, C) return K.BoxMM(P, N, V(A[1], A[2], A[3]), V(B[1], B[2], B[3]), C) end
local F = K.Clear(K.Folder(workspace.Map.RagdollPark.Content, "Unique"))
local STEEL, GALV, DARK = Color3.fromRGB(74, 79, 87), Color3.fromRGB(150, 155, 160), Color3.fromRGB(34, 36, 40)
-- bowling lane ----------------------------------------------------------------------------------------------------
local B = K.Model(F, "BowlingLane"); B:SetAttribute("Station", "Bowling")
local LX, LW, Z0, Z1 = -106, 7, -88, -14 -- 14 wide: real lane proportions for 5-stud (R6-sized) pins -- lane centre X, half width, far end, foul end
K.Tex(BMM(B, "Lane", { LX - LW, -0.15, Z0 }, { LX + LW, 0.45, Z1 }), "w_lane", 10, 10, "topsides")
for _, G in { { LX - LW - 2, LX - LW }, { LX + LW, LX + LW + 2 } } do K.Tex(BMM(B, "Gutter", { G[1], -0.3, Z0 }, { G[2], 0.2, Z1 }), "r_steel", 2, 4, "top") end
for _, X in { { LX - LW - 2.4, LX - LW - 2 }, { LX + LW + 2, LX + LW + 2.4 } } do BMM(B, "GutterLip", { X[1], -0.3, Z0 }, { X[2], 0.8, Z1 }, STEEL) end
K.Detail(BMM(B, "FoulLine", { LX - LW, 0.45, Z1 - 2.6 }, { LX + LW, 0.51, Z1 - 2.2 }, DARK))
for I = -3, 3 do -- target arrows (dark inlaid diamonds) in a shallow V
	K.Detail(K.Part(B, "Arrow", Vector3.new(0.8, 0.06, 0.8), CFrame.new(V(LX + I * 2.5, 0.48, -32 - math.abs(I) * 1.6)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(80, 52, 34)))
end
K.Tex(BMM(B, "Approach", { LX - LW - 2.4, -0.45, Z1 }, { LX + LW + 2.4, 0.15, -8 }), "r_slab", 8, 8, "topsides")
K.Tex(BMM(B, "Backstop", { LX - LW - 2.4, -0.3, Z0 - 0.6 }, { LX + LW + 2.4, 10, Z0 }), "r_steel", 4, 4, "all")
K.Tex(BMM(B, "MaskingBeam", { LX - LW - 3, 10, Z0 - 2 }, { LX + LW + 3, 12.5, -72 }), "r_steel", 4, 4, "all")
K.Tex(K.Detail(BMM(B, "MaskingStripe", { LX - LW - 3.06, 10.7, -72.06 }, { LX + LW + 3.06, 11.8, -71.94 })), "hazard", 2, 2, "sides")
for _, X in { { LX - LW - 2.8, LX - LW - 2.4 }, { LX + LW + 2.4, LX + LW + 2.8 } } do K.Tex(BMM(B, "Kickback", { X[1], -0.3, Z0 }, { X[2], 4.4, -56 }), "r_wood_h", 4, 4, "all") end
-- the 10 Blender pins (free physics, breakable) are placed by 09_CrazyModels.luau
-- tumble stairs -----------------------------------------------------------------------------------------------------
local T = K.Model(F, "TumbleStairs"); T:SetAttribute("Station", "TumbleStairs")
K.Tex(BMM(T, "Tower", { -124, -0.3, 84 }, { -110, 24, 100 }), "r_slab1", 4, 4, "sides")
K.Tex(BMM(T, "TowerTop", { -124.06, 23.4, 83.94 }, { -109.94, 24.06, 100.06 }), "r_slab", 8, 8, "top")
for Y = 6, 18, 6 do K.Detail(BMM(T, "Joint", { -124.08, Y - 0.12, 83.92 }, { -109.92, Y + 0.12, 100.08 }, Color3.fromRGB(110, 110, 106))) end
K.Stairs(T, CFrame.lookAt(V(-62, 0, 92), V(-80, 0, 92)), 12, 24, 48, Color3.fromRGB(150, 150, 146), GALV, "r_slab1")
local function Rail(A, Bp)
	K.Detail(K.BeamBetween(T, "Rail", A + Vector3.new(0, 3.2, 0), Bp + Vector3.new(0, 3.2, 0), 0.3, 0.3, GALV))
	local N = math.max(1, math.floor((Bp - A).Magnitude / 4))
	for I = 0, N do K.Part(T, "RailPost", Vector3.new(0.3, 3.2, 0.3), CFrame.new(A:Lerp(Bp, I / N) + Vector3.new(0, 1.6 + 0.06, 0)), GALV) end
end
Rail(V(-123.6, 24, 84.4), V(-123.6, 24, 99.6)); Rail(V(-123.6, 24, 84.4), V(-110.4, 24, 84.4)); Rail(V(-123.6, 24, 99.6), V(-110.4, 24, 99.6))
local Cnt = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then Cnt += 1 end end
return "unique parts " .. Cnt
