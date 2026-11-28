--!nocheck
--[[ Z-fight scan (2026-10-10, written for the Port map). Run in the Edit DataModel via execute_luau after a build.
Finds pairs of faces that point the same way, lie (almost) in one plane, overlap, and differ in colour or material:
the pairs that z-fight. Same-colour, same-material pairs are skipped (they flicker invisibly).

Set MapName, O (the map origin, street level) and GAP. Use GAP 0.055 to catch every real problem; the house stand-off
is 0.06, so GAP 0.075 also lists the deliberate 0.06 layers (a sanity check that they are all exactly 0.06).

READING THE RESULT: not every gap-0 pair is visible. These are hidden and fine:
- back faces pressed against a wall (door recesses, window glass and bars, jambs: both faces point INTO the wall)
- bottoms resting on, or buried in, something (container bottoms in a deck plate, quay wall tops under the foundation)
- faces inside another part (ChamferBox cores and chamfers of two overlapping boxes)
Bottoms lying on the ground (Y = O.Y) are skipped automatically. Everything else is a real fight: fix it by giving one
face a stand-off of at least 0.06, then rescan. Screenshots catch gap-0 fights (the old bay walls showed soil patches
through the concrete); 0.03-0.05 gaps flicker mostly at range and in motion, so trust the scan for those.
Faces are boxes, cylinder end caps (as squares 0.84 x the diameter) and wedge bottom/back/slope; curved sides, balls
and CornerWedges are not checked.
]]
local MapName = "PortMap_Claude"
local O = Vector3.new(7400, 150, 0)
local GAP = 0.055

local Map = workspace[MapName]
local Faces = {}
-- D (the plane offset used for bucketing) is measured from the map origin O, not the world origin: at X ~11000 a normal
-- that is off by 1e-4 moves a world-origin offset by ~1 stud. The gap itself is measured with ONE face's plane (below).
local function Add(P, N, C, U, V, HU, HV)
	if N.Y < -0.9 and math.abs(C.Y - O.Y) < 0.15 then return end
	table.insert(Faces, { P = P, N = N, C = C, U = U, V = V, HU = HU, HV = HV, D = N:Dot(C - O) })
end
for _, P in Map:GetDescendants() do
	if P:IsA("BasePart") and P.Transparency < 0.95 then
		local CF, S = P.CFrame, P.Size
		local Pos, R, Up, Bk = CF.Position, CF.RightVector, CF.UpVector, -CF.LookVector
		if P:IsA("Part") and P.Shape == Enum.PartType.Block then
			Add(P, R, Pos + R * S.X / 2, Up, Bk, S.Y / 2, S.Z / 2); Add(P, -R, Pos - R * S.X / 2, Up, Bk, S.Y / 2, S.Z / 2)
			Add(P, Up, Pos + Up * S.Y / 2, R, Bk, S.X / 2, S.Z / 2); Add(P, -Up, Pos - Up * S.Y / 2, R, Bk, S.X / 2, S.Z / 2)
			Add(P, Bk, Pos + Bk * S.Z / 2, R, Up, S.X / 2, S.Y / 2); Add(P, -Bk, Pos - Bk * S.Z / 2, R, Up, S.X / 2, S.Y / 2)
		elseif P:IsA("Part") and P.Shape == Enum.PartType.Cylinder then
			local Dm = math.min(S.Y, S.Z)
			Add(P, R, Pos + R * S.X / 2, Up, Bk, Dm * 0.42, Dm * 0.42); Add(P, -R, Pos - R * S.X / 2, Up, Bk, Dm * 0.42, Dm * 0.42)
		elseif P:IsA("WedgePart") then
			Add(P, -Up, Pos - Up * S.Y / 2, R, Bk, S.X / 2, S.Z / 2)
			Add(P, Bk, Pos + Bk * S.Z / 2, R, Up, S.X / 2, S.Y / 2)
			Add(P, (Up * S.Z - Bk * S.Y).Unit, Pos, R, (Bk * S.Z + Up * S.Y).Unit, S.X / 2, math.sqrt(S.Y ^ 2 + S.Z ^ 2) / 2)
		end
	end
end
-- bucket by normal and plane offset, so only near-coplanar candidates get compared
local Bucket = GAP + 0.005
local Buckets = {}
local function NKey(N) return math.round(N.X * 40) .. "," .. math.round(N.Y * 40) .. "," .. math.round(N.Z * 40) end
for I, F in Faces do
	F.NK = NKey(F.N); F.DB = math.floor(F.D / Bucket)
	local K = F.NK .. "|" .. F.DB
	Buckets[K] = Buckets[K] or {}
	table.insert(Buckets[K], I)
