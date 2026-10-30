-- ============================================================
--  NOTRE VOITURE DE RALLY (generateur)
--  A lancer UNE fois dans Studio, en mode Edit. Il construit la voiture
--  dans ServerStorage, sous le nom "VoitureModele" : c est celle que
--  les scripts Voitures, DepartCourse, Garage... utilisent deja.
--  L ancienne (la Jesko du Toolbox) est gardee a cote, renommee
--  "VoitureJesko" : on peut revenir en arriere.
--
--  UNE PETITE COMPACTE DE RALLY : ailes elargies, grand aileron, prise
--  d air sur le capot, pare-boue, arceau dans l habitacle, numero sur
--  les portieres.
--
--  CHAQUE MORCEAU EST UNE VRAIE PIECE, a nous : capot, pare-chocs,
--  portieres, ailes, phares, aileron... et les 4 roues. Chacun porte
--  l attribut "Morceau" (son nom) : le script Degats s en sert pour les
--  abimer et les arracher. Les pieces a repeindre (garage) portent
--  l attribut "Peinture".
--
--  COMMENT ELLE ROULE (la partie physique) :
--    CHASSIS (lourd et bas : elle se retourne moins)
--      | glissiere verticale (PrismaticConstraint) + RESSORT
--    FUSEE (une piece invisible par roue)
--      | charniere MOTEUR (Motor : "tourne a telle vitesse"). A l avant,
--      | on fait pivoter son attache pour BRAQUER.
--    ROUE
--  Le script ConduiteRally (copie dans la voiture) pilote les moteurs et
--  la direction selon ce que le joueur appuie.
--
--  Toutes les mesures sont dans le repere de la voiture : le sol a
--  y = 0, l avant vers -Z, la gauche vers -X.
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")

-- ---- LES REGLAGES ----
local R_ROUE   = 1.5      -- le rayon des roues
local L_ROUE   = 1.3      -- leur largeur
local X_ROUE   = 3.3      -- les roues a 3.3 studs du milieu (gauche / droite)
local Z_AV, Z_AR = -5.2, 5.0   -- l essieu avant et l essieu arriere
local TASSEMENT = 0.4     -- de combien les ressorts s enfoncent a l arret
local COURSE_HAUT, COURSE_BAS = 0.6, 0.8   -- jusqu ou la roue peut monter / descendre
local HAUT_PIVOT = 1.63   -- le pivot du modele, au-dessus du sol (comme l ancienne : Voitures s en sert)
local MASSE_PILOTE = 12   -- le personnage assis (pour regler les ressorts)

local BLANC = Color3.fromRGB(240, 240, 245)    -- la peinture (le garage la change)
local NOIR  = Color3.fromRGB(28, 28, 32)
local GRIS  = Color3.fromRGB(70, 72, 80)
local METAL = Color3.fromRGB(170, 172, 180)
local VITRE = Color3.fromRGB(40, 60, 85)
local BLEU  = Color3.fromRGB(30, 90, 220)       -- la bande de deco

-- ---- ON MET L ANCIENNE DE COTE ----
local ancienne = ServerStorage:FindFirstChild("VoitureModele")
if ancienne and ancienne:FindFirstChild("A-Chassis Tune", true) then
	local jesko = ServerStorage:FindFirstChild("VoitureJesko")
	if jesko then jesko:Destroy() end
	ancienne.Name = "VoitureJesko"
elseif ancienne then
	ancienne:Destroy()          -- une version precedente de NOTRE voiture : on la refait
end

local voiture = Instance.new("Model")
voiture.Name = "VoitureModele"

local function piece(nom, taille, cf, couleur, matiere, morceau)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored = false
	if morceau then p:SetAttribute("Morceau", morceau) end
	p.Parent = voiture
	return p
end
local function en(x, y, z) return CFrame.new(x, y, z) end
local function penche(x, y, z, degres) return CFrame.new(x, y, z) * CFrame.Angles(math.rad(degres), 0, 0) end

-- =========================================================
-- 1. LE CHASSIS : lourd et bas. C est LUI qui frotte par terre si on
--    perd une roue.
-- =========================================================
local chassis = piece("Chassis", Vector3.new(5, 0.6, 14.6), en(0, 1.35, 0), GRIS, Enum.Material.Metal)
chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0.7, 0, 1, 1)   -- densite 3 : lourd
voiture.PrimaryPart = chassis

