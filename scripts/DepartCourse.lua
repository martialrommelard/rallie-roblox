-- =========================================================
--  LE DEPART DE LA COURSE DEPUIS LE SPAWN
--  A placer dans ServerScriptService.
--
--  1. Un joueur appuie sur le bouton "DEMARRAGE DE LA COURSE" du
--     spawn (un ProximityPrompt, pose par scripts/ZoneSpawn.lua).
--  2. Son ecran affiche la grille : il choisit sa place
--     (LocalScript StarterPlayerScripts/ChoixPlace).
--  3. Quand TOUT LE MONDE a choisi -- ou ATTENTE_MAX secondes
--     apres le premier choix, pour qu un spectateur ne bloque pas
--     tout le monde -- chacun est assis dans la voiture de SA place.
--  4. Le reste est deja ecrit : quelqu un s assoit -> FeuxDepart
--     ferme les cages et lance les feux, comme avant.
--
--  C est le SERVEUR qui decide de tout : qui a quelle place, si elle
--  est libre, quand on part. L ecran du joueur ne fait qu afficher et
--  envoyer son choix (sinon, on pourrait tricher en prenant une place
--  deja prise).
-- =========================================================

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ATTENTE_MAX = 30   -- secondes apres le premier choix : on part quand meme

local circuit  = workspace:WaitForChild("Circuit")
local grille   = circuit:WaitForChild("Grille")
local ligne    = circuit:WaitForChild("LigneDepart")
local voitures = workspace:WaitForChild("Voitures")

-- Le RemoteEvent entre le serveur et les ecrans. On le cree s il manque.
local evt = ReplicatedStorage:FindFirstChild("DepartCourse")
if not evt then
	evt = Instance.new("RemoteEvent")
	evt.Name = "DepartCourse"
	evt.Parent = ReplicatedStorage
end

local choix = {}         -- choix[joueur] = nom de sa place ("Place3"...)
local ouverts = {}       -- ouverts[joueur] = true si son ecran de choix est ouvert
local finAttente = nil   -- l heure (os.clock) du depart automatique

-- ---- LES PLACES, DANS L ORDRE DU DEPART ----
-- On ne devine pas l ordre : on DEMANDE a la ligne. Vue depuis la ligne,
-- la grille est derriere elle (Z positif) ; la place la plus proche est
-- la P1. Le signe de X dit si elle est a gauche ou a droite.
local function places()
	local liste = {}
	for _, p in ipairs(grille:GetChildren()) do
		local avant = p:FindFirstChild("Avant")
		if avant then
			local rel = ligne.CFrame:PointToObjectSpace(avant.Position)
			table.insert(liste, {nom = p.Name, distance = rel.Z, cote = (rel.X < 0) and -1 or 1})
		end
	end
	table.sort(liste, function(a, b) return a.distance < b.distance end)
	return liste
end

local function voitureDe(nomPlace)
	for _, v in ipairs(voitures:GetChildren()) do
		if v:GetAttribute("Place") == nomPlace then return v end
	end
	return nil
end

-- Peut-on lancer une course ? Pas si elle tourne deja, pas si les
-- voitures ne sont pas encore revenues, pas si quelqu un est deja assis
-- dans une voiture (un depart se prepare).
local function coursePossible()
	if workspace:GetAttribute("CourseEnCours") then
		return false, "Une course est en cours : attends la fin !"
	end
	-- le script Voitures met GrilleEnPlace a false pendant la course et
	-- pendant le retour des voitures sur la grille
	if workspace:GetAttribute("GrilleEnPlace") == false or #voitures:GetChildren() == 0 then
		return false, "Les voitures reviennent sur la grille, patiente un peu..."
	end
	for _, v in ipairs(voitures:GetChildren()) do
		local siege = v:FindFirstChildWhichIsA("VehicleSeat", true)
		if siege and siege.Occupant then
			return false, "Un depart se prepare deja !"
		end
	end
	return true
end

local function nbChoisis()
	local n = 0
	for _ in pairs(choix) do n += 1 end
	return n
end

