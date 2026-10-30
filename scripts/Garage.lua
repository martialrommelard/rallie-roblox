-- ============================================================
--  LE GARAGE, DANS LA SALLE SOUS LE SPAWN (generateur)
--  A lancer UNE fois dans Studio, en mode Edit (comme ZoneSpawn ou
--  SalleSousSpawn). On y descend par les deux escaliers derriere le
--  spawn. Il construit dans workspace.ZoneSpawn.Garage :
--    - un sol d atelier gris, borde de lignes jaunes ;
--    - la VITRINE : une Jesko sur un plateau tournant ;
--    - 2 BORNES "Ouvrir le garage" ;
--    - le decor : enseigne, etabli, armoires, piles de pneus, 2 ponts.
--  Les regles (acheter, ameliorer, peindre) sont dans GarageServeur et
--  Garage.client.
--
--  Tout se DEDUIT des pieces deja la : le CENTRE est sous le
--  SpawnLocation, le SOL est trouve par un rayon, et le DEVANT est la
--  direction qui part du mur du fond (MurFondSalle) vers le centre. On
--  travaille dans ce repere : base * CFrame.new(x, y, z), avec -Z vers
--  le mur rond (cote piste) et +Z vers le mur du fond.
--  ⚠️ Il modifie la place : Ctrl+S apres !
--  ⚠️ Si on relance SalleSousSpawn, relancer celui-ci.
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")
local zone  = workspace:WaitForChild("ZoneSpawn")
local salle = zone:WaitForChild("SalleSousSpawn")

-- ---- LES REGLAGES (dans le repere du garage) ----
local X_ZONE    = 40      -- le sol d atelier va de -40 a +40 en X...
local Z_AVANT   = -38     -- ...et de -38 (vers le mur rond)
local Z_ARRIERE = 30      -- a +30 (vers le mur du fond)
local Z_VITRINE = -6      -- le plateau tournant
local R_VITRINE = 13

local BLANC = Color3.fromRGB(240, 240, 245)
local GRIS  = Color3.fromRGB(70, 74, 82)
local NOIR  = Color3.fromRGB(25, 25, 28)
local NEON  = Color3.fromRGB(0, 225, 255)    -- le meme bleu que les neons de la salle
local JAUNE = Color3.fromRGB(255, 200, 40)
local ROUGE = Color3.fromRGB(200, 45, 40)

-- ---- ON REPART DE ZERO (le relancer ne fait pas de double) ----
local ancien = zone:FindFirstChild("Garage")
if ancien then ancien:Destroy() end

-- ---- LE REPERE ----
local spawn  = zone:WaitForChild("SpawnLocation")
local murFond = salle:WaitForChild("MurFondSalle")
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Include
rayon.FilterDescendantsInstances = {zone}
-- le sol de la salle, sous le spawn : un rayon qui part sous le plafond
local haut = Vector3.new(spawn.Position.X, murFond.Position.Y, spawn.Position.Z)
local touche = workspace:Raycast(haut, Vector3.new(0, -60, 0), rayon)
assert(touche, "pas de sol sous le spawn : lancer d abord SalleSousSpawn")
local centre = Vector3.new(spawn.Position.X, touche.Position.Y, spawn.Position.Z)
-- le devant : du mur du fond vers le centre, a plat
local versDevant = (centre - murFond.Position) * Vector3.new(1, 0, 1)
local base = CFrame.lookAt(centre, centre + versDevant.Unit)
-- le mur du fond, vu dans ce repere : sa face cote salle
local zFond = base:PointToObjectSpace(murFond.Position).Z - murFond.Size.Z / 2

local garage = Instance.new("Folder")
garage.Name = "Garage"