-- =========================================================
-- 2. LA CARROSSERIE (soudee au chassis, sans poids : "Massless")
-- =========================================================
local carrosserie = {}
local function caisse(nom, taille, cf, couleur, matiere, morceau, peinture)
	local p = piece(nom, taille, cf, couleur, matiere, morceau)
	if peinture then p:SetAttribute("Peinture", true) end
	table.insert(carrosserie, p)
	return p
end
-- une piece en PENTE (WedgePart). Mesure : une Wedge est haute a
-- l arriere (+Z) et basse a l avant (-Z). "versArriere" la retourne
-- (basse a l arriere).
local function pente(nom, taille, cf, couleur, matiere, morceau, peinture, versArriere)
	local p = Instance.new("WedgePart")
	p.Name = nom
	p.Size = taille
	p.CFrame = versArriere and (cf * CFrame.Angles(0, math.pi, 0)) or cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = false
	if morceau then p:SetAttribute("Morceau", morceau) end
	if peinture then p:SetAttribute("Peinture", true) end
	p.Parent = voiture
	table.insert(carrosserie, p)
	return p
end
-- un cylindre (phares ronds, crochets...) : son axe est l axe X de la piece
local function rond(nom, taille, cf, couleur, matiere, morceau)
	local p = caisse(nom, taille, cf, couleur, matiere, morceau)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- un texte ou une deco sur une face
local function deco(p, face, construire)
	local g = Instance.new("SurfaceGui")
	g.Name = "Deco"
	g.Face = face
	g.PixelsPerStud = 40
	construire(g)
	g.Parent = p
	return g
end
local function texte(parent, t, taille, position, couleur, fond)
	local l = Instance.new("TextLabel")
	l.Size, l.Position = taille, position
	l.BackgroundTransparency = fond and 0 or 1
	if fond then l.BackgroundColor3 = fond end
	l.TextColor3 = couleur
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = t
	l.Parent = parent
	return l
end
local function bande(parent, taille, position, couleur, rotation)
	local f = Instance.new("Frame")
	f.Size, f.Position = taille, position
	f.BackgroundColor3 = couleur
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end

local ROUGE = Color3.fromRGB(215, 30, 35)
local OR    = Color3.fromRGB(220, 175, 60)
local PHARE = Color3.fromRGB(255, 250, 215)

-- ---- LA CAISSE (pas un morceau : elle ne tombe pas) ----
local corps = caisse("Caisse", Vector3.new(6.2, 1.6, 12.4), en(0, 2.45, 0.2), BLANC, nil, nil, true)
caisse("Plancher", Vector3.new(6.0, 0.2, 12.0), en(0, 1.75, 0.2), NOIR)
-- les bas de caisse noirs (entre les roues)
for _, s in ipairs({-1, 1}) do
	caisse("BasDeCaisse", Vector3.new(0.4, 0.45, 6.4), en(s * 3.12, 1.85, -0.1), NOIR)
end
-- la DECO de rally sur les flancs : deux bandes en biais et "RALLYE"
for _, face in ipairs({Enum.NormalId.Left, Enum.NormalId.Right}) do
	deco(corps, face, function(g)
		bande(g, UDim2.new(0.18, 0, 1.6, 0), UDim2.new(0.12, 0, -0.3, 0), BLEU, 25)
		bande(g, UDim2.new(0.06, 0, 1.6, 0), UDim2.new(0.33, 0, -0.3, 0), ROUGE, 25)
		texte(g, "RALLYE", UDim2.new(0.22, 0, 0.32, 0), UDim2.new(0.72, 0, 0.12, 0), NOIR)
	end)
end

-- ---- L AVANT : un nez qui plonge ----
pente("Nez", Vector3.new(6.2, 0.55, 1.0), en(0, 3.0, -6.3), BLANC, nil, "Capot", true, false)
caisse("Capot", Vector3.new(6.0, 0.25, 3.4), penche(0, 3.35, -4.3, -4), BLANC, nil, "Capot", true)
caisse("PriseAir", Vector3.new(1.8, 0.3, 1.2), penche(0, 3.58, -3.9, -4), NOIR, nil, "Capot")
-- la RAMPE DE PHARES sur le capot (pour les speciales de nuit)
caisse("RampePhares", Vector3.new(4.6, 0.25, 0.3), en(0, 3.62, -5.6), NOIR, nil, "Rampe de phares")
for i = -1.5, 1.5 do
	rond("PhareRampe", Vector3.new(0.3, 0.7, 0.7), en(i * 1.1, 3.95, -5.65) * CFrame.Angles(0, math.rad(90), 0), PHARE, Enum.Material.Neon, "Rampe de phares")
