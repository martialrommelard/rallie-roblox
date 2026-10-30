-- ============================================================
--  LE GARAGE, DANS LA SALLE RONDE SOUS LE SPAWN (generateur)
--  A lancer UNE fois dans Studio, en mode Edit (comme ZoneSpawn ou
--  SalleSousSpawn). On y descend par les deux escaliers derriere le
--  spawn. Il construit dans workspace.ZoneSpawn.Garage :
--    - un sol d atelier en DEMI-ROND qui suit le mur, borde de jaune ;
--    - 4 POSTES DE REPARATION le long du mur rond, tournes vers le
--      centre : un pont elevateur, un ecran, un pupitre, des etincelles ;
--    - au centre, la VITRINE (une voiture sur un plateau tournant) et 2
--      BORNES "Ouvrir le garage" ;
--    - contre le mur du fond : l enseigne, l etabli, les armoires, des pneus.
--  Les regles (acheter, ameliorer, peindre, reparer) sont dans
--  GarageServeur et Garage.client.
--
--  TOUT SUIT LE ROND, et le rond est MESURE : on prend les morceaux du
--  mur (MurRondSalle) et on cherche le cercle qui passe au mieux par eux
--  (centre et rayon). Ensuite on place tout en COORDONNEES POLAIRES :
--  une distance au centre (r) et un angle (a, 0 = droit devant, vers le
--  mur rond ; positif = vers la droite).
--  ⚠️ Il modifie la place : Ctrl+S apres !
--  ⚠️ Si on relance SalleSousSpawn, relancer celui-ci.
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")
local zone  = workspace:WaitForChild("ZoneSpawn")
local salle = zone:WaitForChild("SalleSousSpawn")

-- ---- LES REGLAGES ----
local MARGE_MUR  = 3      -- le sol d atelier s arrete 3 studs avant le mur rond
local PAS_ANGLE  = 3      -- le demi-rond est fait de tranches de 3 degres
local R_NEON     = 40     -- un cercle de neon au sol, entre la vitrine et les postes
local R_POSTES   = 52     -- les postes de reparation, a 52 studs du centre...
local A_POSTES   = {-60, -24, 24, 60}   -- ...a ces angles (degres)
local R_VITRINE  = 20     -- la vitrine, droit devant (angle 0), a 20 studs du centre
local RAYON_DISQUE = 12   -- le rayon du plateau tournant

local BLANC  = Color3.fromRGB(240, 240, 245)
local GRIS   = Color3.fromRGB(70, 74, 82)
local SOMBRE = Color3.fromRGB(45, 47, 54)
local NOIR   = Color3.fromRGB(25, 25, 28)
local NEON   = Color3.fromRGB(0, 225, 255)    -- le meme bleu que les neons de la salle
local JAUNE  = Color3.fromRGB(255, 200, 40)
local ORANGE = Color3.fromRGB(255, 140, 30)
local ROUGE  = Color3.fromRGB(200, 45, 40)

-- ---- ON REPART DE ZERO (le relancer ne fait pas de double) ----
local ancien = zone:FindFirstChild("Garage")
if ancien then ancien:Destroy() end

