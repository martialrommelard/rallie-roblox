-- =========================================================
--  LES VELOS D APPARTEMENT, EN VRAI  (a lancer UNE fois, dans Studio, en
--  Edit, APRES SalleSport.lua). Remplace les 2 velos simples (une barre, un
--  poteau, un disque) par de vrais velos de salle : roue d inertie devant,
--  cadre, tige de selle, manivelles et pedales, guidon avec cornes, ecran.
--
--  On GARDE la selle (VeloSport) et l ecran (EcranVelo) : on les range dans
--  le modele du velo avec le reste.
--
--  TOUT EST CALCULE A PARTIR DU PILOTE (mesure sur mon avatar) :
--    - la hanche est a HANCHE_Y au-dessus du milieu de la selle ;
--    - la cheville doit pouvoir atteindre la pedale du bas sans tendre la
--      jambe a fond (CUISSE + MOLLET), et la pedale du haut sans plier le
--      genou a l extreme -> le pedalier est a DIST_PEDALIER de la hanche,
--      et la manivelle fait RAYON de long ;
--    - les mains tombent sur le guidon avec le buste penche de PENCHE degres.
--  Le LocalScript Exercices fait tourner les pedales et pose les jambes du
--  pilote dessus (en relisant les pieces du velo : rien n y est en dur).
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")

-- ---- LE PILOTE (mesure sur mon avatar, en studs) ----
local HANCHE_Y   = 0.59    -- hanche au-dessus du milieu de la selle
local CUISSE     = 0.96
local MOLLET     = 0.57
local PIED       = 0.47    -- de la cheville a la semelle
local TAILLE_Y   = 0.4     -- de la hanche a la taille (le pli du buste)
local EPAULE_Y   = 1.25    -- de la taille a l epaule
local BRAS       = 0.58 + 1.09                  -- epaule -> coude -> poignee
local MAIN_X     = 1.4     -- les bras du personnage s ecartent : les mains sont a 1,4 du milieu

-- ---- LE VELO, deduit du pilote ----
local RAYON       = 0.33                          -- la manivelle
local DIST_PEDALIER = CUISSE + MOLLET - 0.08 - RAYON   -- jambe presque tendue en bas
local ANGLE_SELLE = math.rad(20)                  -- le pedalier est 20 degres en avant de la selle
local PENCHE      = math.rad(25)                  -- le buste penche en avant
local ALLONGE     = 0.84                          -- les bras tendus a 84 %
local ANGLE_BRAS  = math.rad(35)                  -- les bras descendent de 35 degres vers le guidon

-- le repere de la selle : X = droite, Y = haut, -Z = devant
local hanche  = Vector3.new(0, HANCHE_Y, 0)
local cheville = hanche + Vector3.new(0, -math.cos(ANGLE_SELLE), -math.sin(ANGLE_SELLE)) * DIST_PEDALIER
local AXE     = cheville - Vector3.new(0, PIED, 0)                        -- le centre du pedalier
local taille  = hanche + Vector3.new(0, TAILLE_Y, 0)                        -- le buste plie ici
local epaule  = taille + Vector3.new(0, EPAULE_Y * math.cos(PENCHE), -EPAULE_Y * math.sin(PENCHE))
local MAIN    = epaule + Vector3.new(0, -math.sin(ANGLE_BRAS), -math.cos(ANGLE_BRAS)) * BRAS * ALLONGE
local VOLANT  = Vector3.new(0, AXE.Y - 0.5, AXE.Z - 1.17)                  -- la roue d inertie, devant le pedalier
local R_VOLANT = 0.75

local GRAPHITE = Color3.fromRGB(45, 47, 52)
local ROUGE    = Color3.fromRGB(200, 30, 35)
local CHROME   = Color3.fromRGB(190, 195, 200)
local NOIR     = Color3.fromRGB(18, 18, 20)

local enregistrement = ChangeHistoryService:TryBeginRecording("Velos d appartement")

