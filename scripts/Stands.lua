-- ============================================================
--  LES STANDS ET LES 6 ECURIES (generateur)
--  A lancer UNE fois dans Studio, en mode Edit.
--
--  Une 2e ROUTE, a cote de la ligne droite du depart, en face du spawn :
--    - on y ENTRE juste apres la ligne d arrivee, on en SORT avant le
--      checkpoint 1 : le compte des tours et les checkpoints ne changent
--      pas ;
--    - le long de la voie, 6 ECURIES (une par voiture, a son numero et
--      a sa couleur) ; devant chacune, une ZONE D ARRET peinte au sol.
--  S arreter dans SA zone repare un peu la voiture (script
--  StandsServeur + Degats) ; dans la voie, la vitesse est limitee.
--
--  Tout se DEDUIT de la route : on prend la ligne droite du morceau
--  D_DEPART (juste apres la ligne d arrivee) jusqu a celui avant le
--  premier checkpoint, et on travaille dans SON repere :
--    d = la distance le long de la ligne droite (dans le sens de la course)
--    x = le cote (negatif = a gauche, cote oppose au spawn).
--  La voie, ses bords et les sols des ecuries vont dans Circuit.Stands
--  (on a le droit d y rouler : Voitures et Degats le savent). Les
--  batiments vont dans Circuit.Ecuries.
--  Les barrieres de la piste qui bloqueraient l entree et la sortie, et
--  les arbres qui genent, sont mis de cote dans ServerStorage.
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")
local circuit = workspace:WaitForChild("Circuit")
local route   = circuit:WaitForChild("Route")
local spawn   = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SpawnLocation")

-- ---- LES REGLAGES ----
local D_DEPART  = "Route10"   -- la voie commence ici (la ligne d arrivee est au morceau 8)...
local D_FIN     = "Route25"   -- ...et la ligne droite va jusqu ici (le checkpoint 1 est au 30)
local ECART     = 6      -- entre le bord de la piste et le bord de la voie (les barrieres)
local LARG_VOIE = 22     -- la largeur de la voie des stands
local DEBUT_VOIE, FIN_VOIE = 45, 225   -- la partie droite de la voie (d, en studs)
local LONG_RAMPE = 50    -- la longueur de l entree et de la sortie (en biais)
local NB        = 6      -- une ecurie par voiture
local LARG_BOX  = 24     -- la largeur d une ecurie (le long de la voie)
local ESPACE    = 2      -- entre deux ecuries
local PROF_BOX  = 22     -- la profondeur d une ecurie
local H_BOX     = 14     -- sa hauteur
local COULEURS = {
	Color3.fromRGB(215, 40, 45), Color3.fromRGB(40, 110, 230), Color3.fromRGB(40, 175, 80),
	Color3.fromRGB(255, 140, 30), Color3.fromRGB(140, 60, 210), Color3.fromRGB(240, 200, 30),
}
local ASPHALTE = Color3.fromRGB(52, 54, 60)
local BETON    = Color3.fromRGB(170, 170, 165)
local BLANC    = Color3.fromRGB(240, 240, 240)
local JAUNE    = Color3.fromRGB(255, 205, 40)
local GRIS     = Color3.fromRGB(70, 72, 80)

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
-- 1. LE REPERE DE LA LIGNE DROITE
-- =========================================================
local a, b = route:WaitForChild(D_DEPART), route:WaitForChild(D_FIN)
local avant = ((b.Position - a.Position) * Vector3.new(1, 0, 1)).Unit
local yRoute = a.Position.Y + a.Size.Y / 2            -- le dessus de la route
local base = CFrame.lookAt(Vector3.new(a.Position.X, yRoute, a.Position.Z),
	Vector3.new(a.Position.X, yRoute, a.Position.Z) + avant)
-- le spawn doit etre a DROITE (+X) : les stands vont a gauche (-X)
assert(base.RightVector:Dot(spawn.Position - a.Position) > 0, "le spawn n est pas a droite de la ligne droite")
local demiRoute = a.Size.X / 2
local xBordVoie = -(demiRoute + ECART)                 -- le bord de la voie cote piste
local xVoie     = xBordVoie - LARG_VOIE / 2            -- le milieu de la voie
local xFond     = xBordVoie - LARG_VOIE                -- le bord de la voie cote ecuries

