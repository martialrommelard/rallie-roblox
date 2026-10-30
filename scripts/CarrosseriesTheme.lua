-- ============================================================
--  LES CARROSSERIES A THEME : GIVRE, REQUIN, DRAGON (generateur)
--  A lancer UNE fois dans Studio, en mode Edit, APRES VoitureRally.lua.
--
--  Comme la Flash et la Ronce : on COPIE ServerStorage.VoitureModele
--  (memes roues, meme moteur, memes morceaux qui cassent) et on la
--  rhabille. Chaque voiture a un POUVOIR (attribut "Pouvoir", lu par le
--  script PouvoirsVoitures) :
--    - GIVRE  : glace bleue, stalactites, cristaux sur le toit, brume.
--               Pouvoir "Verglas" : elle laisse des plaques de glace,
--               les autres glissent dessus.
--    - REQUIN : gris et blanc, aileron sur le toit, une gueule pleine de
--               DENTS devant (attribut "Epine" : qui se fait mordre
--               s abime 2.5 fois plus), des branchies, des petits yeux.
--    - DRAGON : rouge et or, ecailles, cornes, ailes repliees, une queue.
--               Pouvoir "Feu" : touche F, il crache du feu devant lui.
--  Rangees dans ServerStorage (VoitureGivre, VoitureRequin, VoitureDragon),
--  avec l attribut "Carrosserie".
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")
local modele = ServerStorage:WaitForChild("VoitureModele")

-- les pieces de rally qu on enleve sur toutes
local A_ENLEVER = {
	RampePhares = true, PhareRampe = true, PriseToit = true,
	PareBoueG = true, PareBoueD = true, CrochetAv = true, CrochetAr = true,
}
local SANS_DECO = {Caisse = true, PareBrise = true}    -- les "RALLYE" (on garde le numero des portieres)

-- =========================================================
-- LES OUTILS (pour les trois voitures)
-- =========================================================
local v, chassis          -- la voiture en cours de construction
local function ici(x, y, z) return chassis.CFrame * CFrame.new(x, y, z) end    -- (repere du chassis : avant = -Z, gauche = -X)
local function pt(x, y, z) return ici(x, y, z).Position end
local function dir(x, y, z) return chassis.CFrame:VectorToWorldSpace(Vector3.new(x, y, z)) end
local function lp(nom) local p = v:FindFirstChild(nom); return p and chassis.CFrame:ToObjectSpace(p.CFrame), p end

-- on part d une copie de la voiture de rally, sans ses accessoires
local function copier(nom, pouvoir)
	local ancien = ServerStorage:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
	v = modele:Clone()
	v.Name = nom
	v:SetAttribute("Carrosserie", nom)
	v:SetAttribute("Pouvoir", pouvoir)
	chassis = v:WaitForChild("Chassis")
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") and A_ENLEVER[p.Name] then p:Destroy() end
	end
	for _, p in ipairs(v:GetChildren()) do
		if SANS_DECO[p.Name] then
			for _, g in ipairs(p:GetChildren()) do
				if g:IsA("SurfaceGui") and g.Name == "Deco" then g:Destroy() end
			end
		end
	end
end
local function peindre(peinture, jante)
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") then
			if p:GetAttribute("Peinture") then p.Color = peinture end
			if jante and p.Name:match("^Jante") then p.Color = jante end
		end
	end
end
local function colorer(noms, couleur, matiere)
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") and noms[p.Name] then
			p.Color = couleur
			if matiere then p.Material = matiere end
		end
	end
end

-- une piece ajoutee : soudee au chassis, du meme MORCEAU que la piece
-- qu elle decore (elle tombe avec elle), sans poids, elle ne cogne pas
local function ajout(nom, classe, taille, cf, couleur, matiere, morceau)
	local p = Instance.new(classe)
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Massless = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p:SetAttribute("Morceau", morceau)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = chassis, p
	w.Parent = p
	p.Parent = v
	return p
end

-- une POINTE (deux coins colles : un triangle pointu), du point "pied"
-- dans la direction "d". "pique" : elle abime ceux qui la touchent
-- (attribut "Epine", comme la Ronce).
local function pointe(nom, pied, d, longueur, couleur, matiere, morceau, pique)
	local centre = pied + d.Unit * (longueur / 2)
	local haut = (math.abs(d.Unit.Y) > 0.9) and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt(centre, centre + d, haut)
	local large = math.max(0.15, longueur * 0.42)
	local coins = {}
	for k = 1, 2 do
		local cfk = (k == 1) and (cf * CFrame.new(0, large / 4, 0))
			or (cf * CFrame.new(0, -large / 4, 0) * CFrame.Angles(0, 0, math.pi))
		local c = ajout(nom, "WedgePart", Vector3.new(math.min(0.35, longueur * 0.3), large / 2, longueur), cfk, couleur, matiere, morceau)
		if pique then
			c.CanTouch = true
			c:SetAttribute("Epine", true)
		end
		table.insert(coins, c)
	end
	return coins
