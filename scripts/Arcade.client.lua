-- =========================================================
--  LES BORNES D ARCADE DES SIMULATEURS, EN 3D  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  On s assoit au simulateur : la camera se met face a l ecran, et SUR
--  L ECRAN de la borne il y a un jeu de course EN 3D, sur une copie du vrai
--  circuit (route, barrieres, tunnel, arbres, montagne...), vu de derriere
--  la voiture.
--    Z / fleche haut   accelerer          S / fleche bas   freiner, reculer
--    Q / D, fleches    tourner            Espace           se lever (quitter)
--  Sur la route on va vite ; ailleurs, on ralentit. Un tour compte quand on
--  repasse la ligne apres s en etre eloigne.
--
--  COMMENT ON FAIT DE LA 3D DANS UN ECRAN : un ViewportFrame (une fenetre
--  qui montre des pieces 3D) dans le SurfaceGui de l ecran. Dedans, un
--  WorldModel avec la copie du circuit (envoyee par le serveur : a cause du
--  streaming, on ne connait pas tout le circuit ici), une petite voiture,
--  et une camera creee ICI (une camera creee par le serveur donnait un
--  ecran noir : on l a appris avec le podium).
--
--  Le jeu tourne ICI. On envoie au serveur ou est la voiture (10 fois par
--  seconde) : il la recopie sur le siege, et les autres joueurs voient la
--  partie sur l ecran de la borne.
-- =========================================================

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

-- les reglages du jeu
local VMAX_ROUTE = 95     -- studs/s sur la route
local VMAX_HERBE = 28     -- ailleurs
local ACCEL      = 38
local FREIN      = 90
local FROTTEMENT = 14     -- on ralentit tout seul quand on lache l accelerateur
local VIRAGE     = 2.3    -- radians par seconde, a pleine vitesse
local ENVOI      = 0.1    -- on envoie l etat au serveur toutes les 0,1 s
local LOIN       = 300    -- pour qu un tour compte, il faut s etre eloigne de 300 studs de la ligne
local CAM_RECUL, CAM_HAUT = 20, 8     -- la camera du jeu : derriere et au-dessus de la voiture
local DIST_ECRAN = 2.8   -- la camera du joueur : a 2,8 studs de l ecran (devant le volant)

local NEON  = Color3.fromRGB(0, 225, 255)
local OR    = Color3.fromRGB(255, 205, 60)

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local salle  = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")
local arcade = ReplicatedStorage:WaitForChild("Arcade")
local carte  = ReplicatedStorage:WaitForChild("CarteCircuit"):InvokeServer()     -- la ligne et le sens de la course
local pieces3D = ReplicatedStorage:WaitForChild("Circuit3D"):InvokeServer()       -- tout le circuit en 3D

-- ---- LA LIGNE ET LE SENS DE LA COURSE ----
local L = carte.ligne
local avant = {x = 0, z = 1}
do
	local best = math.huge
	for _, m in ipairs(carte.morceaux) do
		local d = (m.x - L.x) ^ 2 + (m.z - L.z) ^ 2
		if d < best then best, avant = d, {x = m.sx, z = m.sz} end
	end
end
local function cote(x, z) return ((x - L.x) * avant.x + (z - L.z) * avant.z) > 0 and 1 or -1 end
local ANGLE0 = math.atan2(avant.x, avant.z)
local yLigne = 0
for _, p in ipairs(pieces3D) do
	if p.route and (p.cf.Position - Vector3.new(L.x, p.cf.Position.Y, L.z)).Magnitude < 30 then yLigne = p.cf.Position.Y + p.taille.Y / 2 end
end

local function enTexte(t)
	return string.format("%d:%05.2f", math.floor(t / 60), t % 60)
end

