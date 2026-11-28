--!nocheck
--[[ Floating-island ground generator (used for the City map, 2026-10-09).

Paste into execute_luau (GPT Playground, Edit) after editing the CONFIG block. Re-runnable: it clears and
rebuilds Content.Ground, Content.Underside and Content.Rims of the map Model.

What it builds, on a grid of CS-stud cells:
- Surfaces: one greedy-merged Part per run of same-type cells (roads at Y 0, raised types at Y 0.6), so a
  360x360 island costs ~90 parts, not 3600.
- Foundation: a 4-stud collidable concrete slab under everything (stops fast falls tunnelling the thin top).
- Strata: 8-stud layers stepping in from every edge AND every hole (a BFS distance field), so the underside
  is an inverted, layered cone and the holes stay open all the way down. Non-colliding (Kit.Detail).
- Boulders on each layer's rim, so the stepped silhouette reads as rock instead of voxels.
- Curbs wherever a raised surface meets road.
- Rims: tilted broken slabs and soil clods around every hole, sparser chunks and rebar on the outer edge.
]]

local Kit = loadstring(game.ServerStorage.ClaudeBuildKit.Source)()
local P = Kit.Palette
local M = Enum.Material

------------------------------------------------------------------ CONFIG
local MapName = "CityMap_Claude"
local O = Vector3.new(3000, 150, 0) -- street-level centre of the island (world)
local CS, N = 6, 60 -- cell size and cells per side: covers N*CS studs
local HALF = CS * N / 2
-- 2026-10-09 v2: Redpillars asked for a smaller map with bigger holes. Radius 170 -> 140 (about 280 studs
-- across instead of 350); pit 42x36 -> 48x48, sinkholes r 11-12 -> 15-16.
local Radius, Squareness = 140, 4 -- superellipse: 2 = circle, 4 = rounded square
local Bites = { -- chunks missing from the outline: {centre, radius}
	{ P = Vector2.new(123, -138), R = 19 },
	{ P = Vector2.new(-146, -33), R = 13 },
	{ P = Vector2.new(49, 148), R = 12 },
	{ P = Vector2.new(146, 49), R = 10 },
}
local function InHole(x, z) -- fall-through holes (they go through the whole island)
	local jx = math.noise(z / 9, 1.5, 7.1) * 5
	local jz = math.noise(x / 9, 2.5, 7.1) * 5
	if x > -80 + jx and x < -30 - jx and z > -100 + jz and z < -56 - jz then return true end -- construction pit
	local n1 = math.noise(x / 7, z / 7, 3.3) * 4
	if (Vector2.new(x, z) - Vector2.new(-72, 2)).Magnitude < 16 + n1 then return true end -- avenue sinkhole
	if (Vector2.new(x, z) - Vector2.new(58, 54)).Magnitude < 15 + n1 then return true end -- car park sinkhole
	return false
end
local function SurfType(x, z) -- which surface a cell gets
	local ax, az = math.abs(x), math.abs(z)
	if az < 12 or ax < 12 then return "Road" end
	if az < 18 or ax < 18 then return "Sidewalk" end
	if x > 0 and z < 0 then return "Plaza" end
	if x < 0 and z < 0 then return "Dirt" end
	if x > 0 and z > 0 then
		if x > 24 and x < 96 and z > 24 and z < 86 then return "Lot" end
		return "Sidewalk"
	end
	return "Pavers"
end
local Types = {
	Road = { Top = 0, Color = P.Road, Mat = M.Asphalt },
	Lot = { Top = 0, Color = P.Lot, Mat = M.Asphalt },
	Sidewalk = { Top = 0.6, Color = P.Sidewalk, Mat = M.Concrete },
	Plaza = { Top = 0.6, Color = P.Plaza, Mat = M.Pavement },
	Pavers = { Top = 0.6, Color = P.Pavers, Mat = M.Pavement },
	Dirt = { Top = 0.6, Color = P.Dirt, Mat = M.Ground },
}
------------------------------------------------------------------ END CONFIG

