-- ============================================================
--  FEUX DE DEPART
--  A placer dans ServerScriptService (c est un Script, pas un
--  LocalScript : les feux doivent etre les memes pour tout le monde).
--
--  LE DEPART N EST PLUS AUTOMATIQUE. Il attend que quelqu un s asseye
--  dans une voiture :
--
--     je m assois  ->  5 secondes pour me preparer
--     puis  0 s : la ligne 1 (en haut) devient ROUGE
--           1 s : la ligne 2 devient rouge AUSSI (la 1 reste allumee)
--           2 s : la ligne 3 devient rouge AUSSI
--           3 s : tout passe au VERT  ->  DEPART
--
--  Les ampoules s appellent Ampoule1, Ampoule2 et Ampoule3 dans chaque
--  colonne : le numero, c est la LIGNE.
-- ============================================================

local TS = game:GetService("TweenService")

local circuit  = workspace:WaitForChild("Circuit")
local feux     = circuit:WaitForChild("FeuxDepart")
local ligneDepart = circuit:WaitForChild("LigneDepart")
local garage      = workspace:WaitForChild("Voitures")   -- le dossier des voitures

-- ---- L AFFICHAGE A L ECRAN ----
-- Ce script tourne sur le SERVEUR : il ne peut pas ecrire sur l ecran d un
-- joueur en particulier. Il envoie donc un message par ce RemoteEvent, et
-- le LocalScript StarterGui/EcranDepart/Affichage, qui tourne chez chaque
-- joueur, affiche le texte. On le cree s il manque, comme ca le jeu
-- fonctionne meme si quelqu un l a supprime par erreur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local afficher = ReplicatedStorage:FindFirstChild("CompteARebours")
if not afficher then
	afficher = Instance.new("RemoteEvent")
	afficher.Name = "CompteARebours"
	afficher.Parent = ReplicatedStorage
end

local ROUGE  = Color3.fromRGB(255, 40, 40)
local VERT   = Color3.fromRGB(60, 255, 110)
local ETEINT = Color3.fromRGB(58, 16, 16)

local NB_LIGNES = 3
local ATTENTE   = 5    -- secondes entre le moment ou je m assois et les feux
local DUREE     = 1    -- secondes entre deux lignes
local VERT_TENU = 3    -- combien de temps le vert reste allume (au moins aussi long que FONDU)

-- ---- LE SON ----
-- DEUX haut-parleurs sur la poutre, chacun son role :
--   Bip     = les 3 petits bips du rouge
--   BipLong = LE bip du depart, joue UNE SEULE FOIS, plus fort et plus long
--
-- Pourquoi deux ? Parce que PlaybackSpeed change la vitesse ET la hauteur :
-- pour rendre un bip long il faut le ralentir... et il devient grave.
-- La solution, c est PitchShiftSoundEffect : il remonte la hauteur SANS
-- toucher a la duree. Ces effets sont poses DANS BipLong, donc ils ne
-- deforment pas les petits bips.
local AIGU     = 1.3   -- hauteur des 3 petits bips (0.72 / 1.3 = 0.55 s)
local VOL_BIP  = 4     -- les 3 petits bips : volume moyen
local VOL_VERT = 10    -- le bip du depart : le maximum de Roblox
local FONDU    = 2.9   -- il s eteint doucement, sur toute sa duree

-- LE CALAGE SON / LUMIERE.
-- Une lumiere s allume instantanement ; un son, non : l ordre doit partir
-- du serveur, arriver au joueur, et le son met un instant a "attaquer".
-- On lance donc le son EN AVANCE, et la lumiere juste apres.
-- Le bip du depart demande plus d avance que les petits : comme il est
-- ralenti 4 fois, son debut est plus mou, donc on l entend plus tard.
local AVANCE      = 0.20   -- avance des 3 petits bips, en secondes
local AVANCE_VERT = 0.45   -- avance du bip du depart (les 2 PitchShift
                           -- ont besoin de temps avant de sortir du son)

