-- =========================================================
--  L ECLAIRAGE DE NUIT
--  A placer dans ServerScriptService.
--
--  Quand il fait nuit (ou au coucher du soleil) :
--    - des REVERBERES jaunes s allument le long de la route ;
--      dans le TUNNEL, ce sont des lampes accrochees au plafond ;
--    - au SPAWN, les bandes de neon eclairent en BLEU autour d elles.
--  Le jour, tout s eteint.
--
--  Les reverberes sont construits par CE script au lancement du jeu
--  (on ne les voit donc qu en Play) : ils sont DEMANDES A LA ROUTE, un
--  tous les ECART_LAMPE morceaux, au bord exterieur du virage.
--
--  "Il fait nuit ?" : on ecoute l heure de Lighting (ClockTime). Ca marche
--  avec le bouton NUIT du bureau, mais aussi si on change l heure a la main.
-- =========================================================

local Lighting = game:GetService("Lighting")

local ECART_LAMPE   = 4      -- un reverbere tous les 4 morceaux de route (~66 studs)
local ECART_TUNNEL  = 2      -- dans le tunnel, une lampe tous les 2 morceaux
local RECUL_LAMPE   = 4      -- studs entre le bord de la route et le poteau (derriere la barriere)
local HAUT_LAMPE    = 22     -- hauteur du poteau au-dessus de la route
-- le bras va jusqu au MILIEU de la route (elle fait 44 a 80 studs de large :
-- une lampe au bord n eclairait que le bord)
local JAUNE         = Color3.fromRGB(255, 190, 90)
local BLEU          = Color3.fromRGB(40, 120, 255)
local NUIT_DEBUT    = 17.8   -- a partir de 17 h 48 on allume...
local NUIT_FIN      = 6.3    -- ... jusqu a 6 h 18
-- au spawn : les neons qui eclairent en bleu la nuit
local NEONS_SPAWN   = {LigneNeon = true, BandeNeon = true, BordureNeon = true}

local circuit = workspace:WaitForChild("Circuit")
local route   = circuit:WaitForChild("Route")
local zone    = workspace:WaitForChild("ZoneSpawn")

local dossier = workspace:FindFirstChild("Eclairage") or Instance.new("Folder")
dossier.Name = "Eclairage"
dossier:ClearAllChildren()
dossier.Parent = workspace

-- ---- la route, dans l ordre (comme dans PosteDirection) ----
local morceaux = {}
for _, p in ipairs(route:GetChildren()) do
	if p:IsA("BasePart") then table.insert(morceaux, p) end
end
local function numero(p) return tonumber(p.Name:match("%d+")) or 0 end
table.sort(morceaux, function(a, b) return numero(a) < numero(b) end)
local NB = #morceaux

-- les rayons ne doivent voir ni les voitures, ni nos propres lampes
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Exclude
rayon.FilterDescendantsInstances = {workspace:WaitForChild("Voitures"), dossier}

local function piece(nom, taille, cf, couleur, matiere)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.CanQuery = false      -- invisible pour les rayons (cameras du bureau...)
	p.CanTouch = false
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.Metal
	p.CastShadow = false
	p.Parent = dossier
	return p
end

local lumieres = {}   -- toutes les lumieres a allumer / eteindre
local tetes    = {}   -- les tetes de lampe (neon la nuit, plastique le jour)

local function lumiere(classe, parent, couleur, portee, intensite)
	local l = Instance.new(classe)
	l.Color = couleur
	l.Range = portee
	l.Brightness = intensite
	l.Shadows = false   -- pas d ombres : beaucoup plus leger pour l ordinateur
	l.Enabled = false
	l.Parent = parent
	table.insert(lumieres, l)
	return l
end

