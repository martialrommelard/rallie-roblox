-- ============================================================
--  L ECRAN DU PILOTE PENDANT LA COURSE
--  LocalScript a placer dans StarterPlayer > StarterPlayerScripts.
--
--  Il ne DECIDE de rien (c est CompteurTours, sur le serveur) : il
--  affiche.
--    1. les messages du serveur : "CHECKPOINT 2 / 5", "MANQUE !"...
--    2. les portiques : JAUNE = le prochain, VERT = deja passe ;
--    3. le bouton ABANDONNER (il faut cliquer 2 fois : pas d accident) ;
--    4. le compte a rebours quand le 1er est arrive.
--    5. l etat de la voiture (les degats, script Degats).
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local info       = ReplicatedStorage:WaitForChild("InfoCourse")
local evtAbandon = ReplicatedStorage:WaitForChild("Abandonner")

local JAUNE  = Color3.fromRGB(255, 205, 60)
local VERT   = Color3.fromRGB(90, 230, 120)
local ROUGE  = Color3.fromRGB(230, 60, 60)
local NORMAL = Color3.fromRGB(120, 200, 255)

-- ---- L ECRAN ----
local ecran = Instance.new("ScreenGui")
ecran.Name = "EcranCourse"
ecran.ResetOnSpawn = false
ecran.IgnoreGuiInset = true
ecran.Parent = joueur:WaitForChild("PlayerGui")

local function etiquette(position, taille)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = position
	l.Size = taille
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextStrokeTransparency = 0.3
	l.Text = ""
	l.Visible = false
	l.Parent = ecran
	return l
end

-- 1. LES MESSAGES : au tiers de la hauteur, ils s en vont tout seuls
local message = etiquette(UDim2.fromScale(0.5, 0.3), UDim2.new(0.6, 0, 0, 44))
local numero = 0
info.OnClientEvent:Connect(function(texte, couleur, duree)
	numero += 1
	local n = numero
	message.Text = texte
	message.TextColor3 = couleur or Color3.new(1, 1, 1)
	message.Visible = true
	task.delay(duree or 2, function()
		if numero == n then message.Visible = false end   -- un message plus recent ? on le laisse
	end)
end)

-- 4. LE COMPTE A REBOURS DE FIN
local rebours = etiquette(UDim2.fromScale(0.5, 0.2), UDim2.new(0.5, 0, 0, 30))
rebours.TextColor3 = JAUNE

-- 3. LE BOUTON ABANDONNER, en bas a droite
local bouton = Instance.new("TextButton")
bouton.AnchorPoint = Vector2.new(1, 1)
bouton.Position = UDim2.new(1, -20, 1, -20)
bouton.Size = UDim2.fromOffset(190, 46)
bouton.BackgroundColor3 = Color3.fromRGB(150, 35, 35)
bouton.TextColor3 = Color3.new(1, 1, 1)
bouton.Font = Enum.Font.GothamBold
bouton.TextSize = 18
bouton.Text = "🏳️ ABANDONNER"
bouton.Visible = false
bouton.Parent = ecran
Instance.new("UICorner", bouton).CornerRadius = UDim.new(0, 10)

-- 1er clic : "SÛR ?" pendant 3 s. 2eme clic dans ce temps : on abandonne.
local confirmeJusqua = 0
bouton.Activated:Connect(function()
	if os.clock() < confirmeJusqua then
		confirmeJusqua = 0
		evtAbandon:FireServer()
	else
		confirmeJusqua = os.clock() + 3
	end
end)

-- 5. L ETAT DE LA VOITURE : une barre en bas a gauche
local cadreEtat = Instance.new("Frame")
cadreEtat.AnchorPoint = Vector2.new(0, 1)
cadreEtat.Position = UDim2.new(0, 20, 1, -20)
cadreEtat.Size = UDim2.fromOffset(220, 22)
cadreEtat.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
cadreEtat.BackgroundTransparency = 0.3
cadreEtat.Visible = false
cadreEtat.Parent = ecran
Instance.new("UICorner", cadreEtat).CornerRadius = UDim.new(0, 6)
local barreEtat = Instance.new("Frame")
barreEtat.Size = UDim2.fromScale(1, 1)
barreEtat.BorderSizePixel = 0
barreEtat.Parent = cadreEtat
Instance.new("UICorner", barreEtat).CornerRadius = UDim.new(0, 6)
local texteEtat = Instance.new("TextLabel")
texteEtat.Size = UDim2.fromScale(1, 1)
texteEtat.BackgroundTransparency = 1
texteEtat.Font = Enum.Font.GothamBold
texteEtat.TextSize = 14
texteEtat.TextColor3 = Color3.new(1, 1, 1)
texteEtat.TextStrokeTransparency = 0.4
texteEtat.ZIndex = 2
texteEtat.Parent = cadreEtat

-- La voiture ou je suis assis (le modele range dans workspace.Voitures)
local function maVoiture()
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local a = hum and hum.SeatPart
	local dossier = workspace:FindFirstChild("Voitures")
	while a and a.Parent and a.Parent ~= dossier do
		a = a.Parent
	end
	if a and a.Parent == dossier then return a end
	return nil
end

-- A CHAQUE IMAGE
RunService.RenderStepped:Connect(function()
	local enCourse = joueur:GetAttribute("EnCourse") == true
	local passes = joueur:GetAttribute("Checkpoint") or 0

	-- 2. les portiques (avec le streaming, certains ne sont pas encore
	-- arrives chez moi : FindFirstChild les saute)
	local circuit = workspace:FindFirstChild("Circuit")
	local dossier = circuit and circuit:FindFirstChild("Checkpoints")
	if dossier then
		for _, portique in ipairs(dossier:GetChildren()) do
			local i = tonumber(portique.Name:match("%d+"))
			local rideau = portique:FindFirstChild("Rideau")
			if i and rideau then
				local couleur = NORMAL
				if enCourse then
					if i <= passes then couleur = VERT
					elseif i == passes + 1 then couleur = JAUNE end
				end
				rideau.Color = couleur
				rideau.Transparency = (enCourse and i == passes + 1) and 0.7 or 0.85
			end
		end
	end

	-- 3. le bouton
	bouton.Visible = enCourse
	bouton.Text = (os.clock() < confirmeJusqua) and "SÛR ? CLIQUE ENCORE" or "🏳️ ABANDONNER"

	-- 4. le compte a rebours
	local fin = workspace:GetAttribute("FinCourse")
	if enCourse and fin then
		local reste = math.max(0, math.ceil(fin - workspace:GetServerTimeNow()))
		rebours.Text = "Le 1er est arrivé ! Fin de la course dans " .. reste .. " s"
		rebours.Visible = true
	else
		rebours.Visible = false
	end

	-- 5. l etat de la voiture (attribut "Etat" pose par le script Degats)
	local voiture = maVoiture()
	local etat = voiture and voiture:GetAttribute("Etat")
	if etat then
		cadreEtat.Visible = true
		barreEtat.Size = UDim2.fromScale(math.clamp(etat / 100, 0, 1), 1)
		barreEtat.BackgroundColor3 = (etat > 60 and VERT) or (etat > 25 and JAUNE) or ROUGE
		texteEtat.Text = "🔧 Voiture : " .. math.floor(etat) .. " %"
	else
		cadreEtat.Visible = false
	end
end)
