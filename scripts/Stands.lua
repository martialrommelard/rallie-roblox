-- ============================================================
--  LES STANDS ET LES 6 ECURIES (generateur)
--  A lancer UNE fois dans Studio, en mode Edit, PUIS relancer
--  ProtectionSpawn.lua (la cloture du spawn passe derriere les stands).
--
--  Une 2e ROUTE, entre la ligne droite du depart et le SPAWN :
--    - on y ENTRE juste apres la ligne d arrivee, on en SORT avant le
--      checkpoint 1 : le compte des tours et les checkpoints ne changent
--      pas ;
--    - un MURET DES STANDS (beton + vitrage + drapeaux) la separe de la
--      piste ;
--    - la voie : une VOIE RAPIDE le long du muret, une VOIE DE TRAVAIL
--      devant les garages, avec une ZONE D ARRET peinte devant chacun ;
--    - le BATIMENT DES STANDS : en bas, 6 GARAGES (un par voiture, a son
--      numero et a sa couleur) ; a l etage, une LOGE vitree avec un
--      balcon ; sur le toit, l enseigne et les drapeaux ; cote spawn,
--      une grande facade decoree.
--  S arreter dans SA zone repare un peu la voiture (StandsServeur +
--  Degats) ; dans la voie, la vitesse est limitee.
--
--  Tout se DEDUIT de la route : on prend la ligne droite de D_DEPART
--  (juste apres la ligne d arrivee) a D_FIN (avant le checkpoint 1), et
--  on travaille dans SON repere :
--    d = la distance le long de la ligne droite (dans le sens de la course)
--    x = la distance au milieu de la route, COTE SPAWN.
--  La voie et les sols vont dans Circuit.Stands (on a le droit d y
--  rouler : Voitures et Degats le savent), le reste dans Circuit.Ecuries.
--  Les barrieres de la piste qui bloqueraient l entree et la sortie sont
--  mises de cote dans ServerStorage (avec leur dossier d origine).
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")
local circuit = workspace:WaitForChild("Circuit")
local route   = circuit:WaitForChild("Route")
local spawn   = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SpawnLocation")

-- ---- LES REGLAGES ----
local D_DEPART, D_FIN = "Route10", "Route25"   -- la ligne d arrivee est au 8, le checkpoint 1 au 30
local DEBUT_VOIE, FIN_VOIE = 45, 225   -- la partie droite de la voie (d)
local LONG_RAMPE = 50    -- la longueur de l entree et de la sortie (en biais)
local X_MURET    = 32.3  -- le muret commence la (juste derriere la barriere de la piste)
local EP_MURET   = 2
local LARG_RAPIDE, LARG_TRAVAIL = 12, 10   -- la voie rapide, puis la voie de travail
local NB         = 6     -- une ecurie par voiture
local LARG_BOX   = 24    -- la largeur d un garage (le long de la voie)
local PILIER     = 2     -- les piliers entre deux garages
local PROF_BOX   = 20    -- la profondeur d un garage
local H_BAS      = 12    -- la hauteur du rez-de-chaussee
local H_ETAGE    = 8     -- la hauteur de la loge
local RETRAIT    = 4     -- la loge est en retrait : c est la largeur du balcon
local EP         = 3     -- l epaisseur des sols (ils descendent jusqu au Baseplate)

local EQUIPES = {
	Color3.fromRGB(215, 40, 45), Color3.fromRGB(40, 110, 230), Color3.fromRGB(40, 175, 80),
	Color3.fromRGB(255, 140, 30), Color3.fromRGB(140, 60, 210), Color3.fromRGB(240, 200, 30),
}
local ASPHALTE = Color3.fromRGB(48, 50, 56)
local BETON    = Color3.fromRGB(175, 175, 170)
local BLANC    = Color3.fromRGB(242, 242, 245)
local GRIS     = Color3.fromRGB(62, 65, 74)
local JAUNE    = Color3.fromRGB(255, 205, 40)
local ROUGE    = Color3.fromRGB(210, 35, 40)
local VERRE    = Color3.fromRGB(150, 200, 235)
local NEON     = Color3.fromRGB(0, 225, 255)

-- ---- ON REPART DE ZERO ----
for _, nom in ipairs({"Stands", "Ecuries"}) do
	local ancien = circuit:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
end
local stands = Instance.new("Folder")
stands.Name = "Stands"
local ecuries = Instance.new("Folder")
ecuries.Name = "Ecuries"

