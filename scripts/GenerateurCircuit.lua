-- ============================================================
--  GENERATEUR DE CIRCUIT - RALLY MONTAGNE
--  A coller dans la barre de commande de Studio (View > Command Bar)
--
--  Le circuit n'est PAS construit a la main. Il est calcule a partir
--  de la liste POINTS ci-dessous. Changer un nombre = nouveau trace.
--
--  Chaque point = { x, z, hauteur, largeur, [type] }
--     x, z     = position sur la carte (vue du dessus)
--     hauteur  = 0 dans la vallee, 70 au sommet de la montagne
--     largeur  = 40 (virage serre) a 80 (zone de depassement)
--     type     = "tunnel" ou "tremplin" (facultatif)
--
--  REGLE : points SERRES = virage lent.  Points ECARTES = courbe rapide.
-- ============================================================

local WS = game:GetService("Workspace")
local EPAISSEUR, PAS, ECHELLE = 2, 18, 0.85
local ANGLE_RAMPE, RAMPE_ENTERREE, RAMPE_DEVANT = 15, 14, 34
local SOL_SURFACE, SOL_EP = -1.5, 24   -- surface de l herbe, calee sous le bitume

local POINTS = {
	{ -380, 490,  0, 60},            -- 1  DEPART / GRANDE LIGNE DROITE
	{ -130, 478,  0, 60},            -- 2
	{  110, 476,  0, 60},            -- 3
	{  310, 468,  0, 80},            -- 4  ZONE DE DEPASSEMENT / gros freinage
	{  430, 440,  3, 62},            -- 5  entree de l'epingle
	{  510, 370,  9, 56},            -- 6  EPINGLE
	{  505, 290, 16, 56},            -- 7  apex
	{  430, 240, 23, 62},            -- 8  sortie, ca monte
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
	{ -445,  -5, 54, 56},            -- 21 on redresse : le couloir du
	{ -452,  85, 52, 64},            -- 22 saut (21 a 25) est DROIT,
	{ -452, 150, 54, 72, "tremplin"},-- 23 sinon la spline tourne pendant
	{ -452, 232, 24, 72},            -- 24 le vol et on retombe a cote
	{ -452, 290, 14, 60},            -- 25 de la piste (7 studs d ecart)
	{ -500, 350,  6, 54},            -- 26
	{ -580, 375,  0, 50},            -- 27
	{ -670, 385,  0, 48},            -- 28 DERNIER VIRAGE
	{ -740, 430,  0, 48},            -- 29
	{ -750, 495,  0, 48},            -- 30
	{ -700, 545,  0, 52},            -- 31
	{ -610, 560,  0, 56},            -- 32
	{ -500, 535,  0, 58},            -- 33
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

-- ============================================================
--  SPLINE DE CATMULL-ROM CENTRIPETE (alpha = 0.5)
--  Transforme les 33 points de controle en une courbe lisse.
--  "Centripete" : la seule variante qui ne peut PAS boucler sur
--  elle-meme quand les points sont irregulierement espaces.
-- ============================================================
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

-- bords gauche et droit de la route (servent au tunnel)
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
local segments = {}
local derniereRoute = nil

-- ============================================================
--  ROUTE, TALUS, TUNNEL, ROCHERS
-- ============================================================
for i = 1, N do
	local a = P[i]
	local suivant = (i % N) + 1
	local b, c2 = P[suivant], P[((i + 1) % N) + 1]
	local pa = Vector3.new(a[1], a[3], a[2])
	local pb = Vector3.new(b[1], b[3], b[2])
	local d = (pb - pa).Magnitude
	if a[3] > hMax then hMax = a[3] end

	if d > 0.01 then
		local tunnel = (a[5] == "tunnel")
		local vide   = (a[5] == "tremplin")   -- le trou du saut
		local videSuivant = (b[5] == "tremplin")

		if not vide then
			longueur += d
			local horiz = math.sqrt((b[1]-a[1])^2 + (b[2]-a[2])^2)
			if horiz > 0.01 then
				local pente = math.abs(b[3]-a[3]) / horiz
				if pente > penteMax then penteMax = pente; penteOu = i end
			end
			local v1x, v1z = b[1]-a[1], b[2]-a[2]
			local v2x, v2z = c2[1]-b[1], c2[2]-b[2]
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
		end

		local larg = (a[4] + b[4]) / 2
		local cfBrut = CFrame.lookAt((pa + pb) / 2, pb)
		-- ANTI Z-FIGHTING : une route sur deux est descendue de 0.04 stud.
		-- Sans ca, deux surfaces exactement a la meme hauteur clignotent
		-- et donnent l'illusion de trous dans le bitume.
		local cf = cfBrut * CFrame.new(0, ((i % 2 == 0) and 0 or -0.04), 0)

		if not vide then
			local rt = bloc(fRoute, "Route"..i, Vector3.new(larg, EPAISSEUR, d*1.4), cf,
				Enum.Material.Asphalt, Color3.fromRGB(62, 62, 66))
			table.insert(segments, {p = rt, tunnel = tunnel})
			if videSuivant then derniereRoute = rt end
			-- talus : suit exactement la pente de la route
			if a[3] > 3 then
				local H = a[3] + 26
				bloc(fTalus, "Talus", Vector3.new(larg + 6, H, d*1.4),
					cfBrut * CFrame.new(0, -H/2 - 0.5, 0),
					Enum.Material.Rock, Color3.fromRGB(94, 86, 72))
			end
		end

		if tunnel and not videSuivant then
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
		-- sinon un coin revient sur la route quand on le fait pivoter.
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

-- ============================================================
--  BARRIERES EN CHAINE
--  Chaque barriere relie le bord d'une route au bord de la SUIVANTE.
--  C'est une chaine continue : plus de trou dans les virages, et
--  plus de bout qui depasse dans le vide.
-- ============================================================
local poses, ouverts = 0, 0
for k = 1, #segments do
	local A1 = segments[k]
	local B1 = segments[(k % #segments) + 1]
	local ecart = (B1.p.Position - A1.p.Position).Magnitude
	if ecart < 45 and not A1.tunnel and not B1.tunnel then
		for _, s in ipairs({-1, 1}) do
			local p1 = (A1.p.CFrame * CFrame.new(s * (A1.p.Size.X/2 + 1), 4, 0)).Position
			local p2 = (B1.p.CFrame * CFrame.new(s * (B1.p.Size.X/2 + 1), 4, 0)).Position
			local L = (p2 - p1).Magnitude
			if L > 0.5 then
				bloc(fBar, "Barriere", Vector3.new(2, 6, L * 1.3),
					CFrame.lookAt((p1 + p2)/2, p2), Enum.Material.Metal,
					((k % 10) < 5) and Color3.fromRGB(200,40,40) or Color3.fromRGB(235,235,235))
				poses += 1
			end
		end
	else
		ouverts += 1   -- le tunnel et le trou du tremplin restent ouverts
	end
end

-- ============================================================
--  LE TREMPLIN
--  L'angle est ABSOLU (par rapport a l'horizontale), pas relatif a
--  la route : sinon la pente du terrain s'ajoute et on obtient une
--  marche dans laquelle la voiture s'ecrase.
--  La rampe est enterree de 14 studs sous le bitume -> aucune marche.
--
--  La rampe emprunte la largeur de la RECEPTION (et non celle de la
--  route d'avant) et elle est recentree sur elle : sinon on decolle
--  d'une rampe de 49 studs pour retomber sur une piste de 71, decalee
--  de 7 studs sur le cote.
-- ============================================================
local trou, chute, vmin, nPiques = 0, 0, 0, 0
if derniereRoute then
	local lv = derniereRoute.CFrame.LookVector
	local dirH = Vector3.new(lv.X, 0, lv.Z).Unit
	local lat = Vector3.new(-dirH.Z, 0, dirH.X)
	local S = (derniereRoute.CFrame * CFrame.new(0, derniereRoute.Size.Y/2, -derniereRoute.Size.Z/2)).Position
	local A = math.rad(ANGLE_RAMPE)
	local u   = (dirH * math.cos(A) + Vector3.new(0,1,0) * math.sin(A)).Unit
	local nrm = (Vector3.new(0,1,0) * math.cos(A) - dirH * math.sin(A)).Unit
	local L = RAMPE_ENTERREE + RAMPE_DEVANT
	local lip = S + u * RAMPE_DEVANT

	-- On cherche la RECEPTION AVANT de construire, pour lui emprunter sa
	-- largeur.  Le filtre lateral (< 80) est indispensable : sans lui on
	-- attrape un morceau de piste situe a l'autre bout de la carte.
	local meil, dmin = nil, 1e9
	for _, p in ipairs(fRoute:GetChildren()) do
		local rel = p.Position - lip
		local av = rel:Dot(dirH)
		if av > 0 and math.abs(rel:Dot(lat)) < 80 and math.abs(rel.Y) < 90 and av < dmin then
			dmin = av; meil = p
		end
	end

	local larg  = meil and meil.Size.X or derniereRoute.Size.X
	local decal = meil and (meil.Position - lip):Dot(lat) or 0
	lip = lip + lat * decal
	local centre = ((S - u*RAMPE_ENTERREE) + (S + u*RAMPE_DEVANT))/2
	             - nrm * (EPAISSEUR/2 + 0.5) + lat * decal

	local function rampePart(nom, taille, pos, couleur, mat)
		local p = Instance.new("Part")
		p.Name = nom; p.Anchored = true; p.Size = taille
		p.CFrame = CFrame.lookAt(pos, pos + u)
		p.Material = mat; p.Color = couleur
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = circuit
	end
	rampePart("Tremplin", Vector3.new(larg, 3, L), centre,
		Color3.fromRGB(128, 120, 104), Enum.Material.Concrete)
	for _, s in ipairs({-1, 1}) do
		rampePart("MarqueTremplin", Vector3.new(6, 3.3, L),
			centre + lat * (s * (larg/2 - 4)),
			Color3.fromRGB(230, 190, 40), Enum.Material.SmoothPlastic)
	end

	-- pilier de roche sous la partie en porte-a-faux
	local RECUL, PROF = 17, 36
	local mid = lip - dirH * RECUL
	local dessous = lip.Y - RECUL * math.tan(A) - 3 / math.cos(A)
	local haut, bas = dessous - 1, -22
	bloc(fDecor, "PilierTremplin", Vector3.new(larg + 4, haut - bas, PROF),
		CFrame.lookAt(Vector3.new(mid.X, (haut + bas)/2, mid.Z),
			Vector3.new(mid.X, (haut + bas)/2, mid.Z) + dirH),
		Enum.Material.Rock, ROCHE)

	-- calcul balistique : quelle vitesse faut-il pour franchir le trou ?
	if meil then
		trou = dmin - meil.Size.Z * 0.5
		chute = lip.Y - (meil.Position.Y + 1)
		local g = WS.Gravity
		for v = 10, 250, 1 do
			local vx, vy = v*math.cos(A), v*math.sin(A)
			if vx * (vy + math.sqrt(vy*vy + 2*g*chute)) / g >= trou then vmin = v; break end
		end

		-- --------------------------------------------------------
		--  LES PIQUES AU FOND DU TROU
		--  Une pique = 4 CornerWedgePart (voir plus bas).  Surtout PAS de
		--  SpecialMesh "Pyramid" : ce type n'est plus affiche par
		--  Roblox et la Part devient carrement invisible.
		--  CanCollide = false : c'est le script ServerScriptService.
		--  Piques qui tue, pas la collision -- sinon la voiture
		--  rebondit sur les pointes au lieu de mourir.
		-- --------------------------------------------------------
		local fPiques = dossier("Piques")
		local bordRecep = meil.Position - dirH * (meil.Size.Z/2)
		local zFin = (bordRecep - lip):Dot(dirH) - 4
		local BASE, ESPACE = 6, 9
		local rp = Random.new(7)
		local nCols  = math.max(1, math.floor((larg - 8) / ESPACE))
		local nRangs = math.max(1, math.floor((zFin - 4) / ESPACE))
		for i = 0, nRangs do
			for j = 0, nCols do
				local av = 4 + i * ESPACE
				if av <= zFin then
					local h = rp:NextNumber(16, 24)
					local pied = Vector3.new(lip.X, SOL_SURFACE - 1, lip.Z)
					           + dirH * av + lat * (-(larg - 8)/2 + j * ESPACE)
					-- Une pique = 4 CornerWedgePart, un par quart de tour.
					-- Leurs quatre sommets se rejoignent au centre : ca fait
					-- une pyramide a pointe unique.
					-- NE PAS essayer avec deux WedgePart croises a 90 deg :
					-- les deux volumes s ADDITIONNENT au lieu de se couper, on
					-- obtient une colonne carree au lieu d une pointe.
					local socle = CFrame.new(pied)
					for _, ang in ipairs({0, 90, 180, 270}) do
						local c = Instance.new("CornerWedgePart")
						c.Name = "Pique"; c.Anchored = true
						c.CanCollide = false; c.CanTouch = true
						c.Size = Vector3.new(BASE/2, h, BASE/2)
						c.CFrame = socle * CFrame.Angles(0, math.rad(ang), 0)
						         * CFrame.new(BASE/4, h/2, BASE/4)
						c.Material = Enum.Material.Metal
						c.Color = Color3.fromRGB(118, 122, 128)
						c.Parent = fPiques
					end


					nPiques += 1
				end
			end
		end
		-- on retire celles qui finissent dans un talus ou dans la roche
		local opP = OverlapParams.new()
		opP.FilterType = Enum.RaycastFilterType.Exclude
		opP.FilterDescendantsInstances = {fPiques, WS:FindFirstChild("Baseplate")}
		for _, p in ipairs(fPiques:GetChildren()) do
			if #WS:GetPartsInPart(p, opP) > 0 then p:Destroy() end
		end

		-- --------------------------------------------------------
		--  LA ZONE DE MORT  (creee APRES le nettoyage ci-dessus,
		--  sinon elle serait supprimee : elle touche les talus)
		--  Les piques seules ne tuent pas : espacees de 9 studs et
		--  traversables (CanCollide = false), on tombe ENTRE deux
		--  pointes sans rien toucher.  Cette boite invisible remplit
		--  tout le fond du trou.
		--  Elle est BASSE expres (20 studs) : plus haute, elle tuerait
		--  un joueur qui reussit le saut et frole le bord de la piste.
		--  C est le script Piques qui la surveille, a chaque image
		--  (Heartbeat) et pas avec Touched -- voir le script.
		-- --------------------------------------------------------
		local HAUT_ZONE = 20
		local profZ = dmin - meil.Size.Z/2 - 2
		local cz = Vector3.new(lip.X, SOL_SURFACE + HAUT_ZONE/2 - 1, lip.Z)
		         + dirH * (profZ/2 + 1)
		local zone = Instance.new("Part")
		zone.Name = "ZoneDeMort"
		zone.Anchored = true
		zone.CanCollide = false
		zone.CanTouch = true
		zone.Transparency = 1
		zone.Size = Vector3.new(larg + 10, HAUT_ZONE, profZ)
		zone.CFrame = CFrame.lookAt(cz, cz + dirH)
		zone.Parent = fPiques

	end
end

-- ============================================================
--  ARBRES sur les parties basses
-- ============================================================
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

-- ============================================================
--  LA MONTAGNE
--  Avant, le "sommet" n etait que 3 gros paves poses au dessus du
--  tunnel : la montagne n avait aucun volume.  Ici on la construit
--  vraiment, en remplissant une grille de COLONNES de roche, hautes
--  au centre et basses sur les bords.
--
--  Trois regles, apprises a la dure :
--   * une colonne qui traverse le TUNNEL repart au dessus de son
--     plafond -- sinon on bouche le tunnel.
--   * une colonne qui touche la PISTE est supprimee -- la route doit
--     rester a ciel ouvert.
--   * la neige est une piece SEPAREE posee sur la colonne, sinon la
--     colonne entiere devient blanche du sol au sommet et on obtient
--     des cubes de glace geants.
-- ============================================================
local fMont = dossier("Montagne")

-- centre et plafond du tunnel : la montagne se batit autour
local mx, mz, nT, plafondT = 0, 0, 0, 0
for _, p in ipairs(fTunnel:GetChildren()) do
	mx += p.Position.X; mz += p.Position.Z; nT += 1
	plafondT = math.max(plafondT, p.Position.Y + p.Size.Y/2)
end
local MONT_X, MONT_Z = mx / math.max(nT, 1), mz / math.max(nT, 1)
local PLAFOND_T = plafondT + 2

local M_RAYON, M_HAUT, M_MAILLE = 370, 640, 40
local M_MINI  = 32          -- en dessous : rien (evite les dalles plates)
local M_NEIGE = 262         -- la neige commence au niveau de la terrasse
local BLANC   = Color3.fromRGB(230, 236, 242)
local rngM = Random.new(3)

for gx = -M_RAYON, M_RAYON, M_MAILLE do
	for gz = -M_RAYON, M_RAYON, M_MAILLE do
		local d = math.sqrt(gx*gx + gz*gz)
		if d < M_RAYON then
			local t = 1 - d / M_RAYON
			local h = M_HAUT * (t ^ 1.25) * rngM:NextNumber(0.95, 1.05)
			if h >= M_MINI then
				bloc(fMont, "Montagne", Vector3.new(M_MAILLE + 2, h - SOL_SURFACE, M_MAILLE + 2),
					CFrame.new(MONT_X + gx, SOL_SURFACE + (h - SOL_SURFACE)/2, MONT_Z + gz),
					Enum.Material.Rock, ROCHE)
			end
		end
	end
end

-- les colonnes qui traversent le tunnel repartent au dessus du plafond
local opTun = OverlapParams.new()
opTun.FilterType = Enum.RaycastFilterType.Include
opTun.FilterDescendantsInstances = {fTunnel}
for _, p in ipairs(fMont:GetChildren()) do
	if #WS:GetPartsInPart(p, opTun) > 0 then
		local haut = p.Position.Y + p.Size.Y/2
		if haut > PLAFOND_T + 12 then
			local nh = haut - PLAFOND_T
			p.Size = Vector3.new(p.Size.X, nh, p.Size.Z)
			p.Position = Vector3.new(p.Position.X, PLAFOND_T + nh/2, p.Position.Z)
		else
			p:Destroy()
		end
	end
end

-- celles qui tombent sur la piste sont supprimees
local opPiste = OverlapParams.new()
opPiste.FilterType = Enum.RaycastFilterType.Include
opPiste.FilterDescendantsInstances = {fRoute, fBar, fTalus, circuit:FindFirstChild("Piques")}
local montSurPiste = 0
for _, p in ipairs(fMont:GetChildren()) do
	if #WS:GetPartsInPart(p, opPiste) > 0 then p:Destroy(); montSurPiste += 1 end
end

-- ------------------------------------------------------------
--  LA TERRASSE DU PODIUM, taillee a mi-pente
--  cote ligne de depart.  On RASE ce qui depasse et on RALLONGE
--  ce qui est trop court : ne faire que raser laisse des creux
--  sous la dalle.
-- ------------------------------------------------------------
local TERR_X, TERR_Z = MONT_X + 6, MONT_Z + 183
local TERR_Y, TERR_R = 260, 112
for _, p in ipairs(fMont:GetChildren()) do
	local dx, dz = p.Position.X - TERR_X, p.Position.Z - TERR_Z
	if math.sqrt(dx*dx + dz*dz) < TERR_R then
		local bas = p.Position.Y - p.Size.Y/2
		if bas < TERR_Y - 2 then
			local nh = TERR_Y - bas
			p.Size = Vector3.new(p.Size.X, nh, p.Size.Z)
			p.Position = Vector3.new(p.Position.X, bas + nh/2, p.Position.Z)
			p.Material = Enum.Material.Rock
			p.Color = ROCHE
		end
	end
end

-- la neige, en pieces separees posees sur les colonnes
local nNeige = 0
for _, p in ipairs(fMont:GetChildren()) do
	local haut, bas = p.Position.Y + p.Size.Y/2, p.Position.Y - p.Size.Y/2
	if haut > M_NEIGE and bas < M_NEIGE then
		local hn = haut - M_NEIGE
		p.Size = Vector3.new(p.Size.X, M_NEIGE - bas, p.Size.Z)
		p.Position = Vector3.new(p.Position.X, bas + (M_NEIGE - bas)/2, p.Position.Z)
		bloc(fMont, "Neige", Vector3.new(p.Size.X, hn, p.Size.Z),
			CFrame.new(p.Position.X, M_NEIGE + hn/2, p.Position.Z),
			Enum.Material.Snow, BLANC)
		nNeige += 1
	end
end

-- ------------------------------------------------------------
--  L EBOULIS
--  Sans lui, les flancs sont des faces planes de 40 studs.
--  Pour chaque direction et chaque hauteur, on tire un rayon
--  HORIZONTAL vers la paroi et on accroche un bloc a l endroit
--  exact touche.  Enfonce a 45 % : moins, il fait l ecaille ;
--  plus, il disparait dans la paroi.
-- ------------------------------------------------------------
local fEb = dossier("Eboulis")
local rpEb = RaycastParams.new()
rpEb.FilterType = Enum.RaycastFilterType.Include
rpEb.FilterDescendantsInstances = {fMont}
local opEb = OverlapParams.new()
opEb.FilterType = Enum.RaycastFilterType.Include
opEb.FilterDescendantsInstances = {fEb}
local rngE = Random.new(11)

local function accroche(ox, oz, angle, y, portee, tailleMax, densiteMax)
	local a = math.rad(angle)
	local dx, dz = math.cos(a), math.sin(a)
	local hit = WS:Raycast(Vector3.new(ox + dx*portee, y, oz + dz*portee),
		Vector3.new(-dx, 0, -dz) * (portee + 40), rpEb)
	if not hit then return end
	local w  = rngE:NextNumber(12, tailleMax)
	local hh = w * rngE:NextNumber(0.75, 1.2)
	local pf = w * rngE:NextNumber(0.85, 1.15)
	local pos = hit.Position - Vector3.new(dx, 0, dz) * (pf * 0.45)
	local neige = (pos.Y > M_NEIGE)
	local p = Instance.new("Part")
	p.Name = neige and "RocherNeige" or "Rocher"
	p.Anchored = true
	p.Size = Vector3.new(w, hh, pf)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(
		math.rad(rngE:NextNumber(-9, 9)),
		math.rad(rngE:NextNumber(0, 360)),
		math.rad(rngE:NextNumber(-9, 9)))
	p.Material = neige and Enum.Material.Snow or Enum.Material.Rock
	p.Color = neige and BLANC or ROCHE
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = WS
	if #WS:GetPartsInPart(p, opEb) > densiteMax then p:Destroy() else p.Parent = fEb end
end

for angle = 0, 359, 10 do
	for y = 30, 570, 42 do
		if rngE:NextNumber() < 0.72 then
			local t = math.clamp(1 - y/600, 0.35, 1)
			accroche(MONT_X, MONT_Z, angle, y, 460, 12 + 34*t, 2)
		end
	end
end
for angle = 0, 359, 6 do
	for y = 88, 256, 17 do
		accroche(TERR_X, TERR_Z, angle, y, 280, 32, 5)
	end
end
for angle = 0, 359, 16 do
	local a = math.rad(angle)
	for _ = 1, 2 do
		local d = rngE:NextNumber(330, 420)
		local w = rngE:NextNumber(16, 52)
		local hh = w * rngE:NextNumber(0.5, 1.0)
		bloc(fEb, "Rocher", Vector3.new(w, hh, w * rngE:NextNumber(0.8, 1.15)),
			CFrame.new(MONT_X + math.cos(a)*d, SOL_SURFACE + hh/2 - 1, MONT_Z + math.sin(a)*d)
			* CFrame.Angles(0, math.rad(rngE:NextNumber(0, 360)), 0),
			Enum.Material.Rock, ROCHE)
	end
end
local ebSurPiste = 0
for _, p in ipairs(fEb:GetChildren()) do
	if #WS:GetPartsInPart(p, opPiste) > 0 then p:Destroy(); ebSurPiste += 1 end
end

-- ============================================================
--  LE PODIUM, sur la terrasse
--  Oriente PLEIN AXE +Z (face a la ligne d arrivee, qui est au
--  nord).  Viser le centre exact de la ligne le mettait 21 degres
--  de travers.
--
--  Piege des chiffres : TextScaled ne fait qu ajuster TextSize,
--  qui est PLAFONNE A 100 par Roblox.  Pour ecrire gros il ne faut
--  donc pas agrandir le texte mais RETRECIR le canvas (ici 5 px
--  par stud) : les 100 px valent alors 20 studs.
-- ============================================================
local fPod = dossier("Podium")
local basePod = CFrame.lookAt(Vector3.new(TERR_X, TERR_Y, TERR_Z),
	Vector3.new(TERR_X, TERR_Y, TERR_Z + 10))

bloc(fPod, "Estrade", Vector3.new(152, 4, 104), basePod * CFrame.new(0, 2, -8),
	Enum.Material.Slate, Color3.fromRGB(96, 94, 92))
bloc(fPod, "Estrade", Vector3.new(138, 3, 91), basePod * CFrame.new(0, 5.5, -8),
	Enum.Material.Marble, Color3.fromRGB(150, 146, 140))
local SOCLE = 7

-- dx POSITIF part vers l ouest (RightVector d un lookAt vers +Z vaut -X) :
-- l argent se met donc a dx positif pour apparaitre a GAUCHE vu de face.
local MARCHES = {
	{r = "2", dx =  38, h = 24, col = Color3.fromRGB(198, 202, 208)},
	{r = "1", dx =   0, h = 35, col = Color3.fromRGB(214, 176,  52)},
	{r = "3", dx = -38, h = 18, col = Color3.fromRGB(176, 116,  60)},
}
local PIX_STUD = 5
local plusBasse = math.huge
for _, mm in ipairs(MARCHES) do plusBasse = math.min(plusBasse, mm.h) end
local COTE_PX = math.floor(plusBasse * 0.86 * PIX_STUD)

for _, mm in ipairs(MARCHES) do
	local p = bloc(fPod, "Marche" .. mm.r, Vector3.new(35, mm.h, 35),
		basePod * CFrame.new(mm.dx, SOCLE + mm.h/2, -8), Enum.Material.Metal, mm.col)
	bloc(fPod, "Bordure", Vector3.new(37, 1, 37),
		basePod * CFrame.new(mm.dx, SOCLE + mm.h + 0.5, -8),
		Enum.Material.SmoothPlastic, Color3.fromRGB(236, 234, 228))
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back,
	                       Enum.NormalId.Left,  Enum.NormalId.Right}) do
		local larg = (face == Enum.NormalId.Front or face == Enum.NormalId.Back) and 35 or 35
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(larg * PIX_STUD, mm.h * PIX_STUD)
		sg.LightInfluence = 0
		sg.Parent = p
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.fromOffset(COTE_PX, COTE_PX)
		t.BackgroundTransparency = 1
		t.Text = mm.r
		t.TextColor3 = Color3.fromRGB(26, 24, 20)
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.Parent = sg
	end
end

-- 4 mats avec un feu en haut
for _, s in ipairs({-1, 1}) do
	for _, z in ipairs({-30, 14}) do
		bloc(fPod, "Mat", Vector3.new(3, 56, 3), basePod * CFrame.new(s*70, SOCLE + 28, z),
			Enum.Material.Metal, Color3.fromRGB(186, 188, 192))
		local b = bloc(fPod, "Feu", Vector3.new(6, 6, 6),
			basePod * CFrame.new(s*70, SOCLE + 58, z),
			Enum.Material.Neon, Color3.fromRGB(255, 244, 214))
		b.Shape = Enum.PartType.Ball
		local pl = Instance.new("PointLight")
		pl.Brightness = 1.4; pl.Range = 65; pl.Shadows = false
		pl.Color = Color3.fromRGB(255, 246, 224); pl.Parent = b
	end
end

-- LE PANNEAU, a mi-hauteur de la zone enneigee, sur le flanc nord.
-- On cherche la paroi au rayon : place au juge, il rentre dans la roche.
local Y_PAN = math.floor((M_NEIGE + 603) / 2)
local hitPan = WS:Raycast(Vector3.new(MONT_X, Y_PAN, MONT_Z + 420),
	Vector3.new(0, 0, -450), rpEb)
local panX = hitPan and hitPan.Position.X or MONT_X
local panZ = hitPan and (hitPan.Position.Z + 5) or (MONT_Z + 102)
local pan = bloc(fPod, "Panneau", Vector3.new(230, 50, 4),
	CFrame.new(panX, Y_PAN, panZ), Enum.Material.Slate, Color3.fromRGB(52, 50, 48))
for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(920, 200)
	sg.LightInfluence = 0; sg.Parent = pan
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
	t.Text = "RALLY MONTAGNE"
	t.TextColor3 = Color3.fromRGB(244, 230, 186)
	t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.Parent = sg
end
-- on degage ce qui masquerait le texte
local sondeP = Instance.new("Part")
sondeP.Anchored = true; sondeP.CanCollide = false; sondeP.Transparency = 1
sondeP.Size = Vector3.new(pan.Size.X + 10, pan.Size.Y, 60)
sondeP.Position = pan.Position + Vector3.new(0, 0, 32)
sondeP.Parent = WS
local opPan = OverlapParams.new()
opPan.FilterType = Enum.RaycastFilterType.Include
opPan.FilterDescendantsInstances = {fMont, fEb}
opPan.MaxParts = 60
for _, g in ipairs(WS:GetPartsInPart(sondeP, opPan)) do
	local bas, haut = g.Position.Y - g.Size.Y/2, g.Position.Y + g.Size.Y/2
	local cible = pan.Position.Y - pan.Size.Y/2 - 6
	if haut > cible then
		if cible - bas > 8 then
			local nh = cible - bas
			g.Size = Vector3.new(g.Size.X, nh, g.Size.Z)
			g.Position = Vector3.new(g.Position.X, bas + nh/2, g.Position.Z)
		else
			g:Destroy()
		end
	end
end
sondeP:Destroy()

-- ============================================================
--  LE SOL
--  Il est CREE s'il n'existe pas (avant, le script se contentait
--  de modifier un sol deja present : si on l'avait supprime, on
--  se retrouvait a rouler au dessus du vide).
--  Sa surface est calee juste sous le bitume de la vallee, sinon
--  la route flotte plusieurs studs au dessus de l'herbe.
-- ============================================================
local bp = WS:FindFirstChild("Baseplate")
if not bp then
	bp = Instance.new("Part"); bp.Name = "Baseplate"; bp.Parent = WS
end
bp.Anchored = true
bp.Size = Vector3.new(2048, SOL_EP, 2048)   -- 2048 = taille maxi d'une Part
bp.Position = Vector3.new(-120, SOL_SURFACE - SOL_EP/2, 140)
bp.Material = Enum.Material.Grass
bp.Color = Color3.fromRGB(76, 112, 62)
bp.TopSurface = Enum.SurfaceType.Smooth
bp.BottomSurface = Enum.SurfaceType.Smooth
bp.Locked = true
local tex = bp:FindFirstChildOfClass("Texture")
if tex then tex:Destroy() end

-- ============================================================
--  LIGNE DE DEPART / ARRIVEE
--  On ne DEVINE pas sa position : on la demande a la route.
--  Avant elle etait ecrite en dur (-230 ; 486) : elle depassait
--  de 6 studs d un cote et laissait un trou de l autre.
--  Le damier est ENTERRE dans l asphalte (0.5 d epaisseur, dessus
--  a +0.02) : ca fait de la peinture sur la route, pas une marche.
--  Le +0.02 n est pas decoratif : a exactement la meme hauteur que
--  le bitume, les deux surfaces clignotent (z-fighting).
-- ============================================================
local SEG_DEPART = 8                  -- 8e morceau de route, sur la ligne droite
local rDep  = segments[SEG_DEPART].p
local largD = rDep.Size.X
local dessD = EPAISSEUR / 2           -- en local : le haut du bitume

-- 1) la zone INVISIBLE : c est elle que lira le chrono
local ligne = Instance.new("Part")
ligne.Name = "LigneDepart"; ligne.Anchored = true
ligne.CanCollide = false; ligne.Transparency = 1
ligne.Size = Vector3.new(largD, 10, 15)
ligne.CFrame = rDep.CFrame * CFrame.new(0, dessD + 5, 0)
ligne.Parent = circuit

