-- =========================================================
--  LES MOUVEMENTS DES EXERCICES  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Roblox ne sait pas faire "pousser une barre" ou "pedaler" : on plie
--  nous-memes les articulations du personnage, a chaque image, PAR-DESSUS
--  ses animations normales (on tourne l Attachment0 des AnimationConstraint,
--  comme pour les PNJ des bureaux).
--    BANC   les bras poussent la barre, en meme temps qu elle monte
--    VELO   les jambes pedalent
--    SAC    a chaque coup ("Frapper"), un bras part en avant, gauche puis droit
--  (Ces mouvements se voient sur NOTRE ecran.)
-- =========================================================

local Players                = game:GetService("Players")
local RunService             = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local DUREE_COUP = 0.32      -- un coup de poing dure 0,32 s (aller-retour)

local joueur = Players.LocalPlayer
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")

local joints = {}            -- nom -> {a = Attachment0, base = sa position de depart}
local function preparer(perso)
	joints = {}
	for _, j in ipairs({{"RightUpperArm", "RightShoulder"}, {"LeftUpperArm", "LeftShoulder"},
		{"RightLowerArm", "RightElbow"}, {"LeftLowerArm", "LeftElbow"},
		{"RightUpperLeg", "RightHip"}, {"LeftUpperLeg", "LeftHip"},
		{"RightLowerLeg", "RightKnee"}, {"LeftLowerLeg", "LeftKnee"}}) do
		local piece = perso:WaitForChild(j[1], 10)
		local c = piece and piece:WaitForChild(j[2], 10)
		if c and c:IsA("AnimationConstraint") and c.Attachment0 then
			joints[j[2]] = {a = c.Attachment0, base = c.Attachment0.CFrame}
		end
	end
end
if joueur.Character then task.spawn(preparer, joueur.Character) end
joueur.CharacterAdded:Connect(preparer)

local function poser(nom, x, y, z)
	local j = joints[nom]
	if j then j.a.CFrame = j.base * CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end
end

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

RunService.RenderStepped:Connect(function()
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	if not hum or not next(joints) then return end
	local siege = hum.SeatPart
	local t = os.clock()
	-- par defaut : rien (on remet tout comme l animation de Roblox le fait)
	local epD, epG, coD, coG, hD, hG, gD, gG = 0, 0, 0, 0, 0, 0, 0, 0

	if not barre then barre = salle:FindFirstChild("Barre") end
	if barre then yBarreRepos = math.min(yBarreRepos, barre.Position.Y) end
	if siege and siege.Name == "BancMuscu" and barre then
		-- s = 0 barre en bas, 1 barre en haut (elle monte de 1,4 stud)
		local s = math.clamp((barre.Position.Y - yBarreRepos) / 1.4, 0, 1)
		epD, epG = 55 + 45 * s, 55 + 45 * s      -- les bras montent devant
		coD, coG = 80 * (1 - s), 80 * (1 - s)    -- les coudes se tendent en haut
	elseif siege and siege.Name == "VeloSport" then
		local p = t * 7                            -- la vitesse du pedalage
		hD, hG = 18 * math.sin(p), 18 * math.sin(p + math.pi)
		gD, gG = -22 * math.sin(p + math.pi / 2), -22 * math.sin(p + math.pi * 1.5)
	end
	if coup then
		local k = (t - coup.t0) / DUREE_COUP
		if k >= 1 then
			coup = nil
		else
			local bosse = math.sin(math.pi * k)    -- 0 -> 1 -> 0 : le bras part et revient
			if coup.bras == "Right" then epD, coD = 90 * bosse, -10 * bosse else epG, coG = 90 * bosse, -10 * bosse end
		end
	end
	poser("RightShoulder", epD) poser("LeftShoulder", epG)
	poser("RightElbow", coD) poser("LeftElbow", coG)
	poser("RightHip", hD) poser("LeftHip", hG)
	poser("RightKnee", gD) poser("LeftKnee", gG)
end)
