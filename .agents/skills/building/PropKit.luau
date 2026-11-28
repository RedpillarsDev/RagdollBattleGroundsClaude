--!nocheck
--[[ Prop kit (2026-10-18): helpers for small ability props (first used for the C4 concepts), loaded on top of BuildKit:
	local Kit = loadstring(game.ServerStorage.ClaudeBuildKit.Source)()
	local PK = loadstring(game.ServerStorage.ClaudePropKit.Source)()(Kit)
Install it like BuildKit, as ServerStorage.ClaudePropKit (PK.Version must match this file).

An ability prop follows PROD's ExplosiveBarrel contract (ReplicatedStorage.Storage.Models.Ability.BarrelThrow):
a Model whose PrimaryPart is `Center`, a flat `Content` folder of parts each welded to Center, and a black outline
Highlight on the Model. Only Center is anchored, so the prop stands still on display; unanchor Center to throw it.
Every prop's local frame: Y up = away from the surface it sits or sticks on, front = -Z.
Props are seen close, so the map rule "nothing under 0.5 studs" relaxes here, but keep them chunky and use the house
0.06 stand-off for anything stuck on a face.
]]
return function(Kit)
	local PK = { Version = "2026-10-18.1" }

	PK.Palette = {
		Charcoal = Color3.fromRGB(40, 44, 56),
		Navy = Color3.fromRGB(36, 48, 82),
		DeepNavy = Color3.fromRGB(31, 41, 66),
		White = Color3.fromRGB(196, 204, 224), -- structural white (pure white glares under PROD lighting)
		Tile = Color3.fromRGB(174, 184, 204),
		Steel = Color3.fromRGB(150, 158, 176),
		Orange = Color3.fromRGB(240, 138, 60),
		Coral = Color3.fromRGB(226, 86, 72),
		Blue = Color3.fromRGB(41, 169, 240),
		Hazard = Color3.fromRGB(242, 194, 48),
		Ink = Color3.fromRGB(28, 30, 38),
		Screen = Color3.fromRGB(16, 18, 24),
		Glass = Color3.fromRGB(150, 220, 255),
		GlowCyan = Color3.fromRGB(47, 214, 255),
		GlowOrange = Color3.fromRGB(255, 138, 26),
		GlowRed = Color3.fromRGB(255, 64, 48),
		Outline = Color3.fromRGB(20, 22, 30),
	}
	local C = PK.Palette

	-- Starts a prop, replacing any old one of that name. Returns the Model and its Content folder.
	function PK.NewProp(Parent, Name)
		local Old = Parent:FindFirstChild(Name)
		if Old then Old:Destroy() end
		local Mo = Kit.Model(Parent, Name)
		local Content = Instance.new("Folder")
		Content.Name = "Content"
		Content.Parent = Mo
		return Mo, Content
	end

	-- Flattens Content (helper Models such as ChamferBox and RoundedSlab become prefixed parts), welds every part to a
	-- new Center at CenterCF, anchors only Center, and adds the outline Highlight. Returns Center and the part count.
	function PK.FinishProp(Mo, Content, CenterCF)
		local Nested = {}
		for _, D in Content:GetDescendants() do
			if D:IsA("BasePart") and D.Parent ~= Content then table.insert(Nested, D) end
		end
		for _, Pt in Nested do
			Pt.Name = Pt.Parent.Name .. Pt.Name
			Pt.Parent = Content
		end
		for _, D in Content:GetChildren() do
			if D:IsA("Model") then D:Destroy() end
		end
		local Center = Kit.Part(Mo, "Center", Vector3.new(0.5, 0.5, 0.5), CenterCF, C.Steel)
		Center.Transparency = 1
		Center.CanCollide, Center.CanTouch, Center.CanQuery, Center.CastShadow = false, false, false, false
		local N = 0
		for _, Pt in Content:GetChildren() do
			if Pt:IsA("BasePart") then
				local W = Instance.new("WeldConstraint")
				W.Part0, W.Part1 = Center, Pt
				W.Parent = Pt
				Pt.Anchored = false
				N += 1
			end
		end
		Mo.PrimaryPart = Center
		local H = Instance.new("Highlight")
		H.FillTransparency = 1
		H.OutlineColor = C.Outline
		H.OutlineTransparency = 0
		H.DepthMode = Enum.HighlightDepthMode.Occluded
		H.Parent = Mo
		return Center, N
	end

	-- Digits (numbers only, never words) on one face of a part, in the house squared font. Glow = a lit screen.
	-- TextScaled caps at 100 px, so letters reach at most 100 / PixelsPerStud studs tall. Returns the TextLabel "Digits".
	function PK.Digits(Pt, Face, Text, Color, Glow, PixelsPerStud)
		local G = Instance.new("SurfaceGui")
		G.Name = "Display"
		G.Face = Face
		G.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		G.PixelsPerStud = PixelsPerStud or 120
		G.LightInfluence = Glow and 0 or 1
		G.Brightness = Glow and 2 or 1
		G.Parent = Pt
		local L = Instance.new("TextLabel")
		L.Name = "Digits"
		L.Size = UDim2.fromScale(1, 1)
		L.BackgroundTransparency = 1
		L.Text = Text
		L.TextScaled = true
		L.TextColor3 = Color
		L.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy)
		L.Parent = G
		local Pad = Instance.new("UIPadding")
		Pad.PaddingTop, Pad.PaddingBottom = UDim.new(0.08, 0), UDim.new(0.08, 0)
		Pad.Parent = L
		return L
	end

	-- A Neon bulb with a PointLight: the part a script blinks. Name it "Light" on a prop.
	function PK.Bulb(Parent, Name, Diameter, Pos, Color, Range)
		local B = Kit.Detail(Kit.Ball(Parent, Name, Diameter, Pos, Color, Enum.Material.Neon))
		local PL = Instance.new("PointLight")
		PL.Color = Color
		PL.Range = Range or 5
		PL.Brightness = 2
		PL.Shadows = false
		PL.Parent = B
		return B
	end

	-- A solid isosceles triangle, apex up, on a face (warning-triangle emblems). FCF looks out of the face
	-- (Kit.FaceCF); Along/Up place its centre, it stands Lift off the face and is T thick. Two WedgeParts.
	function PK.Triangle(Parent, Name, FCF, Along, Up, Base, Height, T, Lift, Color)
		local U, V, N = FCF.RightVector, FCF.UpVector, FCF.LookVector
		local Mid = FCF.Position + U * Along + V * Up + N * (Lift + T / 2)
		local Size = Vector3.new(T, Height, Base / 2)
		-- a wedge is tallest at local +Z: each half has its tall side on the centre line
		local A = Kit.Part(Parent, Name, Size, CFrame.fromMatrix(Mid + U * Base / 4, -N, V, -U), Color, nil, "WedgePart")
		local B = Kit.Part(Parent, Name, Size, CFrame.fromMatrix(Mid - U * Base / 4, N, V, U), Color, nil, "WedgePart")
		return A, B
	end

	return PK
end
