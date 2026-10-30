-- ============================================================
--  LES DEGATS DE NOTRE VOITURE DE RALLY
--  A placer dans ServerScriptService.
--
--  LA VOITURE EST SOLIDE : elle n est jamais detruite, elle roule
--  toujours. Ce sont ses MORCEAUX qui s abiment (capot, portieres, ailes,
--  phares, aileron, pare-chocs... et les 4 roues) : chaque piece de la
--  voiture porte l attribut "Morceau" (pose par le generateur
--  VoitureRally.lua), et chaque morceau a ses POINTS DE VIE (PV), de 100
--  a 0 :
--    - c est LE MORCEAU TOUCHE qui s abime : la piece qui touche un mur,
--      le decor, une autre voiture ou un morceau tombe. MEME UN FROTTEMENT
--      compte (le long d une barriere, ca use vite) ;
--    - il NOIRCIT petit a petit ;
--    - a 0, il SE DETACHE (on casse sa soudure), tombe... et RESTE sur
--      la piste jusqu a la course suivante : un obstacle qui abime les
--      voitures qui le percutent ;
--    - une ROUE detachee : le coin de la voiture tombe et FROTTE par
--      terre (le chassis) : elle avance difficilement.
--  Si la piece touchee n est pas un morceau (la caisse, le toit...), on
--  abime le morceau le plus proche du point touche.
--
--  L ETAT de la voiture (attribut "Etat", la barre de Course.client) =
--  la moyenne des PV de ses morceaux. Il sert au prix de la reparation.
--  Les degats RESTENT d une course a l autre : on previent GarageServeur
--  (BindableEvent "DegatsVoiture"), et on repare au garage.
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ---- LES REGLAGES ----
local PV_COUP      = 6     -- PV perdus a chaque contact...
local PV_VITESSE   = 0.35  -- ...plus 0.35 PV par stud/s (un coup a 60 studs/s = 27 PV)
local PAUSE        = 0.3   -- un meme morceau ne s abime qu une fois toutes les 0.3 s
                           -- (un frottement continu = ~3 coups par seconde)
local ROUE_SOLIDE  = 3     -- une roue est 3 fois plus solide
local ROUTE_SEUIL  = 15    -- la route n abime que si on la tape a plus de 15 studs/s vers le bas
local PRES         = 4     -- piece touchee sans morceau : le morceau le plus proche, a moins de 4 studs
local PROTEGE      = 1.5   -- secondes apres le depart : on ne compte rien
local NOIRCI       = 0.6   -- a 0 PV, la couleur est a 60 % vers le noir
local SUIE   = Color3.fromRGB(30, 28, 26)
local ORANGE = Color3.fromRGB(255, 150, 60)

local dossier = workspace:WaitForChild("Voitures")
local circuit = workspace:WaitForChild("Circuit")
local info = ReplicatedStorage:WaitForChild("InfoCourse")

-- pour prevenir le garage (cree par GarageServeur, ou ici s il manque)
local signal = ServerStorage:FindFirstChild("DegatsVoiture")
if not signal then
	signal = Instance.new("BindableEvent")
	signal.Name = "DegatsVoiture"
	signal.Parent = ServerStorage
end

-- les morceaux tombes restent la jusqu au depart de la course suivante
local tombes = workspace:FindFirstChild("PiecesTombees")
if not tombes then
	tombes = Instance.new("Folder")
	tombes.Name = "PiecesTombees"
	tombes.Parent = workspace
end

-- La piste : la toucher n abime pas (sauf un coup violent vers le bas)
local PISTE = {
	Route = true, Damier = true, Grille = true, LigneDepart = true,
	Tremplin = true, MarqueTremplin = true, PilierTremplin = true,
	CagesDepart = true, Checkpoints = true,
}
local function estPiste(objet)
	if objet:IsA("Terrain") or objet.Name == "Baseplate" then return true end
	if not objet:IsDescendantOf(circuit) then return false end
	local a = objet
	while a.Parent ~= circuit do a = a.Parent end
	return PISTE[a.Name] == true
end
local function estPersonnage(objet)
	local m = objet:FindFirstAncestorOfClass("Model")
	return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
end

-- ---- CE QU ON SAIT DE CHAQUE VOITURE ----
-- morceaux[voiture] = { [nom] = {nom, pv, parties = {...}, couleurs = {...}, roue, moteur, dernier} }
local morceaux = {}
local depart = {}      -- [voiture] = l heure ou la course a commence pour elle

local function voitureDe(objet)
	local a = objet
	while a and a.Parent and a.Parent ~= dossier do a = a.Parent end
	if a and a.Parent == dossier then return a end
	return nil
end