-- 2) le damier : juste pour qu on la voie
local fDam = dossier("Damier")
local NB_CASES, NB_RANGS_D, EP_CASE = 12, 3, 0.5
local pasD = largD / NB_CASES         -- des cases carrees de ~5 studs
for rang = 0, NB_RANGS_D - 1 do
	for k = 0, NB_CASES - 1 do
		local blanc = ((k + rang) % 2 == 0)
		local c = bloc(fDam, "Case", Vector3.new(pasD, EP_CASE, pasD),
			rDep.CFrame * CFrame.new(
				-largD/2 + pasD/2 + k * pasD,
				dessD + 0.02 - EP_CASE/2,
				-(NB_RANGS_D * pasD)/2 + pasD/2 + rang * pasD),
			Enum.Material.SmoothPlastic,
			blanc and Color3.fromRGB(248, 248, 248) or Color3.fromRGB(24, 24, 26))
		c.CanCollide = false           -- sinon la voiture tape une marche
	end
end

-- ============================================================
--  LE PORTIQUE ET LES FEUX DE DEPART
--  Les voitures arrivent du cote local +Z de la route (elles
--  roulent vers -Z). Les ampoules doivent donc REGARDER vers +Z,
--  sinon le pilote ne voit que l arriere du panneau.
--  Un cylindre presente ses faces rondes sur son axe X : il faut
--  le tourner de -90 degres autour de Y pour qu il nous regarde.
--  Les feux sont ETEINTS. Le compte a rebours viendra avec le
--  chrono : 5 colonnes -> une boucle "for i = 1, 5".
-- ============================================================
local fFeux = dossier("FeuxDepart")
local METAL = Color3.fromRGB(58, 58, 62)

