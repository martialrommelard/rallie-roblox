-- =========================================================
--  LA SALLE DE SPORT ET LES SIMULATEURS QUI MARCHENT  (cote SERVEUR)
--  A placer dans ServerScriptService. Les objets sont construits par
--  SalleSport.lua (dans ZoneSpawn/SalleSport).
--
--    BANC     assis : la barre monte et descend, on compte les repetitions
--    VELOS    assis : le pedalier tourne, les kilometres defilent
--    SIMULATEURS  des BORNES D ARCADE : on reste assis et on joue sur l ecran
--             (un jeu de course vu de dessus, sur le vrai trace). Le jeu est
--             dans le LocalScript Arcade ; ici, on recopie la partie pour que
--             tout le monde la voie, et on garde le record.
--    SACS     un bouton "Frapper" : le sac part sous le coup
--    TAPIS    la console affiche le coureur et sa distance
-- =========================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
--  2. LES VELOS
-- =========================================================
for _, selle in ipairs(salle:GetChildren()) do
	if selle.Name == "VeloSport" then
		local pedalier = plusProcheDe("Pedalier", selle.Position)
		local ecran = texteDe(plusProcheDe("EcranVelo", selle.Position))
		local repos = pedalier and pedalier.CFrame
		local enCours = false
		selle:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not selle.Occupant or enCours or not pedalier then return end
			enCours = true
			local km = 0
			while selle.Occupant do
				-- le pedalier tourne autour de son axe (X, c est un cylindre)
				pedalier.CFrame = pedalier.CFrame * CFrame.Angles(math.rad(18), 0, 0)
				km += 0.0025
				if ecran then ecran.Text = string.format("%.2f km", km) end
				task.wait(0.05)
			end
			pedalier.CFrame = repos
			enCours = false
		end)
	end
end

-- =========================================================
--  3. LES SIMULATEURS : des BORNES D ARCADE
--  On reste ASSIS au simulateur et on joue SUR SON ECRAN : un jeu de course
--  vu de dessus, sur le vrai trace du circuit. Le jeu tourne chez le joueur
--  (LocalScript Arcade) ; il envoie au serveur ou en est sa voiture, et le
--  serveur la recopie dans des attributs du siege : comme ca, TOUS les
--  joueurs voient la partie sur l ecran de la borne.
-- =========================================================
local arcade = ReplicatedStorage:FindFirstChild("Arcade") or Instance.new("RemoteEvent")
arcade.Name = "Arcade"
arcade.Parent = ReplicatedStorage

local TOUR_MINI = 20       -- un tour en moins de 20 s, c est de la triche

local function enTexte(t)
	return string.format("%d:%05.2f", math.floor(t / 60), t % 60)
end

local record = nil          -- {temps, nom} : le meilleur tour fait sur les bornes
local sieges = {}
for _, siege in ipairs(salle:GetChildren()) do
	if siege.Name == "SiegeSimulateur" then table.insert(sieges, siege) end
end

-- l ecran "d attente" de la borne (quand personne ne joue)
local function majEcran(siege)
	local ecran = texteDe(plusProcheDe("EcranSimuCentre", siege.Position))
	if not ecran then return end
	local rec = record and ("\nRECORD : " .. enTexte(record.temps) .. " (" .. record.nom .. ")") or ""
	local nom = siege:GetAttribute("PiloteNom")
	ecran.Text = "SIMULATEUR " .. (siege:GetAttribute("Numero") or "") ..
		(nom and ("\nEN JEU : " .. nom) or "\nASSIEDS-TOI POUR JOUER") .. rec
end

local function siegeDe(joueur)
	for _, s in ipairs(sieges) do
		local hum = s.Occupant
		if hum and Players:GetPlayerFromCharacter(hum.Parent) == joueur then return s end
	end
end

for _, siege in ipairs(sieges) do
	majEcran(siege)
	siege:GetPropertyChangedSignal("Occupant"):Connect(function()
		local joueur = joueurAssis(siege)
		siege:SetAttribute("Pilote", joueur and joueur.UserId or nil)
		siege:SetAttribute("PiloteNom", joueur and joueur.DisplayName or nil)
		for _, k in ipairs({"X", "Z", "A", "Chrono", "Tours"}) do siege:SetAttribute(k, nil) end
		majEcran(siege)
	end)
end

