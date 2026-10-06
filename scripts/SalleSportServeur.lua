-- =========================================================
--  LA SALLE DE SPORT QUI MARCHE  (cote SERVEUR)
--  A placer dans ServerScriptService. Les objets sont construits par
--  SalleSport.lua (dans ZoneSpawn/SalleSport).
--
--    BANC     allonge : la barre descend, on la pousse au bon moment (jauge)
--    VELOS    assis : les kilometres defilent
--    SACS     un bouton "Frapper" : le sac part sous le coup
--    TAPIS    chacun sa vitesse, la console affiche le coureur et sa distance
--    BARRES   de traction : on compte, chaque barre a son record
-- =========================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")

local zone    = workspace:WaitForChild("ZoneSpawn")
local salle   = zone:WaitForChild("SalleSport")

local function texteDe(part)
	local g = part and part:FindFirstChildOfClass("SurfaceGui")
	return g and g:FindFirstChild("Texte")
end

-- =========================================================
--  1. LE BANC DE DEVELOPPE COUCHE (le modele BancDeMusculation : BancMusculation.lua)
--  Le jeu de la jauge est chez le joueur (Exercices). Ici, c est NOUS qui
--  bougeons la barre (comme ca, tout le monde la voit) :
--    "debut"  -> la barre descend sur la poitrine, puis EnBas = vrai
--    "pousse" -> (il a clique dans le vert) la barre monte : +1 ; puis elle
--                redescend et EnBas = vrai de nouveau
--    "fin"    -> la barre retourne sur les crochets
-- =========================================================
local evenementBanc = game:GetService("ReplicatedStorage"):FindFirstChild("Banc") or Instance.new("RemoteEvent")
evenementBanc.Name = "Banc"
evenementBanc.Parent = game:GetService("ReplicatedStorage")

