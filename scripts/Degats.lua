-- ============================================================
--  LES DEGATS DES VOITURES
--  A placer dans ServerScriptService.
--
--  CHAQUE MORCEAU S ABIME A PART. Les morceaux (rétroviseurs, phares,
--  portières, aileron... liste dans GarageCatalogue.PIECES) ont chacun
--  leurs POINTS DE VIE (PV), de 100 a 0 :
--    - seul le morceau TOUCHE perd des PV ;
--    - il NOIRCIT petit a petit (on voit qu il est abime) ;
--    - a 0, il SE DETACHE, tombe... et RESTE sur la piste jusqu a la
--      course suivante. C est un obstacle : une voiture qui le percute
--      s abime a son tour.
--  La voiture entiere a aussi un ETAT (attribut "Etat", la barre de
--  Course.client) : a 0 %, elle est detruite et le pilote est elimine.
--
--  COMMENT SAIT-ON QU IL Y A EU UN COUP ?
--   1. LE CONTACT : une partie de la carrosserie TOUCHE un mur, le decor,
--      une autre voiture ou un morceau tombe (evenement Touched). Plus on
--      va vite, plus ca abime. Meme un frottement compte.
--   2. LE CHOC : la vitesse change d un coup d une image a l autre (contre
--      un mur : 30, 50, 100 studs/s). On ne regarde que l HORIZONTALE :
--      retomber du tremplin ne doit pas abimer, ce saut est obligatoire.
--  OU ? On cherche LE MORCEAU LE PLUS PROCHE du point touche (pour un
--  choc : le cote oppose au changement de vitesse).
--
--  "Solidite" (Belier, amelioration Carrosserie) divise les degats.
--  Les degats RESTENT sur la voiture du joueur : on previent GarageServeur
--  (BindableEvent "DegatsVoiture"), et on repare au garage.
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Catalogue = require(ReplicatedStorage:WaitForChild("GarageCatalogue"))

-- 1. le contact
local CONTACT_BASE  = 0.3    -- % d etat perdus a chaque contact...
local CONTACT_VIT   = 0.02   -- ...plus 0.02 % par stud/s (un frottement a 100 studs/s = 2.3 %)
local CONTACT_PAUSE = 0.4    -- secondes entre deux contacts comptes
-- 2. le choc
local SEUIL   = 18     -- studs/s d un coup : en dessous, ce n est pas un choc
local FORCE   = 0.6    -- % d etat perdus par stud/s au-dessus du seuil
-- les morceaux
local PV_PAR_POINT = 5    -- un morceau perd 5 PV pour 1 % d etat perdu (il casse bien avant la voiture)
local PRES         = 6    -- un morceau a plus de 6 studs du point touche n est pas touche
local NOIRCI       = 0.6  -- a 0 PV, la couleur est a 60 % vers le noir
local PROTEGE = 1.5     -- secondes apres le depart : on ne compte rien
local MIN_MSG = 3       -- on ne previent pas pour une egratignure

local ORANGE = Color3.fromRGB(255, 150, 60)
local SUIE   = Color3.fromRGB(30, 28, 26)

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

-- Ce qu on touche SANS s abimer : la route (comme dans Voitures), les
-- cages et portiques du depart, le sol naturel, les personnages.
local PISTE = {
	Route = true, Damier = true, Grille = true, LigneDepart = true,
	Tremplin = true, MarqueTremplin = true, PilierTremplin = true,
	CagesDepart = true, Checkpoints = true,
}
local function sansDegat(objet)
	if objet:IsA("Terrain") or objet.Name == "Baseplate" then return true end    -- le sol
	local modele = objet:FindFirstAncestorOfClass("Model")
	if modele and modele:FindFirstChildOfClass("Humanoid") then return true end
	if objet:IsDescendantOf(circuit) then
		local a = objet
		while a.Parent ~= circuit do a = a.Parent end
		return PISTE[a.Name] == true
	end
	return false
