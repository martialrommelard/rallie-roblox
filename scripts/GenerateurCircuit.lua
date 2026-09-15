-- ============================================================
--  GENERATEUR DE CIRCUIT - RALLY MONTAGNE
--  A coller dans la barre de commande de Studio (View > Command Bar)
--
--  Pour changer le trace : modifier la liste POINTS, puis relancer.
--  Chaque point = { x, z, hauteur, largeur, [type] }
--     x, z     = position sur la carte (vue du dessus)
--     hauteur  = 0 en bas, 70 au sommet de la montagne
--     largeur  = 40 (serre) a 80 (zone de depassement)
--     type     = "tunnel" (murs + plafond) ou "tremplin" (rampe de saut)
--
--  REGLE : points SERRES = virage lent.  Points ECARTES = courbe rapide.
-- ============================================================

local WS = game:GetService("Workspace")
local EPAISSEUR, PAS, ECHELLE = 2, 18, 0.85

local POINTS = {
	{ -380, 480,  0, 60},            -- 1  DEPART / GRANDE LIGNE DROITE
	{ -130, 478,  0, 60},            -- 2
	{  110, 476,  0, 60},            -- 3
	{  310, 468,  0, 80},            -- 4  ZONE DE DEPASSEMENT / gros freinage
	{  430, 440,  3, 46},            -- 5  entree de l'epingle
	{  510, 370,  9, 42},            -- 6  EPINGLE
	{  505, 290, 16, 42},            -- 7  apex
	{  430, 240, 23, 46},            -- 8  sortie, ca monte
	{  330, 195, 29, 48},            -- 9  MONTEE
	{  300,  95, 36, 48},            -- 10 courbe rapide en montee
	{  350,   5, 43, 46},            -- 11
	{  430, -65, 49, 44},            -- 12
	{  420,-165, 55, 44},            -- 13 LACET
	{  330,-220, 60, 44},            -- 14
	{  210,-215, 65, 46},            -- 15 approche du tunnel
	{   90,-230, 70, 44, "tunnel"},  -- 16 ENTREE DU TUNNEL
	{  -40,-235, 70, 44, "tunnel"},  -- 17 DANS LA MONTAGNE
	{ -170,-215, 70, 44},            -- 18 SORTIE DU TUNNEL
	{ -290,-170, 66, 48},            -- 19 debut de la descente
	{ -380,-100, 60, 50},            -- 20 descente rapide
	{ -430,  -5, 54, 50},            -- 21
	{ -450,  85, 52, 48},            -- 22 approche du tremplin
	{ -455, 150, 54, 50, "tremplin"},-- 23 LEVRE : la rampe est posee ici
	{ -450, 195, 40, 70},            -- 24 RECEPTION (large, la pente plonge)
	{ -455, 250, 26, 60},            -- 25
	{ -500, 300, 14, 54},            -- 26
	{ -580, 330,  4, 50},            -- 27
	{ -670, 345,  0, 48},            -- 28 DERNIER VIRAGE (large)
	{ -740, 400,  0, 48},            -- 29
	{ -750, 470,  0, 48},            -- 30
	{ -700, 525,  0, 52},            -- 31
	{ -610, 545,  0, 56},            -- 32
	{ -500, 520,  0, 58},            -- 33 retour sur la ligne droite
}

for _, p in ipairs(POINTS) do
	p[1] = p[1] * ECHELLE; p[2] = p[2] * ECHELLE; p[3] = p[3] * ECHELLE
end

local old = WS:FindFirstChild("Circuit")
if old then old:Destroy() end
local circuit = Instance.new("Folder"); circuit.Name = "Circuit"; circuit.Parent = WS
local function dossier(nom)
	local f = Instance.new("Folder"); f.Name = nom; f.Parent = circuit; return f
end
local fRoute, fBar, fTalus = dossier("Route"), dossier("Barrieres"), dossier("Talus")
local fTunnel, fDecor = dossier("Tunnel"), dossier("Decor")

-- SPLINE DE CATMULL-ROM CENTRIPETE (alpha = 0.5)
-- Passe exactement par chaque point de controle, et ne peut pas
-- boucler sur elle-meme meme si les points sont mal espaces.
local function dist3(a, b)
	local dx, dz, dy = b[1]-a[1], b[2]-a[2], b[3]-a[3]
	return math.sqrt(dx*dx + dz*dz + dy*dy)