-- ---- LA PETITE VOITURE (en pieces) ----
local function creerVoiture(parent)
	local m = Instance.new("Model")
	m.Name = "VoitureArcade"
	local function p(nom, taille, cf, couleur, matiere, forme)
		local b = Instance.new("Part")
		b.Name, b.Size, b.CFrame, b.Color = nom, taille, cf, couleur
		b.Material = matiere or Enum.Material.SmoothPlastic
		if forme then b.Shape = forme end
		b.Anchored = true
		b.Parent = m
		return b
	end
	local caisse = p("Caisse", Vector3.new(7, 1.6, 15), CFrame.new(0, 1.4, 0), Color3.fromRGB(215, 30, 30))
	p("Cabine", Vector3.new(5.6, 1.5, 6), CFrame.new(0, 2.9, 1), Color3.fromRGB(20, 25, 35), Enum.Material.Glass)
	p("Aileron", Vector3.new(7.4, 0.25, 1.6), CFrame.new(0, 3.2, 6.6), Color3.fromRGB(20, 20, 22))
	p("Bande", Vector3.new(1.2, 0.05, 15.05), CFrame.new(0, 2.23, 0), Color3.new(1, 1, 1))
	for _, x in ipairs({-3.3, 3.3}) do
		for _, z in ipairs({-4.6, 4.6}) do
			p("Roue", Vector3.new(1.2, 2.4, 2.4), CFrame.new(x, 1.2, z), Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	for _, x in ipairs({-2.4, 2.4}) do
		p("Phare", Vector3.new(1.4, 0.4, 0.1), CFrame.new(x, 1.6, -7.5), Color3.fromRGB(255, 245, 200), Enum.Material.Neon)
	end
	m.PrimaryPart = caisse
	m.Parent = parent
	return m
end

-- ---- L ECRAN D UNE BORNE : un ViewportFrame avec le circuit ----
local function creerEcran(ecran)
	local g = Instance.new("SurfaceGui")
	g.Name = "ArcadeGui"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 100
	g.LightInfluence = 0
	g.Enabled = false
	g.Parent = ecran
	local vue = Instance.new("ViewportFrame")
	vue.Size = UDim2.fromScale(1, 1)
	vue.BackgroundColor3 = Color3.fromRGB(120, 180, 235)      -- le ciel
	vue.BorderSizePixel = 0
	vue.Ambient = Color3.fromRGB(150, 150, 150)
	vue.LightColor = Color3.fromRGB(255, 250, 235)
	vue.LightDirection = Vector3.new(-0.4, -1, -0.3)
	vue.Parent = g
	local monde = Instance.new("WorldModel")
	monde.Parent = vue
	local solides = {}       -- la route et le sol : pour savoir a quelle hauteur on roule
	-- le sol (l herbe), tres grand
	local herbe = Instance.new("Part")
	herbe.Anchored, herbe.Size = true, Vector3.new(4000, 1, 4000)
	herbe.CFrame = CFrame.new(L.x, -2, L.z)
	herbe.Color = Color3.fromRGB(70, 140, 60)
	herbe.Material = Enum.Material.Grass
	herbe.Parent = monde
	table.insert(solides, herbe)
	local route = {}
	for _, d in ipairs(pieces3D) do
		local b = Instance.new(d.classe or "Part")
		b.Anchored = true
		b.Size, b.CFrame, b.Color, b.Material = d.taille, d.cf, d.couleur, d.matiere
		if d.forme and b:IsA("Part") then b.Shape = d.forme end
		b.Parent = monde
		if d.route then table.insert(solides, b); route[b] = true end
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 70
	cam.Parent = vue
	vue.CurrentCamera = cam
	local voiture = creerVoiture(monde)
	local rayons = RaycastParams.new()
	rayons.FilterType = Enum.RaycastFilterType.Include
	rayons.FilterDescendantsInstances = solides
	-- les textes, PAR-DESSUS la 3D
	local function texte(pos, taille, couleur, align)
		local l = Instance.new("TextLabel")
		l.Position, l.Size = pos, taille
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = couleur
		l.TextStrokeTransparency = 0.2
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.ZIndex = 8
		l.Text = ""
		l.Parent = g
		return l
	end
	return {
		gui = g, monde = monde, cam = cam, voiture = voiture, rayons = rayons, route = route,
		chrono  = texte(UDim2.fromOffset(14, 10), UDim2.fromOffset(220, 36), Color3.new(1, 1, 1)),
		tours   = texte(UDim2.fromOffset(14, 48), UDim2.fromOffset(160, 26), NEON),
		record  = texte(UDim2.new(1, -234, 0, 10), UDim2.fromOffset(220, 26), OR, Enum.TextXAlignment.Right),
		vitesse = texte(UDim2.new(1, -184, 1, -46), UDim2.fromOffset(170, 38), NEON, Enum.TextXAlignment.Right),
		message = texte(UDim2.new(0, 20, 0.5, -26), UDim2.new(1, -40, 0, 52), OR, Enum.TextXAlignment.Center),
	}
end

-- la hauteur de la route (ou du sol) sous un point, et si c est la route
local function sol(e, x, z, yAvant)
	local r = e.monde:Raycast(Vector3.new(x, yAvant + 8, z), Vector3.new(0, -60, 0), e.rayons)
	if r then return r.Position.Y, e.route[r.Instance] == true, r.Normal end
	return yAvant, false, Vector3.yAxis       -- rien dessous (le trou du tremplin) : on garde la hauteur
end

-- placer la voiture et la camera du jeu
local function dessiner(e, x, y, z, a, normale, chrono, tours, v, dt)
	local devant = Vector3.new(math.sin(a), 0, math.cos(a))
	-- la voiture suit la pente : son "haut" est la normale de la route
	local n = normale or Vector3.yAxis
	local droite = devant:Cross(n).Unit
	local devantPente = n:Cross(droite).Unit
	local pos = Vector3.new(x, y, z)
	-- le modele a son avant vers -Z : on lui donne X = sa droite, Y = la normale,
	-- Z = vers l arriere (donc -Z = devant)
	e.voiture:PivotTo(CFrame.fromMatrix(pos, droite, n, -devantPente))
	-- la camera, derriere et au-dessus, avec un peu de retard (plus doux)
	local voulu = CFrame.lookAt(pos - devant * CAM_RECUL + Vector3.new(0, CAM_HAUT, 0), pos + devant * 10 + Vector3.new(0, 2, 0))
	e.cam.CFrame = e.cam.CFrame:Lerp(voulu, math.min(1, (dt or 0.016) * 6))
	e.chrono.Text = chrono and enTexte(chrono) or "0:00.00"
	e.tours.Text = "TOUR " .. (tours or 0) + 1
	local rt = salle:GetAttribute("RecordTemps")
	e.record.Text = rt and ("RECORD " .. enTexte(rt)) or ""
	e.vitesse.Text = v and string.format("%d km/h", math.floor(math.abs(v) * 1.5)) or ""
end

-- ---- LES BORNES : chaque siege et son ecran ----
local bornes = {}       -- siege -> {ecran, e (l affichage), serveurGui}
local function trouverBornes()
	for _, siege in ipairs(salle:GetChildren()) do
		if siege.Name == "SiegeSimulateur" and not bornes[siege] then
			local meilleur, d = nil, math.huge
			for _, p in ipairs(salle:GetChildren()) do
				if p.Name == "EcranSimuCentre" then
					local dd = (p.Position - siege.Position).Magnitude
					if dd < d then meilleur, d = p, dd end
				end
			end
			if meilleur then
				bornes[siege] = {ecran = meilleur, e = creerEcran(meilleur), serveurGui = meilleur:FindFirstChildOfClass("SurfaceGui")}
			end
		end
	end
end
task.spawn(function()
	while true do trouverBornes() task.wait(2) end      -- streaming : elles arrivent quand on s approche
end)

-- ---- MA PARTIE ----
local partie = nil
local envoi = 0

-- pendant la partie, on BLOQUE les touches de deplacement du personnage : sinon
-- appuyer sur Z le fait se lever de la borne (on l a vu en essayant). On les
-- "avale" (Sink) avant lui ; notre jeu, lui, lit quand meme leur etat
-- (IsKeyDown). Espace = quitter.
local TOUCHES = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right}
local function bloquer(oui)
	if oui then
		ContextActionService:BindActionAtPriority("BorneArcadeTouches", function() return Enum.ContextActionResult.Sink end,
			false, Enum.ContextActionPriority.High.Value + 50, table.unpack(TOUCHES))
	else
		ContextActionService:UnbindAction("BorneArcadeTouches")
	end
