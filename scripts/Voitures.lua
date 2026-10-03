-- ============================================================
--  LES VOITURES
--  A placer dans ServerScriptService.
--
--  Il fait deux choses :
--    1. il pose les voitures sur la grille -- au demarrage du jeu, et de
--       nouveau apres chaque course ;
--    2. il surveille les sorties de piste : si on tombe du circuit, OU si
--       on roule hors de la route, le pilote meurt (il reapparait au
--       SpawnLocation) et sa voiture est detruite. Elle reviendra sur la
--       grille avec les autres a la fin de la course.
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
local JEU_NEZ     = 0.5    -- studs entre le nez de la voiture et le trait Avant

local TOLERANCE   = 1      -- secondes hors de la route avant d etre elimine
                           -- (une roue qui mord l herbe ne tue pas)
local EN_L_AIR    = 8      -- a plus de 8 studs du sol, on est en plein saut :
                           -- on ne juge pas ce qu il y a dessous

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

			-- Mais le pivot d une voiture, c est son SIEGE, et le pilote est
			-- assis a gauche : la carrosserie depassait de 1.2 stud d un cote.
			-- Et elle fait 18 studs pour une case de 9 : centree, elle
			-- depassait de 4.5 studs devant le trait Avant.
			-- On demande donc sa boite a la voiture de REFERENCE (comme pour
			-- les cages : en jeu, A-Chassis gonfle la boite d une voiture qui
			-- roule), et on la recale : centree entre les deux traits "Cote",
			-- le nez juste derriere le trait "Avant".
			local refBoite, taille = modele:GetBoundingBox()
			local ecart = modele:GetPivot():PointToObjectSpace(refBoite.Position)  -- la boite, vue depuis le siege
			local epaisseur = place.Avant.Size.Z                 -- le trait Avant lui-meme
			-- Dans la case, l avant est vers -Z et le trait Avant est a -LONGUEUR/2.
			local zVoulu = -LONGUEUR / 2 + epaisseur / 2 + JEU_NEZ + taille.Z / 2
			v:PivotTo(cf * CFrame.new(-ecart.X, 0, zVoulu - ecart.Z))
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

-- ---- EST-ON SUR LA ROUTE ? ----
-- Les dossiers et pieces du Circuit sur lesquels on a le droit de rouler.
-- Tout le reste (talus, montagne, eboulis, herbe, barrieres...) est
-- hors piste. On les reconnait par leur NOM : si on reconstruit le circuit
-- avec le generateur, ca marche toujours.
-- PilierTremplin depasse de 2 studs de chaque cote, juste sous le bord de
-- la rampe : verifie en tirant 15 000 rayons sur la route.
local PISTE = {
	Route = true, Damier = true, Grille = true, LigneDepart = true,
	Tremplin = true, MarqueTremplin = true, PilierTremplin = true,
}

local function estPiste(objet)
	if PISTE[objet.Name] then return true end
	-- sinon on remonte jusqu au dossier range directement dans Circuit
	local a = objet
	while a and a.Parent ~= circuit do
		a = a.Parent
	end
	return a ~= nil and PISTE[a.Name] == true
end

-- Le rayon part du siege et descend. Il traverse les voitures, les
-- personnages, les cages, et la fosse a piques (sinon, au-dessus de la
-- fosse, on croirait toucher le sol en plein saut).
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Exclude

-- Vrai si le siege est POSE sur autre chose que la route.
-- En l air (rien dessous, ou sol a plus de EN_L_AIR studs), on dit non :
-- c est l atterrissage qui decidera.
local function horsPiste(siege)
	local ignores = {dossier, circuit:FindFirstChild("Piques"), circuit:FindFirstChild("CagesDepart")}
	for _, j in ipairs(Players:GetPlayers()) do
		if j.Character then table.insert(ignores, j.Character) end
	end
	rayon.FilterDescendantsInstances = ignores

	local touche = workspace:Raycast(siege.Position, Vector3.new(0, -EN_L_AIR, 0), rayon)
	return touche ~= nil and not estPiste(touche.Instance)
end

-- ---- ELIMINER UN PILOTE ----
local function eliminer(joueur, humanoide, raison)
	-- SeatPart dit dans quel siege il est assis, ou nil s il est a pied.
	local siege = humanoide.SeatPart
	local voiture = siege and voitureDe(siege) or nil

	-- Health = 0 : Roblox le fait reapparaitre tout seul au SpawnLocation
	-- (apres Players.RespawnTime secondes).
	humanoide.Health = 0
	if voiture then
		voiture:Destroy()
		print(joueur.Name .. " " .. raison .. ", sa voiture est detruite")
	else
		print(joueur.Name .. " " .. raison)
	end
end

-- ---- LES SORTIES DE PISTE ----
-- horsDepuis[joueur] = l heure (os.clock) ou il a quitte la route.
local horsDepuis = {}
Players.PlayerRemoving:Connect(function(joueur)
	horsDepuis[joueur] = nil
end)

RunService.Heartbeat:Connect(function()
	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
		local torse = perso and perso:FindFirstChild("HumanoidRootPart")

		if humanoide and torse and humanoide.Health > 0 then
			local siege = humanoide.SeatPart
			local enVoiture = siege ~= nil and voitureDe(siege) ~= nil

			if torse.Position.Y < SEUIL then
				-- tombe du circuit, a pied ou en voiture
				horsDepuis[joueur] = nil
				eliminer(joueur, humanoide, "est tombe hors du circuit")

			elseif enVoiture and horsPiste(siege) then
				-- hors de la route : on lance le chrono la premiere fois...
				if not horsDepuis[joueur] then
					horsDepuis[joueur] = os.clock()
				-- ...et on elimine s il y est depuis plus de TOLERANCE secondes
				elseif os.clock() - horsDepuis[joueur] > TOLERANCE then
					horsDepuis[joueur] = nil
					eliminer(joueur, humanoide, "est sorti de la route")
				end

			else
				-- sur la route, en l air ou a pied : tout va bien
				horsDepuis[joueur] = nil
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

	-- AU FEU VERT (passage de faux a vrai) : les voitures ou personne n est
	-- assis disparaissent. Elles reviennent toutes avec placerVoitures a la
	-- fin de la course, pretes pour la suivante.
	if not courseAvant and maintenant then
		for _, v in ipairs(dossier:GetChildren()) do
			local siege = v:FindFirstChildWhichIsA("VehicleSeat", true)
			if siege and not siege.Occupant then
				v:Destroy()
			end
		end
	end

	if courseAvant and not maintenant then
		task.delay(DELAI_RESET, placerVoitures)
	end

	courseAvant = maintenant
end)

placerVoitures()
