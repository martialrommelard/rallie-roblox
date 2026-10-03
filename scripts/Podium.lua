-- =========================================================
--  LE PODIUM
--  A placer dans ServerScriptService.
--
--  Quand la course est finie, les 3 premiers arrives apparaissent
--  sur le podium de la montagne (Circuit > Podium) : des STATUES
--  geantes a l image de leur avatar -- les vrais joueurs, eux,
--  restent au spawn. Des confettis explosent. Les statues
--  disparaissent au depart de la course suivante.
--
--  Ce script ne touche a aucun autre : il ecoute l attribut
--  "DernierTemps" que CompteurTours pose sur un joueur a l arrivee
--  (l ordre des arrivees = l ordre du podium), et l attribut
--  "CourseEnCours" du workspace.
-- =========================================================

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")

local ECHELLE    = 8      -- les statues sont 8 fois plus grandes qu un avatar
local DELAI      = 4      -- secondes apres la fin : le temps que tous soient revenus au spawn
local NB_PODIUM  = 3
local RAYON_DECOR = 150   -- l ecran du spawn montre aussi le paysage a moins de 150 studs du podium
                          -- (260 = 653 morceaux copies : trop lourd)
local OR, ARGENT, BRONZE = Color3.fromRGB(255, 205, 60), Color3.fromRGB(215, 220, 230), Color3.fromRGB(215, 140, 80)
local CONFETTIS  = {
	Color3.fromRGB(255, 60, 70), Color3.fromRGB(255, 205, 60), Color3.fromRGB(70, 220, 110),
	Color3.fromRGB(0, 200, 255), Color3.fromRGB(255, 110, 200), Color3.fromRGB(255, 255, 255),
}

local podium = workspace:WaitForChild("Circuit"):WaitForChild("Podium")

local statues = workspace:FindFirstChild("StatuesPodium") or Instance.new("Folder")
statues.Name = "StatuesPodium"
statues.Parent = workspace

-- ---- LES ARRIVEES DE LA COURSE EN COURS ----
local arrivees = {}      -- les joueurs, dans l ordre ou ils ont fini
local enCourse = false

local function suivre(joueur)
	joueur:GetAttributeChangedSignal("DernierTemps"):Connect(function()
		-- On ne regarde PAS CourseEnCours ici : pour le dernier arrive, il
		-- vient tout juste de passer a false. "enCourse" ne change que dans
		-- le signal de CourseEnCours, qui passe APRES celui-ci.
		if enCourse then
			table.insert(arrivees, joueur)
		end
	end)
end
Players.PlayerAdded:Connect(suivre)
for _, j in ipairs(Players:GetPlayers()) do suivre(j) end

-- ---- LES MARCHES ----
-- "Marche1" est la plus haute (le 1er), etc. On pose la statue sur ce
-- qu il y a de plus haut au-dessus de la marche (la bordure doree).
local function marche(n)
	return podium:FindFirstChild("Marche" .. n)
end

local function dessusDe(m)
	local haut = m.Position.Y + m.Size.Y / 2
	for _, p in ipairs(podium:GetChildren()) do
		if p:IsA("BasePart") and p ~= m then
			local d = Vector3.new(p.Position.X - m.Position.X, 0, p.Position.Z - m.Position.Z)
			if d.Magnitude < 1 then haut = math.max(haut, p.Position.Y + p.Size.Y / 2) end
		end
	end
	return haut
end

