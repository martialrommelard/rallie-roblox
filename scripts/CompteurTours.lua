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

-- Ce que l on retient pour chaque joueur.
local passages = {}   -- combien de fois il a franchi la ligne
local cote     = {}   -- de quel cote il etait a l image precedente
local fini     = {}
local arrivees = 0    -- combien de joueurs ont deja fini CETTE course (1er, 2eme...)

local function reinitialiser(joueur)
	passages[joueur] = 0
	cote[joueur] = nil
	fini[joueur] = false
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
