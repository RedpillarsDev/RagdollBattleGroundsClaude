--!nocheck
-- Ragdoll Park 08: trees + bushes from the owner's paid Enchanted Forest pack (ServerStorage.RagdollParkAssets.Forest,
-- wind scripts stripped). Owner rules: foliage only from this pack (never boxes/balls); canopies never touch
-- (centre distance >= r1 + r2 + 4, r = (X + Z extent) / 4); props sunk a little and turned. Ground found by raycast
-- (hill terraces included). Foliage is non-colliding (mesh hulls would make invisible walls).
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local Park = workspace.Map.RagdollPark
local F = K.Clear(K.Folder(Park.Content, "Foliage"))
local Kit = game.ServerStorage.RagdollParkAssets.Forest
local Rn = Random.new(23)
-- keep-out rects {x0,z0,x1,z1} in local studs (stations, paths, plaza), grown by the item radius when tested
local KEEP = {
	{ -10, -140, 10, 140 }, { -140, -10, 140, 10 }, { -140, -140, 140, -120 }, { -140, 120, 140, 140 }, { -140, -140, -120, 140 }, { 120, -140, 140, 140 },
	{ 34, -94, 98, -39 }, { 60, -116, 72, -88 }, { 58, -45, 72, -8 }, { -78, -80, -42, -44 }, { -67, -50, -53, -8 }, { -40, -114, -18, -94 }, { -116, -120, -78, -88 },
	{ 104, 88, 124, 118 }, { 40, 92, 110, 116 }, { 6, 82, 44, 116 }, { 50, 28, 112, 62 }, { 58, 8, 72, 28 },
	{ -106, 24, -50, 50 }, { -102, 50, -54, 70 }, { -50, 64, -18, 96 }, { -52, 8, -38, 54 },
	{ -121, -92, -91, -6 }, { -126, 80, -58, 104 }, { -42, -16, -12, -6 }, { 30, 106, 50, 126 }, { -90, -46, -76, -34 }, { 110, -36, 124, -24 }, { -22, 92, -10, 104 },
	{ 12, 38, 48, 62 }, { -126, -118, -108, -90 }, { -40, 40, -8, 58 }, { 100, -122, 123, -36 }, -- 09 crazy models
	{ -10, -258, 10, -130 }, { -10, 130, 10, 258 }, { -258, -10, -130, 10 }, { 130, -10, 258, 10 }, -- avenue extensions
	{ -258, -258, 258, -242 }, { -258, 242, 258, 258 }, { -258, -258, -242, 258 }, { 242, -258, 258, 258 }, -- outer loop
	{ 150, -242, 242, -148 }, { -242, -242, -140, -140 }, { 152, 152, 242, 242 }, { -244, 152, -184, 244 }, -- 10 zones
}
local function Free(X, Z, R)
	if X * X + Z * Z < (42 + R) ^ 2 then return false end
	for _, B in KEEP do if X > B[1] - R and X < B[3] + R and Z > B[2] - R and Z < B[4] + R then return false end end
	return true
end
local RP = RaycastParams.new(); RP.FilterType = Enum.RaycastFilterType.Include; RP.FilterDescendantsInstances = { Park.Content.Ground }
local function GroundY(X, Z)
	local H = workspace:Raycast(V(X, 200, Z), Vector3.new(0, -260, 0), RP); return H and (H.Position.Y - O.Y) or nil
end
local Placed = {}
local function Spaced(X, Z, R) for _, P in Placed do if (P[1] - X) ^ 2 + (P[2] - Z) ^ 2 < (P[3] + R + 4) ^ 2 then return false end end return true end
local function Put(Name, X, Z, H, Sink, Parent)
	local M = Kit[Name]:Clone(); M:ScaleTo(1)
	local _, S0 = M:GetBoundingBox(); M:ScaleTo(H / S0.Y)
	M:PivotTo(M:GetPivot() * CFrame.Angles(0, Rn:NextNumber(0, 2 * math.pi), 0))
	local C, S = M:GetBoundingBox(); local GY = GroundY(X, Z) or 0
	M:PivotTo(M:GetPivot() + (V(X, GY + S.Y / 2 - Sink * S.Y, Z) - C.Position))
	for _, D in M:GetDescendants() do if D:IsA("BasePart") then D.Anchored = true; D.CanCollide = false; D.CanQuery = false; D.CanTouch = false end end
	M.Parent = Parent
	return (S.X + S.Z) / 4
