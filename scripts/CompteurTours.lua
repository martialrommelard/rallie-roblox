-- ============================================================
--  LE COMPTEUR DE TOURS
--  A placer dans ServerScriptService (c est un Script, pas un LocalScript :
--  c est le serveur qui compte, sinon chacun pourrait s inventer des tours).
--
--  On NE se sert PAS de Touched. LigneDepart est traversable
--  (CanCollide = false), donc elle ne declencherait rien -- c est le meme
--  piege que pour les piques. On regarde la position a chaque image.
--
--  L ASTUCE : PointToObjectSpace donne la position du joueur DANS le repere
--  de la ligne. Le signe de son Z dit de quel cote de la ligne il se trouve.
--  Un tour est compte quand ce signe change dans le bon sens -- donc une
--  seule fois par passage, meme si on reste 10 images au-dessus de la ligne.
--
--  Et on suit LE JOUEUR, pas la voiture : comme on est assis dedans, le
--  personnage se deplace avec elle. Ca marche donc avec n importe quelle
--  voiture, et meme a pied.
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NB_TOURS = 3     -- la course s arrete apres 3 tours
local MARGE    = 10    -- studs de tolerance de chaque cote de la ligne
local RETOUR   = 3     -- secondes apres l arrivee avant le retour au spawn

local circuit = workspace:WaitForChild("Circuit")
local ligne   = circuit:WaitForChild("LigneDepart")

local majTours = ReplicatedStorage:WaitForChild("MajTours")

-- Le temps de chaque tour, envoye a l ecran du joueur. On le cree s il manque.
local tempsTour = ReplicatedStorage:FindFirstChild("TempsTour")
if not tempsTour then
	tempsTour = Instance.new("RemoteEvent")
	tempsTour.Name = "TempsTour"
	tempsTour.Parent = ReplicatedStorage
end

-- Ce que l on retient pour chaque joueur.
local passages = {}   -- combien de fois il a franchi la ligne
local cote     = {}   -- de quel cote il etait a l image precedente
local fini     = {}
local dernierPassage = {}  -- l heure de son dernier passage sur la ligne
local meilleurTour   = {}  -- son meilleur tour de la course
local arrivees = 0    -- combien de joueurs ont deja fini CETTE course (1er, 2eme...)

local function reinitialiser(joueur)
	passages[joueur] = 0
	cote[joueur] = nil
	fini[joueur] = false
	dernierPassage[joueur] = nil
	meilleurTour[joueur] = nil
end

-- Vrai quand plus personne n a de tour a faire. Si la liste est vide
-- (tout le monde a quitte), elle repond vrai aussi : la course est finie.
local function tousOntFini()
	for _, joueur in ipairs(Players:GetPlayers()) do
		if not fini[joueur] then return false end
	end
	return true
end

Players.PlayerAdded:Connect(reinitialiser)
Players.PlayerRemoving:Connect(function(joueur)
	passages[joueur], cote[joueur], fini[joueur] = nil, nil, nil

	-- task.defer attend la fin de l image en cours : le joueur qui part est
	-- encore dans la liste a cet instant precis.
	task.defer(function()
		if workspace:GetAttribute("CourseEnCours") and tousOntFini() then
			workspace:SetAttribute("CourseEnCours", false)
			print("Course terminee : il ne reste personne en piste")
		end
	end)
end)
for _, joueur in ipairs(Players:GetPlayers()) do
	reinitialiser(joueur)
end

-- FeuxDepart met cet attribut a true au feu vert. Tant qu il est faux, on
-- ne compte rien : sinon, se promener sur la ligne avant le depart
-- suffirait a gagner un tour.
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		arrivees = 0
		for _, joueur in ipairs(Players:GetPlayers()) do
			reinitialiser(joueur)

			-- Qui court ? Ceux qui sont assis dans une voiture AU FEU VERT.
			-- Les autres sont spectateurs : on les compte comme "finis",
			-- sinon la course attendrait quelqu un qui n a jamais pris le
			-- depart (et les voitures vides disparaissent au vert : il ne
			-- pourrait meme plus monter).
			local perso = joueur.Character
			local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
			local siege = humanoide and humanoide.SeatPart
			if siege and siege:IsA("VehicleSeat") then
				-- on affiche "TOUR 1 / 3" tout de suite, sinon le panneau reste
				-- vide jusqu au premier passage sur la ligne.
				majTours:FireClient(joueur, 1, NB_TOURS, false)
			else
				fini[joueur] = true
				print(joueur.Name .. " est spectateur")
			end
		end

		-- Plus personne en voiture au vert ? (descendu pendant les feux)
		-- task.defer : on ne change pas l attribut au milieu de son propre
		-- signal, on attend la fin de l image.
		task.defer(function()
			if workspace:GetAttribute("CourseEnCours") and tousOntFini() then
				workspace:SetAttribute("CourseEnCours", false)
				print("Course terminee : personne n a pris le depart")
			end
		end)
	end
