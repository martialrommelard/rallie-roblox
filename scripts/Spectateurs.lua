-- ============================================================
--  LES SPECTATEURS (generateur)
--  A lancer UNE fois dans Studio, en mode Edit.
--
--  Des petits bonshommes en blocs ASSIS dans les gradins du spawn, face
--  a la piste, repartis un peu partout (au hasard, mais toujours les
--  memes : le hasard a une graine fixe). Chacun a sa couleur de peau, son
--  t-shirt, son pantalon ; certains ont une casquette, d autres un
--  drapeau aux couleurs d une ecurie.
--  Ils sont en decor (ancres, on passe a travers, invisibles pour les
--  rayons) ; le siege qu ils occupent est desactive (on ne s assoit pas
--  sur quelqu un !). C est le LocalScript Spectateurs.client qui les fait
--  se lever et applaudir quand les voitures passent.
--
--  Rien n est ecrit en dur : on DEMANDE au spawn ses sieges (les modeles
--  "Siege" : une "Assise" et un "Dossier") ; le dossier dit ou est
--  l arriere, donc dans quel sens le spectateur regarde.
--  ⚠️ Il modifie la place : Ctrl+S apres !
-- ============================================================

local zone = workspace:WaitForChild("ZoneSpawn")

local REMPLISSAGE = 0.4      -- 40 % des sieges sont occupes
local GRAINE      = 1234     -- change-la pour une autre foule

local PEAUX = {
	Color3.fromRGB(255, 220, 185), Color3.fromRGB(240, 195, 150), Color3.fromRGB(205, 150, 105),
	Color3.fromRGB(160, 110, 70), Color3.fromRGB(110, 75, 50), Color3.fromRGB(255, 205, 160),
}
local HABITS = {
	Color3.fromRGB(215, 40, 45), Color3.fromRGB(40, 110, 230), Color3.fromRGB(40, 175, 80),
	Color3.fromRGB(255, 140, 30), Color3.fromRGB(140, 60, 210), Color3.fromRGB(240, 200, 30),
	Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 30, 35), Color3.fromRGB(0, 170, 190),
	Color3.fromRGB(255, 110, 170), Color3.fromRGB(120, 85, 60), Color3.fromRGB(90, 95, 110),
}
local PANTALONS = {
	Color3.fromRGB(35, 50, 90), Color3.fromRGB(30, 30, 35), Color3.fromRGB(70, 70, 75),
	Color3.fromRGB(110, 85, 60), Color3.fromRGB(45, 70, 50), Color3.fromRGB(150, 150, 155),
}
-- les couleurs des ecuries (comme dans Stands.lua) : pour les drapeaux
local ECURIES = {
	Color3.fromRGB(215, 40, 45), Color3.fromRGB(40, 110, 230), Color3.fromRGB(40, 175, 80),
	Color3.fromRGB(255, 140, 30), Color3.fromRGB(140, 60, 210), Color3.fromRGB(240, 200, 30),
}

-- ---- ON REPART DE ZERO ----
local ancien = zone:FindFirstChild("Spectateurs")
if ancien then
	-- on rend les sieges qu ils occupaient
	for _, s in ipairs(zone:GetDescendants()) do
		if s:IsA("Seat") and s:GetAttribute("PrisParSpectateur") then
			s.Disabled = false
			s:SetAttribute("PrisParSpectateur", nil)
		end
	end
	ancien:Destroy()
end
local dossier = Instance.new("Folder")
dossier.Name = "Spectateurs"

