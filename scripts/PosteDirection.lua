-- =========================================================
--  LE POSTE DE DIRECTION DE COURSE  (cote SERVEUR)
--  A placer dans ServerScriptService.
--
--  Quand on s assoit sur une ChaiseBureau (les bureaux de la direction
--  de course), un menu s ouvre a l ecran (LocalScript PosteDirection,
--  dans StarterPlayerScripts). Trois onglets :
--    CAMERAS   regarder la piste depuis des cameras posees le long du circuit
--    PILOTES   le classement en direct ; on clique un pilote pour le suivre
--    METEO     soleil, coucher, nuit, brouillard, pluie (pour TOUT le serveur)
--
--  REGLE D OR : le serveur ne croit PAS l ecran du joueur. Avant d obeir a
--  une commande, il verifie que ce joueur est VRAIMENT assis a un bureau.
--  Sinon n importe qui pourrait mettre la nuit en pleine course.
--
--  Rien n est ecrit en dur : les cameras sont DEMANDEES A LA ROUTE (un
--  morceau sur ECART_CAMERA, plus le depart, le tremplin et le tunnel).
-- =========================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECART_CAMERA = 6      -- une camera "TV" tous les 6 morceaux de route
local RECUL_CAMERA = 15     -- studs a cote du bord de la route
local HAUT_CAMERA  = 30     -- studs au-dessus de la route (a 9, les barrieres cachaient tout)
local NB_LISTE     = 4      -- cameras proposees dans la liste (en plus des 3 speciales) ; 8 c etait trop

local circuit = workspace:WaitForChild("Circuit")
local route   = circuit:WaitForChild("Route")
local ligne   = circuit:WaitForChild("LigneDepart")
local tunnel  = circuit:WaitForChild("Tunnel")
local dossierVoitures = workspace:WaitForChild("Voitures")

-- ---- 1. LA ROUTE, DANS L ORDRE ----
-- Les morceaux s appellent Route1, Route2... (il manque 142 a 145 : c est
-- le trou du tremplin). On les trie par leur numero.
local morceaux = {}
for _, p in ipairs(route:GetChildren()) do
	if p:IsA("BasePart") then table.insert(morceaux, p) end
end
local function numero(p) return tonumber(p.Name:match("%d+")) or 0 end
table.sort(morceaux, function(a, b) return numero(a) < numero(b) end)
local NB = #morceaux

-- le morceau le plus proche d un point
local function plusProche(pos)
	local meilleur, indice = math.huge, 1
	for i, p in ipairs(morceaux) do
		local d = (p.Position - pos).Magnitude
		if d < meilleur then meilleur, indice = d, i end
	end
	return indice, meilleur
end

-- le centre d un dossier ou d un modele (la moyenne de ses pieces)
local function centre(objet)
	local somme, n = Vector3.zero, 0
	for _, p in ipairs(objet:GetDescendants()) do
		if p:IsA("BasePart") then somme += p.Position; n += 1 end
	end
	return somme / math.max(n, 1)
end

-- ---- 2. LES CAMERAS ----
-- Une camera au morceau i : sur le cote exterieur du virage (on voit mieux
-- la voiture arriver), en hauteur, et elle regarde le morceau.
-- On VERIFIE par un rayon qu elle voit bien la route (a 9 studs de haut,
-- les barrieres cachaient la route a presque toutes les cameras !). Si
-- quelque chose la cache (les murs du tunnel, le mat du portique), on la
-- met DEDANS : au-dessus de la route, un morceau avant, et elle regarde devant.
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Exclude
rayon.FilterDescendantsInstances = {dossierVoitures, ligne, circuit:FindFirstChild("CagesDepart")}

local function cameraAu(i, nom)
	local p = morceaux[i]
	local suivant = morceaux[i % NB + 1]
	local precedent = morceaux[(i - 2) % NB + 1]
	local droite = p.CFrame.RightVector
	-- de quel cote tourne la route ? on se met a l EXTERIEUR
	local virage = (suivant.Position - p.Position):Cross(p.Position - precedent.Position).Y
	local cote = (virage > 0) and 1 or -1
	local cible = p.Position + Vector3.new(0, 3, 0)     -- a hauteur de voiture
	-- on essaie : en haut a l exterieur, en haut a l interieur, puis a mi-hauteur
	local essais = {{cote, 1}, {-cote, 1}, {cote, 0.5}, {-cote, 0.5}}
	for _, e in ipairs(essais) do
		local position = p.Position + droite * e[1] * (p.Size.X / 2 + RECUL_CAMERA) + Vector3.new(0, HAUT_CAMERA * e[2], 0)
		if not workspace:Raycast(position, cible - position, rayon) then
			return {nom = nom, position = position, cible = cible, indice = i}
		end
	end
	-- rien ne marche (tunnel, portique) : dedans, au-dessus de la route
	local position = precedent.Position + p.CFrame.UpVector * 8
	return {nom = nom, position = position, cible = cible, indice = i}
