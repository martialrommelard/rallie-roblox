-- ============================================================
--  LA RONCE (generateur de carrosserie)
--  A lancer UNE fois dans Studio, en mode Edit, APRES VoitureRally.lua.
--
--  Une voiture de DEFENSE : noire, couverte de BRANCHES rouge sombre et
--  d EPINES tout autour (devant, sur les flancs, et surtout derriere).
--    - les epines portent l attribut "Epine" : le script Degats abime
--      PLUS FORT la voiture qui les touche (EPINE_BONUS), et l epine
--      elle-meme s use peu (EPINE_ARMURE) : elle protege la Ronce ;
--    - elles ne cognent pas (CanCollide false : la voiture se conduit
--      pareil), mais elles "sentent" le contact (CanTouch) ;
--    - une epine arrachee reste sur la piste... et pique encore.
--
--  Comme la Flash : on COPIE ServerStorage.VoitureModele (memes roues,
--  meme moteur, memes morceaux) et on la rhabille. Rangee dans
--  ServerStorage.VoitureRonce, avec l attribut "Carrosserie".
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")

local NOM     = "VoitureRonce"
local NOIR    = Color3.fromRGB(26, 22, 30)     -- la caisse (peinture)
local JANTE   = Color3.fromRGB(70, 12, 26)
local BRANCHE = Color3.fromRGB(105, 18, 34)    -- les branches
local SEVE    = Color3.fromRGB(200, 25, 70)    -- les veines lumineuses dans les branches
local EPINE   = Color3.fromRGB(150, 22, 40)    -- les epines
local L_EPINE = 1.4                            -- longueur des epines des flancs (derriere : plus longues)

-- les pieces de rally qu on enleve
local A_ENLEVER = {
	RampePhares = true, PhareRampe = true, PriseToit = true,
	PareBoueG = true, PareBoueD = true, CrochetAv = true, CrochetAr = true,
}
-- les "RALLYE" qu on enleve (on garde le numero des portieres)
local SANS_DECO = {Caisse = true, PareBrise = true}

-- ---- ON REPART DE ZERO ----
local ancien = ServerStorage:FindFirstChild(NOM)
if ancien then ancien:Destroy() end
local v = ServerStorage:WaitForChild("VoitureModele"):Clone()
v.Name = NOM
v:SetAttribute("Carrosserie", NOM)
local chassis = v:WaitForChild("Chassis")
local function ici(x, y, z) return chassis.CFrame * CFrame.new(x, y, z) end   -- (repere du chassis : avant = -Z, gauche = -X)

-- 1. ON ENLEVE le rally, 2. ON REPEINT en noir
for _, p in ipairs(v:GetDescendants()) do
	if p:IsA("BasePart") and A_ENLEVER[p.Name] then p:Destroy() end
end
for _, p in ipairs(v:GetChildren()) do
	if SANS_DECO[p.Name] then
		for _, g in ipairs(p:GetChildren()) do
			if g:IsA("SurfaceGui") and g.Name == "Deco" then g:Destroy() end
		end
	end
end
for _, p in ipairs(v:GetDescendants()) do
	if p:IsA("BasePart") then
		if p:GetAttribute("Peinture") then p.Color = NOIR end
		if p.Name:match("^Jante") then p.Color = JANTE end
		if p.Name:match("^Arceau") then p.Color = BRANCHE end
	end
end

-- une piece ajoutee : soudee au chassis, du meme MORCEAU que la piece
-- qu elle decore (elle tombe avec elle), et sans poids
local function ajout(nom, classe, taille, cf, couleur, matiere, morceau)
	local p = Instance.new(classe)
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere
	p.Massless = true
	p.CanCollide, p.CanQuery = false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p:SetAttribute("Morceau", morceau)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = chassis, p
	w.Parent = p
	p.Parent = v
	return p
end

