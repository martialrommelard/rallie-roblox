-- ============================================================
--  LES POUVOIRS DES VOITURES (serveur)
--  A placer dans ServerScriptService.
--
--  Certaines carrosseries ont un POUVOIR (attribut "Pouvoir", pose par
--  le generateur CarrosseriesTheme.lua) :
--    - "Verglas" (la Givre) : quand elle roule vite, elle laisse derriere
--      elle des PLAQUES DE GLACE sur la route (elles fondent en quelques
--      secondes). Une autre voiture qui passe dessus GLISSE : on lui pose
--      l attribut "Glisse", et le module PiloteRally lui enleve son
--      adherence pendant un moment.
--    - "Feu" (le Dragon) : le pilote appuie sur F (ou le bouton de son
--      ecran, Conduite.client) -> il crache du FEU devant lui pendant
--      DUREE_FEU secondes. Les voitures dans la flamme s abiment (le
--      script Degats fait les degats : BindableEvent "AbimerVoiture").
--      Puis il faut attendre RECHARGE secondes.
--  Les pouvoirs ne marchent que PENDANT LA COURSE.
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

-- ---- LES REGLAGES ----
-- le verglas
local VITESSE_GLACE = 20     -- elle ne laisse de glace qu au-dessus de 20 studs/s
local COTE_GLACE    = 14     -- une plaque CARREE de 14 studs de cote (avant : un rond de 7)...
local ECART_GLACE   = 12     -- ...posee tous les 12 studs parcourus : une piste de glace continue
local VIE_GLACE     = 8      -- secondes avant qu elle fonde
local DUREE_GLISSE  = 1.2    -- on glisse encore 1.2 s apres etre passe dessus
-- le feu
local DUREE_FEU     = 1.5    -- secondes de flamme
local RECHARGE      = 8      -- secondes entre deux jets de feu
local PORTEE_FEU    = 55     -- la flamme va jusqu a 55 studs (avant : 30)...
local ANGLE_FEU     = 18     -- ...dans un cone de 18 degres
-- la flamme elle-meme (le ParticleEmitter "Feu" de la gueule) : on la
-- regle ICI, au lancement, pour que la portee qu on voit = celle qui brule
local VITESSE_FLAMME = NumberRange.new(60, 75)                     -- studs/s
local VIE_FLAMME     = NumberRange.new(0.7, 0.85)                  -- 70 x 0.78 = ~55 studs
local TAILLE_FLAMME  = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(0.5, 7), NumberSequenceKeypoint.new(1, 11)})
local PV_FEU        = 5      -- PV perdus a chaque brulure...
local CADENCE_FEU   = 0.35   -- ...toutes les 0.35 s (le script Degats ne compte pas plus vite)

local GLACE = Color3.fromRGB(190, 230, 255)
local ORANGE = Color3.fromRGB(255, 140, 40)

local voitures = workspace:WaitForChild("Voitures")
local info = ReplicatedStorage:WaitForChild("InfoCourse")

-- les objets des pouvoirs (les plaques de glace)
local dossier = workspace:FindFirstChild("Pouvoirs") or Instance.new("Folder")
dossier.Name = "Pouvoirs"
dossier:ClearAllChildren()
dossier.Parent = workspace

-- le bouton / la touche F des joueurs
local evt = ReplicatedStorage:FindFirstChild("PouvoirVoiture")
if not evt then
	evt = Instance.new("RemoteEvent")
	evt.Name = "PouvoirVoiture"
	evt.Parent = ReplicatedStorage
end
-- pour abimer une voiture (cree par le script Degats, ou ici s il manque)
local abimer = ServerStorage:FindFirstChild("AbimerVoiture")
if not abimer then
	abimer = Instance.new("BindableEvent")
	abimer.Name = "AbimerVoiture"
	abimer.Parent = ServerStorage
end

local function enCourse() return workspace:GetAttribute("CourseEnCours") == true end
local function piloteDe(voiture)
	local siege = voiture:FindFirstChild("DriveSeat")
	local hum = siege and siege.Occupant
	return hum and Players:GetPlayerFromCharacter(hum.Parent)
end

-- =========================================================
-- 1. LE VERGLAS
-- =========================================================
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Exclude
local plaques = {}          -- {cf (le centre et le sens du carre), de (la voiture qui l a posee), fin}
local derniere = {}         -- [voiture] = l endroit de sa derniere plaque
local glisse = {}           -- [voiture] = l heure ou elle arrete de glisser

local function poserGlace(voiture, chassis)
	-- sous l arriere de la voiture, sur la route
	local arriere = chassis.CFrame * Vector3.new(0, 0, chassis.Size.Z / 2 + 2)
	local ignores = {voitures, dossier, workspace:FindFirstChild("PiecesTombees")}
	for _, j in ipairs(Players:GetPlayers()) do
		if j.Character then table.insert(ignores, j.Character) end
	end
	rayon.FilterDescendantsInstances = ignores
	local sol = workspace:Raycast(arriere + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), rayon)
	if not sol then return false end               -- en plein saut : rien
	local p = Instance.new("Part")
	p.Name = "Verglas"
	p.Size = Vector3.new(COTE_GLACE, 0.15, COTE_GLACE)
	-- un CARRE a plat, colle au sol, dans le sens de la voiture
	-- (son "haut" = la normale du sol : il suit les pentes)
	local avant = chassis.CFrame.LookVector
	local cote = avant:Cross(sol.Normal).Unit
	p.CFrame = CFrame.fromMatrix(sol.Position + sol.Normal * 0.08, cote, sol.Normal)
	p.Color = GLACE
	p.Material = Enum.Material.Ice
	p.Transparency = 0.3
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false    -- (invisible pour les rayons : sortie de route, cameras...)
	p.CastShadow = false
	p.Parent = dossier
	Debris:AddItem(p, VIE_GLACE)
	table.insert(plaques, {cf = p.CFrame, de = voiture, fin = os.clock() + VIE_GLACE})
	return true
