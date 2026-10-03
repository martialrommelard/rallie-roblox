-- ============================================================
--  LA ZONE DE SPAWN (le "village" du depart)
--  A coller dans la barre de commande de Studio (View > Command Bar).
--  On peut le relancer autant qu on veut : il efface et refait tout.
--
--  Une grande plateforme en demi-rond, en hauteur, loin de la piste,
--  DEVANT la ligne de depart, l ARRONDI tourne vers la piste et le cote
--  plat au fond. Le point d apparition est dedans, tourne vers la piste.
--  Les gradins viendront sur les cotes.
--
--     ligne
--  ═════╪═════════════ PISTE ═════════════>   (sens de la course)
--    ───┼──────────── barriere ───────────────
--       |  AVANCE    (DEGAGE : de l herbe)
--       |<------>   [gradins]  ╱‾‾‾‾‾‾‾‾╲  [gradins]
--                             │  spawn  │
--                             └─────────┘ <- cote plat au fond
--
--  Rien n est ecrit en coordonnees : tout est demande a LigneDepart
--  (sa position, le sens de la course, la largeur de la route).
-- ============================================================

-- Les dimensions viennent du bloc-guide pose a la main dans Studio le
-- 2026-10-03 (247 x 137 studs, 158 studs devant la ligne, 131 d herbe).
local COTE         = 1     -- 1 = a droite de la piste (vu du pilote), -1 = a gauche
local AVANCE       = 158   -- studs DEVANT la ligne, dans le sens de la course (0 = pile en face)
local DEMI_LARGEUR = 124   -- la moitie de la largeur, le long de la piste
local PROFONDEUR   = 137   -- du cote plat (au fond) jusqu au bout de l arrondi
local DEGAGE       = 131   -- studs d herbe entre le bord de la route et la plateforme
local NB           = 72    -- nombre de parts de l arrondi (plus = plus rond)
local DESSUS       = 69    -- hauteur de la plateforme au-dessus de l herbe (le bloc-guide)
local GARDE_CORPS  = false -- true = garde-corps rouge et blanc tout autour (enleve le 2026-10-03)
local BORDURE_H    = 3     -- hauteur du garde-corps
local SPAWN_A      = 0.42  -- ou est le spawn : 0 = cote plat, 1 = bout de l arrondi
-- Le sol : blanc et lisse, sans texture, pour ne pas fatiguer les yeux en
-- jouant. Le spawn est de la MEME couleur : on ne le remarque pas.
local COULEUR_SOL  = Color3.fromRGB(245, 245, 245)
local MATIERE_SOL  = Enum.Material.SmoothPlastic

-- UN SEUL NOMBRE pour tout agrandir ou retrecir : il multiplie toutes les
-- distances du dessus (pas la hauteur du garde-corps : c est l avatar qui
-- la decide, lui ne change pas de taille).
-- 1 = la taille du bloc-guide ; 0.65 = un tiers plus petit (2026-10-03 :
-- "c est grand par rapport a l avatar").
local ECHELLE = 0.65
AVANCE, DEMI_LARGEUR, PROFONDEUR = AVANCE * ECHELLE, DEMI_LARGEUR * ECHELLE, PROFONDEUR * ECHELLE
DEGAGE, DESSUS = DEGAGE * ECHELLE, DESSUS * ECHELLE

local circuit = workspace:WaitForChild("Circuit")
local ligne   = circuit:WaitForChild("LigneDepart")

-- ---- ON DEMANDE TOUT A LA LIGNE ----
local sens   = ligne.CFrame.LookVector                     -- sens de la course
sens = Vector3.new(sens.X, 0, sens.Z).Unit
local cote   = ligne.CFrame.RightVector * COTE             -- vers la zone de spawn
cote = Vector3.new(cote.X, 0, cote.Z).Unit
local demiRoute = ligne.Size.X / 2                          -- la ligne fait la largeur de la route

-- Le sol : on demande sa hauteur a la plaque d herbe, juste a cote.
local herbe = workspace:FindFirstChild("Baseplate")
local solY  = herbe and (herbe.Position.Y + herbe.Size.Y / 2) or 0
local hautY = solY + DESSUS

