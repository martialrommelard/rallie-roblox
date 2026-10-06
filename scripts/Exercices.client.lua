-- =========================================================
--  LES MOUVEMENTS DES EXERCICES  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Roblox ne sait pas faire "pousser une barre" ou "pedaler" : on plie
--  nous-memes les articulations du personnage, a chaque image, PAR-DESSUS
--  ses animations normales (on tourne l Attachment0 des AnimationConstraint,
--  comme pour les PNJ des bureaux).
--    BANC   allonge, les mains sur la barre ; on la pousse au bon moment
--    VELO   les pedales tournent ; le pilote se penche, tient le guidon, et
--           ses pieds SUIVENT les pedales (le triangle cuisse-mollet)
--    SAC    a chaque coup ("Frapper"), un bras part en avant, gauche puis droit
--    TAPIS  les rayures de la bande defilent a la vitesse du tapis
--    BARRE  on s accroche ; chaque clic fait monter, la jauge redescend
--           de plus en plus vite : menton a la barre = une traction
--    HALTERES  chaque clic = un curl, bras droit puis bras gauche
--    RAMEUR chaque clic = un coup de rame : la course ; le siege glisse
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

-- ---- LES TAPIS : les rayures de la bande defilent, a la vitesse du tapis ----
local tapis = {}       -- modele -> {bande, rayures, decalage}
local function trouverTapis()
	for _, m in ipairs(salle:GetChildren()) do
		local bande = m:IsA("Model") and m.Name == "TapisDeCourse" and m:FindFirstChild("TapisCourse")
		if bande and not tapis[m] then
			local B = bande.CFrame
			local rayures = {}
			for _, r in ipairs(m:GetChildren()) do
				if r.Name == "RayureTapis" then
					local l = B:PointToObjectSpace(r.Position)
					table.insert(rayures, {p = r, y = l.Y, z = l.Z})
				end
			end
			tapis[m] = {modele = m, B = B, longueur = bande.Size.Z, rayures = rayures, decalage = 0}
		end
	end
	for m in pairs(tapis) do
		if not m:IsDescendantOf(workspace) then tapis[m] = nil end
	end
end
local function defiler(t, dt)
	t.decalage += (t.modele:GetAttribute("Vitesse") or 0) * dt
	local L = t.longueur
	for _, r in ipairs(t.rayures) do
		-- vers l arriere (+Z) ; arrivee au bout, la rayure repart de devant
		local z = (r.z + t.decalage + L / 2) % L - L / 2
		r.p.CFrame = t.B * CFrame.new(0, r.y, z)
	end