end)

-- ---- LE CHRONO ----
-- FeuxDepart a note l heure du feu vert dans l attribut HeureDepart.
local function tempsDeCourse()
	local depart = workspace:GetAttribute("HeureDepart")
	return depart and (workspace:GetServerTimeNow() - depart) or 0
end

-- 83.456 secondes  ->  "1:23.45"
local function enTexte(t)
	local minutes = math.floor(t / 60)
	local secondes = t - minutes * 60
	return string.format("%d:%05.2f", minutes, secondes)
end

-- ---- LE TABLEAU DE LA DERNIERE COURSE (dans le spawn) ----
-- Le classement de la course, mis a jour EN DIRECT : a chaque arrivee et
-- a chaque elimination. Les arrives dans l ordre (or, argent, bronze pour
-- les 3 premiers), puis les elimines en rouge. L ecran "TableauCourse" et
-- ses lignes vides sont poses par le generateur scripts/ZoneSpawn.lua.
local resultats = {}     -- les arrives : {nom, temps}, dans l ordre
local elimines  = {}     -- les elimines : {nom, tours faits}
local COULEURS_PODIUM = {Color3.fromRGB(255, 205, 60), Color3.fromRGB(215, 220, 230), Color3.fromRGB(215, 140, 80)}
local BLANC_TABLEAU   = Color3.fromRGB(235, 240, 250)
local ROUGE_TABLEAU   = Color3.fromRGB(255, 80, 80)

local function afficherResultats()
	local zone = workspace:FindFirstChild("ZoneSpawn")
	local tableau = zone and zone:FindFirstChild("TableauCourse")
	local ecran = tableau and tableau:FindFirstChild("Ecran")
	if not ecran then return end

	-- on remplit les lignes une par une : d abord les arrives, puis les elimines
	local lignes = {}
	for rang, r in ipairs(resultats) do
		table.insert(lignes, {
			texte = ((rang == 1) and "1er" or (rang .. "ème")) .. "  " .. r.nom,
			temps = enTexte(r.temps),
			couleur = COULEURS_PODIUM[rang] or BLANC_TABLEAU,
		})
	end
	for _, e in ipairs(elimines) do
		table.insert(lignes, {
			texte = "ÉLIMINÉ  " .. e.nom,
			temps = e.tours .. " / " .. NB_TOURS .. " tours",
			couleur = ROUGE_TABLEAU,
		})
	end
	local n = 1
	while ecran.Lignes:FindFirstChild("Ligne" .. n) do
		local ligne = ecran.Lignes["Ligne" .. n]
		local l = lignes[n]
		ligne.Text = l and l.texte or ""
		ligne.TextColor3 = l and l.couleur or BLANC_TABLEAU
		ligne.Temps.Text = l and l.temps or ""
		n += 1
	end
	if workspace:GetAttribute("CourseEnCours") then
		ecran.Pied.Text = "course en cours..."
	elseif #lignes == 0 then
		ecran.Pied.Text = "en attente de la fin d'une course..."
	else
		ecran.Pied.Text = #resultats .. " à l'arrivée, " .. #elimines .. " éliminé(s)"
	end
end

-- une nouvelle course : on efface le classement de la precedente ; la
-- course finie : on met a jour le bas du tableau
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		resultats, elimines = {}, {}
	end
	afficherResultats()
end)

-- ---- LE RETOUR AU SPAWN, APRES L ARRIVEE ----
-- Le joueur qui a fini revient au spawn, et sa voiture disparait : elle
-- reviendra sur la grille avec les autres, quand TOUTE la course sera
-- finie (c est le script Voitures qui s en charge).
-- L ordre compte : on fait d abord DESCENDRE le pilote (on detruit la
-- soudure "SeatWeld" qui le tient au siege), on le pose au spawn, et
-- seulement ensuite on detruit la voiture. Detruire une voiture avec
-- quelqu un dedans fait planter l interface d A-Chassis (des centaines
-- d erreurs "DriveSeat is not a valid member" dans l Output).
local function renvoyerAuSpawn(joueur)
	local perso = joueur.Character
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then return end

	-- la voiture : on remonte du siege jusqu au modele range dans Voitures
	local voiture = humanoide.SeatPart
	local dossier = workspace:FindFirstChild("Voitures")
	while voiture and voiture.Parent and voiture.Parent ~= dossier do
		voiture = voiture.Parent
	end

	if humanoide.SeatPart then
		local soudure = humanoide.SeatPart:FindFirstChild("SeatWeld")
		if soudure then soudure:Destroy() end
	end
	task.wait(0.3)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		perso:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
	task.wait(0.5)
	if voiture and voiture.Parent == dossier then
		voiture:Destroy()
	end
	print(joueur.Name .. " est revenu au spawn")
