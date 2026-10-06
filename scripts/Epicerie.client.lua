-- =========================================================
--  L ECRAN DE L EPICERIE  (LocalScript dans StarterPlayerScripts)
--    - mes pieces, a gauche de l ecran ;
--    - mes boosts en cours, avec le compte a rebours ;
--    - les messages du magasin (achat, pas assez de pieces, gain de course) ;
--    - LE VOL (tomate volante) : bouton VOLER ou touche F ;
--        Z Q S D (ou les fleches) = avancer dans la direction de la camera,
--        Espace = monter, Maj = descendre ;
--    - LA GLACE : clic = lancer une boule de glace la ou vise la souris.
--  Il ne DECIDE de rien : le serveur verifie qu on a le pouvoir
--  (attributs "Boost_...", "EnVol").
--  ⚠️ Clavier AZERTY : Roblox lit la PLACE des touches. Mon Z est sa
--  touche W, mon Q est sa touche A : on teste donc W A S D.
-- =========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local joueur  = Players.LocalPlayer
local message = ReplicatedStorage:WaitForChild("MessageEpicerie")
local voler   = ReplicatedStorage:WaitForChild("Voler")
local lancer  = ReplicatedStorage:WaitForChild("LancerGlace")

local VITESSE_VOL = 90
-- dans l ordre d affichage
local BOOSTS = {
	{effet = "vitesse", nom = "⚡ Flash",  couleur = Color3.fromRGB(255, 220, 40)},
	{effet = "saut",    nom = "🦘 Saut",   couleur = Color3.fromRGB(255, 80, 170)},
	{effet = "vol",     nom = "🍅 Vol",    couleur = Color3.fromRGB(255, 90, 70), aide = "F ou bouton : voler"},
	{effet = "glace",   nom = "❄️ Glace",  couleur = Color3.fromRGB(150, 220, 255), aide = "clique pour lancer"},
}

local ecran = Instance.new("ScreenGui")
ecran.Name = "EcranEpicerie"
ecran.ResetOnSpawn = false
ecran.Parent = joueur:WaitForChild("PlayerGui")

local function etiquette(parent, taille, position, texte, couleur, classe)
	local t = Instance.new(classe or "TextLabel")
	t.Size = taille
	t.Position = position
	t.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	t.BackgroundTransparency = 0.3
	t.TextColor3 = couleur or Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = texte
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, 8)
	coin.Parent = t
	local marge = Instance.new("UIPadding")
	marge.PaddingLeft, marge.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	marge.PaddingTop, marge.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	marge.Parent = t
	t.Parent = parent
	return t
end

local function boostActif(effet)
	return (joueur:GetAttribute("Boost_" .. effet) or 0) > workspace:GetServerTimeNow()
end

-- ---- les pieces ----
local boite = etiquette(ecran, UDim2.fromOffset(150, 36), UDim2.new(0, 12, 0.4, 0), "🪙 0", Color3.fromRGB(255, 225, 60))
local function majPieces()
	local ls = joueur:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Pièces")
	if v then boite.Text = "🪙 " .. v.Value end
end
task.spawn(function()
	local v = joueur:WaitForChild("leaderstats"):WaitForChild("Pièces")
	v.Changed:Connect(majPieces)
	majPieces()
end)

-- ---- le bouton VOLER (seulement quand on a mange la tomate) ----
local bouton = etiquette(ecran, UDim2.fromOffset(150, 44), UDim2.new(0, 12, 0.4, -54), "🍅 VOLER",
	Color3.new(1, 1, 1), "TextButton")
bouton.BackgroundColor3 = Color3.fromRGB(200, 40, 30)
bouton.BackgroundTransparency = 0.1
bouton.Visible = false
local function basculerVol()
	voler:FireServer(not joueur:GetAttribute("EnVol"))
end
bouton.Activated:Connect(basculerVol)

-- ---- les boosts ----
local lignes = {}
RunService.RenderStepped:Connect(function()
	local maintenant = workspace:GetServerTimeNow()
	local i = 0
	for _, b in ipairs(BOOSTS) do
		local fin = joueur:GetAttribute("Boost_" .. b.effet)
		local reste = fin and math.ceil(fin - maintenant)
		if reste and reste > 0 then
			i += 1
			local l = lignes[b.effet] or etiquette(ecran, UDim2.fromOffset(150, 40), UDim2.new(), "", b.couleur)
			lignes[b.effet] = l
			l.Position = UDim2.new(0, 12, 0.4, 36 + 6 + (i - 1) * 44)
			local temps = (reste > 1e6) and "fin de course" or (reste .. " s")
			l.Text = b.nom .. "  " .. temps .. (b.aide and ("\n" .. b.aide) or "")
		elseif lignes[b.effet] then
			lignes[b.effet]:Destroy()
			lignes[b.effet] = nil
		end
	end
	bouton.Visible = boostActif("vol")
	bouton.Text = joueur:GetAttribute("EnVol") and "🛬 ATTERRIR" or "🍅 VOLER"
end)

