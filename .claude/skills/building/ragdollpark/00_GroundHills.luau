--!nocheck
-- Ragdoll Park 00: map Model (contract: Center / SpawnPoints / LogicPoints / Content), Roblox Grass ground with the
-- sunken pits cut out, rolling hills. Rerunnable. O = park centre at ground top. North = -Z.
-- Realistic palette + blocky square trees/hills (Guts 2026-11-23). Layout (local studs): plaza r30 at 0,0 | avenues 16 wide to a 12-wide loop at +-130 | NE pool (66,-64)
-- NW press (-60,-62) + cannon (-28,-104) + sand pit | SE ski jump (tower x108..120) + landing pit + trampolines
-- SW lava pit (-78,37) + bleachers + acid pit (-34,80) | trees r140-175 | hills ring r205/r255.
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local Park = workspace.Map:FindFirstChild("RagdollPark") or K.Model(workspace.Map, "RagdollPark")
local Content = K.Folder(Park, "Content")
local Center = Park:FindFirstChild("Center") or K.Box(Park, "Center", Vector3.new(1, 1, 1), V(0, -10, 0), Color3.fromRGB(255, 60, 60))
Center.Transparency = 0.8; Center.CanCollide = false; Park.PrimaryPart = Center
K.Folder(Park, "SpawnPoints"); K.Folder(Park, "LogicPoints")
local G = K.Clear(K.Folder(Content, "Ground"))
local HOLES = { { 46, -77, 86, -51 }, { -100, 30, -56, 44 }, { -44, 70, -24, 90 }, { -235, -235, -155, -155 } } -- pool, lava, acid, shark basin
for _, R in K.SubRects({ -520, -520, 520, 520 }, HOLES) do -- map doubled 2026-11-24 (Guts: "make the map bigger")
	K.BoxMM(G, "Grass", V(R[1], -4, R[2]), V(R[3], 0, R[4]), Color3.fromRGB(128, 172, 60), Enum.Material.Grass)
end
local H = K.Folder(G, "Hills"); local Rn = Random.new(7) -- blocky terraced hills (owner: no round shapes in a blocky map)
for _, S in { { R = 470, N = 36, W = { 70, 110 }, L = { 3, 4 }, LH = { 6, 9 }, Col = Color3.fromRGB(122, 166, 58) },
	{ R = 560, N = 30, W = { 110, 170 }, L = { 4, 5 }, LH = { 8, 12 }, Col = Color3.fromRGB(128, 160, 76) } } do
	for I = 1, S.N do
		local A = (I + Rn:NextNumber(-0.3, 0.3)) / S.N * 2 * math.pi; local RR = S.R + Rn:NextNumber(-10, 10)
		local W = Rn:NextNumber(S.W[1], S.W[2]); local D = W * Rn:NextNumber(0.6, 0.9); local Yaw = Rn:NextNumber(0, math.pi)
		local C = Vector3.new(math.cos(A) * RR, 0, math.sin(A) * RR); local Y = -1
		for L = 1, Rn:NextInteger(S.L[1], S.L[2]) do
			local Hh = Rn:NextNumber(S.LH[1], S.LH[2]); C += Vector3.new(Rn:NextNumber(-0.07, 0.07) * W, 0, Rn:NextNumber(-0.07, 0.07) * D)
			K.Part(H, "Hill", Vector3.new(W, Hh, D), CFrame.new(O + C + Vector3.new(0, Y + Hh / 2, 0)) * CFrame.Angles(0, Yaw + Rn:NextNumber(-0.15, 0.15), 0), S.Col, Enum.Material.Grass)
			Y += Hh - 0.5; W *= Rn:NextNumber(0.6, 0.74); D *= Rn:NextNumber(0.6, 0.74)
		end
	end
end
return ("ground %d parts, hills %d"):format(#G:GetChildren() - 1, #H:GetChildren())
