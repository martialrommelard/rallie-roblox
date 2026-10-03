-- =========================================================
--  LA ZONE DE CHUTE, DERRIERE LES GRADINS
--  A placer dans ServerScriptService.
--
--  Si on tombe des gradins par l arriere, sur l herbe, on meurt :
--  Roblox fait reapparaitre le joueur au SpawnLocation.
--  La zone (une boite invisible "ZoneChute") est posee par le
--  generateur scripts/ZoneSpawn.lua, dans Workspace > ZoneSpawn.
--
--  Meme methode que la fosse a piques : pas de Touched (peu fiable
--  sur une piece qu on traverse), on regarde la POSITION du joueur
--  a chaque image.
-- =========================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local zoneSpawn = workspace:WaitForChild("ZoneSpawn")

-- Ce point est-il a l interieur de la boite ?
-- PointToObjectSpace donne le point VU PAR la boite : il est dedans si
-- ses trois coordonnees sont plus petites que la demi-taille.
local function dedans(boite, pos)
	local rel = boite.CFrame:PointToObjectSpace(pos)
	return  math.abs(rel.X) <= boite.Size.X / 2
	    and math.abs(rel.Y) <= boite.Size.Y / 2
	    and math.abs(rel.Z) <= boite.Size.Z / 2
end

RunService.Heartbeat:Connect(function()
	-- on relit les zones a chaque fois : si on relance le generateur,
	-- l ancienne boite est detruite et une nouvelle la remplace.
	local zones = {}
	for _, p in ipairs(zoneSpawn:GetChildren()) do
		if p.Name == "ZoneChute" then table.insert(zones, p) end
	end

	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local corps = perso and perso:FindFirstChild("HumanoidRootPart")
		local vie   = perso and perso:FindFirstChildOfClass("Humanoid")
		if corps and vie and vie.Health > 0 then
			for _, z in ipairs(zones) do
				if dedans(z, corps.Position) then
					vie.Health = 0
					print(joueur.Name .. " est tombe des gradins")
					break
				end
			end
		end
	end
end)
