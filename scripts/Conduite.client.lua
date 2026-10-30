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

-- ---- LE POUVOIR "FEU" (le Dragon) : touche F, ou le bouton ----
-- C est le serveur (PouvoirsVoitures) qui decide si on peut cracher :
-- ici on ne fait qu envoyer la demande, et afficher l attente.
local UserInputService = game:GetService("UserInputService")
local pouvoir = ReplicatedStorage:WaitForChild("PouvoirVoiture", 30)
local ecran = Instance.new("ScreenGui")
ecran.Name = "PouvoirVoiture"
ecran.ResetOnSpawn = false
ecran.Enabled = false
ecran.Parent = joueur:WaitForChild("PlayerGui")
local bouton = Instance.new("TextButton")
bouton.AnchorPoint = Vector2.new(0.5, 1)
bouton.Position = UDim2.new(0.5, 0, 1, -110)
bouton.Size = UDim2.fromOffset(170, 46)
bouton.BackgroundColor3 = Color3.fromRGB(170, 40, 20)
bouton.TextColor3 = Color3.new(1, 1, 1)
bouton.Font = Enum.Font.GothamBlack
bouton.TextSize = 20
bouton.Text = "🔥 FEU  (F)"
bouton.Parent = ecran
Instance.new("UICorner", bouton).CornerRadius = UDim.new(0, 10)
local function cracher()
	if pouvoir and ecran.Enabled then pouvoir:FireServer("feu") end
end
bouton.Activated:Connect(cracher)
UserInputService.InputBegan:Connect(function(entree, pris)
	if not pris and entree.KeyCode == Enum.KeyCode.F then cracher() end
end)

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
	-- le bouton du feu : seulement au volant d un Dragon, pendant la course
	local dragon = maintenant and siege.Parent:GetAttribute("Pouvoir") == "Feu" and workspace:GetAttribute("CourseEnCours") == true
	ecran.Enabled = dragon
	if dragon then
		local reste = (siege.Parent:GetAttribute("Recharge") or 0) - workspace:GetServerTimeNow()
		bouton.Text = (reste > 0) and string.format("🔥 %d s", math.ceil(reste)) or "🔥 FEU  (F)"
		bouton.BackgroundColor3 = (reste > 0) and Color3.fromRGB(80, 60, 55) or Color3.fromRGB(170, 40, 20)
	end
end)