-- Le centre : au milieu du cote plat, qui est AU FOND (loin de la piste).
-- L arrondi part de la vers la piste : son bout s arrete a DEGAGE studs
-- du bord de la route.
local versRoute = -cote
local base   = ligne.Position + sens * AVANCE + cote * (demiRoute + DEGAGE + PROFONDEUR)
local centre = Vector3.new(base.X, hautY, base.Z)

-- Le point du bord a l angle a (0 = un bout du cote plat, pi = l autre).
-- C est le cercle "etire" : DEMI_LARGEUR le long de la piste, PROFONDEUR
-- vers la piste. Avec deux fois le meme nombre, on retrouve un cercle.
local function bord(a)
	return centre + sens * (math.cos(a) * DEMI_LARGEUR) + versRoute * (math.sin(a) * PROFONDEUR)
end

-- ---- ON REPART DE ZERO ----
local zone = workspace:FindFirstChild("ZoneSpawn")
if zone then zone:Destroy() end
zone = Instance.new("Folder")
zone.Name = "ZoneSpawn"
zone.Parent = workspace

local function bloc(parent, nom, taille, cf, mat, couleur)
	local p = Instance.new("Part")
	p.Name = nom; p.Anchored = true; p.Size = taille; p.CFrame = cf
	p.Material = mat; p.Color = couleur
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local ROUGE = Color3.fromRGB(200, 40, 40)
local BLANC = Color3.fromRGB(235, 235, 235)

-- ---- LE SOL ----
-- Un eventail de NB parts. Chacune couvre le triangle (centre, bord a1,
-- bord a2) : un rectangle dont le bout est la corde entre les deux points
-- du bord, et qui recule jusqu au centre.
-- Elles se chevauchent pres du centre : on decale une part sur deux de
-- 0.02 stud en hauteur, sinon elles clignotent (le z-fighting de la route).
local epais = DESSUS + 1                   -- assez epais pour toucher l herbe
for k = 1, NB do
	local p1, p2 = bord(math.pi * (k - 1) / NB), bord(math.pi * k / NB)
	local corde = p2 - p1
	local dehors = Vector3.new(0, 1, 0):Cross(corde).Unit  -- perpendiculaire a la corde...
	if dehors:Dot((p1 + p2) / 2 - centre) < 0 then dehors = -dehors end  -- ...vers l exterieur
	local recul = ((p1 + p2) / 2 - centre):Dot(dehors) + 2  -- du centre jusqu a la corde
	local y = hautY - epais / 2 + ((k % 2 == 0) and 0.02 or 0)
	local fond = (p1 + p2) / 2
	local milieu = Vector3.new(fond.X, y, fond.Z) - dehors * (recul / 2)
	bloc(zone, "Sol", Vector3.new(corde.Magnitude + 1, epais, recul),
		CFrame.lookAt(milieu, milieu + dehors), MATIERE_SOL, COULEUR_SOL)
end

-- ---- LE GARDE-CORPS ----
-- Le long du cote plat (au fond), un morceau tous les ~10 studs...
local largeur = 2 * DEMI_LARGEUR
if GARDE_CORPS then
	local nbPlat = math.ceil(largeur / 10)
	for k = 1, nbPlat do
		local x = -DEMI_LARGEUR + largeur * (k - 0.5) / nbPlat
		local m = centre + sens * x + Vector3.new(0, BORDURE_H / 2, 0)
		bloc(zone, "Bordure", Vector3.new(1, BORDURE_H, largeur / nbPlat + 0.2),
			CFrame.lookAt(m, m + sens), Enum.Material.SmoothPlastic,
			(k % 2 == 0) and ROUGE or BLANC)
	end
	-- ...et tout le long de l arrondi.
	for k = 1, NB do
		local p1, p2 = bord(math.pi * (k - 1) / NB), bord(math.pi * k / NB)
		local m = (p1 + p2) / 2 + Vector3.new(0, BORDURE_H / 2, 0)
		bloc(zone, "Bordure", Vector3.new(1, BORDURE_H, (p2 - p1).Magnitude + 0.5),
			CFrame.lookAt(m, m + (p2 - p1)), Enum.Material.SmoothPlastic,
			(k % 2 == 0) and ROUGE or BLANC)
	end
end

