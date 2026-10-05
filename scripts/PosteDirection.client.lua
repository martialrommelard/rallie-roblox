-- =========================================================
--  LE POSTE DE DIRECTION DE COURSE  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Il fait deux choses :
--   1. quand JE m assois a un bureau : le menu de la direction de course
--      (cameras, pilotes, meteo) et je pilote la camera ;
--   2. pour TOUT LE MONDE : la pluie, dessinee autour de MA camera.
--
--  L ecran ne decide de rien : il DEMANDE au serveur (RemoteEvent
--  "Commande"), et le serveur verifie que je suis bien assis au bureau.
-- =========================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local dossierRemote = ReplicatedStorage:WaitForChild("PosteDirection")
local commande = dossierRemote:WaitForChild("Commande")
local infos    = dossierRemote:WaitForChild("Infos"):InvokeServer()
local NB       = infos.nbMorceaux
local NB_TOURS = 3

local BLEU_FOND = Color3.fromRGB(10, 28, 55)
local BLEU_BTN  = Color3.fromRGB(22, 52, 95)
local NEON      = Color3.fromRGB(0, 225, 255)
local BLANC     = Color3.fromRGB(255, 255, 255)

-- ---- petits outils pour fabriquer l interface ----
local function cadre(parent, taille, position, couleur)
	local f = Instance.new("Frame")
	f.Size, f.Position = taille, position
	f.BackgroundColor3 = couleur or BLEU_FOND
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end
local function arrondi(objet, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = objet
end
local function texte(parent, t, taille, position, couleur)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size, l.Position = taille, position
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = couleur or BLANC
	l.Text = t
	l.Parent = parent
	return l
end
local function bouton(parent, t, taille, position, couleur)
	local b = Instance.new("TextButton")
	b.Size, b.Position = taille, position
	b.BackgroundColor3 = couleur or BLEU_BTN
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = BLANC
	b.Text = t
	b.Parent = parent
	arrondi(b, 6)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop, marge.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	marge.PaddingLeft, marge.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	marge.Parent = b
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "PosteDirection"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = joueur:WaitForChild("PlayerGui")

-- =========================================================
--  2. LA PLUIE (pour tout le monde, autour de MA camera)
-- =========================================================
-- Une grande plaque invisible au-dessus de la camera, qui lache des gouttes.
local nuage = Instance.new("Part")
nuage.Name = "NuagePluie"
nuage.Anchored, nuage.CanCollide, nuage.CanQuery, nuage.CanTouch = true, false, false, false
nuage.Transparency = 1
nuage.Size = Vector3.new(120, 1, 120)
local gouttes = Instance.new("ParticleEmitter")
gouttes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
gouttes.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
gouttes.Transparency = NumberSequence.new(0.35)
gouttes.Size = NumberSequence.new(0.12)
gouttes.Squash = NumberSequence.new(-4)          -- etirees : des traits, pas des points
gouttes.Lifetime = NumberRange.new(0.9, 1.1)
gouttes.Speed = NumberRange.new(70, 80)
gouttes.EmissionDirection = Enum.NormalId.Bottom
gouttes.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
gouttes.Rate = 1500
gouttes.LightEmission = 0.2
gouttes.Parent = nuage

local function majPluie()
	nuage.Parent = workspace:GetAttribute("Pluie") and camera or nil
end
workspace:GetAttributeChangedSignal("Pluie"):Connect(majPluie)
majPluie()

-- =========================================================
--  1. LE MENU DU BUREAU
-- =========================================================
local menu = cadre(gui, UDim2.new(0, 300, 1, -120), UDim2.fromOffset(12, 100))
menu.BackgroundTransparency = 0.08
menu.Visible = false
arrondi(menu, 12)
local bord = Instance.new("UIStroke")
bord.Color = NEON
bord.Thickness = 2
bord.Parent = menu
texte(menu, "DIRECTION DE COURSE", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 10), NEON)
local sousTitre = texte(menu, "", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(10, 38), Color3.fromRGB(170, 200, 230))

-- les 3 onglets
local ONGLETS = {"CAMÉRAS", "PILOTES", "MÉTÉO"}
local pages, boutonsOnglet = {}, {}
for k, nom in ipairs(ONGLETS) do
	local b = bouton(menu, nom, UDim2.new(1 / 3, -6, 0, 30), UDim2.new((k - 1) / 3, 5, 0, 62))
	b.TextSize = 11
	boutonsOnglet[nom] = b
	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, -20, 1, -160)
	page.Position = UDim2.fromOffset(10, 102)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 5
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Visible = false
	page.Parent = menu
	local liste = Instance.new("UIListLayout")
	liste.Padding = UDim.new(0, 6)
	liste.SortOrder = Enum.SortOrder.LayoutOrder
	liste.Parent = page
	pages[nom] = page
