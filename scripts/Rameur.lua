-- =========================================================
--  LE RAMEUR  (a lancer UNE fois, dans Studio, en Edit, APRES SalleSport.lua)
--  Sur la moquette des tractions. Un rail, un siege qui GLISSE, un
--  repose-pieds, le volant (le gros cylindre devant) d ou sort la chaine, la
--  poignee, et un ecran des records.
--
--  Le jeu : une course de DISTANCE metres. On s assoit (E), on appuie sur
--  Q et D en ALTERNANCE : chaque bonne alternance donne un coup de rame. Le
--  bateau ralentit tout seul. Le LocalScript Exercices fait le jeu et
--  l animation (siege qui glisse, jambes, buste, bras) ; le serveur
--  (SalleSportServeur) assoit le joueur, recopie sa vitesse pour les autres
--  et garde le record.
--
--  Les mesures sont DEDUITES de mon avatar assis sur le siege :
--    - la cheville est a JAMBE * 0,97 de la hanche quand le siege est en
--      arriere (jambes presque tendues) ;
--    - le siege avance de GLISSE : les genoux se plient (sans aller plus
--      pres que |cuisse - mollet| de la hanche).
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")
local sol = salle:WaitForChild("MoquetteSimu")

-- ---- OU : dans le repere de la moquette, au milieu, devant les 2 barres de traction,
--      tourne vers la salle (-Z) ----
local POSITION = Vector3.new(0, 0, 4)
local DISTANCE = 250          -- la course, en metres

-- ---- LE RAMEUR ASSIS (mesure sur mon avatar, en studs) ----
local HANCHE_Y = 0.59         -- hanche au-dessus du milieu du siege
local JAMBE    = 0.96 + 0.57  -- cuisse + mollet
local PIED     = 0.47         -- de la cheville a la semelle
local MAINS_X  = 1.4          -- les mains, de chaque cote du milieu

local Y_SIEGE  = 0.75                               -- le milieu du siege
local GLISSE   = 0.9                                -- de combien le siege avance
local ANGLE_JAMBE = math.rad(18)                    -- jambes tendues : la cheville un peu plus bas que la hanche
local hanche   = Vector3.new(0, Y_SIEGE + HANCHE_Y, 0)                     -- siege en arriere (fin du coup)
local cheville = hanche + Vector3.new(0, -math.sin(ANGLE_JAMBE), -math.cos(ANGLE_JAMBE)) * JAMBE * 0.97
local Z_PIEDS  = cheville.Z
local Y_PIEDS  = cheville.Y - PIED                  -- la ou se posent les semelles
local Z_VOLANT = Z_PIEDS - 1.1

local GRAPHITE = Color3.fromRGB(45, 47, 52)
local ALU      = Color3.fromRGB(170, 175, 182)
local NOIR     = Color3.fromRGB(22, 22, 25)
local ROUGE    = Color3.fromRGB(200, 30, 35)
local NEON     = Color3.fromRGB(0, 225, 255)

local enregistrement = ChangeHistoryService:TryBeginRecording("Rameur")
local ancien = salle:FindFirstChild("Rameur")
if ancien then ancien:Destroy() end

-- le repere : au SOL, sous le siege en arriere ; -Z = vers les pieds (la ou le rameur regarde)
local P = sol.CFrame * CFrame.new(POSITION + Vector3.new(0, sol.Size.Y / 2, 0))

local modele = Instance.new("Model")
modele.Name = "Rameur"
modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
modele:SetAttribute("Distance", DISTANCE)
modele:SetAttribute("Glisse", GLISSE)
modele.Parent = salle

local function piece(nom, taille, cf, couleur, matiere, forme, solide)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.CanCollide = solide == true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.Metal
	if forme then p.Shape = forme end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = modele
	return p
end
local function tube(nom, a, b, ep, couleur)
	local A, B = P * a, P * b
	return piece(nom, Vector3.new(ep, ep, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B, P.RightVector), couleur)
end

-- le rail (il porte le siege) et ses pieds
local zFinRail = 1.6
local yRail = Y_SIEGE - 0.15 - 0.12
piece("RailRameur", Vector3.new(0.45, 0.14, zFinRail - Z_PIEDS + 0.3), P * CFrame.new(0, yRail - 0.07, (zFinRail + Z_PIEDS) / 2), ALU, Enum.Material.Metal, nil, true)
piece("PiedArriereRameur", Vector3.new(1.6, yRail - 0.14, 0.35), P * CFrame.new(0, (yRail - 0.14) / 2, zFinRail - 0.1), GRAPHITE, Enum.Material.Metal, nil, true)
piece("PiedAvantRameur", Vector3.new(1.8, 0.25, 0.5), P * CFrame.new(0, 0.125, Z_VOLANT), GRAPHITE, Enum.Material.Metal, nil, true)
tube("PoutreRameur", Vector3.new(0, yRail - 0.1, Z_PIEDS + 0.2), Vector3.new(0, 0.6, Z_VOLANT + 0.2), 0.3, GRAPHITE)

