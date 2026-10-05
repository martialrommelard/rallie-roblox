-- =========================================================
--  LA GRANDE SALLE SOUS LE SPAWN  (a lancer UNE fois, dans Studio, en Edit)
--  Comme ZoneSpawn : on le colle dans la Command Bar (ou par execute_luau).
--
--  Le spawn est pose sur un gros demi-rond PLEIN : 72 tranches "Sol" qui
--  partent du centre, du sol (Y -2,5) jusqu au plancher du spawn (Y 43,4).
--  Les deux escaliers de l arriere descendent jusqu en bas... et butaient
--  contre ce bloc. On le CREUSE :
--    - chaque tranche garde un SOL (en bas) et un PLAFOND (en haut) ; un
--      MUR rond relie les bouts des tranches ;
--    - au pied de chaque escalier, une PORTE droit devant les marches (dans
--      le mur du batiment), qui donne dans la salle ;
--    - des lampes au plafond, une ligne neon au pied de tous les murs ;
--    - la salle continue SOUS LES DEUX BATIMENTS (leurs blocs pleins "Aile"
--      sont creuses eux aussi, et ouverts du cote de la salle), avec sur le
--      devant de chacun un grand PORTAIL de garage, cote piste, et une rampe.
--  Et on BOUCHE les deux puits a cote des escaliers (on pouvait tomber de
--  l escalier du haut jusqu en bas) : un bloc plein, a la hauteur des marches.
--
--  Rien n est ecrit en dur : le centre, le rayon, la hauteur du sol, la
--  place des portes et des puits sont DEMANDES aux pieces existantes.
--  ⚠️ Si on relance ZoneSpawn.lua, le bloc redevient plein : relancer ce
--  script apres.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local EP_PLAFOND = 1.5       -- epaisseur du plafond (le plancher du spawn)
local EP_MUR     = 2         -- epaisseur du mur rond
local PORTE_L    = 10        -- largeur d une porte
local PORTE_H    = 12        -- hauteur d une porte
local GARAGE_MARGE  = 3      -- le portail de garage prend TOUTE la facade avant (cote piste),
local GARAGE_POUTRE = 3      -- sauf 3 studs de mur de chaque cote et une poutre de 3 en haut
local GARAGE_RAMPE = 7       -- la rampe dehors (pour que les voitures puissent entrer)
local ECART_LAMPE = 18       -- une lampe tous les 18 studs au plafond
local BLANC  = Color3.fromRGB(245, 245, 245)
local SOL_C  = Color3.fromRGB(20, 20, 20)   -- noir, en Plastic (comme la rampe du garage)
local NEON   = Color3.fromRGB(0, 225, 255)

local zone = workspace:WaitForChild("ZoneSpawn")
if zone:FindFirstChild("SalleSousSpawn") then
	print("La salle existe deja : rien a faire")
	return
end
local enregistrement = ChangeHistoryService:TryBeginRecording("Salle sous le spawn")

local salle = Instance.new("Folder")
salle.Name = "SalleSousSpawn"
salle.Parent = zone

local function piece(nom, taille, cf, couleur, matiere)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur or BLANC
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = salle
	return p
end

-- ---- 1. ON DEMANDE AUX PIECES ----
local tranches, marches, marchesHaut = {}, {}, {}
for _, x in ipairs(zone:GetChildren()) do
	if x.Name == "Sol" and x:IsA("BasePart") and x.Size.Y > 20 then table.insert(tranches, x) end
	if x.Name == "Marche" then table.insert(marches, x) end
	if x.Name == "MarcheHaut" then table.insert(marchesHaut, x) end