end

-- ce qu on retient de chaque voiture
local avant  = {}      -- sa vitesse horizontale a l image d avant
local depuis = {}      -- l heure du depart (pour PROTEGE)
local dernierContact = {}
local morceaux = {}    -- [voiture] = { {i, nom, parties, couleurs}, ... }

local function voitureDe(objet)
	local a = objet
	while a and a.Parent and a.Parent ~= dossier do a = a.Parent end
	if a and a.Parent == dossier then return a end
	return nil
end

local function piloteDe(voiture)
	local siege = voiture:FindFirstChildWhichIsA("VehicleSeat", true)
	local hum = siege and siege.Occupant
	return hum and Players:GetPlayerFromCharacter(hum.Parent), siege
end

-- Les morceaux de CETTE voiture (ceux qui ne sont pas deja tombes), avec
-- leur couleur neuve (pour noircir a partir d elle).
local function morceauxDe(voiture)
	if morceaux[voiture] then return morceaux[voiture] end
	local liste = {}
	for i, p in ipairs(Catalogue.PIECES) do
		local parties = Catalogue.partiesDe(voiture, {p.nom})
		if #parties > 0 then
			local couleurs = {}
			for _, partie in ipairs(parties) do couleurs[partie] = partie.Color end
			table.insert(liste, {i = i, nom = p.nom, parties = parties, couleurs = couleurs})
		end
	end
	morceaux[voiture] = liste
	return liste
end

-- Le point le plus proche de "p" sur la boite d une piece (pour un mur
-- de 100 studs, son centre est loin : on prend son point le plus proche).
local function pointProche(piece, p)
	local l = piece.CFrame:PointToObjectSpace(p)
	local d = piece.Size / 2
	return piece.CFrame * Vector3.new(math.clamp(l.X, -d.X, d.X), math.clamp(l.Y, -d.Y, d.Y), math.clamp(l.Z, -d.Z, d.Z))
end

-- Le morceau le plus proche d un point (nil s il est trop loin)
local function morceauPres(voiture, point)
	local meilleur, dMin = nil, PRES
	for _, m in ipairs(morceauxDe(voiture)) do
		for _, partie in ipairs(m.parties) do
			local d = (pointProche(partie, point) - point).Magnitude
			if d < dMin then meilleur, dMin = m, d end
		end
	end
	return meilleur
end

-- ---- UN MORCEAU SE DETACHE (et reste sur la piste) ----
local function detacher(voiture, m)
	local siege = voiture:FindFirstChildWhichIsA("VehicleSeat", true)
	local centre = siege.CFrame * Vector3.new(1.1, 1, 0)
	for _, partie in ipairs(m.parties) do
		-- on casse ses soudures et on le sort de la voiture
		for _, j in ipairs(partie:GetJoints()) do j:Destroy() end
		for _, w in ipairs(partie:GetChildren()) do
			if w:IsA("JointInstance") or w:IsA("WeldConstraint") then w:Destroy() end
		end
		partie.Anchored = false
		partie.Massless = false
		partie.CanCollide = true
		partie.CanTouch = true
		-- il vient de cette voiture : il ne la touche pas tout de suite (sinon
		-- il l abimerait en partant)
		partie:SetAttribute("DeVoiture", voiture.Name)
		partie:SetAttribute("TombeA", os.clock())
		partie.Parent = tombes
		-- il part vers l exterieur, en tournant
		local dehors = (partie.Position - centre).Unit + Vector3.new(0, 0.8, 0)
		partie.AssemblyLinearVelocity = siege.AssemblyLinearVelocity * 0.6 + dehors * 20
		partie.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		pcall(function() partie:SetNetworkOwner(nil) end)
	end
	-- il ne fait plus partie de la voiture
	local liste = morceauxDe(voiture)
	for k, x in ipairs(liste) do
		if x == m then table.remove(liste, k) break end
	end
	local perdues = voiture:GetAttribute("Perdues") or ""
	voiture:SetAttribute("Perdues", (perdues == "") and m.nom or (perdues .. "," .. m.nom))
	voiture:SetAttribute("PV" .. m.i, nil)