end

-- le trou du tremplin : le plus grand ecart entre deux morceaux qui se suivent
local trou, ecartMax = 1, 0
for i = 1, NB do
	local d = (morceaux[i].Position - morceaux[i % NB + 1].Position).Magnitude
	if d > ecartMax then ecartMax, trou = d, i end
end

local cameras = {}   -- celles du menu
table.insert(cameras, cameraAu((plusProche(ligne.Position)), "DÉPART"))
table.insert(cameras, cameraAu(trou, "TREMPLIN"))
table.insert(cameras, cameraAu((plusProche(centre(tunnel))), "TUNNEL"))
for k = 1, NB_LISTE do
	table.insert(cameras, cameraAu(math.floor((k - 0.5) * NB / NB_LISTE) + 1, "CAMÉRA " .. k))
end

local camerasTV = {}  -- les cameras de la realisation TV (une tous les ECART_CAMERA morceaux)
for i = 1, NB, ECART_CAMERA do
	table.insert(camerasTV, cameraAu(i, "TV"))
end

-- ---- 3. LES MESSAGES ----
local dossierRemote = ReplicatedStorage:FindFirstChild("PosteDirection") or Instance.new("Folder")
dossierRemote.Name = "PosteDirection"
dossierRemote.Parent = ReplicatedStorage

local function remote(classe, nom)
	local r = dossierRemote:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = dossierRemote
	return r
end
local infos    = remote("RemoteFunction", "Infos")     -- question : "donne-moi les cameras"
local commande = remote("RemoteEvent", "Commande")     -- l ecran demande quelque chose

infos.OnServerInvoke = function()
	return {cameras = cameras, camerasTV = camerasTV, nbMorceaux = NB}
end

-- Est-il assis a un bureau ?
local function auBureau(joueur)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	return hum and hum.SeatPart and hum.SeatPart.Name == "ChaiseBureau"
end

-- ---- 4. LA METEO ----
-- On retient le ciel de depart pour pouvoir y revenir avec "SOLEIL".
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local depart = {
	ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	Densite = atmosphere and atmosphere.Density, Brume = atmosphere and atmosphere.Haze,
	Couleur = atmosphere and atmosphere.Color,
}
local nuages = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
nuages.Cover = 0
nuages.Parent = workspace.Terrain

local function ciel(heure, lumiere, densite, brume, couverture, pluie)
	Lighting.ClockTime = heure
	Lighting.Brightness = lumiere
	if atmosphere then
		atmosphere.Density = densite
		atmosphere.Haze = brume
	end
	nuages.Cover = couverture
	-- la pluie, elle, est dessinee par l ecran de chaque joueur (autour
	-- de SA camera) : le serveur ne fait que dire "il pleut"
	workspace:SetAttribute("Pluie", pluie)
end

local METEOS = {
	SOLEIL     = function() ciel(depart.ClockTime, depart.Brightness, depart.Densite or 0.3, depart.Brume or 0, 0, false) end,
	COUCHER    = function() ciel(18.2, 2, depart.Densite or 0.3, 1.5, 0.3, false) end,
	NUIT       = function() ciel(0.5, 1, depart.Densite or 0.3, 0, 0.2, false) end,
	BROUILLARD = function() ciel(depart.ClockTime, 1.5, 0.65, 3, 0.6, false) end,
	PLUIE      = function() ciel(depart.ClockTime, 1, 0.45, 2, 0.9, true) end,
}

-- ---- 5. LE STREAMING ----
-- Le joueur assis au bureau ne recoit que ce qui est pres de LUI. Pour qu il
-- voie la piste au bout de la camera, on deplace son "point de focus" :
-- une petite piece invisible, posee la ou il regarde.
local focus = {}     -- joueur -> la piece invisible
local regarde = {}   -- joueur -> {position = Vector3} ou {suit = joueur}

local function lacherFocus(joueur)
	if focus[joueur] then focus[joueur]:Destroy() end
	focus[joueur], regarde[joueur] = nil, nil
	if joueur.Parent then joueur.ReplicationFocus = nil end
end

local function viser(joueur, position)
	if not focus[joueur] then
		local p = Instance.new("Part")
		p.Name = "FocusDirection_" .. joueur.UserId
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.one
		p.Parent = workspace
		focus[joueur] = p
		joueur.ReplicationFocus = p
	end
	focus[joueur].Position = position
end

commande.OnServerEvent:Connect(function(joueur, quoi, valeur)
	if not auBureau(joueur) then return end            -- pas assis au bureau : on refuse
	if quoi == "meteo" and METEOS[valeur] then
		METEOS[valeur]()
		workspace:SetAttribute("Meteo", valeur)
		print(joueur.Name .. " met la meteo : " .. valeur)
	elseif quoi == "regarde" and typeof(valeur) == "Vector3" then
		regarde[joueur] = {position = valeur}
		viser(joueur, valeur)
	elseif quoi == "suit" and typeof(valeur) == "Instance" and valeur:IsA("Player") then
		regarde[joueur] = {suit = valeur}
	elseif quoi == "bureau" then
		lacherFocus(joueur)                               -- retour a la vue normale
	end
end)