-- =========================================================
-- 1. LE ROND, MESURE
-- Le cercle qui passe au mieux par les morceaux du mur (methode des
-- "moindres carres", la meme qu un tableur pour tracer une droite).
-- =========================================================
local murs = {}
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "MurRondSalle" then table.insert(murs, p) end
end
assert(#murs >= 3, "pas de mur rond : lancer d abord SalleSousSpawn")
local mx, mz = 0, 0
for _, p in ipairs(murs) do mx += p.Position.X; mz += p.Position.Z end
mx, mz = mx / #murs, mz / #murs
local Suu, Svv, Suv, Suuu, Svvv, Suvv, Svuu = 0, 0, 0, 0, 0, 0, 0
for _, p in ipairs(murs) do
	local u, v = p.Position.X - mx, p.Position.Z - mz
	Suu += u * u; Svv += v * v; Suv += u * v
	Suuu += u ^ 3; Svvv += v ^ 3; Suvv += u * v * v; Svuu += v * u * u
end
local det = Suu * Svv - Suv * Suv
local uc = (0.5 * (Suuu + Suvv) * Svv - 0.5 * (Svvv + Svuu) * Suv) / det
local vc = (Suu * 0.5 * (Svvv + Svuu) - Suv * 0.5 * (Suuu + Suvv)) / det
local epaisseurMur = math.min(murs[1].Size.X, murs[1].Size.Z)
local rayonMur = math.sqrt(uc * uc + vc * vc + (Suu + Svv) / #murs) - epaisseurMur / 2   -- la face interieure

-- le sol, sous le centre : un rayon qui descend
local murFond = salle:WaitForChild("MurFondSalle")
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Include
rayon.FilterDescendantsInstances = {zone}
local haut = Vector3.new(uc + mx, murFond.Position.Y, vc + mz)
local touche = workspace:Raycast(haut, Vector3.new(0, -60, 0), rayon)
assert(touche, "pas de sol au centre du rond")
local centre = Vector3.new(uc + mx, touche.Position.Y, vc + mz)

-- le repere : au centre, -Z = droit devant (du mur du fond vers le rond)
local versDevant = (centre - murFond.Position) * Vector3.new(1, 0, 1)
local base = CFrame.lookAt(centre, centre + versDevant.Unit)
local zFond = base:PointToObjectSpace(murFond.Position).Z - murFond.Size.Z / 2
local R_SOL = rayonMur - MARGE_MUR

-- un repere a la distance r et a l angle a (degres), -Z tourne vers le mur
local function polaire(r, a, y)
	return base * CFrame.Angles(0, -math.rad(a), 0) * CFrame.new(0, y or 0, -r)
end

local garage = Instance.new("Folder")
garage.Name = "Garage"

local function piece(nom, taille, cf, couleur, matiere, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or garage
	return p
end

-- un texte sur une face d une piece, LISIBLE (2026-10-30) :
--  - Roblox ne fait pas de lettres de plus de 100 pixels : on regle les
--    pixels par stud pour qu UNE LIGNE fasse ~125 pixels de haut (avant :
--    25 par stud, les lettres restaient petites sur les grands panneaux) ;
--  - LightInfluence 0 : le texte ne depend pas de la lumiere (lisible
--    dans le sous-sol et la nuit) ;
--  - un contour sombre autour des lettres, et une marge sur les bords.
local function tailleFace(p, face)
	local s = p.Size
	if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then return s.X, s.Z end
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then return s.X, s.Y end
	return s.Z, s.Y
end
local function ecrire(p, face, texte, couleur, nom)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud   -- sinon Roblox ignore PixelsPerStud (cadre fixe 800x600 etire : lettres ecrasees)
	local _, haut = tailleFace(p, face)
	local lignes = select(2, texte:gsub("\n", "")) + 1
	g.PixelsPerStud = math.clamp(125 * lignes / haut, 10, 200)
	local t = Instance.new("TextLabel")
	t.Name = nom or "Texte"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = couleur
	t.Text = texte
	local marge = Instance.new("UIPadding")
	marge.PaddingTop, marge.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	marge.PaddingLeft, marge.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	marge.Parent = t
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.Color = Color3.fromRGB(10, 10, 14)
	contour.Transparency = 0.2
	contour.Parent = t
	t.Parent = g
	g.Parent = p
	return t
end

-- =========================================================
-- 2. LE SOL EN DEMI-ROND
-- Des tranches fines qui partent du centre, comme les parts d une
-- tarte (comme le sol du spawn), + une bande jusqu au mur du fond.
-- =========================================================
local SOL = 0.1
local largeurTranche = 2 * R_SOL * math.tan(math.rad(PAS_ANGLE / 2)) + 0.3
for a = -90, 90, PAS_ANGLE do
	piece("SolGarage", Vector3.new(largeurTranche, SOL, R_SOL), polaire(R_SOL / 2, a, SOL / 2), GRIS)
	-- le bord jaune, et le cercle de neon
	local l = piece("BordSol", Vector3.new(2 * R_SOL * math.sin(math.rad(PAS_ANGLE / 2)) + 0.2, 0.04, 0.6),
		polaire(R_SOL - 0.4, a, SOL + 0.02), JAUNE)
	l.CanCollide = false
	local n = piece("CercleNeon", Vector3.new(2 * R_NEON * math.sin(math.rad(PAS_ANGLE / 2)) + 0.1, 0.04, 0.35),
		polaire(R_NEON, a, SOL + 0.02), NEON, Enum.Material.Neon)
	n.CanCollide = false
end
-- (pas plus large que le mur du fond : sinon elle entre dans les murs d a cote)
local largeurFond = math.min(2 * R_SOL, murFond.Size.X - 0.2)
piece("SolGarage", Vector3.new(largeurFond, SOL, zFond - 0.05), base * CFrame.new(0, SOL / 2, zFond / 2), GRIS)

-- =========================================================
-- 3. LES POSTES DE REPARATION
-- Chacun dans SON repere : -Z vers le mur (le nez de la voiture), +Z
-- vers le centre (la ou on se tient). GarageServeur fait monter les
-- "Bras", allume les etincelles et le gyrophare, ecrit sur l ecran.
-- =========================================================
local function poste(numero, a)
	local m = Instance.new("Model")
	m.Name = "PosteReparation"
	m:SetAttribute("Numero", numero)
	local S = polaire(R_POSTES, a)
	local function ici(x, y, z) return S * CFrame.new(x, y, z) end

	-- le socle, avec des bandes jaunes aux deux bouts
	piece("Socle", Vector3.new(11, 0.3, 21), ici(0, SOL + 0.15, 0), SOMBRE, Enum.Material.DiamondPlate, m)
	for _, z in ipairs({-10.1, 10.1}) do
		piece("BandeSocle", Vector3.new(11, 0.32, 0.8), ici(0, SOL + 0.16, z), JAUNE, nil, m)
	end
	-- les 2 piliers et la traverse du pont
	for _, s in ipairs({-1, 1}) do
		piece("PlatinePilier", Vector3.new(3, 0.4, 3), ici(s * 7.2, SOL + 0.2, 0), SOMBRE, Enum.Material.Metal, m)
		piece("Pilier", Vector3.new(1.6, 12, 1.6), ici(s * 7.2, SOL + 6, 0), ORANGE, Enum.Material.Metal, m)
		-- ce qui MONTE : le chariot sur le pilier et les 2 bras sous la voiture
		piece("Bras", Vector3.new(2.2, 1.4, 2.2), ici(s * 7.2, SOL + 1.2, 0), GRIS, Enum.Material.Metal, m)
		for _, z in ipairs({-3, 3}) do
			piece("Bras", Vector3.new(5.6, 0.4, 0.8), ici(s * 4.2, SOL + 0.7, z), GRIS, Enum.Material.Metal, m)
		end
	end
	piece("Traverse", Vector3.new(16, 0.8, 1.4), ici(0, SOL + 12.4, 0), ORANGE, Enum.Material.Metal, m)

	-- le gyrophare (allume pendant la reparation)
	local gyro = Instance.new("Part")
	gyro.Name = "Gyrophare"
	gyro.Shape = Enum.PartType.Cylinder
	gyro.Size = Vector3.new(0.8, 1.2, 1.2)
	gyro.CFrame = ici(0, SOL + 13.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	gyro.Color = ORANGE
	gyro.Material = Enum.Material.SmoothPlastic
	gyro.Anchored = true
	gyro.Parent = m
	local lumiere = Instance.new("PointLight")
	lumiere.Color = ORANGE
	lumiere.Range = 18
	lumiere.Brightness = 2
	lumiere.Enabled = false
	lumiere.Parent = gyro

	-- l ecran, accroche sous la traverse, tourne vers le centre (+Z)
	local ecran = piece("Ecran", Vector3.new(8, 3.4, 0.3), ici(0, SOL + 10, 0.9), NOIR, nil, m)
	ecrire(ecran, Enum.NormalId.Back, "LIBRE\nAppuie sur E pour réparer", BLANC)
	local titre = piece("TitrePoste", Vector3.new(8, 0.9, 0.3), ici(0, SOL + 12.2, 0.9), NOIR, nil, m)
	ecrire(titre, Enum.NormalId.Back, "POSTE " .. numero, JAUNE)

	-- le pupitre de commande, cote centre, a gauche : c est la qu on appuie
	piece("Pupitre", Vector3.new(1.6, 3.4, 1.2), ici(-8, SOL + 1.7, 9), GRIS, Enum.Material.Metal, m)
	local dessus = piece("BoitierPupitre", Vector3.new(2.2, 0.8, 1.6), ici(-8, SOL + 3.6, 9) * CFrame.Angles(math.rad(25), 0, 0), SOMBRE, nil, m)
	for i, c in ipairs({Color3.fromRGB(60, 220, 90), ROUGE, JAUNE}) do
		piece("BoutonPupitre", Vector3.new(0.35, 0.15, 0.35), dessus.CFrame * CFrame.new(-0.6 + (i - 1) * 0.6, 0.45, 0), c, Enum.Material.Neon, m)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptReparer"
	prompt.ActionText = "Réparer ma voiture"
	prompt.ObjectText = "Poste " .. numero
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = dessus

	-- le chariot a outils, a droite
	piece("ChariotOutils", Vector3.new(2.4, 3, 1.6), ici(8, SOL + 1.5, 9), ROUGE, Enum.Material.Metal, m)
	for k = 1, 3 do
		piece("TiroirChariot", Vector3.new(2.1, 0.12, 0.05), ici(8, SOL + k * 0.85, 9.82), Color3.fromRGB(190, 190, 195), Enum.Material.Metal, m)
	end

	-- les etincelles (eteintes), sur les cotes de la voiture
	for _, x in ipairs({-5, 5}) do
		for _, z in ipairs({-6, 5}) do
			local att = Instance.new("Attachment")
			att.Name = "Etincelles"
			att.Parent = m:FindFirstChild("Socle")     -- d abord le parent, puis la position
			att.WorldCFrame = ici(x, SOL + 2, z)
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), ORANGE)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.15, 0)
			e.Lifetime = NumberRange.new(0.25, 0.5)
			e.Speed = NumberRange.new(8, 14)
			e.SpreadAngle = Vector2.new(60, 60)
			e.Acceleration = Vector3.new(0, -40, 0)
			e.Rate = 35
			e.Enabled = false
			e.Parent = att
		end
	end

	-- le numero, peint au sol devant le poste
	local marque = piece("NumeroSol", Vector3.new(6, 0.04, 2.4), ici(0, SOL + 0.03, 12.6), GRIS, nil, m)
	marque.CanCollide = false
	marque.Transparency = 1
	ecrire(marque, Enum.NormalId.Top, "POSTE " .. numero, JAUNE)

	m.Parent = garage
end
for i, a in ipairs(A_POSTES) do
	poste(i, a)
end

-- =========================================================
-- 4. LA VITRINE, droit devant, et les 2 bornes
-- =========================================================
local centreVitrine = polaire(R_VITRINE, 0, SOL)
local disque = Instance.new("Part")
disque.Name = "PlateauTournant"
disque.Shape = Enum.PartType.Cylinder
disque.Size = Vector3.new(0.6, RAYON_DISQUE * 2, RAYON_DISQUE * 2)
disque.CFrame = centreVitrine * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
disque.Color = Color3.fromRGB(35, 35, 40)
disque.Material = Enum.Material.Metal
disque.Anchored = true
disque.Parent = garage
local anneau = disque:Clone()
anneau.Name = "AnneauNeon"
anneau.Size = Vector3.new(0.5, RAYON_DISQUE * 2 + 1, RAYON_DISQUE * 2 + 1)
anneau.CFrame = disque.CFrame * CFrame.new(-0.1, 0, 0)
anneau.Material = Enum.Material.Neon
anneau.Color = NEON
anneau.Parent = garage

-- la voiture : une copie du modele, sans ses scripts, figee (Anchored),
-- et on ne peut pas s y asseoir. Garage.client la fait tourner et la
-- repeint CHEZ CHAQUE JOUEUR (chacun voit SA voiture).
local modele = ServerStorage:WaitForChild("VoitureModele")
local vitrine = modele:Clone()
vitrine.Name = "VoitureVitrine"
for _, d in ipairs(vitrine:GetDescendants()) do
	if d:IsA("LuaSourceContainer") or d:IsA("RemoteEvent") or d:IsA("Sound") or d:IsA("Constraint") then
		d:Destroy()
	elseif d:IsA("VehicleSeat") or d:IsA("Seat") then
		d.Disabled = true
	end
end
for _, d in ipairs(vitrine:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = true
		d.CanTouch = false
	end
end
-- posee sur le disque : on demande sa boite pour trouver le bas des roues
vitrine.Parent = garage
local boite, taille = vitrine:GetBoundingBox()
local decalage = vitrine:GetPivot():ToObjectSpace(boite)       -- la boite, vue depuis le pivot
local dessusDisque = centreVitrine * CFrame.new(0, 0.6, 0)
local cible = dessusDisque * CFrame.new(0, taille.Y / 2, 0)    -- ou doit etre le centre de la boite
vitrine:PivotTo(cible * decalage:Inverse())
vitrine:SetAttribute("Centre", dessusDisque.Position)
vitrine.ModelStreamingMode = Enum.ModelStreamingMode.Atomic   -- elle arrive d un bloc chez le joueur

local function borne(cf)
	local b = Instance.new("Model")
	b.Name = "BorneGarage"
	local pied = piece("Pied", Vector3.new(3, 3.5, 2), cf * CFrame.new(0, SOL + 1.75, 0), GRIS, Enum.Material.Metal, b)
	piece("Ecran", Vector3.new(2.8, 2, 0.4), cf * CFrame.new(0, SOL + 4.5, 0) * CFrame.Angles(math.rad(20), 0, 0), NEON, Enum.Material.Neon, b)
	local p = Instance.new("ProximityPrompt")
	p.Name = "PromptGarage"
	p.ActionText = "Ouvrir le garage"
	p.ObjectText = "Garage"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = pied
	b.Parent = garage
end
-- de chaque cote de la vitrine, tournees vers le fond (la ou on arrive)
borne(base * CFrame.new(-RAYON_DISQUE - 4, 0, -R_VITRINE + 6) * CFrame.Angles(0, math.rad(180), 0))
borne(base * CFrame.new(RAYON_DISQUE + 4, 0, -R_VITRINE + 6) * CFrame.Angles(0, math.rad(180), 0))

-- =========================================================
-- 5. CONTRE LE MUR DU FOND : enseigne, etabli, armoires, pneus
-- =========================================================
local function fond(x, y, z) return base * CFrame.new(x, y, zFond - z) end
local enseigne = piece("EnseigneGarage", Vector3.new(52, 10, 0.5), fond(0, 25, 0.35), NOIR)
ecrire(enseigne, Enum.NormalId.Front, "GARAGE", NEON)       -- (pas d emoji : sur un panneau, Roblox les affiche en carre)
piece("NeonEnseigne", Vector3.new(54, 0.5, 0.6), fond(0, 19.75, 0.4), NEON, Enum.Material.Neon)
piece("NeonEnseigne", Vector3.new(54, 0.5, 0.6), fond(0, 30.25, 0.4), NEON, Enum.Material.Neon)

piece("Etabli", Vector3.new(20, 0.5, 4), fond(0, SOL + 3.25, 2.5), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
for _, x in ipairs({-9.5, 9.5}) do
	piece("PiedEtabli", Vector3.new(0.6, 3, 3.4), fond(x, SOL + 1.5, 2.5), GRIS, Enum.Material.Metal)
end
piece("PanneauOutils", Vector3.new(20, 6, 0.3), fond(0, SOL + 8, 0.25), ROUGE)
for i = -4, 4 do
	local h = 4 - math.abs(i) * 0.3
	piece("Outil", Vector3.new(0.4, h, 0.2), fond(i * 2, SOL + 6 + h / 2, 0.5), Color3.fromRGB(185, 185, 195), Enum.Material.Metal)
end
for _, x in ipairs({-15, 15}) do
	piece("Armoire", Vector3.new(6, 5, 2), fond(x, SOL + 2.5, 1.2), ROUGE, Enum.Material.Metal)
	for k = 1, 3 do
		piece("Tiroir", Vector3.new(5.2, 0.15, 0.1), fond(x, SOL + k * 1.4, 2.25), Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
	end
end
local function pneus(x, n)
	for i = 1, n do
		local p = Instance.new("Part")
		p.Name = "Pneu"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(1.2, 3.4, 3.4)
		p.CFrame = fond(x, SOL + 0.6 + (i - 1) * 1.2, 2.5) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = NOIR
		p.Material = Enum.Material.Rubber
		p.Anchored = true
		p.Parent = garage
	end
end
for _, x in ipairs({-24, -28, 24, 28}) do
	pneus(x, 4)
end

garage.Parent = zone
print(string.format("Garage : rond mesure (centre %.1f, %.1f ; rayon %.1f), sol en demi-rond de rayon %.1f, %d postes de reparation",
	centre.X, centre.Z, rayonMur, R_SOL, #A_POSTES))
