-- ============================================================
--  LE CATALOGUE DU GARAGE
--  ModuleScript a placer dans ReplicatedStorage, nom "GarageCatalogue".
--
--  Il est lu par le SERVEUR (GarageServeur : les prix, les effets) ET par
--  l ECRAN (Garage.client : ce qu on affiche). Une seule liste pour les
--  deux : changer un prix ici le change partout.
--
--  Toutes les voitures ont la MEME carrosserie (le chassis A-Chassis de la
--  Jesko) : ce qui change, c est la peinture et les reglages. Les chiffres
--  sont des MULTIPLICATEURS (1 = la Jesko d origine). Le module
--  "A-Chassis Tune" de la voiture les lit (Puissance, VitesseMax,
--  Freinage) ; le script Degats lit Solidite.
-- ============================================================

local Catalogue = {}

Catalogue.VOITURES = {
	{nom = "Jesko", prix = 0, couleur = Color3.fromRGB(235, 235, 240),
		texte = "La voiture de départ. Équilibrée.",
		Puissance = 1, VitesseMax = 1, Freinage = 1, Solidite = 1},
	{nom = "Éclair", prix = 40, couleur = Color3.fromRGB(255, 200, 40),
		texte = "Démarre comme une fusée, mais plafonne plus tôt.",
		Puissance = 1.2, VitesseMax = 0.95, Freinage = 1, Solidite = 0.9},
	{nom = "Comète", prix = 60, couleur = Color3.fromRGB(60, 140, 255),
		texte = "La plus rapide en ligne droite. Freine moins bien.",
		Puissance = 1, VitesseMax = 1.12, Freinage = 0.9, Solidite = 1},
	{nom = "Bélier", prix = 60, couleur = Color3.fromRGB(95, 125, 75),
		texte = "Un tank : encaisse deux fois plus de chocs.",
		Puissance = 0.95, VitesseMax = 1, Freinage = 1.1, Solidite = 2},
	{nom = "Panthère", prix = 120, couleur = Color3.fromRGB(35, 35, 40),
		texte = "La meilleure partout. Il faut la mériter !",
		Puissance = 1.15, VitesseMax = 1.08, Freinage = 1.2, Solidite = 1.2},
}

-- LES AMELIORATIONS : 3 niveaux chacune, pour TOUTES tes voitures.
-- "effet" = ce qu on ajoute au multiplicateur a chaque niveau (0.06 = +6 %).
Catalogue.AMELIORATIONS = {
	{cle = "Puissance",  nom = "Moteur",            effet = 0.06},
	{cle = "VitesseMax", nom = "Boîte de vitesses", effet = 0.04},
	{cle = "Freinage",   nom = "Freins",            effet = 0.10},
	{cle = "Solidite",   nom = "Carrosserie",       effet = 0.25},
}
Catalogue.PRIX_NIVEAUX = {15, 30, 50}   -- prix du niveau 1, puis 2, puis 3

-- LES PEINTURES (gratuites). La 1re = la couleur du modele.
Catalogue.COULEURS = {
	{nom = "Du modèle", couleur = nil},
	{nom = "Rouge",     couleur = Color3.fromRGB(210, 30, 40)},
	{nom = "Orange",    couleur = Color3.fromRGB(255, 120, 20)},
	{nom = "Jaune",     couleur = Color3.fromRGB(255, 215, 40)},
	{nom = "Vert",      couleur = Color3.fromRGB(40, 190, 80)},
	{nom = "Bleu",      couleur = Color3.fromRGB(40, 110, 230)},
	{nom = "Violet",    couleur = Color3.fromRGB(140, 60, 220)},
	{nom = "Rose",      couleur = Color3.fromRGB(255, 110, 180)},
	{nom = "Blanc",     couleur = Color3.fromRGB(240, 240, 245)},
	{nom = "Noir",      couleur = Color3.fromRGB(25, 25, 30)},
}

-- Les pieces de la carrosserie qu on repeint (les autres : vitres,
-- chrome, phares... gardent leur couleur). Mesure sur la Jesko.
Catalogue.PEINTURE = {["Paint"] = true, ["Paint L"] = true, ["Paint R"] = true, ["PareChocsAvant"] = true}

