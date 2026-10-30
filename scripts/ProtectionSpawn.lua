-- ============================================================
--  LA CLOTURE QUI PROTEGE LE SPAWN (generateur)
--  A lancer UNE fois dans Studio, en mode Edit.
--
--  Entre le spawn et la ligne droite du depart, il n y a que du sol plat
--  (le Baseplate) : en sortant par les portails du sous-sol, on pouvait
--  marcher tout droit sur la piste, devant les voitures. On pose une
--  CLOTURE VITREE le long de la route, COTE SPAWN :
--    - 16 studs de haut : un saut normal fait 7 studs, on ne passe pas ;
--    - transparente : on voit la course a travers ;
--    - 5 studs derriere le bord de la route (derriere les barrieres) :
--      elle ne gene jamais les voitures.
--
--  Rien n est ecrit en dur : on DEMANDE a la route quels morceaux sont
--  "en face du spawn" (a moins de DISTANCE_MAX du SpawnLocation, et pas
--  en hauteur), et de quel cote est le spawn pour chacun.
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local circuit = workspace:WaitForChild("Circuit")
local route   = circuit:WaitForChild("Route")
local spawn   = workspace:WaitForChild("ZoneSpawn"):WaitForChild("SpawnLocation")

-- ---- LES REGLAGES ----
local DISTANCE_MAX = 345   -- les morceaux de route a moins de 345 studs du spawn (la grille + la ligne droite)
local Y_MAX        = 10    -- ... et au niveau du sol (pas la route de la montagne)
local RECUL        = 5     -- la cloture, a 5 studs du bord de la route
local HAUT         = 16    -- sa hauteur

local POTEAU = Color3.fromRGB(60, 62, 70)
local VERRE  = Color3.fromRGB(170, 210, 240)

-- ---- ON REPART DE ZERO ----
local ancien = circuit:FindFirstChild("ProtectionSpawn")
if ancien then ancien:Destroy() end
local dossier = Instance.new("Folder")
dossier.Name = "ProtectionSpawn"

-- ---- 1. LES MORCEAUX DE ROUTE EN FACE DU SPAWN, DANS L ORDRE ----
local morceaux = {}
for _, p in ipairs(route:GetChildren()) do
	local n = tonumber(p.Name:match("^Route(%d+)$"))
	if n and p.Position.Y < Y_MAX and ((spawn.Position - p.Position) * Vector3.new(1, 0, 1)).Magnitude < DISTANCE_MAX then
		table.insert(morceaux, {n = n, p = p})
	end
end
table.sort(morceaux, function(a, b) return a.n < b.n end)
-- la route fait une BOUCLE : la ligne droite passe de Route191 a Route1.
-- On commence donc la liste juste apres le plus GRAND trou de numeros,
-- en comptant en boucle (modulo le dernier numero : de 191 a 1, il n y
-- a qu un pas).
local nMax = 0
for _, p in ipairs(route:GetChildren()) do
	nMax = math.max(nMax, tonumber(p.Name:match("^Route(%d+)$")) or 0)
