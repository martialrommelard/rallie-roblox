-- =========================================================
--  L EPICERIE, EN PLAY  (Script dans ServerScriptService)
--    1. LES PIECES : chaque joueur a un compteur "Pièces" (leaderstats :
--       on le voit dans la liste des joueurs). On en GAGNE en finissant
--       une course (plus si on est sur le podium). Elles sont gardees dans
--       un DataStore (ou en memoire si Studio n y a pas acces).
--    2. ACHETER : chaque "ZoneAchat" posee par Epicerie.lua recoit un
--       bouton "Acheter" ; on paie, et le produit arrive dans l inventaire.
--    3. MANGER : on clique avec le produit en main -> 3 bouchees -> l effet.
--    4. LES BOOSTS : vitesse, saut... pendant un temps, puis tout revient.
--    5. LA CAISSIERE : un PNJ derriere le comptoir, qui explique.
--    6. LA TOMATE VOLANTE : on vole ; en course, on devient chasseur.
--    7. LA GLACE : on lance des boules qui congelent (meme un pilote).
--  Les produits, leurs prix et leurs effets : ReplicatedStorage/Produits.
-- =========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local DataStoreService  = game:GetService("DataStoreService")
local StarterPlayer     = game:GetService("StarterPlayer")

local Produits = require(ReplicatedStorage:WaitForChild("Produits"))
local modeles  = ServerStorage:WaitForChild("Epicerie"):WaitForChild("Modeles")
local magasin  = workspace:WaitForChild("ZoneSpawn"):WaitForChild("Epicerie")

local GAINS_PLACE  = {10, 5, 3}      -- pieces pour le 1er, le 2eme, le 3eme
local GAIN_ARRIVEE = 1               -- pour les suivants, s ils finissent (elimine : rien)
local SAUVE_TOUTES = 60              -- secondes entre deux sauvegardes automatiques
local MAX_SAC      = 5               -- produits dans l inventaire, au plus
-- LE CREATEUR DU JEU (moi) : pieces illimitees, il ne paie pas et on ne
-- sauve pas son compte. Les autres joueurs gagnent leurs pieces en course.
local function illimite(joueur)
	return joueur.UserId == game.CreatorId
end
local JAUNE = Color3.fromRGB(255, 225, 60)
local ROUGE = Color3.fromRGB(255, 90, 90)
local VERT  = Color3.fromRGB(90, 230, 120)

-- pour parler a l ecran du joueur (Epicerie.client)
local message = ReplicatedStorage:FindFirstChild("MessageEpicerie")
if not message then
	message = Instance.new("RemoteEvent")
	message.Name = "MessageEpicerie"
	message.Parent = ReplicatedStorage
end
local function dire(joueur, texte, couleur)
	message:FireClient(joueur, texte, couleur or Color3.new(1, 1, 1))
end

-- =========================================================
-- 1. LES PIECES
-- =========================================================
local store = DataStoreService:GetDataStore("Pieces_v1")
local chargeOk = {}       -- [joueur] = vrai si on a bien LU son compte (sinon on n ecrase rien)

local function pieces(joueur)
	local ls = joueur:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Pièces")
end

local function ajouter(joueur, n, texte)
	local v = pieces(joueur)
	if not v then return end
	v.Value += n
	if texte then dire(joueur, texte, JAUNE) end
end

local function sauver(joueur)
	local v = pieces(joueur)
	if not (v and chargeOk[joueur]) or illimite(joueur) then return end
	pcall(function() store:SetAsync(tostring(joueur.UserId), v.Value) end)
end

local function ouvrirCompte(joueur)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local v = Instance.new("IntValue")
	v.Name = "Pièces"
	v.Parent = ls
	ls.Parent = joueur
	local ok, valeur = pcall(function() return store:GetAsync(tostring(joueur.UserId)) end)
	if ok then
		chargeOk[joueur] = true
		v.Value = valeur or 0
	else
		print("Epicerie : pieces gardees en memoire seulement (" .. tostring(valeur) .. ")")
	end
	if illimite(joueur) then v.Value = 999999 end