-- ---- UNE STATUE A L IMAGE D UN JOUEUR ----
-- 1er essai : on demande a Roblox l avatar du joueur (debout, bien droit).
-- Sinon : une copie de son personnage.
local function creerStatue(joueur)
	local modele
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(joueur.UserId)
	end)
	if ok and description then
		local ok2, m = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if ok2 then modele = m end
	end
	if not modele and joueur.Character then
		joueur.Character.Archivable = true      -- sinon :Clone() renvoie nil
		modele = joueur.Character:Clone()
		joueur.Character.Archivable = false
	end
	if not modele then return nil end

	-- une statue : rien ne bouge, aucun script, pas de nom flottant
	for _, d in ipairs(modele:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local humanoide = modele:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	modele.Name = "Statue_" .. joueur.Name
	return modele
end

-- ---- LA POSER SUR SA MARCHE, EN GEANT ----
local function poser(statue, n, joueur)
	local m = marche(n)
	if not m then statue:Destroy() return end
	statue.Parent = statues
	statue:ScaleTo(ECHELLE)                       -- 8 fois plus grande, d un coup

	-- tournee vers le spawn
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local face = Vector3.new(0, 0, 1)
	if spawn then
		local d = spawn.Position - m.Position
		face = Vector3.new(d.X, 0, d.Z).Unit
	end

	-- les pieds pile sur le dessus de la marche : on mesure de combien le
	-- pivot de la statue est au-dessus du bas de sa boite
	local boite, taille = statue:GetBoundingBox()
	local hauteurPivot = statue:GetPivot().Position.Y - (boite.Position.Y - taille.Y / 2)
	local pos = Vector3.new(m.Position.X, dessusDe(m) + hauteurPivot, m.Position.Z)
	statue:PivotTo(CFrame.lookAt(pos, pos + face))

	-- le nom et la place, au-dessus de la tete
	local tete = statue:FindFirstChild("Head")
	if tete then
		local panneau = Instance.new("BillboardGui")
		panneau.Size = UDim2.new(36, 0, 7, 0)     -- en studs : se voit de loin
		panneau.StudsOffset = Vector3.new(0, 9, 0)
		panneau.Adornee = tete
		panneau.LightInfluence = 0
		panneau.Parent = tete
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextStrokeTransparency = 0.2
		t.TextColor3 = (n == 1 and OR) or (n == 2 and ARGENT) or BRONZE
		t.Text = ((n == 1) and "1er" or (n .. "ème")) .. "  " .. joueur.Name
		t.Parent = panneau
	end
end

-- ---- LES CONFETTIS ----
-- Une piece invisible au-dessus du podium, avec un emetteur de
-- particules par couleur. Rate = 0 : il n emet rien tout seul ; on
-- declenche des salves avec :Emit().
local function confettis()
	local m = marche(1)
	if not m then return end
	local source = Instance.new("Part")
	source.Name = "Confettis"
	source.Anchored = true
	source.CanCollide = false
	source.CanQuery = false
	source.Transparency = 1
	source.Size = Vector3.new(60, 1, 40)
	source.Position = Vector3.new(m.Position.X, dessusDe(m) + 70, m.Position.Z)
	source.Parent = statues
	local emetteurs = {}
	for _, couleur in ipairs(CONFETTIS) do
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Color = ColorSequence.new(couleur)
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.LightEmission = 0.4
		e.Size = NumberSequence.new(1.6)
		e.Lifetime = NumberRange.new(5, 7)
		e.Speed = NumberRange.new(40, 80)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -30, 0)   -- ils retombent
		e.Drag = 0.8
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-250, 250)
		e.Parent = source
		table.insert(emetteurs, e)
	end
	task.spawn(function()
		for _ = 1, 3 do                           -- 3 salves
			for _, e in ipairs(emetteurs) do e:Emit(50) end
			task.wait(1)
		end
	end)
	Debris:AddItem(source, 12)                    -- on range la source apres
end