end

RunService.Heartbeat:Connect(function()
	if not workspace:GetAttribute("CourseEnCours") then return end

	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local torse = perso and perso:FindFirstChild("HumanoidRootPart")
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")

		-- MORT PENDANT LA COURSE (sortie de route, chute, piques...) :
		-- il est elimine. On le compte comme "fini", sinon la course
		-- l attendrait pour toujours et les voitures ne reviendraient jamais.
		if humanoide and humanoide.Health <= 0 and not fini[joueur] then
			fini[joueur] = true
			local temps = tempsDeCourse()
			majTours:FireClient(joueur, passages[joueur], NB_TOURS, "elimine", temps)
			print(joueur.Name .. " est elimine apres " .. enTexte(temps))
			-- les tours COMPLETS : le 1er passage sur la ligne ne fait que lancer le tour 1
			table.insert(elimines, {nom = joueur.Name, tours = math.max(0, passages[joueur] - 1)})
			afficherResultats()

			if tousOntFini() then
				workspace:SetAttribute("CourseEnCours", false)
				print("Course terminee : il ne reste personne en piste")
			end
		end

		-- CHASSEUR (la tomate volante de l epicerie) : il est sorti de sa
		-- voiture pour voler. Sa course a lui s arrete, comme un elimine :
		-- sinon il gagnerait en volant tout droit jusqu a la ligne.
		if joueur:GetAttribute("Chasseur") and not fini[joueur] then
			fini[joueur] = true
			local temps = tempsDeCourse()
			majTours:FireClient(joueur, passages[joueur] or 0, NB_TOURS, "elimine", temps)
			print(joueur.Name .. " devient chasseur (tomate volante)")
			table.insert(elimines, {nom = "🍅 " .. joueur.Name, tours = math.max(0, (passages[joueur] or 0) - 1)})
			afficherResultats()
			if tousOntFini() then
				workspace:SetAttribute("CourseEnCours", false)
				print("Course terminee : il ne reste personne en piste")
			end
		end

		if torse and not fini[joueur] then
			-- La position du joueur, vue depuis la ligne.
			local p = ligne.CFrame:PointToObjectSpace(torse.Position)

			-- Est-il bien EN FACE de la ligne, et pas 50 studs a cote ?
			local dansLaLargeur = math.abs(p.X) < ligne.Size.X / 2 + MARGE
			local cotePresent = (p.Z > 0) and 1 or -1

			-- Il etait derriere (1), il est devant (-1) : il vient de franchir.
			if cote[joueur] == 1 and cotePresent == -1 and dansLaLargeur then
				passages[joueur] += 1

				-- LE TEMPS DU TOUR : de son passage precedent a celui-ci. Au
				-- 1er passage (juste apres le depart de la grille), il n y a
				-- pas encore de tour complet : on note seulement l heure.
				local maintenant = workspace:GetServerTimeNow()
				if dernierPassage[joueur] then
					local t = maintenant - dernierPassage[joueur]
					local record = (meilleurTour[joueur] == nil) or (t < meilleurTour[joueur])
					if record then meilleurTour[joueur] = t end
					tempsTour:FireClient(joueur, t, meilleurTour[joueur], record)
				end
				dernierPassage[joueur] = maintenant

				if passages[joueur] > NB_TOURS then
					fini[joueur] = true
					-- C est le SERVEUR qui donne le temps final : l ecran du
					-- joueur ne fait qu afficher, il ne decide de rien.
					local temps = tempsDeCourse()
					arrivees += 1                       -- sa place : 1er, 2eme...
					majTours:FireClient(joueur, NB_TOURS, NB_TOURS, true, temps, arrivees)
					-- pour le script Classement : il ecoute cet attribut
					joueur:SetAttribute("DernierTemps", temps)
					print(joueur.Name .. " a termine ses " .. NB_TOURS .. " tours en " .. enTexte(temps))
					table.insert(resultats, {nom = joueur.Name, temps = temps})
					afficherResultats()
					task.delay(RETOUR, renvoyerAuSpawn, joueur)

					if tousOntFini() then
						workspace:SetAttribute("CourseEnCours", false)
						print("Course terminee pour tout le monde")
					end
				else
					majTours:FireClient(joueur, passages[joueur], NB_TOURS, false)
					print(joueur.Name .. " entame le tour " .. passages[joueur])
				end
			end

			cote[joueur] = cotePresent
		end
	end
end)