end

local prochain = 0
RunService.Heartbeat:Connect(function()
	if os.clock() < prochain then return end
	prochain = os.clock() + 0.1
	local maintenant = os.clock()
	-- les plaques fondues
	for i = #plaques, 1, -1 do
		if plaques[i].fin < maintenant then table.remove(plaques, i) end
	end
	if not enCourse() then
		if #plaques > 0 then plaques = {}; dossier:ClearAllChildren() end
	end
	for _, voiture in ipairs(voitures:GetChildren()) do
		local chassis = voiture:FindFirstChild("Chassis")
		if chassis then
			-- la Givre pose sa glace
			-- (une plaque tous les ECART_GLACE studs parcourus : elles se touchent)
			if voiture:GetAttribute("Pouvoir") == "Verglas" and enCourse() and piloteDe(voiture)
				and chassis.AssemblyLinearVelocity.Magnitude > VITESSE_GLACE
				and (not derniere[voiture] or (chassis.Position - derniere[voiture]).Magnitude > ECART_GLACE) then
				if poserGlace(voiture, chassis) then derniere[voiture] = chassis.Position end
			end
			-- les autres glissent dessus (le centre de la voiture DANS le carre)
			if voiture:GetAttribute("Pouvoir") ~= "Verglas" then
				for _, pl in ipairs(plaques) do
					local l = pl.cf:PointToObjectSpace(chassis.Position)
					if math.abs(l.X) < COTE_GLACE / 2 + 1 and math.abs(l.Z) < COTE_GLACE / 2 + 1 and math.abs(l.Y) < 5 then
						if not glisse[voiture] then
							local j = piloteDe(voiture)
							if j then info:FireClient(j, "❄️ Verglas ! Tu glisses...", GLACE, 1.5) end
						end
						glisse[voiture] = maintenant + DUREE_GLISSE
						break
					end
				end
			end
			local g = glisse[voiture] and glisse[voiture] > maintenant
			if not g then glisse[voiture] = nil end
			if (voiture:GetAttribute("Glisse") == true) ~= (g == true) then
				voiture:SetAttribute("Glisse", g or nil)
			end
		end
	end
end)

-- =========================================================
-- 2. LE FEU DU DRAGON
-- =========================================================
local function cracher(voiture, joueur)
	local gueule = voiture:FindFirstChild("Gueule")
	local feu = gueule and gueule:FindFirstChild("Feu")
	if not feu then return end
	voiture:SetAttribute("Recharge", workspace:GetServerTimeNow() + RECHARGE)   -- (l ecran du pilote affiche l attente)
	feu.Speed, feu.Lifetime, feu.Size = VITESSE_FLAMME, VIE_FLAMME, TAILLE_FLAMME
	feu.Rate = 200
	feu.SpreadAngle = Vector2.new(8, 8)
	feu.Enabled = true
	if gueule:FindFirstChild("Lueur") then gueule.Lueur.Enabled = true end
	local prevenus = {}
	local fin = os.clock() + DUREE_FEU
	while os.clock() < fin and gueule.Parent == voiture do
		local devant = gueule.CFrame.LookVector
		for _, autre in ipairs(voitures:GetChildren()) do
			local ch = autre ~= voiture and autre:FindFirstChild("Chassis")
			if ch then
				local vers = ch.Position - gueule.Position
				local angle = math.deg(math.acos(math.clamp(vers.Unit:Dot(devant), -1, 1)))
				if vers.Magnitude < PORTEE_FEU and angle < ANGLE_FEU then
					abimer:Fire(autre, gueule.Position, PV_FEU, "feu du dragon")
					local victime = piloteDe(autre)
					if victime and not prevenus[autre] then
						prevenus[autre] = true
						info:FireClient(victime, "🔥 Le Dragon te crache du feu dessus !", ORANGE, 2)
					end
				end
			end
		end
		task.wait(CADENCE_FEU)
	end
	if feu.Parent then feu.Enabled = false end
	if gueule:FindFirstChild("Lueur") then gueule.Lueur.Enabled = false end
end

evt.OnServerEvent:Connect(function(joueur, action)
	if action ~= "feu" or not enCourse() then return end
	-- c est bien LUI qui conduit un Dragon ? (le serveur verifie tout)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = hum and hum.SeatPart
	local voiture = siege and siege.Name == "DriveSeat" and siege.Parent
	if not (voiture and voiture.Parent == voitures and voiture:GetAttribute("Pouvoir") == "Feu") then return end
	if workspace:GetServerTimeNow() < (voiture:GetAttribute("Recharge") or 0) then return end
	task.spawn(cracher, voiture, joueur)
end)

voitures.ChildRemoved:Connect(function(voiture)
	derniere[voiture], glisse[voiture] = nil, nil
end)