end
task.spawn(function()
	while true do trouverVelos() trouverTapis() task.wait(2) end
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

-- ---- LA BARRE DE TRACTION : le jeu de la jauge ----
-- Chaque CLIC fait monter (PAS). La jauge redescend toute seule, un peu
-- plus vite qu on est HAUT (h au carre), et surtout de plus en plus vite a
-- chaque traction faite (FATIGUE) : facile au debut, dur petit a petit.
-- Au debut, en haut, il faut ~2,6 clics/s ; a 10 tractions ~5,7 ; a 20 ~8,8.
-- h = 1 : une traction !
local PAS     = 0.14
local CHUTE   = 0.08       -- ce que la jauge perd par seconde, tout en bas
local CHUTE_H = 0.35       -- ... et en plus, tout en haut
local FATIGUE = 0.12       -- chaque traction faite rend la suivante 12 % plus dure

local evenementTraction = game:GetService("ReplicatedStorage"):WaitForChild("Traction")
local UserInputService = game:GetService("UserInputService")
local traction = nil       -- {barre, h, hVue, reps, bas, haut, aligneP, aligneO, att}

-- l ecran de la jauge
local gui = Instance.new("ScreenGui")
gui.Name = "JaugeTraction"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")
local cadre = Instance.new("Frame")
cadre.AnchorPoint = Vector2.new(1, 0.5)
cadre.Position = UDim2.new(1, -40, 0.5, 0)
cadre.Size = UDim2.fromOffset(70, 320)
cadre.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
cadre.BackgroundTransparency = 0.15
cadre.BorderSizePixel = 0
cadre.Parent = gui
Instance.new("UICorner", cadre).CornerRadius = UDim.new(0, 12)
local remplissage = Instance.new("Frame")
remplissage.AnchorPoint = Vector2.new(0, 1)
remplissage.Position = UDim2.new(0, 8, 1, -8)
remplissage.Size = UDim2.new(1, -16, 0, 0)
remplissage.BorderSizePixel = 0
remplissage.Parent = cadre
Instance.new("UICorner", remplissage).CornerRadius = UDim.new(0, 8)
local function etiquette(pos, taille, texte, couleur)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(1, 0.5)
	l.Position, l.Size = pos, taille
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = couleur
	l.TextStrokeTransparency = 0.3
	l.Text = texte
	l.Parent = gui
	return l
end
local texteReps   = etiquette(UDim2.new(1, -20, 0.5, -190), UDim2.fromOffset(260, 40), "TRACTIONS : 0", Color3.new(1, 1, 1))
local texteClic   = etiquette(UDim2.new(1, -120, 0.5, 0), UDim2.fromOffset(220, 50), "CLIQUE !", Color3.fromRGB(255, 205, 60))
local texteAide   = etiquette(UDim2.new(1, -20, 0.5, 190), UDim2.fromOffset(260, 26), "Espace : lacher la barre", Color3.fromRGB(180, 190, 200))
local texteBravo  = etiquette(UDim2.new(1, -120, 0.5, -60), UDim2.fromOffset(160, 60), "", Color3.fromRGB(80, 220, 120))

local function finirTraction()
	if not traction then return end
	local t = traction
	traction = nil
	for _, o in ipairs({t.aligneP, t.aligneO, t.att}) do o:Destroy() end
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
	if perso then relacher(perso) end
	t.prompt.Enabled = true
	gui.Enabled = false
	evenementTraction:FireServer("fin")
end

local function commencerTraction(barre, prompt)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local LT, UT = perso and perso:FindFirstChild("LowerTorso"), perso and perso:FindFirstChild("UpperTorso")
	local brasHaut, brasBas, main = perso and perso:FindFirstChild("RightUpperArm"), perso and perso:FindFirstChild("RightLowerArm"), perso and perso:FindFirstChild("RightHand")
	if traction or not (hum and racine and LT and UT and brasHaut and brasBas and main) or hum.SeatPart then return end
	if barre.Parent:GetAttribute("Occupant") then return end           -- quelqu un y est deja
	-- ou sont l epaule et le cou, vus depuis le HumanoidRootPart (on le DEMANDE a l avatar)
	local base = racine.RootRigAttachment.Position.Y - LT.RootRigAttachment.Position.Y + LT.WaistRigAttachment.Position.Y - UT.WaistRigAttachment.Position.Y
	local epauleY = base + UT.RightShoulderRigAttachment.Position.Y
	local vHaut = brasHaut.RightElbowRigAttachment.Position - brasHaut.RightShoulderRigAttachment.Position
	local vBas = (brasBas.RightWristRigAttachment.Position - brasBas.RightElbowRigAttachment.Position)
		+ (main.RightGripAttachment.Position - main.RightWristRigAttachment.Position)
	local bras = longueurCote(vHaut) + longueurCote(vBas)
	-- en bas : bras presque tendus ; en haut : les epaules a 0,45 sous la barre
	local yBarre = barre.Position.Y
	local bas = yBarre - epauleY - bras * 0.97
	local haut = yBarre - 0.45 - epauleY

	local att = Instance.new("Attachment")
	att.Parent = racine
	local aligneP = Instance.new("AlignPosition")
	aligneP.Mode = Enum.PositionAlignmentMode.OneAttachment
	aligneP.Attachment0 = att
	aligneP.MaxForce = 1e6
	aligneP.Responsiveness = 60
	aligneP.Parent = racine
	local aligneO = Instance.new("AlignOrientation")
	aligneO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aligneO.Attachment0 = att
	aligneO.MaxTorque = 1e6
	aligneO.Responsiveness = 60
	aligneO.CFrame = barre.CFrame - barre.CFrame.Position      -- on regarde comme la barre (vers son -Z)
	aligneO.Parent = racine
	hum.PlatformStand = true
	prompt.Enabled = false
	traction = {perso = perso, barre = barre, prompt = prompt, h = 0, hVue = 0, reps = 0, bas = bas, haut = haut,
		aligneP = aligneP, aligneO = aligneO, att = att, finBravo = 0}
	aligneP.Position = Vector3.new(barre.Position.X, bas, barre.Position.Z)
	texteReps.Text = "TRACTIONS : 0"
	gui.Enabled = true
	evenementTraction:FireServer("debut", barre.Parent)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, qui)
	if qui == joueur and prompt.Parent and prompt.Parent.Name == "BarreTraction" then
		commencerTraction(prompt.Parent, prompt)
	end
end)
UserInputService.InputBegan:Connect(function(entree, dejaPris)
	if not traction then return end
	if entree.KeyCode == Enum.KeyCode.Space then finirTraction() return end
	if dejaPris then return end
	if entree.UserInputType == Enum.UserInputType.MouseButton1 or entree.UserInputType == Enum.UserInputType.Touch
		or entree.KeyCode == Enum.KeyCode.ButtonR2 then
		traction.h += PAS
	end
end)

