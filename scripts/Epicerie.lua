-- =========================================================
--  L EPICERIE  (a lancer UNE fois, dans Studio, en Edit, APRES
--  SalleSport.lua et ParoiSalleSport.lua)
--  Dans le batiment de la salle de sport, la moitie COTE PORTE (vide
--  jusqu ici) devient une epicerie :
--    - une ALLEE libre, tout droit de la porte au passage de la salle de
--      sport (on traverse le magasin pour aller faire du sport) ;
--    - cote fenetres : la caisse, l etal de fruits, le bac a glaces ;
--    - cote fond : 2 rayons (gondoles) et un frigo mural.
--  Ce qui se passe en Play (acheter, manger, les boosts, la caissiere)
--  est fait par le script EpicerieServeur. Ici on ne pose que les objets,
--  plus les MODELES des produits (ServerStorage/Epicerie/Modeles), que le
--  serveur copie quand on achete.
--
--  REPERE : u = de la porte vers la salle de sport, v = en travers
--  (0 = milieu de l allee, + = vers le fond, - = vers les fenetres),
--  y = au-dessus du sol. RIEN N EST ECRIT EN DUR sur le batiment : on
--  DEMANDE au sol sa taille, a la porte sa place, a la paroi de verre
--  ou est le passage.
-- =========================================================

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local zone  = workspace:WaitForChild("ZoneSpawn")
local salle = zone:WaitForChild("SalleSport")

-- ---- les reglages (tout le reste en est deduit) ----
local MARGE_ALLEE = 1       -- l allee = le passage de la paroi + 1 stud de chaque cote
local H_RAYON     = 6       -- hauteur des gondoles
local P_RAYON     = 3.2     -- leur profondeur (les 2 faces)
local NB_ETAGERES = 4
local VERT   = Color3.fromRGB(40, 170, 80)     -- la couleur du magasin
local BLANC  = Color3.fromRGB(240, 240, 238)
local GRIS   = Color3.fromRGB(70, 72, 78)
local NOIR   = Color3.fromRGB(25, 25, 28)
local BOIS   = Color3.fromRGB(160, 115, 70)
local hasard = Random.new(2026)                -- toujours le meme "hasard" : le magasin est pareil a chaque lancement

-- ---- 1. LE REPERE : on le demande au batiment (comme SalleSport.lua) ----
local sol, porte
for _, p in ipairs(zone:GetChildren()) do
	if p.Name == "SolInterieur" and (not sol or p.Position.X > sol.Position.X) then sol = p end
	if p.Name == "PorteCoulissante" and (not porte or p:GetPivot().Position.X > porte:GetPivot().Position.X) then porte = p end
end
assert(sol and porte, "batiment introuvable")
local repere = sol.CFrame * CFrame.new(0, sol.Size.Y / 2, 0)
local lp = repere:PointToObjectSpace(porte:GetPivot().Position)
local S = (lp.X < 0) and 1 or -1                       -- +1 : la porte est du cote des X negatifs
local hx, hz = sol.Size.X / 2, sol.Size.Z / 2

-- le passage : entre les 2 vitres de la paroi
local vitres = {}
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "ParoiVerre" then
		local l = repere:PointToObjectSpace(p.Position)
		table.insert(vitres, {x = l.X, z1 = l.Z - p.Size.Z / 2, z2 = l.Z + p.Size.Z / 2})
	end
