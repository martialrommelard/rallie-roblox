-- =========================================================
--  LES MOUVEMENTS DES EXERCICES  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Roblox ne sait pas faire "pousser une barre" ou "pedaler" : on plie
--  nous-memes les articulations du personnage, a chaque image, PAR-DESSUS
--  ses animations normales (on tourne l Attachment0 des AnimationConstraint,
--  comme pour les PNJ des bureaux).
--    BANC   les bras poussent la barre, en meme temps qu elle monte
--    VELO   les pedales tournent ; le pilote se penche, tient le guidon, et
--           ses pieds SUIVENT les pedales (le triangle cuisse-mollet)
--    SAC    a chaque coup ("Frapper"), un bras part en avant, gauche puis droit
--  Le velo marche pour TOUS les pilotes qu on voit ; le banc et le sac,
--  seulement pour nous.
-- =========================================================

local Players                = game:GetService("Players")
local RunService             = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local DUREE_COUP = 0.32      -- un coup de poing dure 0,32 s (aller-retour)
local CADENCE    = 7         -- le pedalier tourne de 7 radians par seconde (~67 tours/min)

local joueur = Players.LocalPlayer
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")

-- ---- LES ARTICULATIONS D UN PERSONNAGE ----
-- nom -> {a = Attachment0, base = sa position de depart}
local NOMS = {"Waist", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow",
	"RightHip", "LeftHip", "RightKnee", "LeftKnee", "RightAnkle", "LeftAnkle"}
local articulations = setmetatable({}, {__mode = "k"})      -- perso -> ses articulations
local function jointsDe(perso)
	local j = articulations[perso]
	if j then return j end
	j = {}
	for _, nom in ipairs(NOMS) do
		local c = perso:FindFirstChild(nom, true)
		if not (c and c:IsA("AnimationConstraint") and c.Attachment0) then return nil end   -- pas encore charge
		j[nom] = {a = c.Attachment0, base = c.Attachment0.CFrame}
	end
	articulations[perso] = j
	return j
end
local function poser(j, nom, x)
	local o = j and j[nom]
	if o then o.a.CFrame = o.base * CFrame.Angles(math.rad(x or 0), 0, 0) end
end
local function poserRad(j, nom, angle)
	local o = j and j[nom]
	if o then o.a.CFrame = o.base * CFrame.Angles(angle, 0, 0) end
end

-- ---- LES VELOS : les pieces qui tournent ----
local velos = {}       -- selle -> ses pieces et l angle du pedalier
local function trouverVelos()
	for _, m in ipairs(salle:GetChildren()) do
		local selle = m:IsA("Model") and m:FindFirstChild("VeloSport")
		if selle and not velos[selle] then
			local axe = m:FindFirstChild("AxePedalier")
			local mD, mG = m:FindFirstChild("ManivelleD"), m:FindFirstChild("ManivelleG")
			local pD, pG = m:FindFirstChild("PedaleD"), m:FindFirstChild("PedaleG")
			local volant = m:FindFirstChild("VolantInertie")
			if axe and mD and mG and pD and pG then
				local B = axe.CFrame
				velos[selle] = {
					B = B, angle = 0,
					rayon = m:GetAttribute("Rayon") or 0.33,
					penche = math.rad(m:GetAttribute("Penche") or 25),
					-- l ecart de chaque piece a l axe : on le DEMANDE au velo
					xM = math.abs(B:PointToObjectSpace(mD.Position).X),
					xP = math.abs(B:PointToObjectSpace(pD.Position).X),
					mD = mD, mG = mG, pD = pD, pG = pG,
					volant = volant, volant0 = volant and volant.CFrame,
					poigneeD = m:FindFirstChild("PoigneeD"), poigneeG = m:FindFirstChild("PoigneeG"),
				}
			end
		end
	end
	for selle in pairs(velos) do
		if not selle:IsDescendantOf(workspace) then velos[selle] = nil end    -- streaming : il est reparti
	end
end
task.spawn(function()
	while true do trouverVelos() task.wait(2) end
end)