end

-- une BRANCHE COURBE (corne, queue) : des troncons bout a bout ; a chaque
-- troncon, la direction tourne de "virage" (radians) autour de "axe", et
-- l epaisseur diminue. Rend le bout et la derniere direction.
local function courbe(nom, depart, d, n, longueur, ep, epFin, axe, virage, couleur, matiere, morceau)
	local p = depart
	for i = 1, n do
		local e = ep + (epFin - ep) * (i - 1) / math.max(1, n - 1)
		local q = p + d.Unit * longueur
		local t = ajout(nom, "Part", Vector3.new(longueur + e * 0.5, e, e), CFrame.lookAt((p + q) / 2, q) * CFrame.Angles(0, math.pi / 2, 0), couleur, matiere, morceau)
		t.Shape = Enum.PartType.Cylinder
		local b = ajout(nom, "Part", Vector3.new(e, e, e), CFrame.new(q), couleur, matiere, morceau)
		b.Shape = Enum.PartType.Ball
		p = q
		d = CFrame.fromAxisAngle(axe, virage):VectorToWorldSpace(d)
	end
	return p, d
end

-- un TRIANGLE quelconque (a, b, c), avec deux coins (la methode classique
-- de Roblox : on coupe le triangle en deux triangles rectangles)
local function triangle(nom, a, b, c, epaisseur, couleur, matiere, morceau)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then c, a = a, c
	elseif acd > bcd and acd > abd then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	local droite = ac:Cross(ab).Unit
	local haut = bc:Cross(droite).Unit
	local dos = bc.Unit
	local h = math.abs(ab:Dot(haut))
	ajout(nom, "WedgePart", Vector3.new(epaisseur, h, math.abs(ab:Dot(dos))), CFrame.fromMatrix((a + b) / 2, droite, haut, dos), couleur, matiere, morceau)
	ajout(nom, "WedgePart", Vector3.new(epaisseur, h, math.abs(ac:Dot(dos))), CFrame.fromMatrix((a + c) / 2, -droite, haut, -dos), couleur, matiere, morceau)
end

local function ranger(texte)
	v.Parent = ServerStorage
	local n = 0
	for _, p in ipairs(v:GetDescendants()) do if p:IsA("BasePart") then n += 1 end end
	print(string.format("%s : %s (%d pieces)", v.Name, texte, n))
end