-- =========================================================
-- 1. LE REPERE DE LA LIGNE DROITE (x positif = cote spawn)
-- =========================================================
local a, b = route:WaitForChild(D_DEPART), route:WaitForChild(D_FIN)
local avant = ((b.Position - a.Position) * Vector3.new(1, 0, 1)).Unit
local yRoute = a.Position.Y + a.Size.Y / 2
local base = CFrame.lookAt(Vector3.new(a.Position.X, yRoute, a.Position.Z),
	Vector3.new(a.Position.X, yRoute, a.Position.Z) + avant)
-- (mesure : le spawn est bien a droite de la ligne droite, dans le sens de la course)
assert(base.RightVector:Dot(spawn.Position - a.Position) > 0, "le spawn n est pas a droite de la ligne droite")
local demiRoute = a.Size.X / 2
local xVoie1 = X_MURET + EP_MURET + 0.7                 -- le bord de la voie cote muret
local xVoie2 = xVoie1 + LARG_RAPIDE                     -- entre voie rapide et voie de travail
local xFacade = xVoie2 + LARG_TRAVAIL                   -- la facade des garages
local xFondBox = xFacade + PROF_BOX
local xDos = xFondBox + 4                               -- le dos du batiment (cote spawn)
local largVoie = xFacade - xVoie1
local xMilieuVoie = (xVoie1 + xFacade) / 2

local function ici(d, x, y) return base * CFrame.new(x, y or 0, -d) end

local function piece(nom, taille, cf, couleur, matiere, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or ecuries
	return p
end
-- un pave donne par ses bords : d1..d2 (le long), x1..x2 (le cote), y1..y2
local function pave(nom, d1, d2, x1, x2, y1, y2, couleur, matiere, parent)
	return piece(nom, Vector3.new(x2 - x1, y2 - y1, d2 - d1), ici((d1 + d2) / 2, (x1 + x2) / 2, (y1 + y2) / 2), couleur, matiere, parent)
end
-- un texte LISIBLE (2026-10-30) : comme dans Garage.lua, une ligne fait
-- ~125 pixels (Roblox ne fait pas de lettres de plus de 100 pixels),
-- LightInfluence 0 (lisible la nuit), un contour sombre et une marge.
local function tailleFace(p, face)
	local s = p.Size
	if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then return s.X, s.Z end
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then return s.X, s.Y end
	return s.Z, s.Y
end
local function lettres(t, couleur)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = couleur
	local marge = Instance.new("UIPadding")
	marge.PaddingTop, marge.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	marge.PaddingLeft, marge.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	marge.Parent = t
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.Color = Color3.fromRGB(10, 10, 14)
	contour.Transparency = 0.2
	contour.Parent = t
end
local function surface(p, face)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	local _, haut = tailleFace(p, face)
	g.PixelsPerStud = math.clamp(125 / haut, 10, 200)
	g.Parent = p
	return g
end
local function ecrire(p, face, texte, couleur)
	local g = surface(p, face)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.Text = texte
	lettres(t, couleur)
	t.Parent = g
	return g
end
-- le BANDEAU d une ecurie : "ECURIE n" au milieu, et le numero dans une
-- pastille blanche a chaque bout
local function bandeauEcurie(p, face, n, couleur)
	local g = surface(p, face)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.64, 1)
	t.Position = UDim2.fromScale(0.18, 0)
	t.Text = "ÉCURIE " .. n
	lettres(t, Color3.new(1, 1, 1))
	t.Parent = g
	for _, x in ipairs({0.02, 0.98}) do
		local pastille = Instance.new("TextLabel")
		pastille.AnchorPoint = Vector2.new(x, 0.5)
		pastille.Position = UDim2.fromScale(x, 0.5)
		pastille.Size = UDim2.fromScale(1, 0.8)
		pastille.SizeConstraint = Enum.SizeConstraint.RelativeYY     -- un carre
		pastille.BackgroundColor3 = Color3.new(1, 1, 1)
		pastille.Font = Enum.Font.GothamBlack
		pastille.TextScaled = true
		pastille.TextColor3 = couleur
		pastille.Text = tostring(n)
		Instance.new("UICorner", pastille).CornerRadius = UDim.new(0.25, 0)
		pastille.Parent = g
	end
	return g