end
Players.PlayerAdded:Connect(ouvrirCompte)
for _, j in ipairs(Players:GetPlayers()) do ouvrirCompte(j) end
Players.PlayerRemoving:Connect(function(joueur)
	sauver(joueur)
	chargeOk[joueur] = nil
end)
game:BindToClose(function()
	for _, j in ipairs(Players:GetPlayers()) do sauver(j) end
end)
-- et toutes les minutes, au cas ou le serveur s arreterait d un coup
task.spawn(function()
	while true do
		task.wait(SAUVE_TOUTES)
		for _, j in ipairs(Players:GetPlayers()) do sauver(j) end
	end
end)

-- LES GAINS DE COURSE : CompteurTours ecrit "DernierTemps" sur le joueur
-- quand il finit ; on compte les arrivees depuis le depart pour sa place.
local arrives = 0
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then arrives = 0 end
end)
local function suivreCourse(joueur)
	joueur:GetAttributeChangedSignal("DernierTemps"):Connect(function()
		arrives += 1
		local gain = GAINS_PLACE[arrives] or GAIN_ARRIVEE
		local place = (arrives == 1) and "1er" or (arrives .. "ème")
		ajouter(joueur, gain, "Course finie (" .. place .. ") : +" .. gain .. " pièces")
	end)
end
Players.PlayerAdded:Connect(suivreCourse)
for _, j in ipairs(Players:GetPlayers()) do suivreCourse(j) end

-- =========================================================
-- 4. LES BOOSTS (avant MANGER, qui s en sert)
-- La fin de chaque boost est notee sur le joueur : "Boost_vitesse" = l heure
-- du serveur ou il s arrete. L ecran du joueur lit cet attribut pour le
-- compte a rebours ; ce script le lit pour savoir quand tout remettre.
-- =========================================================
local function humanoide(joueur)
	return joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
end

-- des etincelles autour du joueur pendant le boost
local function etincelles(joueur, nom, couleur, actif)
	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if not racine then return end
	local e = racine:FindFirstChild(nom)
	if actif and not e then
		e = Instance.new("ParticleEmitter")
		e.Name = nom
		e.Color = ColorSequence.new(couleur)
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.25, 0)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Rate = 25
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = racine
	elseif not actif and e then
		e:Destroy()
	end
end

-- la trainee de lumiere de Flash : une Trail entre 2 points du torse (haut et bas)
local function trainee(hum, actif)
	local racine = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart")
	if not racine then return end
	local t = racine:FindFirstChild("TraineeFlash")
	if actif and not t then
		local haut, bas = Instance.new("Attachment"), Instance.new("Attachment")
		haut.Name, bas.Name = "FlashHaut", "FlashBas"
		haut.Position, bas.Position = Vector3.new(0, 1.2, 0), Vector3.new(0, -1.5, 0)
		haut.Parent, bas.Parent = racine, racine
		t = Instance.new("Trail")
		t.Name = "TraineeFlash"
		t.Attachment0, t.Attachment1 = haut, bas
		t.Color = ColorSequence.new(Color3.fromRGB(255, 230, 40), Color3.fromRGB(255, 40, 20))
		t.Transparency = NumberSequence.new(0.1, 1)
		t.LightEmission = 1
		t.Lifetime = 0.35
		t.Parent = racine
	elseif not actif and t then
		t:Destroy()
		for _, nom in ipairs({"FlashHaut", "FlashBas"}) do
			local a = racine:FindFirstChild(nom)
			if a then a:Destroy() end
		end
	end
end