end
-- le pare-chocs, sa LAME (splitter), ses prises d air, la plaque, le crochet
caisse("PareChocsAv", Vector3.new(6.4, 1.1, 0.8), en(0, 1.95, -6.75), NOIR, nil, "Pare-chocs avant")
caisse("Lame", Vector3.new(6.8, 0.12, 1.0), en(0, 1.42, -7.0), NOIR, Enum.Material.Metal, "Pare-chocs avant")
for _, s in ipairs({-1, 1}) do
	caisse("PriseAirAv", Vector3.new(1.3, 0.5, 0.06), en(s * 2.2, 1.95, -7.17), Color3.fromRGB(10, 10, 12), nil, "Pare-chocs avant")
end
local plaqueAv = caisse("PlaqueAv", Vector3.new(1.6, 0.4, 0.06), en(0, 1.95, -7.18), Color3.new(1, 1, 1), nil, "Pare-chocs avant")
deco(plaqueAv, Enum.NormalId.Front, function(g) texte(g, "RALLYE 0", UDim2.fromScale(1, 1), UDim2.new(), NOIR).Name = "Numero" end)
caisse("CrochetAv", Vector3.new(0.25, 0.25, 0.5), en(2.9, 1.65, -7.3), ROUGE, Enum.Material.Metal)
caisse("Calandre", Vector3.new(2.6, 0.6, 0.15), en(0, 2.65, -6.45), NOIR)
caisse("PhareG", Vector3.new(1.4, 0.5, 0.2), en(-2.2, 2.75, -6.45), PHARE, Enum.Material.Neon, "Phare gauche")
caisse("PhareD", Vector3.new(1.4, 0.5, 0.2), en(2.2, 2.75, -6.45), PHARE, Enum.Material.Neon, "Phare droit")

-- ---- L HABITACLE ----
local parebrise = caisse("PareBrise", Vector3.new(5.6, 0.15, 2.72), penche(0, 4.35, -2.0, -54), VITRE, Enum.Material.Glass, "Pare-brise")
parebrise.Transparency = 0.45
-- le bandeau en haut du pare-brise
deco(parebrise, Enum.NormalId.Top, function(g)
	texte(g, "RALLYE", UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1), NOIR)
end)
caisse("Toit", Vector3.new(5.6, 0.25, 3.6), en(0, 5.55, 0.6), BLANC, nil, nil, true)
pente("PriseToit", Vector3.new(1.4, 0.4, 1.0), en(0, 5.87, -0.6), NOIR, nil, nil, nil, true)   -- l air frais pour le pilote
local lunette = caisse("LunetteAr", Vector3.new(5.4, 0.15, 2.94), penche(0, 4.38, 3.4, 47), VITRE, Enum.Material.Glass, "Lunette arrière")
lunette.Transparency = 0.45
-- les MONTANTS noirs autour des vitres (avant, milieu, arriere) et sur le toit
for _, s in ipairs({-1, 1}) do
	caisse("MontantAv", Vector3.new(0.25, 0.25, 2.75), penche(s * 2.8, 4.35, -2.0, -54), NOIR)
	caisse("MontantMilieu", Vector3.new(0.25, 2.1, 0.3), en(s * 2.85, 4.4, 0.3), NOIR)
	caisse("MontantAr", Vector3.new(0.25, 0.25, 2.95), penche(s * 2.75, 4.38, 3.4, 47), NOIR)
	caisse("BordToit", Vector3.new(0.25, 0.3, 3.6), en(s * 2.8, 5.5, 0.6), NOIR)
end