-- ---- LES ARBRES QUI GENENT ----
-- Le generateur du circuit a plante des arbres au hasard sur l herbe.
-- Un arbre qui deborde sur la plateforme est enleve : le tronc ET le
-- feuillage juste au-dessus. On mesure avec le FEUILLAGE (22 studs de
-- large) : un tronc dehors peut avoir sa boule qui deborde dedans.
local decor = circuit:FindFirstChild("Decor")
if decor then
	for _, tronc in ipairs(decor:GetChildren()) do
		if tronc.Name == "Tronc" then
			local feuillages = {}
			local marge = math.max(tronc.Size.X, tronc.Size.Z) / 2 + 2
			for _, f in ipairs(decor:GetChildren()) do
				local d = Vector3.new(f.Position.X - tronc.Position.X, 0, f.Position.Z - tronc.Position.Z)
				if f.Name == "Feuillage" and d.Magnitude < 4 then
					table.insert(feuillages, f)
					marge = math.max(marge, math.max(f.Size.X, f.Size.Z) / 2 + 2)
				end
			end
			local rel = tronc.Position - centre
			local x = rel:Dot(sens) / (DEMI_LARGEUR + marge)
			local z = rel:Dot(versRoute) / (PROFONDEUR + marge)
			if x * x + z * z < 1 and rel:Dot(versRoute) > -marge then
				for _, f in ipairs(feuillages) do f:Destroy() end
				tronc:Destroy()
				print("Arbre enleve de la zone de spawn")
			end
		end
	end
end

-- ============================================================
--  LES GRADINS ET L ESCALIER (ajoutes le 2026-10-03)
--  D apres le bloc-guide des gradins pose a la main : 374 studs de long,
--  derriere la plateforme. Entre les deux, un COULOIR ou monte l escalier.
--
--      ╱‾‾‾‾‾‾‾‾‾‾‾╲          (plateforme, vue de dessus)
--      └─────┬─────┘
--   ▁▂▃▄▅▆▇ [palier] ▇▆▅▄▃▂▁   <- l escalier double, dans le couloir
--  ┌─────────┴─────────────┐
--  │ allee, puis rangees   │   <- les gradins, de plus en plus hauts
--  └───────────────────────┘
--  Ces mesures-la ne passent PAS par ECHELLE : le bloc-guide des gradins
--  a ete pose apres le retrecissement.
-- ============================================================
local DEMI_LONG_GRADINS = 187   -- la moitie de la longueur des gradins (bloc-guide : 374)
local NB_RANGS          = 10    -- l allee + 9 rangees de bancs (17 -> 6 -> 10 le 2026-10-03 :
                                -- "pas trop", puis "rajoute 3-5 lignes quand meme")
local COULOIR           = 23.9  -- entre le dos de la plateforme et les gradins : les
                                -- gradins sont COLLES au dos des deux carres poses a
                                -- la main (le droit finit a 228 de l axe, le gauche
                                -- a 235 : il s enfonce de 7 studs dans les gradins)
local PROF_RANG         = 5     -- profondeur d une rangee (le banc + la place des pieds)
local HAUT_RANG         = 2.5   -- montee d une rangee a l autre (au MINIMUM : le calcul
                                -- de la ligne de vue peut l augmenter, voir plus bas)
local YEUX              = 4.5   -- hauteur des yeux d un avatar assis : assise 1.5 + 3
local LARG_ESC          = 14    -- largeur de l escalier
local PALIER            = 20    -- largeur du palier au milieu (plateforme -> gradins)
local MARCHE_MAX        = 1.25  -- hauteur maximale d une marche
local BOUT_LIBRE        = 9     -- studs laisses libres a chaque bout du couloir

local GRIS_GRADIN = Color3.fromRGB(200, 200, 205)

local SIEGES       = true    -- true = sieges bleus ; false = bancs rouges
local ESPACE_SIEGE = 7       -- un siege tous les 7 studs ("de l espace entre eux")
local LARG_SIEGE   = 2.5     -- largeur et profondeur de l assise
local PIED_H       = 1       -- le pied gris sous l assise
local ASSISE_E     = 0.5     -- epaisseur de l assise
local DOSSIER_H    = 2.6     -- hauteur du dossier
local DOSSIER_E    = 0.4     -- epaisseur du dossier
local BLEU_SIEGE   = Color3.fromRGB(30, 90, 210)
local BLEU_DOSSIER = Color3.fromRGB(20, 60, 160)
local GRIS_PIED    = Color3.fromRGB(90, 90, 95)

