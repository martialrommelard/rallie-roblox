-- ============================================================
--  LA FLASH (generateur de carrosserie)
--  A lancer UNE fois dans Studio, en mode Edit, APRES VoitureRally.lua.
--
--  Une voiture de COURSE SUR CIRCUIT (style "stock-car" des dessins
--  animes), pour changer de la voiture de rally :
--    - rouge vif, jantes rouges ;
--    - de GRANDS YEUX sur le pare-brise ;
--    - un ECLAIR jaune-orange sur chaque flanc, avec le numero dessus ;
--    - plus d accessoires de rally (rampe de phares, arceau, pare-boue,
--      crochets, prise d air du toit, "RALLYE").
--
--  On ne refait PAS une voiture de zero : on COPIE ServerStorage.VoitureModele
--  (memes roues, memes ressorts, meme moteur, memes morceaux qui cassent)
--  et on la rhabille. Elle est rangee dans ServerStorage.VoitureFlash, avec
--  l attribut "Carrosserie" : DepartCourse la sort quand un joueur a choisi
--  la Flash au garage, et le script Degats y prend les morceaux a remettre.
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")

local NOM        = "VoitureFlash"
local ROUGE      = Color3.fromRGB(205, 20, 28)
local JANTE      = Color3.fromRGB(170, 20, 25)
local JAUNE      = Color3.fromRGB(255, 214, 30)
local ORANGE     = Color3.fromRGB(255, 125, 20)
local SOMBRE     = Color3.fromRGB(20, 20, 24)
local PPS        = 40          -- pixels par stud des dessins (yeux, eclairs)

-- les pieces de rally qu on enleve
local A_ENLEVER = {
	RampePhares = true, PhareRampe = true, PriseToit = true,
	ArceauG = true, ArceauD = true, ArceauHaut = true,
	PareBoueG = true, PareBoueD = true, CrochetAv = true, CrochetAr = true,
}
-- les dessins "RALLYE" qu on enleve (le SurfaceGui "Deco" de ces pieces)
local SANS_DECO = {Caisse = true, PareBrise = true, PortiereG = true, PortiereD = true}

-- ---- ON REPART DE ZERO ----
local ancien = ServerStorage:FindFirstChild(NOM)
if ancien then ancien:Destroy() end
local v = ServerStorage:WaitForChild("VoitureModele"):Clone()
v.Name = NOM
v:SetAttribute("Carrosserie", NOM)
local chassis = v:WaitForChild("Chassis")

-- 1. ON ENLEVE le rally
local enleves = 0
for _, p in ipairs(v:GetDescendants()) do
	if p:IsA("BasePart") and A_ENLEVER[p.Name] then
		p:Destroy()
		enleves += 1
	end
end
for _, p in ipairs(v:GetChildren()) do
	if SANS_DECO[p.Name] then
		for _, g in ipairs(p:GetChildren()) do
			if g:IsA("SurfaceGui") and g.Name == "Deco" then g:Destroy() end
		end
	end
end

-- 2. LA PEINTURE : rouge partout ou on peint, jantes rouges
for _, p in ipairs(v:GetDescendants()) do
	if p:IsA("BasePart") then
		if p:GetAttribute("Peinture") then p.Color = ROUGE end
		if p.Name:match("^Jante") then p.Color = JANTE end
	end
end

-- une piece de DESSIN (invisible, juste un support pour le SurfaceGui),
-- soudee au chassis comme les autres, et qui appartient au MEME morceau
-- que la piece qu elle recouvre (elle tombe avec elle)
local function support(nom, taille, cf, morceau)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Massless = true
	p:SetAttribute("Morceau", morceau)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = chassis, p
	w.Parent = p
	p.Parent = v
	return p
end
local function dessin(p, face)
	local g = Instance.new("SurfaceGui")
	g.Name = "Deco"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud   -- sinon les dessins sont ecrases
	g.PixelsPerStud = PPS
	g.LightInfluence = 0.3
	g.Parent = p
	return g
end
local function rond(parent, taille, position, couleur)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size, f.Position = taille, position
	f.BackgroundColor3 = couleur
	f.BorderSizePixel = 0
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
	f.Parent = parent
	return f
end