local H_MAT  = 58            -- <<< LE SEUL NOMBRE A CHANGER POUR MONTER LE PORTIQUE
local EP_MAT = 4             -- plus c est haut, plus il faut epaissir : sinon fil de fer
local ECART  = largD/2 + 5   -- les mats se plantent hors des barrieres

for _, cote in ipairs({-1, 1}) do
	bloc(fFeux, "Mat", Vector3.new(EP_MAT, H_MAT, EP_MAT),
		rDep.CFrame * CFrame.new(cote * ECART, dessD + H_MAT/2, 0),
		Enum.Material.Metal, METAL)
	bloc(fFeux, "Socle", Vector3.new(8, 2, 8),
		rDep.CFrame * CFrame.new(cote * ECART, dessD + 1, 0),
		Enum.Material.Concrete, Color3.fromRGB(120, 118, 114))
end

bloc(fFeux, "Poutre", Vector3.new(largD + 16, 3.5, EP_MAT),
	rDep.CFrame * CFrame.new(0, dessD + H_MAT + 1.75, 0),
	Enum.Material.Metal, METAL)

-- 5 COLONNES de 3 ampoules.
-- Tout se DEDUIT de ces trois nombres : largeur et hauteur du panneau,
-- ecartement des ampoules. Changer NB_COL ou NB_RANGS suffit.
local NB_COL, NB_RANGS, DIAM = 5, 3, 6.5
local ECART_A  = DIAM + 1
local LARG_PAN = NB_COL * (DIAM + 3.5)
local HAUT_PAN = NB_RANGS * ECART_A + 3.5
local yPan     = dessD + H_MAT - 0.5 - HAUT_PAN/2   -- suspendu sous la poutre