-- LES PIECES QUI PEUVENT TOMBER dans un choc, rangees par COTE de la
-- voiture. Chaque piece = une ou plusieurs parties du modele (leur nom).
-- Dans chaque cote, les petites d abord, les grosses a la fin.
-- (PareChocsAvant et PiedAileron : renommees le 2026-10-30, elles
-- s appelaient "Paint" et "Paint 2" comme d autres parties.)
Catalogue.PIECES = {
	{nom = "Rétroviseur gauche", cote = "GAUCHE", parties = {"Mirror L"}},
	{nom = "Écope gauche",       cote = "GAUCHE", parties = {"CF L", "Badge L"}},
	{nom = "Portière gauche",    cote = "GAUCHE", parties = {"Paint L", "Window(s) L"}},
	{nom = "Rétroviseur droit",  cote = "DROITE", parties = {"Mirror R"}},
	{nom = "Écope droite",       cote = "DROITE", parties = {"CF R"}},
	{nom = "Portière droite",    cote = "DROITE", parties = {"Paint R", "Window(s) R"}},
	{nom = "Logo",               cote = "AVANT",  parties = {"Koenigsegg Badge"}},
	{nom = "Phare gauche",       cote = "AVANT",  parties = {"F L L"}},
	{nom = "Phare droit",        cote = "AVANT",  parties = {"F L R"}},
	{nom = "Bandeau de phares",  cote = "AVANT",  parties = {"DRLs", "Daytime"}},
	{nom = "Pare-chocs avant",   cote = "AVANT",  parties = {"PareChocsAvant"}},
	{nom = "Feu arrière gauche", cote = "ARRIERE", parties = {"R L L"}},
	{nom = "Feu arrière droit",  cote = "ARRIERE", parties = {"R L R"}},
	{nom = "Aileron",            cote = "ARRIERE", parties = {"Badges", "PiedAileron"}},
}

-- LA REPARATION au garage : 1 piece 🪙 par tranche de 10 % abimes
-- (commencee), et 2 par piece perdue.
function Catalogue.prixReparation(etat, perdues)
	return math.ceil((100 - etat) / 10) + 2 * #perdues
end

function Catalogue.piece(nom)
	for _, p in ipairs(Catalogue.PIECES) do
		if p.nom == nom then return p end
	end
	return nil
end

-- Les parties du modele qui forment ces pieces (pour les enlever ou les
-- faire tomber). Rend une liste de BaseParts.
function Catalogue.partiesDe(modele, nomsPieces)
	local voulues = {}
	for _, nom in ipairs(nomsPieces) do
		local p = Catalogue.piece(nom)
		if p then
			for _, n in ipairs(p.parties) do voulues[n] = true end
		end
	end
	local liste = {}
	for _, d in ipairs(modele:GetDescendants()) do
		if d:IsA("BasePart") and voulues[d.Name] then table.insert(liste, d) end
	end
	return liste
end

function Catalogue.voiture(nom)
	for _, v in ipairs(Catalogue.VOITURES) do
		if v.nom == nom then return v end
	end
	return nil
end

-- Les reglages FINAUX : ceux du modele + les ameliorations.
function Catalogue.reglages(nomVoiture, niveaux)
	local v = Catalogue.voiture(nomVoiture) or Catalogue.VOITURES[1]
	local r = {}
	for _, a in ipairs(Catalogue.AMELIORATIONS) do
		r[a.cle] = v[a.cle] + a.effet * (niveaux[a.cle] or 0)
	end
	return r
end

-- La couleur FINALE : la peinture choisie, sinon celle du modele.
function Catalogue.couleur(nomVoiture, indexCouleur)
	local c = Catalogue.COULEURS[indexCouleur or 1]
	local v = Catalogue.voiture(nomVoiture) or Catalogue.VOITURES[1]
	return (c and c.couleur) or v.couleur
end

-- Repeindre un modele de voiture (sur le serveur pour la course, ou
-- sur l ecran pour la vitrine du garage).
function Catalogue.peindre(modele, couleur)
	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") and Catalogue.PEINTURE[p.Name] then
			p.Color = couleur
		end
	end
end

return Catalogue
