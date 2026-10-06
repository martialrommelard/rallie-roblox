-- =========================================================
--  LES TAPIS DE COURSE, EN VRAI  (a lancer UNE fois, dans Studio, en Edit,
--  APRES SalleSport.lua). Remplace les 3 tapis simples par de vrais tapis :
--  capot moteur, bords pour poser les pieds, rouleaux, montants, rampes,
--  console inclinee vers le coureur, et 2 BOUTONS pour changer la vitesse.
--
--  Chaque tapis a sa vitesse de depart (VITESSES_DEPART) : marche, footing,
--  sprint. La vitesse est un ATTRIBUT du modele ("Vitesse") : le serveur
--  (SalleSportServeur) la change avec les boutons et fait tourner la bande,
--  les joueurs (Exercices) font defiler les rayures de la bande.
--
--  Tout est pose dans le repere de l ANCIENNE bande (on la remplace) :
--  X = droite, Y = haut (0 = milieu de la bande), -Z = devant le coureur.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")

local VITESSES_DEPART = {6, 14, 22}       -- du tapis le plus a gauche au plus a droite
local LARGEUR, LONGUEUR = 2.6, 6.4        -- la bande
local NB_RAYURES = 8                      -- les rayures qui defilent sur la bande

local GRAPHITE = Color3.fromRGB(45, 47, 52)
local GRIS     = Color3.fromRGB(110, 114, 120)
local CHROME   = Color3.fromRGB(190, 195, 200)
local NOIR     = Color3.fromRGB(22, 22, 25)
local ROUGE    = Color3.fromRGB(200, 30, 35)
local BLEU     = Color3.fromRGB(30, 110, 220)
local NEON     = Color3.fromRGB(0, 225, 255)

local enregistrement = ChangeHistoryService:TryBeginRecording("Tapis de course")

-- les anciennes bandes, de gauche a droite (vu par le coureur)
local bandes = {}
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "TapisCourse" and p:IsA("BasePart") then table.insert(bandes, p) end
end
table.sort(bandes, function(a, b)
	return a.CFrame:PointToObjectSpace(b.Position).X > 0      -- b est a droite de a
end)

