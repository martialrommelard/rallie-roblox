-- =========================================================
--  LA SALLE DE SPORT QUI MARCHE  (cote SERVEUR)
--  A placer dans ServerScriptService. Les objets sont construits par
--  SalleSport.lua (dans ZoneSpawn/SalleSport).
--
--    BANC     assis : la barre monte et descend, on compte les repetitions
--    VELOS    assis : le pedalier tourne, les kilometres defilent
--    SACS     un bouton "Frapper" : le sac part sous le coup
--    TAPIS    la console affiche le coureur et sa distance
-- =========================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")

local zone    = workspace:WaitForChild("ZoneSpawn")
local salle   = zone:WaitForChild("SalleSport")

local function texteDe(part)
	local g = part and part:FindFirstChildOfClass("SurfaceGui")
	return g and g:FindFirstChild("Texte")
end
local function plusProcheDe(nom, pos)
	local best, d = nil, math.huge
	for _, p in ipairs(salle:GetChildren()) do
		if p.Name == nom then
			local dd = (p.Position - pos).Magnitude
			if dd < d then best, d = p, dd end
		end
	end
	return best
end
local function joueurAssis(siege)
	local hum = siege.Occupant
	return hum and Players:GetPlayerFromCharacter(hum.Parent), hum
end

-- =========================================================
--  1. LE BANC DE MUSCULATION
-- =========================================================
local banc = salle:FindFirstChild("BancMuscu")
local barre = salle:FindFirstChild("Barre")
if banc and barre then
	local repos = barre.CFrame
	local ecran = texteDe(plusProcheDe("EcranBanc", banc.Position))
	local enCours = false
	banc:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not banc.Occupant or enCours then return end
		enCours = true
		local reps = 0
		while banc.Occupant do
			local monte = TweenService:Create(barre, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {CFrame = repos + Vector3.new(0, 1.4, 0)})
			monte:Play() monte.Completed:Wait()
			local descend = TweenService:Create(barre, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {CFrame = repos})
			descend:Play() descend.Completed:Wait()
			reps += 1
			if ecran then ecran.Text = "REPS : " .. reps end
		end
		barre.CFrame = repos
		task.delay(3, function() if ecran and not banc.Occupant then ecran.Text = "REPS : 0" end end)
		enCours = false
	end)
end

-- =========================================================
--  2. LES VELOS (des modeles VeloAppartement : VeloAppartement.lua)
--  Ici on compte seulement les kilometres. Les pedales qui tournent et les
--  jambes qui pedalent sont faites chez chaque joueur (Exercices) : c est
--  plus fluide que de deplacer des pieces depuis le serveur.
-- =========================================================
for _, selle in ipairs(salle:GetDescendants()) do
	if selle.Name == "VeloSport" and selle:IsA("Seat") then
		local ecran = texteDe(selle.Parent:FindFirstChild("EcranVelo"))
		local enCours = false
		selle:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not selle.Occupant or enCours then return end
			enCours = true
			local km = 0
			while selle.Occupant do
				km += 0.0025
				if ecran then ecran.Text = string.format("%.2f km", km) end
				task.wait(0.05)
			end
			enCours = false
		end)
	end
end

-- =========================================================
--  3. LES SACS DE FRAPPE : on les FRAPPE pour de vrai
--  Un bouton "Frapper" (touche E) quand on est a cote. Le serveur pousse le
--  sac dans la direction du coup (ApplyImpulse), joue un bruit sourd et
--  compte les coups. Le bras du joueur, lui, est anime chez lui (Exercices).
-- =========================================================
local FORCE_COUP = 22       -- la vitesse donnee au sac par un coup (studs/s)
for _, sac in ipairs(salle:GetChildren()) do
	if sac.Name == "SacFrappe" then
		sac:SetNetworkOwner(nil)          -- c est le serveur qui fait bouger le sac
		local bouton = Instance.new("ProximityPrompt")
		bouton.ActionText = "Frapper"
		bouton.ObjectText = "Sac de frappe"
		bouton.KeyboardKeyCode = Enum.KeyCode.E
		bouton.HoldDuration = 0
		bouton.MaxActivationDistance = 7
		bouton.RequiresLineOfSight = false
		bouton.Parent = sac
		local bruit = Instance.new("Sound")
		bruit.SoundId = "rbxasset://sounds/action_jump_land.mp3"
		bruit.Volume = 0.8
		bruit.Parent = sac
		local panneau = Instance.new("BillboardGui")
		panneau.Size = UDim2.new(3.5, 0, 0.8, 0)
		panneau.StudsOffset = Vector3.new(0, 3.4, 0)
		panneau.MaxDistance = 30
		panneau.Parent = sac
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 0.3
		t.BackgroundColor3 = Color3.fromRGB(10, 28, 55)
		t.TextColor3 = Color3.fromRGB(0, 225, 255)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Text = "COUPS : 0"
		t.Parent = panneau
		local coups = 0
		bouton.Triggered:Connect(function(joueur)
			local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
			if not racine or (racine.Position - sac.Position).Magnitude > 9 then return end
			local dir = ((sac.Position - racine.Position) * Vector3.new(1, 0, 1)).Unit
			sac:ApplyImpulse(dir * sac.AssemblyMass * FORCE_COUP)
			bruit.PlaybackSpeed = 0.9 + math.random() * 0.25
			bruit:Play()
			coups += 1
			t.Text = "COUPS : " .. coups
		end)
	end