end
local function Radius(Name, H) local M = Kit[Name]; local _, S = M:GetBoundingBox(); return (S.X + S.Z) / 4 * H / S.Y end
-- trees: forest band outside the loop (onto the hill feet) + a few inside the quadrants
local TreesF = K.Folder(F, "Trees")
local Kinds = { { "Tree 1", 18, 26, 0.40 }, { "Pine Tree 3", 30, 42, 0.65 }, { "JH_Trees", 26, 36, 0.82 }, { "JS-Tree_02", 22, 30, 1.0 } }
local function PickKind() local U = Rn:NextNumber() for _, Kd in Kinds do if U <= Kd[4] then return Kd end end return Kinds[1] end
local NOut, NIn, Tries = 0, 0, 0
while NOut < 110 and Tries < 8000 do
	Tries += 1
	local A = Rn:NextNumber(0, 2 * math.pi); local R = Rn:NextNumber(266, 430); local X, Z = math.cos(A) * R, math.sin(A) * R
	local Kd = PickKind(); local H = Rn:NextNumber(Kd[2], Kd[3]); local Rad = Radius(Kd[1], H)
	if Free(X, Z, Rad * 0.6) and Spaced(X, Z, Rad) and GroundY(X, Z) then
		table.insert(Placed, { X, Z, Put(Kd[1], X, Z, H, 0.03, TreesF) }); NOut += 1
	end
end
Tries = 0
while NIn < 34 and Tries < 6000 do
	Tries += 1
	local X, Z = Rn:NextNumber(-240, 240), Rn:NextNumber(-240, 240)
	local Kd = Kinds[Rn:NextInteger(1, 2)]; local H = Rn:NextNumber(Kd[2], Kd[3]) * 0.85; local Rad = Radius(Kd[1], H)
	if Free(X, Z, Rad * 0.7) and Spaced(X, Z, Rad) then table.insert(Placed, { X, Z, Put(Kd[1], X, Z, H, 0.03, TreesF) }); NIn += 1 end
end
-- bushes: along the inside of the loop, at tree feet and around station edges (soft lobed pack bushes only)
local BushF = K.Folder(F, "Bushes"); local NB = 0; Tries = 0
local Bushes = { { "Bush2_01", 3.4, 4.6 }, { "Bush2_02", 3.0, 4.2 }, { "bush 1", 4.5, 6.5 }, { "Dark Green Ferns", 2.6, 3.6 } }
while NB < 140 and Tries < 12000 do
	Tries += 1
	local X, Z
	if Rn:NextNumber() < 0.5 then local A = Rn:NextNumber(0, 2 * math.pi); local R = Rn:NextNumber(262, 340); X, Z = math.cos(A) * R, math.sin(A) * R
	else X, Z = Rn:NextNumber(-240, 240), Rn:NextNumber(-240, 240) end
	local Bd = Bushes[Rn:NextInteger(1, #Bushes)]; local H = Rn:NextNumber(Bd[2], Bd[3]); local Rad = Radius(Bd[1], H)
	local Ok = Free(X, Z, Rad * 0.8) and GroundY(X, Z)
	if Ok then for _, P in Placed do if (P[1] - X) ^ 2 + (P[2] - Z) ^ 2 < (math.max(P[3] * 0.55, Rad + 1.5)) ^ 2 then Ok = false break end end end
	if Ok then table.insert(Placed, { X, Z, Put(Bd[1], X, Z, H, Rn:NextNumber(0.15, 0.3), BushF) * 0.6 }); NB += 1 end
end
return ("trees %d outside + %d inside, bushes %d"):format(NOut, NIn, NB)