local function construire(ancienne, numero)
	local B = ancienne.CFrame
	local SOL = -ancienne.Size.Y / 2 - 0.5          -- le socle faisait 0,5 sous la bande
	-- on enleve l ancien tapis (par NOM, et seulement autour de cette bande)
	for _, p in ipairs(salle:GetChildren()) do
		if (p.Name == "SocleTapis" or p.Name == "MontantTapis" or p.Name == "RampeTapis" or p.Name == "ConsoleTapis")
			and p ~= ancienne and (p.Position - ancienne.Position).Magnitude < 6 then
			p:Destroy()
		end
	end
	ancienne:Destroy()

	local modele = Instance.new("Model")
	modele.Name = "TapisDeCourse"
	modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	modele:SetAttribute("Numero", numero)
	modele:SetAttribute("Vitesse", VITESSES_DEPART[numero] or 14)
	modele.Parent = salle

	local function piece(nom, taille, cf, couleur, matiere, solide)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.CanCollide = solide ~= false
		p.Size = taille
		p.CFrame = cf
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = modele
		return p
	end
	local function tube(nom, a, b, ep, couleur)
		local A, Bp = B * a, B * b
		return piece(nom, Vector3.new(ep, ep, (Bp - A).Magnitude), CFrame.lookAt((A + Bp) / 2, Bp, B.RightVector), couleur, Enum.Material.Metal)
	end
	local function rond(nom, centre, longueur, diametre, couleur)
		local p = piece(nom, Vector3.new(longueur, diametre, diametre), B * CFrame.new(centre), couleur, Enum.Material.Metal, false)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	local demi = LONGUEUR / 2
	-- le socle, la bande, les bords
	piece("SocleTapis", Vector3.new(LARGEUR + 0.8, -SOL - 0.06, LONGUEUR + 0.4), B * CFrame.new(0, (SOL - 0.06) / 2, 0.1), GRAPHITE, Enum.Material.Metal)
	local bande = piece("TapisCourse", Vector3.new(LARGEUR, 0.12, LONGUEUR), B, NOIR, Enum.Material.Fabric)
	for _, s in ipairs({-1, 1}) do
		piece("BordTapis", Vector3.new(0.4, 0.16, LONGUEUR + 0.2), B * CFrame.new(s * (LARGEUR / 2 + 0.2), 0.02, 0.1), GRIS, Enum.Material.DiamondPlate)
		piece("LiserTapis", Vector3.new(0.05, 0.12, LONGUEUR + 0.2), B * CFrame.new(s * (LARGEUR / 2 + 0.42), -0.12, 0.1), ROUGE, Enum.Material.Neon, false)
	end
	-- les rouleaux aux deux bouts, et les rayures (elles DEFILENT : Exercices)
	rond("RouleauTapis", Vector3.new(0, -0.02, demi), LARGEUR, 0.2, CHROME)
	rond("RouleauTapis", Vector3.new(0, -0.02, -demi), LARGEUR, 0.2, CHROME)
	for i = 1, NB_RAYURES do
		local r = piece("RayureTapis", Vector3.new(LARGEUR - 0.1, 0.01, 0.12),
			B * CFrame.new(0, 0.065, -demi + (i - 0.5) * LONGUEUR / NB_RAYURES), Color3.fromRGB(70, 70, 76), Enum.Material.SmoothPlastic, false)
		r.CanQuery, r.CanTouch = false, false
	end
	-- le capot du moteur, devant
	local zCapot = -demi - 0.55
	piece("CapotMoteur", Vector3.new(LARGEUR + 0.8, -SOL + 0.2, 1.1), B * CFrame.new(0, (SOL + 0.2) / 2, zCapot), GRAPHITE, Enum.Material.SmoothPlastic)
	piece("BandeCapot", Vector3.new(LARGEUR + 0.82, 0.1, 1.12), B * CFrame.new(0, 0.05, zCapot), ROUGE, Enum.Material.SmoothPlastic, false)

	-- les montants (un peu penches vers le coureur) et les rampes
	local yRampe, yConsole = 3.0, 3.9
	for _, s in ipairs({-1, 1}) do
		local x = s * (LARGEUR / 2 + 0.25)
		tube("MontantTapis", Vector3.new(x, 0.1, zCapot), Vector3.new(x, yConsole - 0.3, zCapot + 0.45), 0.22, GRIS)
		tube("RampeTapis", Vector3.new(x, yRampe, zCapot + 0.35), Vector3.new(x, yRampe, -demi + 2.3), 0.16, CHROME)
		tube("RampeTapis", Vector3.new(x, yRampe, -demi + 2.3), Vector3.new(x, yRampe - 0.5, -demi + 2.6), 0.16, CHROME)
		piece("MousseRampe", Vector3.new(0.2, 0.2, 1.2), B * CFrame.new(x, yRampe, -demi + 1.5), NOIR, Enum.Material.Rubber, false)
	end
	tube("TraverseTapis", Vector3.new(-(LARGEUR / 2 + 0.25), yRampe, zCapot + 0.35), Vector3.new(LARGEUR / 2 + 0.25, yRampe, zCapot + 0.35), 0.16, CHROME)

	-- la console : tournee vers les yeux du coureur
	local centreConsole = Vector3.new(0, yConsole, zCapot + 0.5)
	local console = piece("ConsoleTapis", Vector3.new(LARGEUR + 0.4, 1.1, 0.2),
		CFrame.lookAt(B * centreConsole, B * Vector3.new(0, 4.6, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0
	g.Parent = console
	local fond = Instance.new("Frame")
	fond.Size = UDim2.fromScale(1, 1)
	fond.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
	fond.BorderSizePixel = 0
	fond.Parent = g
	local t = Instance.new("TextLabel")
	t.Name = "Texte"
	t.Size = UDim2.new(1, -16, 1, -10)
	t.Position = UDim2.fromOffset(8, 5)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = NEON
	t.Text = "TAPIS " .. numero
	t.ZIndex = 2
	t.Parent = g

	-- les 2 boutons, sous la console : Q moins vite (bleu), E plus vite (rouge)
	for _, info in ipairs({{"BoutonMoins", -1, BLEU, "Moins vite", Enum.KeyCode.Q}, {"BoutonPlus", 1, ROUGE, "Plus vite", Enum.KeyCode.E}}) do
		local bouton = piece(info[1], Vector3.new(0.6, 0.35, 0.15),
			console.CFrame * CFrame.new(info[2] * 0.75, -0.75, -0.05), info[3], Enum.Material.Neon, false)
		local p = Instance.new("ProximityPrompt")
		p.ActionText = info[4]
		p.ObjectText = "Tapis " .. numero
		p.KeyboardKeyCode = info[5]
		p.HoldDuration = 0
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Parent = bouton
	end
	modele.PrimaryPart = bande
	return modele
end

for numero, b in ipairs(bandes) do construire(b, numero) end
if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(#bandes .. " tapis construits, vitesses " .. table.concat(VITESSES_DEPART, " / "))
