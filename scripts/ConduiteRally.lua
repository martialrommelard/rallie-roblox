-- ============================================================
--  LA CONDUITE DE NOTRE VOITURE DE RALLY (cote serveur)
--  Un Script range DANS la voiture. Le generateur VoitureRally.lua le
--  copie depuis ServerStorage/Outils/ConduiteRally.
--
--  Quand un joueur est au volant, c est SON ordinateur qui conduit
--  (LocalScript Conduite.client) : la voiture lui repond tout de suite.
--  Ce script-ci ne s occupe que :
--    - de la voiture SANS pilote (elle s arrete) et des ESSAIS : les
--      attributs "EssaiGaz" / "EssaiVolant" sur la voiture remplacent les
--      touches (pour tester sans joueur) ;
--    - de la remettre sur ses roues si elle est retournee.
--  La conduite elle-meme (moteurs, direction, aides) est dans le module
--  ReplicatedStorage.PiloteRally.
-- ============================================================

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pilote  = require(ReplicatedStorage:WaitForChild("PiloteRally"))
local voiture = script.Parent
local siege   = voiture:WaitForChild("DriveSeat")

-- le son du moteur : plus on va vite, plus il est aigu (le serveur le
-- regle : tout le monde l entend pareil)
local son = siege:FindFirstChild("SonMoteur")

RunService.Heartbeat:Connect(function(dt)
	local essaiGaz = voiture:GetAttribute("EssaiGaz")
	if essaiGaz or not siege.Occupant then
		Pilote.piloter(voiture, essaiGaz or 0, voiture:GetAttribute("EssaiVolant") or 0, dt, essaiGaz ~= nil)
	end
	if son then
		son.PlaybackSpeed = 0.6 + math.abs(Pilote.vitesse(voiture)) / 120 * 1.4
		son.Volume = siege.Occupant and 0.6 or 0
	end
end)

-- ---- SE REMETTRE SUR SES ROUES ----
-- Retournee (le toit vers le bas, ou sur le cote) et presque arretee
-- pendant 3 secondes : on la repose a l endroit, un peu plus haut.
local retourneeDepuis = nil
while true do
	task.wait(0.5)
	local penchee = siege.CFrame.UpVector.Y < 0.3
	local arretee = siege.AssemblyLinearVelocity.Magnitude < 6
	if siege.Occupant and penchee and arretee then
		retourneeDepuis = retourneeDepuis or os.clock()
		if os.clock() - retourneeDepuis > 3 then
			local regard = siege.CFrame.LookVector * Vector3.new(1, 0, 1)
			if regard.Magnitude < 0.1 then regard = Vector3.new(0, 0, -1) end
			local pos = voiture:GetPivot().Position + Vector3.new(0, 4, 0)
			voiture:PivotTo(CFrame.lookAt(pos, pos + regard.Unit))
			retourneeDepuis = nil
		end
	else
		retourneeDepuis = nil
	end
end