-- ---- les messages : en bas, au-dessus de l inventaire ----
local dernier
message.OnClientEvent:Connect(function(texte, couleur)
	if dernier then dernier:Destroy() end
	local m = etiquette(ecran, UDim2.new(0.5, 0, 0, 40), UDim2.new(0.25, 0, 1, -140), texte, couleur)
	dernier = m
	task.delay(3, function()
		if m.Parent then
			local t = TweenService:Create(m, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1})
			t:Play()
			t.Completed:Wait()
			m:Destroy()
		end
	end)
end)

-- =========================================================
-- LE VOL : une "LinearVelocity" pousse le personnage a la vitesse voulue,
-- une "AlignOrientation" le tient dans la direction de la camera.
-- PlatformStand : le personnage ne marche plus, il se laisse porter.
-- =========================================================
local vol = nil     -- tout ce qui sert pendant le vol
local function arreterVol()
	if not vol then return end
	vol.attache:Destroy()
	vol.pousse:Destroy()
	vol.tourne:Destroy()
	if vol.hum.Parent then vol.hum.PlatformStand = false end
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5), {FieldOfView = vol.fov}):Play()
	vol = nil
end
local function demarrerVol()
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	if not (racine and hum) or vol then return end
	local attache = Instance.new("Attachment")
	attache.Name = "AttacheVol"
	attache.Parent = racine
	local pousse = Instance.new("LinearVelocity")
	pousse.Attachment0 = attache
	pousse.MaxForce = math.huge
	pousse.VectorVelocity = Vector3.zero
	pousse.RelativeTo = Enum.ActuatorRelativeTo.World
	pousse.Parent = racine
	local tourne = Instance.new("AlignOrientation")
	tourne.Mode = Enum.OrientationAlignmentMode.OneAttachment
	tourne.Attachment0 = attache
	tourne.MaxTorque = math.huge
	tourne.Responsiveness = 12                 -- il tourne en douceur
	tourne.CFrame = racine.CFrame.Rotation
	tourne.Parent = racine
	hum.PlatformStand = true      -- (Roblox arrete alors ses animations : c est nous qui posons le corps)
	vol = {attache = attache, pousse = pousse, tourne = tourne, hum = hum,
		vitesse = Vector3.zero, fov = workspace.CurrentCamera.FieldOfView}
end
joueur:GetAttributeChangedSignal("EnVol"):Connect(function()
	if joueur:GetAttribute("EnVol") then demarrerVol() else arreterVol() end
end)
joueur.CharacterAdded:Connect(function()   -- l ancien personnage est detruit avec ses pieces
	if vol then workspace.CurrentCamera.FieldOfView = vol.fov end
	vol = nil
end)

local function touche(...)
	for _, k in ipairs({...}) do
		if UserInputService:IsKeyDown(k) then return 1 end
	end
	return 0
end
RunService.RenderStepped:Connect(function(dt)
	if not vol then return end
	local cam = workspace.CurrentCamera
	local K = Enum.KeyCode
	local avant  = touche(K.W, K.Up) - touche(K.S, K.Down)
	local droite = touche(K.D, K.Right) - touche(K.A, K.Left)
	local haut   = touche(K.Space) - touche(K.LeftShift, K.RightShift)
	local dir = cam.CFrame.LookVector * avant + cam.CFrame.RightVector * droite + Vector3.yAxis * haut
	local cible = (dir.Magnitude > 0) and dir.Unit * VITESSE_VOL or Vector3.zero

	-- 1. LA VITESSE : on s en approche petit a petit (il accelere et freine en douceur)
	vol.vitesse = vol.vitesse:Lerp(cible, 1 - math.exp(-4 * dt))
	local v = vol.vitesse
	local vitesse = v.Magnitude
	-- sur place : il flotte, il monte et descend doucement
	local flotte = (cible == Vector3.zero) and Vector3.new(0, math.sin(os.clock() * 2.5) * 1.2, 0) or Vector3.zero
	vol.pousse.VectorVelocity = v + flotte

	-- 2. LA POSITION DU CORPS, dans le repere de la camera (a plat) :
	--    "devant" = ce qu il avance, "monte" = ce qu il monte, "cote" = ce qu il glisse
	local plat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if plat.Magnitude < 0.01 then plat = Vector3.new(0, 0, -1) end
	plat = plat.Unit
	local cotePlat = plat:Cross(Vector3.yAxis)
	local devant, monte, cote = v:Dot(plat), v.Y, v:Dot(cotePlat)
	local enMouvement = vitesse > 8
	local penche = 0
	if enMouvement and devant > 1 then
		-- a l horizontale : couche (-85 degres) ; en montant : debout ; en piquant : tete en bas
		local angle = math.deg(math.atan2(monte, devant))       -- de -90 (pique) a +90 (monte)
		penche = math.clamp(-(90 - angle) * 0.95, -150, 0)
	elseif enMouvement and devant < -1 then
		penche = 15                                            -- en reculant, il se penche en arriere
	end
	local roule = -cote / VITESSE_VOL * 35                     -- dans les virages, il s incline
	vol.tourne.CFrame = CFrame.lookAt(Vector3.zero, plat) * CFrame.Angles(math.rad(penche), 0, math.rad(roule))

	-- 3. LA CAMERA s elargit avec la vitesse : on sent qu on va vite
	cam.FieldOfView = vol.fov + 20 * math.clamp(vitesse / VITESSE_VOL, 0, 1)
end)

