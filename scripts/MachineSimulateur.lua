-- =========================================================
--  LA MACHINE DES SIMULATEURS, REALISTE  (a lancer UNE fois, dans Studio, en
--  Edit, APRES SalleSport.lua). Elle remplace le decor simple des 2
--  simulateurs par un vrai poste de "sim racing" : chassis en profiles alu,
--  siege baquet avec harnais, base et volant avec LED, pedalier, levier de
--  vitesses, 3 ecrans a bords fins retro-eclaires.
--  On GARDE le siege (SiegeSimulateur) et l ecran du milieu (EcranSimuCentre) :
--  les scripts SalleSportServeur et Arcade s en servent.
--  Les pieces du baquet et du poste sont TRAVERSABLES (CanCollide = false) :
--  sinon elles ejectaient le joueur de son siege.
-- =========================================================
-- ---- UN SIMULATEUR DE COURSE REALISTE, autour d un siege ----
-- On garde le SIEGE (SiegeSimulateur) et l ECRAN DU MILIEU (EcranSimuCentre) :
-- les scripts s en servent. Tout le reste est (re)construit autour, dans le
-- repere du siege : X = sa droite, Y = vers le haut, Z = vers l avant
-- (vers les ecrans), a partir du SOL sous le siege.
local function construireSimulateur(dossier, siege, ecranCentre, numero)
	local NOIR    = Color3.fromRGB(18, 18, 20)
	local CUIR    = Color3.fromRGB(28, 28, 32)
	local ALU     = Color3.fromRGB(120, 124, 130)
	local ROUGE   = Color3.fromRGB(200, 30, 35)
	local CYAN    = Color3.fromRGB(0, 225, 255)
	local avant = (siege.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit     -- a plat (le siege peut etre penche)
	-- le centre du simulateur : 1 stud devant le siege, au sol (1,3 sous l assise)
	local sol = Vector3.new(siege.Position.X, siege.Position.Y - 1.3, siege.Position.Z) + avant * 1
	local base = CFrame.lookAt(sol, sol + avant)                          -- -Z = vers l avant
	local function P(x, y, z) return base * CFrame.new(x, y, -z) end      -- z > 0 = vers les ecrans
	local function piece(nom, taille, cf, couleur, matiere, forme)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.Size = taille
		p.CFrame = cf
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		if forme then p.Shape = forme end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = dossier
		return p
	end

	-- le tapis
	piece("TapisSimu", Vector3.new(7.5, 0.06, 11.5), P(0, 0.03, 2.2), Color3.fromRGB(22, 22, 26), Enum.Material.Fabric)
	-- LE CHASSIS en profiles d aluminium : 2 longerons, des traverses, des patins
	for _, x in ipairs({-1.6, 1.6}) do
		piece("ProfileSimu", Vector3.new(0.35, 0.35, 9.4), P(x, 0.3, 2), ALU, Enum.Material.Metal)
		piece("NeonSousSimu", Vector3.new(0.08, 0.06, 9), P(x, 0.1, 2), CYAN, Enum.Material.Neon)
		for _, z in ipairs({-2.4, 6.4}) do
			piece("PatinSimu", Vector3.new(0.6, 0.12, 0.6), P(x, 0.06, z), NOIR, Enum.Material.Fabric)
		end
	end
	for _, z in ipairs({-2.3, 0.2, 2.6, 4.6, 6.3}) do
		piece("TraverseSimu", Vector3.new(3.55, 0.35, 0.35), P(0, 0.3, z), ALU, Enum.Material.Metal)
	end
	-- les glissieres du siege
	for _, x in ipairs({-0.7, 0.7}) do
		piece("GlissiereSimu", Vector3.new(0.25, 0.55, 2.6), P(x, 0.75, -1), NOIR, Enum.Material.Metal)
	end

	-- LE SIEGE BAQUET (l assise, c est le vrai siege, on le replace juste)
	siege.Size = Vector3.new(2.1, 0.45, 2.2)
	siege.CFrame = P(0, 1.25, -1) * CFrame.Angles(math.rad(-6), 0, 0)
	siege.Color = CUIR
	siege.Material = Enum.Material.Leather
	for _, x in ipairs({-1.05, 1.05}) do
		piece("BourreletCuisse", Vector3.new(0.35, 0.55, 2), P(x, 1.55, -0.95), CUIR, Enum.Material.Leather)
	end
	local dossierCF = P(0, 3.05, -2.25) * CFrame.Angles(math.rad(-14), 0, 0)
	piece("DossierBaquet", Vector3.new(2.3, 3.6, 0.45), dossierCF, CUIR, Enum.Material.Leather)
	for _, x in ipairs({-1.2, 1.2}) do
		piece("AileEpaule", Vector3.new(0.35, 2.4, 1.0), dossierCF * CFrame.new(x, 0.3, -0.35) * CFrame.Angles(0, math.rad(x > 0 and -18 or 18), 0), CUIR, Enum.Material.Leather)
		piece("LiserRouge", Vector3.new(0.06, 3.2, 0.06), dossierCF * CFrame.new(x * 0.62, 0, -0.24), ROUGE, Enum.Material.Leather)
	end
	piece("AppuiTete", Vector3.new(1.3, 0.5, 0.4), dossierCF * CFrame.new(0, 1.55, -0.05), CUIR, Enum.Material.Leather)
	-- le harnais 4 points (deux bretelles rouges et la ceinture)
	for _, x in ipairs({-0.42, 0.42}) do
		piece("Harnais", Vector3.new(0.3, 2.7, 0.04), dossierCF * CFrame.new(x, 0.25, -0.25), ROUGE, Enum.Material.Fabric)
	end
	piece("HarnaisCeinture", Vector3.new(1.9, 0.28, 0.04), P(0, 1.62, 0.08), ROUGE, Enum.Material.Fabric)
	local plaque = piece("PlaqueDossier", Vector3.new(1.6, 0.5, 0.05), dossierCF * CFrame.new(0, -0.6, 0.25), NOIR)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.PixelsPerStud = 60
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.LightInfluence = 0
	g.Parent = plaque
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = CYAN
	t.Text = "SIM RACING " .. numero
	t.Parent = g

	-- LE POSTE DE PILOTAGE : montants, plateau, base du volant, volant
	for _, x in ipairs({-1.6, 1.6}) do
		piece("MontantVolant", Vector3.new(0.35, 2.3, 0.35), P(x, 1.45, 1.7), ALU, Enum.Material.Metal)
	end
	piece("PlateauVolant", Vector3.new(3.55, 0.25, 1.1), P(0, 2.6, 1.7), ALU, Enum.Material.Metal)
	local inclinaison = CFrame.Angles(math.rad(18), 0, 0)               -- le volant penche vers le pilote
	local axe = P(0, 3.1, 1.3) * inclinaison
	piece("BaseVolant", Vector3.new(0.85, 0.85, 1.3), axe * CFrame.new(0, 0, -0.55), NOIR, Enum.Material.Metal)
	piece("AnneauBase", Vector3.new(0.06, 0.95, 0.95), axe * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, math.rad(90), 0), CYAN, Enum.Material.Neon, Enum.PartType.Cylinder)
	-- le volant : une jante ronde en 16 morceaux, et un moyeu en carbone
	local centreVolant = axe * CFrame.new(0, 0, 0.45)
	local R = 0.72
	for k = 0, 15 do
		local ang = k / 16 * math.pi * 2
		local poignee = math.abs(math.cos(ang)) > 0.8                 -- a gauche et a droite : les poignees
		piece("JanteVolant", Vector3.new(poignee and 0.24 or 0.16, 0.3, poignee and 0.24 or 0.16),
			centreVolant * CFrame.Angles(0, 0, ang) * CFrame.new(R, 0, 0), NOIR, poignee and Enum.Material.Fabric or Enum.Material.Leather)
	end
	piece("MoyeuVolant", Vector3.new(1.15, 0.7, 0.12), centreVolant, Color3.fromRGB(35, 35, 40), Enum.Material.SmoothPlastic)
	-- la rangee de LED du compte-tours : vert, jaune, rouge
	for k = -3, 3 do
		local c = (math.abs(k) <= 1) and Color3.fromRGB(40, 220, 80) or (math.abs(k) == 2 and Color3.fromRGB(255, 200, 0) or ROUGE)
		piece("LedVolant", Vector3.new(0.08, 0.08, 0.04), centreVolant * CFrame.new(k * 0.13, 0.25, 0.07), c, Enum.Material.Neon)
	end
	piece("EcranVolant", Vector3.new(0.45, 0.22, 0.03), centreVolant * CFrame.new(0, 0.02, 0.07), CYAN, Enum.Material.Neon)
	for _, x in ipairs({-0.5, 0.5}) do
		piece("PaletteVolant", Vector3.new(0.12, 0.55, 0.04), centreVolant * CFrame.new(x, -0.05, -0.12), ALU, Enum.Material.Metal)
	end

	-- LE PEDALIER : une plaque inclinee et 3 pedales (embrayage, frein, accelerateur)
	local plaqueP = P(0, 0.75, 5.2) * CFrame.Angles(math.rad(-40), 0, 0)
	piece("PlaquePedales", Vector3.new(2.2, 0.12, 1.5), plaqueP, NOIR, Enum.Material.Metal)
	for k, x in ipairs({-0.55, 0, 0.55}) do
		piece("PedaleSimu", Vector3.new(0.32, 0.06, 0.75), plaqueP * CFrame.new(x, 0.12, -0.05), (k == 2) and ROUGE or ALU, Enum.Material.Metal)
	end
	-- LE LEVIER DE VITESSES, a droite
	piece("SupportLevier", Vector3.new(0.5, 1.6, 0.5), P(2.1, 0.95, 0.6), ALU, Enum.Material.Metal)
	piece("BoiteLevier", Vector3.new(0.45, 0.25, 0.45), P(2.1, 1.85, 0.6), NOIR, Enum.Material.Metal)
	piece("TigeLevier", Vector3.new(0.08, 0.7, 0.08), P(2.1, 2.25, 0.62) * CFrame.Angles(math.rad(-10), 0, 0), ALU, Enum.Material.Metal)
	piece("PommeauLevier", Vector3.new(0.3, 0.3, 0.3), P(2.1, 2.6, 0.68), NOIR, Enum.Material.SmoothPlastic, Enum.PartType.Ball)

	-- LES 3 ECRANS, a bords noirs fins, sur leur pied, retro-eclaires
	local LARG, HAUT, RAYON, ANGLE = 5.2, 3.1, 5.6, 58
	local centreVue = P(0, 3.6, 0)                                      -- a peu pres les yeux du pilote
	for e, angle in ipairs({-ANGLE, 0, ANGLE}) do
		local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(avant)
		local pos = centreVue.Position + dir * RAYON
		local cf = CFrame.lookAt(pos, centreVue.Position)
		local ecran
		if e == 2 then
			ecran = ecranCentre
			ecran.Size = Vector3.new(LARG, HAUT, 0.12)
			ecran.CFrame = cf
		else
			ecran = piece("EcranSimu", Vector3.new(LARG, HAUT, 0.12), cf, Color3.fromRGB(8, 12, 20))
			local gs = Instance.new("SurfaceGui")
			gs.Face = Enum.NormalId.Front
			gs.PixelsPerStud = 40
			gs.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gs.LightInfluence = 0
			gs.Parent = ecran
			local ts = Instance.new("TextLabel")
			ts.Size = UDim2.fromScale(1, 1)
			ts.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
			ts.BorderSizePixel = 0
			ts.Font = Enum.Font.GothamBlack
			ts.TextScaled = true
			ts.TextColor3 = Color3.fromRGB(40, 70, 110)
			ts.Text = "RALLY MONTAGNE"
			ts.Parent = gs
		end
		local cadre = piece("CadreEcranSimu", Vector3.new(LARG + 0.16, HAUT + 0.16, 0.3), cf * CFrame.new(0, 0, 0.2), NOIR)
		local lumiere = Instance.new("SurfaceLight")
		lumiere.Face = Enum.NormalId.Back
		lumiere.Color = CYAN
		lumiere.Range = 7
		lumiere.Brightness = 1.2
		lumiere.Shadows = false
		lumiere.Parent = cadre
		piece("BrasEcran", Vector3.new(0.25, 0.25, 0.9), cf * CFrame.new(0, 0, 0.75), ALU, Enum.Material.Metal)
	end
	-- le pied des ecrans : un poteau et une barre derriere
	local derriere = P(0, 0, RAYON + 1.0)
	piece("PiedEcrans", Vector3.new(0.4, 3.6, 0.4), derriere * CFrame.new(0, 1.8, 0), ALU, Enum.Material.Metal)
	piece("SocleEcrans", Vector3.new(2.6, 0.15, 1.4), derriere * CFrame.new(0, 0.08, 0), NOIR, Enum.Material.Metal)
	piece("BarreEcrans", Vector3.new(2 * RAYON * math.sin(math.rad(ANGLE)) + 1, 0.25, 0.25), derriere * CFrame.new(0, 3.6, 0), ALU, Enum.Material.Metal)
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local enregistrement = ChangeHistoryService:TryBeginRecording("Simulateurs realistes")
local salle = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SalleSport")
local vieux = {SocleSimu = true, NeonSimu = true, DossierSimu = true, BordSimu = true, ColonneVolant = true,
	Volant = true, Pedale = true, EcranSimu = true, CadreEcranSimu = true, PiedEcrans = true}
