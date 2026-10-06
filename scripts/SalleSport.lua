-- =========================================================
--  LA SALLE DE SPORT ET LES SIMULATEURS  (a lancer UNE fois, dans Studio,
--  en Edit). Dans le batiment VIDE du spawn (pas celui des bureaux), dans
--  la moitie du fond ; la moitie cote porte reste libre.
--
--    une paroi de verre au milieu, avec un passage en face de la porte
--    cote fenetres : la SALLE DE SPORT
--      - 3 tapis de course (le tapis POUSSE vers l arriere : il faut courir)
--      - 1 banc de musculation (assis : la barre monte et descend)
--      - 2 sacs de frappe suspendus (ils se balancent quand on les pousse)
--      - 2 velos (assis : le pedalier tourne)
--      - un ratelier d halteres
--    cote fond : la place des simulateurs (retires le 2026-10-06 : la 3D
--      ne s affichait pas sur l ecran)
--
--  Ce qui BOUGE (barre, pedaliers) est fait par le script
--  SalleSportServeur, en Play. Ici on ne construit que les objets.
--
--  Tout est pose dans le REPERE DU SOL du batiment (il est tourne de 0,6
--  degre) : X = de la porte vers le fond, Z = la largeur, Y = au-dessus du sol.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local VITESSE_TAPIS = 14     -- studs/s : un peu moins que la marche (16)
local NOIR   = Color3.fromRGB(25, 25, 28)
local GRIS   = Color3.fromRGB(70, 72, 78)
local ACIER  = Color3.fromRGB(150, 155, 162)
local NEON   = Color3.fromRGB(0, 225, 255)
local ROUGE  = Color3.fromRGB(220, 40, 40)
local BLEU_E = Color3.fromRGB(10, 28, 55)

local zone = workspace:WaitForChild("ZoneSpawn")
if zone:FindFirstChild("SalleSport") then
	print("La salle de sport existe deja : rien a faire")
	return
end
local enregistrement = ChangeHistoryService:TryBeginRecording("Salle de sport et simulateurs")

-- ---- 1. LE REPERE DU BATIMENT ----
-- le sol du batiment vide : le SolInterieur le plus a droite ; sa porte : la
-- PorteCoulissante la plus a droite
local sol, porte
for _, p in ipairs(zone:GetChildren()) do
	if p.Name == "SolInterieur" and (not sol or p.Position.X > sol.Position.X) then sol = p end
	if p.Name == "PorteCoulissante" and (not porte or p:GetPivot().Position.X > porte:GetPivot().Position.X) then porte = p end
end
assert(sol and porte, "batiment introuvable")
local repere = sol.CFrame * CFrame.new(0, sol.Size.Y / 2, 0)   -- sur le dessus du sol
local lp = repere:PointToObjectSpace(porte:GetPivot().Position)
local S = (lp.X < 0) and 1 or -1                  -- X "depuis la porte vers le fond"
local zPorte = lp.Z
local L = function(x, y, z) return repere * CFrame.new(x * S, y, z) end
local hx, hz = sol.Size.X / 2, sol.Size.Z / 2
-- la hauteur sous plafond : on la MESURE
local toit = workspace:Raycast(L(20, 1, 0).Position, Vector3.new(0, 60, 0))
local hPlafond = toit and (toit.Position.Y - L(0, 0, 0).Position.Y) or 20
-- le cote des fenetres : celui ou il y a des "Fenetre"
local zFen = -1
for _, p in ipairs(zone:GetChildren()) do
	if p.Name == "Fenetre" then
		local l = repere:PointToObjectSpace(p.Position)
		if math.abs(l.X) < hx + 2 and math.abs(l.Z) < hz + 3 then zFen = (l.Z > 0) and 1 or -1 break end
	end
end

local dossier = Instance.new("Folder")
dossier.Name = "SalleSport"
dossier.Parent = zone

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
local function texte(part, face, t, couleur, taillePx)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = taillePx or 40
	g.LightInfluence = 0
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Name = "Texte"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = BLEU_E
	l.BorderSizePixel = 0
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = couleur or NEON
	l.Text = t
	l.Parent = g
	return l
end
-- la face d une piece tournee vers un point (pour les ecrans et panneaux)
local function faceVers(part, point)
	local l = part.CFrame:PointToObjectSpace(point)
	local ax, ay, az = math.abs(l.X), math.abs(l.Y), math.abs(l.Z)
	if ax >= ay and ax >= az then return (l.X > 0) and Enum.NormalId.Right or Enum.NormalId.Left end
	if az >= ay then return (l.Z > 0) and Enum.NormalId.Back or Enum.NormalId.Front end
	return (l.Y > 0) and Enum.NormalId.Top or Enum.NormalId.Bottom
end