local function poserTraction(perso, dt)
	local t = traction
	local hum = perso:FindFirstChildOfClass("Humanoid")
	if perso ~= t.perso or not hum or hum.Health <= 0 or not t.barre:IsDescendantOf(workspace) then finirTraction() return end
	-- la jauge redescend, plus vite en haut et avec la fatigue
	t.h = math.max(0, t.h - (CHUTE + CHUTE_H * t.h * t.h) * (1 + FATIGUE * t.reps) * dt)
	if t.h >= 1 then
		t.reps += 1
		t.h = 0
		t.finBravo = os.clock() + 0.8
		texteReps.Text = "TRACTIONS : " .. t.reps
		evenementTraction:FireServer("rep", t.barre.Parent)
	end
	t.hVue += (t.h - t.hVue) * math.min(1, dt * 12)             -- le corps suit la jauge, en douceur
	-- la jauge : du vert (en bas) au rouge (en haut)
	remplissage.Size = UDim2.new(1, -16, math.clamp(t.h, 0, 1) * (1 - 16 / 320), 0)
	remplissage.BackgroundColor3 = Color3.fromRGB(80, 220, 120):Lerp(Color3.fromRGB(255, 70, 50), t.h)
	texteClic.Visible = (os.clock() * 4) % 2 < 1.4                 -- "CLIQUE !" clignote
	texteBravo.Text = os.clock() < t.finBravo and "+1 !" or ""
	-- le corps monte et descend
	local b = t.barre.Position
	t.aligneP.Position = Vector3.new(b.X, t.bas + (t.haut - t.bas) * t.hVue, b.Z)
	-- les bras : les mains sur les poignees (le meme triangle que sur le velo)
	local j = jointsDe(perso)
	local UT = perso:FindFirstChild("UpperTorso")
	if not (j and UT) then return end
	local animateur = hum:FindFirstChildOfClass("Animator")
	if animateur then
		for _, piste in ipairs(animateur:GetPlayingAnimationTracks()) do piste:Stop(0) end
	end
	local poignees = {}
	for _, p in ipairs(t.barre.Parent:GetChildren()) do
		if p.Name == "PoigneeTraction" then table.insert(poignees, p) end
	end
	for _, cote in ipairs({"Right", "Left"}) do
		local haut, avant, main = perso:FindFirstChild(cote .. "UpperArm"), perso:FindFirstChild(cote .. "LowerArm"), perso:FindFirstChild(cote .. "Hand")
		-- la poignee de ce cote : celle qui est du meme cote que l epaule
		local epaule = UT[cote .. "ShoulderRigAttachment"]
		local poignee = nil
		for _, p in ipairs(poignees) do
			if not poignee or (p.Position - epaule.WorldPosition).Magnitude < (poignee.Position - epaule.WorldPosition).Magnitude then poignee = p end
		end
		if haut and avant and main and poignee then
			local vHaut = haut[cote .. "ElbowRigAttachment"].Position - haut[cote .. "ShoulderRigAttachment"].Position
			local vBas = (avant[cote .. "WristRigAttachment"].Position - avant[cote .. "ElbowRigAttachment"].Position)
				+ (main[cote .. "GripAttachment"].Position - main[cote .. "WristRigAttachment"].Position)
			local tHaut, tBas = triangle(UT.CFrame * j[cote .. "Shoulder"].base, epaule.WorldPosition,
				poignee.Position, longueurCote(vHaut), longueurCote(vBas), false)   -- les coudes passent devant
			local s = tHaut - angleCote(vHaut)
			poserRad(j, cote .. "Shoulder", s)
			poserRad(j, cote .. "Elbow", tBas - s - angleCote(vBas))
		end
		-- les jambes pendent, genoux un peu plies
		poser(j, cote .. "Hip", 12)
		poser(j, cote .. "Knee", -45)
		poser(j, cote .. "Ankle", 25)
	end
end

-- ---- LE BANC DE DEVELOPPE COUCHE : le jeu du bon moment ----
-- Un curseur monte et descend dans la jauge. Quand la barre est sur la
-- poitrine, il faut cliquer pendant qu il est dans la ZONE VERTE : la barre
-- monte (+1). A chaque barre soulevee, le curseur va plus vite et la zone
-- retrecit (et elle change de place). Rate : on attend PENALITE secondes ;
-- et a partir de NIVEAU_DANGER barres, rater = on recommence a zero !
local PERIODE0, PERIODE_MIN, ACCELERE = 1.8, 0.55, 0.92   -- un aller-retour du curseur (s)
local ZONE0, ZONE_MIN, RETRECIT       = 0.30, 0.08, 0.90  -- la hauteur de la zone verte (1 = toute la jauge)
local PENALITE = 0.6
local NIVEAU_DANGER = 5

local evenementBanc = game:GetService("ReplicatedStorage"):WaitForChild("Banc")
local banc = nil       -- la partie en cours

local guiB = Instance.new("ScreenGui")
guiB.Name = "JaugeBanc"
guiB.ResetOnSpawn = false
guiB.Enabled = false
guiB.Parent = joueur:WaitForChild("PlayerGui")
local cadreB = cadre:Clone()          -- le meme cadre que la jauge des tractions
for _, c in ipairs(cadreB:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
cadreB.Parent = guiB
local piste = Instance.new("Frame")
piste.Position, piste.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16)
piste.BackgroundTransparency = 1
piste.Parent = cadreB
local zoneB = Instance.new("Frame")
zoneB.AnchorPoint = Vector2.new(0, 0.5)
zoneB.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
zoneB.BorderSizePixel = 0
zoneB.Parent = piste
Instance.new("UICorner", zoneB).CornerRadius = UDim.new(0, 6)
local curseur = Instance.new("Frame")
curseur.AnchorPoint = Vector2.new(0.5, 0.5)
curseur.Size = UDim2.new(1, 14, 0, 7)
curseur.BackgroundColor3 = Color3.new(1, 1, 1)
curseur.BorderSizePixel = 0
curseur.ZIndex = 3
curseur.Parent = piste
local function etiquetteB(pos, taille, texte, couleur)
	local l = etiquette(pos, taille, texte, couleur)
	l.Parent = guiB
	return l