-- ---- UN REVERBERE au bord du morceau i ----
--        ┌──────┐ <- la tete (neon jaune) eclaire vers le bas
--        │  bras
--        │
--  poteau│
--  ══════╧═══ route
local function reverbere(i)
	local p = morceaux[i]
	local suivant = morceaux[i % NB + 1]
	local precedent = morceaux[(i - 2) % NB + 1]
	local virage = (suivant.Position - p.Position):Cross(p.Position - precedent.Position).Y
	local cote = (virage > 0) and 1 or -1           -- l exterieur du virage
	local droite = p.CFrame.RightVector * cote
	local haut = Vector3.new(0, 1, 0)
	local pied = p.Position + droite * (p.Size.X / 2 + RECUL_LAMPE)
	local yHaut = p.Position.Y + HAUT_LAMPE
	-- le sol sous le poteau (il peut etre plus bas que la route : talus)
	local sol = workspace:Raycast(Vector3.new(pied.X, yHaut, pied.Z), Vector3.new(0, -80, 0), rayon)
	local yBas = sol and sol.Position.Y or p.Position.Y
	-- mais pas plus de 3 studs sous la route : au-dessus d un ravin, ca
	-- faisait des poteaux de 76 studs ! On l accroche au bord de la route.
	yBas = math.max(yBas, p.Position.Y - 3)
	if yBas > yHaut - 4 then return end            -- le poteau serait dans la montagne : on saute
	local longueur = yHaut - yBas
	piece("Poteau", Vector3.new(0.6, longueur, 0.6),
		CFrame.new(pied.X, yBas + longueur / 2, pied.Z), Color3.fromRGB(60, 62, 68))
	local sommet = Vector3.new(pied.X, yHaut, pied.Z)
	local bras = p.Size.X / 2 + RECUL_LAMPE
	local bout = sommet - droite * bras                -- au-dessus du milieu de la route
	piece("Bras", Vector3.new(0.5, 0.5, bras),
		CFrame.lookAt((sommet + bout) / 2, bout), Color3.fromRGB(60, 62, 68))
	local tete = piece("TeteLampe", Vector3.new(2.4, 0.5, 1.4),
		CFrame.lookAt(bout - haut * 0.4, bout - haut * 0.4 + p.CFrame.LookVector), JAUNE, Enum.Material.SmoothPlastic)
	table.insert(tetes, tete)
	local l = lumiere("SpotLight", tete, JAUNE, 60, 4)   -- 60 = la portee maximale de Roblox
	l.Face = Enum.NormalId.Bottom
	l.Angle = 140      -- un cone tres ouvert : un rond de ~60 studs au sol
end

-- ---- UNE LAMPE DE PLAFOND (dans le tunnel) ----
local function lampePlafond(i, plafond)
	local p = morceaux[i]
	local tete = piece("TeteLampe", Vector3.new(6, 0.4, 1),
		CFrame.lookAt(plafond - Vector3.new(0, 0.3, 0), plafond - Vector3.new(0, 0.3, 0) + p.CFrame.RightVector),
		JAUNE, Enum.Material.SmoothPlastic)
	table.insert(tetes, tete)
	lumiere("PointLight", tete, JAUNE, 45, 3)
end

-- ---- on parcourt la route ----
local nbReverberes, nbPlafond = 0, 0
for i = 1, NB do
	local p = morceaux[i]
	-- un plafond au-dessus de la route ? alors on est dans le tunnel
	local dessus = workspace:Raycast(p.Position + Vector3.new(0, 3, 0), Vector3.new(0, 40, 0), rayon)
	if dessus then
		if i % ECART_TUNNEL == 0 then
			lampePlafond(i, dessus.Position)
			nbPlafond += 1
		end
	elseif i % ECART_LAMPE == 0 then
		local avant = #tetes
		reverbere(i)
		if #tetes > avant then nbReverberes += 1 end
	end
end

-- ---- le spawn : du bleu autour des neons ----
local nbBleues = 0
for _, x in ipairs(zone:GetChildren()) do
	if NEONS_SPAWN[x.Name] and x:IsA("BasePart") then
		lumiere("PointLight", x, BLEU, 18, 2.5)
		nbBleues += 1
	end
end

-- ---- allumer / eteindre ----
local allume = nil
local function majEclairage()
	local h = Lighting.ClockTime
	local nuit = h >= NUIT_DEBUT or h < NUIT_FIN
	if nuit == allume then return end
	allume = nuit
	for _, l in ipairs(lumieres) do l.Enabled = nuit end
	for _, t in ipairs(tetes) do
		-- la nuit la tete brille (Neon) ; le jour c est juste du plastique jaune pale
		t.Material = nuit and Enum.Material.Neon or Enum.Material.SmoothPlastic
		t.Color = nuit and JAUNE or Color3.fromRGB(235, 225, 200)
	end
end
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(majEclairage)
majEclairage()

print(string.format("Eclairage de nuit : %d reverberes, %d lampes dans le tunnel, %d lumieres bleues au spawn",
	nbReverberes, nbPlafond, nbBleues))