end
local function ouvrirOnglet(nom)
	for n, page in pairs(pages) do
		page.Visible = (n == nom)
		boutonsOnglet[n].BackgroundColor3 = (n == nom) and Color3.fromRGB(0, 140, 170) or BLEU_BTN
	end
end
for nom, b in pairs(boutonsOnglet) do
	b.Activated:Connect(function() ouvrirOnglet(nom) end)
end

local seLever = bouton(menu, "SE LEVER", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 1, -46), Color3.fromRGB(150, 40, 40))

-- ---- LA CAMERA ----
-- mode = nil (vue normale), "fixe", "tv" ou "embarquee"
local mode, cameraChoisie, pilote = nil, nil, nil
local cameraTV = nil
local regardLisse = nil     -- ou la camera regarde (lissé, pour ne pas trembler)
local voitureLisse = nil

local function vueNormale()
	mode, cameraChoisie, pilote, cameraTV, regardLisse, voitureLisse = nil, nil, nil, nil, nil, nil
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	sousTitre.Text = "Vue : bureau"
	commande:FireServer("bureau")
end

-- la voiture d un pilote : sa vraie piece si je la recois, sinon la
-- position envoyee par le serveur (si elle est trop loin pour le streaming)
local function cframePilote(p)
	local perso = p.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = hum and hum.SeatPart
	if siege and siege:IsA("VehicleSeat") then return siege.CFrame end
	return p:GetAttribute("DirCFrame")
end

-- ---- page CAMERAS ----
local bVue = bouton(pages["CAMÉRAS"], "VUE DU BUREAU", UDim2.new(1, -8, 0, 34), UDim2.new(), Color3.fromRGB(0, 110, 140))
bVue.LayoutOrder = 0
bVue.Activated:Connect(vueNormale)
for k, c in ipairs(infos.cameras) do
	local b = bouton(pages["CAMÉRAS"], "📹  " .. c.nom, UDim2.new(1, -8, 0, 34), UDim2.new())
	b.LayoutOrder = k
	b.Activated:Connect(function()
		mode, cameraChoisie, pilote, regardLisse = "fixe", c, nil, nil
		camera.CameraType = Enum.CameraType.Scriptable
		sousTitre.Text = "Vue : " .. c.nom
		commande:FireServer("regarde", c.cible)
	end)
end

-- ---- page PILOTES ----
local lignesPilotes = {}
local aucun = texte(pages["PILOTES"], "Personne en piste pour l'instant", UDim2.new(1, -8, 0, 20), UDim2.new(),
	Color3.fromRGB(170, 200, 230))

local function suivre(p, quelMode)
	mode, pilote, cameraTV, regardLisse, voitureLisse = quelMode, p, nil, nil, nil
	camera.CameraType = Enum.CameraType.Scriptable
	sousTitre.Text = (quelMode == "tv" and "Caméra TV : " or "Embarquée : ") .. p.DisplayName
	commande:FireServer("suit", p)
end

local function majPilotes()
	-- qui est classe : ceux qui sont arrives (dans l ordre d arrivee), puis
	-- ceux qui roulent (le plus avance devant)
	local liste = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("DirProgression") then table.insert(liste, p) end
	end
	table.sort(liste, function(a, b)
		local ra, rb = a:GetAttribute("DirArrivee"), b:GetAttribute("DirArrivee")
		if ra and rb then return ra < rb end
		if ra or rb then return ra ~= nil end
		return a:GetAttribute("DirProgression") > b:GetAttribute("DirProgression")
	end)
	aucun.Visible = #liste == 0
	for _, l in ipairs(lignesPilotes) do l:Destroy() end
	lignesPilotes = {}
	for rang, p in ipairs(liste) do
		local ligne = cadre(pages["PILOTES"], UDim2.new(1, -8, 0, 62), UDim2.new(), BLEU_BTN)
		ligne.LayoutOrder = rang
		arrondi(ligne, 6)
		local etat
		if p:GetAttribute("DirArrivee") then
			etat = "ARRIVÉ"
		elseif not p:GetAttribute("DirCFrame") then
			etat = "HORS PISTE"
		else
			local tour = math.clamp(math.floor((p:GetAttribute("DirProgression") - 1) / NB), 1, NB_TOURS)
			etat = "TOUR " .. tour .. " / " .. NB_TOURS
		end
		local nom = texte(ligne, rang .. ". " .. p.DisplayName, UDim2.new(0.62, 0, 0, 24), UDim2.fromOffset(8, 4))
		nom.TextXAlignment = Enum.TextXAlignment.Left
		local e = texte(ligne, etat, UDim2.new(0.38, -12, 0, 18), UDim2.new(0.62, 0, 0, 7), NEON)
		e.TextXAlignment = Enum.TextXAlignment.Right
		local bTV = bouton(ligne, "TV", UDim2.new(0.5, -10, 0, 24), UDim2.new(0, 6, 0, 32), Color3.fromRGB(0, 110, 140))
		local bEmb = bouton(ligne, "EMBARQUÉE", UDim2.new(0.5, -10, 0, 24), UDim2.new(0.5, 4, 0, 32), Color3.fromRGB(0, 110, 140))
		bTV.Activated:Connect(function() suivre(p, "tv") end)
		bEmb.Activated:Connect(function() suivre(p, "embarquee") end)
		table.insert(lignesPilotes, ligne)
	end
