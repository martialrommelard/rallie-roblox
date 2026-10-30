-- ============================================================
--  LE SHOWROOM (generateur)
--  A lancer UNE fois dans Studio, en mode Edit.
--
--  Les deux GRANDS PORTAILS de garage du sous-sol (un sur chaque
--  batiment du spawn, cote piste, avec leur rampe) ne menaient plus
--  nulle part : devant, il y a maintenant les stands et la cloture.
--  On en fait une VITRINE :
--    - chaque portail est ferme par une grande BAIE VITREE ;
--    - derriere, sur un sol brillant, les 5 VOITURES DU GARAGE sur des
--      podiums eclaires, chacune a sa couleur, avec un panneau (nom,
--      prix, description) ;
--    - au fond, l enseigne "SHOWROOM".
--  On les voit depuis les stands, et on les visite par le sous-sol.
--
--  Rien n est ecrit en dur : les portails sont DEMANDES au sous-sol (les
--  pieces "SeuilSalle" et leurs rampes), les voitures au catalogue du
--  garage (ReplicatedStorage.GarageCatalogue : noms, prix, couleurs).
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local zone   = workspace:WaitForChild("ZoneSpawn")
local salle  = zone:WaitForChild("SalleSousSpawn")
local Catalogue = require(ReplicatedStorage:WaitForChild("GarageCatalogue"))

-- ---- LES REGLAGES ----
local H_VITRE    = 36.6   -- la baie vitree monte jusque sous le rideau roule
local PAS_MONTANT = 10.7  -- un montant blanc tous les ~10 studs
local PROF_PODIUM = 28    -- les podiums, a 28 studs derriere la vitre
local R_PODIUM   = 11
local ANGLE      = 25     -- les voitures sont un peu de biais (degres)

local BLANC = Color3.fromRGB(242, 242, 245)
local VERRE = Color3.fromRGB(160, 205, 235)
local SOMBRE = Color3.fromRGB(28, 30, 36)
local NEON  = Color3.fromRGB(0, 225, 255)

-- ---- ON REPART DE ZERO ----
local ancien = zone:FindFirstChild("Vitrine")
if ancien then ancien:Destroy() end
local vitrine = Instance.new("Folder")
vitrine.Name = "Vitrine"