local function piloteDe(voiture)
	local siege = voiture:FindFirstChild("DriveSeat")
	local hum = siege and siege.Occupant
	return hum and Players:GetPlayerFromCharacter(hum.Parent), siege
end

local function morceauxDe(voiture)
	if morceaux[voiture] then return morceaux[voiture] end
	local liste = {}
	-- l usure de la course d avant (posee par DepartCourse) : "Capot=40;Aileron=85"
	local usure = {}
	for _, x in ipairs(string.split(voiture:GetAttribute("Usure") or "", ";")) do
		local nom, pv = string.match(x, "^(.+)=(%d+)$")
		if nom then usure[nom] = tonumber(pv) end
	end
	for _, p in ipairs(voiture:GetDescendants()) do
		local nom = p:IsA("BasePart") and p:GetAttribute("Morceau")
		if nom then
			local m = liste[nom]
			if not m then
				m = {nom = nom, pv = usure[nom] or 100, parties = {}, couleurs = {}}
				liste[nom] = m
			end
			table.insert(m.parties, p)
			m.couleurs[p] = p.Color
			-- une roue : son moteur (la charniere qui la tient)
			if p:FindFirstChild("Moteur") then m.roue, m.moteur = p, p.Moteur end
		end
	end
	morceaux[voiture] = liste
	return liste
end

-- L ETAT de la voiture : la moyenne des PV de tous ses morceaux (ceux
-- tombes comptent pour 0)
local function calculerEtat(voiture)
	local total, n = 0, 0
	for _, m in pairs(morceauxDe(voiture)) do
		total += m.pv
		n += 1
	end
	local perdues = voiture:GetAttribute("Perdues") or ""
	if perdues ~= "" then n += #string.split(perdues, ",") end
	return (n > 0) and (total / n) or 100
end

-- Ce qu on envoie au garage : l usure et les morceaux perdus
local function usureTexte(voiture)
	local t = {}
	for nom, m in pairs(morceauxDe(voiture)) do
		if m.pv < 100 then table.insert(t, nom .. "=" .. math.floor(m.pv)) end
	end
	return table.concat(t, ";")
end

-- ---- UN MORCEAU SE DETACHE (et reste sur la piste) ----
local function detacher(voiture, m)
	local chassis = voiture:FindFirstChild("Chassis")
	local centre = chassis and chassis.Position or m.parties[1].Position
	local vitesse = chassis and chassis.AssemblyLinearVelocity or Vector3.zero
	-- une roue : on enleve la charniere qui la tient a sa fusee
	if m.moteur then m.moteur:Destroy() end
	for _, partie in ipairs(m.parties) do
		-- on casse sa soudure au chassis (pas celle de la jante a sa roue)
		for _, w in ipairs(partie:GetChildren()) do
			if w:IsA("WeldConstraint") and (w.Part0 == chassis or w.Part1 == chassis) then w:Destroy() end
		end
		for _, nc in ipairs(partie:GetChildren()) do
			if nc:IsA("NoCollisionConstraint") then nc:Destroy() end
		end
		partie.Massless = false
		partie:SetAttribute("DeVoiture", voiture.Name)
		partie:SetAttribute("TombeA", os.clock())
	end
	for _, partie in ipairs(m.parties) do
		partie.Parent = tombes
	end
	-- il part vers l exterieur, en tournant
	for _, partie in ipairs(m.parties) do
		if partie.AssemblyRootPart == partie then
			local dehors = ((partie.Position - centre) * Vector3.new(1, 0, 1)).Unit + Vector3.new(0, 0.7, 0)
			partie.AssemblyLinearVelocity = vitesse * 0.7 + dehors * 18
			partie.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			pcall(function() partie:SetNetworkOwner(nil) end)
		end
	end
	morceauxDe(voiture)[m.nom] = nil
	local perdues = voiture:GetAttribute("Perdues") or ""
	voiture:SetAttribute("Perdues", (perdues == "") and m.nom or (perdues .. "," .. m.nom))
end

-- ---- ABIMER UN MORCEAU ----
local function abimer(voiture, m, pv, raison)
	if os.clock() - (m.dernier or 0) < PAUSE then return end   -- (un frottement : pas a chaque image)
	m.dernier = os.clock()
	pv = pv / (voiture:GetAttribute("Solidite") or 1) / (m.roue and ROUE_SOLIDE or 1)
	m.pv = math.max(0, m.pv - pv)
	-- il noircit petit a petit
	local t = (1 - m.pv / 100) * NOIRCI
	for _, partie in ipairs(m.parties) do
		if m.couleurs[partie] then partie.Color = m.couleurs[partie]:Lerp(SUIE, t) end
	end
	local arrache = m.pv <= 0
	if arrache then detacher(voiture, m) end

	voiture:SetAttribute("Etat", calculerEtat(voiture))
	local joueur = piloteDe(voiture)
	if joueur then
		if arrache then
			info:FireClient(joueur, "💥 " .. m.nom .. " arraché(e) !", ORANGE, 2)
		end
		-- le garage garde l etat de SA voiture d une course a l autre
		signal:Fire(joueur, voiture:GetAttribute("Modele"), voiture:GetAttribute("Etat"),
			voiture:GetAttribute("Perdues") or "", usureTexte(voiture))
		print(string.format("Degats : %s %s : %s -%.0f PV (reste %.0f)%s", joueur.Name, raison, m.nom, pv, m.pv,
			arrache and " ARRACHE" or ""))
	end
