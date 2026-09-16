-- =========================================================
--  LES PIQUES DU TREMPLIN          (mon premier script Luau)
--  A placer dans ServerScriptService (ou dans Workspace).
--
--  Si on rate le saut et qu'on tombe dans la fosse, on meurt.
--
--  POURQUOI PAS "Touched" ?
--  On a essaye : ca ne marche pas ici.  Les piques et la zone
--  sont en CanCollide = false (on les traverse), et Touched se
--  declenche mal sur une piece qu'on traverse -- on peut tomber
--  au milieu de la fosse sans que rien ne se passe.
--  On regarde donc la POSITION du joueur a chaque image.
-- =========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local piques = workspace.Circuit.Piques
local zone = piques:WaitForChild("ZoneDeMort")

-- Ce point est-il a l'interieur de la boite "zone" ?
-- PointToObjectSpace donne la position du point VU PAR la zone :
-- si les trois coordonnees sont plus petites que la demi-taille,
-- c'est qu'on est dedans.
local function dansLaZone(pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return  math.abs(rel.X) <= zone.Size.X / 2
	    and math.abs(rel.Y) <= zone.Size.Y / 2
	    and math.abs(rel.Z) <= zone.Size.Z / 2
end

-- Heartbeat = "a chaque image du jeu", environ 60 fois par seconde.
RunService.Heartbeat:Connect(function()
	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		if perso then
			local corps = perso:FindFirstChild("HumanoidRootPart")
			local vie   = perso:FindFirstChildOfClass("Humanoid")
			-- En voiture, le corps du joueur suit la voiture :
			-- ce seul test couvre donc aussi le cas de la voiture.
			if corps and vie and vie.Health > 0 and dansLaZone(corps.Position) then
				vie.Health = 0
			end
		end
	end
end)

print("Fosse a piques active - zone de", math.floor(zone.Size.X),
	"x", math.floor(zone.Size.Y), "x", math.floor(zone.Size.Z))