end
-- une bande peinte au sol, de (d1, x1) a (d2, x2)
local function peinture(nom, d1, x1, d2, x2, largeur, couleur)
	local p1 = ici(d1, x1, 0.02).Position
	local p2 = ici(d2, x2, 0.02).Position
	local l = piece(nom, Vector3.new(largeur, 0.05, (p2 - p1).Magnitude), CFrame.lookAt((p1 + p2) / 2, p2), couleur, nil, stands)
	l.CanCollide = false
	return l
end
-- un sol de la voie, de (d1, x1) a (d2, x2) : son dessus 0.02 sous la route
local function sol(nom, d1, x1, d2, x2, largeur, couleur, matiere)
	local p1 = ici(d1, x1, -0.02 - EP / 2).Position
	local p2 = ici(d2, x2, -0.02 - EP / 2).Position
	return piece(nom, Vector3.new(largeur, EP, (p2 - p1).Magnitude + 2), CFrame.lookAt((p1 + p2) / 2, p2),
		couleur or ASPHALTE, matiere or Enum.Material.Asphalt, stands)
end

-- =========================================================
-- 2. LA VOIE : entree en biais, voie droite, sortie en biais
-- =========================================================
local xEntree = demiRoute - largVoie / 2 - 2           -- dans la piste, au bord
sol("EntreeStands", DEBUT_VOIE - LONG_RAMPE, xEntree, DEBUT_VOIE, xMilieuVoie, largVoie)
sol("VoieStands", DEBUT_VOIE, xMilieuVoie, FIN_VOIE, xMilieuVoie, largVoie)
sol("SortieStands", FIN_VOIE, xMilieuVoie, FIN_VOIE + LONG_RAMPE, xEntree, largVoie)
-- les VIBREURS rouges et blancs le long de l entree et de la sortie (peints)
local function vibreurs(d1, x1, d2, x2)
	local n = math.floor(((d2 - d1) ^ 2 + (x2 - x1) ^ 2) ^ 0.5 / 3)      -- un carreau tous les 3 studs
	for k = 0, n - 1 do
		local t1, t2 = k / n, (k + 1) / n
		peinture("Vibreur", d1 + (d2 - d1) * t1, x1 + (x2 - x1) * t1, d1 + (d2 - d1) * t2, x1 + (x2 - x1) * t2,
			1.2, (k % 2 == 0) and ROUGE or BLANC)
	end
end
local cotes = {-largVoie / 2 + 0.6, largVoie / 2 - 0.6}
for _, c in ipairs(cotes) do
	vibreurs(DEBUT_VOIE - LONG_RAMPE + 4, xEntree + c, DEBUT_VOIE, xMilieuVoie + c)
	vibreurs(FIN_VOIE, xMilieuVoie + c, FIN_VOIE + LONG_RAMPE - 4, xEntree + c)
end
-- les lignes : bords blancs, et la ligne qui separe voie rapide / voie de travail (en pointilles)
peinture("LigneStands", DEBUT_VOIE, xVoie1 + 0.4, FIN_VOIE, xVoie1 + 0.4, 0.5, BLANC)
for d = DEBUT_VOIE + 2, FIN_VOIE - 4, 8 do
	peinture("Pointilles", d, xVoie2, d + 4, xVoie2, 0.4, BLANC)
end
-- "STANDS" et la limite, peints a l entree
local mot = piece("MotStands", Vector3.new(LARG_RAPIDE - 2, 0.05, 8), ici(DEBUT_VOIE + 8, (xVoie1 + xVoie2) / 2, 0.03), ASPHALTE, nil, stands)
mot.CanCollide, mot.Transparency = false, 1
ecrire(mot, Enum.NormalId.Top, "40", BLANC)

-- =========================================================
-- 3. LE MURET DES STANDS : beton, vitrage, et un drapeau par equipe
-- =========================================================
pave("Muret", DEBUT_VOIE, FIN_VOIE, X_MURET, X_MURET + EP_MURET, -1, 3.6, BETON, Enum.Material.Concrete)
pave("BandeMuret", DEBUT_VOIE, FIN_VOIE, X_MURET - 0.05, X_MURET, 0.4, 1.4, ROUGE)   -- une bande rouge cote piste
local vitrage = pave("VitrageMuret", DEBUT_VOIE, FIN_VOIE, X_MURET + 0.85, X_MURET + 1.15, 3.6, 8, VERRE, Enum.Material.Glass)
vitrage.Transparency = 0.55
vitrage.CanQuery = false
for d = DEBUT_VOIE, FIN_VOIE, 10 do
	pave("MontantMuret", d - 0.2, d + 0.2, X_MURET + 0.8, X_MURET + 1.2, 3.6, 8.2, GRIS, Enum.Material.Metal)