local EFFETS = {
	vitesse = {
		couleur = Color3.fromRGB(255, 220, 40),
		mettre = function(hum, p)
			-- "VitesseBase" : la vitesse de marche normale du moment ; le tapis
			-- de course (SalleSportServeur) la lit pour savoir quoi rendre
			hum:SetAttribute("VitesseBase", p.valeur)
			hum.WalkSpeed = p.valeur
			trainee(hum, true)
		end,
		enlever = function(hum)
			hum:SetAttribute("VitesseBase", nil)
			hum.WalkSpeed = StarterPlayer.CharacterWalkSpeed
			trainee(hum, false)
		end,
	},
	-- le vol et la glace : le serveur n a rien a changer sur le personnage.
	-- L attribut "Boost_vol" / "Boost_glace" suffit : c est lui qu on verifie
	-- quand le joueur demande a voler ou lance une boule.
	vol = {
		couleur = Color3.fromRGB(235, 45, 30),
		mettre = function() end,
		enlever = function(hum)
			local joueur = Players:GetPlayerFromCharacter(hum.Parent)
			if joueur then joueur:SetAttribute("EnVol", nil) end
		end,
	},
	glace = {
		couleur = Color3.fromRGB(150, 220, 255),
		mettre = function() end,
		enlever = function() end,
	},
	saut = {
		couleur = Color3.fromRGB(255, 80, 170),
		mettre = function(hum, p)
			if hum.UseJumpPower then hum.JumpPower = StarterPlayer.CharacterJumpPower * p.valeur
			else hum.JumpHeight = StarterPlayer.CharacterJumpHeight * p.valeur * p.valeur end   -- hauteur ~ vitesse au carre
		end,
		enlever = function(hum)
			hum.JumpPower = StarterPlayer.CharacterJumpPower
			hum.JumpHeight = StarterPlayer.CharacterJumpHeight
		end,
	},
}
local actifs = {}     -- [joueur] = {[effet] = produit}
local FIN_DE_COURSE = 1e12   -- "l heure de fin" d un boost qui dure jusqu a la fin de la course
local jusquAuDepart = {}     -- [joueur] = vrai : pas de course quand il a mange, on attend la prochaine

local function appliquer(joueur, p)
	local e = EFFETS[p.effet]
	if not e then return end
	local maintenant = workspace:GetServerTimeNow()
	local nom = "Boost_" .. p.effet
	local fin
	if p.duree == "course" then
		-- "jusqu a la fin de la course" : on ne connait pas l heure. On met
		-- une fin tres loin ; c est la fin de la course qui l arretera (plus bas).
		fin = FIN_DE_COURSE
		jusquAuDepart[joueur] = not workspace:GetAttribute("CourseEnCours")
	else
		-- deja actif : on rallonge (au plus 3 fois la duree)
		fin = math.max(joueur:GetAttribute(nom) or 0, maintenant) + p.duree
		fin = math.min(fin, maintenant + 3 * p.duree)
	end
	joueur:SetAttribute(nom, fin)
	actifs[joueur] = actifs[joueur] or {}
	actifs[joueur][p.effet] = p
	local hum = humanoide(joueur)
	if hum then e.mettre(hum, p) end
	etincelles(joueur, nom, e.couleur, true)
end

-- toutes les 0,25 s : les boosts finis, on remet tout comme avant
task.spawn(function()
	while true do
		local maintenant = workspace:GetServerTimeNow()
		for joueur, liste in pairs(actifs) do
			for effet, p in pairs(liste) do
				local nom = "Boost_" .. effet
				if (joueur:GetAttribute(nom) or 0) <= maintenant then
					liste[effet] = nil
					joueur:SetAttribute(nom, nil)
					local hum = humanoide(joueur)
					if hum then EFFETS[effet].enlever(hum) end
					etincelles(joueur, nom, nil, false)
					dire(joueur, p.nom .. " : c'est fini !", Color3.fromRGB(200, 200, 200))
				end
			end
		end
		task.wait(0.25)
	end
end)

-- on meurt pendant un boost : il continue sur le nouveau personnage
local function suivreRespawn(joueur)
	joueur.CharacterAdded:Connect(function(perso)
		joueur:SetAttribute("EnVol", nil)        -- le nouveau personnage repart a pied
		local hum = perso:WaitForChild("Humanoid")
		perso:WaitForChild("HumanoidRootPart")
		for effet, p in pairs(actifs[joueur] or {}) do
			EFFETS[effet].mettre(hum, p)
			etincelles(joueur, "Boost_" .. effet, EFFETS[effet].couleur, true)
		end
	end)
end
Players.PlayerAdded:Connect(suivreRespawn)
for _, j in ipairs(Players:GetPlayers()) do suivreRespawn(j) end
Players.PlayerRemoving:Connect(function(j) actifs[j], jusquAuDepart[j] = nil, nil end)