end
local texteBarres  = etiquetteB(UDim2.new(1, -20, 0.5, -190), UDim2.fromOffset(260, 40), "BARRES : 0", Color3.new(1, 1, 1))
local texteConsigne = etiquetteB(UDim2.new(1, -120, 0.5, 0), UDim2.fromOffset(260, 44), "", Color3.fromRGB(255, 205, 60))
local texteResultat = etiquetteB(UDim2.new(1, -120, 0.5, -60), UDim2.fromOffset(200, 56), "", Color3.fromRGB(80, 220, 120))
etiquetteB(UDim2.new(1, -20, 0.5, 190), UDim2.fromOffset(260, 26), "Espace : se relever", Color3.fromRGB(180, 190, 200))

local function nouvelleZone(b)
	b.centre = b.largeur / 2 + 0.05 + math.random() * (1 - b.largeur - 0.1)
	zoneB.Position = UDim2.fromScale(0, 1 - b.centre)
	zoneB.Size = UDim2.fromScale(1, b.largeur)
end

local function finirBanc()
	if not banc then return end
	local b = banc
	banc = nil
	for _, o in ipairs({b.aligneP, b.aligneO, b.att}) do o:Destroy() end
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	if racine then        -- on se releve, debout a cote du banc
		local c = b.coussin.CFrame
		racine.CFrame = CFrame.lookAt(c.Position + c.RightVector * 2.2 + c.UpVector * 3, c.Position + c.RightVector * 2.2 + c.UpVector * 3 + c.LookVector)
	end
	if hum then hum.PlatformStand = false end
	if perso then relacher(perso) end
	b.prompt.Enabled = true
	guiB.Enabled = false
	evenementBanc:FireServer("fin")
end

local function commencerBanc(coussin, prompt)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local LT, UT = perso and perso:FindFirstChild("LowerTorso"), perso and perso:FindFirstChild("UpperTorso")
	local modele = coussin.Parent
	local place = coussin:FindFirstChild("Epaules")
	if banc or traction or not (hum and racine and LT and UT and place) or hum.SeatPart then return end
	if modele:GetAttribute("Occupant") then return end
	-- ou est l epaule, vue depuis le HumanoidRootPart (comme pour la traction)
	local epauleY = racine.RootRigAttachment.Position.Y - LT.RootRigAttachment.Position.Y + LT.WaistRigAttachment.Position.Y
		- UT.WaistRigAttachment.Position.Y + UT.RightShoulderRigAttachment.Position.Y
	-- allonge sur le dos : la tete vers le rack (-Z du coussin), le ventre vers le ciel
	local c = coussin.CFrame
	local haut, dos = c.LookVector, -c.UpVector
	local pos = place.WorldPosition + c.UpVector * (UT.Size.Z / 2) - haut * epauleY
	local att = Instance.new("Attachment")
	att.Parent = racine
	local aligneP = Instance.new("AlignPosition")
	aligneP.Mode = Enum.PositionAlignmentMode.OneAttachment
	aligneP.Attachment0 = att
	aligneP.MaxForce = 1e6
	aligneP.Responsiveness = 60
	aligneP.Position = pos
	aligneP.Parent = racine
	local aligneO = Instance.new("AlignOrientation")
	aligneO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aligneO.Attachment0 = att
	aligneO.MaxTorque = 1e6
	aligneO.Responsiveness = 60
	aligneO.CFrame = CFrame.fromMatrix(Vector3.zero, haut:Cross(dos), haut, dos)
	aligneO.Parent = racine
	hum.PlatformStand = true
	racine.CFrame = CFrame.fromMatrix(pos, haut:Cross(dos), haut, dos)      -- tout de suite en place
	prompt.Enabled = false
	banc = {perso = perso, modele = modele, coussin = coussin, barre = modele:FindFirstChild("Barre"), prompt = prompt,
		aligneP = aligneP, aligneO = aligneO, att = att,
		reps = 0, periode = PERIODE0, largeur = ZONE0, phase = 0, centre = 0.5, curseur = 0,
		etaitEnBas = false, attendre = false, bloque = 0, finResultat = 0}
	nouvelleZone(banc)
	texteBarres.Text = "BARRES : 0"
	texteResultat.Text = ""
	guiB.Enabled = true
	evenementBanc:FireServer("debut")
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, qui)
	if qui == joueur and prompt.Parent and prompt.Parent.Name == "CoussinBanc" then
		commencerBanc(prompt.Parent, prompt)
	end