end
local coupe, plusGrand = 1, 0
for i = 1, #morceaux do
	local suivant = morceaux[i % #morceaux + 1]
	local trou = (suivant.n - morceaux[i].n) % nMax
	if trou > plusGrand then coupe, plusGrand = i % #morceaux + 1, trou end
end
local ordre = {}
for k = 0, #morceaux - 1 do
	table.insert(ordre, morceaux[(coupe - 1 + k) % #morceaux + 1].p)
end

-- ---- 2. LES POINTS DE LA CLOTURE : au bord COTE SPAWN, + RECUL ----
-- Si la place est deja prise (le mat des feux de depart est plante au
-- bord de la route, cote spawn), on RECULE d un stud et on reessaie.
local RECUL_MAX = 100     -- (devant les stands, elle passe DERRIERE leur batiment : ~55 studs)
local sol = RaycastParams.new()
sol.FilterType = Enum.RaycastFilterType.Exclude
sol.FilterDescendantsInstances = {route, dossier, workspace:FindFirstChild("Voitures")}
local gene = OverlapParams.new()
gene.FilterType = Enum.RaycastFilterType.Exclude
gene.FilterDescendantsInstances = {route, dossier, workspace:FindFirstChild("Voitures")}
local sonde = Instance.new("Part")      -- un morceau de cloture "pour essayer"
sonde.Anchored, sonde.CanCollide = true, false
sonde.Transparency = 1

-- la place est-elle libre ? (le sol, lui, ne compte pas)
local function libre(cf, taille)
	sonde.Size, sonde.CFrame = taille, cf
	sonde.Parent = workspace
	local ok = true
	for _, q in ipairs(workspace:GetPartsInPart(sonde, gene)) do
		if q.Name ~= "Baseplate" and not q:IsA("Terrain") then ok = false end
	end
	sonde.Parent = nil
	return ok
end

local talus = circuit:FindFirstChild("Talus")
local points = {}
local recules = 0
for _, p in ipairs(ordre) do
	local versSpawn = (spawn.Position - p.Position) * Vector3.new(1, 0, 1)
	local cote = (p.CFrame.RightVector:Dot(versSpawn) > 0) and 1 or -1
	local recul, bord, y = RECUL, nil, nil
	repeat
		bord = p.CFrame * Vector3.new(cote * (p.Size.X / 2 + recul), 0, 0)
		-- le sol a cet endroit (le Baseplate, un talus...)
		local hit = workspace:Raycast(Vector3.new(bord.X, p.Position.Y + 30, bord.Z), Vector3.new(0, -60, 0), sol)
		y = hit and hit.Position.Y or (p.Position.Y - 1)
		-- ce qu on a touche doit etre du SOL (le rayon tombait sur le socle
		-- des feux de depart, et la cloture se posait dessus)
		local surLeSol = not hit or hit.Instance.Name == "Baseplate" or hit.Instance:IsA("Terrain")
			or (talus ~= nil and hit.Instance:IsDescendantOf(talus))
		-- un bout de cloture de DEUX longueurs de morceau, a cet endroit (les
		-- panneaux vont en biais vers les voisins : les voisins d un
		-- obstacle doivent reculer aussi)
		local cf = CFrame.lookAt(Vector3.new(bord.X, y + HAUT / 2 + 0.3, bord.Z),
			Vector3.new(bord.X, y + HAUT / 2 + 0.3, bord.Z) + p.CFrame.LookVector)
		local ok = surLeSol and libre(cf, Vector3.new(1, HAUT, p.Size.Z * 2 + 4))
		if not ok then recul += 1 end
	until ok or recul > RECUL_MAX
	if recul > RECUL then recules += 1 end
	table.insert(points, Vector3.new(bord.X, y, bord.Z))
end
sonde:Destroy()

-- ---- 3. LA CLOTURE : un poteau a chaque point, un panneau de verre entre deux ----
local function piece(nom, taille, cf, couleur, matiere)
	local q = Instance.new("Part")
	q.Name = nom
	q.Size = taille
	q.CFrame = cf
	q.Color = couleur
	q.Material = matiere
	q.Anchored = true
	q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	q.Parent = dossier
	return q
end
for i, pt in ipairs(points) do
	piece("Poteau", Vector3.new(0.8, HAUT + 1, 0.8), CFrame.new(pt + Vector3.new(0, (HAUT + 1) / 2 - 0.5, 0)), POTEAU, Enum.Material.Metal)
	local suivant = points[i + 1]
	if suivant then
		-- le bas du panneau : le plus bas des deux points (pas de trou dessous)
		local bas = math.min(pt.Y, suivant.Y)
		local a = Vector3.new(pt.X, bas, pt.Z)
		local b = Vector3.new(suivant.X, bas, suivant.Z)
		local milieu = (a + b) / 2
		local longueur = (b - a).Magnitude
		local haut = HAUT + math.abs(pt.Y - suivant.Y)
		local vitre = piece("Vitre", Vector3.new(0.3, haut, longueur),
			CFrame.lookAt(milieu + Vector3.new(0, haut / 2, 0), b + Vector3.new(0, haut / 2, 0)), VERRE, Enum.Material.Glass)
		vitre.Transparency = 0.6
		vitre.CastShadow = false
		vitre.CanQuery = false             -- les cameras du bureau voient a travers
		-- la main courante, tout en haut
		local h = Vector3.new(0, haut + 0.3, 0)
		piece("Main", Vector3.new(0.6, 0.6, longueur + 0.8), CFrame.lookAt(milieu + h, b + h), POTEAU, Enum.Material.Metal)
	end
end

dossier.Parent = circuit
print(string.format("Cloture du spawn : %d morceaux de route (de %s a %s), %d poteaux, %d endroits recules",
	#ordre, ordre[1].Name, ordre[#ordre].Name, #points, recules))