-- ---- 2. LA PAROI DE VERRE au milieu, avec un passage en face de la porte ----
local H_PAROI, PASSAGE = 9, 10
local z1, z2 = zPorte - PASSAGE / 2, zPorte + PASSAGE / 2
for _, morceau in ipairs({{-hz, z1}, {z2, hz}}) do
	local a, b = morceau[1], morceau[2]
	local v = piece("ParoiVerre", Vector3.new(0.3, H_PAROI, b - a), L(0, H_PAROI / 2, (a + b) / 2), Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
	v.Transparency = 0.6
	piece("ParoiNeon", Vector3.new(0.4, 0.2, b - a), L(0, H_PAROI, (a + b) / 2), NEON, Enum.Material.Neon)
end

-- les deux moities : la SPORT du cote des fenetres, les SIMULATEURS de l autre
local function Z(z) return z * zFen end      -- z > 0 = vers les fenetres
local xA, xB = 3, hx - 1.5                    -- de la paroi jusqu au fond

-- ---- 3. LES SOLS ----
piece("TapisSport", Vector3.new(xB - xA, 0.06, hz - 2), L((xA + xB) / 2, 0.03, Z(hz / 2 + 0.5)), Color3.fromRGB(38, 38, 42), Enum.Material.Fabric)
piece("MoquetteSimu", Vector3.new(xB - xA, 0.06, hz - 2), L((xA + xB) / 2, 0.03, Z(-hz / 2 - 0.5)), Color3.fromRGB(18, 18, 24), Enum.Material.Fabric)
piece("LigneSol", Vector3.new(xB - xA, 0.08, 0.3), L((xA + xB) / 2, 0.04, 0), NEON, Enum.Material.Neon)

-- ---- 4. LES TAPIS DE COURSE ----
-- le coureur regarde les fenetres ; le tapis le pousse vers l arriere
for k, x in ipairs({10, 17, 24}) do
	local zc = Z(hz - 9)
	local avant = Z(1)                      -- vers les fenetres
	piece("SocleTapis", Vector3.new(3.4, 0.5, 7.4), L(x, 0.25, zc), GRIS, Enum.Material.Metal)
	local bande = piece("TapisCourse", Vector3.new(2.6, 0.12, 6.4), L(x, 0.56, zc), NOIR, Enum.Material.Fabric)
	-- la vitesse d une piece ANCREE : elle ne bouge pas, mais elle entraine ce qui est dessus
	bande.AssemblyLinearVelocity = (L(0, 0, -avant).Position - L(0, 0, 0).Position).Unit * VITESSE_TAPIS
	for _, dx in ipairs({-1.5, 1.5}) do
		piece("MontantTapis", Vector3.new(0.25, 4, 0.25), L(x + dx, 2.5, zc + avant * 3.3), ACIER, Enum.Material.Metal)
		piece("RampeTapis", Vector3.new(0.2, 0.2, 2.6), L(x + dx, 3.6, zc + avant * 2.1), ACIER, Enum.Material.Metal)
	end
	local console = piece("ConsoleTapis", Vector3.new(3.2, 1.3, 0.25), L(x, 4.3, zc + avant * 3.4), BLEU_E)
	texte(console, faceVers(console, L(x, 4.3, zc).Position), "TAPIS " .. k .. "\n14 km/h", NEON, 30)
end

-- ---- 5. LE BANC DE MUSCULATION ----
do
	local x, zc = 34, Z(hz - 10)
	local avant = Z(1)
	piece("PiedBanc", Vector3.new(0.8, 1.4, 4), L(x, 0.7, zc), GRIS, Enum.Material.Metal)
	piece("CoussinBanc", Vector3.new(1.6, 0.4, 4.6), L(x, 1.6, zc - avant * 0.3), ROUGE, Enum.Material.Fabric)
	local assise = Instance.new("Seat")
	assise.Name = "BancMuscu"
	assise.Anchored = true
	assise.Size = Vector3.new(1.6, 0.4, 1.6)
	assise.CFrame = CFrame.lookAt(L(x, 2, zc + avant * 1.6).Position, L(x, 2, zc + avant * 10).Position)
	assise.Color = ROUGE
	assise.Material = Enum.Material.Fabric
	assise.Parent = dossier
	for _, dx in ipairs({-2.6, 2.6}) do
		piece("MontantBanc", Vector3.new(0.3, 5.2, 0.3), L(x + dx, 2.6, zc + avant * 2.6), ACIER, Enum.Material.Metal)
	end
	local barre = piece("Barre", Vector3.new(6.4, 0.2, 0.2), L(x, 4.6, zc + avant * 2.6), ACIER, Enum.Material.Metal)
	for _, dx in ipairs({-3.1, -2.9, 2.9, 3.1}) do     -- en dehors des montants (a +-2,6)
		local disque = piece("DisqueBarre", Vector3.new(0.25, 1.6, 1.6), L(x + dx, 4.6, zc + avant * 2.6), NOIR, Enum.Material.Metal, Enum.PartType.Cylinder)
		-- les disques suivent la barre : soudes a elle
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = barre, disque
		w.Parent = disque
		disque.Anchored = false
	end
	local ecran = piece("EcranBanc", Vector3.new(3, 1.4, 0.2), L(x, 6.4, zc + avant * 2.8), BLEU_E)
	texte(ecran, faceVers(ecran, L(x, 6.4, zc).Position), "REPS : 0", NEON, 30)
end

-- ---- 6. LES SACS DE FRAPPE ----
for _, x in ipairs({44, 50}) do
	local zc = Z(hz - 10)
	local crochet = piece("CrochetSac", Vector3.new(0.6, 0.4, 0.6), L(x, hPlafond - 0.3, zc), ACIER, Enum.Material.Metal)
	local sac = piece("SacFrappe", Vector3.new(4.5, 1.8, 1.8), L(x, 5.2, zc) * CFrame.Angles(0, 0, math.rad(90)), ROUGE, Enum.Material.Leather, Enum.PartType.Cylinder)
	sac.Anchored = false
	sac.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.2)
	local a0 = Instance.new("Attachment") a0.Parent = crochet a0.Position = Vector3.new(0, -0.2, 0)
	local a1 = Instance.new("Attachment") a1.Parent = sac a1.Position = Vector3.new(2.25, 0, 0)   -- le haut du sac (son axe X, couche)
	local corde = Instance.new("RopeConstraint")
	corde.Attachment0, corde.Attachment1 = a0, a1
	corde.Length = (hPlafond - 0.5) - (5.2 + 2.25)
	corde.Visible = true
	corde.Color = BrickColor.new("Dark stone grey")
	corde.Thickness = 0.12
	corde.Parent = sac
