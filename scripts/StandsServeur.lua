-- ============================================================
--  LES STANDS (serveur)
--  A placer dans ServerScriptService. Le decor (la voie, les 6
--  ecuries, les zones d arret) est pose par le generateur Stands.lua.
--
--  1. LE LIMITEUR : dans la voie des stands, la vitesse est limitee
--     (attribut "Limiteur" sur la voiture : le module PiloteRally le lit).
--  2. LA REPARATION : ta voiture ARRETEE dans la zone de SON ecurie (son
--     numero) se repare un peu, tant que tu restes : chaque seconde, le
--     script Degats remet un morceau tombe (les roues d abord), ou rend
--     des PV aux morceaux abimes (jusqu a 80 : le garage, lui, remet a
--     neuf). Tu repars quand tu veux.
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local LIMITEUR = 40     -- studs/s dans la voie des stands
local ARRET    = 5      -- en dessous de 5 studs/s, on est arrete (avant : 3, trop dur)
local CADENCE  = 1      -- une etape de reparation par seconde

local JAUNE = Color3.fromRGB(255, 205, 60)
local VERT  = Color3.fromRGB(90, 230, 120)

local circuit = workspace:WaitForChild("Circuit")
local stands  = circuit:WaitForChild("Stands", 30)
local dossier = workspace:WaitForChild("Voitures")
local info    = ReplicatedStorage:WaitForChild("InfoCourse")
-- le script Degats fait la reparation (c est lui qui connait les morceaux)
local reparer = ServerStorage:WaitForChild("ReparationStand")

if not stands then
	warn("Stands : pas de voie des stands (lancer le generateur scripts/Stands.lua)")
	return
end

-- les zones d arret, par numero d ecurie
local zones = {}
for _, z in ipairs(stands:GetChildren()) do
	if z.Name == "ZoneArret" then zones[z:GetAttribute("Numero")] = z end
end

-- Est-on dans les stands ? Le sol juste sous la voiture fait partie de Stands.
local rayon = RaycastParams.new()
rayon.FilterType = Enum.RaycastFilterType.Include
rayon.FilterDescendantsInstances = {stands, circuit:WaitForChild("Route")}
local function dansLesStands(chassis)
	local hit = workspace:Raycast(chassis.Position, Vector3.new(0, -6, 0), rayon)
	return hit ~= nil and hit.Instance:IsDescendantOf(stands)
end

local function dedans(zone, position)
	local l = zone.CFrame:PointToObjectSpace(position)
	return math.abs(l.X) < zone.Size.X / 2 and math.abs(l.Z) < zone.Size.Z / 2 and math.abs(l.Y) < zone.Size.Y / 2
end

local etat = {}   -- [voiture] = {stands = vrai/faux, derniere = heure de la derniere reparation, prevenu}

while true do
	task.wait(0.25)
	for _, voiture in ipairs(dossier:GetChildren()) do
		local chassis = voiture:FindFirstChild("Chassis")
		local siege = voiture:FindFirstChild("DriveSeat")
		local hum = siege and siege.Occupant
		local joueur = hum and Players:GetPlayerFromCharacter(hum.Parent)
		if chassis then
			local e = etat[voiture] or {}
			etat[voiture] = e
			local numero = tonumber(voiture.Name:match("%d+"))

			-- 1. LE LIMITEUR
			local auxStands = dansLesStands(chassis)
			voiture:SetAttribute("Limiteur", auxStands and LIMITEUR or nil)
			if auxStands and not e.stands and joueur then
				info:FireClient(joueur, "🔧 STANDS — limiteur " .. LIMITEUR .. " — arrête-toi à l'écurie n°" .. tostring(numero), JAUNE, 4)
			end
			e.stands = auxStands

			-- 2. LA REPARATION (arrete dans SA zone, pendant une course)
			local zone = zones[numero]
			local arretee = chassis.AssemblyLinearVelocity.Magnitude < ARRET
			if zone and joueur and arretee and dedans(zone, chassis.Position)
				and workspace:GetAttribute("CourseEnCours") then
				if os.clock() - (e.derniere or 0) >= CADENCE then
					e.derniere = os.clock()
					local resultat, nom = reparer:Invoke(voiture)
					if resultat == "remis" then
						info:FireClient(joueur, "🔩 " .. nom .. " remis(e) en place", VERT, 1.5)
						e.prevenu = false
					elseif resultat == "soigne" then
						info:FireClient(joueur, string.format("🔧 Réparation... %d %%", math.floor(voiture:GetAttribute("Etat") or 0)), JAUNE, 1.2)
						e.prevenu = false
					elseif resultat == "fini" and not e.prevenu then
						info:FireClient(joueur, "✅ Réparée autant que possible aux stands : repars !", VERT, 2.5)
						e.prevenu = true
					end
				end
			end
		end
	end
	for voiture in pairs(etat) do
		if not voiture.Parent then etat[voiture] = nil end
	end
end
