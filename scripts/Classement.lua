-- =========================================================
--  LE CLASSEMENT DES MEILLEURS TEMPS
--  A placer dans ServerScriptService.
--
--  1. Quand un joueur finit ses 3 tours, CompteurTours note son
--     temps dans l attribut "DernierTemps" du joueur.
--  2. Ce script garde le MEILLEUR temps de chaque joueur dans un
--     OrderedDataStore : une base de donnees de Roblox, rangee
--     dans l ordre, qui survit a la fermeture du jeu.
--  3. Il ecrit le top 10 sur le tableau du spawn (pose par le
--     generateur scripts/ZoneSpawn.lua), a chaque nouveau temps
--     et toutes les 30 secondes.
--
--  ⚠️ En Studio, le DataStore ne marche que si on coche :
--  Game Settings > Security > Enable Studio Access to API Services.
--  Sinon, le classement garde les temps de la partie en cours
--  seulement (et le dit en bas du tableau).
-- =========================================================

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local NB_CLASSES = 10    -- le top 10
local RAFRAICHIR = 30    -- secondes entre deux mises a jour du tableau

-- Un OrderedDataStore ne range que des NOMBRES ENTIERS : on garde les
-- temps en millisecondes (83.456 s -> 83456).
local store = DataStoreService:GetOrderedDataStore("MeilleursTemps_v1")

local enMemoire = {}     -- [UserId] = meilleur temps en ms, pour la partie en cours
local noms = {}          -- [UserId] = pseudo, pour ne pas le redemander a chaque fois

-- 83.456 secondes -> "1:23.45" (comme le chrono)
local function enTexte(t)
	local minutes = math.floor(t / 60)
	return string.format("%d:%05.2f", minutes, t - minutes * 60)
end

local function nomDe(userId)
	if not noms[userId] then
		local ok, nom = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		noms[userId] = ok and nom or ("Joueur " .. userId)
	end
	return noms[userId]
end

-- ---- ENREGISTRER UN TEMPS ----
local function enregistrer(joueur, temps)
	local ms = math.floor(temps * 1000 + 0.5)
	noms[joueur.UserId] = joueur.Name
	if not enMemoire[joueur.UserId] or ms < enMemoire[joueur.UserId] then
		enMemoire[joueur.UserId] = ms
	end
	-- UpdateAsync : on lit l ancien record et on decide. On ne garde le
	-- nouveau temps que s il est MEILLEUR (plus petit). pcall : si la base
	-- de donnees ne repond pas, le jeu continue quand meme.
	local ok, erreur = pcall(function()
		store:UpdateAsync(tostring(joueur.UserId), function(ancien)
			if ancien == nil or ms < ancien then
				return ms
			end
			return nil        -- pas mieux : on ne change rien
		end)
	end)
	if not ok then
		warn("Classement : temps non sauvegarde (" .. tostring(erreur) .. ")")
	end
end

-- ---- LIRE LE TOP 10 ----
-- Renvoie la liste {id, ms}, et true si elle vient de la sauvegarde.
local function meilleurs()
	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, NB_CLASSES)   -- true = du plus petit au plus grand
	end)
	if ok then
		local liste = {}
		for _, e in ipairs(pages:GetCurrentPage()) do
			table.insert(liste, {id = tonumber(e.key), ms = e.value})
		end
		return liste, true
	end
	-- pas de sauvegarde : les temps de la partie en cours
	local liste = {}
	for id, ms in pairs(enMemoire) do
		table.insert(liste, {id = id, ms = ms})
	end
	table.sort(liste, function(a, b) return a.ms < b.ms end)
	while #liste > NB_CLASSES do table.remove(liste) end
	return liste, false
end

-- ---- ECRIRE SUR LE TABLEAU ----
-- On recherche le tableau a chaque fois : si on relance le generateur,
-- l ancien est detruit et un nouveau le remplace.
local function afficher()
	local zone = workspace:FindFirstChild("ZoneSpawn")
	local tableau = zone and zone:FindFirstChild("TableauClassement")
	local ecran = tableau and tableau:FindFirstChild("Ecran")
	if not ecran then return end

	local liste, sauvegarde = meilleurs()
	for n = 1, NB_CLASSES do
		local ligne = ecran.Lignes:FindFirstChild("Ligne" .. n)
		if ligne then
			local e = liste[n]
			ligne.Text = e and (n .. ".  " .. nomDe(e.id)) or (n .. ".  ---")
			ligne.Temps.Text = e and enTexte(e.ms / 1000) or ""
		end
	end
	if #liste == 0 then
		ecran.Pied.Text = "en attente du premier temps..."
	elseif sauvegarde then
		ecran.Pied.Text = "les meilleurs temps de tous les joueurs"
	else
		ecran.Pied.Text = "partie en cours seulement (sauvegarde desactivee)"
	end
end

-- ---- ECOUTER LES ARRIVEES ----
local function suivre(joueur)
	joueur:GetAttributeChangedSignal("DernierTemps"):Connect(function()
		local temps = joueur:GetAttribute("DernierTemps")
		if temps then
			enregistrer(joueur, temps)
			afficher()
		end
	end)
end
Players.PlayerAdded:Connect(suivre)
for _, joueur in ipairs(Players:GetPlayers()) do suivre(joueur) end

-- et toutes les RAFRAICHIR secondes (pour voir les temps faits sur les
-- AUTRES serveurs du jeu)
while true do
	afficher()
	task.wait(RAFRAICHIR)
end
