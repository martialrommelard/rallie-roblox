-- ============================================================
--  LE CATALOGUE DU GARAGE
--  ModuleScript a placer dans ReplicatedStorage, nom "GarageCatalogue".
--
--  Il est lu par le SERVEUR (GarageServeur : les prix, les effets) ET par
--  l ECRAN (Garage.client : ce qu on affiche). Une seule liste pour les
--  deux : changer un prix ici le change partout.
--
--  Les voitures ont NOTRE carrosserie de rally (generateur VoitureRally.lua),
--  sauf celles qui en precisent une autre ("carrosserie", ex. la Flash) :
--  ce qui change, c est la peinture et les reglages. Les chiffres sont des MULTIPLICATEURS (1 = la voiture de
--  base). Le module PiloteRally les lit (Puissance, VitesseMax,
--  Freinage) ; le script Degats lit Solidite.
--  (La 1re s appelle encore "Jesko" : c est son nom dans les sauvegardes.)
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
	-- (2026-10-30) une AUTRE CARROSSERIE : la voiture de course rouge aux
	-- grands yeux (generateur VoitureFlash.lua). Tres maniable : elle tourne
	-- plus vite et colle mieux a la route (Maniabilite, lue par PiloteRally).
	{nom = "Flash", prix = 500, couleur = Color3.fromRGB(205, 20, 28),
		texte = "Rapide et très maniable : elle colle à la route.",
		Puissance = 1.12, VitesseMax = 1.1, Freinage = 1.1, Solidite = 0.9, Maniabilite = 1.3,
		carrosserie = "VoitureFlash"},
	-- (2026-10-30) la voiture de DEFENSE : noire, couverte d epines et de
	-- branches (generateur VoitureRonce.lua). Qui la touche s abime 2.5 fois
	-- plus (script Degats). Lourde a manier, mais tres solide.
	{nom = "Ronce", prix = 300, couleur = Color3.fromRGB(26, 22, 30),
		texte = "Couverte d'épines : qui la touche s'abîme. Lente, mais très solide.",
		Puissance = 0.95, VitesseMax = 0.97, Freinage = 1.05, Solidite = 1.8, Maniabilite = 0.95,
		carrosserie = "VoitureRonce"},
	-- (2026-10-30) trois carrosseries a POUVOIR (generateur CarrosseriesTheme.lua,
	-- pouvoirs dans le script PouvoirsVoitures)
	{nom = "Givre", prix = 350, couleur = Color3.fromRGB(175, 215, 240),
		texte = "Laisse des plaques de verglas : ceux qui roulent dessus glissent.",
		Puissance = 1.05, VitesseMax = 1.05, Freinage = 1, Solidite = 1, Maniabilite = 1.1,
		carrosserie = "VoitureGivre"},
	{nom = "Requin", prix = 350, couleur = Color3.fromRGB(105, 118, 132),
		texte = "Des dents à l'avant : mords les autres par derrière !",
		Puissance = 1.15, VitesseMax = 1.04, Freinage = 1, Solidite = 1.2, Maniabilite = 1,
		carrosserie = "VoitureRequin"},
	{nom = "Dragon", prix = 450, couleur = Color3.fromRGB(150, 20, 18),
		texte = "Crache du feu sur la voiture devant toi (touche F).",
		Puissance = 1.05, VitesseMax = 1.03, Freinage = 1.05, Solidite = 1.3, Maniabilite = 1,
		carrosserie = "VoitureDragon"},
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

-- Les pieces qu on repeint : celles qui portent l attribut "Peinture"
-- (pose par le generateur VoitureRally.lua sur la caisse, le capot, les
-- portieres, les ailes, l aileron...). Les vitres, phares, plastiques
-- noirs gardent leur couleur.

-- LA REPARATION au garage : 1 piece 🪙 par tranche de 10 % abimes
-- (commencee), et 2 par morceau perdu.
function Catalogue.prixReparation(etat, perdues)
	return math.ceil((100 - etat) / 10) + 2 * #perdues
end

-- Les parties du modele qui forment ces MORCEAUX (leur attribut
-- "Morceau" : "Capot", "Aileron", "Roue avant gauche"...).
-- Rend une liste de BaseParts.
function Catalogue.partiesDe(modele, nomsMorceaux)
	local voulus = {}
	for _, nom in ipairs(nomsMorceaux) do voulus[nom] = true end
	local liste = {}
	for _, d in ipairs(modele:GetDescendants()) do
		if d:IsA("BasePart") and voulus[d:GetAttribute("Morceau") or ""] then table.insert(liste, d) end
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
	r.Maniabilite = v.Maniabilite or 1     -- (pas d amelioration pour elle)
	return r
end

-- Le nom de la CARROSSERIE (le modele dans ServerStorage) d une voiture.
-- Sans rien de precise : notre voiture de rally.
function Catalogue.carrosserie(nomVoiture)
	local v = Catalogue.voiture(nomVoiture) or Catalogue.VOITURES[1]
	return v.carrosserie or "VoitureModele"
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
		if p:IsA("BasePart") and p:GetAttribute("Peinture") then
			p.Color = couleur
		end
	end
end

return Catalogue