local panneau = bloc(fFeux, "Panneau", Vector3.new(LARG_PAN, HAUT_PAN, 2),
	rDep.CFrame * CFrame.new(0, yPan, 0),
	Enum.Material.SmoothPlastic, Color3.fromRGB(20, 20, 22))

local ETEINT = Color3.fromRGB(58, 16, 16)
local PAS_F  = LARG_PAN / NB_COL
for i = 1, NB_COL do
	local col = Instance.new("Model"); col.Name = "Feu" .. i; col.Parent = fFeux
	local dx = -LARG_PAN/2 + PAS_F/2 + (i - 1) * PAS_F
	for r = 1, NB_RANGS do
		local dy = (NB_RANGS - 1)/2 * ECART_A - (r - 1) * ECART_A
		local amp = bloc(col, "Ampoule", Vector3.new(1.4, DIAM, DIAM),
			panneau.CFrame * CFrame.new(dx, dy, 1.6)
			               * CFrame.Angles(0, math.rad(-90), 0),
			Enum.Material.SmoothPlastic, ETEINT)
		amp.Shape = Enum.PartType.Cylinder
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 40, 40)
		l.Brightness = 6; l.Range = 28; l.Enabled = false
		l.Parent = amp
	end
end

local sp = WS:FindFirstChild("SpawnLocation")
if sp then
	sp.Anchored = true
	sp.CFrame = CFrame.lookAt(Vector3.new(-310*ECHELLE, 3, 488*ECHELLE),
		Vector3.new(0, 3, 482*ECHELLE))