local hasard = Random.new(GRAINE)
local function auHasard(liste) return liste[hasard:NextInteger(1, #liste)] end

local function bloc(m, nom, taille, cf, couleur, matiere)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false          -- (beaucoup de pieces : sans ombre, c est plus leger)
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- UN SPECTATEUR assis. "base" : le repere du siege, au-dessus de l assise,
-- -Z = vers la piste (devant lui)
local function spectateur(base)
	local m = Instance.new("Model")
	m.Name = "Spectateur"
	local function ici(x, y, z) return base * CFrame.new(x, y, z) end
	local peau = auHasard(PEAUX)
	local habit = auHasard(HABITS)
	local pantalon = auHasard(PANTALONS)
	-- le corps, les jambes (cuisses sur le siege, mollets qui pendent)
	local torse = bloc(m, "Torse", Vector3.new(2, 2, 1), ici(0, 1, 0.5), habit)
	for _, x in ipairs({-0.5, 0.5}) do
		bloc(m, "Cuisse", Vector3.new(1, 1, 2), ici(x, 0.5, -0.5), pantalon)
		bloc(m, "Mollet", Vector3.new(1, 1.4, 1), ici(x, -0.7, -1.0), pantalon)
	end
	-- les bras : le client les fait lever (attribut "Bras" = l epaule, dans
	-- le repere du torse)
	for _, x in ipairs({-1.5, 1.5}) do
		local bras = bloc(m, "Bras", Vector3.new(1, 2, 1), ici(x, 1, 0.5), peau)
		bras:SetAttribute("Cote", x)
	end
	-- la tete, avec un visage
	local tete = bloc(m, "Tete", Vector3.new(1.2, 1.2, 1.2), ici(0, 2.6, 0.5), peau)
	local forme = Instance.new("SpecialMesh")
	forme.MeshType = Enum.MeshType.Head
	forme.Scale = Vector3.new(1.25, 1.25, 1.25)
	forme.Parent = tete
	local visage = Instance.new("Decal")
	visage.Name = "Visage"
	visage.Face = Enum.NormalId.Front
	visage.Texture = "rbxasset://textures/face.png"
	visage.Parent = tete
	-- une casquette (1 sur 4)
	if hasard:NextNumber() < 0.25 then
		local c = auHasard(HABITS)
		bloc(m, "Casquette", Vector3.new(1.3, 0.45, 1.3), ici(0, 3.25, 0.5), c)
		bloc(m, "Visiere", Vector3.new(1.2, 0.12, 0.7), ici(0, 3.05, -0.35), c)
	end
	-- un drapeau d ecurie (1 sur 6) : tenu dans la main droite
	if hasard:NextNumber() < 1 / 6 then
		local c = auHasard(ECURIES)
		bloc(m, "Hampe", Vector3.new(0.15, 4, 0.15), ici(1.5, 1.8, -0.2), Color3.fromRGB(80, 60, 45), Enum.Material.Wood)
		local d = bloc(m, "Drapeau", Vector3.new(1.8, 1.2, 0.08), ici(2.4, 3.2, -0.2), c, Enum.Material.Fabric)
		d:SetAttribute("Couleur", c)
	end
	m.PrimaryPart = torse
	m.Parent = dossier
	return m
end

-- ---- LES SIEGES DU SPAWN ----
local sieges = {}
for _, s in ipairs(zone:GetChildren()) do
	if s.Name == "Siege" and s:IsA("Model") and s:FindFirstChild("Assise") and s:FindFirstChild("Dossier") then
		table.insert(sieges, s)
	end
end
table.sort(sieges, function(a, b)       -- (dans un ordre fixe : avec la graine, toujours la meme foule)
	local pa, pb = a.Assise.Position, b.Assise.Position
	if math.abs(pa.Z - pb.Z) > 0.1 then return pa.Z < pb.Z end
	return pa.X < pb.X
end)

local n = 0
for _, s in ipairs(sieges) do
	if hasard:NextNumber() < REMPLISSAGE then
		local assise, dos = s.Assise, s.Dossier
		-- devant = de son dossier vers l assise (a plat)
		local devant = ((assise.Position - dos.Position) * Vector3.new(1, 0, 1)).Unit
		local dessus = assise.Position + Vector3.new(0, assise.Size.Y / 2, 0)
		spectateur(CFrame.lookAt(dessus, dessus + devant))
		assise.Disabled = true                         -- la place est prise
		assise:SetAttribute("PrisParSpectateur", true)
		n += 1
	end
end

dossier.Parent = zone
print(string.format("Spectateurs : %d assis sur %d sieges", n, #sieges))
