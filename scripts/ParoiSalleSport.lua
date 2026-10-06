-- =========================================================
--  LA PAROI DE VERRE DE LA SALLE DE SPORT, EN PROPRE  (a lancer UNE fois,
--  dans Studio, en Edit, APRES SalleSport.lua)
--  La paroi qui coupe le batiment en 2 (cote porte / cote salle de sport)
--  n allait qu a 9 studs de haut. On en fait une vraie verriere :
--    - du verre jusqu au plafond, des montants gris fonce reguliers ;
--    - un portail autour du passage, avec l enseigne lumineuse ;
--    - une bande depolie a hauteur des yeux (on voit qu il y a une vitre) ;
--    - une plinthe en bas ; un panneau au-dessus du coin rameurs / tractions.
--  Les 2 vieux panneaux noirs (PanneauSalle) sont enleves.
--
--  RIEN N EST ECRIT EN DUR : on DEMANDE a la paroi ou sont les vitres
--  (ParoiVerre) et donc le passage (le trou entre les deux), et au plafond
--  sa hauteur (un rayon vers le haut). Repere : celui du sol de la salle de
--  sport (X = de la porte vers la salle, Y = haut, Z = le long de la paroi).
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local zone = workspace:WaitForChild("ZoneSpawn")
local salle = zone:WaitForChild("SalleSport")
local F = salle:WaitForChild("TapisSport").CFrame
local moquette = salle:WaitForChild("MoquetteSimu")

local GRAPHITE = Color3.fromRGB(38, 40, 46)
local NOIR     = Color3.fromRGB(18, 18, 20)
local NEON     = Color3.fromRGB(0, 225, 255)
local BLANC    = Color3.new(1, 1, 1)

local PAS_MONTANTS = 5          -- un montant tous les ~5 studs
local H_DEPOLI = 4.5            -- la bande depolie, a hauteur des yeux

-- ---- ON DEMANDE A LA PAROI : les 2 vitres, donc le passage ----
local vitres = {}
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "ParoiVerre" then
		local l = F:PointToObjectSpace(p.Position)
		table.insert(vitres, {part = p, x = l.X, z1 = l.Z - p.Size.Z / 2, z2 = l.Z + p.Size.Z / 2, h = l.Y + p.Size.Y / 2, ep = p.Size.X})
	end
end
assert(#vitres == 2, "il faut les 2 vitres de la paroi")
table.sort(vitres, function(a, b) return a.z1 < b.z1 end)
local X = vitres[1].x                                   -- le plan de la paroi
local zPassage1, zPassage2 = vitres[1].z2, vitres[2].z1 -- le passage : entre les deux vitres
local H_VITRE = vitres[1].h
-- le plafond, au-dessus du passage
local hit = workspace:Raycast(F * Vector3.new(X, 1, (zPassage1 + zPassage2) / 2), F:VectorToWorldSpace(Vector3.new(0, 50, 0)))
local H_PLAFOND = (hit and F:PointToObjectSpace(hit.Position).Y or 20) - 0.4    -- on s arrete juste dessous (les lampes)

local enregistrement = ChangeHistoryService:TryBeginRecording("Paroi de la salle de sport")
local ancien = salle:FindFirstChild("ParoiPropre")
if ancien then ancien:Destroy() end
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "PanneauSalle" then p:Destroy() end
end
local modele = Instance.new("Model")
modele.Name = "ParoiPropre"
modele.Parent = salle

local function piece(nom, centre, taille, couleur, matiere, transparence)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = F * CFrame.new(centre)
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Transparency = transparence or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = modele
	return p
end
-- un panneau avec du texte, sa face avant tournee vers "sens" (-1 = cote porte, +1 = cote salle)
local function enseigne(nom, centre, largeur, hauteur, sens, lignes)
	local pos = (F * CFrame.new(centre)).Position
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = Vector3.new(largeur, hauteur, 0.1)
	p.CFrame = CFrame.lookAt(pos, pos + F:VectorToWorldSpace(Vector3.new(sens, 0, 0)), F.UpVector)
	p.Color = NOIR
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = modele
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0
	g.Parent = p
	local y = 0
	for _, l in ipairs(lignes) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.04, y)
		t.Size = UDim2.fromScale(0.92, l.h)
		t.Font = l.police or Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = l.couleur or NEON
		t.Text = l.texte
		t.Parent = g
		y += l.h
	end
	return p
end

local verre = vitres[1].part
local EP = vitres[1].ep

