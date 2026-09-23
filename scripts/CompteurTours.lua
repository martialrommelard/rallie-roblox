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

local circuit = workspace:WaitForChild("Circuit")
local ligne   = circuit:WaitForChild("LigneDepart")

local majTours = ReplicatedStorage:WaitForChild("MajTours")

-- Ce que l on retient pour chaque joueur.
local passages = {}   -- combien de fois il a franchi la ligne
local cote     = {}   -- de quel cote il etait a l image precedente
local fini     = {}

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
		for _, joueur in ipairs(Players:GetPlayers()) do
			reinitialiser(joueur)
			-- on affiche "TOUR 1 / 3" tout de suite, sinon le panneau reste
			-- vide jusqu au premier passage sur la ligne.
			majTours:FireClient(joueur, 1, NB_TOURS, false)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not workspace:GetAttribute("CourseEnCours") then return end

	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local torse = perso and perso:FindFirstChild("HumanoidRootPart")

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
					majTours:FireClient(joueur, NB_TOURS, NB_TOURS, true)
					print(joueur.Name .. " a termine ses " .. NB_TOURS .. " tours")

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