Players.PlayerRemoving:Connect(lacherFocus)

-- ---- 6. LE CLASSEMENT EN DIRECT ----
-- Pour chaque pilote en voiture : le morceau de route ou il est, compte A
-- PARTIR DE LA LIGNE (le morceau de la ligne = 1). Quand il passe du
-- dernier morceau au premier, il franchit la ligne : un tour de plus. Sa
-- PROGRESSION = tours x NB + morceau : le plus grand est devant.
-- Sur la grille (juste avant la ligne) : tours = 0 ; apres la ligne : 1.
local iLigne = plusProche(ligne.Position)
local tours, dernierIndice = {}, {}

workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(function()
	if workspace:GetAttribute("CourseEnCours") then
		tours, dernierIndice = {}, {}
		for _, j in ipairs(Players:GetPlayers()) do
			j:SetAttribute("DirProgression", nil)
			j:SetAttribute("DirArrivee", nil)
		end
	end
end)

-- le torse du joueur s il est assis dans une voiture
local function enVoiture(joueur)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = hum and hum.SeatPart
	if siege and siege:IsA("VehicleSeat") and siege:IsDescendantOf(dossierVoitures) then
		return siege
	end
end

local attente = 0
RunService.Heartbeat:Connect(function(dt)
	attente += dt
	if attente < 0.2 then return end      -- 5 fois par seconde suffit
	attente = 0

	for _, joueur in ipairs(Players:GetPlayers()) do
		local siege = enVoiture(joueur)
		if siege then
			local i = (plusProche(siege.Position) - iLigne) % NB + 1
			local avant = dernierIndice[joueur]
			tours[joueur] = tours[joueur] or 0
			if avant then
				if avant > NB * 0.8 and i < NB * 0.2 then tours[joueur] += 1 end   -- un tour de plus
				if avant < NB * 0.2 and i > NB * 0.8 then tours[joueur] -= 1 end   -- marche arriere sur la ligne
			end
			dernierIndice[joueur] = i
			joueur:SetAttribute("DirProgression", tours[joueur] * NB + i)
			-- la position et le sens de la voiture, pour les cameras (meme si
			-- la voiture est trop loin pour etre "streamee" chez le directeur)
			joueur:SetAttribute("DirCFrame", siege.CFrame)
		else
			joueur:SetAttribute("DirCFrame", nil)
		end
		-- le focus du directeur qui suit un pilote : on le pose sur la voiture
		local r = regarde[joueur]
		if r and r.suit then
			local cf = r.suit:GetAttribute("DirCFrame")
			if cf then viser(joueur, cf.Position) end
		end
	end
end)

-- l heure d arrivee, pour classer ceux qui ont fini dans l ordre
local function surveiller(joueur)
	joueur:GetAttributeChangedSignal("DernierTemps"):Connect(function()
		joueur:SetAttribute("DirArrivee", workspace:GetServerTimeNow())
	end)
end
for _, j in ipairs(Players:GetPlayers()) do surveiller(j) end
Players.PlayerAdded:Connect(surveiller)

-- ---- 7. L ECRAN DU BUREAU ----
-- Quand quelqu un s assoit, l ecran de SON bureau affiche son nom.
local zone = workspace:WaitForChild("ZoneSpawn")
local ecrans = {}
for _, e in ipairs(zone:GetChildren()) do
	if e.Name == "Ecran" then table.insert(ecrans, e) end
end
for _, chaise in ipairs(zone:GetChildren()) do
	if chaise.Name == "ChaiseBureau" and chaise:IsA("Seat") then
		-- son ecran : le plus proche de la chaise
		local monEcran, d = nil, math.huge
		for _, e in ipairs(ecrans) do
			local dd = (e.Position - chaise.Position).Magnitude
			if dd < d then monEcran, d = e, dd end
		end
		local texte = monEcran and monEcran:FindFirstChildWhichIsA("TextLabel", true)
		local texteDeBase = texte and texte.Text
		chaise:GetPropertyChangedSignal("Occupant"):Connect(function()
			local hum = chaise.Occupant
			local joueur = hum and Players:GetPlayerFromCharacter(hum.Parent)
			if texte then texte.Text = joueur and ("EN LIGNE : " .. joueur.DisplayName) or texteDeBase end
			if not hum then
				-- il s est leve : on rend son focus a tous ceux qui n ont plus de bureau
				for j in pairs(focus) do
					if not auBureau(j) then lacherFocus(j) end
				end
			end
		end)
	end
end

print(string.format("Poste de direction : %d cameras dans le menu, %d cameras TV, tremplin apres %s",
	#cameras, #camerasTV, morceaux[trou].Name))