-- =========================================================
-- 1. GIVRE
-- =========================================================
do
	copier("VoitureGivre", "Verglas")
	local GLACE  = Color3.fromRGB(175, 215, 240)
	local BLANC  = Color3.fromRGB(235, 245, 255)
	local STALAC = Color3.fromRGB(205, 235, 255)
	local CRISTAL = Color3.fromRGB(120, 225, 255)
	peindre(GLACE, Color3.fromRGB(225, 235, 245))
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Peinture") then p.Reflectance = 0.15 end
	end
	colorer({PareChocsAv = true, PareChocsAr = true, BasDeCaisse = true, Lame = true, Diffuseur = true}, BLANC)
	colorer({ArceauG = true, ArceauD = true, ArceauHaut = true}, CRISTAL, Enum.Material.Ice)
	local nbStalac = 0
	-- les STALACTITES : sous le bord exterieur des 4 ailes, et sous l aileron
	local function stalactites(nomPiece, cote)
		local cf, p = lp(nomPiece)
		if not p then return end
		local m = p:GetAttribute("Morceau")
		local n = 4
		for i = 0, n - 1 do
			local z = cf.Position.Z - p.Size.Z / 2 + (i + 0.5) * p.Size.Z / n
			local x = cf.Position.X + cote * (p.Size.X / 2 - 0.15)
			local l = (i % 2 == 0) and 0.9 or 0.55
			local s = pointe("Stalactite", pt(x, cf.Position.Y - p.Size.Y / 2, z), dir(0, -1, 0.12), l, STALAC, Enum.Material.Ice, m, false)
			for _, c in ipairs(s) do c.Transparency = 0.15 end
			nbStalac += 1
		end
	end
	for _, s in ipairs({{"G", -1}, {"D", 1}}) do
		stalactites("AileAv" .. s[1], s[2])
		stalactites("AileAr" .. s[1], s[2])
	end
	local cfA, aileron = lp("Aileron")
	if aileron then
		for i = 0, 6 do
			local x = -aileron.Size.X / 2 + 0.4 + i * (aileron.Size.X - 0.8) / 6
			local s = pointe("Stalactite", pt(x, cfA.Position.Y - aileron.Size.Y / 2, cfA.Position.Z + aileron.Size.Z / 2 - 0.2),
				dir(0, -1, 0.1), (i % 2 == 0) and 1.1 or 0.6, STALAC, Enum.Material.Ice, aileron:GetAttribute("Morceau"), false)
			for _, c in ipairs(s) do c.Transparency = 0.15 end
			nbStalac += 1
		end
	end
	-- les CRISTAUX sur le toit : un bouquet de pointes lumineuses
	local cfT, toit = lp("Toit")
	local yT = cfT.Position.Y + toit.Size.Y / 2
	for _, c in ipairs({{0, 0.4, 1.7, 0, 1, 0.15}, {-0.5, 0.6, 1.1, -0.5, 1, 0.3}, {0.5, 0.7, 1.2, 0.5, 1, 0.25},
		{-0.2, 1.2, 0.9, -0.2, 1, 0.6}, {0.3, -0.2, 1.0, 0.3, 1, -0.3}}) do
		local s = pointe("Cristal", pt(c[1], yT - 0.05, cfT.Position.Z + c[2]), dir(c[4], c[5], c[6]), c[3], CRISTAL, Enum.Material.Neon, nil, false)
		for _, x in ipairs(s) do x.Transparency = 0.25 end
	end
	-- la BRUME froide qui s echappe de l arriere
	local brume = Instance.new("ParticleEmitter")
	brume.Name = "Brume"
	brume.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	brume.Transparency = NumberSequence.new(0.55, 1)
	brume.Size = NumberSequence.new(0.6, 1.8)
	brume.Lifetime = NumberRange.new(0.8, 1.4)
	brume.Rate = 14
	brume.Speed = NumberRange.new(1, 3)
	brume.SpreadAngle = Vector2.new(30, 30)
	brume.EmissionDirection = Enum.NormalId.Back
	brume.LightEmission = 0.3
	brume.Parent = v:FindFirstChild("PareChocsAr")
	ranger(nbStalac .. " stalactites, 5 cristaux, brume")
end