for _, s in ipairs({-1, 1}) do
	local g = (s < 0) and "gauche" or "droite"      -- (une portiere droite)
	local gm = (s < 0) and "gauche" or "droit"      -- (un retroviseur droit)
	local G = (s < 0) and "G" or "D"
	local vitre = caisse("Vitre" .. G, Vector3.new(0.15, 2.1, 4.2), en(s * 2.85, 4.33, 0.5), VITRE, Enum.Material.Glass, "Portière " .. g)
	vitre.Transparency = 0.45
	-- la portiere, avec le numero (le script Voitures l ecrit)
	local porte = caisse("Portiere" .. G, Vector3.new(0.2, 1.5, 4.0), en(s * 3.15, 2.5, -0.2), BLANC, nil, "Portière " .. g, true)
	deco(porte, (s < 0) and Enum.NormalId.Left or Enum.NormalId.Right, function(gui)
		bande(gui, UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.7, 0), BLEU)
		local rond = texte(gui, "0", UDim2.new(0.3, 0, 0.55, 0), UDim2.new(0.35, 0, 0.08, 0), NOIR, Color3.new(1, 1, 1))
		rond.Name = "Numero"
		Instance.new("UICorner", rond).CornerRadius = UDim.new(0.5, 0)
	end)
	-- le retroviseur, sur sa tige
	caisse("Retro" .. G, Vector3.new(0.55, 0.4, 0.25), en(s * 3.45, 3.85, -1.7), BLANC, nil, "Rétroviseur " .. gm, true)
	caisse("TigeRetro" .. G, Vector3.new(0.5, 0.12, 0.12), en(s * 3.1, 3.75, -1.7), NOIR, nil, "Rétroviseur " .. gm)
	-- les AILES ELARGIES : elles entourent la roue (un dessus + deux pentes)
	for _, a in ipairs({{"AileAv", Z_AV, "Aile avant " .. g}, {"AileAr", Z_AR, "Aile arrière " .. g}}) do
		local z = a[2]
		caisse(a[1] .. G, Vector3.new(1.0, 0.35, 2.2), en(s * 3.6, 3.32, z), BLANC, nil, a[3], true)
		pente(a[1] .. "Av" .. G, Vector3.new(1.0, 1.2, 0.9), en(s * 3.6, 2.75, z - 1.55), BLANC, nil, a[3], true, false)
		pente(a[1] .. "Ar" .. G, Vector3.new(1.0, 1.2, 0.9), en(s * 3.6, 2.75, z + 1.55), BLANC, nil, a[3], true, true)
		caisse(a[1] .. "Bord" .. G, Vector3.new(1.05, 0.12, 2.2), en(s * 3.62, 3.12, z), NOIR, nil, a[3])
	end
	-- l arriere
	caisse("FeuAr" .. G, Vector3.new(1.2, 0.5, 0.15), en(s * 2.3, 2.85, 6.45), Color3.fromRGB(230, 30, 30), Enum.Material.Neon, "Feu arrière " .. gm)
	local boue = caisse("PareBoue" .. G, Vector3.new(1.1, 1.1, 0.1), en(s * 3.4, 0.95, 6.3), ROUGE, nil, "Pare-boue " .. gm)
	boue.CanCollide = false     -- il descend a 0.4 du sol : il ne doit pas accrocher la route
	deco(boue, Enum.NormalId.Back, function(gui) texte(gui, "RALLYE", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.3), Color3.new(1, 1, 1)) end)
	-- l aileron : ses pieds et ses DERIVES (les plaques au bout)
	caisse("PiedAileron" .. G, Vector3.new(0.2, 1.9, 0.6), en(s * 2.0, 4.45, 5.6), NOIR, nil, "Aileron")
	caisse("Derive" .. G, Vector3.new(0.15, 1.0, 1.7), en(s * 3.12, 5.35, 5.65), NOIR, nil, "Aileron")
	-- l arceau (dans l habitacle)
	caisse("Arceau" .. G, Vector3.new(0.2, 3.1, 0.2), en(s * 2.55, 3.95, 1.6), ROUGE, Enum.Material.Metal)
end

-- ---- L ARRIERE ----
caisse("Hayon", Vector3.new(5.8, 0.25, 2.0), en(0, 3.35, 5.4), BLANC, nil, "Hayon", true)
caisse("PareChocsAr", Vector3.new(6.4, 1.0, 0.7), en(0, 1.95, 6.75), NOIR, nil, "Pare-chocs arrière")
-- le DIFFUSEUR (sous le pare-chocs, avec ses ailettes)
caisse("Diffuseur", Vector3.new(5.2, 0.3, 0.9), en(0, 1.42, 6.9), NOIR, Enum.Material.Metal, "Pare-chocs arrière")
for i = -2, 2 do
	caisse("Ailette", Vector3.new(0.1, 0.4, 0.9), en(i * 1.0, 1.25, 6.9), NOIR, Enum.Material.Metal, "Pare-chocs arrière")