-- un repere a (d, x, y) ; il regarde dans le sens de la course
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
	p.Parent = parent
	return p
end
local function ecrire(p, face, texte, couleur, fond)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.PixelsPerStud = 20
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = fond and 0 or 1
	if fond then t.BackgroundColor3 = fond end
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = couleur
	t.Text = texte
	t.Parent = g
	g.Parent = p
	return t
end
-- une bande au sol entre deux points (d, x) -> (d, x)
local function bande(nom, d1, x1, d2, x2, largeur, couleur, parent)
	local p1 = ici(d1, x1, 0.02).Position
	local p2 = ici(d2, x2, 0.02).Position
	local l = piece(nom, Vector3.new(largeur, 0.05, (p2 - p1).Magnitude), CFrame.lookAt((p1 + p2) / 2, p2), couleur, nil, parent)
	l.CanCollide = false
	return l
end

-- =========================================================
-- 2. LA VOIE DES STANDS (on a le droit d y rouler)
-- Son dessus est 0.02 sous la route : la ou elles se chevauchent
-- (l entree, la sortie), c est la route qu on voit.
-- =========================================================
local EP = 3        -- assez epais pour descendre jusqu au sol (le Baseplate est 3 studs sous la route)
local function sol(nom, d1, x1, d2, x2, largeur)
	local p1 = ici(d1, x1, -0.02 - EP / 2).Position
	local p2 = ici(d2, x2, -0.02 - EP / 2).Position
	return piece(nom, Vector3.new(largeur, EP, (p2 - p1).Magnitude + 2), CFrame.lookAt((p1 + p2) / 2, p2), ASPHALTE, Enum.Material.Asphalt, stands)
end
-- l entree (en biais), la voie droite, la sortie (en biais)
local xRoute = -demiRoute + LARG_VOIE / 2 + 2           -- dans la piste, au bord
sol("EntreeStands", DEBUT_VOIE - LONG_RAMPE, xRoute, DEBUT_VOIE, xVoie, LARG_VOIE)
sol("VoieStands", DEBUT_VOIE, xVoie, FIN_VOIE, xVoie, LARG_VOIE)
sol("SortieStands", FIN_VOIE, xVoie, FIN_VOIE + LONG_RAMPE, xRoute, LARG_VOIE)
-- les lignes blanches des bords
bande("LigneStands", DEBUT_VOIE, xBordVoie - 0.4, FIN_VOIE, xBordVoie - 0.4, 0.5, BLANC, stands)
bande("LigneStands", DEBUT_VOIE, xFond + 0.4, FIN_VOIE, xFond + 0.4, 0.5, BLANC, stands)
-- "STANDS" peint a l entree
local mot = piece("MotStands", Vector3.new(LARG_VOIE - 4, 0.05, 7), ici(DEBUT_VOIE + 6, xVoie, 0.03), ASPHALTE, nil, stands)
mot.CanCollide = false
mot.Transparency = 1
ecrire(mot, Enum.NormalId.Top, "STANDS  40", BLANC)