-- =========================================================
-- 2. REQUIN
-- =========================================================
do
	copier("VoitureRequin", nil)
	local GRIS  = Color3.fromRGB(105, 118, 132)
	local VENTRE = Color3.fromRGB(228, 232, 236)
	local DENT  = Color3.fromRGB(248, 244, 228)
	local GORGE = Color3.fromRGB(70, 10, 16)
	local SOMBRE = Color3.fromRGB(25, 28, 34)
	peindre(GRIS, Color3.fromRGB(190, 196, 204))
	colorer({PareChocsAv = true, PareChocsAr = true, BasDeCaisse = true, Diffuseur = true, Lame = true}, VENTRE)
	colorer({ArceauG = true, ArceauD = true, ArceauHaut = true}, SOMBRE)
	-- la GUEULE : on enleve la plaque et les prises d air du pare-chocs avant
	for _, p in ipairs(v:GetChildren()) do
		if p.Name == "PlaqueAv" or p.Name == "PriseAirAv" then p:Destroy() end
	end
	local cfP, pc = lp("PareChocsAv")
	local m = pc:GetAttribute("Morceau")
	local zAv = cfP.Position.Z - pc.Size.Z / 2
	local larg, haut = pc.Size.X - 1.2, pc.Size.Y * 0.7
	ajout("Gueule", "Part", Vector3.new(larg, haut, 0.1), ici(0, cfP.Position.Y, zAv - 0.04), GORGE, Enum.Material.SmoothPlastic, m)
	-- les DENTS : une rangee en haut (vers le bas), une en bas (vers le haut)
	local nbDents = 0
	for i = 0, 8 do
		local x = -larg / 2 + 0.3 + i * (larg - 0.6) / 8
		pointe("Dent", pt(x, cfP.Position.Y + haut / 2, zAv - 0.12), dir(0, -1, -0.25), 0.5, DENT, Enum.Material.SmoothPlastic, m, true)
		nbDents += 1
		if i < 8 then
			pointe("Dent", pt(x + (larg - 0.6) / 16, cfP.Position.Y - haut / 2, zAv - 0.12), dir(0, 1, -0.25), 0.4, DENT, Enum.Material.SmoothPlastic, m, true)
			nbDents += 1
		end
	end
	-- l AILERON sur le toit : un coin (son bord droit a l arriere, sa pente devant)
	local cfT, toit = lp("Toit")
	local yT = cfT.Position.Y + toit.Size.Y / 2
	ajout("Aileron dorsal", "WedgePart", Vector3.new(0.3, 2.4, 2.6), ici(0, yT + 1.2, cfT.Position.Z + 0.4), GRIS, Enum.Material.SmoothPlastic, nil)
	-- une petite NAGEOIRE de queue sur l aileron arriere
	local cfA, aileron = lp("Aileron")
	if aileron then
		ajout("Nageoire", "WedgePart", Vector3.new(0.25, 1.3, 1.2),
			ici(0, cfA.Position.Y + aileron.Size.Y / 2 + 0.65, cfA.Position.Z), GRIS, Enum.Material.SmoothPlastic, aileron:GetAttribute("Morceau"))
	end
	-- les BRANCHIES (3 fentes sur chaque portiere, a l avant) et les YEUX
	for _, s in ipairs({{"G", -1}, {"D", 1}}) do
		local cfD, porte = lp("Portiere" .. s[1])
		local x = cfD.Position.X + s[2] * (porte.Size.X / 2 + 0.03)
		for k = 0, 2 do
			ajout("Branchie", "Part", Vector3.new(0.06, porte.Size.Y * 0.6, 0.14),
				ici(x, cfD.Position.Y + 0.1, cfD.Position.Z - porte.Size.Z / 2 + 0.35 + k * 0.32) * CFrame.Angles(math.rad(-12), 0, 0),
				SOMBRE, Enum.Material.SmoothPlastic, porte:GetAttribute("Morceau"))
		end
		local cfW, aile = lp("AileAvAv" .. s[1])
		if aile then
			local xo = cfW.Position.X + s[2] * (aile.Size.X / 2 + 0.05)
			local oeil = ajout("Oeil", "Part", Vector3.new(0.5, 0.5, 0.5), ici(xo, cfW.Position.Y + 0.15, cfW.Position.Z + 0.1), SOMBRE, Enum.Material.Glass, aile:GetAttribute("Morceau"))
			oeil.Shape = Enum.PartType.Ball
			local reflet = ajout("Oeil", "Part", Vector3.new(0.16, 0.16, 0.16), ici(xo + s[2] * 0.2, cfW.Position.Y + 0.28, cfW.Position.Z), Color3.new(1, 1, 1), Enum.Material.Neon, aile:GetAttribute("Morceau"))
			reflet.Shape = Enum.PartType.Ball
		end
	end
	ranger(nbDents .. " dents, aileron, branchies, yeux")
end

