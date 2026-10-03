-- =========================================================
--  LES PORTES COULISSANTES (des batiments du spawn)
--  A placer dans ServerScriptService.
--
--  Quand un joueur approche, les deux panneaux s ecartent et
--  rentrent dans le mur ; quand plus personne n est pres, ils
--  se referment.
--
--  Les portes sont posees par le generateur scripts/ZoneSpawn.lua
--  (des modeles "PorteCoulissante" dans Workspace > ZoneSpawn).
--  Ce script ne calcule AUCUNE position : le generateur a ecrit
--  sur chaque piece qui bouge deux attributs, "Ferme" et
--  "Ouvert" (des CFrame), et sur la porte son "Centre".
-- =========================================================

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DETECTION = 12     -- studs : a cette distance du centre de la porte, elle s ouvre
local DUREE     = 0.45   -- secondes pour s ouvrir ou se fermer
local mouvement = TweenInfo.new(DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ouverte = {}       -- ouverte[porte] = true quand elle est ouverte

-- Quelqu un est-il pres de ce point ?
local function quelquUnPres(centre)
	for _, joueur in ipairs(Players:GetPlayers()) do
		local corps = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		if corps and (corps.Position - centre).Magnitude < DETECTION then
			return true
		end
	end
	return false
end

-- 10 fois par seconde, ca suffit pour une porte (pas besoin de 60).
while true do
	task.wait(0.1)
	local zone = workspace:FindFirstChild("ZoneSpawn")
	if zone then
		for _, porte in ipairs(zone:GetChildren()) do
			local centre = porte:GetAttribute("Centre")
			if porte.Name == "PorteCoulissante" and centre then
				local pres = quelquUnPres(centre)
				-- on ne lance le mouvement qu au CHANGEMENT (fermee -> ouverte
				-- ou l inverse), pas a chaque tour de boucle
				if pres ~= (ouverte[porte] == true) then
					ouverte[porte] = pres
					for _, piece in ipairs(porte:GetChildren()) do
						local cible = piece:GetAttribute(pres and "Ouvert" or "Ferme")
						if cible then
							TweenService:Create(piece, mouvement, {CFrame = cible}):Play()
						end
					end
				end
			end
		end
	end
end