-- un remote, cree s il manque
local function remote(nom)
	local r = ReplicatedStorage:FindFirstChild(nom)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = nom
		r.Parent = ReplicatedStorage
	end
	return r
end
local function actif(joueur, effet)
	return (joueur:GetAttribute("Boost_" .. effet) or 0) > workspace:GetServerTimeNow()
end

-- =========================================================
-- 6. LA TOMATE VOLANTE
-- Le joueur demande a voler (bouton VOLER ou touche F) ; le serveur
-- verifie qu il a le pouvoir et note "EnVol". C est l ecran du joueur qui
-- le fait voler (lui seul sait ou il appuie). Pendant une course, voler
-- = devenir CHASSEUR : on le sort de sa voiture, et CompteurTours arrete
-- sa course (attribut "Chasseur").
-- =========================================================
local voler = remote("Voler")
voler.OnServerEvent:Connect(function(joueur, veutVoler)
	if veutVoler and actif(joueur, "vol") then
		local hum = humanoide(joueur)
		if hum and hum.SeatPart then              -- on descend de la voiture (comme CompteurTours)
			local soudure = hum.SeatPart:FindFirstChild("SeatWeld")
			if soudure then soudure:Destroy() end
		end
		if workspace:GetAttribute("CourseEnCours") then joueur:SetAttribute("Chasseur", true) end
		joueur:SetAttribute("EnVol", true)
	else
		joueur:SetAttribute("EnVol", nil)
	end
end)

-- CE QUE LES AUTRES VOIENT : des trainees de vent aux mains et aux pieds,
-- et une bouffee de fumee au decollage. Faites ici, par le serveur : ce que
-- l ecran d un joueur cree sur son personnage, les autres ne le voient pas.
local MEMBRES_VOL = {"LeftHand", "RightHand", "LeftFoot", "RightFoot"}
local function traineesVol(joueur, actif)
	local perso = joueur.Character
	if not perso then return end
	for _, nom in ipairs(MEMBRES_VOL) do
		local membre = perso:FindFirstChild(nom)
		local ancienne = membre and membre:FindFirstChild("TraineeVol")
		if ancienne then
			ancienne:Destroy()
			for _, a in ipairs(membre:GetChildren()) do
				if a.Name == "AttacheTraineeVol" then a:Destroy() end
			end
		end
		if membre and actif then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "AttacheTraineeVol", "AttacheTraineeVol"
			a0.Position, a1.Position = Vector3.new(0, 0.12, 0), Vector3.new(0, -0.12, 0)
			a0.Parent, a1.Parent = membre, membre
			local t = Instance.new("Trail")
			t.Name = "TraineeVol"
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 120, 100))
			t.Transparency = NumberSequence.new(0.3, 1)
			t.Lifetime = 0.5
			t.MinLength = 0.2
			t.LightEmission = 0.5
			t.Parent = membre
		end
	end
	local racine = perso:FindFirstChild("HumanoidRootPart")
	if actif and racine then
		local fumee = Instance.new("ParticleEmitter")
		fumee.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 130))
		fumee.Size = NumberSequence.new(1, 3)
		fumee.Transparency = NumberSequence.new(0.3, 1)
		fumee.Lifetime = NumberRange.new(0.6, 1)
		fumee.Speed = NumberRange.new(6, 10)
		fumee.SpreadAngle = Vector2.new(180, 180)
		fumee.Rate = 0
		fumee.Parent = racine
		fumee:Emit(30)
		task.delay(1.5, function() fumee:Destroy() end)
	end
end
local function suivreVol(joueur)
	joueur:GetAttributeChangedSignal("EnVol"):Connect(function()
		traineesVol(joueur, joueur:GetAttribute("EnVol") == true)
	end)
end
Players.PlayerAdded:Connect(suivreVol)
for _, j in ipairs(Players:GetPlayers()) do suivreVol(j) end