end

-- ---- 7. LES VELOS ----
for _, x in ipairs({34, 40}) do
	local zc = Z(4)
	local avant = Z(1)
	piece("CadreVelo", Vector3.new(0.4, 0.4, 3.6), L(x, 0.4, zc), GRIS, Enum.Material.Metal)
	piece("MontantVelo", Vector3.new(0.3, 2.2, 0.3), L(x, 1.5, zc - avant * 0.8), GRIS, Enum.Material.Metal)
	local selle = Instance.new("Seat")
	selle.Name = "VeloSport"
	selle.Anchored = true
	selle.Size = Vector3.new(1.2, 0.3, 1.4)
	selle.CFrame = CFrame.lookAt(L(x, 2.7, zc - avant * 0.8).Position, L(x, 2.7, zc + avant * 10).Position)
	selle.Color = NOIR
	selle.Parent = dossier
	piece("GuidonVelo", Vector3.new(1.8, 0.2, 0.2), L(x, 3.6, zc + avant * 1.4), ACIER, Enum.Material.Metal)
	piece("ColonneVelo", Vector3.new(0.3, 3.2, 0.3), L(x, 1.8, zc + avant * 1.4), GRIS, Enum.Material.Metal)
	piece("Pedalier", Vector3.new(0.3, 1.6, 1.6), L(x, 1.1, zc + avant * 0.3), ACIER, Enum.Material.Metal, Enum.PartType.Cylinder)
	local ecran = piece("EcranVelo", Vector3.new(1.6, 0.9, 0.15), L(x, 4.1, zc + avant * 1.5), BLEU_E)
	texte(ecran, faceVers(ecran, L(x, 4.1, zc).Position), "0.00 km", NEON, 30)
end

-- ---- 8. LE RATELIER D HALTERES ----
do
	local zc = Z(3)
	piece("Ratelier", Vector3.new(8, 2.4, 1.4), L(49, 1.2, zc), GRIS, Enum.Material.Metal)
	for k = 0, 5 do
		local x = 45.8 + k * 1.3
		piece("Haltere", Vector3.new(1, 0.25, 0.25), L(x, 2.55, zc), ACIER, Enum.Material.Metal)
		for _, dz in ipairs({-0.45, 0.45}) do
			piece("PoidsHaltere", Vector3.new(0.3, 0.6, 0.6), L(x, 2.55, zc + dz) * CFrame.Angles(0, math.rad(90), 0), NOIR, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
end

-- ---- 10. LES PANNEAUX ----
for _, info in ipairs({{"SALLE DE SPORT", Z(hz / 2)}, {"SIMULATEURS DE COURSE", Z(-hz / 2)}}) do
	local pan = piece("PanneauSalle", Vector3.new(0.3, 2, 12), L(0.3, H_PAROI + 1.6, info[2]), BLEU_E)
	texte(pan, faceVers(pan, L(-10, H_PAROI + 1.6, info[2]).Position), info[1], NEON, 30)
end

if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(string.format("Salle de sport : %d objets ; plafond a %.1f studs ; fenetres cote z %d", #dossier:GetChildren(), hPlafond, zFen))