end)
UserInputService.InputBegan:Connect(function(entree, dejaPris)
	local b = banc
	if not b then return end
	if entree.KeyCode == Enum.KeyCode.Space then finirBanc() return end
	if dejaPris then return end
	if not (entree.UserInputType == Enum.UserInputType.MouseButton1 or entree.UserInputType == Enum.UserInputType.Touch
		or entree.KeyCode == Enum.KeyCode.ButtonR2) then return end
	if not b.modele:GetAttribute("EnBas") or b.attendre or os.clock() < b.bloque then return end
	local ecart = math.abs(b.curseur - b.centre)
	if ecart <= b.largeur / 2 then
		-- dans le vert : on pousse !
		b.attendre = true
		b.reps += 1
		evenementBanc:FireServer("pousse")
		texteBarres.Text = "BARRES : " .. b.reps
		texteResultat.Text = ecart < b.largeur / 6 and "PARFAIT !" or "BIEN !"
		texteResultat.TextColor3 = Color3.fromRGB(80, 220, 120)
		-- et ca se complique
		b.periode = math.max(PERIODE_MIN, b.periode * ACCELERE)
		b.largeur = math.max(ZONE_MIN, b.largeur * RETRECIT)
	elseif b.reps >= NIVEAU_DANGER then
		-- rate apres le niveau 5 : tout est a refaire
		b.reps, b.periode, b.largeur = 0, PERIODE0, ZONE0
		evenementBanc:FireServer("zero")
		texteBarres.Text = "BARRES : 0"
		texteResultat.Text = "RATE ! RETOUR A ZERO"
		texteResultat.TextColor3 = Color3.fromRGB(255, 70, 50)
		nouvelleZone(b)
		b.bloque = os.clock() + PENALITE * 2
	else
		texteResultat.Text = "RATE !"
		texteResultat.TextColor3 = Color3.fromRGB(255, 70, 50)
		b.bloque = os.clock() + PENALITE
	end
	b.finResultat = os.clock() + 0.9
end)

local function poserBanc(perso, dt)
	local b = banc
	local hum = perso:FindFirstChildOfClass("Humanoid")
	if perso ~= b.perso or not hum or hum.Health <= 0 or not b.modele:IsDescendantOf(workspace) then finirBanc() return end
	-- le curseur : un aller-retour par periode (0 en bas, 1 en haut)
	b.phase = (b.phase + dt / b.periode) % 1
	b.curseur = b.phase < 0.5 and b.phase * 2 or 2 - b.phase * 2
	curseur.Position = UDim2.fromScale(0.5, 1 - b.curseur)
	-- la barre arrive en bas : une nouvelle zone verte
	local enBas = b.modele:GetAttribute("EnBas") == true
	if enBas and not b.etaitEnBas then nouvelleZone(b) end
	if not enBas then b.attendre = false end
	b.etaitEnBas = enBas
	local pret = enBas and not b.attendre
	zoneB.BackgroundTransparency = pret and 0 or 0.7
	texteConsigne.Text = pret and "CLIQUE DANS LE VERT !" or "..."
	if os.clock() > b.finResultat then texteResultat.Text = "" end
	-- la pose : allonge, les mains sur la barre (le meme triangle)
	local j = jointsDe(perso)
	local UT = perso:FindFirstChild("UpperTorso")
	if not (j and UT and b.barre) then return end
	local animateur = hum:FindFirstChildOfClass("Animator")
	if animateur then
		for _, piste in ipairs(animateur:GetPlayingAnimationTracks()) do piste:Stop(0) end
	end
	local poignees = {}
	for _, p in ipairs(b.barre:GetChildren()) do
		if p.Name == "PoigneeBanc" then table.insert(poignees, p) end
	end
	for _, cote in ipairs({"Right", "Left"}) do
		local hautBras, avant, main = perso:FindFirstChild(cote .. "UpperArm"), perso:FindFirstChild(cote .. "LowerArm"), perso:FindFirstChild(cote .. "Hand")
		local epaule = UT[cote .. "ShoulderRigAttachment"]
		local poignee = nil
		for _, p in ipairs(poignees) do
			if not poignee or (p.Position - epaule.WorldPosition).Magnitude < (poignee.Position - epaule.WorldPosition).Magnitude then poignee = p end
		end
		if hautBras and avant and main and poignee then
			local vHaut = hautBras[cote .. "ElbowRigAttachment"].Position - hautBras[cote .. "ShoulderRigAttachment"].Position
			local vBas = (avant[cote .. "WristRigAttachment"].Position - avant[cote .. "ElbowRigAttachment"].Position)
				+ (main[cote .. "GripAttachment"].Position - main[cote .. "WristRigAttachment"].Position)
			local tHaut, tBas = triangle(UT.CFrame * j[cote .. "Shoulder"].base, epaule.WorldPosition,
				poignee.Position, longueurCote(vHaut), longueurCote(vBas), false)
			local s = tHaut - angleCote(vHaut)
			poserRad(j, cote .. "Shoulder", s)
			poserRad(j, cote .. "Elbow", tBas - s - angleCote(vBas))
		end
		-- les cuisses descendent du banc, les pieds a plat par terre
		poser(j, cote .. "Hip", -30)
		poser(j, cote .. "Knee", -60)
		poser(j, cote .. "Ankle", 0)
	end
	poser(j, "Waist", 0)
end