-- la course demarre : ceux qui attendaient la prochaine course ne l attendent
-- plus ; la course finit : tous les boosts "jusqu a la fin de la course"
-- s arretent (on met leur fin a maintenant : la boucle des boosts fait le reste)
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	local enCours = workspace:GetAttribute("CourseEnCours")
	for _, joueur in ipairs(Players:GetPlayers()) do
		if enCours then
			jusquAuDepart[joueur] = nil
			if joueur:GetAttribute("EnVol") then joueur:SetAttribute("Chasseur", true) end
		else
			joueur:SetAttribute("Chasseur", nil)
			for effet, p in pairs(actifs[joueur] or {}) do
				if p.duree == "course" and not jusquAuDepart[joueur] then
					joueur:SetAttribute("Boost_" .. effet, workspace:GetServerTimeNow())
				end
			end
		end
	end
end)

-- =========================================================
-- 7. LA GLACE : les boules qui congelent
-- Le joueur clique (Epicerie.client envoie le point vise). Le serveur fait
-- avancer la boule lui-meme, image par image, avec un rayon entre sa
-- position d avant et celle d apres : rien ne peut passer "entre deux images".
-- =========================================================
local VITESSE_BOULE = 140      -- studs/s
local PORTEE_BOULE  = 250      -- studs, apres quoi elle fond
local RECHARGE      = 0.4      -- secondes entre deux boules
local IMMUNITE      = 3        -- secondes sans pouvoir etre recongele, apres
local dernierTir = {}
local congeles = {}            -- [modele du personnage] = heure de fin (gel + immunite)

local function congeler(perso, duree)
	local maintenant = workspace:GetServerTimeNow()
	if (congeles[perso] or 0) > maintenant then return false end
	local hum = perso:FindFirstChildOfClass("Humanoid")
	local racine = perso:FindFirstChild("HumanoidRootPart")
	if not (hum and racine) then return false end
	congeles[perso] = maintenant + duree + IMMUNITE
	local joueur = Players:GetPlayerFromCharacter(perso)
	if joueur then
		dire(joueur, "❄️ CONGELÉ ! (" .. duree .. " s)", Color3.fromRGB(150, 220, 255))
		joueur:SetAttribute("CongeleJusqua", maintenant + duree)
	end
	-- dans une voiture : on fige la VOITURE (ancrer le siege fige toute la voiture)
	local fige = hum.SeatPart or racine
	local etaitAncre = fige.Anchored
	fige.Anchored = true
	-- le bloc de glace autour de lui
	local _, taille = perso:GetBoundingBox()
	local bloc = Instance.new("Part")
	bloc.Name = "BlocDeGlace"
	bloc.Size = Vector3.new(math.max(taille.X, 3), taille.Y + 0.5, math.max(taille.Z, 3))
	bloc.CFrame = racine.CFrame
	bloc.Anchored, bloc.CanCollide, bloc.CanQuery = true, false, false
	bloc.Material = Enum.Material.Ice
	bloc.Color = Color3.fromRGB(160, 220, 255)
	bloc.Transparency = 0.35
	bloc.Parent = workspace
	task.delay(duree, function()
		bloc:Destroy()
		if fige.Parent then fige.Anchored = etaitAncre end
		if joueur then joueur:SetAttribute("CongeleJusqua", nil) end
	end)
	return true
end

-- a qui appartient la piece touchee ? un personnage (joueur ou PNJ), ou une
-- voiture : alors c est son pilote
local function persoTouche(piece)
	local m = piece:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return m end
		local siege = m:FindFirstChild("DriveSeat", true)
		if siege and siege:IsA("VehicleSeat") and siege.Occupant then return siege.Occupant.Parent end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local lancer = remote("LancerGlace")