local traversables = {BourreletCuisse = 1, DossierBaquet = 1, AileEpaule = 1, LiserRouge = 1, AppuiTete = 1,
	Harnais = 1, HarnaisCeinture = 1, PlaqueDossier = 1, MontantVolant = 1, PlateauVolant = 1, BaseVolant = 1,
	AnneauBase = 1, JanteVolant = 1, MoyeuVolant = 1, LedVolant = 1, EcranVolant = 1, PaletteVolant = 1,
	PlaquePedales = 1, PedaleSimu = 1, SupportLevier = 1, BoiteLevier = 1, TigeLevier = 1, PommeauLevier = 1, GlissiereSimu = 1}
for _, siege in ipairs(salle:GetChildren()) do
	if siege.Name == "SiegeSimulateur" then
		local ecranC, d = nil, math.huge
		for _, p in ipairs(salle:GetChildren()) do
			if p.Name == "EcranSimuCentre" then
				local dd = (p.Position - siege.Position).Magnitude
				if dd < d then ecranC, d = p, dd end
			end
		end
		for _, p in ipairs(salle:GetChildren()) do
			if vieux[p.Name] and (p.Position - siege.Position).Magnitude < 10 then p:Destroy() end
		end
		construireSimulateur(salle, siege, ecranC, siege:GetAttribute("Numero") or 1)
		-- le siege a PLAT (penche, il ejectait le joueur)
		local avant = (siege.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
		siege.CFrame = CFrame.lookAt(siege.Position, siege.Position + avant)
	end
end
for _, p in ipairs(salle:GetChildren()) do
	if traversables[p.Name] then p.CanCollide = false end
end
if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print("Simulateurs realistes construits")