end
local plaqueAr = caisse("PlaqueAr", Vector3.new(1.6, 0.4, 0.06), en(0, 2.2, 7.12), Color3.new(1, 1, 1), nil, "Pare-chocs arrière")
deco(plaqueAr, Enum.NormalId.Back, function(g) texte(g, "RALLYE 0", UDim2.fromScale(1, 1), UDim2.new(), NOIR).Name = "Numero" end)
caisse("CrochetAr", Vector3.new(0.25, 0.25, 0.5), en(-2.9, 1.65, 7.2), ROUGE, Enum.Material.Metal)
caisse("Aileron", Vector3.new(6.2, 0.2, 1.4), en(0, 5.5, 5.6), BLANC, nil, "Aileron", true)
caisse("ArceauHaut", Vector3.new(5.1, 0.2, 0.2), en(0, 5.4, 1.6), ROUGE, Enum.Material.Metal)
caisse("Tableau", Vector3.new(5.6, 0.6, 0.8), en(0, 3.0, -2.6), NOIR)
caisse("SiegeCopilote", Vector3.new(1.6, 1.6, 1.4), en(1.3, 2.6, 0.5), NOIR)
rond("Echappement", Vector3.new(1.0, 0.45, 0.45), en(2.0, 1.5, 7.2) * CFrame.Angles(0, math.rad(90), 0), METAL, Enum.Material.Metal)
rond("Volant", Vector3.new(0.15, 1.0, 1.0), en(-1.2, 3.3, -2.05) * CFrame.Angles(math.rad(-30), math.rad(90), 0), NOIR)

-- le siege du pilote (a gauche), bas : sinon sa tete depasse du toit
local siege = Instance.new("VehicleSeat")
siege.Name = "DriveSeat"               -- (l epicerie le cherche sous ce nom)
siege.Size = Vector3.new(1.6, 0.4, 1.6)
siege.CFrame = en(-1.2, 1.85, 0.4)
siege.Color = NOIR
siege.MaxSpeed, siege.Torque, siege.TurnSpeed = 0, 0, 0   -- c est NOTRE script qui conduit
siege.HeadsUpDisplay = false
siege.Parent = voiture
table.insert(carrosserie, siege)

-- le son du moteur (le meme que l ancienne voiture : il se charge bien)
local son = Instance.new("Sound")
son.Name = "SonMoteur"
son.SoundId = "rbxassetid://2478816735"
son.Looped = true
son.Volume = 0
son.RollOffMaxDistance = 150
son.Playing = true
son.Parent = siege

-- tout est soude au chassis, sans poids, et peut toucher (pour les degats)
for _, p in ipairs(carrosserie) do
	p.Massless = true
	p.CanTouch = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = chassis, p
	w.Parent = p
end

-- =========================================================
-- 3. LES 4 ROUES ET LEUR SUSPENSION
-- =========================================================
local function attache(partie, nom, cf, axe, axe2)
	local a = Instance.new("Attachment")
	a.Name = nom
	a.Parent = partie
	a.WorldCFrame = cf
	if axe then a.Axis, a.SecondaryAxis = axe, axe2 end
	return a
end
local HAUT, DEVANT = Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)