-- ---- CE QU ON ENVOIE AUX ECRANS ----
local function etat()
	local liste = {}
	for rang, p in ipairs(places()) do
		local pris = nil
		for joueur, nom in pairs(choix) do
			if nom == p.nom then pris = joueur.Name end
		end
		table.insert(liste, {nom = p.nom, rang = rang, cote = p.cote, pris = pris})
	end
	return {
		places  = liste,
		prets   = nbChoisis(),
		joueurs = #Players:GetPlayers(),
		reste   = finAttente and math.max(0, math.ceil(finAttente - os.clock())) or nil,
	}
end

local function diffuser()
	local e = etat()
	for joueur in pairs(ouverts) do
		evt:FireClient(joueur, "etat", e)
	end
end

-- ---- LE DEPART : chacun dans la voiture de sa place ----
local function lancer()
	local partants = choix
	choix, finAttente = {}, nil
	for joueur in pairs(ouverts) do
		evt:FireClient(joueur, "fermer")
	end
	ouverts = {}

	for joueur, nomPlace in pairs(partants) do
		task.spawn(function()
			local v = voitureDe(nomPlace)
			local perso = joueur.Character
			local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
			local siege = v and v:FindFirstChildWhichIsA("VehicleSeat", true)
			if not (humanoide and siege) then return end
			-- on pose le joueur au-dessus de son siege, et on l assoit.
			-- Plusieurs essais : le tout premier peut rater le temps que le
			-- personnage arrive (il vient de loin).
			for _ = 1, 15 do
				if humanoide.SeatPart == siege then break end
				perso:PivotTo(siege.CFrame + Vector3.new(0, 3, 0))
				task.wait(0.05)
				siege:Sit(humanoide)
				task.wait(0.2)
			end
			print(joueur.Name .. " part en " .. nomPlace)
		end)
	end
end

-- Tout le monde a choisi ? On part tout de suite.
local function verifier()
	local n = nbChoisis()
	if n > 0 and n >= #Players:GetPlayers() then
		lancer()
	end
end

-- ---- LE BOUTON ----
-- PromptTriggered marche pour TOUS les ProximityPrompt du jeu : on garde
-- celui qui s appelle "PromptCourse". Comme ca, meme si on relance le
-- generateur (nouveau bouton), ce script n a rien a refaire.
ProximityPromptService.PromptTriggered:Connect(function(prompt, joueur)
	if prompt.Name ~= "PromptCourse" then return end
	local ok, raison = coursePossible()
	if not ok then
		evt:FireClient(joueur, "message", raison)
		return
	end
	ouverts[joueur] = true
	evt:FireClient(joueur, "ouvrir", etat())
end)

-- ---- CE QUE LES ECRANS NOUS ENVOIENT ----
evt.OnServerEvent:Connect(function(joueur, action, nomPlace)
	if action == "choisir" and type(nomPlace) == "string" then
		if not coursePossible() then return end
		-- la place existe ?
		local existe = false
		for _, p in ipairs(places()) do
			if p.nom == nomPlace then existe = true end
		end
		if not existe then return end
		-- elle est libre ?
		for autre, nom in pairs(choix) do
			if nom == nomPlace and autre ~= joueur then return end
		end
		choix[joueur] = nomPlace
		ouverts[joueur] = true
		finAttente = finAttente or (os.clock() + ATTENTE_MAX)
		diffuser()
		verifier()
	elseif action == "annuler" then
		choix[joueur], ouverts[joueur] = nil, nil
		if nbChoisis() == 0 then finAttente = nil end
		diffuser()
		verifier()
	end
end)

Players.PlayerRemoving:Connect(function(joueur)
	choix[joueur], ouverts[joueur] = nil, nil
	if nbChoisis() == 0 then finAttente = nil end
	-- task.defer : le joueur qui part est encore compte a cet instant
	task.defer(function()
		diffuser()
		verifier()
	end)
end)

-- Le compte a rebours de l attente : on met les ecrans a jour chaque
-- seconde, et on part quand il arrive a zero.
while true do
	task.wait(1)
	if finAttente then
		if os.clock() >= finAttente then
			lancer()
		else
			diffuser()
		end
	end
end