local banc = salle:FindFirstChild("BancDeMusculation")
local barre = banc and banc:FindFirstChild("Barre")
if barre then
	local enHaut = barre.CFrame
	local enBas = enHaut - enHaut.UpVector * (banc:GetAttribute("Course") or 0.9)
	local serieBanc = nil          -- {joueur, n}
	local recordBanc = nil         -- {n, nom}
	local tour = 0                 -- change a chaque "fin" : les mouvements en route s arretent
	local function majPanneau()
		local texte = "DEVELOPPE COUCHE\nRECORD : " .. (recordBanc and string.format("%s · %d", recordBanc.nom, recordBanc.n) or "—")
			.. (serieBanc and string.format("\n%s : %d", serieBanc.joueur.DisplayName, serieBanc.n) or "")
		for _, g in ipairs(banc.PanneauBanc:GetChildren()) do
			local t = g:IsA("SurfaceGui") and g:FindFirstChild("Texte")
			if t then t.Text = texte end
		end
	end
	local function bouger(cf, duree)
		local tw = TweenService:Create(barre, TweenInfo.new(duree, Enum.EasingStyle.Sine), {CFrame = cf})
		tw:Play()
		return tw
	end
	local function descendre(monTour, duree)
		bouger(enBas, duree).Completed:Connect(function()
			if tour == monTour and serieBanc then banc:SetAttribute("EnBas", true) end
		end)
	end
	local function finir()
		tour += 1
		serieBanc = nil
		banc:SetAttribute("EnBas", false)
		banc:SetAttribute("Occupant", nil)
		bouger(enHaut, 0.6)
		majPanneau()
	end
	majPanneau()
	evenementBanc.OnServerEvent:Connect(function(joueur, quoi)
		local proprio = banc:GetAttribute("Occupant") == joueur.UserId
		if quoi == "fin" then if proprio then finir() end return end
		local r = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		if not r or (r.Position - barre.Position).Magnitude > 10 then return end
		if quoi == "debut" and not banc:GetAttribute("Occupant") then
			banc:SetAttribute("Occupant", joueur.UserId)
			serieBanc = {joueur = joueur, n = 0}
			descendre(tour, 1.2)
		elseif quoi == "pousse" and proprio and banc:GetAttribute("EnBas") then
			banc:SetAttribute("EnBas", false)
			serieBanc.n += 1
			if not recordBanc or serieBanc.n > recordBanc.n then recordBanc = {n = serieBanc.n, nom = joueur.DisplayName} end
			local monTour = tour
			bouger(enHaut, 0.45).Completed:Connect(function()
				task.wait(0.3)
				if tour == monTour then descendre(monTour, 1.0) end
			end)
		end
		majPanneau()
	end)
	Players.PlayerRemoving:Connect(function(joueur)
		if banc:GetAttribute("Occupant") == joueur.UserId then finir() end
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

-- =========================================================
--  5. LES BARRES DE TRACTION (les modeles BarreDeTraction : BarreTraction.lua)
--  Le jeu de la jauge tourne chez le joueur (Exercices). Il nous dit
--  "debut", "rep" (une traction) et "fin", avec la barre. Ici : une seule
--  personne par barre, on compte, et chaque barre garde son record.
--  Le serveur ne croit pas tout : il faut etre pres de la barre, et une
--  traction en moins de 0,4 s, c est de la triche.
-- =========================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local evenementTraction = ReplicatedStorage:FindFirstChild("Traction") or Instance.new("RemoteEvent")
evenementTraction.Name = "Traction"
evenementTraction.Parent = ReplicatedStorage

local stations = {}          -- modele -> {barre, panneau, record = {n, nom}}
local serie = {}             -- joueur -> {station, n, dernier}
local function majPanneau(station)
	local s = stations[station]
	local enCours = ""
	local qui = station:GetAttribute("Occupant") and Players:GetPlayerByUserId(station:GetAttribute("Occupant"))
	if qui and serie[qui] then enCours = string.format("\n%s : %d", qui.DisplayName, serie[qui].n) end
	local texte = "BARRE DE TRACTION " .. (station:GetAttribute("Numero") or "") .. "\nRECORD : "
		.. (s.record and string.format("%s · %d", s.record.nom, s.record.n) or "—") .. enCours
	for _, g in ipairs(s.panneau:GetChildren()) do        -- le panneau a 2 faces
		local t = g:IsA("SurfaceGui") and g:FindFirstChild("Texte")
		if t then t.Text = texte end
	end
end
for _, m in ipairs(salle:GetChildren()) do
	if m.Name == "BarreDeTraction" and m:FindFirstChild("BarreTraction") and m:FindFirstChild("PanneauTraction") then
		stations[m] = {barre = m.BarreTraction, panneau = m.PanneauTraction}
		majPanneau(m)
	end
end

local function lacher(joueur)
	local s = serie[joueur]
	serie[joueur] = nil
	if s and s.station:GetAttribute("Occupant") == joueur.UserId then
		s.station:SetAttribute("Occupant", nil)
		majPanneau(s.station)
	end
end
evenementTraction.OnServerEvent:Connect(function(joueur, quoi, station)
	if quoi == "fin" then lacher(joueur) return end           -- "fin" marche de partout (mort, reapparu...)
	local st = typeof(station) == "Instance" and stations[station]
	local r = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if not st or not r or (r.Position - st.barre.Position).Magnitude > 10 then return end
	if quoi == "debut" and not station:GetAttribute("Occupant") then
		lacher(joueur)
		station:SetAttribute("Occupant", joueur.UserId)
		serie[joueur] = {station = station, n = 0, dernier = 0}
	elseif quoi == "rep" and serie[joueur] and serie[joueur].station == station then
		local s = serie[joueur]
		if os.clock() - s.dernier < 0.4 then return end
		s.n += 1
		s.dernier = os.clock()
		if not st.record or s.n > st.record.n then st.record = {n = s.n, nom = joueur.DisplayName} end
	end
	majPanneau(station)
end)
Players.PlayerRemoving:Connect(lacher)

print("Salle de sport prete")
