-- =========================================================
--  LA MINIMAP  (LocalScript : elle tourne CHEZ LE JOUEUR)
--  A placer dans StarterPlayer > StarterPlayerScripts.
--
--  Le circuit vu de dessus, en bas a droite de l ecran, avec un
--  point par pilote : moi en gros point blanc, les autres en orange.
--  Elle ne s affiche que quand je suis dans une voiture.
--
--  Rien n est dessine a la main : chaque morceau de route est dessine
--  en petit, a l echelle, a sa place et dans son sens. La liste des
--  morceaux vient du SERVEUR (script CarteCircuit) : a cause du
--  streaming, cet ecran-ci ne connait au debut que la route proche.
--
--  monde (vu de dessus)        ecran
--     X  ->                     x ->
--     Z  |                      y |      (un Frame tourne de "Rotation"
--        v                        v       degres, dans le sens des aiguilles)
-- =========================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local joueur = Players.LocalPlayer

local TAILLE   = 160      -- la minimap fait 160 x 160 pixels (220 : trop grand)
local MARGE    = 8        -- pixels de vide autour du circuit
local CONTOUR  = 4        -- epaisseur du contour sombre autour de la piste (facon Mario Kart)
local NEON     = Color3.fromRGB(0, 225, 255)
local ORANGE   = Color3.fromRGB(255, 150, 40)

-- ---- LA CARTE, DEMANDEE AU SERVEUR ----
-- InvokeServer : on pose la question, et on ATTEND la reponse.
local donnees = game:GetService("ReplicatedStorage"):WaitForChild("CarteCircuit"):InvokeServer()

-- ---- L ECHELLE : le circuit doit tenir dans le carre ----
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, m in ipairs(donnees.morceaux) do
	minX, maxX = math.min(minX, m.x), math.max(maxX, m.x)
	minZ, maxZ = math.min(minZ, m.z), math.max(maxZ, m.z)
end
local echelle = (TAILLE - 2 * MARGE) / math.max(maxX - minX, maxZ - minZ)
-- on centre le circuit dans le carre
local decalX = (TAILLE - (maxX - minX) * echelle) / 2
local decalY = (TAILLE - (maxZ - minZ) * echelle) / 2

-- un point du monde -> un point de la minimap (en pixels)
local function versCarte(pos)
	return Vector2.new(decalX + (pos.X - minX) * echelle, decalY + (pos.Z - minZ) * echelle)
end

-- ---- LE CADRE ----
local gui = Instance.new("ScreenGui")
gui.Name = "Minimap"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

-- facon Mario Kart : PAS de fond, on ne voit que le trace de la piste
local carte = Instance.new("Frame")
carte.AnchorPoint = Vector2.new(1, 1)
carte.Position = UDim2.new(1, -20, 1, -20)
carte.Size = UDim2.fromOffset(TAILLE, TAILLE)
carte.BackgroundTransparency = 1
carte.Parent = gui

-- un trait : un Frame de la bonne longueur, tourne dans le bon sens
local function trait(centre, direction, longueur, epaisseur, couleur, z)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(centre.X, centre.Y)
	f.Size = UDim2.fromOffset(longueur, epaisseur)
	-- atan2(y, x) sur l ecran (y vers le bas) = l angle dans le sens des aiguilles
	f.Rotation = math.deg(math.atan2(direction.Y, direction.X))
	f.BackgroundColor3 = couleur
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = carte
	return f
end

-- ---- LE CIRCUIT ----
-- Deux couches, comme dans Mario Kart : d abord la piste en plus LARGE et
-- en sombre (le contour), puis par-dessus la piste claire. Le contour
-- ne depasse donc que sur les bords.
for _, m in ipairs(donnees.morceaux) do
	local centre, sens = versCarte(Vector3.new(m.x, 0, m.z)), Vector2.new(m.sx, m.sz)
	local largeur = math.max(3, m.larg * echelle)
	trait(centre, sens, m.long * echelle + 1 + CONTOUR, largeur + CONTOUR, Color3.fromRGB(20, 22, 30), 1)
	trait(centre, sens, m.long * echelle + 1, largeur, Color3.fromRGB(215, 220, 230), 2)
end
-- la ligne de depart, en blanc, en travers de la route
do
	local l = donnees.ligne
	trait(versCarte(Vector3.new(l.x, 0, l.z)), Vector2.new(l.sx, l.sz),
		l.long * echelle + 4, 3, Color3.fromRGB(255, 255, 255), 3)
end

-- ---- LES POINTS DES PILOTES ----
local points = {}      -- points[joueur] = le Frame de son point

local function pointDe(j)
	if points[j] then return points[j] end
	local moi = (j == joueur)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(moi and 12 or 9, moi and 12 or 9)
	f.BackgroundColor3 = moi and Color3.fromRGB(255, 255, 255) or ORANGE
	f.ZIndex = moi and 6 or 5          -- mon point passe par-dessus les autres
	f.Parent = carte
	local rond = Instance.new("UICorner")
	rond.CornerRadius = UDim.new(1, 0)
	rond.Parent = f
	-- un cercle autour de chaque point : il ressort sur n importe quel
	-- decor (il n y a plus de fond derriere la carte)
	local s = Instance.new("UIStroke")
	s.Color = moi and NEON or Color3.fromRGB(20, 22, 30)
	s.Thickness = 2
	s.Parent = f
	points[j] = f
	return f
end

Players.PlayerRemoving:Connect(function(j)
	if points[j] then points[j]:Destroy(); points[j] = nil end
end)

-- dans une voiture ? (le siege d une voiture est un VehicleSeat)
local function enVoiture(j)
	local h = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.SeatPart ~= nil and h.SeatPart:IsA("VehicleSeat")
end

RunService.RenderStepped:Connect(function()
	gui.Enabled = enVoiture(joueur)
	if not gui.Enabled then return end
	for _, j in ipairs(Players:GetPlayers()) do
		local corps = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
		local f = pointDe(j)
		if corps and enVoiture(j) then
			local p = versCarte(corps.Position)
			f.Position = UDim2.fromOffset(p.X, p.Y)
			f.Visible = true
		else
			f.Visible = false
		end
	end
end)
