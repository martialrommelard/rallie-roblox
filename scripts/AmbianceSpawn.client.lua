-- =========================================================
--  L AMBIANCE DU SPAWN  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  1. La voiture d exposition tourne sur son socle. On la fait tourner
--     ICI, chez chaque joueur : 60 images par seconde, bien fluide, et
--     le serveur n a rien a envoyer.
--  2. La musique : les morceaux B puis D (de la bibliotheque de Roblox),
--     en boucle, avec un FONDU ENCHAINE (l un baisse pendant que l autre
--     monte). On ne l entend que dans le spawn ; elle se coupe en
--     douceur quand on monte en voiture.
-- =========================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local joueur = Players.LocalPlayer

local TOURS_PAR_MINUTE = 3            -- vitesse de rotation de la voiture
local MUSIQUES = {1846368080, 1839246711}   -- B puis D (choisies a l ecoute le 2026-10-03)
local VOLUME   = 0.35                 -- volume dans le spawn
local FONDU    = 3                    -- secondes du fondu enchaine
local DISTANCE = 110                  -- "dans le spawn" = a moins de 110 studs du point d apparition

-- ---- 1. LA VOITURE QUI TOURNE ----
local angle = 0
RunService.RenderStepped:Connect(function(dt)
	local zone = workspace:FindFirstChild("ZoneSpawn")
	local expo = zone and zone:FindFirstChild("VoitureExpo")
	local base = expo and expo:GetAttribute("Base")
	if base then
		angle += dt * TOURS_PAR_MINUTE * 2 * math.pi / 60
		expo:PivotTo(base * CFrame.Angles(0, angle, 0))
	end
end)

-- ---- 2. LA MUSIQUE ----
local sons = {}
for i, id in ipairs(MUSIQUES) do
	local s = Instance.new("Sound")
	s.Name = "MusiqueSpawn" .. i
	s.SoundId = "rbxassetid://" .. id
	s.Volume = 0
	s.Parent = SoundService            -- un son "partout" (pas dans le monde)
	sons[i] = s
end

-- Suis-je dans le spawn, a pied ?
local function dansLeSpawn()
	local perso = joueur.Character
	local corps = perso and perso:FindFirstChild("HumanoidRootPart")
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not (corps and humanoide and spawn) then return false end
	if humanoide.SeatPart and humanoide.SeatPart:IsA("VehicleSeat") then return false end
	local d = corps.Position - spawn.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude < DISTANCE and math.abs(d.Y) < 40
end

local actuel = 1          -- le morceau qui joue
local fonduDepuis = nil   -- l heure du debut du fondu (nil = pas de fondu en cours)
local volume = 0          -- le volume "general", qui suit dansLeSpawn() en douceur
sons[actuel]:Play()

RunService.Heartbeat:Connect(function(dt)
	-- le volume monte ou descend en douceur (environ 1 seconde)
	local cible = dansLeSpawn() and VOLUME or 0
	volume += (cible - volume) * math.min(1, dt * 1.5)

	local s = sons[actuel]
	local suivant = sons[actuel % #sons + 1]
	if not fonduDepuis then
		s.Volume = volume
		-- bientot la fin du morceau : on lance le suivant, et le fondu
		if s.TimeLength > 0 and s.TimeLength - s.TimePosition < FONDU then
			fonduDepuis = os.clock()
			suivant.TimePosition = 0
			suivant:Play()
		end
	else
		local f = math.min(1, (os.clock() - fonduDepuis) / FONDU)
		s.Volume = volume * (1 - f)
		suivant.Volume = volume * f
		if f >= 1 then
			s:Stop()
			actuel = actuel % #sons + 1
			fonduDepuis = nil
		end
	end
end)
