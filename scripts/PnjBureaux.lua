-- =========================================================
--  LES PNJ DES BUREAUX  (cote SERVEUR)
--  A placer dans ServerScriptService.
--
--  Des employes de la direction de course, assis a leur bureau, qui
--  tapent sur leur clavier. Ils sont fabriques par CE script au lancement
--  du jeu (on ne les voit qu en Play).
--
--  Rien n est ecrit a la main :
--    - leurs chaises : une sur ECART_PNJ, prises dans l ordre des chaises
--      (les autres restent libres pour les joueurs) ;
--    - leur METIER : pris dans la liste METIERS, chacun son tour.
--
--  Un PNJ, c est un personnage comme le notre (un "rig" R15), mais sans
--  joueur. Son script "Animate" ne tourne pas (il n y a pas de joueur pour
--  le faire tourner) : on le met donc en position ASSISE nous-memes, en
--  pliant ses articulations (Motor6D). Le mouvement des mains qui tapent,
--  lui, est fait chez chaque joueur (LocalScript PnjBureaux).
-- =========================================================

local Players = game:GetService("Players")

local ECART_PNJ = 3          -- un PNJ sur une chaise sur 3
local DESCENTE  = 0.5        -- de combien on l enfonce dans la chaise (il flottait de 0,5)
local HAUT_BUREAU = 1.2      -- le dessus du bureau, au-dessus du centre de l assise (3,10 - 1,90)
local PEAUX = {
	Color3.fromRGB(255, 220, 180), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 94),
	Color3.fromRGB(141, 85, 54), Color3.fromRGB(96, 60, 40),
}
local CHEMISE  = Color3.fromRGB(20, 45, 95)     -- l uniforme bleu de la direction de course
local PANTALON = Color3.fromRGB(45, 45, 52)
local NEON     = Color3.fromRGB(0, 225, 255)

-- les metiers, donnes CHACUN SON TOUR (avant, on lisait l ecran du bureau,
-- et presque tout le monde avait le meme)
local METIERS = {
	"Adjoint du directeur", "Chronométreur", "Réalisatrice TV", "Commissaire de piste",
	"Météo", "Radio", "Mécanicien", "Caméraman", "Classement", "Sécurité tremplin",
	"Sécurité tunnel", "Médecin", "Journaliste", "Informaticienne", "Commentateur",
	"Photographe", "Assistante", "Stagiaire",
}

local zone = workspace:WaitForChild("ZoneSpawn")

local dossier = workspace:FindFirstChild("PnjBureaux") or Instance.new("Folder")
dossier.Name = "PnjBureaux"
dossier:ClearAllChildren()
dossier.Parent = workspace

-- ---- les chaises des bureaux ----
local chaises = {}
for _, x in ipairs(zone:GetChildren()) do
	if x.Name == "ChaiseBureau" and x:IsA("Seat") then table.insert(chaises, x) end
end
-- toujours le meme ordre (sinon ce ne seraient pas les memes chaises a chaque partie)
table.sort(chaises, function(a, b)
	if math.abs(a.Position.X - b.Position.X) > 0.5 then return a.Position.X < b.Position.X end
	return a.Position.Z < b.Position.Z
end)

-- plier une articulation (angles en degres). Les personnages Roblox recents
-- n ont plus de Motor6D : leurs articulations sont des AnimationConstraint,
-- qui relient deux Attachment. On tourne celui du cote du corps (Attachment0),
-- comme on tournerait le C0 d un Motor6D.
local function plier(perso, nomPiece, nomJoint, x, y, z)
	local piece = perso:FindFirstChild(nomPiece)
	local joint = piece and piece:FindFirstChild(nomJoint)
	local tourne = CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
	if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		joint.Attachment0.CFrame = joint.Attachment0.CFrame * tourne
	elseif joint and joint:IsA("Motor6D") then
		joint.C0 = joint.C0 * tourne
	end
end