end

-- =========================================================
-- 4. LE BATIMENT DES STANDS
-- =========================================================
local longueur = NB * LARG_BOX + (NB + 1) * PILIER
local dA = (DEBUT_VOIE + FIN_VOIE) / 2 - longueur / 2      -- le debut du batiment
local dB = dA + longueur                                    -- sa fin
local yToit = H_BAS + H_ETAGE

-- le sol de tout le batiment (on y roule : dans Stands)
pave("SolGarages", dA, dB, xFacade, xFondBox, -EP - 0.02, -0.02, Color3.fromRGB(95, 98, 108), Enum.Material.SmoothPlastic, stands)

for n = 1, NB do
	local couleur = EQUIPES[(n - 1) % #EQUIPES + 1]
	local d1 = dA + PILIER + (n - 1) * (LARG_BOX + PILIER)
	local d2 = d1 + LARG_BOX
	local dC = (d1 + d2) / 2
	local box = Instance.new("Model")
	box.Name = "Ecurie" .. n
	box:SetAttribute("Numero", n)
	-- la bande de couleur au sol du garage, et le fond
	local bandeSol = pave("SolEquipe", d1 + 1, d2 - 1, xFacade + 2, xFondBox - 1, -0.02, 0.01, couleur, nil, box)
	bandeSol.CanCollide = false
	pave("FondGarage", d1, d2, xFondBox - 0.6, xFondBox, 0, H_BAS, BLANC, nil, box)
	-- le bandeau au-dessus de l ouverture, a la couleur de l equipe
	local bandeau = pave("Bandeau", d1, d2, xFacade - 0.5, xFacade, H_BAS - 2.6, H_BAS, couleur, nil, box)
	bandeauEcurie(bandeau, Enum.NormalId.Left, n, couleur)
	-- le rideau metallique, enroule en haut de l ouverture
	local rideau = piece("Rideau", Vector3.new(LARG_BOX - 0.5, 1.3, 1.3), ici(dC, xFacade + 0.8, H_BAS - 3.3) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(150, 152, 160), Enum.Material.Metal, box)
	rideau.Shape = Enum.PartType.Cylinder
	-- dedans : le grand numero, la lumiere, l etabli, la servante, les pneus
	local grand = pave("GrandNumero", dC - 3.5, dC + 3.5, xFondBox - 0.8, xFondBox - 0.6, 3.5, 10.5, Color3.new(1, 1, 1), nil, box)
	ecrire(grand, Enum.NormalId.Left, tostring(n), couleur)
	local neon = pave("NeonGarage", d1 + 3, d2 - 3, xFacade + 4, xFacade + 4.6, H_BAS - 0.6, H_BAS - 0.3, Color3.new(1, 1, 1), Enum.Material.Neon, box)
	local lumiere = Instance.new("SurfaceLight")
	lumiere.Face, lumiere.Range, lumiere.Brightness, lumiere.Angle = Enum.NormalId.Bottom, 18, 1.4, 120
	lumiere.Parent = neon
	pave("Etabli", dC - 4, dC + 4, xFondBox - 3, xFondBox - 0.6, 3, 3.4, Color3.fromRGB(120, 85, 50), Enum.Material.Wood, box)
	pave("Servante", d1 + 1, d1 + 4, xFondBox - 3, xFondBox - 1, 0, 3.6, couleur, Enum.Material.Metal, box)
	for k = 1, 4 do
		local pneu = piece("Pneu", Vector3.new(1.2, 3.2, 3.2),
			ici(d2 - 2.5, xFondBox - 2.2, 0.6 + (k - 1) * 1.2) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(25, 25, 28), Enum.Material.Rubber, box)
		pneu.Shape = Enum.PartType.Cylinder
	end
	-- le drapeau de l equipe sur le muret, et sur le toit
	for _, x in ipairs({X_MURET + EP_MURET / 2, xDos - 2}) do
		local yPied = (x < xFacade) and 3.6 or yToit + 1
		pave("MatDrapeau", dC - 0.15, dC + 0.15, x - 0.15, x + 0.15, yPied, yPied + 8, GRIS, Enum.Material.Metal, box)
		pave("Drapeau", dC + 0.15, dC + 3.4, x - 0.05, x + 0.05, yPied + 5.8, yPied + 8, couleur, Enum.Material.Fabric, box)
	end
	box.Parent = ecuries

	-- LA ZONE D ARRET (agrandie le 2026-10-30) : toute la LARGEUR DE LA
	-- VOIE (voie rapide comprise), toute la largeur du garage (jusqu au
	-- milieu des piliers : les zones se touchent), et le garage jusqu au
	-- fond. Un grand cadre jaune et le numero sont peints sur la voie. La
	-- piece "ZoneArret" (invisible) : StandsServeur regarde si la voiture
	-- est dedans.
	local z1, z2 = d1 - PILIER / 2, d2 + PILIER / 2
	peinture("CadreArret", d1 + 0.3, xVoie1 + 0.9, d2 - 0.3, xVoie1 + 0.9, 0.5, JAUNE)
	peinture("CadreArret", d1 + 0.3, xVoie1 + 0.9, d1 + 0.3, xFacade - 0.3, 0.5, JAUNE)
	peinture("CadreArret", d2 - 0.3, xVoie1 + 0.9, d2 - 0.3, xFacade - 0.3, 0.5, JAUNE)
	local num = piece("NumeroSol", Vector3.new(10, 0.05, 10), ici(dC, xMilieuVoie, 0.03), ASPHALTE, nil, stands)
	num.CanCollide, num.Transparency = false, 1
	ecrire(num, Enum.NormalId.Top, tostring(n), couleur)
	local zone = pave("ZoneArret", z1, z2, xVoie1, xFondBox - 0.6, 0, 12, couleur, nil, stands)
	zone.Transparency = 1
	zone.CanCollide, zone.CanQuery, zone.CanTouch = false, false, false
	zone:SetAttribute("Numero", n)
end

-- les PILIERS entre les garages (et aux deux bouts), et les cloisons
for k = 0, NB do
	local d = dA + k * (LARG_BOX + PILIER)
	pave("Pilier", d, d + PILIER, xFacade - 0.6, xFondBox, 0, H_BAS, GRIS, Enum.Material.Concrete)
	pave("Cloison", d + 0.5, d + PILIER - 0.5, xFacade, xFondBox, 0, H_BAS, BLANC)
end
-- le couloir de derriere et le dos du batiment (une grande facade cote SPAWN)
pave("Couloir", dA, dB, xFondBox, xDos - 0.5, 0, H_BAS, BETON, Enum.Material.Concrete)
local dos = pave("DosStands", dA, dB, xDos - 0.5, xDos, -1, yToit + 1, BLANC)
local deco = Instance.new("SurfaceGui")
deco.Face = Enum.NormalId.Right            -- cote spawn
deco.PixelsPerStud = 10
deco.LightInfluence = 0
for i, c in ipairs(EQUIPES) do
	local bandeD = Instance.new("Frame")
	bandeD.Size = UDim2.new(1 / (#EQUIPES * 2), 0, 1, 0)
	bandeD.Position = UDim2.new((i - 1) / #EQUIPES + 1 / (#EQUIPES * 4), 0, 0, 0)
	bandeD.BackgroundColor3 = c
	bandeD.BackgroundTransparency = 0.15
	bandeD.BorderSizePixel = 0
	bandeD.Parent = deco
end
local titre = Instance.new("TextLabel")
titre.Size = UDim2.new(0.8, 0, 0.42, 0)
titre.Position = UDim2.new(0.1, 0, 0.2, 0)
titre.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
titre.TextColor3 = Color3.new(1, 1, 1)
titre.Font = Enum.Font.GothamBlack
titre.TextScaled = true
titre.Text = "STANDS"       -- (pas d emoji : sur un panneau, Roblox les affiche en carre)
titre.Parent = deco
local margeTitre = Instance.new("UIPadding")
margeTitre.PaddingTop, margeTitre.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
margeTitre.Parent = titre
Instance.new("UICorner", titre).CornerRadius = UDim.new(0.15, 0)
deco.Parent = dos
-- les deux bouts du batiment
for _, d in ipairs({dA - 0.6, dB}) do
	pave("BoutStands", d, d + 0.6, xFacade - 0.6, xDos, -1, yToit + 1, BLANC)
end

-- L ETAGE : le plancher (avec son neon en dessous), le balcon vitre, la
-- loge vitree en retrait, et le toit
pave("Plancher", dA, dB, xFacade - 0.6, xDos, H_BAS, H_BAS + 0.6, GRIS, Enum.Material.Concrete)
local neonBalcon = pave("NeonBalcon", dA, dB, xFacade - 0.7, xFacade - 0.6, H_BAS - 0.1, H_BAS + 0.1, NEON, Enum.Material.Neon)
neonBalcon.CanCollide = false
local garde = pave("GardeCorps", dA, dB, xFacade - 0.5, xFacade - 0.2, H_BAS + 0.6, H_BAS + 2.8, VERRE, Enum.Material.Glass)
garde.Transparency = 0.5
pave("MainCourante", dA, dB, xFacade - 0.6, xFacade - 0.1, H_BAS + 2.8, H_BAS + 3.1, BLANC, Enum.Material.Metal)
local xLoge = xFacade + RETRAIT
local baie = pave("BaieLoge", dA, dB, xLoge, xLoge + 0.3, H_BAS + 0.6, yToit, VERRE, Enum.Material.Glass)
baie.Transparency = 0.45
for d = dA, dB, (LARG_BOX + PILIER) / 2 do
	pave("MontantLoge", d - 0.25, d + 0.25, xLoge - 0.1, xLoge + 0.4, H_BAS + 0.6, yToit, BLANC, Enum.Material.Metal)
end
pave("FondLoge", dA, dB, xLoge + 0.3, xDos - 0.5, H_BAS + 0.6, yToit, BLANC)    -- la loge est pleine : on ne la visite pas
pave("Toit", dA - 1, dB + 1, xFacade - 1.5, xDos + 0.5, yToit, yToit + 1, GRIS, Enum.Material.Metal)
-- l ENSEIGNE sur le toit, cote piste
local enseigne = pave("EnseigneStands", (dA + dB) / 2 - 30, (dA + dB) / 2 + 30, xFacade + 1, xFacade + 1.6, yToit + 1, yToit + 7, Color3.fromRGB(20, 22, 28))
ecrire(enseigne, Enum.NormalId.Left, "STANDS", Color3.new(1, 1, 1))
local neonEnseigne = pave("NeonEnseigne", (dA + dB) / 2 - 30, (dA + dB) / 2 + 30, xFacade + 0.9, xFacade + 1, yToit + 1, yToit + 1.3, NEON, Enum.Material.Neon)
neonEnseigne.CanCollide = false

-- les PANNEAUX de vitesse, a l entree et a la sortie (sur le muret)
-- (le panneau est en travers de la voie, tourne vers les pilotes qui
-- arrivent : sa face "Back" regarde vers l arriere, d ou ils viennent)
local function panneau(d, texte)
	pave("PoteauPanneau", d - 0.3, d + 0.3, X_MURET + 0.7, X_MURET + 1.3, 3.6, 11, GRIS, Enum.Material.Metal)
	local tableau = pave("TexteVitesse", d - 0.1, d + 0.1, X_MURET + EP_MURET - 0.5, X_MURET + EP_MURET + 3.5, 10, 14, Color3.new(1, 1, 1))
	ecrire(tableau, Enum.NormalId.Back, texte, ROUGE)
	ecrire(tableau, Enum.NormalId.Front, texte, ROUGE)
end
panneau(DEBUT_VOIE + 2, "40")
panneau(FIN_VOIE - 2, "FIN")

-- =========================================================
-- 5. LES BARRIERES DE LA PISTE QUI BLOQUENT l entree et la sortie : mises
--    de cote dans ServerStorage, en notant leur dossier d origine
-- =========================================================
local cote = ServerStorage:FindFirstChild("RetireParLesStands") or Instance.new("Folder")
cote.Name = "RetireParLesStands"
cote.Parent = ServerStorage
stands.Parent = circuit
ecuries.Parent = circuit
local gene = OverlapParams.new()
gene.FilterType = Enum.RaycastFilterType.Include
gene.FilterDescendantsInstances = {circuit:FindFirstChild("Barrieres")}
local retires = 0
for _, z in ipairs({stands:FindFirstChild("EntreeStands"), stands:FindFirstChild("SortieStands")}) do
	local sonde = z:Clone()
	sonde.Size = z.Size + Vector3.new(0, 12, 0)
	sonde.Parent = workspace
	for _, q in ipairs(workspace:GetPartsInPart(sonde, gene)) do
		if q.Parent ~= cote then
			q:SetAttribute("Origine", q.Parent:GetFullName())
			q.Parent = cote
			retires += 1
		end
	end
	sonde:Destroy()
end

print(string.format("Stands (cote spawn) : voie de %d studs, %d garages, batiment de %.0f studs, %d barrieres mises de cote",
	FIN_VOIE - DEBUT_VOIE + 2 * LONG_RAMPE, NB, longueur, retires))
