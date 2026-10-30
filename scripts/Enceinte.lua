-- ============================================================
--  L ENCEINTE DU STADE (generateur)
--  A lancer UNE fois dans Studio, en mode Edit.
--
--  Un grand MUR qui entoure TOUT : le circuit, le spawn et ses gradins.
--  Il ferme le decor (on ne voit plus le bout du Baseplate ni le vide),
--  comme les murs d un stade :
--    - beton clair, un pilier tous les ECART_PILIER studs ;
--    - en bas, cote interieur, une bande de panneaux colores (les
--      couleurs des ecuries) ;
--    - une bande lumineuse et une corniche en haut.
--  Il ne fait pas d ombre (CastShadow = false) : sinon, 110 studs de mur
--  plongeraient la piste dans le noir le matin et le soir.
--
--  Rien n est ecrit en dur : on DEMANDE au circuit et au spawn la place
--  qu ils prennent (les coins de toutes leurs pieces, vus du dessus),
--  on en fait le CONTOUR (l enveloppe convexe : un elastique tendu autour)
--  et on l ecarte de MARGE studs. Le mur suit ce contour.
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local HAUT          = 110    -- la hauteur du mur
local MARGE         = 40     -- studs entre le mur et ce qu il y a de plus pres
local EPAIS         = 4
local ECART_PILIER  = 60     -- un pilier tous les 60 studs
local H_PANNEAUX    = 10     -- la bande de panneaux en bas

local BETON   = Color3.fromRGB(165, 165, 170)
local SOMBRE  = Color3.fromRGB(70, 72, 80)
local NEON    = Color3.fromRGB(0, 200, 255)
local ECURIES = {
	Color3.fromRGB(215, 40, 45), Color3.fromRGB(40, 110, 230), Color3.fromRGB(40, 175, 80),
	Color3.fromRGB(255, 140, 30), Color3.fromRGB(140, 60, 210), Color3.fromRGB(240, 200, 30),
}

local circuit = workspace:WaitForChild("Circuit")
local zone = workspace:WaitForChild("ZoneSpawn")
local sol = workspace:FindFirstChild("Baseplate")

-- ---- ON REPART DE ZERO ----
local ancien = circuit:FindFirstChild("Enceinte")
if ancien then ancien:Destroy() end
local enceinte = Instance.new("Folder")
enceinte.Name = "Enceinte"

-- =========================================================
-- 1. LE CONTOUR : les coins (vus du dessus) de toutes les pieces
-- =========================================================
local points = {}
local yBas = sol and (sol.Position.Y + sol.Size.Y / 2) or 0
for _, racine in ipairs({circuit, zone}) do
	for _, p in ipairs(racine:GetDescendants()) do
		if p:IsA("BasePart") then
			for _, sx in ipairs({-1, 1}) do
				for _, sz in ipairs({-1, 1}) do
					local c = p.CFrame * Vector3.new(sx * p.Size.X / 2, 0, sz * p.Size.Z / 2)
					table.insert(points, Vector2.new(c.X, c.Z))
				end
			end
		end
	end
end

-- l ENVELOPPE CONVEXE (methode de la "chaine monotone") : on trie les
-- points, puis on fait le tour en ne gardant que ceux qui tournent
-- toujours dans le meme sens
table.sort(points, function(a, b) return a.X < b.X or (a.X == b.X and a.Y < b.Y) end)
local function tourne(o, a, b) return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X) end
local bas, haut = {}, {}
for _, p in ipairs(points) do
	while #bas >= 2 and tourne(bas[#bas - 1], bas[#bas], p) <= 0 do table.remove(bas) end
	table.insert(bas, p)
end
for i = #points, 1, -1 do
	local p = points[i]
	while #haut >= 2 and tourne(haut[#haut - 1], haut[#haut], p) <= 0 do table.remove(haut) end
	table.insert(haut, p)
end
table.remove(bas); table.remove(haut)
local contour = {}
for _, p in ipairs(bas) do table.insert(contour, p) end
for _, p in ipairs(haut) do table.insert(contour, p) end

-- on enleve les sommets trop proches (des cotes minuscules)
local propre = {}
for _, p in ipairs(contour) do
	if #propre == 0 or (p - propre[#propre]).Magnitude > 8 then table.insert(propre, p) end