-- Toutes les positions se donnent en (le long de la piste, depuis l axe).
local origine = Vector3.new(ligne.Position.X, 0, ligne.Position.Z)
local haut    = Vector3.new(0, 1, 0)
local function pave(nom, a1, a2, l1, l2, y1, y2, mat, couleur)
	local pos = origine + sens * ((a1 + a2) / 2) + cote * ((l1 + l2) / 2) + haut * ((y1 + y2) / 2)
	-- fromMatrix : l axe X du pave suit la piste, son axe Y monte.
	return bloc(zone, nom, Vector3.new(math.abs(a2 - a1), y2 - y1, math.abs(l2 - l1)),
		CFrame.fromMatrix(pos, sens, haut), mat, couleur)
end

local dos    = demiRoute + DEGAGE + PROFONDEUR   -- le dos de la plateforme (cote plat)
local avant  = dos + COULOIR                     -- le devant des gradins
local milieu = AVANCE                            -- le milieu de la plateforme, le long de la piste

-- ---- A QUELLE HAUTEUR METTRE LES GRADINS ? LA LIGNE DE VUE ----
-- On ne devine pas : on CALCULE. Un spectateur doit voir le bord de la
-- route PAR-DESSUS le bout de la plateforme du spawn (c est elle qui
-- cache la piste). On trace la droite qui part du bord de la route et
-- frole le bout de la plateforme : elle monte de "pente" studs a chaque
-- stud qu on s eloigne. Les yeux du spectateur doivent etre au-dessus.
--
--   yeux ●
--         ╲  <- la ligne de vue
--          ╲___________
--           plateforme │╲
--                      │  ╲_________ route
local routeY = ligne.Position.Y - ligne.Size.Y / 2        -- le dessus du bitume
local bout   = demiRoute + DEGAGE                          -- le bout de la plateforme
local pente  = (hautY - routeY) / (bout - demiRoute)
-- Chaque rangee est PROF_RANG plus loin : elle doit monter d au moins
-- pente x PROF_RANG pour voir, elle aussi, par-dessus la plateforme.
HAUT_RANG = math.max(HAUT_RANG, pente * PROF_RANG + 0.1)
-- La 1re rangee de bancs (la 0, c est l allee) fixe la hauteur de tout le reste.
local assis1 = avant + PROF_RANG + 1.5                     -- ou est assis le spectateur
local yeux1  = hautY + pente * (assis1 - bout) + 1         -- + 1 stud de marge
local SURELEVATION = yeux1 - YEUX - HAUT_RANG - hautY       -- de combien soulever les gradins