end
assert(#vitres == 2, "il faut les 2 vitres de la paroi de la salle de sport")
table.sort(vitres, function(a, b) return a.z1 < b.z1 end)
local zPassage = (vitres[1].z2 + vitres[2].z1) / 2
local A = (vitres[2].z1 - vitres[1].z2) / 2 + MARGE_ALLEE   -- la demi-largeur de l allee

-- le cote des fenetres
local zFen = 0
for _, p in ipairs(zone:GetChildren()) do
	if p.Name == "Fenetre" then
		local l = repere:PointToObjectSpace(p.Position)
		if math.abs(l.X) < hx + 3 and math.abs(l.Z) < hz + 3 then zFen = (l.Z < 0) and -1 or 1 break end
	end
end
assert(zFen ~= 0, "fenetres introuvables")

-- le repere G : origine = au ras du mur de la porte, au milieu de l allee
local xMur = -S * hx
local uDir = repere:VectorToWorldSpace(Vector3.new(S, 0, 0))
local vDir = repere:VectorToWorldSpace(Vector3.new(0, 0, -zFen))
local G = CFrame.fromMatrix(repere * Vector3.new(xMur, 0, zPassage), uDir, repere.UpVector, vDir)
assert(uDir:Cross(repere.UpVector):Dot(vDir) > 0.99, "repere G pas direct : a adapter")
local LONG = math.abs(vitres[1].x - xMur)                   -- de la porte a la paroi
-- les bords du sol, dans G
local vMin, vMax = math.huge, -math.huge
for _, sz in ipairs({-1, 1}) do
	local l = G:PointToObjectSpace(repere * Vector3.new(0, 0, sz * hz))
	vMin, vMax = math.min(vMin, l.Z), math.max(vMax, l.Z)
end
local toit = workspace:Raycast(G * Vector3.new(LONG / 2, 1, 0), G.UpVector * 60)
local H_PLAFOND = toit and (toit.Position - G.Position):Dot(G.UpVector) or 19
print(string.format("Epicerie : %.1f de long, allee %.1f de large, cote fenetres %.1f, cote fond %.1f, plafond %.1f",
	LONG, 2 * A, -vMin - A, vMax - A, H_PLAFOND))

-- ---- les outils pour poser ----
local enregistrement = ChangeHistoryService:TryBeginRecording("Epicerie")
local ancien = zone:FindFirstChild("Epicerie")
if ancien then ancien:Destroy() end
local magasin = Instance.new("Model")
magasin.Name = "Epicerie"
magasin.Parent = zone

local function piece(nom, taille, cf, couleur, matiere, parent, forme)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if forme then p.Shape = forme end
	p.Parent = parent or magasin
	return p
end
-- une piece posee dans le magasin : centre (u, y, v), taille (le long de u, haut, le long de v)
local function bloc(nom, u, y, v, tu, ty, tv, couleur, matiere, parent)
	return piece(nom, Vector3.new(tu, ty, tv), G * CFrame.new(u, y, v), couleur, matiere, parent)
end
-- un panneau ecrit, sa face avant tournee vers "dir" (un vecteur de G)
local function panneau(nom, u, y, v, largeur, hauteur, dir, lignes, fond, parent)
	local pos = G * Vector3.new(u, y, v)
	local p = piece(nom, Vector3.new(largeur, hauteur, 0.1),
		CFrame.lookAt(pos, pos + G:VectorToWorldSpace(dir), G.UpVector), fond or VERT, nil, parent)
	p.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.LightInfluence = 0
	gui.Parent = p
	local liste = Instance.new("UIListLayout")
	liste.VerticalAlignment = Enum.VerticalAlignment.Center
	liste.Parent = gui
	for _, l in ipairs(lignes) do
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, l.part)
		t.BackgroundTransparency = 1
		t.Text = l.texte
		t.TextColor3 = l.couleur or BLANC
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = gui
	end
	return p
end
-- la zone ou l on achete un produit : une boite invisible ; le serveur y met
-- le bouton "Acheter" et remplit l etiquette de prix posee juste devant
local function zoneAchat(id, u, y, v, tu, ty, tv, dirEtiquette, uE, yE, vE)
	local z = bloc("ZoneAchat", u, y, v, tu, ty, tv, BLANC)
	z.Transparency, z.CanCollide, z.CanTouch = 1, false, false
	z:SetAttribute("Produit", id)
	local e = panneau("Etiquette", uE, yE, vE, 2.4, 1.3, dirEtiquette, {}, Color3.fromRGB(255, 225, 60))
	e:SetAttribute("Produit", id)
	return z
end

-- ---- 2. LES MODELES DES PRODUITS (ce qu on tient dans la main) ----
-- chacun : une poignee invisible "Handle" au centre + les pieces visibles,
-- soudees APRES avoir ete placees.
local rangement = ServerStorage:FindFirstChild("Epicerie") or Instance.new("Folder")
rangement.Name = "Epicerie"
rangement.Parent = ServerStorage
local vieux = rangement:FindFirstChild("Modeles")
if vieux then vieux:Destroy() end
local modeles = Instance.new("Folder")
modeles.Name = "Modeles"
modeles.Parent = rangement