-- LE CIRCUIT EN 3D, pour l ecran des bornes. A cause du streaming, l ecran du
-- joueur ne connait que le decor proche : c est le serveur qui envoie la
-- liste des pieces (position, taille, couleur), comme pour la minimap.
local DOSSIERS_3D = {"Route", "Barrieres", "Tunnel", "Decor", "Montagne", "Talus", "Damier",
	"Tremplin", "MarqueTremplin", "LigneDepart", "FeuxDepart"}
local circuit3D = nil
local function preparer3D()
	local pieces = {}
	local circuit = workspace:WaitForChild("Circuit")
	for _, nom in ipairs(DOSSIERS_3D) do
		for _, objet in ipairs(circuit:GetChildren()) do
			if objet.Name == nom then
				local liste = objet:IsA("BasePart") and {objet} or objet:GetDescendants()
				for _, p in ipairs(liste) do
					if p:IsA("BasePart") and p.Transparency < 0.9 then
						table.insert(pieces, {
							cf = p.CFrame, taille = p.Size, couleur = p.Color, matiere = p.Material,
							forme = p:IsA("Part") and p.Shape or nil,
							classe = (p:IsA("WedgePart") or p:IsA("CornerWedgePart")) and p.ClassName or "Part",
							route = (nom == "Route"),
						})
					end
				end
			end
		end
	end
	return pieces
end
local question3D = ReplicatedStorage:FindFirstChild("Circuit3D") or Instance.new("RemoteFunction")
question3D.Name = "Circuit3D"
question3D.Parent = ReplicatedStorage
question3D.OnServerInvoke = function()
	circuit3D = circuit3D or preparer3D()
	return circuit3D
end

arcade.OnServerEvent:Connect(function(joueur, quoi, a, b, c, d, e)
	-- le serveur ne croit pas l ecran : il faut etre ASSIS a une borne
	local siege = siegeDe(joueur)
	if not siege then return end
	if quoi == "etat" then
		-- ou est la voiture : x, z (en studs, sur le vrai circuit), angle, chrono, tours
		if typeof(a) == "number" and typeof(b) == "number" and typeof(c) == "number" then
			siege:SetAttribute("X", a)
			siege:SetAttribute("Z", b)
			siege:SetAttribute("A", c)
			siege:SetAttribute("Chrono", typeof(d) == "number" and d or nil)
			siege:SetAttribute("Tours", typeof(e) == "number" and e or nil)
		end
	elseif quoi == "tour" and typeof(a) == "number" and a >= TOUR_MINI and a < 600 then
		if not record or a < record.temps then
			record = {temps = a, nom = joueur.DisplayName}
			-- le record, dans des attributs de la salle : tous les ecrans le lisent
			salle:SetAttribute("RecordTemps", a)
			salle:SetAttribute("RecordNom", joueur.DisplayName)
			print(joueur.Name .. " bat le record des bornes : " .. enTexte(a))
		end
		for _, s in ipairs(sieges) do majEcran(s) end
	end
end)

-- =========================================================
--  4. LES SACS DE FRAPPE : on les FRAPPE pour de vrai
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
--  5. LES TAPIS : la console dit qui court, et la distance
-- =========================================================
local dejaCouru = {}      -- tapis -> distance (km)
task.spawn(function()
	while true do
		for _, bande in ipairs(salle:GetChildren()) do
			if bande.Name == "TapisCourse" then
				local console = texteDe(plusProcheDe("ConsoleTapis", bande.Position))
				local coureur = nil
				for _, j in ipairs(Players:GetPlayers()) do
					local r = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
					if r then
						local l = bande.CFrame:PointToObjectSpace(r.Position)
						if math.abs(l.X) < bande.Size.X / 2 and math.abs(l.Z) < bande.Size.Z / 2 and l.Y > 0 and l.Y < 5 then coureur = j end
					end
				end
				if coureur then
					-- 14 km/h pendant 0,25 seconde
					dejaCouru[bande] = (dejaCouru[bande] or 0) + 14 / 3600 * 0.25
					if console then console.Text = string.format("%s\n14 km/h · %.2f km", coureur.DisplayName, dejaCouru[bande]) end
				elseif dejaCouru[bande] then
					dejaCouru[bande] = nil
					if console then console.Text = "TAPIS\n14 km/h" end
				end
			end
		end
		task.wait(0.25)
	end
end)

print("Salle de sport et simulateurs prets")
