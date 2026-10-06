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
--    TAPIS  les rayures de la bande defilent a la vitesse du tapis
--    BARRE  on s accroche ; chaque clic fait monter, la jauge redescend
--           de plus en plus vite : menton a la barre = une traction
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
	for perso in pairs(surLeVelo) do
		if not vus[perso] then relacher(perso) end
	end
	surLeVelo = vus

	-- MOI, sur le banc ou au sac
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local j = perso and jointsDe(perso)
	if traction then if perso then poserTraction(perso, dt) else finirTraction() end return end
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
