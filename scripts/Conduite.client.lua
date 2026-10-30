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

-- Mon personnage assis a GAUCHE alourdit ce cote de la voiture (mesure :
-- elle tournait 5 % moins bien a droite). Au volant, il ne pese plus rien
-- ("Massless") ; on lui rend son poids quand il descend.
local allege = {}
local function alleger(perso, oui)
	for _, p in ipairs(perso:GetDescendants()) do
		if p:IsA("BasePart") then
			if oui and not p.Massless then
				p.Massless = true
				allege[p] = true
			elseif not oui and allege[p] then
				p.Massless = false
			end
		end
	end
	if not oui then allege = {} end
end

local auVolant = false
RunService.Heartbeat:Connect(function(dt)
	local perso = joueur.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = hum and hum.SeatPart
	-- assis au volant d une voiture de rally ? (elle a un Chassis)
	local maintenant = siege ~= nil and siege.Name == "DriveSeat" and siege:IsA("VehicleSeat")
		and siege.Parent:FindFirstChild("Chassis") ~= nil
	if maintenant ~= auVolant and perso then
		alleger(perso, maintenant)
		auVolant = maintenant
	end
	if maintenant then
		Pilote.piloter(siege.Parent, siege.ThrottleFloat, siege.SteerFloat, dt, true)
	end
end)