-- 1. CHAQUE VITRE : le verre du haut (jusqu au plafond), les montants, la bande depolie, la plinthe
for _, v in ipairs(vitres) do
	local long = v.z2 - v.z1
	local milieu = (v.z1 + v.z2) / 2
	local haut = piece("VerreHaut", Vector3.new(X, (H_VITRE + H_PLAFOND) / 2, milieu), Vector3.new(EP, H_PLAFOND - H_VITRE, long), verre.Color, verre.Material, verre.Transparency)
	haut.CastShadow = false
	local n = math.max(1, math.round(long / PAS_MONTANTS))         -- nombre de carreaux
	for k = 0, n do
		local z = v.z1 + k * long / n
		piece("MontantParoi", Vector3.new(X, H_PLAFOND / 2, z), Vector3.new(0.5, H_PLAFOND, 0.35), GRAPHITE)
	end
	piece("TraverseParoi", Vector3.new(X, H_VITRE, milieu), Vector3.new(0.45, 0.35, long), GRAPHITE)
	piece("PlintheParoi", Vector3.new(X, 0.25, milieu), Vector3.new(0.55, 0.5, long), GRAPHITE)
	for _, s in ipairs({-1, 1}) do       -- la bande depolie, collee sur les 2 faces du verre
		local b = piece("BandeDepolie", Vector3.new(X + s * (EP / 2 + 0.01), H_DEPOLI, milieu), Vector3.new(0.02, 0.5, long), BLANC, Enum.Material.SmoothPlastic, 0.45)
		b.CanCollide = false
	end
end

-- 2. LE PORTAIL autour du passage, et le bandeau de l enseigne (les 2 cotes)
local LARGE_PORTAIL = 1.0
local H_LINTEAU = math.min(H_VITRE + 1.5, H_PLAFOND - 4)
for _, z in ipairs({zPassage1 - LARGE_PORTAIL / 2, zPassage2 + LARGE_PORTAIL / 2}) do
	piece("PilierPassage", Vector3.new(X, H_PLAFOND / 2, z), Vector3.new(0.9, H_PLAFOND, LARGE_PORTAIL), GRAPHITE)
	for _, s in ipairs({-1, 1}) do
		piece("NeonPassage", Vector3.new(X + s * 0.47, H_LINTEAU / 2, z), Vector3.new(0.05, H_LINTEAU - 0.5, 0.15), NEON, Enum.Material.Neon)
	end
end
local zM = (zPassage1 + zPassage2) / 2
local largeBandeau = zPassage2 - zPassage1 + LARGE_PORTAIL * 2
local hBandeau = 4
piece("BandeauPassage", Vector3.new(X, H_LINTEAU + hBandeau / 2, zM), Vector3.new(0.9, hBandeau, largeBandeau), GRAPHITE)
piece("NeonLinteau", Vector3.new(X, H_LINTEAU + 0.03, zM), Vector3.new(0.92, 0.06, largeBandeau), NEON, Enum.Material.Neon)
piece("VerreHaut", Vector3.new(X, (H_LINTEAU + hBandeau + H_PLAFOND) / 2, zM), Vector3.new(EP, H_PLAFOND - H_LINTEAU - hBandeau, zPassage2 - zPassage1), verre.Color, verre.Material, verre.Transparency)
enseigne("EnseigneSalle", Vector3.new(X - 0.5, H_LINTEAU + hBandeau / 2, zM), largeBandeau - 1, hBandeau - 0.8, -1, {
	{texte = "SALLE DE SPORT", h = 0.62},
	{texte = "MUSCU · CARDIO · TRACTIONS", h = 0.38, couleur = BLANC, police = Enum.Font.GothamBold},
})
enseigne("EnseigneSalle", Vector3.new(X + 0.5, H_LINTEAU + hBandeau / 2, zM), largeBandeau - 1, hBandeau - 0.8, 1, {
	{texte = "BON COURAGE !", h = 0.62},
	{texte = "la sortie, c est par ici", h = 0.38, couleur = BLANC, police = Enum.Font.GothamBold},
})

-- 3. LE PANNEAU du coin rameurs / tractions (au-dessus de la moquette, les 2 cotes)
local zMoq = F:PointToObjectSpace(moquette.Position).Z
for _, s in ipairs({-1, 1}) do
	enseigne("PanneauZone", Vector3.new(X + s * 0.32, H_VITRE + 2.2, zMoq), 12, 2.4, s, {
		{texte = "RAMEURS · TRACTIONS", h = 1},
	})
end

if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(string.format("Paroi : vitres hautes de %.1f, plafond a %.1f, passage de z=%.1f a %.1f, %d pieces",
	H_VITRE, H_PLAFOND, zPassage1, zPassage2, #modele:GetChildren()))