-- le siege (un Seat : on s assoit dessus ; c est Exercices qui le fait glisser)
local siege = Instance.new("Seat")
siege.Name = "SiegeRameur"
siege.Anchored = true
siege.Size = Vector3.new(0.9, 0.3, 1.0)
siege.CFrame = P * CFrame.new(0, Y_SIEGE, 0)          -- regarde vers -Z, comme le rameur
siege.Color = NOIR
siege.Material = Enum.Material.Leather
siege.Parent = modele

-- le repose-pieds : 2 plaques un peu penchees, avec leurs sangles
for _, s in ipairs({-1, 1}) do
	local cf = P * CFrame.new(s * 0.45, Y_PIEDS, Z_PIEDS - 0.1) * CFrame.Angles(math.rad(20), 0, 0)
	piece("ReposePieds", Vector3.new(0.5, 0.08, 1.1), cf, NOIR, Enum.Material.Rubber, nil, true)
	piece("SanglePieds", Vector3.new(0.52, 0.12, 0.2), cf * CFrame.new(0, 0.1, -0.1), ROUGE, Enum.Material.Fabric)
end
piece("SupportPieds", Vector3.new(1.4, 0.3, 0.3), P * CFrame.new(0, Y_PIEDS - 0.2, Z_PIEDS - 0.2), GRAPHITE)

-- le volant (le gros cylindre devant) et son carter
piece("VolantRameur", Vector3.new(0.7, 1.4, 1.4), P * CFrame.new(0, 1.0, Z_VOLANT), GRAPHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, true)
piece("BordVolantRameur", Vector3.new(0.72, 1.2, 1.2), P * CFrame.new(0, 1.0, Z_VOLANT), ROUGE, Enum.Material.Neon, Enum.PartType.Cylinder)
-- la sortie de la chaine, en haut du volant
local sortie = Vector3.new(0, 1.55, Z_VOLANT + 0.35)
piece("SortieChaine", Vector3.new(0.3, 0.2, 0.3), P * CFrame.new(sortie), ALU)

-- la poignee (Exercices la fait aller et venir) et la chaine
local poignee = piece("PoigneeRameur", Vector3.new(MAINS_X * 2 + 0.3, 0.12, 0.12), P * CFrame.new(sortie + Vector3.new(0, 0, 0.3)), ALU, Enum.Material.Metal, Enum.PartType.Cylinder)
for _, s in ipairs({-1, 1}) do
	local g = piece(s > 0 and "PoigneeD" or "PoigneeG", Vector3.new(0.4, 0.18, 0.18), poignee.CFrame * CFrame.new(s * MAINS_X, 0, 0), NOIR, Enum.Material.Rubber, Enum.PartType.Cylinder)
	g.Anchored = false
	g.Massless = true
	local w = Instance.new("WeldConstraint")         -- on soude APRES avoir pose (sinon ca ne suit pas)
	w.Part0, w.Part1 = poignee, g
	w.Parent = g
end
piece("ChaineRameur", Vector3.new(0.05, 0.05, 0.3), P * CFrame.new(sortie + Vector3.new(0, 0, 0.15)), NOIR, Enum.Material.Metal)
local att = Instance.new("Attachment")
att.Name = "Sortie"
att.Parent = modele:FindFirstChild("SortieChaine")

-- l ecran : au bout d un bras, au-dessus du volant, tourne vers le rameur
local ecran = piece("EcranRameur", Vector3.new(1.6, 1.0, 0.1), CFrame.lookAt((P * CFrame.new(0, 2.6, Z_VOLANT + 0.2)).Position, (P * CFrame.new(0, 2.4, 0)).Position), GRAPHITE, Enum.Material.SmoothPlastic)
tube("BrasEcran", Vector3.new(0, 1.6, Z_VOLANT + 0.1), Vector3.new(0, 2.2, Z_VOLANT + 0.2), 0.12, ALU)
local g = Instance.new("SurfaceGui")
g.Face = Enum.NormalId.Front
g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.PixelsPerStud = 60
g.LightInfluence = 0
g.Parent = ecran
local fond = Instance.new("Frame")
fond.Size = UDim2.fromScale(1, 1)
fond.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
fond.BorderSizePixel = 0
fond.Parent = g
local t = Instance.new("TextLabel")
t.Name = "Texte"
t.Size = UDim2.new(1, -10, 1, -8)
t.Position = UDim2.fromOffset(5, 4)
t.BackgroundTransparency = 1
t.Font = Enum.Font.GothamBold
t.TextScaled = true
t.TextColor3 = NEON
t.Text = "RAMEUR " .. DISTANCE .. " m\nRECORD : —"
t.ZIndex = 2
t.Parent = g
g:Clone().Parent = ecran
ecran:FindFirstChildOfClass("SurfaceGui").Face = Enum.NormalId.Back

-- le bouton pour s asseoir
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Ramer"
prompt.ObjectText = "Rameur " .. DISTANCE .. " m"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 7
prompt.RequiresLineOfSight = false
prompt.Parent = siege

modele.PrimaryPart = siege
if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(string.format("Rameur : pieds a %.2f devant le siege, siege qui glisse de %.2f", -Z_PIEDS, GLISSE))