local function tournerVelo(v, dt)
	-- vers les angles negatifs : en bas, la pedale part vers l ARRIERE (comme en vrai)
	v.angle -= CADENCE * dt
	local r = v.rayon
	for _, cote in ipairs({{v.mD, v.pD, 1, 0}, {v.mG, v.pG, -1, math.pi}}) do
		local phi = v.angle + cote[4]                       -- la pedale gauche est en face
		cote[1].CFrame = v.B * CFrame.new(cote[3] * v.xM, 0, 0) * CFrame.Angles(phi, 0, 0) * CFrame.new(0, -r / 2, 0)
		cote[2].CFrame = v.B * CFrame.new(cote[3] * v.xP, -r * math.cos(phi), -r * math.sin(phi))   -- la pedale reste a plat
	end
	if v.volant then v.volant.CFrame = v.volant0 * CFrame.Angles(v.angle * 3, 0, 0) end   -- la roue tourne 3 fois plus vite
end

-- ---- LE PILOTE : le triangle cuisse-mollet ----
-- Vu de cote (devant / bas), on connait la hanche, la cible (au-dessus de la
-- pedale) et les longueurs de la cuisse (a) et du mollet (b). Le genou est
-- la pointe du triangle : l angle a la hanche se trouve avec Al-Kashi,
--   cos(gamma) = (a^2 + d^2 - b^2) / (2 a d)      (d = hanche -> cible)
-- Les angles sont comptes depuis "tout droit vers le bas", positifs vers l avant.
local function longueurCote(v) return math.sqrt(v.Y ^ 2 + v.Z ^ 2) end
local function angleCote(v) return math.atan2(-v.Z, -v.Y) end
local function triangle(F, origine, cible, a, b, pointeDevant)
	local D = F:VectorToObjectSpace(cible - origine)
	local devant, bas = -D.Z, -D.Y
	local d = math.clamp(math.sqrt(devant ^ 2 + bas ^ 2), math.abs(a - b) + 0.01, a + b - 0.001)
	local beta = math.atan2(devant, bas)
	local gamma = math.acos(math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
	local haut = pointeDevant and beta + gamma or beta - gamma                    -- la cuisse (ou le bras)
	local bas2 = math.atan2(devant - a * math.sin(haut), bas - a * math.cos(haut)) -- le mollet (ou l avant-bras)
	return haut, bas2
end

local function poserPilote(perso, v)
	local j = jointsDe(perso)
	local LT, UT = perso:FindFirstChild("LowerTorso"), perso:FindFirstChild("UpperTorso")
	if not (j and LT and UT) then return end
	-- on coupe l animation "assis" de Roblox : c est nous qui posons tout
	local hum = perso:FindFirstChildOfClass("Humanoid")
	local animateur = hum and hum:FindFirstChildOfClass("Animator")
	if animateur then
		for _, piste in ipairs(animateur:GetPlayingAnimationTracks()) do piste:Stop(0) end
	end
	poserRad(j, "Waist", -v.penche)                   -- le buste penche en avant
	for _, cote in ipairs({"Right", "Left"}) do
		-- LA JAMBE : la cheville juste au-dessus de la pedale
		local cuisse, mollet, pied = perso:FindFirstChild(cote .. "UpperLeg"), perso:FindFirstChild(cote .. "LowerLeg"), perso:FindFirstChild(cote .. "Foot")
		local pedale = cote == "Right" and v.pD or v.pG
		if cuisse and mollet and pied then
			local a = (cuisse[cote .. "KneeRigAttachment"].Position - cuisse[cote .. "HipRigAttachment"].Position).Magnitude
			local b = (mollet[cote .. "AnkleRigAttachment"].Position - mollet[cote .. "KneeRigAttachment"].Position).Magnitude
			local h = (pied[cote .. "AnkleRigAttachment"].Position - pied[cote .. "FootAttachment"].Position).Magnitude
			local cible = pedale.Position + pedale.CFrame.UpVector * (pedale.Size.Y / 2 + h)
			local tCuisse, tMollet = triangle(LT.CFrame * j[cote .. "Hip"].base, LT[cote .. "HipRigAttachment"].WorldPosition,
				cible, a, b, true)                            -- le genou pointe vers l avant
			poserRad(j, cote .. "Hip", tCuisse)
			poserRad(j, cote .. "Knee", tMollet - tCuisse)
			poserRad(j, cote .. "Ankle", -tMollet)          -- le pied reste a plat
		end
		-- LE BRAS : la main sur la poignee
		local haut, avant, main = perso:FindFirstChild(cote .. "UpperArm"), perso:FindFirstChild(cote .. "LowerArm"), perso:FindFirstChild(cote .. "Hand")
		local poignee = cote == "Right" and v.poigneeD or v.poigneeG
		if haut and avant and main and poignee then
			local vHaut = haut[cote .. "ElbowRigAttachment"].Position - haut[cote .. "ShoulderRigAttachment"].Position
			local vBas = (avant[cote .. "WristRigAttachment"].Position - avant[cote .. "ElbowRigAttachment"].Position)
				+ (main[cote .. "GripAttachment"].Position - main[cote .. "WristRigAttachment"].Position)
			local tHaut, tBas = triangle(UT.CFrame * j[cote .. "Shoulder"].base, UT[cote .. "ShoulderRigAttachment"].WorldPosition,
				poignee.Position, longueurCote(vHaut), longueurCote(vBas), false)   -- le coude plie vers le bas
			local s = tHaut - angleCote(vHaut)              -- au repos, le bras n est pas tout droit
			poserRad(j, cote .. "Shoulder", s)
			poserRad(j, cote .. "Elbow", tBas - s - angleCote(vBas))
		end
	end
end

-- remettre un personnage comme avant (il est descendu du velo)
local function relacher(perso)
	local j = articulations[perso]
	if j then for _, o in pairs(j) do o.a.CFrame = o.base end end
end

-- ---- MOI : le banc et le sac ----
-- les coups de poing
local coup = nil       -- {bras = "Right"/"Left", t0}
local bras = "Left"
ProximityPromptService.PromptTriggered:Connect(function(prompt, qui)
	if qui ~= joueur or not prompt.Parent or prompt.Parent.Name ~= "SacFrappe" then return end
	bras = (bras == "Left") and "Right" or "Left"
	coup = {bras = bras, t0 = os.clock()}
	-- on se tourne vers le sac
	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if racine then
		local cible = Vector3.new(prompt.Parent.Position.X, racine.Position.Y, prompt.Parent.Position.Z)
		racine.CFrame = CFrame.lookAt(racine.Position, cible)
	end
end)

-- la barre (avec le streaming, elle peut arriver plus tard) ; sa hauteur de
-- repos = la plus basse qu on lui ait vue
local barre, yBarreRepos = nil, math.huge
local surLeVelo = {}     -- perso -> true : ceux qu on a poses sur un velo a l image d avant

RunService.RenderStepped:Connect(function(dt)
	-- LES VELOS : les pedales tournent quand quelqu un est dessus, et on pose le pilote
	local vus = {}
	for selle, v in pairs(velos) do
		local hum = selle.Occupant
		if hum and hum.Parent then
			tournerVelo(v, dt)
			poserPilote(hum.Parent, v)
			vus[hum.Parent] = true
		end
	end
	for perso in pairs(surLeVelo) do
		if not vus[perso] then relacher(perso) end
	end
	surLeVelo = vus

	-- MOI, sur le banc ou au sac
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local j = perso and jointsDe(perso)
	if not hum or not j or vus[perso] then return end
	local siege = hum.SeatPart
	-- par defaut : rien (on remet tout comme l animation de Roblox le fait)
	local epD, epG, coD, coG = 0, 0, 0, 0

	if not barre then barre = salle:FindFirstChild("Barre") end
	if barre then yBarreRepos = math.min(yBarreRepos, barre.Position.Y) end
	if siege and siege.Name == "BancMuscu" and barre then
		-- s = 0 barre en bas, 1 barre en haut (elle monte de 1,4 stud)
		local s = math.clamp((barre.Position.Y - yBarreRepos) / 1.4, 0, 1)
		epD, epG = 55 + 45 * s, 55 + 45 * s      -- les bras montent devant
		coD, coG = 80 * (1 - s), 80 * (1 - s)    -- les coudes se tendent en haut
	end
	if coup then
		local k = (os.clock() - coup.t0) / DUREE_COUP
		if k >= 1 then
			coup = nil
		else
			local bosse = math.sin(math.pi * k)    -- 0 -> 1 -> 0 : le bras part et revient
			if coup.bras == "Right" then epD, coD = 90 * bosse, -10 * bosse else epG, coG = 90 * bosse, -10 * bosse end
		end
	end
	poser(j, "RightShoulder", epD) poser(j, "LeftShoulder", epG)
	poser(j, "RightElbow", coD) poser(j, "LeftElbow", coG)
end)
