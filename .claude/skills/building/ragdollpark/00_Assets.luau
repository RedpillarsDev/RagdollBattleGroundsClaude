--!nocheck
-- Ragdoll Park 00_Assets: (re)creates ServerStorage.RagdollParkAssets, which chunks 01, 02, 06 and 08 clone from.
-- * StreetLamp (Creator Store 9095808198) and ParkBench (17305329295): free MeshParts, checked 2026-11-23, no scripts.
-- * Forest: one copy of each foliage model from Guts' paid Enchanted Forest Village pack. Needs the local file
--   content/rp_src/forest_kit.rbxm in this PC's Studio install (made by RagdollPark/forest_kit.py on Guts' machine,
--   which reads the pack .rbxl). Their 8 wind-sway Scripts are stripped: benign, but they loop forever on static props.
-- Set Target to test into another folder. Existing entries are kept (delete one to refetch it).
local Target = Target or game.ServerStorage
local A = Target:FindFirstChild("RagdollParkAssets") or Instance.new("Folder"); A.Name = "RagdollParkAssets"; A.Parent = Target
local function Strip(Root) local N = 0 for _, D in Root:GetDescendants() do if D:IsA("LuaSourceContainer") then D:Destroy(); N += 1 end end return N end
local Log = {}
for Name, Id in { StreetLamp = 9095808198, ParkBench = 17305329295 } do
	if not A:FindFirstChild(Name) then
		local Ok, Objs = pcall(function() return game:GetObjects("rbxassetid://" .. Id) end)
		if Ok and Objs[1] then
			local M = Objs[1]; if not M:IsA("Model") then local W = Instance.new("Model"); M.Parent = W; M = W end
			table.insert(Log, Name .. " fetched, scripts stripped " .. Strip(M)); M.Name = Name; M.Parent = A
		else table.insert(Log, Name .. " FAILED: " .. tostring(Objs)) end
	end
end
if not A:FindFirstChild("Forest") then
	local Ok, Objs = pcall(function() return game:GetObjects("rbxasset://rp_src/forest_kit.rbxm") end)
	if Ok then
		local F = Instance.new("Folder"); F.Name = "Forest"
		for _, O in Objs do Strip(O); if O.Name ~= "Light GReen Bush" then O.Parent = F else O:Destroy() end end
		F.Parent = A; table.insert(Log, "Forest " .. #F:GetChildren() .. " models")
	else table.insert(Log, "Forest FAILED (run forest_kit.py first): " .. tostring(Objs)) end
end
return "assets: " .. (#Log > 0 and table.concat(Log, "; ") or "all present")