lancer.OnServerEvent:Connect(function(joueur, cible)
	if typeof(cible) ~= "Vector3" or not actif(joueur, "glace") then return end
	if (joueur:GetAttribute("CongeleJusqua") or 0) > workspace:GetServerTimeNow() then return end
	local maintenant = os.clock()
	if dernierTir[joueur] and maintenant - dernierTir[joueur] < RECHARGE then return end
	dernierTir[joueur] = maintenant
	local perso = joueur.Character
	local tete = perso and perso:FindFirstChild("Head")
	if not tete then return end
	local p = actifs[joueur] and actifs[joueur].glace
	local duree = p and p.valeur or 15

	local depart = tete.Position + Vector3.new(0, 0.5, 0)
	local dir = (cible - depart)
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	local boule = Instance.new("Part")
	boule.Name = "BouleDeGlace"
	boule.Shape = Enum.PartType.Ball
	boule.Size = Vector3.new(1.2, 1.2, 1.2)
	boule.Material = Enum.Material.Ice
	boule.Color = Color3.fromRGB(200, 240, 255)
	boule.Anchored, boule.CanCollide, boule.CanQuery, boule.CanTouch = true, false, false, false
	boule.CFrame = CFrame.new(depart)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	a0.Parent, a1.Parent = boule, boule
	local trace = Instance.new("Trail")
	trace.Attachment0, trace.Attachment1 = a0, a1
	trace.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	trace.Transparency = NumberSequence.new(0.3, 1)
	trace.Lifetime = 0.3
	trace.Parent = boule
	boule.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {perso, boule}
	local parcouru = 0
	local pos = depart
	local connexion
	connexion = game:GetService("RunService").Heartbeat:Connect(function(dt)
		local pas = VITESSE_BOULE * dt
		local touche = workspace:Raycast(pos, dir * pas, params)
		if touche then
			connexion:Disconnect()
			boule:Destroy()
			local cibleTouchee = persoTouche(touche.Instance)
			if cibleTouchee and cibleTouchee ~= perso and congeler(cibleTouchee, duree) then
				dire(joueur, "❄️ Touché : " .. cibleTouchee.Name .. " est congelé !", Color3.fromRGB(150, 220, 255))
			end
			return
		end
		pos += dir * pas
		parcouru += pas
		boule.CFrame = CFrame.new(pos)
		if parcouru > PORTEE_BOULE then
			connexion:Disconnect()
			boule:Destroy()
		end
	end)
end)
Players.PlayerRemoving:Connect(function(j) dernierTir[j] = nil end)

-- =========================================================
-- 3. MANGER
-- =========================================================
local function miettes(poignee, couleur)
	local m = Instance.new("ParticleEmitter")
	m.Color = ColorSequence.new(couleur)
	m.Size = NumberSequence.new(0.15)
	m.Lifetime = NumberRange.new(0.5, 0.8)
	m.Speed = NumberRange.new(2, 4)
	m.SpreadAngle = Vector2.new(60, 60)
	m.Acceleration = Vector3.new(0, -20, 0)
	m.Rate = 0
	m.Parent = poignee
	return m
end

local function fabriquerOutil(p)
	local outil = Instance.new("Tool")
	outil.Name = p.nom
	outil.ToolTip = p.texte
	outil.CanBeDropped = false
	outil:SetAttribute("Produit", p.id)
	local couleur = Color3.new(1, 1, 1)
	for _, piece in ipairs(modeles[p.id]:Clone():GetChildren()) do
		if piece:IsA("BasePart") then
			piece.Anchored = false
			piece.Massless = true
			piece.CanCollide = false
			if piece.Name ~= "Handle" then couleur = piece.Color end
		end
		piece.Parent = outil
	end
	local poignee = outil:WaitForChild("Handle")
	local m = miettes(poignee, couleur)
	local mange = false
	outil.Activated:Connect(function()
		if mange then return end
		mange = true
		local joueur = Players:GetPlayerFromCharacter(outil.Parent)
		for _ = 1, 3 do                   -- 3 bouchees
			m:Emit(10)
			task.wait(0.35)
		end
		outil:Destroy()
		if not joueur then return end
		if p.effet == "fun" then
			dire(joueur, p.nom .. " : " .. p.texte, VERT)
		else
			appliquer(joueur, p)
			dire(joueur, p.nom .. " : " .. p.texte, VERT)
		end
	end)
	return outil
end

-- =========================================================
-- 2. ACHETER
-- =========================================================
local function nbDansLeSac(joueur)
	local n = 0
	for _, conteneur in ipairs({joueur:FindFirstChild("Backpack"), joueur.Character}) do
		for _, o in ipairs(conteneur and conteneur:GetChildren() or {}) do
			if o:IsA("Tool") and o:GetAttribute("Produit") then n += 1 end
		end
	end
	return n
end