end

-- Le point le plus proche de "p" sur la boite d une piece
local function pointProche(piece, p)
	local l = piece.CFrame:PointToObjectSpace(p)
	local d = piece.Size / 2
	return piece.CFrame * Vector3.new(math.clamp(l.X, -d.X, d.X), math.clamp(l.Y, -d.Y, d.Y), math.clamp(l.Z, -d.Z, d.Z))
end

-- Le morceau d une piece : le sien, sinon le plus proche du point touche
local function morceauDe(voiture, partie, point)
	local nom = partie:GetAttribute("Morceau")
	local liste = morceauxDe(voiture)
	if nom then return liste[nom] end
	local meilleur, dMin = nil, PRES
	for _, m in pairs(liste) do
		for _, p in ipairs(m.parties) do
			local d = (pointProche(p, point) - point).Magnitude
			if d < dMin then meilleur, dMin = m, d end
		end
	end
	return meilleur
end

-- ---- LE CONTACT ----
local function surContact(voiture, partie, autre)
	if partie.Parent == tombes then return end                  -- deja tombee
	if not workspace:GetAttribute("CourseEnCours") then return end
	if voitureDe(autre) == voiture or estPersonnage(autre) then return end
	-- un morceau qui vient de tomber de CETTE voiture : pas tout de suite
	if autre:GetAttribute("DeVoiture") == voiture.Name and os.clock() - (autre:GetAttribute("TombeA") or 0) < 1.5 then return end
	if not (depart[voiture] and os.clock() - depart[voiture] > PROTEGE) then return end
	local _, siege = piloteDe(voiture)
	local chassis = voiture:FindFirstChild("Chassis")
	if not chassis then return end
	local vitesse = (chassis.AssemblyLinearVelocity - autre.AssemblyLinearVelocity).Magnitude

	if estPiste(autre) then
		-- LA ROUTE : seulement un coup violent vers le bas (une reception
		-- de saut qui tape le pare-chocs). Les roues roulent dessus : rien.
		local bas = -chassis.AssemblyLinearVelocity.Y
		if bas > ROUTE_SEUIL and partie:GetAttribute("Morceau") and not partie:FindFirstChild("Moteur") then
			local m = morceauxDe(voiture)[partie:GetAttribute("Morceau")]
			if m then abimer(voiture, m, PV_COUP + (bas - ROUTE_SEUIL) * 2, "route") end
		end
		return
	end
	local point = pointProche(partie, pointProche(autre, partie.Position))
	local m = morceauDe(voiture, partie, point)
	if m then abimer(voiture, m, PV_COUP + vitesse * PV_VITESSE, "contact " .. autre.Name) end
end

local function brancher(voiture)
	if voiture:GetAttribute("DegatsBranches") then return end
	voiture:SetAttribute("DegatsBranches", true)
	-- l usure de la course d avant : on noircit tout de suite
	for _, m in pairs(morceauxDe(voiture)) do
		local t = (1 - m.pv / 100) * NOIRCI
		for _, partie in ipairs(m.parties) do partie.Color = m.couleurs[partie]:Lerp(SUIE, t) end
	end
	voiture:SetAttribute("Etat", calculerEtat(voiture))
	for _, partie in ipairs(voiture:GetDescendants()) do
		if partie:IsA("BasePart") and partie.CanTouch and partie.Name ~= "DriveSeat" then
			partie.Touched:Connect(function(autre)
				surContact(voiture, partie, autre)
			end)
		end
	end
end

-- Une voiture qui part : on la branche (DepartCourse lui a donne "Modele")
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		tombes:ClearAllChildren()             -- on ramasse les morceaux de la course d avant
		for _, voiture in ipairs(dossier:GetChildren()) do
			if voiture:GetAttribute("Modele") then
				depart[voiture] = os.clock()
				brancher(voiture)
			end
		end
	end
end)

-- une voiture remplacee : on oublie ce qu on savait d elle
dossier.ChildRemoved:Connect(function(voiture)
	morceaux[voiture], depart[voiture] = nil, nil
end)