end
-- overlap area of face B with face A, in A's plane (B clipped to A's rectangle)
local function Clip(Poly, Ax, Ay, Lim)
	local Out = {}
	for I = 1, #Poly do
		local A, B = Poly[I], Poly[I % #Poly + 1]
		local Da, Db = Ax * A[1] + Ay * A[2] - Lim, Ax * B[1] + Ay * B[2] - Lim
		if Da <= 0 then table.insert(Out, A) end
		if (Da < 0 and Db > 0) or (Da > 0 and Db < 0) then local T = Da / (Da - Db); table.insert(Out, { A[1] + (B[1] - A[1]) * T, A[2] + (B[2] - A[2]) * T }) end
	end
	return Out
end
local function Overlap(A, B)
	local Poly = {}
	for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local Pt = B.C + B.U * (s[1] * B.HU) + B.V * (s[2] * B.HV) - A.C
		table.insert(Poly, { Pt:Dot(A.U), Pt:Dot(A.V) })
	end
	for _, L in { { 1, 0, A.HU }, { -1, 0, A.HU }, { 0, 1, A.HV }, { 0, -1, A.HV } } do
		Poly = Clip(Poly, L[1], L[2], L[3]); if #Poly < 3 then return 0 end
	end
	local Ar = 0
	for I = 1, #Poly do local P1, P2 = Poly[I], Poly[I % #Poly + 1]; Ar += P1[1] * P2[2] - P2[1] * P1[2] end
	return math.abs(Ar) / 2
end
local function Where(P)
	local Pa = P
	while Pa and Pa.Parent and Pa.Parent.Name ~= "Content" and Pa.Parent ~= Map do Pa = Pa.Parent end
	return (Pa and Pa.Name or "?") .. "/" .. P.Name
end
local function Differ(A, B)
	if A.Material ~= B.Material then return true end
	local Ca, Cb = A.Color, B.Color
	return math.abs(Ca.R - Cb.R) + math.abs(Ca.G - Cb.G) + math.abs(Ca.B - Cb.B) > 0.03
end
local Groups, Total = {}, 0
for I, A in Faces do
	for _, Off in { 0, 1 } do
		local L = Buckets[A.NK .. "|" .. (A.DB + Off)]
		if L then for _, J in L do
			if Off == 1 or J > I then
				local B = Faces[J]
				if B.P ~= A.P and Differ(A.P, B.P) then
					-- distance of B's centre from A's plane (two normals 1e-4 apart turned a real 0.4 gap into "0.04")
					local Gap = math.abs(A.N:Dot(B.C - A.C))
					if Gap < GAP and A.N:Dot(B.N) > 0.9995 then
						local Rr = math.sqrt(A.HU ^ 2 + A.HV ^ 2) + math.sqrt(B.HU ^ 2 + B.HV ^ 2)
						local Dc = (B.C - A.C) - A.N * (B.C - A.C):Dot(A.N)
						if Dc.Magnitude < Rr then
							local Ar = Overlap(A, B)
							if Ar > 0.02 then
								Total += 1
								local Ka, Kb = Where(A.P), Where(B.P)
								if Ka > Kb then Ka, Kb = Kb, Ka end
								local Nd = math.abs(A.N.Y) > 0.9 and (A.N.Y > 0 and "up" or "down") or "side"
								local K = Ka .. " <> " .. Kb .. " [" .. Nd .. "]"
								local G = Groups[K]
								if not G then G = { N = 0, Area = 0, MinGap = 1, MaxGap = 0, Ex = A.C - O }; Groups[K] = G end
								G.N += 1; G.Area += Ar; G.MinGap = math.min(G.MinGap, Gap); G.MaxGap = math.max(G.MaxGap, Gap)
							end
						end
					end
				end
			end
		end end
	end
end
local L = {}
for K, G in Groups do table.insert(L, { K, G }) end
table.sort(L, function(a, b) return a[2].Area > b[2].Area end)
local Out = { ("gap<%.3f pairs=%d groups=%d (folder/part <> folder/part [face], example position relative to O)"):format(GAP, Total, #L) }
for I = 1, math.min(80, #L) do
	local G = L[I][2]
	table.insert(Out, ("%4d x area %7.1f gap %.3f-%.3f  %s  @%.0f,%.2f,%.0f"):format(G.N, G.Area, G.MinGap, G.MaxGap, L[I][1], G.Ex.X, G.Ex.Y, G.Ex.Z))
end
return table.concat(Out, "\n")
