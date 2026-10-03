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

-- FONDRE plusieurs morceaux en UN seul objet (l "Union" de Studio).
-- Pour le verre et tout ce qui est transparent : chaque morceau laisse
-- voir ses bords, chaque jonction fait un trait. Une fois fondus, il n y
-- a plus de jonction, donc plus de trait.
-- Si la fusion echoue, on garde les morceaux tels quels (le jeu marche).
local function fondre(morceaux, nom, transparence)
	if #morceaux < 2 then return end
	local premier = morceaux[1]
	local autres = {}
	for i = 2, #morceaux do autres[#autres + 1] = morceaux[i] end
	local ok, union = pcall(function() return premier:UnionAsync(autres) end)
	if not ok or not union then
		warn("Fusion impossible pour " .. nom .. " : " .. tostring(union))
		return
	end
	union.Name = nom
	union.Anchored = true
	union.UsePartColor = true
	union.Color = premier.Color
	union.Material = premier.Material
	union.Transparency = transparence
	union.CastShadow = false
	-- la collision suit la vraie forme (sinon une "boite" autour bloquerait l interieur)
	union.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	union.Parent = zone
	for _, p in ipairs(morceaux) do p:Destroy() end
end

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

-- ---- LES MURS DE VERRE TOUT AUTOUR DU ROND (2026-10-03) ----
-- Tout l arrondi, sans ouverture, et le cote plat, avec juste un passage
-- au milieu vers le palier et les escaliers.
-- "Propre et lisse" : deux fois plus de morceaux que le sol, coupes PILE
-- a la bonne longueur (les morceaux qui se chevauchaient faisaient des
-- traits plus fonces dans le verre), et du plastique lisse transparent
-- plutot que la matiere "Glass", qui deforme et fait ressortir les joints.
local MURS       = true
local MUR_H      = 16      -- hauteur des murs au-dessus de la plateforme
local MUR_E      = 0.5     -- epaisseur du verre
local TRANSP_MUR = 0.6     -- 0 = opaque, 1 = invisible
local NB_MUR     = 2 * NB  -- nombre de morceaux de l arrondi
local PASSAGE    = 20      -- le passage dans le mur du cote plat, vers le palier
local VERRE      = Color3.fromRGB(205, 230, 255)
-- On ne construit PAS les murs ici : il faut d abord savoir ou sont les
-- ailes (plus bas), car le verre s arrete contre elles. On ecrit donc
-- une fonction, et on l appelle plus loin, une fois les ailes placees.
--   xMax   : le verre du cote plat s arrete a xMax du milieu ;
--   latMax : on ne met pas de verre plus loin que latMax de l axe de la
--            route (ce morceau d arrondi est dans une aile).
local function construireMurs(xMax, latMax)
	local vitres = {}
	local function vitreMur(taille, cf)
		local p = bloc(zone, "MurVerre", taille, cf, Enum.Material.SmoothPlastic, VERRE)
		p.Transparency = TRANSP_MUR
		p.CastShadow = false
		vitres[#vitres + 1] = p
	end
	-- 1. l arrondi
	local function morceau(p1, p2)
		local c = (p1 + p2) / 2 + Vector3.new(0, MUR_H / 2, 0)
		vitreMur(Vector3.new(MUR_E, MUR_H, (p2 - p1).Magnitude + 0.05), CFrame.lookAt(c, c + (p2 - p1)))
	end
	local function lat(p) return (p - ligne.Position):Dot(cote) end
	for k = 1, NB_MUR do
		local p1, p2 = bord(math.pi * (k - 1) / NB_MUR), bord(math.pi * k / NB_MUR)
		local l1, l2 = lat(p1), lat(p2)
		if l1 <= latMax and l2 <= latMax then
			morceau(p1, p2)
		elseif l1 <= latMax or l2 <= latMax then
			-- ce morceau traverse la limite de l aile : on le COUPE pile la
			-- ou il la croise (sinon il manquait un morceau : un trou entre
			-- le verre et le batiment)
			local pin, pout = p1, p2
			if l2 <= latMax then pin, pout = p2, p1 end
			local t = (latMax - lat(pin)) / (lat(pout) - lat(pin))
			morceau(pin, pin + (pout - pin) * t)
		end
	end
	-- 2. le cote plat, de chaque cote du passage
	for _, s in ipairs({-1, 1}) do
		local x1, x2 = s * PASSAGE / 2, s * xMax
		local c = centre + sens * ((x1 + x2) / 2) + Vector3.new(0, MUR_H / 2, 0)
		vitreMur(Vector3.new(math.abs(x2 - x1), MUR_H, MUR_E), CFrame.fromMatrix(c, sens, Vector3.new(0, 1, 0)))
	end
	-- 3. on fond tous les morceaux en un seul mur : plus aucun trait
	fondre(vitres, "MurVerre", TRANSP_MUR)
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

-- ---- LES DEUX AILES (les "carres" poses a la main, 2026-10-03) ----
-- Deux blocs blancs de chaque cote du rond, le dessus au niveau du sol du
-- spawn : on passe de l un a l autre a plat. Ils sont colles :
--   - par l arriere, au devant des gradins ;
--   - sur le cote, au rond : on CALCULE ou passe l arrondi a la hauteur
--     du devant de l aile, et l aile commence la. Son coin avant touche
--     pile l arrondi, sans trou.
--          ┌───────┐╱‾‾‾‾‾╲┌───────┐
--          │ aile  │ spawn │ aile  │
--          └───────┴───────┴───────┘
--          ███████ gradins ████████
-- Ce sont des BATIMENTS (2026-10-03 : "il faut de la hauteur pour
-- rentrer") : sur le bloc, une salle de AILE_H studs de haut, 4 murs
-- blancs et un toit, et une porte dans le mur cote spawn.
local AILES     = true
local AILE_LONG = 113    -- le long de la piste (comme les carres poses a la main)
local AILE_PROF = 66     -- profondeur
local AILE_H    = 20     -- hauteur de la salle, au-dessus du sol du spawn
local AILE_MUR  = 1      -- epaisseur des murs
local PORTE_L   = 12     -- largeur de la porte (cote spawn)
local PORTE_H   = 10     -- hauteur de la porte
local BLEU_PORTE   = Color3.fromRGB(120, 200, 255)   -- le verre des portes coulissantes
local TRANSP_PORTE = 0.35
local NEON         = Color3.fromRGB(0, 225, 255)     -- liseres et cadres, style futuriste
-- l interieur des batiments
local GRIS_INTERIEUR = Color3.fromRGB(42, 46, 56)    -- le sol, gris fonce brillant
local BLANC_LUMIERE  = Color3.fromRGB(240, 246, 255) -- les panneaux du plafond
local DECO_SOL       = 0.06   -- epaisseur du revetement (assez mince pour la porte)
local BORD_SOL       = 0.4    -- largeur de la bordure neon du sol
local ECART_BANDES   = 16     -- une bande neon verticale tous les ~16 studs
local MONTANT        = 1      -- largeur des montants blancs entre les fenetres

-- Sans ailes, le verre fait tout le tour du rond.
local xCoin, devantAile = DEMI_LARGEUR, math.huge
if AILES then
	devantAile = avant - AILE_PROF                  -- le devant des ailes, depuis l axe
	local profRond = dos - devantAile               -- a quelle profondeur du rond ca tombe
	-- l ellipse du rond : a la profondeur p, elle est a x = A * racine(1 - (p/B)^2) du milieu
	xCoin = DEMI_LARGEUR * math.sqrt(math.max(0, 1 - (profRond / PROFONDEUR) ^ 2))
end

-- Les murs de verre du rond : ils s arretent contre les ailes.
if MURS then
	construireMurs(xCoin, devantAile)
end

if AILES then
	local y0, y1 = hautY, hautY + AILE_H
	for _, s in ipairs({-1, 1}) do
		local aIn, aOut = milieu + s * xCoin, milieu + s * (xCoin + AILE_LONG)
		-- le bloc (le plancher du batiment). 0.01 stud sous le sol du spawn :
		-- la ou les deux se chevauchent, ils ne clignotent pas.
		pave("Aile", aIn, aOut, devantAile, avant, solY, hautY - 0.01, MATIERE_SOL, COULEUR_SOL)
		-- les murs : derriere (cote gradins), cote exterieur. Le mur de DEVANT
		-- (cote cour et piste) a des fenetres : il est construit plus bas,
		-- avec la decoration interieure dont il suit les lignes.
		pave("AileMur", aIn, aOut, avant - AILE_MUR, avant, y0, y1, MATIERE_SOL, COULEUR_SOL)
		pave("AileMur", aOut - s * AILE_MUR, aOut, devantAile, avant, y0, y1, MATIERE_SOL, COULEUR_SOL)
		-- le mur cote spawn, avec la porte au milieu de la partie qui donne
		-- sur le spawn (entre le devant de l aile et le dos du rond)
		local pMilieu = (devantAile + dos) / 2
		local p1, p2 = pMilieu - PORTE_L / 2, pMilieu + PORTE_L / 2
		local aMur = aIn + s * AILE_MUR
		pave("AileMur", aIn, aMur, devantAile, p1, y0, y1, MATIERE_SOL, COULEUR_SOL)
		pave("AileMur", aIn, aMur, p2, avant, y0, y1, MATIERE_SOL, COULEUR_SOL)
		pave("AileMur", aIn, aMur, p1, p2, y0 + PORTE_H, y1, MATIERE_SOL, COULEUR_SOL)
		-- le toit
		pave("AileToit", aIn, aOut, devantAile, avant, y1, y1 + 1, MATIERE_SOL, COULEUR_SOL)

		-- LA PORTE COULISSANTE (style futuriste) : deux panneaux de verre
		-- bleute qui s ecartent et rentrent dans le mur. Le generateur note
		-- sur chaque piece qui bouge sa position "Ferme" et "Ouvert" (des
		-- attributs) : le script PortesCoulissantes n a plus qu a les faire
		-- glisser de l une a l autre quand un joueur approche.
		local porte = Instance.new("Model")
		porte.Name = "PorteCoulissante"
		local aC = aIn + s * AILE_MUR / 2                  -- au milieu de l epaisseur du mur
		for _, cp in ipairs({-1, 1}) do                    -- -1 : panneau cote route, 1 : cote gradins
			local l1, l2 = (cp < 0) and p1 or pMilieu, (cp < 0) and pMilieu or p2
			local panneau = pave("Panneau", aC - 0.2, aC + 0.2, l1, l2, y0, y0 + PORTE_H,
				Enum.Material.Glass, BLEU_PORTE)
			panneau.Transparency = TRANSP_PORTE
			-- le lisere neon, sur le bord ou les deux panneaux se rejoignent
			local neon = pave("Lisere", aC - 0.25, aC + 0.25, pMilieu + cp * 0.3, pMilieu,
				y0, y0 + PORTE_H, Enum.Material.Neon, NEON)
			for _, piece in ipairs({panneau, neon}) do
				piece:SetAttribute("Ferme", piece.CFrame)
				-- ouvert : decale de la moitie de la porte, dans le mur
				piece:SetAttribute("Ouvert", piece.CFrame + cote * (cp * PORTE_L / 2))
				piece.Parent = porte
			end
		end
		porte:SetAttribute("Centre", origine + sens * aC + cote * pMilieu + haut * (y0 + PORTE_H / 2))
		porte.Parent = zone
		-- le cadre neon, des deux cotes du mur (il ne bouge pas)
		for _, face in ipairs({aIn - s * 0.15, aMur + s * 0.15}) do
			local f1 = (face == aIn - s * 0.15) and aIn or aMur
			pave("CadreNeon", face, f1, p1 - 0.5, p2 + 0.5, y0 + PORTE_H, y0 + PORTE_H + 0.5,
				Enum.Material.Neon, NEON)
			pave("CadreNeon", face, f1, p1 - 0.5, p1, y0, y0 + PORTE_H, Enum.Material.Neon, NEON)
			pave("CadreNeon", face, f1, p2, p2 + 0.5, y0, y0 + PORTE_H, Enum.Material.Neon, NEON)
		end

		-- L INTERIEUR, meme style que la porte (2026-10-03) :
		--   ┌──────────────────────────────┐ <- corniche neon (en haut)
		--   │ ▕     ▕     ▕     ▕     ▕     │ <- bandes neon verticales
		--   └──────────────────────────────┘ <- plinthe neon (en bas)
		--   sol gris fonce brillant, bordure neon ; plafond : panneaux lumineux
		-- Les limites de la salle, a l interieur des murs :
		local i1, i2 = aMur, aOut - s * AILE_MUR             -- le long de la piste
		local j1, j2 = devantAile + AILE_MUR, avant - AILE_MUR -- depuis l axe
		local iMin, iMax = math.min(i1, i2), math.max(i1, i2)
		local yS = y0 + DECO_SOL                             -- le dessus du revetement

		-- le sol : revetement brillant, et la bordure neon tout autour
		local sol = pave("SolInterieur", iMin + BORD_SOL, iMax - BORD_SOL, j1 + BORD_SOL, j2 - BORD_SOL,
			y0, yS, Enum.Material.SmoothPlastic, GRIS_INTERIEUR)
		sol.Reflectance = 0.15
		pave("BordureNeon", iMin, iMax, j1, j1 + BORD_SOL, y0, yS, Enum.Material.Neon, NEON)
		pave("BordureNeon", iMin, iMax, j2 - BORD_SOL, j2, y0, yS, Enum.Material.Neon, NEON)
		pave("BordureNeon", iMin, iMin + BORD_SOL, j1 + BORD_SOL, j2 - BORD_SOL, y0, yS, Enum.Material.Neon, NEON)
		pave("BordureNeon", iMax - BORD_SOL, iMax, j1 + BORD_SOL, j2 - BORD_SOL, y0, yS, Enum.Material.Neon, NEON)

		-- plinthe (en bas) et corniche (en haut), le long des 4 murs
		for _, h in ipairs({{yS + 0.3, yS + 0.7}, {y1 - 0.9, y1 - 0.5}}) do
			local ya, yb = h[1], h[2]
			pave("LigneNeon", iMin, iMax, j1, j1 + 0.15, ya, yb, Enum.Material.Neon, NEON)   -- mur avant
			pave("LigneNeon", iMin, iMax, j2 - 0.15, j2, ya, yb, Enum.Material.Neon, NEON)   -- mur arriere
			pave("LigneNeon", i2, i2 - s * 0.15, j1, j2, ya, yb, Enum.Material.Neon, NEON)   -- mur du fond
			-- mur de la porte : on laisse la porte (et son cadre) libre
			pave("LigneNeon", i1, i1 + s * 0.15, j1, p1 - 0.5, ya, yb, Enum.Material.Neon, NEON)
			pave("LigneNeon", i1, i1 + s * 0.15, p2 + 0.5, j2, ya, yb, Enum.Material.Neon, NEON)
		end

		-- bandes verticales sur les deux grands murs (avant et arriere)
		local nbBandes = math.floor((iMax - iMin) / ECART_BANDES)
		local bandes = {}
		for b = 1, nbBandes do
			local a = iMin + (iMax - iMin) * b / (nbBandes + 1)
			bandes[b] = a
			for _, j in ipairs({{j1, j1 + 0.15}, {j2 - 0.15, j2}}) do
				pave("BandeNeon", a - 0.15, a + 0.15, j[1], j[2], yS + 0.7, y1 - 0.9, Enum.Material.Neon, NEON)
			end
		end

		-- LE MUR DE DEVANT, AVEC SES FENETRES (2026-10-03 : "les carres
		-- deviennent des vitres pour voir la cour, mais on garde les traits
		-- bleus"). Les lignes neon dessinent des rectangles : chacun devient
		-- une vitre, les lignes restent comme cadre.
		--   ████████████████████████  <- mur plein (au-dessus de la corniche)
		--   █ ░░░░ █ ░░░░ █ ░░░░ █ █  <- vitres entre les montants des bandes
		--   ████████████████████████  <- mur plein (sous la plinthe)
		local m1, m2 = devantAile, devantAile + AILE_MUR
		local yBas, yHaut = yS + 0.7, y1 - 0.9                    -- la fenetre, entre plinthe et corniche
		pave("AileMur", aIn, aOut, m1, m2, y0, yBas, MATIERE_SOL, COULEUR_SOL)     -- en bas
		pave("AileMur", aIn, aOut, m1, m2, yHaut, y1, MATIERE_SOL, COULEUR_SOL)    -- en haut
		-- les coins (dans l epaisseur des murs de cote)
		pave("AileMur", math.min(aIn, aOut), iMin, m1, m2, yBas, yHaut, MATIERE_SOL, COULEUR_SOL)
		pave("AileMur", iMax, math.max(aIn, aOut), m1, m2, yBas, yHaut, MATIERE_SOL, COULEUR_SOL)
		-- les montants (sous chaque bande) et les vitres entre eux
		local bords = {iMin}
		for _, a in ipairs(bandes) do bords[#bords + 1] = a end
		bords[#bords + 1] = iMax
		for k = 1, #bords - 1 do
			local debut = bords[k] + ((k > 1) and MONTANT / 2 or 0)
			local fin = bords[k + 1] - ((k + 1 < #bords) and MONTANT / 2 or 0)
			local vitre = pave("Fenetre", debut, fin, m1 + 0.3, m2 - 0.3, yBas, yHaut,
				Enum.Material.SmoothPlastic, VERRE)
			vitre.Transparency = TRANSP_MUR
			vitre.CastShadow = false
		end
		for _, a in ipairs(bandes) do
			pave("AileMur", a - MONTANT / 2, a + MONTANT / 2, m1, m2, yBas, yHaut, MATIERE_SOL, COULEUR_SOL)
		end

		-- le plafond : des panneaux lumineux blancs, qui eclairent vers le bas
		local nbA = math.floor((iMax - iMin) / 22)
		local nbJ = 3
		for u = 1, nbA do
			for v = 1, nbJ do
				local a = iMin + (iMax - iMin) * u / (nbA + 1)
				local j = j1 + (j2 - j1) * v / (nbJ + 1)
				local panneau = pave("Lumiere", a - 7, a + 7, j - 2, j + 2, y1 - 0.3, y1,
					Enum.Material.Neon, BLANC_LUMIERE)
				local lampe = Instance.new("SurfaceLight")
				lampe.Face = Enum.NormalId.Bottom             -- elle eclaire vers le sol
				lampe.Brightness = 1.2
				lampe.Range = 22
				lampe.Color = BLANC_LUMIERE
				lampe.Parent = panneau
			end
		end
	end
	print(string.format("Ailes : batiments de %d x %d x %d studs, colles au rond a %.1f studs du milieu, porte de %d x %d",
		AILE_LONG, AILE_PROF, AILE_H, xCoin, PORTE_L, PORTE_H))
end

-- ---- LE TOIT BLANC (2026-10-03) ----
-- Il pose sur les murs et couvre tout le rond, en deux parties :
--   - l ARRIERE, blanc plein ;
--   - l AVANT, blanc translucide (comme du verre depoli) : un toit opaque
--     a cet endroit cacherait la route aux gradins (verifie par le calcul).
-- La limite entre les deux n est PAS choisie au hasard : on reprend la
-- ligne de vue de la 1re rangee de bancs (celle qui a le moins de marge)
-- et le blanc plein s arrete juste avant de couper cette ligne.
local TOIT         = true
local TOIT_E       = 1       -- epaisseur du toit
local TOIT_MARGE   = 2       -- studs de marge avant la ligne de vue
local BANDE        = 1       -- largeur des bandes qui suivent l arrondi
local TRANSP_AVANT = 0       -- l avant du toit : 0 = blanc plein (cache la route), 1 = invisible
if TOIT and MURS then
	local yToit = hautY + MUR_H + TOIT_E
	-- La ligne de vue part des yeux de la 1re rangee (assis1, yeux1) et va
	-- au bord de la route (demiRoute, routeY). A quelle distance de l axe
	-- passe-t-elle a la hauteur du dessus du toit ?
	local passe = demiRoute + (yToit - routeY) * (assis1 - demiRoute) / (yeux1 - routeY)
	local profToit = math.min(PROFONDEUR, dos - passe - TOIT_MARGE)
	-- la profondeur de l arrondi a la distance x du milieu
	local function profArrondi(x)
		return PROFONDEUR * math.sqrt(math.max(0, 1 - (x / DEMI_LARGEUR) ^ 2))
	end
	-- le toit du rond s arrete contre les ailes (xCoin), comme le verre
	local xBout = math.min(DEMI_LARGEUR, xCoin)
	local xPlein = math.min(xBout, DEMI_LARGEUR * math.sqrt(math.max(0, 1 - (profToit / PROFONDEUR) ^ 2)))

	-- 1. L ARRIERE, blanc plein. Au milieu, la ou l arrondi est plus profond
	-- que cette partie : un grand rectangle. Aux deux bouts : des bandes qui
	-- suivent l arrondi (sa profondeur au bord EXTERIEUR de la bande : le
	-- toit ne depasse jamais des murs).
	local arriere = {}
	arriere[1] = pave("Toit", milieu - xPlein, milieu + xPlein, dos - profToit, dos,
		yToit - TOIT_E, yToit, MATIERE_SOL, COULEUR_SOL)
	for _, s in ipairs({-1, 1}) do
		local x = xPlein
		while x < xBout do
			local x2 = math.min(x + BANDE, xBout)
			local prof = profArrondi(x2)
			if prof > 0.2 then
				arriere[#arriere + 1] = pave("Toit", milieu + s * x, milieu + s * x2, dos - prof, dos,
					yToit - TOIT_E, yToit, MATIERE_SOL, COULEUR_SOL)
			end
			x = x2
		end
	end
	fondre(arriere, "Toit", 0)

	-- 2. L AVANT, blanc translucide : des bandes de profToit jusqu a l arrondi.
	local devantToit = {}
	for _, s in ipairs({-1, 1}) do
		local x = 0
		while x < xPlein do
			local x2 = math.min(x + BANDE, xPlein)
			local prof = profArrondi(x2)
			if prof > profToit + 0.2 then
				local p = pave("ToitAvant", milieu + s * x, milieu + s * x2, dos - prof, dos - profToit,
					yToit - TOIT_E, yToit, MATIERE_SOL, COULEUR_SOL)
				p.Transparency = TRANSP_AVANT
				p.CastShadow = false
				devantToit[#devantToit + 1] = p
			end
			x = x2
		end
	end
	fondre(devantToit, "ToitAvant", TRANSP_AVANT)

	print(string.format("Toit : blanc plein sur %.0f studs de profondeur, translucide sur les %.0f de devant, a Y = %.1f",
		profToit, PROFONDEUR - profToit, yToit))
end

-- ---- LE TABLEAU DU CLASSEMENT (2026-10-03) ----
-- Un ecran contre le mur du fond du spawn (le cote plat), tourne vers
-- l interieur. Le generateur pose l ecran et ses lignes VIDES ; c est le
-- script Classement (ServerScriptService) qui les remplit avec les
-- meilleurs temps, et les tient a jour.
-- Ou ? La ou il a ete pose a la main : a DROITE du passage. On le centre
-- pile sur le morceau de mur entre le passage et le batiment de droite,
-- le dos colle au verre.
local TABLEAU      = true
local TAB_L, TAB_H = 20, 10.8  -- largeur et hauteur de l ecran (26 x 14 : trop grand)
local TAB_COTE     = 1         -- 1 = a droite du passage, -1 = a gauche
local TAB_BAS      = 3         -- hauteur du bas de l ecran au-dessus du sol
local TAB_E        = 0.8       -- epaisseur de l ecran
local NB_CLASSES   = 10        -- le top 10
if TABLEAU then
	-- le milieu du morceau de mur libre : entre le bord du passage et l aile
	local a = milieu + TAB_COTE * (PASSAGE / 2 + math.min(xCoin, DEMI_LARGEUR)) / 2
	local yB = hautY + TAB_BAS
	local dosEcran = dos - MUR_E / 2                -- la face interieure du verre
	local ecran = pave("TableauClassement", a - TAB_L / 2, a + TAB_L / 2, dosEcran - TAB_E, dosEcran,
		yB, yB + TAB_H, Enum.Material.SmoothPlastic, Color3.fromRGB(18, 22, 30))
	-- le cadre neon, sur la face qui regarde le spawn
	local f1, f2 = dosEcran - TAB_E - 0.15, dosEcran - TAB_E
	pave("CadreNeon", a - TAB_L / 2 - 0.4, a + TAB_L / 2 + 0.4, f1, f2, yB + TAB_H, yB + TAB_H + 0.4, Enum.Material.Neon, NEON)
	pave("CadreNeon", a - TAB_L / 2 - 0.4, a + TAB_L / 2 + 0.4, f1, f2, yB - 0.4, yB, Enum.Material.Neon, NEON)
	pave("CadreNeon", a - TAB_L / 2 - 0.4, a - TAB_L / 2, f1, f2, yB, yB + TAB_H, Enum.Material.Neon, NEON)
	pave("CadreNeon", a + TAB_L / 2, a + TAB_L / 2 + 0.4, f1, f2, yB, yB + TAB_H, Enum.Material.Neon, NEON)

	-- L AFFICHAGE : une SurfaceGui, sur la face tournee vers le spawn.
	-- Le pave a son axe X le long de la piste et son axe Y vers le haut ;
	-- sa face "Front" regarde vers -(X x Y). On choisit la bonne face.
	local devantVers = -(sens:Cross(haut))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Ecran"
	gui.Face = (devantVers:Dot(versRoute) > 0) and Enum.NormalId.Front or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0          -- l ecran brille tout seul, meme dans l ombre
	gui.Parent = ecran

	local function texte(nom, parent, pos, taille, police, couleur, aligne)
		local t = Instance.new("TextLabel")
		t.Name = nom
		t.BackgroundTransparency = 1
		t.Position = pos
		t.Size = taille
		t.Font = police
		t.TextColor3 = couleur
		t.TextScaled = true
		t.TextXAlignment = aligne or Enum.TextXAlignment.Center
		t.Text = ""
		t.Parent = parent
		return t
	end
	texte("Titre", gui, UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.13), Enum.Font.GothamBlack, NEON).Text = "MEILLEURS TEMPS"
	local lignes = Instance.new("Frame")
	lignes.Name = "Lignes"
	lignes.BackgroundTransparency = 1
	lignes.Position = UDim2.fromScale(0.06, 0.19)
	lignes.Size = UDim2.fromScale(0.88, 0.72)
	lignes.Parent = gui
	local OR, ARGENT, BRONZE = Color3.fromRGB(255, 205, 60), Color3.fromRGB(215, 220, 230), Color3.fromRGB(215, 140, 80)
	for n = 1, NB_CLASSES do
		local couleur = (n == 1 and OR) or (n == 2 and ARGENT) or (n == 3 and BRONZE) or Color3.fromRGB(235, 240, 250)
		local ligne = texte("Ligne" .. n, lignes, UDim2.fromScale(0, (n - 1) / NB_CLASSES),
			UDim2.new(0.7, 0, 1 / NB_CLASSES, -4), Enum.Font.GothamBold, couleur, Enum.TextXAlignment.Left)
		ligne.Text = n .. ".  ---"
		texte("Temps", ligne, UDim2.fromScale(1, 0), UDim2.fromScale(0.43, 1), Enum.Font.RobotoMono, NEON,
			Enum.TextXAlignment.Right)
	end
	texte("Pied", gui, UDim2.fromScale(0.05, 0.92), UDim2.fromScale(0.9, 0.06), Enum.Font.Gotham,
		Color3.fromRGB(130, 140, 160)).Text = "en attente du premier temps..."
end

-- ---- LE TABLEAU DE LA DERNIERE COURSE (2026-10-03) ----
-- De l AUTRE cote du passage, en face du tableau des records : le
-- classement de la derniere course. 1er, 2eme... avec les temps, puis les
-- elimines en rouge. Le generateur pose l ecran et ses lignes VIDES ; c est
-- le script CompteurTours qui les remplit a la fin de chaque course.
-- (Il remplace l ecran "camera du podium", abandonne.)
local TABLEAU_COURSE = true
local NB_LIGNES_COURSE = 6     -- autant que de places sur la grille
if TABLEAU_COURSE and TABLEAU then
	local a = milieu - TAB_COTE * (PASSAGE / 2 + math.min(xCoin, DEMI_LARGEUR)) / 2
	local yB = hautY + TAB_BAS
	local dosEcran = dos - MUR_E / 2
	local ecran = pave("TableauCourse", a - TAB_L / 2, a + TAB_L / 2, dosEcran - TAB_E, dosEcran,
		yB, yB + TAB_H, Enum.Material.SmoothPlastic, Color3.fromRGB(18, 22, 30))
	local f1, f2 = dosEcran - TAB_E - 0.15, dosEcran - TAB_E
	pave("CadreNeon", a - TAB_L / 2 - 0.4, a + TAB_L / 2 + 0.4, f1, f2, yB + TAB_H, yB + TAB_H + 0.4, Enum.Material.Neon, NEON)
	pave("CadreNeon", a - TAB_L / 2 - 0.4, a + TAB_L / 2 + 0.4, f1, f2, yB - 0.4, yB, Enum.Material.Neon, NEON)
	pave("CadreNeon", a - TAB_L / 2 - 0.4, a - TAB_L / 2, f1, f2, yB, yB + TAB_H, Enum.Material.Neon, NEON)
	pave("CadreNeon", a + TAB_L / 2, a + TAB_L / 2 + 0.4, f1, f2, yB, yB + TAB_H, Enum.Material.Neon, NEON)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Ecran"
	gui.Face = (-(sens:Cross(haut))):Dot(versRoute) > 0 and Enum.NormalId.Front or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = ecran

	local function texte(nom, parent, pos, taille, police, couleur, aligne)
		local t = Instance.new("TextLabel")
		t.Name = nom
		t.BackgroundTransparency = 1
		t.Position = pos
		t.Size = taille
		t.Font = police
		t.TextColor3 = couleur
		t.TextScaled = true
		t.TextXAlignment = aligne or Enum.TextXAlignment.Center
		t.Text = ""
		t.Parent = parent
		return t
	end
	texte("Titre", gui, UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.13), Enum.Font.GothamBlack, NEON).Text = "DERNIÈRE COURSE"
	local lignes = Instance.new("Frame")
	lignes.Name = "Lignes"
	lignes.BackgroundTransparency = 1
	lignes.Position = UDim2.fromScale(0.06, 0.19)
	lignes.Size = UDim2.fromScale(0.88, 0.72)
	lignes.Parent = gui
	for n = 1, NB_LIGNES_COURSE do
		local ligne = texte("Ligne" .. n, lignes, UDim2.fromScale(0, (n - 1) / NB_LIGNES_COURSE),
			UDim2.new(0.7, 0, 1 / NB_LIGNES_COURSE, -6), Enum.Font.GothamBold, Color3.fromRGB(235, 240, 250),
			Enum.TextXAlignment.Left)
		texte("Temps", ligne, UDim2.fromScale(1, 0), UDim2.fromScale(0.43, 1), Enum.Font.RobotoMono, NEON,
			Enum.TextXAlignment.Right)
	end
	texte("Pied", gui, UDim2.fromScale(0.05, 0.92), UDim2.fromScale(0.9, 0.06), Enum.Font.Gotham,
		Color3.fromRGB(130, 140, 160)).Text = "en attente de la fin d'une course..."
end

-- ---- LE BOUTON "DEMARRAGE DE LA COURSE" (2026-10-03) ----
-- Au bout de l arrondi, pres du verre, face a la piste : un socle, un
-- bouton rouge avec un anneau neon, et DERRIERE le bouton (entre lui et
-- le verre), sur un mat, le panneau.
-- Le bouton porte un ProximityPrompt nomme "PromptCourse" : c est le
-- script DepartCourse (ServerScriptService) qui reagit quand on appuie.
--   vue de cote :     verre │  ┌──────────────────┐
--                           │  │ DEMARRAGE DE LA  │ <- le panneau, derriere
--                           │  └───────┬──────────┘
--                           │          │   ▄███▄    <- le bouton
--                           │          │   █████    <- le socle    <- on arrive du spawn
local BOUTON      = true
local BOUTON_VERRE = 6       -- studs entre le bouton et le verre de l arrondi
local SOCLE_H     = 3.2      -- hauteur du socle
local PANNEAU_L   = 11       -- largeur du panneau
local PANNEAU_H   = 2.6      -- hauteur du panneau
local PANNEAU_BAS = 7        -- hauteur du bas du panneau au-dessus du sol
if BOUTON then
	local a = milieu                                   -- au milieu, le long de la piste
	local l = dos - PROFONDEUR + BOUTON_VERRE          -- pres du bout de l arrondi
	local y = hautY
	pave("SocleBouton", a - 1.6, a + 1.6, l - 1.6, l + 1.6, y, y + SOCLE_H, MATIERE_SOL, COULEUR_SOL)
	pave("AnneauNeon", a - 1.75, a + 1.75, l - 1.75, l + 1.75, y + SOCLE_H - 0.3, y + SOCLE_H,
		Enum.Material.Neon, NEON)
	-- le bouton : un cylindre couche sur le cote, puis redresse (un
	-- cylindre Roblox a son axe sur X : on le tourne de 90 degres)
	local bouton = Instance.new("Part")
	bouton.Name = "BoutonCourse"
	bouton.Shape = Enum.PartType.Cylinder
	bouton.Anchored = true
	bouton.Size = Vector3.new(0.6, 2.2, 2.2)
	bouton.CFrame = CFrame.new(origine + sens * a + cote * l + haut * (y + SOCLE_H + 0.3))
		* CFrame.Angles(0, 0, math.rad(90))
	bouton.Material = Enum.Material.Neon
	bouton.Color = Color3.fromRGB(255, 50, 60)
	bouton.Parent = zone
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptCourse"
	prompt.ActionText = "Choisir ma place"
	prompt.ObjectText = "Demarrage de la course"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bouton
	-- le mat, du socle jusqu au panneau, cote VERRE (derriere le bouton
	-- quand on arrive du spawn : la, "l - ..." = vers la piste)
	pave("MatPanneau", a - 0.2, a + 0.2, l - 1.6, l - 1.2, y + SOCLE_H, y + PANNEAU_BAS, MATIERE_SOL, COULEUR_SOL)
	-- le panneau, et le texte sur ses DEUX faces (on le voit de partout)
	local panneau = pave("PanneauCourse", a - PANNEAU_L / 2, a + PANNEAU_L / 2, l - 1.6, l - 1.2,
		y + PANNEAU_BAS, y + PANNEAU_BAS + PANNEAU_H, Enum.Material.SmoothPlastic, Color3.fromRGB(18, 22, 30))
	pave("CadreNeon", a - PANNEAU_L / 2 - 0.2, a + PANNEAU_L / 2 + 0.2, l - 1.7, l - 1.1,
		y + PANNEAU_BAS - 0.2, y + PANNEAU_BAS, Enum.Material.Neon, NEON)
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Parent = panneau
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = NEON
		t.Text = "DÉMARRAGE DE LA COURSE"
		t.Parent = g
		local marge = Instance.new("UIPadding")
		marge.PaddingLeft, marge.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		marge.PaddingTop, marge.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		marge.Parent = t
	end
end

-- ---- LA DECO DU SPAWN (2026-10-03) ----
-- Dans le rond (pas dans les batiments) :
--   1. une VOITURE D EXPOSITION sur un socle, qui tourne sur elle-meme
--      (la rotation est faite chez chaque joueur : LocalScript AmbianceSpawn) ;
--   2. des LIGNES NEON au sol, en pointilles, qui guident du point
--      d apparition vers le bouton, le passage des gradins et les portes ;
--   3. des BANCS (on peut s y asseoir) et des PLANTES le long du verre.
-- Toutes les positions se donnent en (le long de la piste, profondeur
-- depuis le cote plat), comme le reste du rond.
local DECO        = true
local EXPO_A      = 0.66     -- la voiture : 0 = cote plat, 1 = bout de l arrondi
local SOCLE_R     = 12       -- rayon du socle de la voiture
local POINTILLE   = 3        -- longueur d un trait des lignes au sol
local TROU        = 1.6      -- vide entre deux traits
local BLANC_BANC  = Color3.fromRGB(240, 240, 245)
local VERT_PLANTE = Color3.fromRGB(70, 150, 70)
if DECO then
	local function pt(le_long, profondeur)
		return centre + sens * le_long + versRoute * profondeur
	end
	local yDeco = hautY

	-- 1. LA VOITURE D EXPOSITION ------------------------------------
	local cExpo = pt(0, PROFONDEUR * EXPO_A)
	local socle = Instance.new("Part")
	socle.Name = "SocleExpo"
	socle.Shape = Enum.PartType.Cylinder
	socle.Anchored = true
	socle.Size = Vector3.new(1, SOCLE_R * 2, SOCLE_R * 2)
	-- un cylindre a son axe sur X : on le couche pour qu il soit plat
	socle.CFrame = CFrame.new(cExpo + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	socle.Material = MATIERE_SOL
	socle.Color = COULEUR_SOL
	socle.Parent = zone
	local anneau = socle:Clone()
	anneau.Name = "AnneauExpo"
	anneau.Size = Vector3.new(0.3, SOCLE_R * 2 + 0.8, SOCLE_R * 2 + 0.8)
	anneau.CFrame = CFrame.new(cExpo + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	anneau.Material = Enum.Material.Neon
	anneau.Color = NEON
	anneau.Parent = zone

	local modele = game:GetService("ServerStorage"):FindFirstChild("VoitureModele")
	if modele then
		local expo = modele:Clone()
		expo.Name = "VoitureExpo"
		-- une voiture POUR DE FAUX : tout est ancre, plus aucun script, plus
		-- aucun son, plus aucun siege (sinon s y asseoir lancerait une course !)
		for _, d in ipairs(expo:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true end
		end
		for _, d in ipairs(expo:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Seat") or d:IsA("VehicleSeat") then
				d:Destroy()
			end
		end
		-- posee sur le socle : le bas de sa boite sur le dessus du socle
		expo.Parent = zone
		local cf, taille = expo:GetBoundingBox()
		local hauteurPivot = expo:GetPivot().Position.Y - (cf.Position.Y - taille.Y / 2)
		local base = CFrame.lookAt(cExpo + Vector3.new(0, 1 + hauteurPivot + 0.05, 0),
			cExpo + Vector3.new(0, 1 + hauteurPivot + 0.05, 0) + sens)
		expo:PivotTo(base)
		expo:SetAttribute("Base", base)     -- le LocalScript la fait tourner autour de ce point
	end

	-- 2. LES LIGNES NEON AU SOL -------------------------------------
	local function ligne(a, b)
		local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local longueur = d.Magnitude
		local dir = d.Unit
		local x = 0
		while x + POINTILLE <= longueur do
			local m = a + dir * (x + POINTILLE / 2)
			local trait = Instance.new("Part")
			trait.Name = "LigneSol"
			trait.Anchored = true
			trait.CanCollide = false
			trait.CanQuery = false
			trait.Size = Vector3.new(0.4, 0.06, POINTILLE)
			trait.CFrame = CFrame.lookAt(Vector3.new(m.X, yDeco + 0.06, m.Z), Vector3.new(m.X, yDeco + 0.06, m.Z) + dir)
			trait.Material = Enum.Material.Neon
			trait.Color = NEON
			trait.Parent = zone
			x += POINTILLE + TROU
		end
	end
	local pSpawn = PROFONDEUR * SPAWN_A
	-- vers le bouton (en passant de part et d autre du socle de la voiture)
	local pBouton = PROFONDEUR - BOUTON_VERRE - 2
	for _, s in ipairs({-1, 1}) do
		ligne(pt(s * 2.5, pSpawn + 7), pt(s * (SOCLE_R + 2), PROFONDEUR * EXPO_A))
		ligne(pt(s * (SOCLE_R + 2), PROFONDEUR * EXPO_A), pt(s * 2.5, pBouton))
	end
	-- vers le passage des gradins (le cote plat, au milieu)
	ligne(pt(0, pSpawn - 7), pt(0, 2))
	-- vers les portes des deux batiments
	if AILES then
		local pPorte = dos - (devantAile + dos) / 2       -- profondeur de la porte
		for _, s in ipairs({-1, 1}) do
			ligne(pt(s * 7, pSpawn), pt(s * (xCoin - 3), pPorte))
		end
	end

	-- 3. LES BANCS ET LES PLANTES, LE LONG DU VERRE -----------------
	-- "a" = l angle sur l arrondi (pi/2 = le bout, ou est le bouton)
	local function surLarrondi(a, recul)
		local p = bord(a)
		local versCentre = Vector3.new(centre.X - p.X, 0, centre.Z - p.Z).Unit
		return p + versCentre * recul, -versCentre      -- la position, et la direction du verre
	end
	for _, a in ipairs({0.62, 0.95, math.pi - 0.95, math.pi - 0.62}) do
		local p, versVerre = surLarrondi(a, 5)
		local cf = CFrame.lookAt(p + Vector3.new(0, yDeco - p.Y, 0), p + Vector3.new(0, yDeco - p.Y, 0) + versVerre)
		-- l assise : un vrai Seat, tourne vers le verre (on regarde la piste)
		local assise = Instance.new("Seat")
		assise.Name = "Banc"
		assise.Anchored = true
		assise.Size = Vector3.new(7, 0.6, 2.2)
		assise.CFrame = cf * CFrame.new(0, 1.8, 0)
		assise.Material = Enum.Material.SmoothPlastic
		assise.Color = BLANC_BANC
		assise.Parent = zone
		for _, x in ipairs({-2.8, 2.8}) do
			local pied = Instance.new("Part")
			pied.Name = "PiedBanc"
			pied.Anchored = true
			pied.Size = Vector3.new(0.5, 1.5, 1.8)
			pied.CFrame = cf * CFrame.new(x, 0.75, 0)
			pied.Material = Enum.Material.SmoothPlastic
			pied.Color = Color3.fromRGB(60, 62, 70)
			pied.Parent = zone
		end
		local dossier = Instance.new("Part")
		dossier.Name = "DossierBanc"
		dossier.Anchored = true
		dossier.Size = Vector3.new(7, 1.8, 0.35)
		dossier.CFrame = cf * CFrame.new(0, 2.9, 1.0)
		dossier.Material = Enum.Material.SmoothPlastic
		dossier.Color = BLANC_BANC
		dossier.Parent = zone
	end
	for _, a in ipairs({0.785, math.pi - 0.785, math.pi / 2 - 0.22, math.pi / 2 + 0.22}) do
		local p = surLarrondi(a, 4)
		local sol = Vector3.new(p.X, yDeco, p.Z)
		local pot = Instance.new("Part")
		pot.Name = "Pot"
		pot.Shape = Enum.PartType.Cylinder
		pot.Anchored = true
		pot.Size = Vector3.new(2.6, 3, 3)
		pot.CFrame = CFrame.new(sol + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pot.Material = Enum.Material.SmoothPlastic
		pot.Color = Color3.fromRGB(45, 48, 56)
		pot.Parent = zone
		local lisere = pot:Clone()
		lisere.Name = "LisereNeon"
		lisere.Size = Vector3.new(0.25, 3.2, 3.2)
		lisere.CFrame = CFrame.new(sol + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		lisere.Material = Enum.Material.Neon
		lisere.Color = NEON
		lisere.Parent = zone
		local feuilles = Instance.new("Part")
		feuilles.Name = "Feuilles"
		feuilles.Shape = Enum.PartType.Ball
		feuilles.Anchored = true
		feuilles.Size = Vector3.new(4.2, 4.2, 4.2)
		feuilles.Position = sol + Vector3.new(0, 4.4, 0)
		feuilles.Material = Enum.Material.Grass
		feuilles.Color = VERT_PLANTE
		feuilles.Parent = zone
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