end
if #propre > 2 and (propre[1] - propre[#propre]).Magnitude <= 8 then table.remove(propre) end
contour = propre

-- on l ECARTE de MARGE : chaque sommet recule le long de la bissectrice
-- (le contour tourne dans le sens inverse des aiguilles d une montre :
-- l exterieur est a DROITE de chaque cote)
local n = #contour
local ecarte = {}
for i = 1, n do
	local a, p, b = contour[(i - 2) % n + 1], contour[i], contour[i % n + 1]
	local d1, d2 = (p - a).Unit, (b - p).Unit
	local n1, n2 = Vector2.new(d1.Y, -d1.X), Vector2.new(d2.Y, -d2.X)    -- a droite = dehors
	local m = (n1 + n2).Unit
	local cosinus = math.max(0.35, m:Dot(n1))
	table.insert(ecarte, p + m * (MARGE / cosinus))
end

-- =========================================================
-- 2. LE MUR, cote par cote
-- =========================================================
local function piece(nom, taille, cf, couleur, matiere)
	local q = Instance.new("Part")
	q.Name = nom
	q.Size = taille
	q.CFrame = cf
	q.Color = couleur
	q.Material = matiere or Enum.Material.Concrete
	q.Anchored = true
	q.CastShadow = false
	q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	q.Parent = enceinte
	return q
end

local longueurTotale, nbPiliers, nbPanneaux = 0, 0, 0
for i = 1, n do
	local a, b = ecarte[i], ecarte[i % n + 1]
	local A, B = Vector3.new(a.X, yBas, a.Y), Vector3.new(b.X, yBas, b.Y)
	local l = (B - A).Magnitude
	longueurTotale += l
	-- le repere du cote : -Z le long du mur (de A vers B), +X vers
	-- l INTERIEUR (le contour tourne dans le sens inverse des aiguilles
	-- d une montre vu avec X et Z ; en 3D, la droite de Roblox est alors
	-- tournee vers le dedans)
	local cf = CFrame.lookAt((A + B) / 2, B)
	local function ici(x, y, z) return cf * CFrame.new(x, y, z) end
	-- le mur (un peu plus long : les coins se rejoignent)
	piece("Mur", Vector3.new(EPAIS, HAUT, l + EPAIS), ici(0, HAUT / 2, 0), BETON)
	-- la corniche en haut, et la bande lumineuse dessous (cote interieur)
	piece("Corniche", Vector3.new(EPAIS + 3, 2.5, l + EPAIS + 3), ici(0, HAUT + 1.25, 0), SOMBRE)
	local neon = piece("BandeLumineuse", Vector3.new(0.4, 1.2, l), ici(EPAIS / 2 + 0.2, HAUT - 6, 0), NEON, Enum.Material.Neon)
	neon.CanCollide = false
	-- les PILIERS (cote interieur), regulierement
	local nb = math.max(1, math.floor(l / ECART_PILIER))
	for k = 0, nb do
		local z = -l / 2 + k * l / nb
		piece("Pilier", Vector3.new(3, HAUT, 5), ici(EPAIS / 2 + 1.5, HAUT / 2, z), SOMBRE)
		nbPiliers += 1
	end
	-- les PANNEAUX en bas (cote interieur), un par travee, aux couleurs des ecuries
	for k = 0, nb - 1 do
		local z1, z2 = -l / 2 + k * l / nb + 3, -l / 2 + (k + 1) * l / nb - 3
		if z2 - z1 > 4 then
			nbPanneaux += 1
			local c = ECURIES[(nbPanneaux - 1) % #ECURIES + 1]
			piece("Panneau", Vector3.new(0.5, H_PANNEAUX, z2 - z1), ici(EPAIS / 2 + 0.25, 2 + H_PANNEAUX / 2, (z1 + z2) / 2), c, Enum.Material.SmoothPlastic)
		end
	end
end

enceinte.Parent = circuit
print(string.format("Enceinte : %d cotes, %.0f studs de mur, %d piliers, %d panneaux (%.0f studs de haut, a %d studs de tout)",
	n, longueurTotale, nbPiliers, nbPanneaux, HAUT, MARGE))
