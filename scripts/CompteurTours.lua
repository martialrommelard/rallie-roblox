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

-- LES CHECKPOINTS : les morceaux de route (leur numero) qu il faut
-- traverser DANS L ORDRE pour qu un tour compte. Un tous les ~550 studs
-- (le tour en fait 3152), hors du tunnel (morceaux 100 a 113) et du
-- tremplin (141 a 146) : mesure dans Studio le 2026-10-30.
local CHECKPOINTS = {30, 60, 90, 125, 165}
local CP_COTE     = 15    -- studs de tolerance au bord de la route
local CP_HAUT     = 30    -- on compte jusqu a 30 studs au-dessus (sauts)

-- L ABANDON et LE TEMPS LIMITE : plus personne ne peut bloquer la course.
local ABANDON_A_PIED = 8     -- secondes hors de sa voiture : abandon automatique
local TEMPS_MAX      = 600   -- 10 minutes apres le depart, la course s arrete
local APRES_PREMIER  = 90    -- secondes laissees aux autres apres le 1er

local VERT  = Color3.fromRGB(90, 230, 120)
local ROUGE = Color3.fromRGB(255, 80, 80)
local JAUNE = Color3.fromRGB(255, 205, 60)

local circuit = workspace:WaitForChild("Circuit")
local ligne   = circuit:WaitForChild("LigneDepart")

-- On DEMANDE les checkpoints a la route : rien n est ecrit en dur.
local route  = circuit:WaitForChild("Route")
local portes = {}
for i, numero in ipairs(CHECKPOINTS) do
	portes[i] = route:WaitForChild("Route" .. numero)
end

