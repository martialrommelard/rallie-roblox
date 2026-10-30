-- ============================================================
--  LE GARAGE (serveur)
--  A placer dans ServerScriptService.
--
--  1. Ce que chaque joueur POSSEDE : ses voitures, ses ameliorations,
--     sa peinture. Sauvegarde dans un DataStore (ou en memoire si Studio
--     n y a pas acces, comme les pieces de l epicerie).
--  2. Les ACHATS : c est le SERVEUR qui verifie le prix et retire les
--     pieces. L ecran (Garage.client) ne fait que demander.
--  3. Pour la course : les reglages de SA voiture sont poses en attributs
--     sur le joueur ("G_Puissance"...). DepartCourse les recopie sur la
--     voiture ou il s assoit.
--
--  Le garage lui-meme (sous le spawn) est pose par le generateur
--  scripts/Garage.lua ; les prix et les voitures sont dans
--  ReplicatedStorage.GarageCatalogue.
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Catalogue = require(ReplicatedStorage:WaitForChild("GarageCatalogue"))

local SAUVE_TOUTES = 60
local NB_NIVEAUX   = #Catalogue.PRIX_NIVEAUX

-- le createur du jeu : pieces illimitees (comme a l epicerie)
local function illimite(joueur)
	return joueur.UserId == game.CreatorId
end

local fonction = ReplicatedStorage:FindFirstChild("Garage")
if not fonction then
	fonction = Instance.new("RemoteFunction")
	fonction.Name = "Garage"
	fonction.Parent = ReplicatedStorage
end

-- =========================================================
-- 1. LES DONNEES DE CHAQUE JOUEUR
-- =========================================================
local store = DataStoreService:GetDataStore("Garage_v1")
local donnees  = {}   -- [joueur] = {voiture, possede, niveaux, couleur}
local chargeOk = {}   -- vrai si on a bien LU son garage (sinon on n ecrase rien)
local modifie  = {}   -- vrai s il y a quelque chose a sauver

local function parDefaut()
	return {voiture = "Jesko", possede = {Jesko = true}, niveaux = {}, couleur = 1}
end

local function pieces(joueur)
	local ls = joueur:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Pièces")
end

-- Les reglages de la course, en attributs sur le joueur : DepartCourse
-- les lit, et l ecran du garage aussi.
local function publier(joueur)
	local d = donnees[joueur]
	for cle, valeur in pairs(Catalogue.reglages(d.voiture, d.niveaux)) do
		joueur:SetAttribute("G_" .. cle, valeur)
	end
	joueur:SetAttribute("G_Couleur", Catalogue.couleur(d.voiture, d.couleur))
	joueur:SetAttribute("G_Voiture", d.voiture)
end

local function sauver(joueur)
	if not (chargeOk[joueur] and modifie[joueur]) then return end
	local ok = pcall(function()
		store:SetAsync(tostring(joueur.UserId), donnees[joueur])
	end)
	if ok then modifie[joueur] = nil end
end

local function ouvrir(joueur)
	local ok, valeur = pcall(function()
		return store:GetAsync(tostring(joueur.UserId))
	end)
	local d = parDefaut()
	if ok then
		chargeOk[joueur] = true
		if type(valeur) == "table" then
			-- on recopie champ par champ : une vieille sauvegarde incomplete
			-- ne casse rien
			d.voiture = Catalogue.voiture(valeur.voiture) and valeur.voiture or "Jesko"
			d.possede = type(valeur.possede) == "table" and valeur.possede or d.possede
			d.possede.Jesko = true
			d.niveaux = type(valeur.niveaux) == "table" and valeur.niveaux or {}
			d.couleur = Catalogue.COULEURS[valeur.couleur] and valeur.couleur or 1
		end
	else
		print("Garage : garde en memoire seulement (" .. tostring(valeur) .. ")")
	end
	donnees[joueur] = d
	publier(joueur)
end

Players.PlayerAdded:Connect(ouvrir)
for _, j in ipairs(Players:GetPlayers()) do task.spawn(ouvrir, j) end
Players.PlayerRemoving:Connect(function(joueur)
	sauver(joueur)
	donnees[joueur], chargeOk[joueur], modifie[joueur] = nil, nil, nil
end)
game:BindToClose(function()
	for _, j in ipairs(Players:GetPlayers()) do sauver(j) end
end)
task.spawn(function()
	while true do
		task.wait(SAUVE_TOUTES)
		for _, j in ipairs(Players:GetPlayers()) do sauver(j) end
	end
end)

-- =========================================================
-- 2. LES DEMANDES DE L ECRAN (et publier() donne les reglages de course)
-- Chaque demande renvoie : l etat du garage (pour reafficher), et un
-- message a montrer (vert si ca a marche, rouge sinon).
-- =========================================================
local function etat(joueur)
	local d = donnees[joueur]
	local v = pieces(joueur)
	return {
		voiture = d.voiture, possede = d.possede, niveaux = d.niveaux, couleur = d.couleur,
		pieces = v and v.Value or 0,
		illimite = illimite(joueur),
	}
end

-- Payer : vrai si c est fait. Le createur ne paie pas.
local function payer(joueur, prix)
	if illimite(joueur) then return true end
	local v = pieces(joueur)
	if not v or v.Value < prix then return false end
	v.Value -= prix
	return true
end

local actions = {}

function actions.acheter(joueur, d, nom)
	local v = Catalogue.voiture(nom)
	if not v then return false, "Cette voiture n'existe pas." end
	if d.possede[nom] then return false, "Tu l'as déjà !" end
	if not payer(joueur, v.prix) then return false, "Pas assez de pièces : il en faut " .. v.prix .. " 🪙" end
	d.possede[nom] = true
	d.voiture = nom
	return true, nom .. " est à toi ! Elle sera sur la grille à ta prochaine course."
end

function actions.choisir(joueur, d, nom)
	if not d.possede[nom] then return false, "Achète-la d'abord." end
	d.voiture = nom
	return true, "Tu cours maintenant en " .. nom .. "."
end

function actions.ameliorer(joueur, d, cle)
	local a = nil
	for _, x in ipairs(Catalogue.AMELIORATIONS) do
		if x.cle == cle then a = x end
	end
	if not a then return false, "Amélioration inconnue." end
	local niveau = d.niveaux[cle] or 0
	if niveau >= NB_NIVEAUX then return false, a.nom .. " : déjà au maximum !" end
	local prix = Catalogue.PRIX_NIVEAUX[niveau + 1]
	if not payer(joueur, prix) then return false, "Pas assez de pièces : il en faut " .. prix .. " 🪙" end
	d.niveaux[cle] = niveau + 1
	return true, a.nom .. " : niveau " .. (niveau + 1) .. " !"
end

function actions.couleur(joueur, d, index)
	local c = Catalogue.COULEURS[index]
	if not c then return false, "Couleur inconnue." end
	d.couleur = index
	return true, "Peinture : " .. c.nom
end

fonction.OnServerInvoke = function(joueur, action, valeur)
	local d = donnees[joueur]
	if not d then return nil, "Le garage se charge, réessaie dans un instant." end
	local f = actions[action]
	if not f then return etat(joueur) end              -- "etat" : juste lire
	local ok, message = f(joueur, d, valeur)
	if ok then
		modifie[joueur] = true
		publier(joueur)
		print("Garage : " .. joueur.Name .. " " .. action .. " " .. tostring(valeur))
	end
	return etat(joueur), message, ok
end