local Map = workspace:FindFirstChild(MapName)
if not Map then Map = Instance.new("Model"); Map.Name = MapName; Map.Parent = workspace end
local Content = Kit.Folder(Map, "Content")
local Ground = Kit.Clear(Kit.Folder(Content, "Ground"))
local Under = Kit.Clear(Kit.Folder(Content, "Underside"))
local Rims = Kit.Clear(Kit.Folder(Content, "Rims"))
local function CX(i) return -HALF + CS * (i + 0.5) end

-- math.noise returns 0 at whole-number inputs: always divide coordinates and use fractional seeds
local function InIsland(x, z)
	local n = math.noise(x / 46, z / 46, 11.3) * 12 + math.noise(x / 15, z / 15, 4.7) * 5
	local d = ((math.abs(x) / Radius) ^ Squareness + (math.abs(z) / Radius) ^ Squareness) ^ (1 / Squareness) * Radius
	if d > Radius + n then return false end
	for _, B in Bites do
		if (Vector2.new(x, z) - B.P).Magnitude < B.R + math.noise(x / 6, z / 6, 2.2) * 4 then return false end
	end
	return true
end

local Solid, Type, Outside = {}, {}, {}
for j = 0, N - 1 do for i = 0, N - 1 do
	local x, z = CX(i), CX(j)
	local k = j * N + i
	Outside[k] = not InIsland(x, z)
	Solid[k] = not Outside[k] and not InHole(x, z)
	Type[k] = SurfType(x, z)
end end
local function IsSolid(i, j) return i >= 0 and j >= 0 and i < N and j < N and Solid[j * N + i] end

-- distance (cells) to the nearest edge or hole
local Dist, Queue, Head = {}, {}, 1
for j = 0, N - 1 do for i = 0, N - 1 do
	if Solid[j * N + i] and not (IsSolid(i + 1, j) and IsSolid(i - 1, j) and IsSolid(i, j + 1) and IsSolid(i, j - 1)) then
		Dist[j * N + i] = 1; table.insert(Queue, { i, j })
	end
end end
while Head <= #Queue do
	local c = Queue[Head]; Head += 1
	local d = Dist[c[2] * N + c[1]]
	for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local ii, jj = c[1] + o[1], c[2] + o[2]
		if IsSolid(ii, jj) and not Dist[jj * N + ii] then Dist[jj * N + ii] = d + 1; table.insert(Queue, { ii, jj }) end
	end
end

-- greedy rectangle merge of a cell mask
local function Greedy(Mask)
	local Used, Rects = {}, {}
	for j = 0, N - 1 do for i = 0, N - 1 do
		if Mask(i, j) and not Used[j * N + i] then
			local i1 = i
			while i1 + 1 < N and Mask(i1 + 1, j) and not Used[j * N + i1 + 1] do i1 += 1 end
			local j1 = j
			while j1 + 1 < N do
				local ok = true
				for ii = i, i1 do if not Mask(ii, j1 + 1) or Used[(j1 + 1) * N + ii] then ok = false; break end end
				if not ok then break end
				j1 += 1
			end
			for jj = j, j1 do for ii = i, i1 do Used[jj * N + ii] = true end end
			table.insert(Rects, { i, j, i1, j1 })
		end
	end end
	return Rects
end
local function RectPart(Parent, Name, R, Y0, Y1, Color, Mat)
	local Min = O + Vector3.new(-HALF + R[1] * CS, Y0, -HALF + R[2] * CS)
	local Max = O + Vector3.new(-HALF + (R[3] + 1) * CS, Y1, -HALF + (R[4] + 1) * CS)
	return Kit.BoxMinMax(Parent, Name, Min, Max, Color, Mat)
end