end

-- ============================================================
--  CONTROLES AUTOMATIQUES
--  Le script verifie son propre travail au lieu de me faire
--  chercher les defauts a l'oeil.
-- ============================================================
-- a) rochers qui empietent sur le couloir de roulage -> on les pousse
local opD = OverlapParams.new()
opD.FilterType = Enum.RaycastFilterType.Include
opD.FilterDescendantsInstances = {fDecor}
opD.MaxParts = 30
local sonde = Instance.new("Part")
sonde.Anchored = true; sonde.CanCollide = false; sonde.Transparency = 1; sonde.Parent = WS
local pousses = 0
for _ = 1, 4 do
	for _, r in ipairs(fRoute:GetChildren()) do
		sonde.Size = Vector3.new(r.Size.X + 8, 20, r.Size.Z)
		sonde.CFrame = r.CFrame * CFrame.new(0, 12, 0)
		for _, p in ipairs(WS:GetPartsInPart(sonde, opD)) do
			if p.Name == "Rocher" then
				local rel = r.CFrame:PointToObjectSpace(p.Position)
				p.CFrame = p.CFrame + r.CFrame.RightVector * (((rel.X >= 0) and 1 or -1) * 22)
				pousses += 1
			end
		end
	end
end
sonde:Destroy()

-- b) talus sans route au-dessus -> ils depassent dans le vide, on les enleve
local rpR = RaycastParams.new()
rpR.FilterType = Enum.RaycastFilterType.Include
rpR.FilterDescendantsInstances = {fRoute}
local orphelins = 0
for _, t in ipairs(fTalus:GetChildren()) do
	local sommet = (t.CFrame * CFrame.new(0, t.Size.Y/2 - 1, 0)).Position
	if not WS:Raycast(sommet, t.CFrame.UpVector * 9, rpR) then
		t:Destroy(); orphelins += 1
	end
end

local pm, pp = P[iMin], P[penteOu]
return string.format(
	"CIRCUIT COMPLET | %d routes, %d barrieres | tour %d studs (~%d s)\n"..
	"pente max %.1f%% | rayon mini %d | sommet de piste %d studs\n"..
	"TREMPLIN : trou %d, chute %d, vitesse mini %d studs/s, %d piques\n"..
	"MONTAGNE : %d blocs + %d eboulis | terrasse et podium a y=%d\n"..
	"Controles : %d ouvertures, %d rochers repousses, %d talus orphelins\n"..
	"TOTAL : %d objets",
	#segments, poses, math.floor(longueur), math.floor(longueur/70),
	penteMax*100, math.floor(rayonMin), math.floor(hMax),
	math.floor(trou), math.floor(chute), vmin, nPiques,
	#fMont:GetChildren(), #fEb:GetChildren(), TERR_Y,
	ouverts, pousses, orphelins,
	#circuit:GetDescendants())