-- ---- LE RAMEUR : la course, et l animation de TOUS les rameurs ----
-- Chaque CLIC = un coup de rame (IMPULSION_CLIC). Avec le clavier : A/Q et D
-- (ou les fleches) en ALTERNANCE (IMPULSION). Attention : Roblox lit la PLACE
-- des touches (clavier anglais) : sur un clavier AZERTY, le "Q" est la touche A.
-- Le bateau ralentit tout seul (FREIN). Le coup de rame
-- (le siege qui glisse, le buste, les bras) avance d autant plus vite
-- qu on va vite. Un coup = 40 % de "tirage" rapide, 60 % de retour lent.
local IMPULSION, VMAX = 0.9, 9          -- m/s gagnes par coup (clavier) ; vitesse maxi
local IMPULSION_CLIC = 0.6              -- m/s gagnes par clic de souris
local FREIN_V, FREIN_0 = 0.35, 0.25     -- on perd 35 % de sa vitesse par seconde, plus 0,25 m/s
local evenementRameur = game:GetService("ReplicatedStorage"):WaitForChild("Rameur", 10)
local rameurs = {}       -- siege -> {pieces, phase}
local course = nil       -- MA course : {v, d, t0, derniere, fini, envoi}

local function trouverRameurs()
	for _, m in ipairs(salle:GetChildren()) do
		local siege = m.Name == "Rameur" and m:FindFirstChild("SiegeRameur")
		if siege and not rameurs[siege] then
			local plaques = {}
			for _, p in ipairs(m:GetChildren()) do
				if p.Name == "ReposePieds" then table.insert(plaques, p) end
			end
			rameurs[siege] = {modele = m, siege0 = siege.CFrame, poignee = m:FindFirstChild("PoigneeRameur"),
				chaine = m:FindFirstChild("ChaineRameur"), sortie = m:FindFirstChild("SortieChaine"),
				glisse = m:GetAttribute("Glisse") or 0.9, plaques = plaques, phase = 0, s = 1}
		end
	end
	for siege in pairs(rameurs) do
		if not siege:IsDescendantOf(workspace) then rameurs[siege] = nil end
	end
end
task.spawn(function()
	while true do trouverRameurs() task.wait(2) end      -- streaming : il arrive quand on s approche
end)

local guiR = Instance.new("ScreenGui")
guiR.Name = "CourseRameur"
guiR.ResetOnSpawn = false
guiR.Enabled = false
guiR.Parent = joueur:WaitForChild("PlayerGui")
local barreR = Instance.new("Frame")
barreR.AnchorPoint = Vector2.new(0.5, 0)
barreR.Position = UDim2.new(0.5, 0, 0, 70)
barreR.Size = UDim2.fromOffset(420, 22)
barreR.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
barreR.BorderSizePixel = 0
barreR.Parent = guiR
Instance.new("UICorner", barreR).CornerRadius = UDim.new(0, 8)
local avanceR = Instance.new("Frame")
avanceR.Size = UDim2.fromScale(0, 1)
avanceR.BackgroundColor3 = Color3.fromRGB(0, 225, 255)
avanceR.BorderSizePixel = 0
avanceR.Parent = barreR
Instance.new("UICorner", avanceR).CornerRadius = UDim.new(0, 8)
local function etiquetteR(y, h, couleur)
	local l = etiquette(UDim2.new(0.5, 260, 0, y), UDim2.fromOffset(520, h), "", couleur)
	l.Parent = guiR
	return l
end
local texteCourse  = etiquetteR(118, 36, Color3.new(1, 1, 1))
local texteConsR   = etiquetteR(160, 30, Color3.fromRGB(255, 205, 60))

local function nouvelleCourse()
	course = {v = 0, d = 0, t0 = nil, derniere = nil, fini = nil, envoi = 0}
end
UserInputService.InputBegan:Connect(function(entree)
	-- on ne regarde PAS "dejaPris" : Roblox prend D (marcher a droite) pour lui, et
	-- on ne recevait que Q. On ignore seulement ce qu on tape dans le chat.
	if not course or UserInputService:GetFocusedTextBox() then return end
	local k, genre = entree.KeyCode, entree.UserInputType
	local touche = (genre == Enum.UserInputType.MouseButton1 or genre == Enum.UserInputType.Touch) and "clic"
		or (k == Enum.KeyCode.Q or k == Enum.KeyCode.A or k == Enum.KeyCode.Left) and "G"
		or (k == Enum.KeyCode.D or k == Enum.KeyCode.Right) and "D" or nil
	if not touche then return end
	if course.fini then
		if os.clock() - course.fini > 2 then nouvelleCourse() end   -- on rejoue
		return
	end
	if touche == "clic" then
		course.v = math.min(VMAX, course.v + IMPULSION_CLIC)
	elseif touche ~= course.derniere then
		course.derniere = touche
		course.v = math.min(VMAX, course.v + IMPULSION)
	else
		return                                            -- deux fois la meme touche : rien
	end
	course.t0 = course.t0 or os.clock()                   -- le chrono part au premier coup
end)

