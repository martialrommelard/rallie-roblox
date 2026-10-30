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
--  4. Les DEGATS restent sur chaque voiture du joueur d une course a
--     l autre (le script Degats nous previent a chaque choc).
--  5. Les POSTES DE REPARATION : le pont eleve la voiture, les machines la
--     reparent piece par piece. On paie selon les degats.
--
--  Le garage lui-meme (sous le spawn) est pose par le generateur
--  scripts/Garage.lua ; les prix et les voitures sont dans
--  ReplicatedStorage.GarageCatalogue.
-- ============================================================

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local ServerStorage          = game:GetService("ServerStorage")
local DataStoreService       = game:GetService("DataStoreService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService             = game:GetService("RunService")

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
	-- degats[nomVoiture] = {etat = 0..100, perdues = {"Aileron", ...}}
	return {voiture = "Jesko", possede = {Jesko = true}, niveaux = {}, couleur = 1, degats = {}}
end

-- les degats d une voiture (neuve si on n en sait rien)
local function degatsDe(d, nom)
	local x = d.degats[nom]
	if type(x) ~= "table" then return {etat = 100, perdues = {}, usure = ""} end
	return {etat = tonumber(x.etat) or 100, perdues = type(x.perdues) == "table" and x.perdues or {},
		usure = type(x.usure) == "string" and x.usure or ""}     -- usure : "Capot=40;Aileron=85" (morceau=PV)
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
	local x = degatsDe(d, d.voiture)
	joueur:SetAttribute("G_Etat", x.etat)
	joueur:SetAttribute("G_Perdues", table.concat(x.perdues, ","))
	joueur:SetAttribute("G_Usure", x.usure)
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
			d.degats = type(valeur.degats) == "table" and valeur.degats or {}
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
	local x = degatsDe(d, d.voiture)
	return {
		voiture = d.voiture, possede = d.possede, niveaux = d.niveaux, couleur = d.couleur,
		pieces = v and v.Value or 0,
		illimite = illimite(joueur),
		etatVoiture = x.etat, perdues = x.perdues,
		prixReparation = Catalogue.prixReparation(x.etat, x.perdues),
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

-- =========================================================
-- 3. LES DEGATS (le script Degats nous previent a chaque choc)
-- =========================================================
local signal = ServerStorage:FindFirstChild("DegatsVoiture")
if not signal then
	signal = Instance.new("BindableEvent")
	signal.Name = "DegatsVoiture"
	signal.Parent = ServerStorage
end
signal.Event:Connect(function(joueur, modele, etatVoiture, perdues, usure)
	local d = donnees[joueur]
	if not (d and Catalogue.voiture(modele)) then return end
	d.degats[modele] = {
		etat = math.floor(etatVoiture * 10 + 0.5) / 10,
		perdues = (perdues ~= "") and string.split(perdues, ",") or {},
		usure = usure or "",
	}
	modifie[joueur] = true
	publier(joueur)
end)

-- =========================================================
-- 4. LES POSTES DE REPARATION
-- Le generateur Garage.lua a pose 4 postes ("PosteReparation") le long
-- du mur rond. Chacun a : un Socle (ou se pose la voiture), des Bras
-- (le pont qui monte), un Ecran, des Etincelles, un Gyrophare, et le
-- bouton "Reparer ma voiture" (PromptReparer).
-- =========================================================
local HAUSSE      = 4      -- le pont monte la voiture de 4 studs
local T_PONT      = 1.5    -- secondes pour monter (et pour descendre)
local T_BASE      = 3      -- la reparation dure 3 s...
local T_PAR_POINT = 0.05   -- ...+ 0.05 s par % abime...
local T_PAR_PIECE = 1.5    -- ...+ 1.5 s par piece a remettre

local info = ReplicatedStorage:WaitForChild("InfoCourse")
local VERT  = Color3.fromRGB(90, 230, 120)
local JAUNE = Color3.fromRGB(255, 205, 60)
local ROUGE = Color3.fromRGB(255, 80, 80)

local enReparation = {}    -- [joueur] = vrai pendant qu une de ses voitures est sur un pont

-- Une copie FIGEE de la voiture (comme la vitrine) : sans scripts, ancree,
-- on ne peut ni s y asseoir ni la pousser.
local function voitureFigee()
	local v = ServerStorage:WaitForChild("VoitureModele"):Clone()
	for _, x in ipairs(v:GetDescendants()) do
		if x:IsA("LuaSourceContainer") or x:IsA("RemoteEvent") or x:IsA("Sound") or x:IsA("Constraint") then
			x:Destroy()
		elseif x:IsA("VehicleSeat") or x:IsA("Seat") then
			x.Disabled = true
		end
	end
	for _, x in ipairs(v:GetDescendants()) do
		if x:IsA("BasePart") then
			x.Anchored = true
			x.CanCollide, x.CanTouch, x.CanQuery = false, false, false
		end
	end
	return v
end

local function ecrire(poste, texte, couleur)
	local ecran = poste:FindFirstChild("Ecran")
	local l = ecran and ecran:FindFirstChild("Texte", true)
	if l then
		l.Text = texte
		l.TextColor3 = couleur or Color3.new(1, 1, 1)
	end
end

local function machines(poste, allumees)
	for _, x in ipairs(poste:GetDescendants()) do
		if x:IsA("ParticleEmitter") or x:IsA("PointLight") then x.Enabled = allumees end
	end
	local g = poste:FindFirstChild("Gyrophare")
	if g then g.Material = allumees and Enum.Material.Neon or Enum.Material.SmoothPlastic end
end

-- Le pont : on deplace la voiture ET les bras de "h" studs vers le haut
-- (h va de 0 a HAUSSE), a partir de leur position de depart.
local function pont(poste, voiture, departVoiture, departBras, h1, h2)
	local debut = os.clock()
	repeat
		local t = math.min(1, (os.clock() - debut) / T_PONT)
		local h = h1 + (h2 - h1) * (1 - math.cos(t * math.pi)) / 2     -- doux au depart et a l arrivee
		voiture:PivotTo(departVoiture + Vector3.new(0, h, 0))
		for bras, cf in pairs(departBras) do
			bras.CFrame = cf + Vector3.new(0, h, 0)
		end
		RunService.Heartbeat:Wait()
	until t >= 1
end

local function reparer(poste, joueur)
	local d = donnees[joueur]
	if not d then return end
	if poste:GetAttribute("Occupe") then
		info:FireClient(joueur, "Ce poste est occupé, prends-en un autre !", JAUNE, 2.5)
		return
	end
	if enReparation[joueur] then
		info:FireClient(joueur, "Ta voiture est déjà sur un pont !", JAUNE, 2.5)
		return
	end
	if joueur:GetAttribute("EnCourse") then return end
	local nom = d.voiture
	local x = degatsDe(d, nom)
	if x.etat >= 100 and #x.perdues == 0 then
		info:FireClient(joueur, "Ta " .. nom .. " est en parfait état ✅", VERT, 2.5)
		return
	end

	-- LE PRIX. Pas assez de pieces ? Le garagiste prend ce que tu as : on
	-- ne doit jamais rester bloque avec une voiture cassee.
	local prix = Catalogue.prixReparation(x.etat, x.perdues)
	local v = pieces(joueur)
	if not illimite(joueur) and v then
		prix = math.min(prix, v.Value)
		v.Value -= prix
	end

	poste:SetAttribute("Occupe", joueur.Name)
	enReparation[joueur] = true
	print("Garage : " .. joueur.Name .. " repare sa " .. nom .. " (" .. math.floor(x.etat) .. " %, " .. #x.perdues .. " pieces) pour " .. prix .. " pieces")
	info:FireClient(joueur, "🔧 Réparation de ta " .. nom .. " : " .. (illimite(joueur) and "gratuit" or (prix .. " 🪙")), VERT, 3)

	-- 1. la voiture arrive sur le socle, a SA couleur, SANS ses pieces perdues
	local socle = poste.Socle
	local voiture = voitureFigee()
	voiture.Name = "VoitureEnReparation"
	Catalogue.peindre(voiture, Catalogue.couleur(nom, d.couleur))
	local manquantes = Catalogue.partiesDe(voiture, x.perdues)
	local transparence = {}
	for _, p in ipairs(manquantes) do
		transparence[p] = p.Transparency
		p.Transparency = 1
	end
	-- les morceaux uses sont noircis (comme en course) : ils redeviennent
	-- propres pendant la reparation
	local noircis = {}
	for _, u in ipairs(string.split(x.usure, ";")) do
		local nomMorceau, pv = string.match(u, "^(.+)=(%d+)$")
		if nomMorceau then
			for _, partie in ipairs(Catalogue.partiesDe(voiture, {nomMorceau})) do
				local propre = partie.Color
				local sale = propre:Lerp(Color3.fromRGB(30, 28, 26), (1 - tonumber(pv) / 100) * 0.6)
				partie.Color = sale
				noircis[partie] = {sale, propre}
			end
		end
	end
	voiture.Parent = poste
	-- posee sur le socle, le nez vers le mur (meme calcul que la vitrine)
	local boite, taille = voiture:GetBoundingBox()
	local decalage = voiture:GetPivot():ToObjectSpace(boite)
	local dessus = socle.CFrame * CFrame.new(0, socle.Size.Y / 2, 0)
	local departVoiture = dessus * CFrame.new(0, taille.Y / 2, 0) * decalage:Inverse()
	voiture:PivotTo(departVoiture)
	local departBras = {}
	for _, b in ipairs(poste:GetChildren()) do
		if b.Name == "Bras" then departBras[b] = b.CFrame end
	end

	-- 2. le pont monte
	ecrire(poste, "⬆ " .. joueur.DisplayName, JAUNE)
	pont(poste, voiture, departVoiture, departBras, 0, HAUSSE)

	-- 3. les machines travaillent : l etat remonte, les pieces reviennent
	--    une par une (avec un petit eclair)
	machines(poste, true)
	local duree = T_BASE + (100 - x.etat) * T_PAR_POINT + #x.perdues * T_PAR_PIECE
	local piecesARemettre = {}
	for _, n in ipairs(x.perdues) do table.insert(piecesARemettre, n) end
	local debut = os.clock()
	local remises = 0
	while true do
		local t = math.min(1, (os.clock() - debut) / duree)
		local etat = x.etat + (100 - x.etat) * t
		ecrire(poste, string.format("🔧 RÉPARATION %d %%\n%s", math.floor(etat), joueur.DisplayName), JAUNE)
		for partie, c in pairs(noircis) do
			partie.Color = c[1]:Lerp(c[2], t)
		end
		-- la piece numero k revient quand on a fait k / (n+1) du travail
		local doivent = math.floor(t * (#piecesARemettre + 1))
		while remises < math.min(doivent, #piecesARemettre) do
			remises += 1
			local nomPiece = piecesARemettre[remises]
			for _, p in ipairs(Catalogue.partiesDe(voiture, {nomPiece})) do
				p.Transparency = transparence[p] or 0
				local eclair = Instance.new("Highlight")
				eclair.FillColor = Color3.fromRGB(255, 230, 120)
				eclair.FillTransparency = 0.2
				eclair.OutlineTransparency = 1
				eclair.Adornee = p
				eclair.Parent = p
				game:GetService("Debris"):AddItem(eclair, 0.4)
			end
			info:FireClient(joueur, "🔩 " .. nomPiece .. " remis(e) en place", VERT, 1.5)
		end
		if t >= 1 then break end
		task.wait(0.1)
	end
	machines(poste, false)

	-- 4. c est fini : le pont redescend, la voiture est neuve
	d.degats[nom] = {etat = 100, perdues = {}, usure = ""}
	modifie[joueur] = true
	if joueur.Parent then publier(joueur) end
	ecrire(poste, "✅ PRÊTE !\n" .. joueur.DisplayName, VERT)
	pont(poste, voiture, departVoiture, departBras, HAUSSE, 0)
	info:FireClient(joueur, "✅ Ta " .. nom .. " est comme neuve !", VERT, 3)
	task.wait(3)
	voiture:Destroy()
	ecrire(poste, "LIBRE\nAppuie sur E pour réparer", Color3.new(1, 1, 1))
	poste:SetAttribute("Occupe", nil)
	enReparation[joueur] = nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, joueur)
	if prompt.Name ~= "PromptReparer" then return end
	local poste = prompt:FindFirstAncestor("PosteReparation")
	if poste then task.spawn(reparer, poste, joueur) end
end)

Players.PlayerRemoving:Connect(function(joueur)
	enReparation[joueur] = nil
end)
