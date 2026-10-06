-- =========================================================
--  LE RATELIER D HALTERES  (a lancer UNE fois, dans Studio, en Edit, APRES
--  SalleSport.lua). Remplace l ancien ratelier (6 barres pour faire joli)
--  par un vrai ratelier avec 3 PAIRES d haltères : 5, 10 et 20 kg.
--
--  On prend une paire (touche E) : le serveur (SalleSportServeur) en fait un
--  OUTIL (Tool) qu on a en main, une haltère dans chaque main. Chaque clic =
--  un curl (Exercices plie le bras), plus lent quand c est lourd. On la
--  repose en appuyant encore sur E devant le ratelier.
--
--  Chaque paire = un Model "PaireHalteres" (attribut Poids) avec 2 Models
--  "Haltere" (la poignee + 2 disques). Le serveur COPIE ces haltères pour
--  faire l outil : rien n est dessine deux fois.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")
local sol = salle:WaitForChild("TapisSport")

-- ---- OU : la ou etait l ancien ratelier (repere du sol de la salle de sport) ----
local POSITION = Vector3.new(20.7, 0, 13.3)

-- ---- LES PAIRES : le poids, la couleur, la taille des disques, la duree d un curl ----
local PAIRES = {
	{poids = 5,  couleur = Color3.fromRGB(30, 110, 220), disque = 0.42, epaisseur = 0.12, duree = 0.6},
	{poids = 10, couleur = Color3.fromRGB(240, 190, 40), disque = 0.55, epaisseur = 0.16, duree = 0.9},
	{poids = 20, couleur = Color3.fromRGB(200, 30, 35),  disque = 0.70, epaisseur = 0.22, duree = 1.3},
}
local POIGNEE = 0.55          -- la longueur de la poignee (entre les disques)
local H_RATELIER = 2.3        -- le dessus du ratelier
local ECART = 2.4             -- entre deux paires

local GRAPHITE = Color3.fromRGB(45, 47, 52)
local CHROME   = Color3.fromRGB(190, 195, 200)
local NOIR     = Color3.fromRGB(22, 22, 25)

local enregistrement = ChangeHistoryService:TryBeginRecording("Ratelier d halteres")

-- on enleve l ancien ratelier (par NOM)
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "Ratelier" or p.Name == "Haltere" or p.Name == "PoidsHaltere" or p.Name == "RatelierHalteres" then
		p:Destroy()
	end
end

-- le repere : au SOL ; X = le long du ratelier, -Z = cote ou on se tient
local R = sol.CFrame * CFrame.new(POSITION + Vector3.new(0, sol.Size.Y / 2, 0))
local LONGUEUR = ECART * #PAIRES + 0.6

local modele = Instance.new("Model")
modele.Name = "RatelierHalteres"
modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
modele.Parent = salle

local function piece(nom, taille, cf, couleur, matiere, forme, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.Metal
	if forme then p.Shape = forme end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or modele
	return p
end

-- le meuble : 2 pieds, un plateau incline vers celui qui se sert, un rebord
for _, s in ipairs({-1, 1}) do
	piece("PiedRatelier", Vector3.new(0.3, H_RATELIER - 0.1, 1.2), R * CFrame.new(s * (LONGUEUR / 2 - 0.2), (H_RATELIER - 0.1) / 2, 0), GRAPHITE)
end
local plateau = R * CFrame.new(0, H_RATELIER, 0) * CFrame.Angles(math.rad(-12), 0, 0)    -- penche vers -Z
piece("PlateauRatelier", Vector3.new(LONGUEUR, 0.12, 1.3), plateau, GRAPHITE)
piece("RebordRatelier", Vector3.new(LONGUEUR, 0.25, 0.1), plateau * CFrame.new(0, 0.12, -0.62), CHROME)
piece("TraverseRatelier", Vector3.new(LONGUEUR - 0.4, 0.2, 0.2), R * CFrame.new(0, 0.4, 0), GRAPHITE)

-- une haltère : la poignee (le long de X) et 2 disques
local function haltere(paire, info, cf)
	local h = Instance.new("Model")
	h.Name = "Haltere"
	local poignee = piece("Poignee", Vector3.new(POIGNEE + info.epaisseur * 2 + 0.1, 0.16, 0.16), cf, CHROME, Enum.Material.Metal, Enum.PartType.Cylinder, h)
	for _, s in ipairs({-1, 1}) do
		piece("Disque", Vector3.new(info.epaisseur, info.disque, info.disque), cf * CFrame.new(s * (POIGNEE / 2 + info.epaisseur / 2), 0, 0),
			info.couleur, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, h)
	end
	h.PrimaryPart = poignee
	h.Parent = paire
	return h
end

for k, info in ipairs(PAIRES) do
	local x = (k - (#PAIRES + 1) / 2) * ECART
	local paire = Instance.new("Model")
	paire.Name = "PaireHalteres"
	paire:SetAttribute("Poids", info.poids)
	paire:SetAttribute("Duree", info.duree)
	paire.Parent = modele
	-- les 2 haltères couchees cote a cote sur le plateau (posees sur leurs disques)
	for _, s in ipairs({-1, 1}) do
		haltere(paire, info, plateau * CFrame.new(x, 0.06 + info.disque / 2, s * (info.disque / 2 + 0.04)))
	end
	-- la pancarte du poids, sur le rebord
	local pancarte = piece("PancartePoids", Vector3.new(0.9, 0.35, 0.05), plateau * CFrame.new(x, 0.12, -0.68), NOIR, Enum.Material.SmoothPlastic, nil, paire)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 80
	g.LightInfluence = 0
	g.Parent = pancarte
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = info.couleur
	t.Text = info.poids .. " kg"
	t.Parent = g
	-- la zone pour prendre (invisible) et son bouton
	local zone = piece("ZonePrise", Vector3.new(ECART - 0.3, 1, 1.3), plateau * CFrame.new(x, 0.5, 0), NOIR, Enum.Material.SmoothPlastic, nil, paire)
	zone.Transparency = 1
	zone.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Prendre / reposer"
	prompt.ObjectText = "Halteres " .. info.poids .. " kg"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone
end

if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(#PAIRES .. " paires d halteres sur le ratelier")