end

-- ---- UN MORCEAU S ABIME ----
local function abimerMorceau(voiture, m, pv)
	local reste = math.max(0, (voiture:GetAttribute("PV" .. m.i) or 100) - pv)
	voiture:SetAttribute("PV" .. m.i, reste)
	-- il noircit petit a petit
	local t = (1 - reste / 100) * NOIRCI
	for _, partie in ipairs(m.parties) do
		partie.Color = m.couleurs[partie]:Lerp(SUIE, t)
	end
	if reste <= 0 then
		detacher(voiture, m)
		return true
	end
	return false
end

-- Le texte des PV des morceaux pour le garage : "3:40,7:85" (numero:PV)
local function usure(voiture)
	local t = {}
	for _, m in ipairs(morceauxDe(voiture)) do
		local pv = voiture:GetAttribute("PV" .. m.i)
		if pv and pv < 100 then table.insert(t, m.i .. ":" .. math.floor(pv)) end
	end
	return table.concat(t, ",")
end

-- La fumee et le feu : poses sur le siege, allumes selon l etat.
local function effets(siege, etat)
	local fumee = siege:FindFirstChild("FumeeDegats")
	if not fumee then
		fumee = Instance.new("Smoke")
		fumee.Name = "FumeeDegats"
		fumee.Color = Color3.fromRGB(60, 60, 60)
		fumee.Size = 4
		fumee.RiseVelocity = 6
		fumee.Enabled = false
		fumee.Parent = siege
		local feu = Instance.new("Fire")
		feu.Name = "FeuDegats"
		feu.Size = 6
		feu.Enabled = false
		feu.Parent = siege
	end
	fumee.Enabled = etat < 50
	siege.FeuDegats.Enabled = etat < 25
end

-- ---- ABIMER : la voiture perd "perte" %, le morceau pres du point touche aussi ----
local function abimer(voiture, perte, point, raison)
	local etat = voiture:GetAttribute("Etat")
	if not etat or etat <= 0 then return end
	local joueur, siege = piloteDe(voiture)
	perte = perte / (voiture:GetAttribute("Solidite") or 1)
	etat = math.max(0, etat - perte)
	voiture:SetAttribute("Etat", etat)

	local m = morceauPres(voiture, point)
	local parti = m and abimerMorceau(voiture, m, perte * PV_PAR_POINT)

	if joueur then
		if parti then
			info:FireClient(joueur, "💥 " .. m.nom .. " arraché(e) !", ORANGE, 2)
		elseif perte >= MIN_MSG and etat > 0 then
			info:FireClient(joueur, "💥 Choc !  −" .. math.floor(perte) .. " %", ORANGE, 1.5)
		end
		-- le garage garde l etat de SA voiture d une course a l autre
		signal:Fire(joueur, voiture:GetAttribute("Modele"), etat, voiture:GetAttribute("Perdues") or "", usure(voiture))
		print(string.format("Degats : %s %s -%.1f %% (reste %.0f %%)%s", joueur.Name, raison, perte, etat,
			m and (" sur " .. m.nom .. (parti and " (ARRACHE)" or "")) or ""))
	end
	if siege then effets(siege, etat) end

	if etat <= 0 then
		-- DETRUITE : le pilote est elimine (CompteurTours le voit : Health
		-- = 0). On le fait d abord descendre (comme a l arrivee), sinon
		-- l interface d A-Chassis plante, puis la voiture disparait.
		if joueur then
			info:FireClient(joueur, "💥 VOITURE DÉTRUITE — répare-la au garage !", Color3.fromRGB(255, 80, 80), 4)
		end
		local hum = siege and siege.Occupant
		local soudure = siege and siege:FindFirstChild("SeatWeld")
		if soudure then soudure:Destroy() end
		if hum then hum.Health = 0 end
		task.delay(0.5, function() voiture:Destroy() end)
	end