-- =========================================================
-- 3. LES EPINES
-- Une epine = deux coins (WedgePart) colles par le dessous : un triangle
-- pointu (mesure : un coin est HAUT a +Z et a zero a -Z ; retourne, il
-- complete l autre). Elle part de "pied" dans la "direction".
-- =========================================================
local nbEpines = 0
local function epine(pied, direction, longueur, morceau)
	local centre = pied + direction.Unit * (longueur / 2)
	-- (un "haut" pas parallele a la direction, pour lookAt)
	local haut = (math.abs(direction.Unit.Y) > 0.9) and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt(centre, centre + direction, haut)
	local large = math.max(0.5, longueur * 0.42)
	for k = 1, 2 do
		local morceauCf = (k == 1) and (cf * CFrame.new(0, large / 4, 0))
			or (cf * CFrame.new(0, -large / 4, 0) * CFrame.Angles(0, 0, math.pi))
		-- (le coin a son bout fin a -Z, sur sa face du dessous : la pointe)
		local c = ajout("Epine", "WedgePart", Vector3.new(0.35, large / 2, longueur), morceauCf,
			EPINE, Enum.Material.Metal, morceau)
		c.CanTouch = true                -- c est elle qui "pique" (script Degats)
		c:SetAttribute("Epine", true)
	end
	nbEpines += 1
end

-- les pieces de la voiture qu on va garnir (leur position dans le repere du chassis)
local function lp(nom) local p = v:FindFirstChild(nom); return p and chassis.CFrame:ToObjectSpace(p.CFrame), p end

-- DERRIERE (la defense) : 5 grandes epines qui sortent du pare-chocs arriere
local cfAr, pcAr = lp("PareChocsAr")
if pcAr then
	local zAr = cfAr.Position.Z + pcAr.Size.Z / 2
	for i, x in ipairs({-2.6, -1.3, 0, 1.3, 2.6}) do
		local ecarte = Vector3.new(x * 0.18, (i % 2 == 0) and 0.25 or 0, 1)
		epine(ici(x, cfAr.Position.Y, zAr - 0.1).Position, chassis.CFrame:VectorToWorldSpace(ecarte), (x == 0) and 2.6 or 2, pcAr:GetAttribute("Morceau"))
	end
end
-- DEVANT : 2 cornes sur le pare-chocs avant
local cfAv, pcAv = lp("PareChocsAv")
if pcAv then
	local zAv = cfAv.Position.Z - pcAv.Size.Z / 2
	for _, x in ipairs({-2.4, 2.4}) do
		epine(ici(x, cfAv.Position.Y + 0.2, zAv + 0.1).Position, chassis.CFrame:VectorToWorldSpace(Vector3.new(x * 0.12, 0.25, -1)), 1.8, pcAv:GetAttribute("Morceau"))
	end
end
-- LES FLANCS : sur les ailes (avant et arriere) et en bas des portieres,
-- vers l exterieur, un peu vers l arriere (comme des epines de ronce)
for _, cote in ipairs({{"G", -1}, {"D", 1}}) do
	local s, sx = cote[1], cote[2]
	for _, nom in ipairs({"AileAv" .. s, "AileAr" .. s}) do
		local cf, aile = lp(nom)
		if aile then
			local x = cf.Position.X + sx * aile.Size.X / 2
			for _, dz in ipairs({-0.7, 0.7}) do
				epine(ici(x - sx * 0.1, cf.Position.Y - 0.3, cf.Position.Z + dz).Position,
					chassis.CFrame:VectorToWorldSpace(Vector3.new(sx, 0.35, 0.45)), L_EPINE, aile:GetAttribute("Morceau"))
			end
		end
	end
	local cf, portiere = lp("Portiere" .. s)
	if portiere then
		local x = cf.Position.X + sx * portiere.Size.X / 2
		for _, dz in ipairs({-1.3, 1.3}) do
			epine(ici(x - sx * 0.05, cf.Position.Y - portiere.Size.Y / 2 + 0.25, cf.Position.Z + dz).Position,
				chassis.CFrame:VectorToWorldSpace(Vector3.new(sx, -0.1, 0.5)), L_EPINE * 0.85, portiere:GetAttribute("Morceau"))
		end
	end