-- ---- LES GRADINS ----
-- Rangee 0 : une allee, SURELEVATION studs au-dessus de la plateforme.
-- Puis chaque rangee monte de HAUT_RANG. Chaque rangee est un bloc plein
-- jusqu a l herbe : pas de vide dessous.
local nbRangs = NB_RANGS
for k = 0, nbRangs - 1 do
	local l1 = avant + k * PROF_RANG
	local dessus = hautY + SURELEVATION + k * HAUT_RANG
	pave("Gradin", milieu - DEMI_LONG_GRADINS, milieu + DEMI_LONG_GRADINS,
		l1, l1 + PROF_RANG, solY, dessus, MATIERE_SOL, GRIS_GRADIN)
	if k >= 1 and SIEGES then
		-- des SIEGES tournes vers la piste, un tous les ESPACE_SIEGE studs.
		-- Chacun est un petit modele de 3 pieces :
		--      ▐  <- le dossier (cote fond des gradins)
		--   ▄▄▄▐  <- l assise : un vrai "Seat", on marche dessus, on s assoit
		--    ▐    <- le pied
		local nb = math.floor(2 * DEMI_LONG_GRADINS / ESPACE_SIEGE)
		local c = l1 + 1.75                              -- le milieu de l assise, depuis l axe
		local yAssise = dessus + PIED_H
		for n = 1, nb do
			local a = milieu - DEMI_LONG_GRADINS + ESPACE_SIEGE * (n - 0.5)
			local modele = Instance.new("Model")
			modele.Name = "Siege"
			local pied = pave("Pied", a - 0.5, a + 0.5, c - 0.5, c + 0.5, dessus, yAssise,
				Enum.Material.SmoothPlastic, GRIS_PIED)
			local pos = origine + sens * a + cote * c + haut * (yAssise + ASSISE_E / 2)
			local assise = Instance.new("Seat")
			assise.Name = "Assise"
			assise.Anchored = true
			assise.Size = Vector3.new(LARG_SIEGE, ASSISE_E, LARG_SIEGE)
			-- lookAt vers la piste : un Seat assoit l avatar face a son avant
			assise.CFrame = CFrame.lookAt(pos, pos + versRoute)
			assise.Material = Enum.Material.SmoothPlastic
			assise.Color = BLEU_SIEGE
			assise.TopSurface = Enum.SurfaceType.Smooth
			assise.BottomSurface = Enum.SurfaceType.Smooth
			local dossier = pave("Dossier", a - LARG_SIEGE / 2, a + LARG_SIEGE / 2,
				c + LARG_SIEGE / 2 - DOSSIER_E, c + LARG_SIEGE / 2,
				yAssise + ASSISE_E, yAssise + ASSISE_E + DOSSIER_H, Enum.Material.SmoothPlastic, BLEU_DOSSIER)
			pied.Parent, assise.Parent, dossier.Parent = modele, modele, modele
			modele.PrimaryPart = assise
			modele.Parent = zone
		end
	elseif k >= 1 then
		-- le banc, rouge, au bord de la rangee (on s assoit face a la piste)
		pave("Banc", milieu - DEMI_LONG_GRADINS, milieu + DEMI_LONG_GRADINS,
			l1 + 0.5, l1 + 2.5, dessus, dessus + 1.2, Enum.Material.SmoothPlastic, ROUGE)
	end
end

-- ---- LE PALIER ----
-- Au milieu du couloir, de la plateforme jusqu a l allee des gradins.
pave("Palier", milieu - PALIER / 2, milieu + PALIER / 2, dos, avant, solY, hautY, MATIERE_SOL, COULEUR_SOL)

-- ---- L ESCALIER DOUBLE ----
-- Deux volees, une a chaque bout du couloir, qui montent vers le palier.
-- Le nombre de marches se DEDUIT de la hauteur : aucune marche ne depasse
-- MARCHE_MAX (sinon l avatar doit sauter a chaque marche).
local montee = hautY - solY
local nbMarches = math.ceil(montee / MARCHE_MAX)
local course = (DEMI_LARGEUR - BOUT_LIBRE) - PALIER / 2   -- longueur d une volee
local giron = course / nbMarches                           -- profondeur d une marche
for _, s in ipairs({-1, 1}) do
	for i = 1, nbMarches do
		-- la marche i part du bout du couloir (i = 1, en bas) vers le palier
		local a1 = milieu + s * (DEMI_LARGEUR - BOUT_LIBRE - (i - 1) * giron)
		local a2 = milieu + s * (DEMI_LARGEUR - BOUT_LIBRE - i * giron)
		pave("Marche", a1, a2, dos, dos + LARG_ESC, solY, solY + i * montee / nbMarches,
			MATIERE_SOL, COULEUR_SOL)
	end