-- ---- L ECRAN DU PODIUM, DANS LE SPAWN ----
-- Une "fenetre 3D" (ViewportFrame) ne montre pas le vrai monde : elle
-- montre ce qu on met DEDANS. On y met donc une COPIE du podium et des
-- statues, et une camera placee devant, du cote du spawn.
-- L ecran est pose par le generateur scripts/ZoneSpawn.lua.
local function majEcran(noms)
	local zone = workspace:FindFirstChild("ZoneSpawn")
	local ecran = zone and zone:FindFirstChild("EcranPodium")
	local gui = ecran and ecran:FindFirstChild("Ecran")
	local vue = gui and gui:FindFirstChild("Vue")
	local m1 = marche(1)
	if not (vue and m1) then return end

	vue:ClearAllChildren()
	for _, p in ipairs(podium:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Panneau" then p:Clone().Parent = vue end
	end
	for _, s in ipairs(statues:GetChildren()) do
		if s:IsA("Model") then s:Clone().Parent = vue end
	end
	-- LE PAYSAGE AUTOUR (2026-10-03) : pour que l ecran ressemble a une
	-- vraie camera, et pas a un podium qui flotte dans le vide, on copie
	-- aussi la montagne, les rochers, la route... qui sont pres du podium.
	-- (Roblox ne sait pas filmer le vrai monde : une "fenetre 3D" ne
	-- montre que les copies qu on met dedans.)
	local circuit = podium.Parent
	for _, nom in ipairs({"Montagne", "Eboulis", "Decor", "Route", "Barrieres", "Talus", "Tunnel"}) do
		local dossier = circuit:FindFirstChild(nom)
		if dossier then
			for _, p in ipairs(dossier:GetChildren()) do
				if p:IsA("BasePart") and (p.Position - m1.Position).Magnitude < RAYON_DECOR then
					p:Clone().Parent = vue
				end
			end
		end
	end
	-- le petit "EN DIRECT" rouge, comme a la tele
	if not gui:FindFirstChild("Direct") then
		local t = Instance.new("TextLabel")
		t.Name = "Direct"
		t.Position = UDim2.fromScale(0.02, 0.16)
		t.Size = UDim2.fromScale(0.3, 0.08)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = Color3.fromRGB(255, 60, 60)
		t.Text = "● EN DIRECT"
		t.ZIndex = 3
		t.Parent = gui
	end

	-- la camera : devant le podium, du cote du spawn, un peu en hauteur
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local face = Vector3.new(0, 0, 1)
	if spawn then
		local d = spawn.Position - m1.Position
		face = Vector3.new(d.X, 0, d.Z).Unit
	end
	local vise = Vector3.new(m1.Position.X, dessusDe(m1) + 10, m1.Position.Z)
	-- ATTENTION : une Camera creee ICI (sur le serveur) n arrive PAS chez
	-- les joueurs, et sans camera la fenetre 3D reste NOIRE. On note donc
	-- seulement ou la mettre ; le LocalScript CameraPodium la cree chez
	-- chaque joueur.
	vue:SetAttribute("Camera", CFrame.lookAt(vise + face * 175 + Vector3.new(0, 25, 0), vise))
	vue:SetAttribute("Champ", 50)

	gui.Noms.Text = noms or "en attente de la fin d'une course..."
end

-- ---- LA CEREMONIE ----
local function ceremonie(podiumListe)
	statues:ClearAllChildren()
	local noms = {}
	for n = 1, math.min(NB_PODIUM, #podiumListe) do
		local joueur = podiumListe[n]
		if joueur.Parent then                      -- il n a pas quitte le jeu
			local statue = creerStatue(joueur)
			if statue then poser(statue, n, joueur) end
			table.insert(noms, ((n == 1) and "1er " or (n .. "ème ")) .. joueur.Name)
		end
	end
	if #podiumListe > 0 then
		confettis()
		print("Podium : " .. #podiumListe .. " pilote(s) a l arrivee")
	end
	majEcran(#noms > 0 and table.concat(noms, "   •   ") or nil)
end

-- ---- DEBUT ET FIN DE COURSE ----
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	local maintenant = workspace:GetAttribute("CourseEnCours") == true
	if maintenant and not enCourse then
		-- une nouvelle course part : le podium de la precedente s en va
		arrivees = {}
		statues:ClearAllChildren()
		majEcran()
	elseif enCourse and not maintenant then
		-- la course est finie : on garde la liste, et on attend que tout le
		-- monde soit revenu au spawn
		local liste = arrivees
		task.delay(DELAI, function()
			if not workspace:GetAttribute("CourseEnCours") then
				ceremonie(liste)
			end
		end)
	end
	enCourse = maintenant
end)

-- au lancement du jeu : l ecran montre le podium vide
majEcran()
