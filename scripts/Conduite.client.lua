-- ============================================================
--  CONDUIRE (chez le joueur)
--  LocalScript a placer dans StarterPlayer > StarterPlayerScripts.
--
--  Quand je m assois au volant de notre voiture de rally, Roblox donne a
--  MON ordinateur le controle de sa physique. Alors c est ici, a chaque
--  image, qu on la conduit (module PiloteRally) : elle repond tout de
--  suite a mes touches, sans attendre le serveur.
--  Les touches : celles du VehicleSeat de Roblox (Z/S ou fleches pour
--  avancer / freiner, Q/D pour tourner ; sur AZERTY Roblox lit la PLACE
--  des touches, ca marche donc tout seul).
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pilote = require(ReplicatedStorage:WaitForChild("PiloteRally"))
local joueur = Players.LocalPlayer

RunService.Heartbeat:Connect(function(dt)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = hum and hum.SeatPart
	-- assis au volant d une voiture de rally ? (elle a un Chassis)
	if siege and siege.Name == "DriveSeat" and siege:IsA("VehicleSeat") and siege.Parent:FindFirstChild("Chassis") then
		Pilote.piloter(siege.Parent, siege.ThrottleFloat, siege.SteerFloat, dt, true)
	end
end)