end

-- =========================================================
--  4. LES TAPIS (des modeles TapisDeCourse : TapisDeCourse.lua)
--  Chaque tapis a SA vitesse (l attribut "Vitesse" du modele). Deux boutons
--  la changent (Q moins vite, E plus vite). La bande pousse le coureur vers
--  l arriere a cette vitesse ; pour qu il puisse suivre, sa vitesse de
--  marche monte tant qu il est sur le tapis. La console dit le niveau, qui
--  court, et la distance.
-- =========================================================
local VITESSES = {6, 10, 14, 18, 22, 26}     -- les crans des boutons
local function niveau(v)
	if v <= 8 then return "MARCHE", Color3.fromRGB(80, 220, 120)
	elseif v <= 16 then return "FOOTING", Color3.fromRGB(255, 190, 60)
	else return "SPRINT", Color3.fromRGB(255, 80, 60) end
end

local tapis = {}
local function majConsole(t)
	if not t.ecran then return end
	local v = t.modele:GetAttribute("Vitesse") or 14
	local nom, couleur = niveau(v)
	t.ecran.TextColor3 = couleur
	t.ecran.Text = string.format("TAPIS %d · %s\n%d km/h", t.modele:GetAttribute("Numero") or 0, nom, v)
		.. (t.coureur and string.format("\n%s · %.2f km", t.coureur.DisplayName, t.km) or "")
end
for _, m in ipairs(salle:GetChildren()) do
	local bande = m:IsA("Model") and m.Name == "TapisDeCourse" and m:FindFirstChild("TapisCourse")
	if bande then
		local t = {modele = m, bande = bande, ecran = texteDe(m:FindFirstChild("ConsoleTapis")), km = 0}
		table.insert(tapis, t)
		local function appliquer()
			-- la bande "roule" vers l arriere du coureur (+Z de la bande)
			bande.AssemblyLinearVelocity = bande.CFrame:VectorToWorldSpace(Vector3.new(0, 0, m:GetAttribute("Vitesse") or 14))
			majConsole(t)
		end
		m:GetAttributeChangedSignal("Vitesse"):Connect(appliquer)
		appliquer()
		for _, b in ipairs({{"BoutonMoins", -1}, {"BoutonPlus", 1}}) do
			local bouton = m:FindFirstChild(b[1])
			local prompt = bouton and bouton:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function()
					-- le cran le plus proche de la vitesse actuelle, puis un cran de plus ou de moins
					local v, i = m:GetAttribute("Vitesse") or 14, 1
					for k, x in ipairs(VITESSES) do
						if math.abs(x - v) < math.abs(VITESSES[i] - v) then i = k end
					end
					m:SetAttribute("Vitesse", VITESSES[math.clamp(i + b[2], 1, #VITESSES)])
				end)
			end
		end
	end
end

local marcheNormale = {}     -- joueur -> sa vitesse de marche avant de monter sur un tapis
task.spawn(function()
	while true do
		local surUnTapis = {}
		for _, t in ipairs(tapis) do
			local coureur, humCoureur = nil, nil
			for _, j in ipairs(Players:GetPlayers()) do
				local r = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
				local hum = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
				if r and hum then
					local l = t.bande.CFrame:PointToObjectSpace(r.Position)
					if math.abs(l.X) < t.bande.Size.X / 2 and math.abs(l.Z) < t.bande.Size.Z / 2 and l.Y > 0 and l.Y < 5 then
						coureur, humCoureur = j, hum
					end
				end
			end
			local v = t.modele:GetAttribute("Vitesse") or 14
			if coureur then
				surUnTapis[coureur] = true
				marcheNormale[coureur] = marcheNormale[coureur] or humCoureur.WalkSpeed
				humCoureur.WalkSpeed = math.max(marcheNormale[coureur], v + 4)    -- 4 de marge pour avancer
				if t.coureur ~= coureur then t.coureur, t.km = coureur, 0 end
				t.km += v / 3600 * 0.25                  -- v km/h pendant 0,25 seconde
				majConsole(t)
			elseif t.coureur then
				t.coureur = nil
				majConsole(t)
			end
		end
		-- ceux qui sont descendus : on leur rend leur vitesse de marche
		for j, vitesse in pairs(marcheNormale) do
			if not surUnTapis[j] then
				local hum = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
				if hum then hum.WalkSpeed = vitesse end
				marcheNormale[j] = nil
			end
		end
		task.wait(0.25)
	end
end)

print("Salle de sport prete")