end
assert(#tranches > 0, "pas de tranches Sol pleines")

-- l axe long d une tranche (celui qui va du centre vers le bord)
local function axeLong(p)
	if p.Size.X > p.Size.Z then return p.CFrame.RightVector, p.Size.X end
	return p.CFrame.LookVector, p.Size.Z
end
-- la largeur du demi-rond : les bouts des tranches les plus a gauche et a droite
local xMin, xMax = math.huge, -math.huge
for _, p in ipairs(tranches) do
	local axe, l = axeLong(p)
	local a, b = p.Position + axe * l / 2, p.Position - axe * l / 2
	xMin, xMax = math.min(xMin, a.X, b.X), math.max(xMax, a.X, b.X)
end
local yBas  = tranches[1].Position.Y - tranches[1].Size.Y / 2
-- le centre : au milieu en X ; en Z, sur la ligne des tranches couchees le long du diametre
local zCentre = -math.huge
for _, p in ipairs(tranches) do
	local axe = axeLong(p)
	if math.abs(axe.Z) < 0.1 then zCentre = math.max(zCentre, p.Position.Z) end
end
local centre = Vector3.new((xMin + xMax) / 2, 0, zCentre)

-- le SOL de la salle : au niveau du pied des escaliers
local pied = {}
for _, m in ipairs(marches) do
	local dessus = m.Position.Y + m.Size.Y / 2
	local cote = (m.Position.X < centre.X) and "gauche" or "droite"
	if not pied[cote] or dessus < pied[cote].dessus then pied[cote] = {dessus = dessus, x = m.Position.X, z = m.Position.Z, zMin = m.Position.Z - m.Size.Z / 2} end
end
local ySol = math.min(pied.gauche.dessus, pied.droite.dessus)

-- les deux BATIMENTS (Aile) debordent dans le demi-rond, de chaque cote :
-- leurs murs sont les vrais bords de la salle. On cherche ou ils sont.
local faceG, faceD = -math.huge, math.huge
-- les blocs sont un peu TOURNES (0,6 degre) : leur mur interieur n est pas au
-- meme x devant et au fond. Le mur rond les rejoint DEVANT : on garde aussi
-- le x du coin avant (faceGRond, faceDRond), sinon il reste une fente.
local faceGRond, faceDRond = -math.huge, math.huge
for _, a in ipairs(zone:GetChildren()) do
	if a.Name == "Aile" and a:IsA("BasePart") and a.Position.Y < 30 and math.abs(a.Position.Z - centre.Z) < 60 then
		local xs = {}
		for _, dx in ipairs({-1, 1}) do
			for _, dz in ipairs({-1, 1}) do
				table.insert(xs, (a.CFrame * Vector3.new(dx * a.Size.X / 2, 0, dz * a.Size.Z / 2)).X)
			end
		end
		table.sort(xs)
		if a.Position.X < centre.X then faceG, faceGRond = math.max(faceG, xs[4]), math.max(faceGRond, xs[3])
		else faceD, faceDRond = math.min(faceD, xs[1]), math.min(faceDRond, xs[2]) end
	end
end

-- ---- 2. ON CREUSE CHAQUE TRANCHE ----
local yPlafondMin = math.huge
for _, p in ipairs(tranches) do
	local dessus = p.Position.Y + p.Size.Y / 2
	local yPlafond = dessus - EP_PLAFOND
	yPlafondMin = math.min(yPlafondMin, yPlafond)
	local horizontal = p.CFrame - p.CFrame.Position
	-- le plafond : le haut de la tranche
	piece("PlafondSalle", Vector3.new(p.Size.X, EP_PLAFOND, p.Size.Z),
		horizontal + Vector3.new(p.Position.X, dessus - EP_PLAFOND / 2, p.Position.Z), p.Color, p.Material)
	-- et la tranche elle-meme devient le SOL de la salle
	p.Size = Vector3.new(p.Size.X, ySol - yBas, p.Size.Z)
	p.Position = Vector3.new(p.Position.X, (yBas + ySol) / 2, p.Position.Z)
	p.Color = SOL_C
	p.Material = Enum.Material.Plastic
end

-- ---- 2b. LE MUR ROND, d un seul tenant ----
-- (avant : un bloc au bout de chaque tranche. Ils se chevauchaient : leurs
-- coins faisaient des dents de scie, et ils depassaient sur les cotes.)
-- On relie les BOUTS des tranches, dans l ordre, par des murs droits qui
-- se touchent bord a bord ; et on coupe net contre les murs des batiments.
local bouts = {}
for _, p in ipairs(tranches) do
	local axe, l = axeLong(p)
	local a, b = p.Position + axe * l / 2, p.Position - axe * l / 2
	local e = (((a - centre) * Vector3.new(1, 0, 1)).Magnitude > ((b - centre) * Vector3.new(1, 0, 1)).Magnitude) and a or b
	local v = (e - centre) * Vector3.new(1, 0, 1)
	table.insert(bouts, {e = Vector3.new(e.X, 0, e.Z), dir = v.Unit, angle = math.atan2(v.X, -v.Z)})
end
table.sort(bouts, function(u, w) return u.angle < w.angle end)
local hRond = yPlafondMin - ySol
-- la JONCTION avec chaque batiment : le coin interieur du bout coupe du mur
-- rond (le mur du batiment s arretera la, sans depasser dans la salle)
local jonction = {}
local function anneau(nom, recul, epaisseur, hauteur, yCentre, couleur, matiere)
	local n = 0
	for i = 1, #bouts - 1 do
		local A = bouts[i].e - bouts[i].dir * recul
		local B = bouts[i + 1].e - bouts[i + 1].dir * recul
		-- on coupe ce qui passe derriere le mur d un batiment (et on note quel bout est coupe)
		local function couper(P, Q, xLim, garderPlusGrand)
			local okP = garderPlusGrand and P.X >= xLim or (not garderPlusGrand and P.X <= xLim)
			local okQ = garderPlusGrand and Q.X >= xLim or (not garderPlusGrand and Q.X <= xLim)
			if okP and okQ then return P, Q, false, false end
			if not okP and not okQ then return nil end
			local t = (xLim - P.X) / (Q.X - P.X)
			local I = P + (Q - P) * t
			if okP then return P, I, false, true else return I, Q, true, false end
		end
		local P, Q, cP, cQ = couper(A, B, faceGRond, true)
		if P then
			local cP2, cQ2
			P, Q, cP2, cQ2 = couper(P, Q, faceDRond, false)
			cP, cQ = cP or cP2, cQ or cQ2
		end
		if P and (Q - P).Magnitude > 0.05 then
			local d = (Q - P).Unit
			-- un mur EPAIS coupe en biais : son coin depasserait. On recule le
			-- bout coupe pour que le coin s arrete au mur du batiment... en le
			-- laissant entrer de 0,3 DANS ce mur (sinon il reste une fente au coin).
			local recul2 = math.max(0, math.abs(d.Z) * epaisseur / 2 / math.max(math.abs(d.X), 0.05) - 0.3)
			if cP then P += d * recul2 end
			if cQ then Q -= d * recul2 end
			-- les bouts NON coupes debordent un peu (0,15) pour bien se toucher
			local P2 = P - d * (cP and 0 or 0.15)
			local Q2 = Q + d * (cQ and 0 or 0.15)
			if (Q2 - P2):Dot(d) > 0.05 then
				local milieu = (P2 + Q2) / 2
				piece(nom, Vector3.new(epaisseur, hauteur, (Q2 - P2).Magnitude),
					CFrame.lookAt(Vector3.new(milieu.X, yCentre, milieu.Z), Vector3.new(Q2.X, yCentre, Q2.Z)), couleur, matiere)
				if nom == "MurRondSalle" and (cP or cQ) then
					local bout = cP and P2 or Q2
					local versCentre = (centre - bout) * Vector3.new(1, 0, 1)
					local normale = Vector3.new(-d.Z, 0, d.X)
					if normale:Dot(versCentre) < 0 then normale = -normale end
					jonction[(bout.X < centre.X) and "gauche" or "droite"] = bout + normale * epaisseur / 2
				end
				n += 1
			end
		end
	end
	return n
end
local nbRond = anneau("MurRondSalle", EP_MUR / 2, EP_MUR, hRond, ySol + hRond / 2, BLANC)

-- ---- 3. LE MUR DU FOND, plein ----
-- (les portes ne sont plus ici, sur le cote des escaliers : elles sont
-- EN FACE du bas de chaque escalier, dans le mur des batiments -> partie 6)
local zAvant = centre.Z - 2.5
local zArriere = math.min(pied.gauche.zMin, pied.droite.zMin) - 0.05
local ep = zArriere - zAvant
local hFond = yPlafondMin - ySol
local zMilieu = (zAvant + zArriere) / 2
local xF1, xF2 = math.max(xMin, faceG), math.min(xMax, faceD)
piece("MurFondSalle", Vector3.new(xF2 - xF1, hFond, ep), CFrame.new((xF1 + xF2) / 2, ySol + hFond / 2, zMilieu), BLANC)

-- ---- 4. LES LAMPES AU PLAFOND ----
-- un plafonnier CLASSIQUE (les grands panneaux neon, c etait moche) : un disque
-- blanc colle au plafond, un verre blanc chaud dessous, une lumiere douce
local CHAUD = Color3.fromRGB(255, 238, 205)
local function plafonnier(position, rot)
	local socle = piece("LampeSalle", Vector3.new(0.3, 3, 3),
		CFrame.new(position - Vector3.new(0, 0.15, 0)) * rot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(235, 235, 235))
	socle.Shape = Enum.PartType.Cylinder
	socle.CanCollide = false
	local verre = piece("VerreLampe", Vector3.new(0.12, 2.2, 2.2),
		CFrame.new(position - Vector3.new(0, 0.36, 0)) * rot * CFrame.Angles(0, 0, math.rad(90)), CHAUD, Enum.Material.Neon)
	verre.Shape = Enum.PartType.Cylinder
	verre.Transparency = 0.35
	verre.CanCollide = false
	-- la LUMIERE, elle, part de MI-HAUTEUR (une source invisible sous le plafonnier) :
	-- venue du plafond (42 studs), elle laissait de grosses ombres en bas des murs
	local source = piece("SourceLumiere", Vector3.new(0.2, 0.2, 0.2), CFrame.new(position.X, ySol + 18, position.Z))
	source.Transparency = 1
	source.CanCollide, source.CanQuery, source.CanTouch = false, false, false
	local lum = Instance.new("PointLight")
	lum.Color, lum.Brightness, lum.Range, lum.Shadows = Color3.fromRGB(255, 250, 242), 0.4, 50, false
	lum.Parent = source
end
local rayon = (xMax - xMin) / 2
local nbLampes = 0
for dx = -rayon + ECART_LAMPE / 2, rayon, ECART_LAMPE do
	for dz = ECART_LAMPE / 2, rayon, ECART_LAMPE do
		local lx = centre.X + dx
		if math.sqrt(dx * dx + dz * dz) < rayon - 8 and lx > faceG + 3 and lx < faceD - 3 then
			plafonnier(Vector3.new(centre.X + dx, yPlafondMin, centre.Z - dz), CFrame.new())
			nbLampes += 1
		end
	end
end

-- ---- 5. ON BOUCHE LES DEUX PUITS a cote des escaliers ----
-- un puits = une colonne VIDE en bas, au milieu et en haut
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = {workspace:FindFirstChild("Baseplate"), workspace.Terrain}
local function vide(px, py, pz)
	return #workspace:GetPartBoundsInBox(CFrame.new(px, py, pz), Vector3.new(0.3, 0.3, 0.3), op) == 0
end
local couleurMarche = marchesHaut[1] and marchesHaut[1].Color or BLANC
local matMarche = marchesHaut[1] and marchesHaut[1].Material or Enum.Material.SmoothPlastic
local bouches = {}
for _, cote in ipairs({{pied.gauche.x - 15, pied.gauche.x + 20}, {pied.droite.x - 20, pied.droite.x + 15}}) do
	local x1, x2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge
	for px = cote[1], cote[2], 0.5 do
		for pz = zArriere, zArriere + 35, 0.5 do
			if vide(px, ySol - 0.75, pz) and vide(px, 40, pz) and vide(px, 85, pz) then
				x1, x2, z1, z2 = math.min(x1, px), math.max(x2, px), math.min(z1, pz), math.max(z2, pz)
			end
		end
	end
	if x1 < x2 then
		x1, x2, z1, z2 = x1 - 0.25, x2 + 0.25, z1 - 0.25, z2 + 0.25
		-- jusqu ou monter ? au niveau de la marche du haut qui le touche
		local voisine = workspace:GetPartBoundsInBox(CFrame.new((x1 + x2) / 2, 40, (z1 + z2) / 2), Vector3.new(x2 - x1 + 2, 1, z2 - z1 + 2), op)
		local haut = ySol
		for _, v in ipairs(voisine) do
			if v.Name == "MarcheHaut" then
				local r = workspace:Raycast(Vector3.new(v.Position.X, 95.4, v.Position.Z), Vector3.new(0, -100, 0))   -- 95,4 : juste sous le plancher du haut
				local dessus = (r and r.Instance == v) and r.Position.Y or (v.Position.Y + v.Size.Y / 2)
				haut = math.max(haut, dessus)
			end
		end
		piece("BouchePuits", Vector3.new(x2 - x1, haut - yBas, z2 - z1),
			CFrame.new((x1 + x2) / 2, (yBas + haut) / 2, (z1 + z2) / 2), couleurMarche, matMarche)
		table.insert(bouches, string.format("%.1f x %.1f, jusqu a Y %.1f", x2 - x1, z2 - z1, haut))
	end
end

-- ---- 6. LA SALLE CONTINUE SOUS LES DEUX BATIMENTS ----
-- Chaque batiment est pose sur un bloc plein ("Aile"). On le creuse aussi :
-- un sol, un plafond, et des murs tout autour... sauf du cote de la salle,
-- ou on ouvre en grand (entre le mur rond et le mur du fond).
-- d abord : les morceaux du mur rond qui sont DANS les blocs (ils couperaient
-- la salle en deux une fois les blocs creuses)
local enleves = 0
for _, p in ipairs(salle:GetChildren()) do
	if (p.Name == "MurSalle" or p.Name == "LisereSalle") and p.Size.Y < 50 and (p.Position.X < faceG - 3 or p.Position.X > faceD + 3)
		and ((p.Position - centre) * Vector3.new(1, 0, 1)).Magnitude > rayon - 6 then
		p:Destroy()
		enleves += 1
	end
end
local nbAiles = 0
for _, a in ipairs(zone:GetChildren()) do
	if a.Name == "Aile" and a:IsA("BasePart") and a.Size.Y > 20 and math.abs(a.Position.Z - centre.Z) < 60 then
		nbAiles += 1
		local cf, s = a.CFrame, a.Size
		local bas, dessus = a.Position.Y - s.Y / 2, a.Position.Y + s.Y / 2
		local yPlaf = dessus - EP_PLAFOND
		local h = yPlaf - ySol
		local gauche = a.Position.X < centre.X
		-- dans le repere du bloc : de quel cote (X local) est la salle ?
		local signe = (cf:VectorToObjectSpace(Vector3.new(gauche and 1 or -1, 0, 0)).X > 0) and 1 or -1
		local face = gauche and faceG or faceD
		-- l ouverture : du bout du mur rond (la jonction) jusqu au mur du fond
		-- (avec "+3" comme avant, le mur du batiment depassait de 4 a 5 studs)
		local j = jonction[gauche and "gauche" or "droite"]
		local zRond = j and j.Z or centre.Z
		local l1 = cf:PointToObjectSpace(Vector3.new(face, 0, zRond)).Z
		local l2 = cf:PointToObjectSpace(Vector3.new(face, 0, zAvant)).Z
		local o1, o2 = math.min(l1, l2), math.max(l1, l2)
		local function loc(x, y, z) return cf * CFrame.new(x, 0, z) + Vector3.new(0, y - a.Position.Y, 0) end
		-- plafond et sol
		-- plafond un peu plus bas (0,05) et sol un peu plus haut (0,02) que ceux du
		-- rond : sinon les deux se melangent au meme niveau et les bords clignotent
		piece("PlafondSalle", Vector3.new(s.X, EP_PLAFOND + 0.05, s.Z), loc(0, dessus - (EP_PLAFOND + 0.05) / 2, 0), a.Color, a.Material)
		local sol = piece("SolSalle", Vector3.new(s.X, ySol + 0.02 - bas, s.Z), loc(0, (bas + ySol + 0.02) / 2, 0), SOL_C, Enum.Material.Plastic)
		-- les murs : les deux bouts en Z, le cote exterieur, et le cote salle en 2 morceaux
		local yM = ySol + h / 2
		piece("MurSalle", Vector3.new(s.X, h, EP_MUR), loc(0, yM, s.Z / 2 - EP_MUR / 2), BLANC)
		-- le mur AVANT (cote piste), avec un grand PORTAIL de garage au milieu
		-- (dehors = Z local negatif, vers la piste)
		local zAv = -s.Z / 2 + EP_MUR / 2
		local GARAGE_L = s.X - 2 * GARAGE_MARGE
		local GARAGE_H = h - GARAGE_POUTRE
		local g2 = GARAGE_L / 2
		piece("MurSalle", Vector3.new(s.X / 2 - g2, h, EP_MUR), loc((-s.X / 2 - g2) / 2, yM, zAv), BLANC)
		piece("MurSalle", Vector3.new(s.X / 2 - g2, h, EP_MUR), loc((s.X / 2 + g2) / 2, yM, zAv), BLANC)
		piece("MurSalle", Vector3.new(GARAGE_L, h - GARAGE_H, EP_MUR), loc(0, ySol + GARAGE_H + (h - GARAGE_H) / 2, zAv), BLANC)
		piece("SeuilSalle", Vector3.new(GARAGE_L, ySol - bas, EP_MUR), loc(0, (bas + ySol) / 2, zAv), SOL_C, Enum.Material.Plastic)
		-- des bandes jaunes et noires de chaque cote, comme un vrai garage
		for _, xg in ipairs({-g2, g2}) do
			local versDedans = (xg < 0) and 1 or -1
			for k = 0, math.floor(GARAGE_H / 2) - 1 do
				piece("BandeGarage", Vector3.new(0.6, 2, EP_MUR + 0.2), loc(xg + versDedans * 0.3, ySol + 1 + k * 2, zAv),
					(k % 2 == 0) and Color3.fromRGB(255, 200, 0) or SOL_C)
			end
		end
		piece("CadrePorteSalle", Vector3.new(GARAGE_L, 0.3, EP_MUR + 0.3), loc(0, ySol + GARAGE_H - 0.15, zAv), NEON, Enum.Material.Neon)
		-- le rideau metallique remonte en haut, et son caisson (cote salle)
		piece("RideauGarage", Vector3.new(GARAGE_L, 2.2, 0.4), loc(0, ySol + GARAGE_H - 1.1, zAv + EP_MUR / 2 + 0.2),
			Color3.fromRGB(150, 155, 160), Enum.Material.DiamondPlate)
		piece("CaissonGarage", Vector3.new(GARAGE_L, 1.6, 1.6), loc(0, ySol + GARAGE_H + 0.8, zAv + EP_MUR / 2 + 0.8),
			Color3.fromRGB(110, 112, 118), Enum.Material.Metal)
		-- dehors : une RAMPE du sol de dehors (mesure) jusqu au sol de la salle :
		-- les voitures peuvent entrer. Un WedgePart monte vers son +Z local : vers le mur.
		local zR = -s.Z / 2 - GARAGE_RAMPE / 2
		local rD = workspace:Raycast(loc(0, ySol + 5, zR).Position, Vector3.new(0, -15, 0))
		local yDehors = rD and rD.Position.Y or (ySol - 1.3)
		local hR = ySol - yDehors
		if hR > 0.05 then
			local rampe = Instance.new("WedgePart")
			rampe.Name = "RampeGarage"
			rampe.Anchored = true
			rampe.Size = Vector3.new(GARAGE_L, hR, GARAGE_RAMPE)
			rampe.CFrame = loc(0, yDehors + hR / 2, zR)
			rampe.Color = SOL_C
			rampe.Parent = salle
		end
		-- le panneau sur la poutre du haut, dehors
		local pan = piece("PanneauEntree", Vector3.new(30, 2.4, 0.3), loc(0, ySol + h - GARAGE_POUTRE / 2, -s.Z / 2 - 0.2), Color3.fromRGB(10, 28, 55))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front          -- Front = -Z local = dehors
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = pan
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Font = Enum.Font.GothamBold
		txt.TextScaled = true
		txt.TextColor3 = NEON
		txt.Text = "GARAGE  ·  SOUS-SOL"
		txt.Parent = gui
		-- le mur du bout du batiment : plein
		piece("MurSalle", Vector3.new(EP_MUR, h, s.Z), loc(-signe * (s.X / 2 - EP_MUR / 2), yM, 0), BLANC)
		local xi = signe * (s.X / 2 - EP_MUR / 2)
		if o1 > -s.Z / 2 then
			piece("MurSalle", Vector3.new(EP_MUR, h, o1 + s.Z / 2), loc(xi, yM, (-s.Z / 2 + o1) / 2), BLANC)
		end
		if o2 < s.Z / 2 then
			-- ce mur longe le bas de l escalier : on y ouvre la PORTE, en face des marches
			local bas = pied[gauche and "gauche" or "droite"]
			local zc = cf:PointToObjectSpace(Vector3.new(bas.x, 0, bas.z)).Z
			local d1, d2 = zc - PORTE_L / 2, zc + PORTE_L / 2
			local function morceau(a, b2, yA, yB)
				if b2 - a < 0.05 or yB - yA < 0.05 then return end
				piece("MurSalle", Vector3.new(EP_MUR, yB - yA, b2 - a), loc(xi, (yA + yB) / 2, (a + b2) / 2), BLANC)
			end
			morceau(o2, d1, ySol, ySol + h)                    -- avant la porte
			morceau(d2, s.Z / 2, ySol, ySol + h)               -- apres la porte
			morceau(d1, d2, ySol + PORTE_H, ySol + h)          -- au-dessus de la porte
			-- le cadre neon, sur les deux faces du mur
			for _, c in ipairs({-1, 1}) do
				local xc = xi + c * (EP_MUR / 2 + 0.05)
				piece("CadrePorteSalle", Vector3.new(0.1, PORTE_H, 0.3), loc(xc, ySol + PORTE_H / 2, d1 + 0.15), NEON, Enum.Material.Neon)
				piece("CadrePorteSalle", Vector3.new(0.1, PORTE_H, 0.3), loc(xc, ySol + PORTE_H / 2, d2 - 0.15), NEON, Enum.Material.Neon)
				piece("CadrePorteSalle", Vector3.new(0.1, 0.3, PORTE_L), loc(xc, ySol + PORTE_H - 0.15, zc), NEON, Enum.Material.Neon)
			end
		end
		-- le petit coin creux entre le bout du mur rond et ce mur : on le bouche
		-- (un bloc cache dans le bout du mur rond)
		if j then
			local xMur = gauche and faceGRond or faceDRond
			local x1, x2 = math.min(xMur, j.X), math.max(xMur, j.X)
			piece("CoinSalle", Vector3.new(x2 - x1 + 0.02, h, 0.86), CFrame.new((x1 + x2) / 2, yM, j.Z - 0.43), BLANC)
		end
		-- des lampes
		for lx = -s.X / 2 + ECART_LAMPE / 2, s.X / 2 - 4, ECART_LAMPE do
			for lz = -s.Z / 2 + ECART_LAMPE / 2, s.Z / 2 - 4, ECART_LAMPE do
				plafonnier(loc(lx, yPlaf, lz).Position, cf - cf.Position)
			end
		end
		-- le bloc plein disparait
		a:Destroy()
	end
end
print(string.format("Sous les batiments : %d blocs creuses, %d morceaux du mur rond enleves", nbAiles, enleves))

-- ---- 7. LA LIGNE BLEUE, au pied de TOUS les murs de la salle ----
-- (avant : elle flottait 0,3 au-dessus du sol et s arretait aux jonctions)
-- Pour chaque mur, et chacune de ses deux grandes faces : si devant la face
-- c est la SALLE (vide, avec le plafond de la salle au-dessus et un sol
-- en dessous), on y couche une ligne neon, posee sur le sol.
local rayLigne = RaycastParams.new()
rayLigne.FilterType = Enum.RaycastFilterType.Exclude
local function solDansLaSalle(pt)
	if #workspace:GetPartBoundsInBox(CFrame.new(pt), Vector3.one * 0.1) > 0 then return nil end
	local h = workspace:Raycast(pt, Vector3.new(0, 50, 0), rayLigne)
	local b = workspace:Raycast(pt, Vector3.new(0, -4, 0), rayLigne)
	if h and h.Instance:IsDescendantOf(salle) and b then return b.Position.Y end
	return nil
end
for _, p in ipairs(salle:GetChildren()) do
	local mur = p.Name == "MurRondSalle" or p.Name == "MurSalle" or p.Name == "MurFondSalle" or p.Name == "CoinSalle"
	if mur and (p.Position.Y - p.Size.Y / 2) < ySol + 1 then
		local fin, long, ep, L
		if p.Size.X <= p.Size.Z then fin, long, ep, L = p.CFrame.RightVector, p.CFrame.LookVector, p.Size.X, p.Size.Z
		else fin, long, ep, L = p.CFrame.LookVector, p.CFrame.RightVector, p.Size.Z, p.Size.X end
		for _, cote in ipairs({-1, 1}) do
			local n = fin * cote
			local face = p.Position + n * ep / 2
			-- 3 points le long de la face : il faut que 2 au moins soient dans la salle
			local ySolIci, oui = nil, 0
			for _, f in ipairs({-0.35, 0, 0.35}) do
				local y = solDansLaSalle(Vector3.new(face.X, 1, face.Z) + n * 0.6 + long * (L * f))
				if y then ySolIci, oui = y, oui + 1 end
			end
			if oui >= 2 then
				local c = face + n * 0.1
				piece("LisereSalle", Vector3.new(0.2, 0.4, L),
					CFrame.lookAt(Vector3.new(c.X, ySolIci + 0.2, c.Z), Vector3.new(c.X, ySolIci + 0.2, c.Z) + long),
					NEON, Enum.Material.Neon)
			end
		end
	end
end

-- ---- 9. LES ESCALIERS QUI DESCENDENT AU SOUS-SOL : bien visibles ----
-- Toutes blanches et eclairees pareil, on ne distinguait plus les marches.
-- Un nez neon au bord de chaque marche (du cote ou l escalier descend), et
-- des lumieres douces au-dessus, toutes les 6 marches.
local parCote = {gauche = {}, droite = {}}
for _, m in ipairs(marches) do
	local gauche = m.Position.X < centre.X
	local dessus = m.Position.Y + m.Size.Y / 2
	if dessus > ySol + 0.1 then        -- la marche du bas est au niveau du sol : pas de nez
		-- a gauche on descend vers les x plus petits, a droite vers les x plus grands
		local versBas = gauche and -1 or 1
		local cote = (m.CFrame.RightVector.X > 0) and versBas or -versBas
		local nez = piece("NezMarche", Vector3.new(0.18, 0.08, m.Size.Z - 0.2),
			m.CFrame * CFrame.new(cote * (m.Size.X / 2 - 0.09), m.Size.Y / 2 + 0.04, 0), NEON, Enum.Material.Neon)
		nez.CanCollide, nez.CanQuery, nez.CanTouch = false, false, false
	end
	table.insert(parCote[gauche and "gauche" or "droite"], m)
end
for _, liste in pairs(parCote) do
	table.sort(liste, function(a, b) return a.Position.X < b.Position.X end)
	for i = 1, #liste, 6 do
		local m = liste[i]
		local s = piece("SourceLumiere", Vector3.new(0.2, 0.2, 0.2), CFrame.new(m.Position.X, m.Position.Y + m.Size.Y / 2 + 9, m.Position.Z))
		s.Transparency = 1
		s.CanCollide, s.CanQuery, s.CanTouch = false, false, false
		local pl = Instance.new("PointLight")
		pl.Color, pl.Brightness, pl.Range, pl.Shadows = Color3.fromRGB(255, 250, 242), 0.7, 22, false
		pl.Parent = s
	end
end

-- ---- 8. PAS D OMBRES dans la salle (rayures, cadres, rideaux... faisaient des taches)
for _, p in ipairs(salle:GetDescendants()) do
	if p:IsA("BasePart") and p.Name ~= "PlafondSalle" then p.CastShadow = false end
end

if enregistrement then ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit) end
print(string.format("Salle sous le spawn : %d tranches creusees, sol a Y %.2f, hauteur %.1f, %d lampes ; puits bouches : %s",
	#tranches, ySol, yPlafondMin - ySol, nbLampes, table.concat(bouches, " | ")))
