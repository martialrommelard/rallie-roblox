-- =========================================================
--  MOINS DE LUMIERE SUR LE SPAWN  (LocalScript : chez le joueur)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Le spawn est eclaire par le SOLEIL, comme tout le circuit : le baisser
--  pour tout le jeu assombrirait aussi la piste (on ne veut pas). Alors
--  c est l ecran du joueur qui baisse l exposition (ExposureCompensation)
--  quand il est sur le spawn ou dans ses escaliers, en douceur, et la remet
--  comme avant quand il en sort. (Ce qu un LocalScript change dans Lighting
--  ne change que pour LUI.)
-- =========================================================

local Players      = game:GetService("Players")
local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local SOMBRE = -0.5      -- de combien on baisse sur le spawn (0 = rien, -1 = tres sombre)
local FONDU  = 1.5       -- secondes pour passer de l un a l autre, en douceur

local joueur = Players.LocalPlayer
local zone = workspace:WaitForChild("ZoneSpawn")
local normale = Lighting.ExposureCompensation      -- l exposition du jeu, qu on remet en sortant

-- la boite du spawn et celle des escaliers : DEMANDEES aux pieces
local function boite(noms, enPlus)
	local a, b = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(zone:GetChildren()) do
		if p:IsA("BasePart") and noms[p.Name] then
			a = a:Min(p.Position - p.Size / 2)
			b = b:Max(p.Position + p.Size / 2)
		end
	end
	return a - enPlus, b + enPlus
end
local spawnA, spawnB = boite({Sol = true, Gradin = true}, Vector3.new(30, 0, 30))   -- le demi-rond et les gradins
local escA, escB = boite({Marche = true}, Vector3.new(0, 0, 0))
local ySpawn = zone:WaitForChild("SpawnLocation").Position.Y

local function dans(p, a, b)
	return p.X > a.X and p.X < b.X and p.Z > a.Z and p.Z < b.Z and p.Y > a.Y and p.Y < b.Y
end

local actuel = nil
while true do
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local ici = false
	if racine then
		local p = racine.Position
		-- sur le spawn : dans sa boite, AU-DESSUS du plancher (la salle du dessous garde sa lumiere)
		local surSpawn = p.X > spawnA.X and p.X < spawnB.X and p.Z > spawnA.Z and p.Z < spawnB.Z
			and p.Y > ySpawn - 3 and p.Y < ySpawn + 120
		local escalier = dans(p, escA, escB + Vector3.new(0, 12, 0))
		ici = surSpawn or escalier
	end
	if ici ~= actuel then
		actuel = ici
		TweenService:Create(Lighting, TweenInfo.new(FONDU), {ExposureCompensation = ici and (normale + SOMBRE) or normale}):Play()
	end
	task.wait(0.4)
end