local function acheter(joueur, p)
	local v = pieces(joueur)
	if not v then return end
	if v.Value < p.prix then
		dire(joueur, "Pas assez de pièces : il t'en manque " .. (p.prix - v.Value) .. ". Gagne-les en course !", ROUGE)
		return
	end
	if nbDansLeSac(joueur) >= MAX_SAC then
		dire(joueur, "Ton sac est plein (" .. MAX_SAC .. " produits) : mange d'abord !", ROUGE)
		return
	end
	if not illimite(joueur) then v.Value -= p.prix end
	fabriquerOutil(p).Parent = joueur:WaitForChild("Backpack")
	dire(joueur, p.nom .. " acheté(e) ! Clique avec pour le manger.", JAUNE)
end

local function remplirEtiquette(e, p)
	local gui = e:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	for _, t in ipairs(gui:GetChildren()) do
		if t:IsA("TextLabel") then t:Destroy() end
	end
	for _, l in ipairs({{p.nom, 0.34}, {p.prix .. " pièces", 0.38}, {p.texte, 0.28}}) do
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, l[2])
		t.BackgroundTransparency = 1
		t.Text = l[1]
		t.TextColor3 = Color3.fromRGB(25, 25, 28)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = gui
	end
end

for _, d in ipairs(magasin:GetDescendants()) do
	local id = d:GetAttribute("Produit")
	local p = id and Produits.parId[id]
	if p and d.Name == "Etiquette" then
		remplirEtiquette(d, p)
	elseif p and d.Name == "ZoneAchat" then
		local bouton = Instance.new("ProximityPrompt")
		bouton.ActionText = "Acheter : " .. p.prix .. " pièces"
		bouton.ObjectText = p.nom
		bouton.HoldDuration = 0
		bouton.MaxActivationDistance = 8
		bouton.RequiresLineOfSight = false
		bouton.Parent = d
		bouton.Triggered:Connect(function(joueur) acheter(joueur, p) end)
	end
end

-- =========================================================
-- 5. LA CAISSIERE
-- =========================================================
local poste = magasin:FindFirstChild("PosteCaissiere")
if poste then
	local ok, perso = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok then
		perso.Name = "Caissiere"
		perso.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local bodyColors = perso:FindFirstChildOfClass("BodyColors")
		if bodyColors then bodyColors:Destroy() end
		for _, p in ipairs(perso:GetChildren()) do
			if p:IsA("BasePart") then
				if p.Name:find("Torso") or p.Name:find("UpperArm") then p.Color = Color3.fromRGB(40, 170, 80)   -- la tenue du magasin
				elseif p.Name:find("Leg") or p.Name:find("Foot") then p.Color = Color3.fromRGB(40, 40, 50)
				else p.Color = Color3.fromRGB(234, 184, 146) end
				p.CanCollide = false
			end
		end
		local hum = perso.Humanoid
		hum.DisplayName = "Caissière"
		hum.NameDisplayDistance = 25
		local racine = perso.HumanoidRootPart
		local sol = poste.Position - poste.CFrame.UpVector * poste.Size.Y / 2
		local pied = sol + Vector3.new(0, hum.HipHeight + racine.Size.Y / 2, 0)
		perso:PivotTo(CFrame.lookAt(pied, pied + poste.CFrame.LookVector))
		racine.Anchored = true
		perso.Parent = magasin
		-- on peut lui parler : elle dit combien on a et comment en gagner
		local parler = Instance.new("ProximityPrompt")
		parler.ActionText = "Parler"
		parler.ObjectText = "Caissière"
		parler.HoldDuration = 0
		parler.MaxActivationDistance = 10
		parler.RequiresLineOfSight = false
		parler.Parent = racine
		parler.Triggered:Connect(function(joueur)
			local v = pieces(joueur)
			dire(joueur, "Bonjour ! Tu as " .. (v and v.Value or 0) .. " pièces. En course : " .. GAINS_PLACE[1]
				.. " si tu es 1er, " .. GAINS_PLACE[2] .. " si 2ème, " .. GAINS_PLACE[3] .. " si 3ème, "
				.. GAIN_ARRIVEE .. " si tu finis !", JAUNE)
		end)
	else
		warn("Epicerie : pas de caissiere (" .. tostring(perso) .. ")")
	end
end

print("Epicerie prete : " .. #Produits .. " produits")