local function piece(nom, taille, cf, couleur, matiere, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or vitrine
	return p
end
local function texte(parent, t, taille, position, couleur, police)
	local l = Instance.new("TextLabel")
	l.Size, l.Position = taille, position
	l.BackgroundTransparency = 1
	l.TextColor3 = couleur
	l.Font = police or Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = t
	l.Parent = parent
	return l
end

-- =========================================================
-- 1. LES PORTAILS : chaque "SeuilSalle" et sa rampe (dehors)
-- =========================================================
local seuils, rampes = {}, {}
for _, p in ipairs(salle:GetChildren()) do
	if p.Name == "SeuilSalle" then table.insert(seuils, p) end
	if p.Name == "RampeGarage" then table.insert(rampes, p) end
end
table.sort(seuils, function(a, b) return a.Position.X < b.Position.X end)

-- les voitures, reparties : la moitie (arrondie au-dessus) dans le 1er portail
local voitures = Catalogue.VOITURES
local nb1 = math.ceil(#voitures / #seuils)

-- une voiture POUR DE FAUX : la voiture de rally, sans scripts, ancree
-- (avec SA carrosserie : la Flash est exposee avec ses yeux et ses eclairs)
local function voitureExpo(info)
	local v = ServerStorage:WaitForChild(Catalogue.carrosserie(info.nom)):Clone()
	v.Name = "Expo" .. info.nom
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Constraint") or d:IsA("VehicleSeat") or d:IsA("Seat") then
			d:Destroy()
		end
	end
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
		if d:IsA("TextLabel") and d.Name == "Numero" then d.Text = "" end
	end
	Catalogue.peindre(v, Catalogue.couleur(info.nom, 1))
	return v
end

local numero = 0
for k, seuil in ipairs(seuils) do
	-- le repere du portail : X le long du portail, -Z vers DEHORS (la rampe)
	local rampe, dMin = nil, math.huge
	for _, r in ipairs(rampes) do
		local d = (r.Position - seuil.Position).Magnitude
		if d < dMin then rampe, dMin = r, d end
	end
	local dedans = ((seuil.Position - rampe.Position) * Vector3.new(1, 0, 1)).Unit
	local ySol = seuil.Position.Y + seuil.Size.Y / 2
	local o = Vector3.new(seuil.Position.X, ySol, seuil.Position.Z)
	local base = CFrame.lookAt(o, o - dedans)        -- regarde dehors : -Z = dehors, +Z = dedans
	local largeur = seuil.Size.X
	local function ici(x, y, z) return base * CFrame.new(x, y, z) end

	-- 2. LA BAIE VITREE et ses montants
	-- (pas en matiere Glass : derriere du Glass, Roblox n affiche pas les
	-- textes des panneaux ! Du plastique tres transparent, un peu brillant)
	local baie = piece("BaieVitree", Vector3.new(largeur, H_VITRE, 0.5), ici(0, H_VITRE / 2, 0), VERRE)
	baie.Transparency = 0.85      -- tres claire : on doit voir les voitures, pas la vitre
	baie.Reflectance = 0.1
	baie.CastShadow = false
	local n = math.max(1, math.round(largeur / PAS_MONTANT))
	for i = 0, n do
		local x = -largeur / 2 + i * largeur / n
		piece("Montant", Vector3.new(0.8, H_VITRE, 0.9), ici(x, H_VITRE / 2, 0), BLANC, Enum.Material.Metal)
	end
	piece("Traverse", Vector3.new(largeur, 0.8, 0.9), ici(0, 0.4, 0), BLANC, Enum.Material.Metal)
	piece("Traverse", Vector3.new(largeur, 0.8, 0.9), ici(0, H_VITRE - 0.4, 0), BLANC, Enum.Material.Metal)

	-- 3. LE SOL BRILLANT
	local profondeur = PROF_PODIUM * 2
	local sol = piece("SolShowroom", Vector3.new(largeur - 2, 0.1, profondeur), ici(0, 0.05, profondeur / 2 + 1), SOMBRE)
	sol.Reflectance = 0.2

	-- 4. LES VOITURES sur leurs podiums
	local premiere = (k == 1) and 1 or (nb1 + 1)
	local derniere = (k == 1) and nb1 or #voitures
	local nbIci = derniere - premiere + 1
	for i = premiere, derniere do
		local info = voitures[i]
		numero += 1
		local rang = i - premiere                                   -- 0, 1, 2...
		local x = (rang - (nbIci - 1) / 2) * (largeur / nbIci)      -- reparties sur la largeur
		local centre = ici(x, 0, PROF_PODIUM)
		-- (plus il y a de voitures, plus les podiums sont petits : ils ne se touchent pas)
		local r = math.min(R_PODIUM, largeur / nbIci / 2 - 1)
		-- le podium (un disque) et son anneau de neon
		local disque = piece("Podium", Vector3.new(1, r * 2, r * 2), centre * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), SOMBRE, Enum.Material.Metal)
		disque.Shape = Enum.PartType.Cylinder
		disque.Reflectance = 0.1
		local anneau = piece("AnneauPodium", Vector3.new(0.6, r * 2 + 1, r * 2 + 1), centre * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), info.couleur, Enum.Material.Neon)
		anneau.Shape = Enum.PartType.Cylinder
		-- la voiture, posee sur le disque, de biais, le nez vers la vitre
		local v = voitureExpo(info)
		v.Parent = vitrine
		local boite, taille = v:GetBoundingBox()
		local decalage = v:GetPivot():ToObjectSpace(boite)
		local cible = centre * CFrame.new(0, 1 + taille.Y / 2, 0) * CFrame.Angles(0, math.rad((rang % 2 == 0) and ANGLE or -ANGLE), 0)
		v:PivotTo(cible * decalage:Inverse())
		-- le spot au plafond (une lumiere LOCALE, vers le bas)
		local spot = piece("Spot", Vector3.new(2, 1, 2), centre * CFrame.new(0, 40.5, 0), SOMBRE, Enum.Material.Metal)
		local l = Instance.new("SpotLight")
		l.Face, l.Range, l.Angle, l.Brightness = Enum.NormalId.Bottom, 50, 45, 4
		l.Color = Color3.fromRGB(255, 245, 230)
		l.Parent = spot
		-- le panneau devant (cote vitre) : nom, prix, description. Un
		-- PUPITRE bas et penche : il ne cache pas la voiture derriere lui.
		local pied = piece("PiedPanneau", Vector3.new(0.6, 1.6, 0.6), centre * CFrame.new(0, 0.8, -r - 3), SOMBRE, Enum.Material.Metal)
		local panneau = piece("Panneau", Vector3.new(9, 4.5, 0.3), centre * CFrame.new(0, 2.6, -r - 3) * CFrame.Angles(math.rad(55), 0, 0), SOMBRE)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front            -- vers la vitre (et ceux qui regardent)
		g.PixelsPerStud = 30
		g.LightInfluence = 0                    -- lisible meme dans l ombre
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud   -- sinon Roblox ignore PixelsPerStud (cadre fixe 800x600 etire : lettres ecrasees)
		local bande = Instance.new("Frame")
		bande.Size = UDim2.new(1, 0, 0.08, 0)
		bande.BackgroundColor3 = info.couleur
		bande.BorderSizePixel = 0
		bande.Parent = g
		-- (pas d emoji : sur un panneau, Roblox les affiche en carre)
		texte(g, info.nom, UDim2.new(0.94, 0, 0.34, 0), UDim2.new(0.03, 0, 0.12, 0), Color3.new(1, 1, 1))
		texte(g, (info.prix == 0) and "GRATUITE" or (info.prix .. " PIÈCES"), UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0.47, 0), Color3.fromRGB(255, 205, 60))
		texte(g, info.texte, UDim2.new(0.94, 0, 0.26, 0), UDim2.new(0.03, 0, 0.69, 0), Color3.fromRGB(225, 228, 235), Enum.Font.GothamMedium)
		g.Parent = panneau
		pied.Parent, panneau.Parent = vitrine, vitrine
	end

	-- 5. L ENSEIGNE au fond
	local fond = piece("EnseigneShowroom", Vector3.new(math.min(60, largeur - 10), 9, 0.4), ici(0, 26, profondeur + 4), SOMBRE)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.PixelsPerStud = 15
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.LightInfluence = 0
	texte(g, "SHOWROOM", UDim2.new(1, 0, 0.62, 0), UDim2.new(0, 0, 0.04, 0), NEON)
	texte(g, "Ces voitures s'achètent au GARAGE, sous le spawn", UDim2.new(1, 0, 0.26, 0), UDim2.new(0, 0, 0.7, 0), Color3.new(1, 1, 1), Enum.Font.GothamBold)
	g.Parent = fond
	piece("NeonShowroom", Vector3.new(math.min(60, largeur - 10), 0.4, 0.5), ici(0, 21.3, profondeur + 4), NEON, Enum.Material.Neon)
end

vitrine.Parent = zone
print(string.format("Showroom : %d portails fermes par une baie vitree, %d voitures exposees", #seuils, numero))