-- =========================================================
-- LA POSE DE VOL, pour TOUS ceux qui volent (comme les pilotes des velos) :
-- chaque ecran plie lui-meme les articulations de ceux qu il voit voler.
-- On tourne l Attachment0 des AnimationConstraint (degres ; epaule + = bras
-- vers l avant, coude + = plie, hanche + = cuisse vers l avant, genou - = plie).
--   SUR PLACE : bras un peu ecartes en avant, jambes qui pendent et se balancent
--   SUPERMAN  : poing droit tendu devant, bras gauche le long du corps,
--               jambes tendues et serrees
-- On passe de l une a l autre selon la vitesse "vers la tete" (le corps
-- couche a l horizontale : sa tete est devant).
-- =========================================================
local SUR_PLACE = {RightShoulder = 25, LeftShoulder = 25, RightElbow = 35, LeftElbow = 35, Waist = 0,
	RightHip = 18, LeftHip = 6, RightKnee = -40, LeftKnee = -18}
local SUPERMAN  = {RightShoulder = 175, LeftShoulder = -8, RightElbow = 0, LeftElbow = 5, Waist = -5,
	RightHip = -6, LeftHip = -6, RightKnee = -6, LeftKnee = -22}
local NOMS_POSE = {"RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist",
	"RightHip", "LeftHip", "RightKnee", "LeftKnee"}

local poses = setmetatable({}, {__mode = "k"})   -- perso -> {articulations + "s" : 0 sur place .. 1 superman}
local function articulations(perso)
	if poses[perso] then return poses[perso] end
	local j = {s = 0}
	for _, nom in ipairs(NOMS_POSE) do
		local c = perso:FindFirstChild(nom, true)
		if not (c and c:IsA("AnimationConstraint") and c.Attachment0) then return nil end   -- pas encore charge
		j[nom] = {a = c.Attachment0, base = c.Attachment0.CFrame}
	end
	poses[perso] = j
	return j
end
local function remettre(perso)
	local j = poses[perso]
	if not j then return end
	for _, nom in ipairs(NOMS_POSE) do j[nom].a.CFrame = j[nom].base end
	poses[perso] = nil
end

RunService.RenderStepped:Connect(function(dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local perso = p.Character
		if perso and p:GetAttribute("EnVol") then
			local racine = perso:FindFirstChild("HumanoidRootPart")
			local j = racine and articulations(perso)
			if j then
				-- vers la tete = vers l avant quand il est couche, vers le haut quand il decolle
				local versTete = racine.AssemblyLinearVelocity:Dot(racine.CFrame.UpVector)
				local but = math.clamp(versTete / (VITESSE_VOL * 0.5), 0, 1)
				j.s += (but - j.s) * (1 - math.exp(-5 * dt))
				local t = os.clock()
				for _, nom in ipairs(NOMS_POSE) do
					local angle = SUR_PLACE[nom] + (SUPERMAN[nom] - SUR_PLACE[nom]) * j.s
					-- sur place, les jambes se balancent doucement
					if nom:find("Hip") then angle += math.sin(t * 2 + (nom == "LeftHip" and 1.5 or 0)) * 6 * (1 - j.s) end
					j[nom].a.CFrame = j[nom].base * CFrame.Angles(math.rad(angle), 0, 0)
				end
			end
		elseif perso and poses[perso] then
			remettre(perso)
		end
	end
end)

-- =========================================================
-- LES TOUCHES : F = voler ; clic = boule de glace
-- =========================================================
UserInputService.InputBegan:Connect(function(entree, dejaPris)
	if UserInputService:GetFocusedTextBox() then return end     -- on ecrit dans le chat
	if entree.KeyCode == Enum.KeyCode.F and boostActif("vol") then
		basculerVol()
	elseif (entree.UserInputType == Enum.UserInputType.MouseButton1 or entree.UserInputType == Enum.UserInputType.Touch)
		and not dejaPris and boostActif("glace") then
		local perso = joueur.Character
		if not perso or perso:FindFirstChildOfClass("Tool") then return end   -- un produit en main : le clic sert a manger
		-- le point vise : un rayon depuis la camera, a travers la souris
		local cam = workspace.CurrentCamera
		local souris = (entree.UserInputType == Enum.UserInputType.Touch) and entree.Position or UserInputService:GetMouseLocation()
		local rayon = (entree.UserInputType == Enum.UserInputType.Touch) and cam:ScreenPointToRay(souris.X, souris.Y)
			or cam:ViewportPointToRay(souris.X, souris.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {perso}
		local impact = workspace:Raycast(rayon.Origin, rayon.Direction * 400, params)
		lancer:FireServer(impact and impact.Position or (rayon.Origin + rayon.Direction * 400))
	end
end)