-- =========================================================
-- 3. DRAGON
-- =========================================================
do
	copier("VoitureDragon", "Feu")
	local ROUGE  = Color3.fromRGB(150, 20, 18)
	local OR     = Color3.fromRGB(220, 172, 52)
	local IVOIRE = Color3.fromRGB(236, 222, 186)
	local MEMBRANE = Color3.fromRGB(95, 12, 14)
	peindre(ROUGE, OR)
	colorer({PhareG = true, PhareD = true}, Color3.fromRGB(255, 195, 30), Enum.Material.Neon)    -- des yeux jaunes
	colorer({ArceauG = true, ArceauD = true, ArceauHaut = true}, OR, Enum.Material.Metal)
	-- les ECAILLES : des losanges dores dessines sur le capot, le toit et le hayon
	local nbEcailles = 0
	local function ecailles(nomPiece)
		local _, p = lp(nomPiece)
		if not p then return end
		local g = Instance.new("SurfaceGui")
		g.Name = "Ecailles"
		g.Face = Enum.NormalId.Top
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 30
		g.LightInfluence = 0.6
		local L, H = p.Size.X * 30, p.Size.Z * 30
		local pas = 22
		local ligne = 0
		for y = 0, H + pas, pas * 0.6 do
			for x = (ligne % 2) * pas / 2, L + pas, pas do
				local f = Instance.new("Frame")
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.fromOffset(x, y)
				f.Size = UDim2.fromOffset(pas * 0.62, pas * 0.62)
				f.Rotation = 45
				f.BackgroundTransparency = 1
				local trait = Instance.new("UIStroke")
				trait.Color = OR
				trait.Thickness = 2
				trait.Transparency = 0.25
				trait.Parent = f
				f.Parent = g
				nbEcailles += 1
			end
			ligne += 1
		end
		g.Parent = p
	end
	ecailles("Capot")
	ecailles("Toit")
	ecailles("Hayon")
	-- les CORNES : a l arriere du capot, elles montent puis se courbent vers l arriere
	local cfK, capot = lp("Capot")
	local yK = cfK.Position.Y + capot.Size.Y / 2
	local zK = cfK.Position.Z + capot.Size.Z / 2 - 0.3
	for _, sx in ipairs({-1, 1}) do
		local bout, d = courbe("Corne", pt(sx * 2.1, yK, zK), dir(sx * 0.35, 1, 0.1), 6, 0.42, 0.42, 0.14,
			chassis.CFrame.RightVector, math.rad(22), IVOIRE, Enum.Material.SmoothPlastic, capot:GetAttribute("Morceau"))
		pointe("Corne", bout, d, 0.5, IVOIRE, Enum.Material.SmoothPlastic, capot:GetAttribute("Morceau"), false)
	end
	-- une CRETE de petites pointes dorees sur le toit
	local cfT, toit = lp("Toit")
	local yT = cfT.Position.Y + toit.Size.Y / 2
	for i = 0, 3 do
		pointe("Crete", pt(0, yT - 0.05, cfT.Position.Z - toit.Size.Z / 2 + 0.5 + i * (toit.Size.Z - 1) / 3), dir(0, 1, 0.5), 0.8 - i * 0.08, OR, Enum.Material.Metal, nil, false)
	end
	-- les AILES repliees le long des flancs : 3 doigts d os qui partent de
	-- l epaule, et la membrane tendue entre eux
	for _, s in ipairs({{"G", -1}, {"D", 1}}) do
		local sx = s[2]
		local cfR, aileAr = lp("AileAr" .. s[1])
		local m = aileAr and aileAr:GetAttribute("Morceau")
		local epaule = pt(sx * 3.3, 2.5, 0.2)
		local doigts = {pt(sx * 3.9, 4.3, 2.2), pt(sx * 4.0, 3.7, 3.9), pt(sx * 3.8, 2.7, 5.4)}
		for _, b in ipairs(doigts) do
			local t = ajout("AileDragon", "Part", Vector3.new((b - epaule).Magnitude, 0.2, 0.2),
				CFrame.lookAt((epaule + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), OR, Enum.Material.Metal, m)
			t.Shape = Enum.PartType.Cylinder
			pointe("AileDragon", b, b - epaule, 0.35, OR, Enum.Material.Metal, m, false)
		end
		for k = 1, 2 do
			triangle("Membrane", epaule, doigts[k], doigts[k + 1], 0.06, MEMBRANE, Enum.Material.Fabric, m)
		end
	end
	-- la QUEUE : elle part du pare-chocs arriere et ondule, avec un dard
	local cfQ, pcAr = lp("PareChocsAr")
	local mQ = pcAr:GetAttribute("Morceau")
	local bout, d = courbe("Queue", pt(0, cfQ.Position.Y + 0.2, cfQ.Position.Z + pcAr.Size.Z / 2), dir(0, 0.15, 1), 4, 0.6, 0.5, 0.3,
		chassis.CFrame.UpVector, math.rad(14), ROUGE, Enum.Material.SmoothPlastic, mQ)
	bout, d = courbe("Queue", bout, d, 3, 0.55, 0.28, 0.16, chassis.CFrame.UpVector, math.rad(-22), ROUGE, Enum.Material.SmoothPlastic, mQ)
	pointe("Dard", bout, d, 0.9, OR, Enum.Material.Metal, mQ, true)
	-- la GUEULE (invisible) d ou sort le feu, au milieu du pare-chocs avant
	local cfP, pc = lp("PareChocsAv")
	local gueule = ajout("Gueule", "Part", Vector3.new(0.6, 0.6, 0.6), ici(0, cfP.Position.Y + 0.3, cfP.Position.Z - pc.Size.Z / 2 - 0.4), OR, nil, pc:GetAttribute("Morceau"))
	gueule.Transparency = 1
	local feu = Instance.new("ParticleEmitter")
	feu.Name = "Feu"
	feu.Enabled = false
	feu.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 10)),
	})
	feu.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	feu.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4.5)})
	feu.Lifetime = NumberRange.new(0.5, 0.8)
	feu.Rate = 120
	feu.Speed = NumberRange.new(30, 40)
	feu.SpreadAngle = Vector2.new(12, 12)
	feu.EmissionDirection = Enum.NormalId.Front
	feu.LightEmission = 1
	feu.Parent = gueule
	local lueur = Instance.new("PointLight")
	lueur.Name = "Lueur"
	lueur.Enabled = false
	lueur.Color = Color3.fromRGB(255, 140, 40)
	lueur.Range = 20
	lueur.Brightness = 3
	lueur.Parent = gueule
	ranger(nbEcailles .. " ecailles, cornes, ailes, queue, gueule de feu")
end