-- ---- fabriquer un PNJ ----
local function pnj(chaise, numero)
	local desc = Instance.new("HumanoidDescription")
	local perso = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	local metier = METIERS[(numero - 1) % #METIERS + 1]
	perso.Name = "Pnj" .. numero
	perso.ModelStreamingMode = Enum.ModelStreamingMode.Atomic   -- tout le PNJ arrive d un coup chez le joueur

	-- les couleurs : peau, uniforme, pantalon
	local peau = PEAUX[(numero - 1) % #PEAUX + 1]
	local bodyColors = perso:FindFirstChildOfClass("BodyColors")
	if bodyColors then bodyColors:Destroy() end
	for _, p in ipairs(perso:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name:find("Torso") or p.Name:find("UpperArm") or p.Name:find("LowerArm") then
				p.Color = CHEMISE
			elseif p.Name:find("Leg") or p.Name:find("Foot") then
				p.Color = PANTALON
			else
				p.Color = peau   -- tete et mains
			end
			p.CanCollide = false
			p.Massless = true
		end
	end

	-- un casque radio : un arceau au-dessus de la tete et un petit micro neon
	local tete = perso.Head
	local function accessoire(nom, taille, decalage, couleur, matiere)
		local a = Instance.new("Part")
		a.Name = nom
		a.Size = taille
		a.Color = couleur
		a.Material = matiere or Enum.Material.SmoothPlastic
		a.CanCollide, a.CanQuery, a.CanTouch, a.Massless = false, false, false, true
		a.CFrame = tete.CFrame * decalage
		local soudure = Instance.new("WeldConstraint")
		soudure.Part0, soudure.Part1 = tete, a
		soudure.Parent = a
		a.Parent = perso
	end
	accessoire("Arceau", Vector3.new(1.35, 0.15, 0.25), CFrame.new(0, 0.62, 0), Color3.fromRGB(30, 30, 35))
	accessoire("Ecouteur", Vector3.new(0.2, 0.5, 0.5), CFrame.new(0.66, 0.1, 0), Color3.fromRGB(30, 30, 35))
	accessoire("Ecouteur", Vector3.new(0.2, 0.5, 0.5), CFrame.new(-0.66, 0.1, 0), Color3.fromRGB(30, 30, 35))
	accessoire("Micro", Vector3.new(0.1, 0.1, 0.6), CFrame.new(0.55, -0.25, -0.35) * CFrame.Angles(0, math.rad(30), 0),
		NEON, Enum.Material.Neon)

	-- son metier, au-dessus de la tete (visible de pres seulement)
	local hum = perso.Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local etiquette = Instance.new("BillboardGui")
	-- taille en STUDS (pas en pixels) : elle rapetisse quand on s eloigne,
	-- au lieu de prendre tout l ecran
	etiquette.Size = UDim2.new(3.2, 0, 0.5, 0)
	etiquette.StudsOffset = Vector3.new(0, 1.6, 0)
	etiquette.MaxDistance = 20
	etiquette.Adornee = tete
	etiquette.Parent = tete
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(10, 28, 55)
	t.BackgroundTransparency = 0.25
	t.TextColor3 = NEON
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Text = metier
	t.Parent = etiquette
	Instance.new("UICorner").Parent = t

	-- LA POSITION ASSISE : on plie les articulations
	--   hanches +90 (les cuisses vers l avant), genoux -90 (les mollets vers le bas)
	--   epaules +45 et coudes +65 : les mains au-dessus du clavier (a +45, les
	--   avant-bras rentraient dans le bord du bureau)
	plier(perso, "RightUpperLeg", "RightHip", 90)
	plier(perso, "LeftUpperLeg", "LeftHip", 90)
	plier(perso, "RightLowerLeg", "RightKnee", -90)
	plier(perso, "LeftLowerLeg", "LeftKnee", -90)
	plier(perso, "RightUpperArm", "RightShoulder", 45, 0, 8)
	plier(perso, "LeftUpperArm", "LeftShoulder", 45, 0, -8)
	plier(perso, "RightLowerArm", "RightElbow", 65)
	plier(perso, "LeftLowerArm", "LeftElbow", 65)
	perso:SetAttribute("Metier", metier)
	perso:SetAttribute("Phase", numero * 1.7)   -- pour que tout le monde ne tape pas en meme temps

	perso:PivotTo(chaise.CFrame * CFrame.new(0, 3, 0))
	perso.Parent = dossier
	chaise:Sit(hum)
	-- assis, il flottait de 0,5 stud (mesure) et ses genoux rentraient dans
	-- le bureau : on le descend en reglant la soudure qui le tient a la chaise
	local soudure = chaise:FindFirstChild("SeatWeld")
	-- (CFrame.new A GAUCHE : on descend dans le repere de la chaise. A droite,
	-- ca le faisait reculer dans le dossier, car la soudure est tournee.)
	if soudure then soudure.C0 = CFrame.new(0, -DESCENTE, 0) * soudure.C0 end

	-- un clavier sous ses mains, sur le bureau
	local clavier = Instance.new("Part")
	clavier.Name = "Clavier"
	clavier.Anchored, clavier.CanCollide, clavier.CanQuery = true, false, false
	clavier.Size = Vector3.new(2.6, 0.12, 0.9)
	clavier.CFrame = chaise.CFrame * CFrame.new(0, HAUT_BUREAU + 0.06, -1.9)
	clavier.Color = Color3.fromRGB(25, 25, 30)
	clavier.Material = Enum.Material.SmoothPlastic
	clavier.Parent = dossier
	return perso
end

local nb = 0
for i, chaise in ipairs(chaises) do
	if i % ECART_PNJ == 1 and not chaise.Occupant then
		nb += 1
		pnj(chaise, nb)
	end
end
print(string.format("PNJ des bureaux : %d employes sur %d chaises", nb, #chaises))

-- =========================================================
--  LE DIRECTEUR DE COURSE : debout au fond, devant le croquis du circuit,
--  il montre le TREMPLIN avec une baguette. Il a l AVATAR DU CREATEUR du
--  jeu (game.CreatorId : celui qui a cree la place).
-- =========================================================
local RunService = game:GetService("RunService")

local RECUL_DIRECTEUR  = 1.8   -- studs entre le tableau et lui
local COTE_DIRECTEUR   = 3     -- il se met a cote du point (pour ne pas le cacher)
local TOURNE_DIRECTEUR = 30    -- degres : face a la salle, mais un peu tourne vers le tableau
local ROUGE = Color3.fromRGB(230, 30, 40)

local tableau = zone:FindFirstChild("TableauCroquis")
-- le point a montrer : le trait du croquis le plus proche de l etiquette TREMPLIN
local etiquetteTremplin
for _, x in ipairs(zone:GetChildren()) do
	local l = x.Name == "TexteCroquis" and x:FindFirstChildWhichIsA("TextLabel", true)
	if l and l.Text == "TREMPLIN" then etiquetteTremplin = x end
end
local cible, dMin = nil, math.huge
if etiquetteTremplin then
	for _, x in ipairs(zone:GetChildren()) do
		if x.Name == "TraitCroquis" then
			local d = (x.Position - etiquetteTremplin.Position).Magnitude
			if d < dMin then cible, dMin = x, d end
		end
	end
end

local function directeur()
	if not (tableau and cible) then return end
	-- le cote "salle" du tableau : la ou sont les chaises
	local face = tableau.CFrame.RightVector
	if (chaises[1].Position - tableau.Position):Dot(face) < 0 then face = -face end
	local point = cible.Position + face * 0.1

	-- LE POINT ROUGE sur le croquis
	local rond = Instance.new("Part")
	rond.Name = "PointRouge"
	rond.Shape = Enum.PartType.Cylinder           -- un cylindre couche = un disque
	rond.Size = Vector3.new(0.1, 1, 1)
	rond.CFrame = CFrame.lookAt(point, point + face) * CFrame.Angles(0, math.rad(90), 0)
	rond.Anchored, rond.CanCollide, rond.CanQuery = true, false, false
	rond.Color = ROUGE
	rond.Material = Enum.Material.Neon
	rond.Parent = dossier

	-- SON AVATAR : celui du createur ; si Roblox ne repond pas, un avatar de base
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(game.CreatorId)
	end)
	if not ok then desc = Instance.new("HumanoidDescription") end
	local perso = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	local okNom, nom = pcall(function() return Players:GetNameFromUserIdAsync(game.CreatorId) end)
	perso.Name = "Directeur"
	perso.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	perso:SetAttribute("Debout", true)          -- le LocalScript ne le fait pas taper au clavier
	local hum = perso.Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- OU IL SE MET : a cote du point, DOS AU TABLEAU et face a la salle (on
	-- voit son visage), un peu tourne vers le tableau, comme un prof qui explique.
	-- Face a la salle, sa droite est "droite" : on le decale vers sa GAUCHE,
	-- pour que le point soit du cote de son bras droit, un peu derriere lui.
	local regard = face
	local droite = regard:Cross(Vector3.new(0, 1, 0))
	local sol = workspace:Raycast(point + face * RECUL_DIRECTEUR, Vector3.new(0, -30, 0))
	local ySol = sol and sol.Position.Y or (point.Y - 8)
	local racine = perso.HumanoidRootPart
	local pied = point + face * RECUL_DIRECTEUR - droite * COTE_DIRECTEUR
	pied = Vector3.new(pied.X, ySol + hum.HipHeight + racine.Size.Y / 2, pied.Z)
	perso:PivotTo(CFrame.lookAt(pied, pied + regard) * CFrame.Angles(0, math.rad(-TOURNE_DIRECTEUR), 0))
	racine.Anchored = true
	perso.Parent = dossier

	-- LES JAMBES : droites comme des piquets, ca ne fait pas naturel. On
	-- plie un peu les genoux, on ecarte les pieds, et la jambe GAUCHE est
	-- "au repos" : plus pliee, le pied un peu en avant et tourne vers
	-- l exterieur (le poids du corps est sur la droite).
	--   hanche + (cuisse vers l avant), genou - (mollet vers l arriere),
	--   cheville + (pour que le pied reste a plat)
	plier(perso, "RightUpperLeg", "RightHip", 8, 0, 5)
	plier(perso, "RightLowerLeg", "RightKnee", -16)
	plier(perso, "RightFoot", "RightAnkle", 8, 0, -5)
	plier(perso, "LeftUpperLeg", "LeftHip", 18, -15, -6)
	plier(perso, "LeftLowerLeg", "LeftKnee", -34)
	plier(perso, "LeftFoot", "LeftAnkle", 16, 0, 6)
	-- genoux plies = pieds plus hauts : on le redescend jusqu a ce que le
	-- pied le plus bas touche le sol (mesure, pas devine)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	local function dessous(pied)
		local m = math.huge
		for _, x in ipairs({-1, 1}) do
			for _, y in ipairs({-1, 1}) do
				for _, z in ipairs({-1, 1}) do
					m = math.min(m, (pied.CFrame * (pied.Size / 2 * Vector3.new(x, y, z))).Y)
				end
			end
		end
		return m
	end
	local descente = math.min(dessous(perso.LeftFoot), dessous(perso.RightFoot)) - ySol
	racine.CFrame = racine.CFrame - Vector3.new(0, descente, 0)
	RunService.Heartbeat:Wait()

	-- LE BRAS DROIT vers le point. On tourne l epaule de l angle entre "ou va
	-- le bras" (epaule -> main) et "ou est le point" (epaule -> point), et on
	-- recommence 4 fois : a chaque fois l ecart diminue (la 1re version
	-- laissait 25 degres entre le bras et la baguette).
	local torse = perso.UpperTorso
	local epaule = perso.RightUpperArm:FindFirstChild("RightShoulder")
	local a0 = epaule and epaule.Attachment0
	local function viserBras()
		local pivot = (torse.CFrame * a0.CFrame).Position
		local actuel = torse.CFrame:VectorToObjectSpace((perso.RightHand.Position - pivot).Unit)
		local voulu = torse.CFrame:VectorToObjectSpace((point - pivot).Unit)
		local axe = actuel:Cross(voulu)
		local angle = math.acos(math.clamp(actuel:Dot(voulu), -1, 1))
		if axe.Magnitude > 1e-4 then
			local rot = a0.CFrame - a0.CFrame.Position
			a0.CFrame = a0.CFrame * (rot:Inverse() * CFrame.fromAxisAngle(axe.Unit, angle) * rot)
		end
		return math.deg(angle)
	end
	local ecart = 0
	if a0 then
		for _ = 1, 4 do
			ecart = viserBras()
			RunService.Heartbeat:Wait()
		end
	end
	-- le bras gauche, detendu : un peu ecarte du corps, le coude a peine plie
	plier(perso, "LeftUpperArm", "LeftShoulder", 8, 0, -10)
	plier(perso, "LeftLowerArm", "LeftElbow", 20)

	-- son metier et son nom au-dessus de la tete
	local etiquette = Instance.new("BillboardGui")
	etiquette.Size = UDim2.new(4.5, 0, 0.6, 0)
	etiquette.StudsOffset = Vector3.new(0, 2, 0)
	etiquette.MaxDistance = 25
	etiquette.Adornee = perso.Head
	etiquette.Parent = perso.Head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(10, 28, 55)
	t.BackgroundTransparency = 0.25
	t.TextColor3 = Color3.fromRGB(255, 205, 60)       -- en or : c est le chef
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Text = "Directeur de course" .. (okNom and (" · " .. nom) or "")
	t.Parent = etiquette
	Instance.new("UICorner").Parent = t

	-- LA BAGUETTE : on attend que le bras ait bouge, puis on la tend de la
	-- MAIN jusqu au POINT (sa longueur est mesuree, pas choisie)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	local main = perso.RightHand
	local longueur = (point - main.Position).Magnitude
	local baguette = Instance.new("Part")
	baguette.Name = "Baguette"
	baguette.Size = Vector3.new(0.12, 0.12, longueur)
	baguette.CFrame = CFrame.lookAt((main.Position + point) / 2, point)
	baguette.CanCollide, baguette.CanQuery, baguette.Massless = false, false, true
	baguette.Color = Color3.fromRGB(120, 80, 45)
	baguette.Material = Enum.Material.Wood
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0, soudure.Part1 = main, baguette
	soudure.Parent = baguette
	baguette.Parent = perso
	perso:SetAttribute("Pret", true)              -- le LocalScript peut maintenant noter sa pose
	print(string.format("Directeur de course : %s, montre le tremplin (baguette de %.1f studs, bras vise a %.1f degres pres)",
		okNom and nom or "avatar de base", longueur, ecart))
end
directeur()