local DEBOUT = CFrame.Angles(0, 0, math.rad(90))   -- un cylindre est couche sur X : on le leve
local recettes = {
	Energie = function(m, d)
		d("Canette", Vector3.new(1.2, 0.6, 0.6), CFrame.new() * DEBOUT, NOIR, Enum.Material.Metal, Enum.PartType.Cylinder)
		d("Bande", Vector3.new(0.4, 0.62, 0.62), CFrame.new(0, 0.1, 0) * DEBOUT, Color3.fromRGB(60, 255, 90), Enum.Material.Neon, Enum.PartType.Cylinder)
		d("Couvercle", Vector3.new(0.06, 0.52, 0.52), CFrame.new(0, 0.61, 0) * DEBOUT, Color3.fromRGB(200, 200, 205), Enum.Material.Metal, Enum.PartType.Cylinder)
	end,
	Ressort = function(m, d)
		d("Bonbon", Vector3.new(0.7, 0.7, 0.7), CFrame.new(), Color3.fromRGB(255, 80, 170), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		d("Papier", Vector3.new(0.35, 0.45, 0.45), CFrame.new(0.45, 0, 0), Color3.fromRGB(255, 190, 230), Enum.Material.Glass, Enum.PartType.Cylinder)
		d("Papier", Vector3.new(0.35, 0.45, 0.45), CFrame.new(-0.45, 0, 0), Color3.fromRGB(255, 190, 230), Enum.Material.Glass, Enum.PartType.Cylinder)
	end,
	Glace = function(m, d)
		d("Cornet", Vector3.new(0.9, 0.35, 0.35), CFrame.new(0, -0.25, 0) * DEBOUT, Color3.fromRGB(215, 165, 95), Enum.Material.Sand, Enum.PartType.Cylinder)
		d("Boule", Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, 0.3, 0), Color3.fromRGB(255, 175, 195), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		d("Boule", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0.65, 0), Color3.fromRGB(110, 65, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end,
	Pomme = function(m, d)
		d("Pomme", Vector3.new(0.7, 0.7, 0.7), CFrame.new(), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		d("Queue", Vector3.new(0.25, 0.06, 0.06), CFrame.new(0, 0.4, 0) * DEBOUT, Color3.fromRGB(90, 60, 30), Enum.Material.Wood, Enum.PartType.Cylinder)
		d("Feuille", Vector3.new(0.05, 0.12, 0.28), CFrame.new(0.08, 0.44, 0.1) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(60, 160, 50))
	end,
	Tomate = function(m, d)
		d("Tomate", Vector3.new(0.8, 0.8, 0.8), CFrame.new(), Color3.fromRGB(235, 45, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for k = 0, 4 do       -- la collerette verte : 5 petites feuilles en etoile
			d("Sepale", Vector3.new(0.06, 0.05, 0.3), CFrame.Angles(0, k * 2 * math.pi / 5, 0) * CFrame.new(0, 0.39, 0.12)
				* CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(50, 150, 50))
		end
		d("Queue", Vector3.new(0.15, 0.06, 0.06), CFrame.new(0, 0.46, 0) * DEBOUT, Color3.fromRGB(50, 150, 50), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end,
}
for id, recette in pairs(recettes) do
	local m = Instance.new("Model")
	m.Name = id
	local poignee = piece("Handle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(), BLANC, nil, m)
	poignee.Transparency = 1
	m.PrimaryPart = poignee
	local pieces = {}
	recette(m, function(nom, taille, cf, couleur, matiere, forme)
		table.insert(pieces, piece(nom, taille, cf, couleur, matiere, m, forme))
	end)
	for _, p in ipairs(pieces) do        -- on soude APRES avoir tout place
		p.CanCollide = false
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = poignee, p
		w.Parent = p
	end
	poignee.CanCollide = false
	m.Parent = modeles
end
-- un exemplaire pose dans le magasin (ancre, juste pour voir)
local function exposer(id, u, y, v, tourne)
	local m = modeles[id]:Clone()
	m:PivotTo(G * CFrame.new(u, y, v) * (tourne or CFrame.new()))
	m.Parent = magasin
	return m
end

-- ---- 3. LE SOL ET L ALLEE ----
bloc("SolEpicerie", LONG / 2, 0.03, (vMin + vMax) / 2, LONG, 0.06, vMax - vMin, Color3.fromRGB(225, 225, 220), Enum.Material.Marble)
for _, cote in ipairs({-1, 1}) do
	bloc("LigneAllee", LONG / 2, 0.07, cote * A, LONG, 0.02, 0.25, VERT, Enum.Material.Neon)
end

-- ---- 4. L ENSEIGNE au-dessus de l allee, en entrant ----
local yEns = H_PLAFOND - 3
panneau("Enseigne", 4, yEns, 0, 2 * A - 1, 2.6, Vector3.new(-1, 0, 0),
	{{texte = "ÉPICERIE", part = 0.65}, {texte = "boosts · snacks · boissons", part = 0.35, couleur = Color3.fromRGB(255, 225, 60)}})
panneau("Enseigne", 4.12, yEns, 0, 2 * A - 1, 2.6, Vector3.new(1, 0, 0),
	{{texte = "À BIENTÔT !", part = 1}})
for _, cote in ipairs({-1, 1}) do       -- les 2 cables qui la tiennent
	bloc("Cable", 4.06, (yEns + 1.3 + H_PLAFOND) / 2, cote * (A - 1.5), 0.08, H_PLAFOND - yEns - 1.3, 0.08, NOIR)
end

-- ---- 5. LA CAISSE (cote fenetres, pres de la porte) ----
local uC1, uC2 = 6, 16
local vC = -A - 2.5
bloc("Comptoir", (uC1 + uC2) / 2, 1.6, vC, uC2 - uC1, 3.2, 2.6, VERT)
bloc("PlateauComptoir", (uC1 + uC2) / 2, 3.25, vC, uC2 - uC1 + 0.2, 0.1, 2.8, BLANC, Enum.Material.Marble)
bloc("TapisCaisse", (uC1 + uC2) / 2 - 1.5, 3.32, vC + 0.3, 6, 0.05, 1.4, NOIR, Enum.Material.Rubber)
bloc("Caisse", uC2 - 2, 3.75, vC - 0.3, 1.6, 0.9, 1.4, GRIS)
bloc("EcranCaisse", uC2 - 2, 4.6, vC - 0.3, 1.2, 0.8, 0.1, NOIR, Enum.Material.Glass)
-- la ou se tient la caissiere (le serveur la fait apparaitre) : derriere le comptoir, face a l allee
local poste = bloc("PosteCaissiere", uC2 - 3, 0.5, vC - 2.6, 1, 1, 1, BLANC)
poste.Transparency, poste.CanCollide, poste.CanQuery = 1, false, false
poste.CFrame = CFrame.lookAt(poste.Position, poste.Position + G.LookVector * -1)   -- G.LookVector = -v : on regarde +v, l allee
panneau("PanneauCaisse", (uC1 + uC2) / 2, yEns + 0.5, vC, 4, 1.4, Vector3.new(0, 0, 1), {{texte = "CAISSE", part = 1}})
panneau("PanneauCaisse", (uC1 + uC2) / 2, yEns + 0.5, vC - 0.12, 4, 1.4, Vector3.new(0, 0, -1), {{texte = "CAISSE", part = 1}})
bloc("Cable", (uC1 + uC2) / 2, (yEns + 1.2 + H_PLAFOND) / 2, vC - 0.06, 0.08, H_PLAFOND - yEns - 1.2, 0.08, NOIR)

-- ---- 6. L ETAL DE FRUITS : les pommes a gauche, les tomates a droite ----
local uF1, uF2 = 22, 30
local vF = -A - 3
bloc("Etal", (uF1 + uF2) / 2, 1.2, vF, uF2 - uF1, 2.4, 3.6, BOIS, Enum.Material.Wood)
-- le plateau penche vers l allee
local pente = math.rad(20)
local plateau = piece("CageotFruits", Vector3.new(uF2 - uF1 - 0.4, 0.3, 3.4),
	G * CFrame.new((uF1 + uF2) / 2, 2.9, vF) * CFrame.Angles(-pente, 0, 0), Color3.fromRGB(120, 80, 45), Enum.Material.WoodPlanks)
for i = 0, 9 do
	for j = 0, 3 do
		local p = plateau.CFrame * CFrame.new(-3.4 + i * 0.75 + (j % 2) * 0.35, 0.45, -1.2 + j * 0.8)
		local rouge = hasard:NextInteger(170, 225)
		local tomate = i >= 5
		local b = piece(tomate and "TomateEtal" or "PommeEtal", Vector3.new(0.7, 0.7, 0.7), p,
			tomate and Color3.fromRGB(235, hasard:NextInteger(35, 70), 30) or Color3.fromRGB(rouge, hasard:NextInteger(20, 60), 30),
			nil, magasin, Enum.PartType.Ball)
		b.CanCollide = false
	end
end
local uFm = (uF1 + uF2) / 2
for k, id in ipairs({"Pomme", "Tomate"}) do
	local u = (k == 1) and (uF1 + uFm) / 2 or (uFm + uF2) / 2
	exposer(id, u, 3.9, vF - 0.6)
	zoneAchat(id, u, 3, vF, uFm - uF1, 3, 3.6, Vector3.new(0, 0, 1), u, 1.6, vF + 1.86)
end

-- ---- 7. LE BAC A GLACES ----
local uG1, uG2 = 36, 44
local vG = -A - 2.5
-- le bas plein jusqu a 2, puis 4 rebords jusqu a 2,8 : les bacs se voient par-dessus
bloc("Congelateur", (uG1 + uG2) / 2, 1, vG, uG2 - uG1, 2, 3.4, BLANC)
for _, c in ipairs({-1, 1}) do
	bloc("Rebord", (uG1 + uG2) / 2, 2.4, vG + c * 1.6, uG2 - uG1, 0.8, 0.2, BLANC)
	bloc("Rebord", (uG1 + uG2) / 2 + c * ((uG2 - uG1) / 2 - 0.1), 2.4, vG, 0.2, 0.8, 3.4, BLANC)
end
bloc("VitreCongelateur", (uG1 + uG2) / 2, 2.85, vG, uG2 - uG1 - 0.4, 0.1, 3, Color3.fromRGB(190, 230, 255), Enum.Material.Glass).Transparency = 0.6
bloc("NeonCongelateur", (uG1 + uG2) / 2, 2.3, vG + 1.72, uG2 - uG1, 0.15, 0.05, Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
local PARFUMS = {Color3.fromRGB(255, 175, 195), Color3.fromRGB(110, 65, 40), Color3.fromRGB(250, 240, 200),
	Color3.fromRGB(140, 220, 120), Color3.fromRGB(255, 200, 80), Color3.fromRGB(200, 120, 220)}
for i, c in ipairs(PARFUMS) do      -- les bacs de glace, a l interieur
	bloc("BacGlace", uG1 + 0.8 + (i - 1) * 1.28, 2.4, vG - 0.6, 1.1, 0.7, 1.6, c)
end
for i = 0, 3 do                     -- des cornets sur le dessus, dans un support
	exposer("Glace", uG1 + 1.5 + i * 1.6, 3.55, vG + 0.9)
end
bloc("SupportCornets", (uG1 + uG2) / 2, 2.95, vG + 0.9, 6.4, 0.1, 0.8, GRIS, Enum.Material.Metal)
zoneAchat("Glace", (uG1 + uG2) / 2, 2.5, vG, uG2 - uG1, 3, 3.4, Vector3.new(0, 0, 1), (uG1 + uG2) / 2, 1.6, vG + 1.76)

-- ---- 8. LES 2 RAYONS (gondoles), cote fond ----
local COULEURS_BOITES = {Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 200, 60), Color3.fromRGB(70, 130, 220),
	Color3.fromRGB(245, 245, 240), Color3.fromRGB(240, 140, 50), Color3.fromRGB(120, 190, 90), Color3.fromRGB(150, 90, 180)}
local function gondole(u1, u2, v, reserve)
	local r = Instance.new("Model")
	r.Name = "Rayon"
	r.Parent = magasin
	local L = u2 - u1
	local uM = (u1 + u2) / 2
	bloc("Socle", uM, 0.25, v, L, 0.5, P_RAYON, GRIS, nil, r)
	bloc("Dos", uM, H_RAYON / 2, v, L, H_RAYON, 0.2, BLANC, nil, r)
	for _, bout in ipairs({u1, u2}) do
		bloc("Montant", bout, H_RAYON / 2, v, 0.3, H_RAYON, P_RAYON, VERT, nil, r)
	end
	local hEt = (H_RAYON - 0.5) / NB_ETAGERES
	for e = 0, NB_ETAGERES - 1 do
		local y = 0.5 + e * hEt
		for _, face in ipairs({-1, 1}) do
			local vE = v + face * P_RAYON / 4
			if e > 0 then bloc("Etagere", uM, y, vE, L - 0.3, 0.1, P_RAYON / 2 - 0.2, GRIS, Enum.Material.Metal, r) end
			-- les boites, cote a cote ; la place reservee a un produit reste libre
			local u = u1 + 0.3
			while true do
				local larg = hasard:NextNumber(0.8, 1.6)
				if u + larg > u2 - 0.3 then break end
				local libre = true
				if reserve and face == reserve.face and e >= 1 and e <= 2 and u + larg > reserve.u1 and u < reserve.u2 then libre = false end
				if libre then
					local haut = hasard:NextNumber(0.7, hEt - 0.3)
					local b = bloc("Boite", u + larg / 2, y + 0.05 + haut / 2, vE, larg - 0.1, haut, P_RAYON / 2 - 0.5,
						COULEURS_BOITES[hasard:NextInteger(1, #COULEURS_BOITES)], nil, r)
					b.CanCollide = false
				end
				u += larg
			end
		end
	end
	return r, hEt
end
local vR1, vR2 = A + 9, A + 21
local res = {id = "Ressort", face = -1, u1 = 13, u2 = 20}     -- le bonbon ressort : rayon 1, face allee
local _, hEt = gondole(10, 42, vR1, res)
gondole(10, 42, vR2)
-- les bonbons ressort, sur les 2 etageres du milieu, dans leur place reservee
for e = 1, 2 do
	local y = 0.5 + e * hEt + 0.45
	for i = 0, 7 do
		exposer(res.id, res.u1 + 0.5 + i * 0.85, y, vR1 - P_RAYON / 4 - 0.1)
	end
end
panneau("BandeauRayon", (res.u1 + res.u2) / 2, H_RAYON + 0.6, vR1 - 0.15, res.u2 - res.u1, 1.1, Vector3.new(0, 0, -1),
	{{texte = "BONBONS", part = 1}}, Color3.fromRGB(255, 80, 170))
zoneAchat(res.id, (res.u1 + res.u2) / 2, 2.5, vR1 - P_RAYON / 4, res.u2 - res.u1, 4, P_RAYON / 2 + 1,
	Vector3.new(0, 0, -1), (res.u1 + res.u2) / 2, 0.5 + hEt - 0.5, vR1 - P_RAYON / 2 - 0.08)

-- ---- 9. LE FRIGO MURAL (les boissons), contre le mur du fond ----
local uB1, uB2 = 6, 22
local P_FRIGO, H_FRIGO = 2.6, 8
local vB = vMax - P_FRIGO / 2 - 0.2
local frigo = Instance.new("Model")
frigo.Name = "Frigo"
frigo.Parent = magasin
-- un caisson CREUX (fond, cotes, dessus, dessous) : sinon on ne verrait pas les bouteilles
bloc("FondFrigo", (uB1 + uB2) / 2, H_FRIGO / 2, vB + P_FRIGO / 2 - 0.3, uB2 - uB1, H_FRIGO, 0.2, BLANC, nil, frigo)
for _, bout in ipairs({uB1, uB2}) do
	bloc("CoteFrigo", bout, H_FRIGO / 2, vB, 0.2, H_FRIGO, P_FRIGO, GRIS, nil, frigo)
end
bloc("DessusFrigo", (uB1 + uB2) / 2, H_FRIGO - 0.1, vB, uB2 - uB1, 0.2, P_FRIGO, GRIS, nil, frigo)
bloc("DessousFrigo", (uB1 + uB2) / 2, 0.25, vB, uB2 - uB1, 0.5, P_FRIGO, GRIS, nil, frigo)
bloc("Fronton", (uB1 + uB2) / 2, H_FRIGO + 0.6, vB, uB2 - uB1, 1.2, P_FRIGO, VERT, nil, frigo)
panneau("TexteFrigo", (uB1 + uB2) / 2, H_FRIGO + 0.6, vB - P_FRIGO / 2 - 0.06, uB2 - uB1 - 1, 1, Vector3.new(0, 0, -1),
	{{texte = "BOISSONS FRAÎCHES", part = 1}}, VERT, frigo)
local NB_PORTES = 4
local lPorte = (uB2 - uB1) / NB_PORTES
local vPorte = vB - P_FRIGO / 2 + 0.05
for i = 0, NB_PORTES - 1 do
	local uP = uB1 + (i + 0.5) * lPorte
	local vitre = bloc("PorteVitree", uP, H_FRIGO / 2, vPorte, lPorte - 0.15, H_FRIGO - 0.3, 0.1, Color3.fromRGB(200, 230, 255), Enum.Material.Glass, frigo)
	vitre.Transparency = 0.7
	bloc("Poignee", uP + lPorte / 2 - 0.4, H_FRIGO / 2, vPorte - 0.15, 0.12, 2, 0.12, Color3.fromRGB(200, 200, 205), Enum.Material.Metal, frigo)
	bloc("CadrePorte", uP - lPorte / 2 + 0.05, H_FRIGO / 2, vPorte, 0.1, H_FRIGO, 0.2, NOIR, nil, frigo)
end
local lumiere = bloc("NeonFrigo", (uB1 + uB2) / 2, H_FRIGO - 0.3, vB, uB2 - uB1 - 0.4, 0.1, 1, BLANC, Enum.Material.Neon, frigo)
local spot = Instance.new("SurfaceLight")
spot.Face = Enum.NormalId.Bottom
spot.Range, spot.Brightness, spot.Angle = 9, 1.5, 120
spot.Parent = lumiere
-- les etageres et les bouteilles ; la 1re porte = les boissons energisantes
local NB_ET_FRIGO = 4
local BOUTEILLES = {Color3.fromRGB(80, 160, 255), Color3.fromRGB(200, 30, 30), Color3.fromRGB(250, 150, 30), Color3.fromRGB(240, 240, 240)}
for e = 0, NB_ET_FRIGO - 1 do
	local y = 0.6 + e * (H_FRIGO - 1) / NB_ET_FRIGO
	bloc("EtagereFrigo", (uB1 + uB2) / 2, y, vB + 0.1, uB2 - uB1 - 0.3, 0.08, P_FRIGO - 0.6, Color3.fromRGB(200, 200, 205), Enum.Material.Metal, frigo)
	for i = 0, NB_PORTES - 1 do
		local u0 = uB1 + i * lPorte + 0.5
		for k = 0, math.floor((lPorte - 1) / 0.75) do
			if i == 0 then
				exposer("Energie", u0 + k * 0.75, y + 0.65, vB - 0.3).Parent = frigo
			else
				local c = BOUTEILLES[(i + e) % #BOUTEILLES + 1]
				local b = piece("Bouteille", Vector3.new(1.4, 0.5, 0.5), G * CFrame.new(u0 + k * 0.75, y + 0.75, vB - 0.3) * DEBOUT,
					c, Enum.Material.Glass, frigo, Enum.PartType.Cylinder)
				b.Transparency, b.CanCollide = 0.2, false
			end
		end
	end
end
zoneAchat("Energie", uB1 + lPorte / 2, H_FRIGO / 2, vB, lPorte, H_FRIGO, P_FRIGO + 1.5,
	Vector3.new(0, 0, -1), uB1 + lPorte / 2, 5.5, vPorte - 0.12)

-- ---- 10. LES PANIERS, a l entree ----
for i = 0, 4 do
	bloc("Panier", 2.5, 0.4 + i * 0.35, A + 2.5, 1.8, 0.3, 1.3, Color3.fromRGB(220, 50, 50), Enum.Material.Plastic)
end

if enregistrement then
	ChangeHistoryService:FinishRecording(enregistrement, Enum.FinishRecordingOperation.Commit)
end
local n = 0
for _, d in ipairs(magasin:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print("Epicerie construite : " .. n .. " pieces. N oublie pas Ctrl+S !")