end

-- ---- page METEO ----
local METEOS = {
	{"SOLEIL", "☀️  SOLEIL"}, {"COUCHER", "🌅  COUCHER DE SOLEIL"}, {"NUIT", "🌙  NUIT"},
	{"BROUILLARD", "🌫️  BROUILLARD"}, {"PLUIE", "🌧️  PLUIE"},
}
for k, m in ipairs(METEOS) do
	local b = bouton(pages["MÉTÉO"], m[2], UDim2.new(1, -8, 0, 38), UDim2.new())
	b.LayoutOrder = k
	b.Activated:Connect(function() commande:FireServer("meteo", m[1]) end)
end

-- =========================================================
--  ASSIS OU PAS ?
-- =========================================================
local assis = false
local function auBureau()
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	return hum and hum.SeatPart and hum.SeatPart.Name == "ChaiseBureau", hum
end

seLever.Activated:Connect(function()
	local _, hum = auBureau()
	if hum then hum.Jump = true end      -- sauter = se lever de la chaise
end)

local attente = 0
RunService.RenderStepped:Connect(function(dt)
	local maintenant = auBureau() == true     -- "== true" : jamais nil, toujours vrai ou faux
	if maintenant ~= assis then
		assis = maintenant
		menu.Visible = assis
		if assis then
			ouvrirOnglet("CAMÉRAS")
			sousTitre.Text = "Vue : bureau"
		elseif mode then
			vueNormale()
		end
	end
	-- la pluie suit ma camera (40 studs au-dessus de moi)
	if nuage.Parent then
		nuage.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
	end
	if not assis then return end

	attente += dt
	if attente > 0.5 then
		attente = 0
		if pages["PILOTES"].Visible then majPilotes() end
	end

	-- lissage : on se rapproche de la cible un peu a chaque image
	local alpha = 1 - math.exp(-8 * dt)

	if mode == "fixe" then
		-- la camera reste a sa place, mais tourne vers le pilote le plus
		-- proche s il passe devant (comme un cameraman)
		local cible, dMin = cameraChoisie.cible, 150
		for _, p in ipairs(Players:GetPlayers()) do
			local cf = p:GetAttribute("DirCFrame") and cframePilote(p)
			if cf then
				local d = (cf.Position - cameraChoisie.position).Magnitude
				if d < dMin then cible, dMin = cf.Position, d end
			end
		end
		regardLisse = regardLisse and regardLisse:Lerp(cible, alpha) or cible
		camera.CFrame = CFrame.lookAt(cameraChoisie.position, regardLisse)
		camera.FieldOfView = 60

	elseif mode == "tv" or mode == "embarquee" then
		local cf = pilote and pilote.Parent and cframePilote(pilote)
		if not cf then
			sousTitre.Text = "Le pilote n'est plus en piste"
			return
		end
		voitureLisse = voitureLisse and voitureLisse:Lerp(cf, alpha) or cf
		local pos = voitureLisse.Position

		if mode == "tv" then
			-- la camera TV la plus proche de la voiture ; on ne change que si
			-- une autre est NETTEMENT plus proche (sinon ca clignote)
			local meilleure, dMin = nil, math.huge
			for _, c in ipairs(infos.camerasTV) do
				local d = (c.position - pos).Magnitude
				if d < dMin then meilleure, dMin = c, d end
			end
			if not cameraTV or (cameraTV.position - pos).Magnitude > dMin * 1.3 then
				cameraTV = meilleure
			end
			local d = (cameraTV.position - pos).Magnitude
			camera.CFrame = CFrame.lookAt(cameraTV.position, pos)
			-- le zoom : la voiture (~18 studs) garde a peu pres la meme taille
			camera.FieldOfView = math.clamp(math.deg(2 * math.atan(25 / d)), 12, 70)
		else
			-- derriere et au-dessus de la voiture, on regarde devant elle
			local oeil = voitureLisse * Vector3.new(0, 6, 16)
			camera.CFrame = CFrame.lookAt(oeil, voitureLisse * Vector3.new(0, 2, -25))
			camera.FieldOfView = 70
		end
	end
end)