-- Un pave dans le repere du garage, donne par ses bords
local function pave(nom, x1, x2, y1, y2, z1, z2, couleur, matiere, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = Vector3.new(x2 - x1, y2 - y1, z2 - z1)
	p.CFrame = base * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or garage
	return p
end

-- Un texte sur une face d une piece
local function ecrire(p, face, texte, couleur)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.PixelsPerStud = 20
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = couleur
	t.Text = texte
	t.Parent = g
	g.Parent = p
end

-- ============================================================
-- 1. LE SOL D ATELIER, borde de jaune
-- ============================================================
local SOL = 0.1    -- son epaisseur, pose sur le sol noir de la salle
local sol = pave("SolGarage", -X_ZONE, X_ZONE, 0, SOL, Z_AVANT, Z_ARRIERE, GRIS)
sol.Reflectance = 0.08
for _, b in ipairs({
	{-X_ZONE, X_ZONE, Z_AVANT, Z_AVANT + 0.6}, {-X_ZONE, X_ZONE, Z_ARRIERE - 0.6, Z_ARRIERE},
	{-X_ZONE, -X_ZONE + 0.6, Z_AVANT, Z_ARRIERE}, {X_ZONE - 0.6, X_ZONE, Z_AVANT, Z_ARRIERE},
}) do
	local l = pave("LigneSol", b[1], b[2], SOL, SOL + 0.02, b[3], b[4], JAUNE)
	l.CanCollide = false
end

-- ============================================================
-- 2. L ENSEIGNE, en grand sur le mur du fond
-- ============================================================
local enseigne = pave("EnseigneGarage", -26, 26, 20, 30, zFond - 0.6, zFond - 0.1, NOIR)
ecrire(enseigne, Enum.NormalId.Front, "🔧 GARAGE", NEON)
pave("NeonEnseigne", -27, 27, 19.5, 20, zFond - 0.7, zFond - 0.1, NEON, Enum.Material.Neon)
pave("NeonEnseigne", -27, 27, 30, 30.5, zFond - 0.7, zFond - 0.1, NEON, Enum.Material.Neon)

-- ============================================================
-- 3. LA VITRINE : une Jesko sur un plateau tournant
-- ============================================================
local centreVitrine = base * CFrame.new(0, SOL, Z_VITRINE)
local disque = Instance.new("Part")
disque.Name = "PlateauTournant"
disque.Shape = Enum.PartType.Cylinder
disque.Size = Vector3.new(0.6, R_VITRINE * 2, R_VITRINE * 2)
disque.CFrame = centreVitrine * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
disque.Color = Color3.fromRGB(35, 35, 40)
disque.Material = Enum.Material.Metal
disque.Anchored = true
disque.Parent = garage
local anneau = disque:Clone()
anneau.Name = "AnneauNeon"
anneau.Size = Vector3.new(0.5, R_VITRINE * 2 + 1, R_VITRINE * 2 + 1)
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

-- ============================================================
-- 4. LES BORNES "OUVRIR LE GARAGE", devant la vitrine
-- ============================================================
local function borne(x, z)
	local b = Instance.new("Model")
	b.Name = "BorneGarage"
	pave("Pied", x - 1.5, x + 1.5, SOL, SOL + 3.5, z - 1, z + 1, GRIS, Enum.Material.Metal, b)
	local ecran = pave("Ecran", x - 1.4, x + 1.4, SOL + 3.5, SOL + 5.5, z - 0.2, z + 0.2, NEON, Enum.Material.Neon, b)
	ecran.CFrame = ecran.CFrame * CFrame.Angles(math.rad(20), 0, 0)
	local p = Instance.new("ProximityPrompt")
	p.Name = "PromptGarage"
	p.ActionText = "Ouvrir le garage"
	p.ObjectText = "Garage"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = b.Pied
	b.Parent = garage
end
borne(-14, Z_VITRINE + R_VITRINE + 5)
borne(14, Z_VITRINE + R_VITRINE + 5)

-- ============================================================
-- 5. LE DECOR
-- ============================================================
-- l etabli et le panneau a outils, contre le mur du fond (sous l enseigne)
local zEtabli = zFond - 2.5
pave("Etabli", -10, 10, SOL + 3, SOL + 3.5, zEtabli - 2, zEtabli + 2, Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
for _, x in ipairs({-9.5, 9.5}) do
	pave("PiedEtabli", x - 0.3, x + 0.3, SOL, SOL + 3, zEtabli - 1.7, zEtabli + 1.7, GRIS, Enum.Material.Metal)
end
pave("PanneauOutils", -10, 10, SOL + 5, SOL + 11, zFond - 0.4, zFond - 0.1, ROUGE)
for i = -4, 4 do
	pave("Outil", i * 2 - 0.2, i * 2 + 0.2, SOL + 6, SOL + 10 - math.abs(i) * 0.3, zFond - 0.6, zFond - 0.4,
		Color3.fromRGB(185, 185, 195), Enum.Material.Metal)
end
-- les armoires rouges, de chaque cote de l etabli
for _, x in ipairs({-15, 15}) do
	pave("Armoire", x - 3, x + 3, SOL, SOL + 5, zFond - 2.2, zFond - 0.1, ROUGE, Enum.Material.Metal)
	for k = 1, 3 do
		pave("Tiroir", x - 2.6, x + 2.6, SOL + k * 1.4, SOL + k * 1.4 + 0.15, zFond - 2.3, zFond - 2.2, Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
	end
end
-- des piles de pneus
local function pneus(x, z, n)
	for i = 1, n do
		local p = Instance.new("Part")
		p.Name = "Pneu"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(1.2, 3.4, 3.4)
		p.CFrame = base * CFrame.new(x, SOL + 0.6 + (i - 1) * 1.2, z) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = NOIR
		p.Material = Enum.Material.Rubber
		p.Anchored = true
		p.Parent = garage
	end
end
for _, x in ipairs({-36, -32, -28, 28, 32, 36}) do
	pneus(x, Z_ARRIERE - 3, 4)
end
-- deux ponts elevateurs (le decor d un vrai garage), sur les cotes
local function pont(x)
	for _, z in ipairs({-8, 8}) do
		pave("PilierPont", x - 0.8, x + 0.8, SOL, SOL + 12, z - 0.8, z + 0.8, JAUNE, Enum.Material.Metal)
		pave("BrasPont", x - 4, x + 4, SOL + 3, SOL + 3.4, z - 0.4, z + 0.4, GRIS, Enum.Material.Metal)
	end
	pave("TraversePont", x - 0.6, x + 0.6, SOL + 12, SOL + 13, -9, 9, JAUNE, Enum.Material.Metal)
end
pont(-30)
pont(30)

garage.Parent = zone
print(string.format("Garage : atelier de %d x %d studs sous le spawn (sol a Y = %.2f), vitrine et 2 bornes",
	X_ZONE * 2, Z_ARRIERE - Z_AVANT, centre.Y))