end
-- LE TOIT : une crete de petites epines, vers le haut et l arriere
local cfToit, toit = lp("Toit")
if toit then
	for _, dz in ipairs({-1.2, 0, 1.2}) do
		epine(ici(0, cfToit.Position.Y + toit.Size.Y / 2 - 0.05, cfToit.Position.Z + dz).Position,
			chassis.CFrame:VectorToWorldSpace(Vector3.new(0, 1, 0.6)), 1, nil)
	end
end

-- =========================================================
-- 4. LES BRANCHES : des baguettes rouge sombre plaquees sur la caisse,
-- qui se divisent, avec une veine lumineuse dedans
-- =========================================================
local nbBranches = 0
-- une baguette de a a b (dans le repere du chassis), plaquee sur la
-- surface dont la normale (vers l exterieur) est "dehors"
local function branche(a, b, epaisseur, dehors, morceau)
	local A, B = ici(a.X, a.Y, a.Z).Position, ici(b.X, b.Y, b.Z).Position
	local n = chassis.CFrame:VectorToWorldSpace(dehors)
	local cf = CFrame.lookAt((A + B) / 2, B, n)
	ajout("Branche", "Part", Vector3.new(epaisseur, 0.12, (B - A).Magnitude + epaisseur), cf,
		BRANCHE, Enum.Material.Wood, morceau).CanTouch = false
	ajout("Seve", "Part", Vector3.new(epaisseur * 0.35, 0.14, (B - A).Magnitude), cf, SEVE, Enum.Material.Neon, morceau).CanTouch = false
	nbBranches += 1
end
-- sur chaque flanc : une branche le long du bas, et deux rameaux qui
-- montent sur les ailes (on laisse la portiere libre : le numero)
local caisse = v:WaitForChild("Caisse")
local cfC = chassis.CFrame:ToObjectSpace(caisse.CFrame)
for _, cote in ipairs({{"G", -1}, {"D", 1}}) do
	local s, sx = cote[1], cote[2]
	local _, portiere = lp("Portiere" .. s)
	local cfP = chassis.CFrame:ToObjectSpace(portiere.CFrame)
	local x = cfP.Position.X + sx * (portiere.Size.X / 2 + 0.06)
	local yBas = cfC.Position.Y - caisse.Size.Y / 2 + 0.3
	local dehors = Vector3.new(sx, 0, 0)
	local m = portiere:GetAttribute("Morceau")
	branche(Vector3.new(x, yBas, -3.1), Vector3.new(x, yBas + 0.15, 3.0), 0.3, dehors, m)
	branche(Vector3.new(x, yBas + 0.05, -2.4), Vector3.new(x, yBas + 1.0, -3.2), 0.22, dehors, m)
	branche(Vector3.new(x, yBas + 0.1, 2.3), Vector3.new(x, yBas + 1.0, 3.1), 0.22, dehors, m)
	branche(Vector3.new(x, yBas + 0.12, 0.6), Vector3.new(x, yBas + 0.55, 1.2), 0.16, dehors, m)
end
-- sur le capot : une branche au milieu qui se divise en deux vers l avant
local cfK, capot = lp("Capot")
if capot then
	local y = cfK.Position.Y + capot.Size.Y / 2 + 0.06
	local z1, z2 = cfK.Position.Z + capot.Size.Z / 2 - 0.2, cfK.Position.Z - capot.Size.Z / 2 + 0.3
	local zM = (z1 + z2) / 2
	local haut = Vector3.new(0, 1, 0)
	local m = capot:GetAttribute("Morceau")
	branche(Vector3.new(0, y, z1), Vector3.new(0, y, zM), 0.32, haut, m)
	branche(Vector3.new(0, y, zM), Vector3.new(-1.8, y, z2), 0.24, haut, m)
	branche(Vector3.new(0, y, zM), Vector3.new(1.8, y, z2), 0.24, haut, m)
	branche(Vector3.new(-0.9, y, (zM + z2) / 2), Vector3.new(-2.5, y, zM), 0.16, haut, m)
	branche(Vector3.new(0.9, y, (zM + z2) / 2), Vector3.new(2.5, y, zM), 0.16, haut, m)
end

v.Parent = ServerStorage
print(string.format("Ronce : %d epines, %d branches (ServerStorage.%s)", nbEpines, nbBranches, NOM))