-- surfaces, foundation, strata + boulders
for Name, T in Types do
	local F = Kit.Folder(Ground, Name)
	for _, R in Greedy(function(i, j) return Solid[j * N + i] and Type[j * N + i] == Name end) do
		RectPart(F, Name, R, -1, T.Top, T.Color, T.Mat)
	end
end
for _, R in Greedy(function(i, j) return Solid[j * N + i] end) do
	RectPart(Under, "Foundation", R, -5, -1, P.Foundation, M.Concrete)
end
local Depth = {}
for k, d in Dist do Depth[k] = math.min(110, 14 + d * CS * 0.85 + math.noise(k * 0.37, 0.5, 9.1) * 8) end
for L = 1, 13 do
	local Y1, Y0 = -5 - 8 * (L - 1), -5 - 8 * L
	local Color, Mat
	if L == 1 then Color, Mat = P.Soil, M.Ground else Color, Mat = P.Rock[(L - 2) % #P.Rock + 1], ((L % 2 == 0) and M.Rock or M.Slate) end
	local InLayer = function(i, j) local k = j * N + i; return Solid[k] and Depth[k] and Depth[k] >= -Y0 end
	local Rects = Greedy(InLayer)
	if #Rects == 0 then break end
	for _, R in Rects do Kit.Detail(RectPart(Under, "Strata" .. L, R, Y0, Y1, Color, Mat)) end
	local Rng = Random.new(100 + L)
	for j = 0, N - 1 do for i = 0, N - 1 do
		if InLayer(i, j) then
			for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				if not InLayer(i + o[1], j + o[2]) and Rng:NextNumber() < 0.2 then
					local S = Rng:NextNumber(4, 8)
					local Pos = O + Vector3.new(CX(i) + o[1] * Rng:NextNumber(1, 3), (Y0 + Y1) / 2 + Rng:NextNumber(-2, 2), CX(j) + o[2] * Rng:NextNumber(1, 3))
					local CF = CFrame.new(Pos) * CFrame.Angles(Rng:NextNumber(0, 6.28), Rng:NextNumber(0, 6.28), Rng:NextNumber(0, 6.28))
					Kit.Detail(Kit.Part(Under, "Boulder", Vector3.new(S, S * Rng:NextNumber(0.6, 1), S * Rng:NextNumber(0.7, 1.1)), CF, Color, Mat))
				end
			end
		end
	end end
end

-- curbs where a raised surface meets road
local Curbs = Kit.Folder(Ground, "Curbs")
local function Raised(k) return Types[Type[k]].Top > 0 end
local function CurbRun(i0, i1, j, Side, Horizontal)
	local a, b = -HALF + i0 * CS, -HALF + (i1 + 1) * CS
	local edge = -HALF + (Side > 0 and (j + 1) or j) * CS
	if Horizontal then
		Kit.Box(Curbs, "Curb", Vector3.new(b - a, 1.1, 0.8), O + Vector3.new((a + b) / 2, 0.15, edge - Side * 0.4), P.Curb, M.Concrete)
	else
		Kit.Box(Curbs, "Curb", Vector3.new(0.8, 1.1, b - a), O + Vector3.new(edge - Side * 0.4, 0.15, (a + b) / 2), P.Curb, M.Concrete)
	end
end
for _, Side in { 1, -1 } do
	for j = 0, N - 1 do
		local Run
		for i = 0, N do
			local Is = i < N and IsSolid(i, j) and IsSolid(i, j + Side) and Raised(j * N + i) and not Raised((j + Side) * N + i)
			if Is and not Run then Run = i end
			if not Is and Run then CurbRun(Run, i - 1, j, Side, true); Run = nil end
		end
	end
	for i = 0, N - 1 do
		local Run
		for j = 0, N do
			local Is = j < N and IsSolid(i, j) and IsSolid(i + Side, j) and Raised(j * N + i) and not Raised(j * N + i + Side)
			if Is and not Run then Run = j end
			if not Is and Run then CurbRun(Run, j - 1, i, Side, false); Run = nil end
		end
	end
end

-- rims: broken slabs + clods round holes, sparser chunks + rebar on the outer edge
local Rng = Random.new(77)
for j = 0, N - 1 do for i = 0, N - 1 do
	local k = j * N + i
	if Solid[k] then
		local T = Types[Type[k]]
		for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ii, jj = i + o[1], j + o[2]
			if not IsSolid(ii, jj) then
				local Inside = ii >= 0 and jj >= 0 and ii < N and jj < N
				local IsHole = Inside and not Outside[jj * N + ii]
				local Dir = Vector3.new(o[1], 0, o[2])
				local Across = Vector3.new(-o[2], 0, o[1])
				local Edge = O + Vector3.new(CX(i), 0, CX(j)) + Dir * (CS / 2)
				local function Chunk(Pos, Size, Tilt, Yaw)
					local CF = CFrame.lookAt(Pos, Pos + Dir) * CFrame.Angles(0, Yaw, 0) * CFrame.Angles(-Tilt, 0, 0)
					Kit.Detail(Kit.Part(Rims, "Chunk", Size, CF, T.Color, T.Mat))
				end
				if IsHole then
					for _, Off in { -1.6, 1.6 } do
						Chunk(Edge + Across * (Off + Rng:NextNumber(-0.6, 0.6)) + Dir * Rng:NextNumber(-0.2, 1.4) + Vector3.new(0, T.Top - 0.7 - Rng:NextNumber(0, 0.9), 0),
							Vector3.new(Rng:NextNumber(2.6, 4.2), Rng:NextNumber(1.0, 1.4), Rng:NextNumber(2.2, 3.6)), math.rad(Rng:NextNumber(14, 38)), math.rad(Rng:NextNumber(-22, 22)))
					end
					if Rng:NextNumber() < 0.6 then
						local S = Rng:NextNumber(2, 3.5)
						local Pos = Edge + Across * Rng:NextNumber(-2.5, 2.5) + Dir * Rng:NextNumber(0, 1) + Vector3.new(0, T.Top - Rng:NextNumber(3, 7), 0)
						Kit.Detail(Kit.Part(Rims, "Clod", Vector3.new(S, S * 0.8, S), CFrame.new(Pos) * CFrame.Angles(Rng:NextNumber(0, 6), Rng:NextNumber(0, 6), Rng:NextNumber(0, 6)), P.Soil, M.Ground))
					end
				elseif Rng:NextNumber() < 0.38 then
					Chunk(Edge + Across * Rng:NextNumber(-2, 2) + Dir * Rng:NextNumber(0, 1.2) + Vector3.new(0, T.Top - 0.9 - Rng:NextNumber(0, 1.2), 0),
						Vector3.new(Rng:NextNumber(3, 5), Rng:NextNumber(1.2, 1.8), Rng:NextNumber(2.4, 4)), math.rad(Rng:NextNumber(8, 30)), math.rad(Rng:NextNumber(-25, 25)))
					if Type[k] == "Road" and Rng:NextNumber() < 0.7 then
						for _ = 1, 3 do
							local A = Edge + Across * Rng:NextNumber(-2.6, 2.6) + Vector3.new(0, -2.5 + Rng:NextNumber(-0.8, 0.8), 0)
							local Tip = A + Dir * Rng:NextNumber(1.5, 3.5) + Vector3.new(0, Rng:NextNumber(-1.5, 0.8), 0) + Across * Rng:NextNumber(-0.6, 0.6)
							Kit.Detail(Kit.CylBetween(Rims, "Rebar", 0.22, A, Tip, Color3.fromRGB(150, 84, 60), M.CorrodedMetal))
						end
					end
				end
			end
		end
	end
end end

local Count = 0
for _, F in { Ground, Under, Rims } do for _, D in F:GetDescendants() do if D:IsA("BasePart") then Count += 1 end end end
return "island parts: " .. Count
