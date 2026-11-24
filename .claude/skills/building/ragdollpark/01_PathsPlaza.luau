--!nocheck
-- Ragdoll Park 01: concrete slab paths ('r_slab'), round spawn plaza (polar 'r_plaza' texture on a cylinder cap),
-- centre planter with a pack tree. Heights: grass 0 | curb ring 0.09 | paths 0.15 | plaza 0.21 (0.06 apart, no z-fight).
local K = loadstring(game.ServerStorage.ClaudeParkKit.Source)()
local O = Vector3.new(3000, 20, 0)
local function V(x, y, z) return O + Vector3.new(x, y, z) end
local Content = workspace.Map.RagdollPark.Content
local F = K.Clear(K.Folder(Content, "Paths"))
local ST = Color3.new(0.97, 0.97, 0.97)
local function Path(Name, X0, Z0, X1, Z1, Tile)
	return K.Tex(K.BoxMM(F, Name, V(X0, -0.45, Z0), V(X1, 0.15, Z1)), "r_slab", Tile or 16, Tile or 16, "topsides", ST)
end
Path("AvenueN", -8, -124, 8, -29); Path("AvenueS", -8, 29, 8, 124); Path("AvenueW", -124, -8, -29, 8); Path("AvenueE", 29, -8, 124, 8)
Path("LoopN", -136, -136, 136, -124, 12); Path("LoopS", -136, 124, 136, 136, 12)
Path("LoopW", -136, -124, -124, 124, 12); Path("LoopE", 124, -124, 136, 124, 12)
Path("SpurPool", 60, -43, 70, -8, 10); Path("SpurPress", -65, -48.5, -55, -8, 10)
Path("SpurTramps", 60, 8, 70, 26, 10); Path("SpurStands", -50, 8, -40, 52, 10)
-- outer ring (map doubled 2026-11-24): avenues run on to an outer loop at +-250 that links the four corner zones
Path("AvenueN2", -8, -244, 8, -136); Path("AvenueS2", -8, 136, 8, 244); Path("AvenueW2", -244, -8, -136, 8); Path("AvenueE2", 136, -8, 244, 8)
Path("LoopN2", -256, -256, 256, -244, 12); Path("LoopS2", -256, 244, 256, 256, 12)
Path("LoopW2", -256, -244, -244, 244, 12); Path("LoopE2", 244, -244, 256, 244, 12)
-- plaza: one cylinder, the painted concentric courses fill its top cap (local +X = Right face)
local P = K.Folder(F, "Plaza")
local Disc = K.VCyl(P, "PlazaDisc", 60.4, 0.6, V(0, -0.09, 0), K.Shade(ST, 0))
K.Tex(Disc, "r_plaza", 60.4, 60.4, { Enum.NormalId.Right }, ST)
K.VCyl(P, "PlazaCurb", 63.2, 0.5, V(0, -0.16, 0), Color3.fromRGB(112, 112, 108))
-- centre planter: stone ring (alternate segment heights 0.06 apart: their tops overlap at the inner corners)
local Ring = K.Ring(P, "Planter", V(0, 1.01, 0), 5.6, 1.4, 1.6, 12, nil, nil, 0.1)
for I, S in Ring:GetChildren() do
	if I % 2 == 0 then S.Size += Vector3.new(0, 0.06, 0); S.CFrame += Vector3.new(0, 0.03, 0) end
	K.Tex(S, "r_stone", 4, 4, "topsides", Color3.new(0.95, 0.95, 0.95))
end
K.VCyl(P, "PlanterSoil", 11.6, 1.2, V(0, 0.9, 0), Color3.fromRGB(128, 172, 60), Enum.Material.Grass)
local Tr = game.ServerStorage.RagdollParkAssets.Forest["Tree 1"]:Clone() -- owner's Enchanted Forest pack tree
local _, S0 = Tr:GetBoundingBox(); Tr:ScaleTo(Tr:GetScale() * 24 / S0.Y); local C, S = Tr:GetBoundingBox() -- pack models carry their own scale (~0.023); ScaleTo is absolute
Tr:PivotTo(Tr:GetPivot() + (V(0, 1.4 + S.Y / 2, 0) - C.Position))
for _, D in Tr:GetDescendants() do if D:IsA("BasePart") then D.Anchored = true; D.CanCollide = false; D.CanQuery = false end end
Tr.Parent = P
return ("paths %d"):format(#F:GetDescendants())