end
local function spline(p0, p1, p2, p3, s)
	local t0 = 0
	local t1 = t0 + math.max(dist3(p0, p1), 0.001) ^ 0.5
	local t2 = t1 + math.max(dist3(p1, p2), 0.001) ^ 0.5
	local t3 = t2 + math.max(dist3(p2, p3), 0.001) ^ 0.5
	local t = t1 + (t2 - t1) * s
	local out = {}
	for k = 1, 4 do
		local A1 = (t1-t)/(t1-t0)*p0[k] + (t-t0)/(t1-t0)*p1[k]
		local A2 = (t2-t)/(t2-t1)*p1[k] + (t-t1)/(t2-t1)*p2[k]
		local A3 = (t3-t)/(t3-t2)*p2[k] + (t-t2)/(t3-t2)*p3[k]
		local B1 = (t2-t)/(t2-t0)*A1 + (t-t0)/(t2-t0)*A2
		local B2 = (t3-t)/(t3-t1)*A2 + (t-t1)/(t3-t1)*A3
		out[k] = (t2-t)/(t2-t1)*B1 + (t-t1)/(t2-t1)*B2
	end
	return out
end

local n = #POINTS
local P = {}
for i = 1, n do
	local p0 = POINTS[((i - 2) % n) + 1]
	local p1 = POINTS[i]
	local p2 = POINTS[(i % n) + 1]
	local p3 = POINTS[((i + 1) % n) + 1]
	local d = math.sqrt((p2[1]-p1[1])^2 + (p2[2]-p1[2])^2)
	local pas = math.max(2, math.ceil(d / PAS))
	for s = 0, pas - 1 do
		local q = spline(p0, p1, p2, p3, s / pas)
		q[4] = math.clamp(q[4], 36, 84)
		q[5] = p1[5]
		P[#P + 1] = q
	end
end
local N = #P

-- BORDS DE ROUTE : une ligne decalee a gauche et une a droite.
-- Les barrieres suivent CES lignes -> plus aucun trou dans les virages.
local G, D = {}, {}
for i = 1, N do
	local a, b = P[i], P[(i % N) + 1]
	local dx, dz = b[1]-a[1], b[2]-a[2]
	local m = math.sqrt(dx*dx + dz*dz); if m < 0.001 then m = 1 end
	local px, pz = -dz/m, dx/m
	local off = a[4]/2 + 1
	G[i] = Vector3.new(a[1] + px*off, a[3] + 4, a[2] + pz*off)
	D[i] = Vector3.new(a[1] - px*off, a[3] + 4, a[2] - pz*off)
end

local function bloc(parent, nom, taille, cf, mat, couleur)
	local p = Instance.new("Part")
	p.Name = nom; p.Anchored = true; p.Size = taille; p.CFrame = cf
	p.Material = mat; p.Color = couleur
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local ROCHE = Color3.fromRGB(102, 97, 90)
local rng = Random.new(12)
local longueur, penteMax, penteOu, rayonMin, iMin, hMax = 0, 0, 1, 99999, 1, 0
local cfLevre, largLevre = nil, 50

for i = 1, N do
	local a = P[i]
	local suivant = (i % N) + 1
	local b, c = P[suivant], P[((i + 1) % N) + 1]
	local pa = Vector3.new(a[1], a[3], a[2])
	local pb = Vector3.new(b[1], b[3], b[2])
	local d = (pb - pa).Magnitude
	if a[3] > hMax then hMax = a[3] end

	if d > 0.01 then
		local tunnel = (a[5] == "tunnel")
		longueur += d
		local horiz = math.sqrt((b[1]-a[1])^2 + (b[2]-a[2])^2)
		if horiz > 0.01 then
			local pente = math.abs(b[3]-a[3]) / horiz
			if pente > penteMax then penteMax = pente; penteOu = i end
		end
		local v1x, v1z = b[1]-a[1], b[2]-a[2]
		local v2x, v2z = c[1]-b[1], c[2]-b[2]
		local n1 = math.sqrt(v1x*v1x + v1z*v1z)
		local n2 = math.sqrt(v2x*v2x + v2z*v2z)
		if n1 > 0.01 and n2 > 0.01 then
			local cosA = math.clamp((v1x*v2x + v1z*v2z) / (n1*n2), -1, 1)
			local ang = math.acos(cosA)
			if ang > 0.02 then
				local r = n1 / ang
				if r < rayonMin then rayonMin = r; iMin = i end
			end
		end

		local larg = (a[4] + b[4]) / 2
		local cfBrut = CFrame.lookAt((pa + pb) / 2, pb)
		-- ANTI Z-FIGHTING : une route sur deux est descendue de 0.04 stud.
		-- Les surfaces ne sont plus confondues -> plus de faux "trous".
		local cf = cfBrut * CFrame.new(0, ((i % 2 == 0) and 0 or -0.04), 0)

		if a[5] == "tremplin" then cfLevre = cfBrut; largLevre = larg end

		bloc(fRoute, "Route"..i, Vector3.new(larg, EPAISSEUR, d*1.4), cf,
			Enum.Material.Asphalt, Color3.fromRGB(62, 62, 66))

		-- TALUS : suit exactement la pente de la route
		if a[3] > 3 then
			local H = a[3] + 24
			bloc(fTalus, "Talus", Vector3.new(larg + 16, H, d*1.4),
				cfBrut * CFrame.new(0, -H/2 - 0.5, 0),
				Enum.Material.Rock, Color3.fromRGB(94, 86, 72))
		end

		if not tunnel then
			for _, cote in ipairs({G, D}) do
				local p1, p2 = cote[i], cote[suivant]
				local lb = (p2 - p1).Magnitude
				if lb > 0.01 then
					bloc(fBar, "Barriere", Vector3.new(2, 6, lb * 1.25),
						CFrame.lookAt((p1+p2)/2, p2), Enum.Material.Metal,
						((i % 10) < 5) and Color3.fromRGB(200,40,40) or Color3.fromRGB(235,235,235))
				end
			end
		else
			for _, cote in ipairs({G, D}) do
				local p1, p2 = cote[i], cote[suivant]
				local lb = (p2 - p1).Magnitude
				if lb > 0.01 then
					bloc(fTunnel, "Mur", Vector3.new(4, 22, lb * 1.25),
						CFrame.lookAt((p1+p2)/2, p2) * CFrame.new(0, 7, 0),
						Enum.Material.Slate, ROCHE)
				end
			end
			bloc(fTunnel, "Plafond", Vector3.new(larg + 12, 4, d*1.4),
				cfBrut * CFrame.new(0, 22, 0), Enum.Material.Slate, ROCHE)
		end

		-- ROCHERS : le degagement tient compte de la ROTATION du bloc,
		-- sinon un coin repart vers la route quand on le fait pivoter.
		if (tunnel or (a[3] > 38 and (i % 5) == 0)) and (i % 3) == 0 then
			for _, s in ipairs({-1, 1}) do
				local w    = rng:NextNumber(70, 130)
				local prof = rng:NextNumber(70, 140)
				local ang  = math.rad(rng:NextNumber(-25, 25))
				local H    = a[3] + rng:NextNumber(30, 70)
				local demi = (w/2)*math.abs(math.cos(ang)) + (prof/2)*math.abs(math.sin(ang))
				local off  = larg/2 + demi + rng:NextNumber(14, 34)
				bloc(fDecor, "Rocher", Vector3.new(w, H, prof),
					cfBrut * CFrame.new(s * off, 0, 0) * CFrame.Angles(0, ang, 0)
					       * CFrame.new(0, H/2 - a[3] - 14, 0),
					Enum.Material.Rock, ROCHE)
			end
		end
		if tunnel and (i % 5) == 0 then
			bloc(fDecor, "Sommet", Vector3.new(larg + 200, 44, d*6),
				cfBrut * CFrame.new(0, 46, 0), Enum.Material.Rock, ROCHE)
		end
	end
end

-- LA RAMPE DU TREMPLIN : 12 degres vers le haut, posee sur la route.
-- C'est elle qui donne la vitesse verticale ; la pente a 35% juste
-- derriere se derobe sous la voiture et donne la hauteur du saut.
-- La route reste CONTINUE : en arrivant doucement on descend, sans tomber.
if cfLevre then
	bloc(circuit, "Tremplin", Vector3.new(largLevre, 3, 36),
		cfLevre * CFrame.new(0, 0, -18) * CFrame.Angles(math.rad(12), 0, 0)
		        * CFrame.new(0, 2.5, 0),
		Enum.Material.Concrete, Color3.fromRGB(120, 112, 96))
end

-- ARBRES sur les parties basses
for i = 1, N, 4 do
	local a = P[i]
	if a[3] < 16 and a[5] == nil then
		for _ = 1, 2 do
			local cote = (rng:NextInteger(0,1) == 0) and G[i] or D[i]
			local dir = (cote - Vector3.new(a[1], a[3]+4, a[2]))
			if dir.Magnitude > 0.01 then
				dir = dir.Unit
				local dd = rng:NextNumber(45, 130)
				local x, z = a[1] + dir.X*dd, a[2] + dir.Z*dd
				local h = rng:NextNumber(18, 32)
				bloc(fDecor, "Tronc", Vector3.new(4, h, 4),
					CFrame.new(x, h/2 - 1, z), Enum.Material.Wood, Color3.fromRGB(86, 62, 42))
				local f = Instance.new("Part")
				f.Name = "Feuillage"; f.Anchored = true; f.Shape = Enum.PartType.Ball
				f.Size = Vector3.new(h*0.9, h*0.9, h*0.9)
				f.CFrame = CFrame.new(x, h + h*0.25, z)
				f.Material = Enum.Material.Grass
				f.Color = Color3.fromRGB(46, 96, 52)
				f.Parent = fDecor
			end
		end
	end
end

local bp = WS:FindFirstChild("Baseplate")
if bp then
	bp.Locked = false; bp.Anchored = true
	bp.Size = Vector3.new(2300, 24, 2300)
	bp.Position = Vector3.new(-100, -26, 130)
	bp.Material = Enum.Material.Grass
	bp.Color = Color3.fromRGB(76, 112, 62)
	local tex = bp:FindFirstChildOfClass("Texture")
	if tex then tex:Destroy() end
end

local ligne = Instance.new("Part")
ligne.Name = "LigneDepart"; ligne.Anchored = true
ligne.Size = Vector3.new(62, 0.4, 8)
ligne.CFrame = CFrame.lookAt(Vector3.new(-230*ECHELLE, 1.3, 479*ECHELLE),
	Vector3.new(0, 1.3, 477*ECHELLE))
ligne.Material = Enum.Material.SmoothPlastic
ligne.Color = Color3.fromRGB(245, 245, 245)
ligne.Parent = circuit

local sp = WS:FindFirstChild("SpawnLocation")
if sp then
	sp.Anchored = true
	sp.CFrame = CFrame.lookAt(Vector3.new(-310*ECHELLE, 3, 479*ECHELLE),
		Vector3.new(0, 3, 477*ECHELLE))
end

-- VERIFICATION AUTOMATIQUE : on teste chaque morceau de route et on
-- pousse dehors tout rocher qui empiete sur le couloir de roulage.
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {fDecor}
params.MaxParts = 30

local sonde = Instance.new("Part")
sonde.Anchored = true; sonde.CanCollide = false; sonde.Transparency = 1
sonde.Parent = WS

local pousses = 0
for _ = 1, 4 do
	for _, r in ipairs(fRoute:GetChildren()) do
		sonde.Size = Vector3.new(r.Size.X + 8, 20, r.Size.Z)
		sonde.CFrame = r.CFrame * CFrame.new(0, 12, 0)
		for _, p in ipairs(WS:GetPartsInPart(sonde, params)) do
			if p.Name == "Rocher" then
				local rel = r.CFrame:PointToObjectSpace(p.Position)
				local s = (rel.X >= 0) and 1 or -1
				p.CFrame = p.CFrame + r.CFrame.RightVector * (s * 22)
				pousses += 1
			end
		end
	end
end
sonde:Destroy()

local pm, pp = P[iMin], P[penteOu]
return string.format(
	"RALLY MONTAGNE | %d segments | tour = %d studs (~%d s) | pente max %.1f%% (x=%d z=%d) | rayon mini %d studs (x=%d z=%d) | sommet %d studs | %d rochers repousses",
	#fRoute:GetChildren(), math.floor(longueur), math.floor(longueur/70),
	penteMax*100, math.floor(pp[1]), math.floor(pp[2]),
	math.floor(rayonMin), math.floor(pm[1]), math.floor(pm[2]), math.floor(hMax), pousses)
