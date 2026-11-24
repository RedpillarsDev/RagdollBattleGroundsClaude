--!nocheck
-- Ragdoll Park 06: street lamps + park benches (2 Creator Store meshes, checked: no scripts, kept in
-- ServerStorage.RagdollParkAssets), open-top steel bins (CSG unions), crate clusters, SpawnPoints (map contract).
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local Park = workspace.Map.RagdollPark
local F = K.Clear(K.Folder(Park.Content, "Props"))
local A = game.ServerStorage.RagdollParkAssets
local function Mesh(Src, Name, Scale, Pos, Yaw)
	local M = Src:FindFirstChildWhichIsA("MeshPart", true):Clone(); M.Name = Name; M.Anchored = true
	M.Size = M.Size * Scale; M.CFrame = CFrame.new(Pos + Vector3.new(0, M.Size.Y / 2, 0)) * CFrame.Angles(0, Yaw, 0); M.Parent = F
	return M
end
-- lamps: the mesh's pole is at its local +X end and the arm/head at -X (checked from above 2026-11-24). Pole stands
-- 10.6 off the path centre, the arm reaches back over the path: yaw maps local -X onto the arm direction D, and the
-- part (placed by its bounding-box centre) shifts by half the arm length so the pole lands on the planned spot.
local LampLen = A.StreetLamp:FindFirstChildWhichIsA("MeshPart", true).Size.X * 0.32
for _, L in { { 10.6, -52, -1, 0 }, { -10.6, -96, 1, 0 }, { -10.6, 52, 1, 0 }, { 10.6, 96, -1, 0 },
	{ 52, 10.6, 0, -1 }, { 96, -10.6, 0, 1 }, { -52, -10.6, 0, 1 }, { -96, 10.6, 0, -1 } } do
	local D = Vector3.new(L[3], 0, L[4])
	Mesh(A.StreetLamp, "StreetLamp", 0.32, V(L[1], 0, L[2]) + D * (LampLen / 2 - 0.3), math.atan2(L[4], -L[3]))
end
-- benches around the plaza (facing the centre) and along the avenues
local function Bench(X, Z, Yaw) local B = Mesh(A.ParkBench, "Bench", 0.14, V(X, 0, Z), Yaw); return B end
for I = 0, 3 do local Ang = math.rad(45 + 90 * I); Bench(math.cos(Ang) * 37, math.sin(Ang) * 37, -Ang - math.pi / 2) end
Bench(44, 11.6, 0); Bench(-44, -11.6, math.pi); Bench(11.6, 44, math.pi / 2); Bench(-11.6, -44, -math.pi / 2)
-- open-top square steel bins (union: box minus inner box), next to the plaza benches
local Bin0 = K.Box(F, "BinShell", Vector3.new(1.8, 2.6, 1.8), V(0, 1.3, 0), Color3.fromRGB(70, 92, 76), Enum.Material.Metal)
local Cut = K.Box(F, "Cut", Vector3.new(1.5, 2.6, 1.5), V(0, 1.6, 0), Color3.new(1, 1, 1))
local Ok, Bin = pcall(function() return Bin0:SubtractAsync({ Cut }) end)
Cut:Destroy()
if Ok and Bin then Bin0:Destroy(); Bin.Name = "Bin"; Bin.Anchored = true; Bin.UsePartColor = true; Bin.Color = Color3.fromRGB(70, 92, 76); Bin.Parent = F else Bin = Bin0 end
for I = 0, 3 do
	local Ang = math.rad(45 + 90 * I + 12)
	local C = Bin:Clone(); C.CFrame = CFrame.new(V(math.cos(Ang) * 37, 1.3, math.sin(Ang) * 37)) * CFrame.Angles(0, -Ang, 0); C.Parent = F
	K.Detail(K.Box(F, "BinBag", Vector3.new(1.46, 0.1, 1.46), C.Position + Vector3.new(0, 0.9, 0), Color3.fromRGB(30, 32, 34)))
end
Bin:Destroy()
-- crate clusters (painted planks + dark outline), 2-4 crates each
local function Crate(Base, S, Yaw)
	local M = K.Model(F, "Crate"); local CF = CFrame.new(Base + Vector3.new(0, S / 2, 0)) * CFrame.Angles(0, Yaw, 0)
	K.Tex(K.Part(M, "Body", Vector3.new(S, S, S), CF), "r_wood", S, S, "all")
	K.Outline(M, CF, Vector3.new(S, S, S), 0.3, Color3.fromRGB(70, 54, 42))
end
for _, C in { { 40, 120, 0.1 }, { -84, -40, -0.2 }, { -16, 98, 0.35 }, { 116, -30, 0 } } do
	local B = V(C[1], 0, C[2])
	Crate(B, 4, C[3]); Crate(B + Vector3.new(4.6, 0, 0.8), 3.4, C[3] + 0.2); Crate(B + Vector3.new(0.3, 4, -0.1), 3, C[3] - 0.15)
	Crate(B + Vector3.new(-1.2, 0, 4.4), 2.6, C[3] + 0.5)
end
-- spawn points (contract: 1x1x1 Parts named SpawnPoint, ~3 studs above open ground, spread over every zone)
local SP = K.Clear(Park.SpawnPoints)
for I, S in { { 0, -20 }, { 20, 0 }, { 0, 20 }, { -20, 0 }, { 14, -14 }, { -14, 14 }, { 0, -70 }, { 70, 0 }, { 0, 70 }, { -70, 0 }, { 130, 60 }, { -130, -60 }, { 0, -250 }, { 250, 0 }, { 0, 250 }, { -250, 0 } } do
	local P = K.Box(SP, "SpawnPoint", Vector3.new(1, 1, 1), V(S[1], 3.2, S[2]), Color3.fromRGB(80, 200, 120))
	P.Transparency = 0.6; P.CanCollide = false; P.CanQuery = false; P.CanTouch = false
end
local Cnt = 0 for _, D in F:GetDescendants() do if D:IsA("BasePart") then Cnt += 1 end end
return ("props parts %d, bins union %s, spawns %d"):format(Cnt, tostring(Ok), #SP:GetChildren())
