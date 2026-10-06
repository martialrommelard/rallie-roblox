-- =========================================================
--  LES BARRES DE TRACTION  (a lancer UNE fois, dans Studio, en Edit, APRES
--  SalleSport.lua). Sur la moquette de l ancien coin des simulateurs, a cote
--  de la salle de sport : un portique par position de POSITIONS (2 montants,
--  une poutre), la barre avec ses poignees en mousse, un tapis de sol et un
--  panneau des records.
--
--  On s y accroche (touche E) ; une JAUGE apparait : chaque CLIC fait
--  monter, et la jauge redescend toute seule, d autant plus vite qu on est
--  haut (et qu on a deja fait de tractions). Menton au-dessus de la barre =
--  une traction. C est le LocalScript Exercices qui fait tout ca ; le
--  serveur (SalleSportServeur) compte et garde le record.
--
--  La hauteur de la barre est DEDUITE de mon avatar : bras tendus, les pieds
--  doivent pendre a PIEDS_SOL du sol.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")
local sol = salle:WaitForChild("MoquetteSimu")     -- la moquette de l ancien coin des simulateurs

-- ---- OU : dans le repere de la moquette (son milieu = 0, 0) : contre le mur du fond (+Z),
--      de chaque cote du rameur, tournees vers la salle ----
local POSITIONS = {Vector3.new(-6, 0, 12), Vector3.new(6, 0, 12)}

-- ---- LE PILOTE (mesure sur mon avatar, en studs, depuis le HumanoidRootPart) ----
local RACINE_PIEDS = 3.0     -- du HumanoidRootPart a la semelle
local RACINE_MAINS = 2.25    -- du HumanoidRootPart aux mains, bras tendus en l air
local MAINS_X      = 1.46    -- les bras s ecartent : les mains sont a 1,46 du milieu
local PIEDS_SOL    = 0.5

local H_BARRE  = PIEDS_SOL + RACINE_PIEDS + RACINE_MAINS      -- la barre, au-dessus du sol
local LARGEUR  = 4                                            -- entre les montants

local GRAPHITE = Color3.fromRGB(45, 47, 52)
local CHROME   = Color3.fromRGB(190, 195, 200)
local NOIR     = Color3.fromRGB(22, 22, 25)
local ROUGE    = Color3.fromRGB(200, 30, 35)
local NEON     = Color3.fromRGB(0, 225, 255)

local enregistrement = ChangeHistoryService:TryBeginRecording("Barres de traction")

-- on enleve les anciennes barres (meme celle d a cote des tapis de course)
for _, m in ipairs(salle:GetChildren()) do
	if m.Name == "BarreDeTraction" then m:Destroy() end
end

local function construire(position, numero)
	-- le repere de la barre : au SOL, X = le long de la barre, -Z = la ou on regarde
	local P = sol.CFrame * CFrame.new(position + Vector3.new(0, sol.Size.Y / 2, 0))

	local modele = Instance.new("Model")
	modele.Name = "BarreDeTraction"
	modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	modele:SetAttribute("Numero", numero)
	modele.Parent = salle

	local function piece(nom, taille, cf, couleur, matiere, forme)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.Size = taille
		p.CFrame = cf
		p.Color = couleur
		p.Material = matiere or Enum.Material.Metal
		if forme then p.Shape = forme end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = modele
		return p
	end

	-- le tapis de sol et les pieds
	piece("SolTraction", Vector3.new(LARGEUR + 1, 0.06, 3.4), P * CFrame.new(0, 0.03, 0), NOIR, Enum.Material.Rubber)
	for _, s in ipairs({-1, 1}) do
		local x = s * LARGEUR / 2
		piece("PiedTraction", Vector3.new(0.45, 0.2, 2.8), P * CFrame.new(x, 0.1, 0), GRAPHITE)
		piece("MontantTraction", Vector3.new(0.35, H_BARRE + 0.7, 0.35), P * CFrame.new(x, (H_BARRE + 0.7) / 2, 0), GRAPHITE)
		-- les poignees en mousse, la ou tombent les mains
		piece("PoigneeTraction", Vector3.new(0.6, 0.24, 0.24), P * CFrame.new(s * MAINS_X, H_BARRE, 0), NOIR, Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
	piece("PoutreTraction", Vector3.new(LARGEUR + 0.35, 0.35, 0.35), P * CFrame.new(0, H_BARRE + 0.7, 0), GRAPHITE)
	local barre = piece("BarreTraction", Vector3.new(LARGEUR, 0.16, 0.16), P * CFrame.new(0, H_BARRE, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece("LiserTraction", Vector3.new(LARGEUR + 0.37, 0.06, 0.37), P * CFrame.new(0, H_BARRE + 0.88, 0), ROUGE, Enum.Material.Neon)

	-- le bouton pour s accrocher
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "S'accrocher"
	prompt.ObjectText = "Barre de traction " .. numero
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = barre

	-- le panneau des records, au-dessus de la poutre (le texte des 2 cotes)
	local panneau = piece("PanneauTraction", Vector3.new(LARGEUR, 1.3, 0.15), P * CFrame.new(0, H_BARRE + 1.6, 0), GRAPHITE, Enum.Material.SmoothPlastic)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.LightInfluence = 0
	g.Parent = panneau
	local fond = Instance.new("Frame")
	fond.Size = UDim2.fromScale(1, 1)
	fond.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
	fond.BorderSizePixel = 0
	fond.Parent = g
	local t = Instance.new("TextLabel")
	t.Name = "Texte"
	t.Size = UDim2.new(1, -12, 1, -8)
	t.Position = UDim2.fromOffset(6, 4)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = NEON
	t.Text = "BARRE DE TRACTION " .. numero .. "\nRECORD : —"
	t.ZIndex = 2
	t.Parent = g
	g:Clone().Parent = panneau          -- le meme texte de l autre cote
	panneau:FindFirstChildOfClass("SurfaceGui").Face = Enum.NormalId.Back

	modele.PrimaryPart = barre
	return modele
end

for numero, position in ipairs(POSITIONS) do construire(position, numero) end

if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(string.format("%d barres de traction : a %.2f studs du sol", #POSITIONS, H_BARRE))