local roues = {}
for _, w in ipairs({
	{nom = "AvG", x = -X_ROUE, z = Z_AV, avant = true, morceau = "Roue avant gauche"},
	{nom = "AvD", x = X_ROUE, z = Z_AV, avant = true, morceau = "Roue avant droite"},
	{nom = "ArG", x = -X_ROUE, z = Z_AR, avant = false, morceau = "Roue arrière gauche"},
	{nom = "ArD", x = X_ROUE, z = Z_AR, avant = false, morceau = "Roue arrière droite"},
}) do
	local centre = en(w.x, R_ROUE, w.z)

	-- la fusee : monte et descend sur sa glissiere, tenue par le ressort.
	-- Assez LOURDE (5) : une piece minuscule entre le chassis (131) et la
	-- roue (11) fait trembler la physique (les roues partaient dans tous
	-- les sens).
	local fusee = piece("Fusee" .. w.nom, Vector3.new(1, 1, 1), centre, GRIS)
	fusee.Transparency, fusee.CanCollide = 1, false
	fusee.CustomPhysicalProperties = PhysicalProperties.new(5, 0.3, 0, 1, 1)
	local glissiere = Instance.new("PrismaticConstraint")
	glissiere.Name = "Glissiere" .. w.nom
	glissiere.Attachment0 = attache(chassis, "Susp" .. w.nom, centre, HAUT, DEVANT)
	glissiere.Attachment1 = attache(fusee, "Susp", centre, HAUT, DEVANT)
	glissiere.LimitsEnabled = true
	glissiere.LowerLimit, glissiere.UpperLimit = -COURSE_BAS, COURSE_HAUT
	glissiere.Parent = fusee
	local ressort = Instance.new("SpringConstraint")
	ressort.Name = "Ressort" .. w.nom
	ressort.Attachment0 = attache(chassis, "Ressort" .. w.nom, centre + Vector3.new(0, 2, 0))
	ressort.Attachment1 = attache(fusee, "Ressort", centre)
	ressort.Parent = fusee

	-- a l avant, la DIRECTION : pas de charniere en plus (elle tremblait).
	-- La roue tourne autour de l axe de son attache sur la fusee : pour
	-- braquer, PiloteRally fait pivoter CETTE attache ("AttMoteur" de la
	-- fusee). L axe de la roue suit, la roue tourne a gauche ou a droite.
	local porte = fusee

	-- la roue (un cylindre couche : son axe est l axe X, de gauche a droite)
	local roue = piece("Roue" .. w.nom, Vector3.new(L_ROUE, R_ROUE * 2, R_ROUE * 2), centre, NOIR, Enum.Material.SmoothPlastic, w.morceau)
	roue.Shape = Enum.PartType.Cylinder
	-- densite, FROTTEMENT (2 = le maximum : ca accroche), rebond, poids du frottement, poids du rebond
	roue.CustomPhysicalProperties = PhysicalProperties.new(1.2, 2, 0, 100, 1)
	roue.CanTouch = true
	local jante = piece("Jante" .. w.nom, Vector3.new(L_ROUE + 0.04, R_ROUE * 1.2, R_ROUE * 1.2), centre, OR, Enum.Material.Metal, w.morceau)   -- jantes dorees, comme en rally
	jante.Shape = Enum.PartType.Cylinder
	jante.CanCollide, jante.Massless = false, true
	local sj = Instance.new("WeldConstraint")
	sj.Part0, sj.Part1 = roue, jante
	sj.Parent = jante
	local moteur = Instance.new("HingeConstraint")
	moteur.Name = "Moteur"
	moteur.ActuatorType = Enum.ActuatorType.Motor
	-- (les attaches ne s appellent PAS "Moteur" : le script de conduite
	-- cherche "Moteur" dans la roue et trouvait l attache a la place !)
	moteur.Attachment0 = attache(porte, "AttMoteur", centre)
	moteur.Attachment1 = attache(roue, "AttMoteur", centre)
	moteur.MotorMaxTorque = 0
	moteur.AngularVelocity = 0
	moteur.Parent = roue
	table.insert(roues, {roue = roue, jante = jante, fusee = fusee, porte = porte, ressort = ressort})
end

-- les roues ne doivent pas cogner leur propre voiture (elles depassent
-- un peu dans les ailes) : une "non-collision" entre chaque roue et
-- chaque piece qui touche de la voiture
for _, r in ipairs(roues) do
	for _, p in ipairs(voiture:GetDescendants()) do
		if p:IsA("BasePart") and p ~= r.roue and p.CanCollide then
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0, nc.Part1 = r.roue, p
			nc.Parent = r.roue
		end
	end
end

-- =========================================================
-- 4. LES RESSORTS, REGLES PAR LE CALCUL
-- Chaque ressort porte un quart de la voiture (sans les roues) + le
-- pilote. Raideur = poids / tassement voulu. Amortissement : la moitie
-- du "critique" (au-dessus, ca ne rebondit plus du tout).
-- =========================================================
local masse = MASSE_PILOTE
for _, p in ipairs(voiture:GetDescendants()) do
	if p:IsA("BasePart") and not p.Massless and not p.Name:match("^Roue") then
		masse += p:GetMass()
	end
end
local poidsParRoue = masse / 4 * workspace.Gravity
local raideur = poidsParRoue / TASSEMENT
local amorti = 0.5 * 2 * math.sqrt(raideur * masse / 4)
for _, r in ipairs(roues) do
	r.ressort.Stiffness = raideur
	r.ressort.Damping = amorti
	r.ressort.FreeLength = 2 + TASSEMENT       -- a l arret : 2 studs, il pousse juste ce qu il faut
end

-- =========================================================
-- 5. LE SCRIPT DE CONDUITE, et le pivot
-- =========================================================
local conduite = ServerStorage:WaitForChild("Outils"):WaitForChild("ConduiteRally"):Clone()
conduite.Name = "Conduite"
conduite.Enabled = true
conduite.Parent = voiture

voiture.WorldPivot = CFrame.new(0, HAUT_PIVOT, 0)    -- l avant vers -Z
voiture.Parent = ServerStorage

print(string.format("Voiture de rally : %d pieces, masse %.0f, ressorts %.0f (amortis %.0f)",
	#voiture:GetDescendants(), masse, raideur, amorti))