-- LES PORTIQUES : construits au lancement, sur chaque morceau-checkpoint.
-- Deux piliers hors de la route, une banderole, et un rideau transparent
-- que l ecran de chaque pilote colore (Course.client) : JAUNE = le
-- prochain, VERT = deja passe. Rien ne bloque : on les traverse, et les
-- rayons de Voitures (sortie de route) ne les voient pas (CanQuery).
local function piece(nom, taille, cf, couleur, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Parent = parent
	return p
end

local dossierPortiques = circuit:FindFirstChild("Checkpoints")
if dossierPortiques then dossierPortiques:Destroy() end
dossierPortiques = Instance.new("Folder")
dossierPortiques.Name = "Checkpoints"
local HAUTEUR_PORTIQUE = 22
for i, morceau in ipairs(portes) do
	local w = morceau.Size.X
	-- le dessus de la route, au milieu du morceau
	local sol = morceau.CFrame * CFrame.new(0, morceau.Size.Y / 2, 0)
	local portique = Instance.new("Model")
	portique.Name = "Checkpoint" .. i
	for _, cote in ipairs({-1, 1}) do
		piece("Pilier", Vector3.new(2.5, HAUTEUR_PORTIQUE, 2.5),
			sol * CFrame.new(cote * (w / 2 + 3), HAUTEUR_PORTIQUE / 2, 0), Color3.fromRGB(40, 40, 48), portique)
	end
	local banderole = piece("Banderole", Vector3.new(w + 9, 4, 1),
		sol * CFrame.new(0, HAUTEUR_PORTIQUE, 0), Color3.fromRGB(25, 25, 30), portique)
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.PixelsPerStud = 25
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud   -- sinon Roblox ignore PixelsPerStud (cadre fixe 800x600 etire : lettres ecrasees)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = "CHECKPOINT " .. i .. " / " .. #portes
		t.Parent = g
		g.Parent = banderole
	end
	local rideau = piece("Rideau", Vector3.new(w + 4, HAUTEUR_PORTIQUE - 2, 0.2),
		sol * CFrame.new(0, (HAUTEUR_PORTIQUE - 2) / 2, 0), Color3.fromRGB(120, 200, 255), portique)
	rideau.Material = Enum.Material.Neon
	rideau.Transparency = 0.85
	portique.Parent = dossierPortiques
end
dossierPortiques.Parent = circuit

local majTours = ReplicatedStorage:WaitForChild("MajTours")

-- Le temps de chaque tour, envoye a l ecran du joueur. On le cree s il manque.
local tempsTour = ReplicatedStorage:FindFirstChild("TempsTour")
if not tempsTour then
	tempsTour = Instance.new("RemoteEvent")
	tempsTour.Name = "TempsTour"
	tempsTour.Parent = ReplicatedStorage
end

-- Les petits messages de course (checkpoint, coupe, abandon...), et le
-- bouton ABANDONNER de l ecran (LocalScript Course.client).
local function remote(nom)
	local r = ReplicatedStorage:FindFirstChild(nom)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = nom
		r.Parent = ReplicatedStorage
	end
	return r
end
local info       = remote("InfoCourse")
local evtAbandon = remote("Abandonner")

-- Ce que l on retient pour chaque joueur.
local passages = {}   -- combien de fois il a franchi la ligne
local cote     = {}   -- de quel cote il etait a l image precedente
local fini     = {}
local dernierPassage = {}  -- l heure de son dernier passage sur la ligne
local meilleurTour   = {}  -- son meilleur tour de la course
local arrivees = 0    -- combien de joueurs ont deja fini CETTE course (1er, 2eme...)
local cp        = {}  -- combien de checkpoints il a passes dans CE tour
local aPied     = {}  -- l heure ou il est descendu de sa voiture
local saVoiture = {}  -- son siege au feu vert (pour enlever sa voiture s il abandonne)
local tempsPremier = nil   -- le temps du 1er a l arrivee

local function reinitialiser(joueur)
	passages[joueur] = 0
	cote[joueur] = nil
	fini[joueur] = false
	dernierPassage[joueur] = nil
	meilleurTour[joueur] = nil
	cp[joueur] = 0
	aPied[joueur] = nil
	saVoiture[joueur] = nil
	-- lus par l ecran (Course.client) pour colorer les portiques
	joueur:SetAttribute("Checkpoint", 0)
	joueur:SetAttribute("EnCourse", false)
end

-- Vrai quand plus personne n a de tour a faire. Si la liste est vide
-- (tout le monde a quitte), elle repond vrai aussi : la course est finie.
local function tousOntFini()
	for _, joueur in ipairs(Players:GetPlayers()) do
		if not fini[joueur] then return false end
	end
	return true
end

-- Un joueur qui arrive PENDANT une course est spectateur : sans ca, la
-- course l attendait (bug trouve en preparant le test a plusieurs).
Players.PlayerAdded:Connect(function(joueur)
	reinitialiser(joueur)
	if workspace:GetAttribute("CourseEnCours") then
		fini[joueur] = true
	end
end)
Players.PlayerRemoving:Connect(function(joueur)
	passages[joueur], cote[joueur], fini[joueur] = nil, nil, nil
	cp[joueur], aPied[joueur], saVoiture[joueur] = nil, nil, nil

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
		tempsPremier = nil
		workspace:SetAttribute("FinCourse", nil)
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
				saVoiture[joueur] = siege
				joueur:SetAttribute("EnCourse", true)
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
			texte = (e.mot or "ÉLIMINÉ") .. "  " .. e.nom,
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
	else
		-- course finie : plus personne n est "en course" (les portiques
		-- reprennent leur couleur normale chez tout le monde)
		for _, joueur in ipairs(Players:GetPlayers()) do
			joueur:SetAttribute("EnCourse", false)
		end
		workspace:SetAttribute("FinCourse", nil)
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

	-- la voiture : on remonte du siege jusqu au modele range dans Voitures.
	-- Descendu (abandon) ? On prend le siege qu il avait au feu vert.
	local voiture = humanoide.SeatPart or saVoiture[joueur]
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

-- ---- SORTIR DE LA COURSE ----
-- Elimine, chasseur, abandon ou hors delai : dans tous les cas il est
-- compte comme "fini" (sinon la course l attendrait pour toujours), son
-- ecran affiche ELIMINE, et il va dans la liste rouge du tableau avec un
-- mot devant son nom ("ÉLIMINÉ", "ABANDON"...).
local function sortir(joueur, mot, raison)
	if fini[joueur] ~= false then return end
	fini[joueur] = true
	joueur:SetAttribute("EnCourse", false)
	local temps = tempsDeCourse()
	majTours:FireClient(joueur, passages[joueur], NB_TOURS, "elimine", temps)
	print(joueur.Name .. " " .. raison .. " apres " .. enTexte(temps))
	-- les tours COMPLETS : le 1er passage sur la ligne ne fait que lancer le tour 1
	table.insert(elimines, {mot = mot, nom = joueur.Name, tours = math.max(0, passages[joueur] - 1)})
	afficherResultats()

	if tousOntFini() then
		workspace:SetAttribute("CourseEnCours", false)
		print("Course terminee : il ne reste personne en piste")
	end
end

-- ABANDONNER : il sort de la course et revient au spawn ; sa voiture
-- disparait (elle reviendra sur la grille a la fin, avec les autres).
local function abandonner(joueur, raison)
	sortir(joueur, "ABANDON", raison)
	task.delay(1, renvoyerAuSpawn, joueur)
end

-- Le bouton ABANDONNER de l ecran. Le serveur verifie qu il est bien en
-- course : un spectateur qui clique ne fait rien.
evtAbandon.OnServerEvent:Connect(function(joueur)
	if workspace:GetAttribute("CourseEnCours") and fini[joueur] == false then
		abandonner(joueur, "abandonne (bouton)")
	end
end)

-- ---- LES CHECKPOINTS ----
-- Est-il DANS ce morceau de route ? Meme astuce que pour la ligne : sa
-- position vue depuis le morceau. Dans la largeur (X), dans la longueur
-- (Z), et pas trop haut (Y).
local function dansCheckpoint(morceau, position)
	local p = morceau.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) < morceau.Size.X / 2 + CP_COTE
		and math.abs(p.Z) < morceau.Size.Z / 2 + 4
		and p.Y > -5 and p.Y < CP_HAUT
end

RunService.Heartbeat:Connect(function()
	if not workspace:GetAttribute("CourseEnCours") then return end
	local ecoule = tempsDeCourse()

	-- ---- LE TEMPS LIMITE ----
	-- TEMPS_MAX apres le depart, ou APRES_PREMIER secondes apres l arrivee
	-- du 1er : ceux qui roulent encore sont HORS DELAI.
	local limite = TEMPS_MAX
	if tempsPremier then
		limite = math.min(limite, tempsPremier + APRES_PREMIER)
	end
	if ecoule > limite then
		for _, joueur in ipairs(Players:GetPlayers()) do
			if fini[joueur] == false then
				sortir(joueur, "HORS DÉLAI", "est hors delai")
				task.delay(1, renvoyerAuSpawn, joueur)
			end
		end
		return
	end

	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local torse = perso and perso:FindFirstChild("HumanoidRootPart")
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")

		if fini[joueur] == false and humanoide then
			local siege = humanoide.SeatPart
			if humanoide.Health <= 0 then
				-- MORT PENDANT LA COURSE (sortie de route, chute, piques...)
				sortir(joueur, "ÉLIMINÉ", "est elimine")

			elseif joueur:GetAttribute("Chasseur") then
				-- CHASSEUR (la tomate volante de l epicerie) : il est sorti de
				-- sa voiture pour voler. Sa course a lui s arrete, sinon il
				-- gagnerait en volant tout droit jusqu a la ligne.
				sortir(joueur, "🍅 CHASSEUR", "devient chasseur (tomate volante)")

			elseif not (siege and siege:IsA("VehicleSeat")) then
				-- DESCENDU DE SA VOITURE : avant, il bloquait toute la course.
				-- Il a ABANDON_A_PIED secondes pour remonter.
				if not aPied[joueur] then
					aPied[joueur] = ecoule
					info:FireClient(joueur, "Remonte dans ta voiture ! Abandon dans " .. ABANDON_A_PIED .. " s", JAUNE, 3)
				elseif ecoule - aPied[joueur] > ABANDON_A_PIED then
					abandonner(joueur, "est descendu de sa voiture")
				end
			else
				aPied[joueur] = nil
			end
		end

		if torse and fini[joueur] == false then
			-- LE PROCHAIN CHECKPOINT : on ne regarde QUE celui-la, donc on les
			-- passe forcement dans l ordre. Pas avant le 1er passage de la
			-- ligne : on est encore sur la grille.
			local prochain = portes[cp[joueur] + 1]
			if passages[joueur] >= 1 and prochain and dansCheckpoint(prochain, torse.Position) then
				cp[joueur] += 1
				joueur:SetAttribute("Checkpoint", cp[joueur])
				info:FireClient(joueur, "CHECKPOINT " .. cp[joueur] .. " / " .. #portes, VERT, 1.5)
			end

			-- La position du joueur, vue depuis la ligne.
			local p = ligne.CFrame:PointToObjectSpace(torse.Position)

			-- Est-il bien EN FACE de la ligne, et pas 50 studs a cote ?
			local dansLaLargeur = math.abs(p.X) < ligne.Size.X / 2 + MARGE
			local cotePresent = (p.Z > 0) and 1 or -1

			-- Il etait derriere (1), il est devant (-1) : il vient de franchir.
			if cote[joueur] == 1 and cotePresent == -1 and dansLaLargeur then
				if passages[joueur] >= 1 and cp[joueur] < #portes then
					-- IL A COUPE : il lui manque un checkpoint, le tour ne
					-- compte pas. Il devra refaire un tour en passant par la.
					info:FireClient(joueur, "CHECKPOINT " .. (cp[joueur] + 1) .. " MANQUÉ !  Tour non compté", ROUGE, 3)
					print(joueur.Name .. " a coupe : checkpoint " .. (cp[joueur] + 1) .. " manque")
				else
					passages[joueur] += 1
					cp[joueur] = 0
					joueur:SetAttribute("Checkpoint", 0)

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
						joueur:SetAttribute("EnCourse", false)
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

						-- le 1er est arrive : les autres ont APRES_PREMIER secondes.
						-- L heure de fin va dans un attribut : les ecrans l affichent.
						if arrivees == 1 then
							tempsPremier = temps
							workspace:SetAttribute("FinCourse", workspace:GetAttribute("HeureDepart") + math.min(TEMPS_MAX, temps + APRES_PREMIER))
						end

						if tousOntFini() then
							workspace:SetAttribute("CourseEnCours", false)
							print("Course terminee pour tout le monde")
						end
					else
						majTours:FireClient(joueur, passages[joueur], NB_TOURS, false)
						print(joueur.Name .. " entame le tour " .. passages[joueur])
					end
				end
			end

			cote[joueur] = cotePresent
		end
	end
end)
