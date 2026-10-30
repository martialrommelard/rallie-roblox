-- ============================================================
--  LES SPECTATEURS QUI APPLAUDISSENT (chez le joueur)
--  LocalScript a placer dans StarterPlayer > StarterPlayerScripts.
--
--  Les spectateurs des gradins (poses par le generateur Spectateurs.lua)
--  sont du decor. Ici, chez chaque joueur, on les fait vivre :
--    - de temps en temps, l un d eux se leve un peu et LEVE LES BRAS ;
--    - PENDANT LA COURSE, beaucoup plus souvent... et encore plus quand
--      une voiture passe pres d eux ;
--    - les drapeaux s agitent.
--  C est fait chez le joueur (pas sur le serveur) : ca ne charge pas le
--  serveur, et c est plus fluide. On n anime QUE ceux qui applaudissent.
-- ============================================================

local RunService = game:GetService("RunService")

local CHANCE_CALME  = 0.004   -- chance par spectateur, a chaque tirage, hors course
local CHANCE_COURSE = 0.03    -- pendant la course
local CHANCE_VOITURE = 0.25   -- une voiture a moins de PRES studs
local PRES          = 140
local DUREE         = 1.4     -- secondes d applaudissement
local SAUT          = 0.6     -- ils se soulevent de 0.6 stud

local zone = workspace:WaitForChild("ZoneSpawn")
local dossier = zone:WaitForChild("Spectateurs", 60)
local voitures = workspace:WaitForChild("Voitures")
if not dossier then return end

-- ce qu on retient de chacun : ses pieces et leur place de depart
local fans = {}
local function connaitre(m)
	if not m:IsA("Model") then return end
	local torse = m:WaitForChild("Torse", 5)
	if not torse then return end
	local f = {modele = m, torse = torse, depart = {}, bras = {}, drapeau = nil, fin = 0}
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then f.depart[p] = p.CFrame end
		if p.Name == "Bras" then table.insert(f.bras, p) end
		if p.Name == "Drapeau" then f.drapeau = p end
	end
	table.insert(fans, f)
end
for _, m in ipairs(dossier:GetChildren()) do task.spawn(connaitre, m) end
dossier.ChildAdded:Connect(connaitre)      -- (avec le streaming, ils arrivent petit a petit)

local actifs = {}    -- [fan] = vrai pendant qu il applaudit

-- on pose chaque piece : "leve" = 0 (assis) a 1 (debout, bras en l air)
local function poser(f, leve, t)
	local hausse = CFrame.new(0, SAUT * leve, 0)
	for p, cf in pairs(f.depart) do
		if p.Parent then
			if p.Name == "Bras" then
				-- le bras tourne autour de l epaule (en haut du bras), vers le
				-- haut, et s agite un peu
				local epaule = cf * CFrame.new(0, p.Size.Y / 2 - 0.5, 0)
				local angle = math.rad(170 * leve + math.sin(t * 14 + (p:GetAttribute("Cote") or 0)) * 15 * leve)
				p.CFrame = hausse * epaule * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -(p.Size.Y / 2 - 0.5), 0)
			elseif p.Name == "Drapeau" or p.Name == "Hampe" then
				-- le drapeau se leve et se balance
				local balance = CFrame.Angles(0, 0, math.sin(t * 9) * 0.35 * leve)
				p.CFrame = hausse * CFrame.new(0, 1.2 * leve, 0) * f.depart[f.torse] * balance * f.depart[f.torse]:ToObjectSpace(cf)
			else
				p.CFrame = hausse * cf
			end
		end
	end
end

-- LE TIRAGE : qui se met a applaudir ?
local prochain = 0
RunService.Heartbeat:Connect(function()
	local maintenant = os.clock()
	if maintenant >= prochain then
		prochain = maintenant + 0.15
		local course = workspace:GetAttribute("CourseEnCours") == true
		-- ou sont les voitures ?
		local positions = {}
		for _, v in ipairs(voitures:GetChildren()) do
			local ch = v:FindFirstChild("Chassis")
			if ch then table.insert(positions, ch.Position) end
		end
		for _, f in ipairs(fans) do
			if not actifs[f] and f.torse.Parent then
				local chance = course and CHANCE_COURSE or CHANCE_CALME
				if course then
					for _, pos in ipairs(positions) do
						if (pos - f.depart[f.torse].Position).Magnitude < PRES then chance = CHANCE_VOITURE; break end
					end
				end
				if math.random() < chance then
					f.fin = maintenant + DUREE * (0.7 + math.random() * 0.6)
					f.debut = maintenant
					actifs[f] = true
				end
			end
		end
	end
	-- on anime ceux qui applaudissent
	for f in pairs(actifs) do
		local t = maintenant - f.debut
		local reste = f.fin - maintenant
		if reste <= 0 then
			poser(f, 0, 0)
			actifs[f] = nil
		else
			-- ils se levent vite, restent, puis se rassoient
			local leve = math.min(1, t / 0.2, reste / 0.3)
			poser(f, leve, t)
		end
	end
end)