-- la pose d un rameur, pour s (0 = jambes pliees, en avant ; 1 = fin du coup, en arriere)
local function poserRameur(perso, r)
	local j = jointsDe(perso)
	local hum = perso:FindFirstChildOfClass("Humanoid")
	local LT, UT = perso:FindFirstChild("LowerTorso"), perso:FindFirstChild("UpperTorso")
	if not (j and hum and LT and UT) then return end
	local animateur = hum:FindFirstChildOfClass("Animator")
	if animateur then
		for _, piste in ipairs(animateur:GetPlayingAnimationTracks()) do piste:Stop(0) end
	end
	poserRad(j, "Waist", math.rad(-25 + 40 * r.s))       -- penche en avant (-25) puis en arriere (+15)
	for _, cote in ipairs({"Right", "Left"}) do
		-- les jambes : la cheville au-dessus de la plaque du repose-pieds (le triangle)
		local cuisse, mollet, pied = perso:FindFirstChild(cote .. "UpperLeg"), perso:FindFirstChild(cote .. "LowerLeg"), perso:FindFirstChild(cote .. "Foot")
		local hanche = LT[cote .. "HipRigAttachment"]
		local plaque = nil
		for _, p in ipairs(r.plaques) do
			if not plaque or (p.Position - hanche.WorldPosition).Magnitude < (plaque.Position - hanche.WorldPosition).Magnitude then plaque = p end
		end
		if cuisse and mollet and pied and plaque then
			local a = (cuisse[cote .. "KneeRigAttachment"].Position - cuisse[cote .. "HipRigAttachment"].Position).Magnitude
			local b = (mollet[cote .. "AnkleRigAttachment"].Position - mollet[cote .. "KneeRigAttachment"].Position).Magnitude
			local h = (pied[cote .. "AnkleRigAttachment"].Position - pied[cote .. "FootAttachment"].Position).Magnitude
			local cible = plaque.Position + plaque.CFrame.UpVector * (plaque.Size.Y / 2 + h)
			local tCuisse, tMollet = triangle(LT.CFrame * j[cote .. "Hip"].base, hanche.WorldPosition, cible, a, b, true)
			poserRad(j, cote .. "Hip", tCuisse)
			poserRad(j, cote .. "Knee", tMollet - tCuisse)
			poserRad(j, cote .. "Ankle", -tMollet)
		end
		-- les bras : les mains sur la poignee
		local haut, avant, main = perso:FindFirstChild(cote .. "UpperArm"), perso:FindFirstChild(cote .. "LowerArm"), perso:FindFirstChild(cote .. "Hand")
		local g = r.modele:FindFirstChild(cote == "Right" and "PoigneeD" or "PoigneeG")
		if haut and avant and main and g then
			local vHaut = haut[cote .. "ElbowRigAttachment"].Position - haut[cote .. "ShoulderRigAttachment"].Position
			local vBas = (avant[cote .. "WristRigAttachment"].Position - avant[cote .. "ElbowRigAttachment"].Position)
				+ (main[cote .. "GripAttachment"].Position - main[cote .. "WristRigAttachment"].Position)
			local tHaut, tBas = triangle(UT.CFrame * j[cote .. "Shoulder"].base, UT[cote .. "ShoulderRigAttachment"].WorldPosition,
				g.Position, longueurCote(vHaut), longueurCote(vBas), false)
			local sh = tHaut - angleCote(vHaut)
			poserRad(j, cote .. "Shoulder", sh)
			poserRad(j, cote .. "Elbow", tBas - sh - angleCote(vBas))
		end
	end
end

local function lisse(x) return x * x * (3 - 2 * x) end
local function animerRameurs(dt, moi)
	local poses = {}
	for siege, r in pairs(rameurs) do
		local hum = siege.Occupant
		local perso = hum and hum.Parent
		local v = 0
		if perso and perso == moi and course then v = course.v
		elseif perso then v = siege:GetAttribute("Vitesse") or 0 end
		if perso then
			-- le coup de rame avance plus vite quand on va vite
			r.phase = (r.phase + dt * (0.15 + v * 0.11)) % 1
			local p = r.phase
			r.s = p < 0.4 and lisse(p / 0.4) or 1 - lisse((p - 0.4) / 0.6)
		else
			r.phase, r.s = 0, 1
		end
		-- le siege glisse (-Z = vers les pieds), la poignee suit les bras, la chaine s etire
		local seatZ = -r.glisse * (1 - r.s)
		siege.CFrame = r.siege0 * CFrame.new(0, 0, seatZ)
		if r.poignee then
			local pos = r.siege0 * Vector3.new(0, 1.05 + 0.1 * r.s, seatZ - (0.45 + 0.75 * (1 - r.s)))
			if not perso then pos = r.sortie.Position + (r.siege0.LookVector * -0.3) end          -- au repos, contre le volant
			r.poignee.CFrame = r.siege0.Rotation + pos
			if r.chaine and r.sortie then
				local a, b = r.sortie.Position, pos
				r.chaine.Size = Vector3.new(0.05, 0.05, math.max(0.05, (b - a).Magnitude))
				r.chaine.CFrame = CFrame.lookAt((a + b) / 2, b)
			end
		end
		if perso then
			poserRameur(perso, r)
			poses[perso] = true
		end
	end
	return poses
end