end

-- ---- 1. LE CONTACT ----
local function brancher(voiture)
	if voiture:GetAttribute("DegatsBranches") then return end
	voiture:SetAttribute("DegatsBranches", true)
	-- l usure de la course d avant (posee par DepartCourse) : on noircit
	for _, m in ipairs(morceauxDe(voiture)) do
		local pv = voiture:GetAttribute("PV" .. m.i)
		if pv then abimerMorceau(voiture, m, 0) end
	end
	for _, partie in ipairs(voiture:GetDescendants()) do
		if partie:IsA("BasePart") and partie:FindFirstAncestor("Body") then
			partie.Touched:Connect(function(autre)
				if partie.Parent == tombes then return end        -- ce morceau est deja tombe
				if not workspace:GetAttribute("CourseEnCours") then return end
				if voitureDe(autre) == voiture or sansDegat(autre) then return end
				-- un morceau qui vient de tomber de CETTE voiture : pas tout de suite
				if autre:GetAttribute("DeVoiture") == voiture.Name and os.clock() - (autre:GetAttribute("TombeA") or 0) < 1.5 then return end
				local joueur, siege = piloteDe(voiture)
				if not (joueur and depuis[voiture] and os.clock() - depuis[voiture] > PROTEGE) then return end
				if os.clock() - (dernierContact[voiture] or 0) < CONTACT_PAUSE then return end
				dernierContact[voiture] = os.clock()
				-- la vitesse de l un PAR RAPPORT a l autre (une voiture qui me
				-- rentre dedans compte aussi)
				local vitesse = (siege.AssemblyLinearVelocity - autre.AssemblyLinearVelocity).Magnitude
				-- le point touche : sur MA partie, le plus pres de l objet
				local point = pointProche(partie, pointProche(autre, partie.Position))
				abimer(voiture, CONTACT_BASE + vitesse * CONTACT_VIT, point, "contact " .. autre.Name)
			end)
		end
	end
end

-- ---- 2. LE CHOC ----
RunService.Heartbeat:Connect(function()
	local enCourse = workspace:GetAttribute("CourseEnCours") == true
	for _, voiture in ipairs(dossier:GetChildren()) do
		local _, siege = piloteDe(voiture)
		if voiture:GetAttribute("Etat") then brancher(voiture) end
		if siege and siege.Occupant and enCourse and voiture:GetAttribute("Etat") then
			depuis[voiture] = depuis[voiture] or os.clock()
			local v = siege.AssemblyLinearVelocity
			local plat = Vector3.new(v.X, 0, v.Z)
			if avant[voiture] and os.clock() - depuis[voiture] > PROTEGE then
				local saut = plat - avant[voiture]
				if saut.Magnitude > SEUIL then
					-- poussee vers l arriere = touchee devant : le point touche
					-- est du cote OPPOSE au changement de vitesse, au bord de
					-- la carrosserie (9 de long, 4.5 de large depuis le centre)
					local l = siege.CFrame:VectorToObjectSpace(-saut).Unit
					local point = siege.CFrame * Vector3.new(1.1 + l.X * 4.5, 1, l.Z * 9)
					abimer(voiture, (saut.Magnitude - SEUIL) * FORCE, point, "choc")
					if voiture:GetAttribute("Etat") <= 0 then continue end
				end
			end
			avant[voiture] = plat
		else
			avant[voiture], depuis[voiture] = nil, nil
		end
	end
end)

-- une voiture detruite ou remplacee : on oublie ce qu on savait d elle
dossier.ChildRemoved:Connect(function(voiture)
	avant[voiture], depuis[voiture], dernierContact[voiture], morceaux[voiture] = nil, nil, nil, nil
end)

-- une NOUVELLE course : on ramasse les morceaux tombes de la precedente
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		tombes:ClearAllChildren()
	end
end)