-- =========================================================
-- 3. LES YEUX, sur le pare-brise
-- Le support est pose a plat sur le pare-brise, sa face avant vers
-- l exterieur, son "haut" vers le toit (le dessin est donc dans le bon sens)
-- =========================================================
local pb = v:WaitForChild("PareBrise")
local dehors = pb.CFrame.UpVector                   -- la face du dessus du pare-brise regarde dehors
local versToit = -pb.CFrame.LookVector              -- (mesure : le -Z du pare-brise descend vers le capot)
local vZ = -dehors
local cfYeux = CFrame.fromMatrix(pb.Position + dehors * (pb.Size.Y / 2 + 0.03), versToit:Cross(vZ), versToit, vZ)
local yeux = support("Yeux", Vector3.new(pb.Size.X - 0.3, pb.Size.Z - 0.2, 0.05), cfYeux, pb:GetAttribute("Morceau"))
local gYeux = dessin(yeux, Enum.NormalId.Front)
for i, x in ipairs({0.27, 0.73}) do
	local blanc = rond(gYeux, UDim2.fromScale(0.43, 0.86), UDim2.fromScale(x, 0.52), Color3.fromRGB(250, 250, 250))
	local contour = Instance.new("UIStroke")
	contour.Thickness = 4
	contour.Color = SOMBRE
	contour.Parent = blanc
	-- l iris (bleu), un peu tourne vers le milieu, la pupille, le reflet
	local iris = rond(blanc, UDim2.fromScale(0.7, 0.7), UDim2.fromScale((i == 1) and 0.6 or 0.4, 0.55), Color3.fromRGB(45, 125, 225))
	iris.SizeConstraint = Enum.SizeConstraint.RelativeYY
	rond(iris, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), SOMBRE)
	rond(iris, UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.68, 0.3), Color3.new(1, 1, 1))
end

-- =========================================================
-- 4. LES ECLAIRS, sur les flancs (entre les deux passages de roue)
-- =========================================================
-- Un trait epais de (u1, y1) a (u2, y2) : u = 0 a l arriere, 1 a l avant ;
-- y = 0 en haut, 1 en bas. "avantAGauche" : sur le flanc gauche, quand on
-- le regarde, l avant de la voiture est a GAUCHE du dessin (et a droite
-- sur l autre flanc) : on retourne les u.
local function trait(g, l, h, avantAGauche, u1, y1, u2, y2, epaisseur)
	if avantAGauche then u1, u2 = 1 - u1, 1 - u2 end
	local a = Vector2.new(u1 * l, y1 * h)
	local b = Vector2.new(u2 * l, y2 * h)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset((b - a).Magnitude + epaisseur * h * 0.5, epaisseur * h)
	f.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	local degrade = Instance.new("UIGradient")
	degrade.Color = ColorSequence.new(ORANGE, JAUNE)
	degrade.Rotation = avantAGauche and 180 or 0      -- orange a l arriere, jaune vers la pointe
	degrade.Parent = f
	f.Parent = g
end

local caisse = v:WaitForChild("Caisse")
for _, cote in ipairs({{"G", -1, Enum.NormalId.Left}, {"D", 1, Enum.NormalId.Right}}) do
	local portiere = v:FindFirstChild("Portiere" .. cote[1])
	-- de l arriere de l aile avant a l avant de l aile arriere
	local aileAv = v:FindFirstChild("AileAvAr" .. cote[1])
	local aileAr = v:FindFirstChild("AileArAv" .. cote[1])
	local zAv = chassis.CFrame:PointToObjectSpace(aileAv.Position).Z + aileAv.Size.Z / 2 + 0.1
	local zAr = chassis.CFrame:PointToObjectSpace(aileAr.Position).Z - aileAr.Size.Z / 2 - 0.1
	local xp = chassis.CFrame:PointToObjectSpace(portiere.Position).X + cote[2] * (portiere.Size.X / 2 + 0.03)
	local yBas = chassis.CFrame:PointToObjectSpace(caisse.Position).Y - caisse.Size.Y / 2 + 0.1
	local yHaut = chassis.CFrame:PointToObjectSpace(caisse.Position).Y + caisse.Size.Y / 2 + 0.1
	local l, h = zAr - zAv, yHaut - yBas
	local p = support("Eclair" .. cote[1], Vector3.new(0.05, h, l),
		chassis.CFrame * CFrame.new(xp, (yBas + yHaut) / 2, (zAv + zAr) / 2), portiere:GetAttribute("Morceau"))
	local g = dessin(p, cote[3])
	local L, H = l * PPS, h * PPS
	local aGauche = (cote[1] == "G")
	-- le zigzag : epais a l arriere, pointu a l avant
	trait(g, L, H, aGauche, 0.02, 0.36, 0.50, 0.60, 0.34)
	trait(g, L, H, aGauche, 0.47, 0.64, 0.58, 0.36, 0.24)
	trait(g, L, H, aGauche, 0.55, 0.40, 0.99, 0.52, 0.14)
	-- le numero, par-dessus (s appelle "Numero" : le script Voitures y
	-- ecrit le numero de la place sur la grille)
	local n = Instance.new("TextLabel")
	n.Name = "Numero"
	n.AnchorPoint = Vector2.new(0.5, 0.5)
	n.Position = UDim2.fromScale(0.5, 0.5)
	n.Size = UDim2.fromScale(0.3, 1)
	n.BackgroundTransparency = 1
	n.Font = Enum.Font.GothamBlack
	n.TextScaled = true
	n.TextColor3 = Color3.new(1, 1, 1)
	n.Text = "0"
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.Color = SOMBRE
	contour.Parent = n
	n.Parent = g
end

v.Parent = ServerStorage
local nb = 0
for _, p in ipairs(v:GetDescendants()) do if p:IsA("BasePart") then nb += 1 end end
print(string.format("Flash : %d pieces de rally enlevees, yeux + 2 eclairs ajoutes, %d pieces (ServerStorage.%s)", enleves, nb, NOM))