local poutre  = feux:WaitForChild("Poutre")
local bip     = poutre:WaitForChild("Bip")
local bipLong = poutre:WaitForChild("BipLong")

-- On force le chargement des deux sons DES MAINTENANT. Sans ca, Roblox ne
-- les telecharge qu au tout premier Play : le bip arrive alors en retard
-- sur la lumiere, qui, elle, s allume instantanement.
game:GetService("ContentProvider"):PreloadAsync({bip, bipLong})

local function biper(vitesse, volume)
	bip.PlaybackSpeed = vitesse
	bip.Volume = volume
	bip:Play()
end

-- LE BIP DU DEPART. Un seul, parce que BipLong a Looped = false.
-- On remet son volume a fond a chaque depart : le fondu de la fois
-- precedente l avait laisse a zero.
local function bipDepart()
	bipLong:Stop()
	bipLong.Volume = VOL_VERT
	bipLong:Play()
	TS:Create(bipLong, TweenInfo.new(FONDU, Enum.EasingStyle.Linear), {Volume = 0}):Play()
end

-- ---- LES CAGES DE DEPART ----
-- Tant que le feu n est pas vert, chaque voiture est enfermee dans une cage
-- de 4 murs. On ne peut donc pas partir en avance.
--
-- La cage n est PAS calee sur le marquage au sol : un emplacement de grille
-- fait 9 studs de long, alors qu une voiture en fait 18. On demande donc ses
-- mesures a la voiture elle-meme, avec GetBoundingBox() : il renvoie la plus
-- petite boite qui la contient, et son orientation. La cage s adapte ainsi a
-- n importe quelle voiture, quelle que soit sa taille.
local MARGE  = 1.5   -- studs de jeu entre la voiture et ses murs
local EPAIS  = 1     -- epaisseur des murs
local RAYON  = 200   -- on ne cage que les voitures garees pres du depart
local TRANSP = 1     -- 1 = cages invisibles ; 0.6 = murs rouges translucides

local cages = circuit:WaitForChild("CagesDepart")

local function poserMur(parent, cf, taille)
	local p = Instance.new("Part")
	p.Size = taille
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.ForceField
	p.Color = Color3.fromRGB(255, 60, 60)
	p.Transparency = TRANSP
	p.CastShadow = false
	p.Parent = parent
end

local function fermerCages()
	cages:ClearAllChildren()

	-- Les voitures vivent dans le dossier Workspace.Voitures, pas a la racine
	-- du Workspace : c est la qu il faut aller les chercher.
	for _, m in ipairs(garage:GetChildren()) do
		if m:IsA("Model") and m:FindFirstChildWhichIsA("VehicleSeat", true) then
			local cf, taille = m:GetBoundingBox()

			-- On laisse tranquilles les voitures qui sont loin : si quelqu un
			-- fait son tour pendant qu un autre se met en grille, on ne va pas
			-- lui planter un mur devant le capot.
			if (cf.Position - ligneDepart.Position).Magnitude < RAYON then
				local cage = Instance.new("Model")
				cage.Name = m.Name
				cage.Parent = cages

				local demiL = taille.X / 2 + MARGE   -- demi-largeur
				local demiP = taille.Z / 2 + MARGE   -- demi-profondeur
				local haut  = taille.Y + 2

				-- devant et derriere (larges comme la voiture)
				poserMur(cage, cf * CFrame.new(0, 0, -demiP), Vector3.new(demiL * 2, haut, EPAIS))
				poserMur(cage, cf * CFrame.new(0, 0,  demiP), Vector3.new(demiL * 2, haut, EPAIS))
				-- les deux cotes (longs comme la voiture)
				poserMur(cage, cf * CFrame.new(-demiL, 0, 0), Vector3.new(EPAIS, haut, demiP * 2))
				poserMur(cage, cf * CFrame.new( demiL, 0, 0), Vector3.new(EPAIS, haut, demiP * 2))
			end
		end
	end
end

local function ouvrirCages()
	cages:ClearAllChildren()
end