local function construire(selle)
	local S = selle.CFrame
	-- le sol sous la selle
	local rayons = RaycastParams.new()
	rayons.FilterDescendantsInstances = {selle.Parent}
	rayons.FilterType = Enum.RaycastFilterType.Exclude
	local r = workspace:Raycast(selle.Position, Vector3.new(0, -10, 0), rayons)
	local SOL = r and (r.Position.Y - selle.Position.Y) or -2.5

	-- on enleve l ancien velo (par NOM, et seulement autour de cette selle)
	for _, p in ipairs(salle:GetChildren()) do
		if (p.Name == "CadreVelo" or p.Name == "MontantVelo" or p.Name == "GuidonVelo"
			or p.Name == "ColonneVelo" or p.Name == "Pedalier") and (p.Position - selle.Position).Magnitude < 4.5 then
			p:Destroy()
		end
	end
	local ecran = nil
	for _, p in ipairs(salle:GetChildren()) do
		if p.Name == "EcranVelo" and (p.Position - selle.Position).Magnitude < 4.5 then ecran = p end
	end

	local modele = Instance.new("Model")
	modele.Name = "VeloAppartement"
	modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic      -- il arrive en entier chez le joueur
	modele.Parent = salle

	local function piece(nom, taille, cf, couleur, matiere, forme, solide)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.CanCollide = solide == true      -- traversable : sinon les jambes ejectent le pilote
		p.Size = taille
		p.CFrame = cf
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		if forme then p.Shape = forme end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = modele
		return p
	end
	-- un tube d un point a un autre (points dans le repere de la selle)
	local function tube(nom, a, b, ep, couleur, matiere)
		local A, B = S * a, S * b
		return piece(nom, Vector3.new(ep, ep, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B, S.RightVector), couleur, matiere or Enum.Material.Metal)
	end
	-- un cylindre couche le long de X (axe, roue, poignee)
	local function rond(nom, centre, longueur, diametre, couleur, matiere)
		return piece(nom, Vector3.new(longueur, diametre, diametre), S * CFrame.new(centre), couleur, matiere or Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	-- le pied : deux barres au sol et un longeron
	local yPied = SOL + 0.125
	local zArr, zAv = 1.1, VOLANT.Z - 1.05
	piece("PiedVelo", Vector3.new(2.4, 0.25, 0.4), S * CFrame.new(0, yPied, zArr), GRAPHITE, Enum.Material.Metal, nil, true)
	piece("PiedVelo", Vector3.new(2.4, 0.25, 0.4), S * CFrame.new(0, yPied, zAv), GRAPHITE, Enum.Material.Metal, nil, true)
	for _, x in ipairs({-1.2, 1.2}) do
		for _, z in ipairs({zArr, zAv}) do
			piece("PatinVelo", Vector3.new(0.3, 0.27, 0.42), S * CFrame.new(x, yPied, z), NOIR, Enum.Material.Rubber)
		end
	end
	tube("Longeron", Vector3.new(0, SOL + 0.25, zArr), Vector3.new(0, SOL + 0.25, zAv), 0.28, GRAPHITE)

	-- le cadre : du pied arriere au pedalier, puis la tige de selle
	tube("TubeArriere", Vector3.new(0, SOL + 0.3, zArr - 0.1), AXE, 0.32, GRAPHITE)
	tube("TubeSelle", AXE, Vector3.new(0, -0.15, 0.05), 0.28, GRAPHITE)
	tube("TigeSelle", Vector3.new(0, -0.6, -0.07), Vector3.new(0, -0.14, 0.04), 0.18, CHROME)
	rond("BoitierPedalier", AXE, 0.5, 0.55, GRAPHITE)

	-- la roue d inertie (devant), avec un bord rouge et une fourche de chaque cote
	rond("VolantInertie", VOLANT, 0.22, R_VOLANT * 2, CHROME)
	rond("BordVolant", VOLANT, 0.12, R_VOLANT * 2 + 0.08, ROUGE, Enum.Material.SmoothPlastic)
	rond("MoyeuVolant", VOLANT, 0.5, 0.25, NOIR)
	local haut = Vector3.new(0, VOLANT.Y + R_VOLANT + 0.25, VOLANT.Z - 0.05)
	for _, x in ipairs({-0.2, 0.2}) do
		tube("Fourche", Vector3.new(x, VOLANT.Y, VOLANT.Z), Vector3.new(x, haut.Y, haut.Z), 0.12, GRAPHITE)
		tube("JambeAvant", Vector3.new(x, VOLANT.Y, VOLANT.Z), Vector3.new(x, SOL + 0.25, zAv), 0.14, GRAPHITE)
	end
	tube("TubeAvant", Vector3.new(0, haut.Y - 0.1, haut.Z), Vector3.new(0, MAIN.Y - 0.35, MAIN.Z + 0.05), 0.3, GRAPHITE)
	tube("TubeBas", AXE, Vector3.new(0, haut.Y - 0.05, haut.Z), 0.26, GRAPHITE)
	-- la courroie, sous un carter rouge (cote droit)
	local dirC = (VOLANT - AXE).Unit
	-- (un tube a son Y vers la droite de la selle : X = la hauteur du carter, Y = son epaisseur)
	tube("CarterCourroie", AXE - dirC * 0.3 + Vector3.new(0.21, 0, 0), VOLANT + dirC * 0.3 + Vector3.new(0.21, 0, 0), 0.06, ROUGE, Enum.Material.SmoothPlastic).Size =
		Vector3.new(0.55, 0.06, (VOLANT - AXE).Magnitude + 0.6)

	-- le guidon : potence, barre, poignees, cornes
	tube("Potence", Vector3.new(0, MAIN.Y - 0.4, MAIN.Z + 0.05), Vector3.new(0, MAIN.Y, MAIN.Z), 0.22, CHROME)
	rond("GuidonVelo", MAIN, MAIN_X * 2 + 0.3, 0.14, CHROME)
	for _, s in ipairs({-1, 1}) do
		rond(s > 0 and "PoigneeD" or "PoigneeG", MAIN + Vector3.new(s * MAIN_X, 0, 0), 0.5, 0.2, NOIR, Enum.Material.Rubber)
		tube("CorneGuidon", MAIN + Vector3.new(s * 0.35, 0, 0), MAIN + Vector3.new(s * 0.35, 0.15, -0.55), 0.13, CHROME)
		rond("BoutCorne", MAIN + Vector3.new(s * 0.35, 0.15, -0.55), 0.16, 0.16, NOIR, Enum.Material.Rubber)
	end

	-- le pedalier : l axe, les manivelles, les pedales (elles TOURNENT : Exercices)
	rond("AxePedalier", AXE, 0.7, 0.14, CHROME)
	for _, s in ipairs({1, -1}) do
		-- a droite la manivelle vers le bas, a gauche vers le haut (en face)
		local bout = AXE + Vector3.new(s * 0.33, -s * RAYON, 0)
		piece(s > 0 and "ManivelleD" or "ManivelleG", Vector3.new(0.1, RAYON + 0.12, 0.14),
			S * CFrame.new(AXE + Vector3.new(s * 0.33, -s * RAYON / 2, 0)), GRAPHITE, Enum.Material.Metal)
		piece(s > 0 and "PedaleD" or "PedaleG", Vector3.new(0.42, 0.08, 0.5),
			S * CFrame.new(bout + Vector3.new(s * 0.26, 0, 0)), NOIR, Enum.Material.Rubber)
	end

	-- l ecran : au-dessus du guidon, tourne vers les yeux du pilote
	if ecran then
		ecran.Size = Vector3.new(1.2, 0.7, 0.1)
		ecran.CFrame = CFrame.lookAt(S * (MAIN + Vector3.new(0, 0.3, -0.25)), S * (epaule + Vector3.new(0, 0.6, 0)))
		local g = ecran:FindFirstChildOfClass("SurfaceGui")
		if g then g.Face = Enum.NormalId.Front end
		ecran.Parent = modele
		tube("SupportEcran", MAIN + Vector3.new(0, 0, 0.02), MAIN + Vector3.new(0, 0.28, -0.22), 0.1, CHROME)
	end
	selle.Parent = modele
	modele.PrimaryPart = selle
	-- pour Exercices : le rayon de la manivelle et la penche du buste
	modele:SetAttribute("Rayon", RAYON)
	modele:SetAttribute("Penche", math.deg(PENCHE))
	return modele
end

local n = 0
for _, selle in ipairs(salle:GetChildren()) do
	if selle.Name == "VeloSport" then
		construire(selle)
		n += 1
	end
end
print(string.format("%d velos construits : pedalier a %.2f de la hanche (%.0f degres en avant), manivelle %.2f, guidon a (%.2f haut, %.2f devant)",
	n, DIST_PEDALIER, math.deg(ANGLE_SELLE), RAYON, MAIN.Y, -MAIN.Z))
if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