-- =========================================================
-- 3. LES 6 ECURIES
-- =========================================================
local longueur = NB * LARG_BOX + (NB - 1) * ESPACE
local d0 = (DEBUT_VOIE + FIN_VOIE) / 2 - longueur / 2
for n = 1, NB do
	local couleur = COULEURS[(n - 1) % #COULEURS + 1]
	local dC = d0 + (n - 1) * (LARG_BOX + ESPACE) + LARG_BOX / 2      -- le milieu de l ecurie
	local xAv, xAr = xFond, xFond - PROF_BOX                           -- l ouverture, le fond
	local xC = (xAv + xAr) / 2
	local box = Instance.new("Model")
	box.Name = "Ecurie" .. n
	box:SetAttribute("Numero", n)

	-- le sol (on y roule : dans Stands)
	piece("SolEcurie", Vector3.new(PROF_BOX, EP, LARG_BOX + ESPACE), ici(dC, xC, -0.02 - EP / 2), BETON, Enum.Material.Concrete, stands)
	-- les murs : deux cotes et le fond, et le toit qui deborde sur la voie
	for _, s in ipairs({-1, 1}) do
		piece("MurEcurie", Vector3.new(PROF_BOX, H_BOX, 1), ici(dC + s * (LARG_BOX / 2 + 0.5), xC, H_BOX / 2), BLANC, Enum.Material.SmoothPlastic, box)
	end
	piece("FondEcurie", Vector3.new(1, H_BOX, LARG_BOX + 2), ici(dC, xAr - 0.5, H_BOX / 2), BLANC, Enum.Material.SmoothPlastic, box)
	piece("ToitEcurie", Vector3.new(PROF_BOX + 4, 0.8, LARG_BOX + 2), ici(dC, xC + 2, H_BOX + 0.4), GRIS, Enum.Material.Metal, box)
	-- la bande de couleur de l equipe en bas des murs, et l enseigne
	piece("BandeEquipe", Vector3.new(0.2, 1.2, LARG_BOX), ici(dC, xAr + 0.1, 2.5), couleur, Enum.Material.SmoothPlastic, box)
	local enseigne = piece("Enseigne", Vector3.new(0.6, 3, LARG_BOX + 2), ici(dC, xAv + 0.3, H_BOX - 1.5), couleur, Enum.Material.SmoothPlastic, box)
	ecrire(enseigne, Enum.NormalId.Right, "ÉCURIE " .. n, Color3.new(1, 1, 1))
	-- le grand numero au fond, et la lumiere au plafond (LOCALE)
	local grand = piece("GrandNumero", Vector3.new(0.2, 7, 7), ici(dC, xAr + 0.15, 7.5), Color3.new(1, 1, 1), nil, box)
	ecrire(grand, Enum.NormalId.Right, tostring(n), couleur)
	local neon = piece("NeonEcurie", Vector3.new(PROF_BOX - 4, 0.3, 0.6), ici(dC, xC, H_BOX - 0.3), Color3.new(1, 1, 1), Enum.Material.Neon, box)
	local lumiere = Instance.new("SurfaceLight")
	lumiere.Face = Enum.NormalId.Bottom
	lumiere.Range = 18
	lumiere.Brightness = 1.5
	lumiere.Angle = 120
	lumiere.Parent = neon
	-- dedans : une servante d outils, une pile de pneus, un etabli
	piece("Servante", Vector3.new(2, 3.5, 3), ici(dC - LARG_BOX / 2 + 2.5, xAr + 2, 1.75), couleur, Enum.Material.Metal, box)
	for k = 1, 4 do
		local pneu = piece("Pneu", Vector3.new(1.2, 3.2, 3.2),
			ici(dC + LARG_BOX / 2 - 2.5, xAr + 2.2, 0.6 + (k - 1) * 1.2) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(25, 25, 28), Enum.Material.Rubber, box)
		pneu.Shape = Enum.PartType.Cylinder
	end
	piece("Etabli", Vector3.new(2.5, 0.4, 8), ici(dC, xAr + 1.5, 3.2), Color3.fromRGB(120, 85, 50), Enum.Material.Wood, box)
	box.Parent = ecuries

	-- LA ZONE D ARRET, sur la voie devant l ecurie : un cadre jaune et le
	-- numero peints au sol. La piece "ZoneArret" (invisible) couvre la zone
	-- ET l ecurie : StandsServeur regarde si la voiture est dedans.
	local zd1, zd2 = dC - LARG_BOX / 2 + 1, dC + LARG_BOX / 2 - 1
	local zx1, zx2 = xBordVoie - 3, xFond + 1
	bande("CadreArret", zd1, zx1, zd2, zx1, 0.4, JAUNE, stands)
	bande("CadreArret", zd1, zx2, zd2, zx2, 0.4, JAUNE, stands)
	bande("CadreArret", zd1, zx1, zd1, zx2, 0.4, JAUNE, stands)
	bande("CadreArret", zd2, zx1, zd2, zx2, 0.4, JAUNE, stands)
	local num = piece("NumeroSol", Vector3.new(7, 0.05, 7), ici(dC, xVoie, 0.03), ASPHALTE, nil, stands)
	num.CanCollide = false
	num.Transparency = 1
	ecrire(num, Enum.NormalId.Top, tostring(n), couleur)
	local zone = piece("ZoneArret", Vector3.new(zx1 - (xAr), 8, LARG_BOX - 2), ici(dC, (zx1 + xAr) / 2, 4), couleur, nil, stands)
	zone.Transparency = 1
	zone.CanCollide, zone.CanQuery, zone.CanTouch = false, false, false
	zone:SetAttribute("Numero", n)
end

-- un toit continu derriere les ecuries (le batiment), et le panneau d entree
piece("Batiment", Vector3.new(4, H_BOX + 2, longueur + 4), ici((DEBUT_VOIE + FIN_VOIE) / 2, xFond - PROF_BOX - 2, (H_BOX + 2) / 2), GRIS, Enum.Material.Concrete, ecuries)
local poteau = piece("PoteauPanneau", Vector3.new(0.8, 12, 0.8), ici(DEBUT_VOIE - LONG_RAMPE - 5, xBordVoie - 3, 6), GRIS, Enum.Material.Metal, ecuries)
local panneau = piece("PanneauStands", Vector3.new(0.4, 4, 9), ici(DEBUT_VOIE - LONG_RAMPE - 5, xBordVoie - 3, 13), Color3.fromRGB(20, 20, 24), nil, ecuries)
ecrire(panneau, Enum.NormalId.Right, "STANDS ↙  40", JAUNE)
ecrire(panneau, Enum.NormalId.Left, "STANDS ↙  40", JAUNE)
poteau.CanCollide = true

-- =========================================================
-- 4. CE QUI GENE : les barrieres de la piste a l entree et a la sortie,
--    et les arbres sur le chantier. On les met de cote dans ServerStorage.
-- =========================================================
local cote = ServerStorage:FindFirstChild("RetireParLesStands") or Instance.new("Folder")
cote.Name = "RetireParLesStands"
cote.Parent = ServerStorage
local gene = OverlapParams.new()
gene.FilterType = Enum.RaycastFilterType.Include
gene.FilterDescendantsInstances = {circuit:FindFirstChild("Barrieres"), circuit:FindFirstChild("Decor")}
stands.Parent = circuit
ecuries.Parent = circuit
local retires = 0
for _, z in ipairs({stands:FindFirstChild("EntreeStands"), stands:FindFirstChild("SortieStands")}) do
	local sonde = z:Clone()
	sonde.Size = z.Size + Vector3.new(0, 12, 0)    -- les barrieres sont au-dessus du sol
	sonde.Parent = workspace
	for _, q in ipairs(workspace:GetPartsInPart(sonde, gene)) do
		if q.Parent then q.Parent = cote; retires += 1 end
	end
	sonde:Destroy()
end
-- les arbres (des modeles du Decor) qui touchent les stands ou les ecuries
local zoneTravaux = Instance.new("Part")
zoneTravaux.Anchored = true
zoneTravaux.Size = Vector3.new(LARG_VOIE + PROF_BOX + 12, 40, FIN_VOIE - DEBUT_VOIE + 2 * LONG_RAMPE)
zoneTravaux.CFrame = ici((DEBUT_VOIE + FIN_VOIE) / 2, (xBordVoie + xFond - PROF_BOX) / 2, 20)
zoneTravaux.Parent = workspace
local decor = circuit:FindFirstChild("Decor")
for _, q in ipairs(workspace:GetPartsInPart(zoneTravaux, gene)) do
	local m = q
	while m.Parent and m.Parent ~= decor and m.Parent ~= circuit:FindFirstChild("Barrieres") do m = m.Parent end
	if m.Parent == decor then m.Parent = cote; retires += 1 end
end
zoneTravaux:Destroy()

print(string.format("Stands : voie de %d studs, %d ecuries, %d objets mis de cote (barrieres de l entree / sortie, arbres)",
	FIN_VOIE - DEBUT_VOIE + 2 * LONG_RAMPE, NB, retires))
