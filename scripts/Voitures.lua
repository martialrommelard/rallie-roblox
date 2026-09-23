-- ============================================================
--  LES VOITURES
--  A placer dans ServerScriptService.
--
--  Il fait deux choses :
--    1. il pose les voitures sur la grille -- au demarrage du jeu, et de
--       nouveau apres chaque course ;
--    2. il surveille les chutes : si on sort du circuit, le pilote meurt
--       et sa voiture est detruite.
--
--  Rien n est ecrit en dur : le nombre de voitures est celui des
--  emplacements de la grille, et chaque position est DEMANDEE au trait
--  "Avant" de son emplacement.
-- ============================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local SEUIL       = -60    -- sous ce Y, on est tombe hors du circuit
                           -- (le point le plus bas du decor est a -27.8)
local DELAI_RESET = 5      -- secondes apres la course avant de tout remettre
local HAUTEUR     = 1.63   -- le DriveSeat est a 1.63 stud au-dessus des roues
local GARDE       = 0.4    -- on pose la voiture juste au-dessus du sol
local LONGUEUR    = 9      -- la longueur d un emplacement (les traits "Cote")
local RETOURNER   = false  -- true si les voitures se posent a l envers

local circuit = workspace:WaitForChild("Circuit")
local grille  = circuit:WaitForChild("Grille")
local modele  = ServerStorage:WaitForChild("VoitureModele")

local dossier = workspace:FindFirstChild("Voitures")
if not dossier then
	dossier = Instance.new("Folder")
	dossier.Name = "Voitures"
	dossier.Parent = workspace
end

-- ---- OU POSER UNE VOITURE ----
-- On ne devine aucune coordonnee : le trait "Avant" de l emplacement donne
-- sa position ET sa direction. La voiture se recule ensuite d une demi-
-- longueur pour se centrer dans sa case.
local function placeDe(place)
	local avant = place:FindFirstChild("Avant")
	if not avant then return nil end

	local sens = avant.CFrame.LookVector
	local centre = avant.Position - sens * (LONGUEUR / 2)
	local solY = avant.Position.Y - avant.Size.Y / 2

	local pos = Vector3.new(centre.X, solY + HAUTEUR + GARDE, centre.Z)
	if RETOURNER then sens = -sens end

	-- CFrame.lookAt : "sois a cet endroit, et regarde par la".
	return CFrame.lookAt(pos, pos + sens)
end

local function placerVoitures()
	dossier:ClearAllChildren()

	local n = 0
	for _, place in ipairs(grille:GetChildren()) do
		local cf = placeDe(place)
		if cf then
			n += 1
			local v = modele:Clone()
			v.Name = "Voiture" .. n
			v.Parent = dossier
			-- PivotTo deplace tout le modele d un bloc, en gardant ses pieces
			-- assemblees. On le fait APRES l avoir mis dans le Workspace.
			v:PivotTo(cf)
		end
	end
	-- Les cages d avant entouraient des voitures qui viennent d etre
	-- detruites : elles resteraient plantees en piste. FeuxDepart en
	-- refabriquera des que quelqu un s assoira.
	local cages = circuit:FindFirstChild("CagesDepart")
	if cages then
		cages:ClearAllChildren()
	end

	print(n .. " voitures posees sur la grille")
end

-- ---- RETROUVER LA VOITURE D UN OBJET ----
-- On part du siege et on remonte de parent en parent jusqu a tomber sur le
-- modele qui est range directement dans le dossier Voitures.
local function voitureDe(objet)
	local a = objet
	while a and a.Parent and a.Parent ~= dossier do
		a = a.Parent
	end
	if a and a.Parent == dossier then return a end
	return nil
end

-- ---- LES CHUTES ----
RunService.Heartbeat:Connect(function()
	-- les joueurs tombes
	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
		local torse = perso and perso:FindFirstChild("HumanoidRootPart")

		if humanoide and torse and humanoide.Health > 0 and torse.Position.Y < SEUIL then
			-- SeatPart dit dans quel siege il est assis, ou nil s il est a pied.
			local siege = humanoide.SeatPart
			local voiture = siege and voitureDe(siege) or nil

			humanoide.Health = 0
			if voiture then
				voiture:Destroy()
				print(joueur.Name .. " est tombe hors du circuit, sa voiture est detruite")
			else
				print(joueur.Name .. " est tombe hors du circuit")
			end
		end
	end

	-- les voitures vides tombees toutes seules
	for _, v in ipairs(dossier:GetChildren()) do
		if v:IsA("Model") and v:GetPivot().Position.Y < SEUIL then
			v:Destroy()
		end
	end
end)

-- ---- LE RETOUR EN GRILLE ----
-- CourseEnCours passe a false quand la course se termine. On attend un peu
-- (le temps de savourer l arrivee), puis on remet tout en place.
--
-- ATTENTION : il ne suffit pas de tester "l attribut vaut false". Au
-- demarrage du jeu, FeuxDepart le met a false, et on aurait rase les
-- voitures 5 secondes apres le lancement -- sous le pilote deja assis.
-- On ne reagit donc qu au PASSAGE de vrai a faux.
local courseAvant = false

workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	local maintenant = workspace:GetAttribute("CourseEnCours") == true

	if courseAvant and not maintenant then
		task.delay(DELAI_RESET, placerVoitures)
	end

	courseAvant = maintenant
end)

placerVoitures()