-- Rend toutes les ampoules d une meme LIGNE, quelle que soit la colonne.
local function ligne(n)
	local t = {}
	for _, colonne in ipairs(feux:GetChildren()) do
		if colonne:IsA("Model") then
			local a = colonne:FindFirstChild("Ampoule" .. n)
			if a then table.insert(t, a) end
		end
	end
	return t
end

-- Une ampoule ETEINTE est en plastique sombre ; une ampoule ALLUMEE est
-- en Neon et sa lumiere est activee. Sans le Neon, une ampoule rouge vif
-- reste terne : c est la matiere qui fait l effet "allume".
local function peindre(ampoules, couleur, allumee)
	for _, a in ipairs(ampoules) do
		a.Color = couleur
		a.Material = allumee and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local lumiere = a:FindFirstChildOfClass("PointLight")
		if lumiere then
			lumiere.Color = couleur
			lumiere.Enabled = allumee
		end
	end
end

local function toutEteindre()
	for n = 1, NB_LIGNES do
		peindre(ligne(n), ETEINT, false)
	end
end

local function compteARebours()
	toutEteindre()

	-- On n eteint PAS la ligne precedente : elles s ajoutent.
	for n = 1, NB_LIGNES do
		biper(AIGU, VOL_BIP)
		task.wait(AVANCE)
		peindre(ligne(n), ROUGE, true)
		afficher:FireAllClients(tostring(NB_LIGNES - n + 1), ROUGE)   -- 3, puis 2, puis 1

		if n < NB_LIGNES then
			task.wait(DUREE - AVANCE)
		else
			-- DERNIERE LIGNE ROUGE. Le bip du depart doit partir en avance,
			-- mais sans decaler le rythme : on prend cette avance SUR la
			-- seconde qui reste, au lieu de l ajouter apres. Les lumieres
			-- restent donc espacees de DUREE seconde, du premier rouge au vert.
			task.wait(DUREE - AVANCE - AVANCE_VERT)
			bipDepart()
			task.wait(AVANCE_VERT)
		end
	end

	for n = 1, NB_LIGNES do
		peindre(ligne(n), VERT, true)
	end
	ouvrirCages()
	afficher:FireAllClients("GO", VERT)

	-- Le signal pour le script CompteurTours : a partir de maintenant, les
	-- passages sur la ligne comptent. Un attribut, c est une petite valeur
	-- accrochee a un objet, que tous les scripts du serveur peuvent lire.
	workspace:SetAttribute("CourseEnCours", true)
	print("DEPART !")          -- <<< c est ICI que le chrono demarrera

	task.wait(VERT_TENU)
	toutEteindre()
end

-- ============================================================
--  QUI DECLENCHE LE DEPART ?
--  Un VehicleSeat a une propriete "Occupant" : elle vaut nil quand le
--  siege est vide, et le Humanoid du pilote quand quelqu un est assis.
--  On ecoute donc le CHANGEMENT de cette propriete.
--
--  "enCours" evite qu un deuxieme joueur qui s assoit pendant le compte
--  a rebours ne le relance depuis le debut.
-- ============================================================
local enCours = false

local function surveillerSiege(siege)
	siege:GetPropertyChangedSignal("Occupant"):Connect(function()
		-- On ne relance RIEN tant que la course tourne : sinon un joueur qui
		-- s assoit en cours de route relancerait le compte a rebours et
		-- ferait reapparaitre les cages devant ceux qui roulent.
		if siege.Occupant and not enCours and not workspace:GetAttribute("CourseEnCours") then
			enCours = true
			fermerCages()
			print("Pilote installe - depart dans " .. ATTENTE .. " secondes")
			task.wait(ATTENTE)
			compteARebours()
			enCours = false
		end
	end)
end

-- les sieges deja la au lancement
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("VehicleSeat") then
		surveillerSiege(d)
	end
end

-- et ceux qui arriveront plus tard (quand on ajoutera le garage et les
-- ecuries, les voitures apparaitront en cours de partie)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("VehicleSeat") then
		surveillerSiege(d)
	end
end)

toutEteindre()
fermerCages()
workspace:SetAttribute("CourseEnCours", false)