end
UserInputService.InputBegan:Connect(function(entree)
	if entree.KeyCode == Enum.KeyCode.Space and partie then
		local hum = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Sit = false; hum.Jump = true end
	end
end)

local function commencer(siege)
	bloquer(true)
	partie = {siege = siege, x = L.x - avant.x * 14, z = L.z - avant.z * 14, y = yLigne, a = ANGLE0, v = 0,
		chrono0 = nil, tours = 0, loin = 0, cote = -1, message = "ACCELERE !", finMessage = os.clock() + 2.5}
end
local function arreter()
	partie = nil
	bloquer(false)
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

local function touche(...)
	for _, k in ipairs({...}) do if UserInputService:IsKeyDown(k) then return true end end
	return false
end

RunService:BindToRenderStep("BorneArcade", Enum.RenderPriority.Camera.Value + 1, function(dt)
	dt = math.min(dt, 0.05)
	local hum = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local siege = hum and hum.SeatPart
	local assis = siege and siege.Name == "SiegeSimulateur" and bornes[siege] and siege or nil
	if assis and (not partie or partie.siege ~= assis) then commencer(assis) end
	if not assis and partie then arreter() end

	-- MA partie : la conduite
	if partie then
		local p = partie
		local b = bornes[p.siege]
		local gaz = touche(Enum.KeyCode.W, Enum.KeyCode.Up)
		local frein = touche(Enum.KeyCode.S, Enum.KeyCode.Down)
		local tourne = (touche(Enum.KeyCode.D, Enum.KeyCode.Right) and 1 or 0) - (touche(Enum.KeyCode.A, Enum.KeyCode.Left) and 1 or 0)
		local y, surRoute, normale = sol(b.e, p.x, p.z, p.y)
		local vmax = surRoute and VMAX_ROUTE or VMAX_HERBE
		if gaz then p.v += ACCEL * dt elseif p.v > 0 then p.v = math.max(0, p.v - FROTTEMENT * dt) elseif p.v < 0 then p.v = math.min(0, p.v + FROTTEMENT * dt) end
		if frein then p.v -= FREIN * dt end
		if p.v > vmax then p.v = math.max(vmax, p.v - 70 * dt) end      -- hors de la route, on freine fort
		p.v = math.max(p.v, -15)
		-- on tourne d autant mieux qu on roule (et a l envers en marche arriere)
		p.a -= tourne * VIRAGE * dt * math.clamp(math.abs(p.v) / 25, 0, 1) * (p.v >= 0 and 1 or -1)
		p.x += math.sin(p.a) * p.v * dt
		p.z += math.cos(p.a) * p.v * dt
		p.y = p.y + (y - p.y) * math.min(1, dt * 12)                    -- on suit la route, en douceur
		-- la ligne : on la passe dans le bon sens ?
		local c = cote(p.x, p.z)
		local enTravers = math.abs(-(p.x - L.x) * avant.z + (p.z - L.z) * avant.x) < L.long / 2 + 10
		p.loin = math.max(p.loin, math.sqrt((p.x - L.x) ^ 2 + (p.z - L.z) ^ 2))
		if c == 1 and p.cote == -1 and enTravers then
			local maintenant = os.clock()
			if not p.chrono0 then
				p.chrono0, p.loin = maintenant, 0                 -- le chrono demarre
			elseif p.loin > LOIN then
				local t = maintenant - p.chrono0
				p.tours += 1
				arcade:FireServer("tour", t)
				p.message, p.finMessage = "TOUR : " .. enTexte(t), maintenant + 3
				p.chrono0, p.loin = maintenant, 0
			end
		end
		p.cote = c
		local chrono = p.chrono0 and (os.clock() - p.chrono0) or nil
		-- l affichage sur MON ecran (tout de suite, sans attendre le serveur)
		b.e.gui.Enabled = true
		if b.serveurGui then b.serveurGui.Enabled = false end
		dessiner(b.e, p.x, p.y, p.z, p.a, normale, chrono, p.tours, p.v, dt)
		b.e.message.Text = (os.clock() < p.finMessage) and p.message or ""
		-- la camera du JOUEUR : face a l ecran de la borne, qui remplit la vue. On la
		-- met DEVANT le volant (a 4,4 studs de l ecran, elle etait dedans : on ne
		-- voyait rien), et l angle de vue est calcule pour que l ecran remplisse tout.
		local ecran = b.ecran
		local oeil = ecran.Position + ecran.CFrame.LookVector * DIST_ECRAN
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = math.deg(2 * math.atan((ecran.Size.Y / 2 + 0.2) / DIST_ECRAN))
		camera.CFrame = CFrame.lookAt(oeil, ecran.Position)
		-- et on dit au serveur ou on en est
		envoi += dt
		if envoi > ENVOI then
			envoi = 0
			arcade:FireServer("etat", p.x, p.z, p.a, chrono, p.tours)
		end
	end

	-- les AUTRES bornes : la partie des autres joueurs (recopiee par le serveur)
	for siege, b in pairs(bornes) do
		if not partie or partie.siege ~= siege then
			local x, z, a = siege:GetAttribute("X"), siege:GetAttribute("Z"), siege:GetAttribute("A")
			local enJeu = siege:GetAttribute("Pilote") ~= nil and x ~= nil
			b.e.gui.Enabled = enJeu
			if b.serveurGui then b.serveurGui.Enabled = not enJeu end
			if enJeu then
				-- un peu de lissage : on se rapproche de la position recue
				b.lx = b.lx and (b.lx + (x - b.lx) * math.min(1, dt * 10)) or x
				b.lz = b.lz and (b.lz + (z - b.lz) * math.min(1, dt * 10)) or z
				local y, _, normale = sol(b.e, b.lx, b.lz, b.ly or yLigne)
				b.ly = y
				dessiner(b.e, b.lx, y, b.lz, a, normale, siege:GetAttribute("Chrono"), siege:GetAttribute("Tours"), nil, dt)
				b.e.message.Text = ""
			else
				b.lx, b.lz, b.ly = nil, nil, nil
			end
		end
	end
end)