-- MA course : la vitesse, la distance, le chrono, l ecran
local function majCourse(dt, perso)
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local assis = hum and hum.SeatPart and hum.SeatPart.Name == "SiegeRameur" and hum.SeatPart or nil
	if assis and not course then nouvelleCourse() end
	if not assis then course = nil guiR.Enabled = false return end
	guiR.Enabled = true
	local c = course
	local distance = assis.Parent:GetAttribute("Distance") or 250
	c.v = math.max(0, c.v - (FREIN_V * c.v + FREIN_0) * dt)
	if not c.fini then c.d = math.min(distance, c.d + c.v * dt) end
	local temps = c.t0 and ((c.fini or os.clock()) - c.t0) or 0
	if c.d >= distance and not c.fini then
		c.fini = os.clock()
		temps = c.fini - c.t0
		if evenementRameur then evenementRameur:FireServer("arrivee", temps) end
	end
	avanceR.Size = UDim2.fromScale(c.d / distance, 1)
	texteCourse.Text = string.format("%d / %d m   ·   %d:%05.2f   ·   %.1f m/s", math.floor(c.d), distance, temps // 60, temps % 60, c.v)
	texteConsR.Text = c.fini and "ARRIVEE ! (clique pour rejouer, Espace pour descendre)" or (c.t0 and "CLIQUE le plus vite possible !" or "Clique pour partir !")
	c.envoi += dt
	if c.envoi > 0.25 and evenementRameur then
		c.envoi = 0
		evenementRameur:FireServer("vitesse", c.v)
	end
end

-- ---- MOI : le sac ----
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

-- ---- MOI : les halteres ----
-- On tient l outil "Halteres" (pris au ratelier). Chaque clic = un curl :
-- un bras se plie puis redescend, droite puis gauche. La duree d un curl
-- est un attribut de l outil (plus long quand c est lourd).
local curl = nil       -- {bras, t0, duree}
local brasCurl = "Left"
local nbCurls = 0
local guiH = Instance.new("ScreenGui")
guiH.Name = "CompteurHalteres"
guiH.ResetOnSpawn = false
guiH.Enabled = false
guiH.Parent = joueur:WaitForChild("PlayerGui")
local texteCurls = etiquette(UDim2.new(0.5, 150, 1, -110), UDim2.fromOffset(300, 40), "", Color3.new(1, 1, 1))
texteCurls.Parent = guiH
local branches = setmetatable({}, {__mode = "k"})     -- les outils deja branches
local function brancher(outil)
	if branches[outil] or not (outil:IsA("Tool") and outil.Name == "Halteres") then return end
	branches[outil] = true
	nbCurls = 0
	outil.Activated:Connect(function()
		if curl then return end                         -- on attend que le curl d avant soit fini
		brasCurl = (brasCurl == "Left") and "Right" or "Left"
		curl = {bras = brasCurl, t0 = os.clock(), duree = outil:GetAttribute("Duree") or 0.8}
		nbCurls += 1
	end)
end
local function surveiller(perso)
	perso.ChildAdded:Connect(brancher)
	for _, c in ipairs(perso:GetChildren()) do brancher(c) end
end
if joueur.Character then surveiller(joueur.Character) end
joueur.CharacterAdded:Connect(surveiller)

local surLeVelo = {}     -- perso -> true : ceux qu on a poses sur un velo a l image d avant

RunService.RenderStepped:Connect(function(dt)
	for _, t in pairs(tapis) do defiler(t, dt) end

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
	-- LES RAMEURS : le siege glisse, la poignee et la chaine bougent, on pose le rameur
	for perso in pairs(animerRameurs(dt, joueur.Character)) do vus[perso] = true end
	majCourse(dt, joueur.Character)
	for perso in pairs(surLeVelo) do
		if not vus[perso] then relacher(perso) end
	end
	surLeVelo = vus

	-- MOI : a la barre de traction, au banc, ou au sac
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local j = perso and jointsDe(perso)
	if traction then if perso then poserTraction(perso, dt) else finirTraction() end return end
	if banc then if perso then poserBanc(perso, dt) else finirBanc() end return end
	if not hum or not j or vus[perso] then return end
	-- par defaut : rien (on remet tout comme l animation de Roblox le fait)
	local epD, epG, coD, coG = 0, 0, 0, 0
	if coup then
		local k = (os.clock() - coup.t0) / DUREE_COUP
		if k >= 1 then
			coup = nil
		else
			local bosse = math.sin(math.pi * k)    -- 0 -> 1 -> 0 : le bras part et revient
			if coup.bras == "Right" then epD, coD = 90 * bosse, -10 * bosse else epG, coG = 90 * bosse, -10 * bosse end
		end
	end
	-- les halteres en main : les curls
	local outil = perso:FindFirstChild("Halteres")
	guiH.Enabled = outil ~= nil
	if outil then
		texteCurls.Text = string.format("CURLS : %d · %d kg", nbCurls, outil:GetAttribute("Poids") or 0)
		if curl then
			local k = (os.clock() - curl.t0) / curl.duree
			if k >= 1 then
				curl = nil
			else
				local bosse = math.sin(math.pi * k)    -- 0 -> 1 -> 0 : l avant-bras monte et redescend
				if curl.bras == "Right" then epD, coD = 15 * bosse, 130 * bosse else epG, coG = 15 * bosse, 130 * bosse end
			end
		end
	else
		curl = nil
	end
	poser(j, "RightShoulder", epD) poser(j, "LeftShoulder", epG)
	poser(j, "RightElbow", coD) poser(j, "LeftElbow", coG)
end)