end
-- ---- L ESCALIER DU HAUT : du palier jusqu aux gradins ----
-- Les gradins sont SURELEVATION studs plus haut que la plateforme. Un
-- deuxieme escalier double part du palier et monte vers les bouts du
-- couloir, dans la bande qui reste a cote du premier (qui, lui, y
-- descend).
--
-- LE PLANCHER DU HAUT (2026-10-03 : "on tombe dans le vide apres les
-- escaliers... cree un sol pour que ce soit plus propre") : un sol au
-- niveau de l allee des gradins recouvre TOUT le couloir, sur toute la
-- longueur des gradins. Les seuls trous sont les deux tremies ou monte
-- l escalier du haut. Le palier et l escalier du bas sont dessous, a l abri.
--
--   vue de dessus du couloir :
--   ████████████████████████████████████████  <- plancher (au-dessus de l escalier du bas)
--   ███████[ tremie  ]████[ tremie  ]███████  <- plancher, sauf ou monte l escalier du haut
--   ═══════════════ allee des gradins ═══════
local RAMPE_H     = 3.5   -- hauteur de la rampe le long de l escalier du haut
local RAMPE_E     = 0.6   -- epaisseur de la rampe
local PLANCHER_E  = 1     -- epaisseur du plancher du haut
local TRANSP_PLANCHER = 0.6  -- 0 = opaque (cache la route), 1 = invisible
local PALIER_HAUT = 6     -- longueur de plancher plat entre la derniere marche et le bout
if SURELEVATION > 0 then
	local nbHaut = math.ceil(SURELEVATION / MARCHE_MAX)
	local gironHaut = (course - PALIER_HAUT) / nbHaut
	local yHaut = hautY + SURELEVATION
	local lat1, lat2 = dos + LARG_ESC, avant      -- la bande du couloir a cote du 1er escalier
	local x0, x1 = milieu - DEMI_LONG_GRADINS, milieu + DEMI_LONG_GRADINS
	local haut1 = PALIER / 2 + course - PALIER_HAUT   -- ou s arrete la derniere marche
	for _, s in ipairs({-1, 1}) do
		for i = 1, nbHaut do
			local a1 = milieu + s * (PALIER / 2 + (i - 1) * gironHaut)
			local a2 = milieu + s * (PALIER / 2 + i * gironHaut)
			local y = hautY + i * SURELEVATION / nbHaut
			pave("MarcheHaut", a1, a2, lat1, lat2, solY, y, MATIERE_SOL, COULEUR_SOL)
			-- la rampe cote escalier du bas (on ne tombe pas dessus en montant)
			pave("Rampe", a1, a2, lat1, lat1 + RAMPE_E, y, y + RAMPE_H, MATIERE_SOL, COULEUR_SOL)
		end
	end
	-- le plancher est EN VERRE : il avance de 24 studs devant les gradins,
	-- a la hauteur de l allee. Opaque, il cachait la route aux spectateurs
	-- (verifie en tirant un rayon depuis les yeux de chaque rangee).
	local function vitre(a1, a2, l1, l2)
		local p = pave("Plancher", a1, a2, l1, l2, yHaut - PLANCHER_E, yHaut,
			Enum.Material.Glass, Color3.fromRGB(200, 230, 255))
		p.Transparency = TRANSP_PLANCHER
	end
	-- en 4 morceaux :
	-- 1. toute la bande au-dessus de l escalier du bas, d un bout a l autre
	vitre(x0, x1, dos, lat1)
	-- 2. et 3. la bande de l escalier du haut, apres la derniere marche, jusqu aux bouts
	vitre(x0, milieu - haut1, lat1, lat2)
	vitre(milieu + haut1, x1, lat1, lat2)
	-- 4. au-dessus du palier, entre le depart des deux volees
	vitre(milieu - PALIER / 2, milieu + PALIER / 2, lat1, lat2)
	print(string.format("Escalier du haut : 2 x %d marches de %.2f studs, %.1f studs de large ; plancher du haut a Y = %.1f",
		nbHaut, SURELEVATION / nbHaut, COULOIR - LARG_ESC, yHaut))
end

-- ---- LES PETITES BARRIERES (2026-10-03 : "pour pas tomber") ----
-- Aux deux bouts des gradins (sur chaque rangee, et au bout du plancher),
-- au fond de la derniere rangee, et devant le plancher en verre. Toutes
-- EN VERRE, comme le plancher : elles ne cachent rien.
local GARDE_FOU_H = 3
local yAllee = hautY + SURELEVATION
local g0, g1 = milieu - DEMI_LONG_GRADINS, milieu + DEMI_LONG_GRADINS
local function gardeFou(a1, a2, l1, l2, y)
	local p = pave("GardeFou", a1, a2, l1, l2, y, y + GARDE_FOU_H,
		Enum.Material.Glass, Color3.fromRGB(200, 230, 255))
	p.Transparency = TRANSP_PLANCHER
end
for _, x in ipairs({g0, g1}) do
	local dedans = (x == g0) and RAMPE_E or -RAMPE_E      -- l epaisseur, vers l interieur
	for k = 0, nbRangs - 1 do
		local l1 = avant + k * PROF_RANG
		gardeFou(x, x + dedans, l1, l1 + PROF_RANG, yAllee + k * HAUT_RANG)
	end
	gardeFou(x, x + dedans, dos, avant, yAllee)
end
local fond = avant + nbRangs * PROF_RANG
gardeFou(g0, g1, fond - RAMPE_E, fond, yAllee + (nbRangs - 1) * HAUT_RANG)
gardeFou(g0, g1, dos, dos + RAMPE_E, yAllee)

-- ---- LA ZONE DE CHUTE, DERRIERE LES GRADINS ----
-- Une boite invisible au ras de l herbe. Le script ZoneChute (dans
-- ServerScriptService) tue le joueur qui s y trouve : il reapparait au
-- spawn. CanQuery = false : les rayons (la sortie de route...) la traversent.
local CHUTE_PROF  = 80    -- studs d herbe, derriere les gradins
local CHUTE_BORDS = 20    -- elle deborde de 20 studs a chaque bout des gradins
local CHUTE_H     = 8     -- hauteur au-dessus de l herbe
local chute = pave("ZoneChute", g0 - CHUTE_BORDS, g1 + CHUTE_BORDS, fond, fond + CHUTE_PROF,
	solY - 2, solY + CHUTE_H, Enum.Material.SmoothPlastic, Color3.fromRGB(255, 0, 0))
chute.Transparency = 1
chute.CanCollide = false
chute.CanQuery = false
chute.CanTouch = false
chute.CastShadow = false

print(string.format("Gradins : %d rangees, de Y = %.1f a %.1f | escalier : 2 x %d marches de %.2f studs",
	nbRangs, hautY + SURELEVATION, hautY + SURELEVATION + (nbRangs - 1) * HAUT_RANG, nbMarches, montee / nbMarches))

-- ---- LES ARBRES QUI TOUCHENT LES GRADINS OU L ESCALIER ----
if decor then
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = {decor}
	for _, p in ipairs(zone:GetChildren()) do
		if p.Name == "Gradin" or p.Name == "Marche" or p.Name == "MarcheHaut" or p.Name == "Palier" or p.Name == "Plancher" then
			for _, q in ipairs(workspace:GetPartsInPart(p, op)) do
				if q.Parent and (q.Name == "Tronc" or q.Name == "Feuillage") then
					-- on enleve l arbre entier : tout ce qui est a la verticale
					for _, f in ipairs(decor:GetChildren()) do
						local d = Vector3.new(f.Position.X - q.Position.X, 0, f.Position.Z - q.Position.Z)
						if (f.Name == "Tronc" or f.Name == "Feuillage") and f ~= q and d.Magnitude < 4 then f:Destroy() end
					end
					q:Destroy()
					print("Arbre enleve (gradins / escalier)")
				end
			end
		end
	end
end

-- ---- LE POINT D APPARITION ----
-- On reprend le SpawnLocation qui existe (ou on en cree un), on le pose
-- sur la plateforme et on le tourne vers la piste : le joueur apparait
-- face a la ligne de depart.
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true) or Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
-- A fleur du sol : son dessus est 0.04 stud au-dessus du beton (et pas
-- 0.02 : c est deja la hauteur d une part sur deux du sol -> clignotement).
local ou = centre + versRoute * (PROFONDEUR * SPAWN_A) + Vector3.new(0, 0.04 - spawn.Size.Y / 2, 0)
spawn.CFrame = CFrame.lookAt(ou, ou + versRoute)
spawn.Material = MATIERE_SOL
spawn.Color = COULEUR_SOL
-- Un SpawnLocation a un motif (Decal) dessus : on l enleve, pour que le
-- spawn se fonde dans le sol.
for _, d in ipairs(spawn:GetChildren()) do
	if d:IsA("Decal") or d:IsA("Texture") then d:Destroy() end
end
spawn.Parent = zone

print(string.format("Zone de spawn : %.0f x %.0f studs, a %.0f studs du bord de la route, sol a Y = %.1f",
	largeur, PROFONDEUR, DEGAGE, hautY))
