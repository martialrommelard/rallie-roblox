-- =========================================================
--  LA LISTE DES PRODUITS DE L EPICERIE  (ModuleScript)
--  A placer dans ReplicatedStorage, nom : Produits.
--
--  C est LA SEULE liste : le generateur (Epicerie.lua) y lit quoi poser
--  sur les rayons, le serveur (EpicerieServeur) les prix et les effets,
--  l ecran du joueur (Epicerie.client) les noms et les durees.
--  Pour ajouter un produit : une ligne ici, et c est tout.
--
--  effet :
--    "vitesse" : on court plus vite      (valeur = vitesse de marche)
--    "saut"    : on saute plus haut      (valeur = multiplicateur)
--    "vol"     : on vole ; pendant une course, on devient CHASSEUR (on
--                sort de sa voiture, sa course a soi s arrete)
--    "glace"   : on lance des boules de glace (clic) ; touche = congele
--                (valeur = secondes de congelation)
--    "fun"     : rien, c est pour le plaisir (et ca se mange quand meme)
--  duree : en secondes, ou "course" = jusqu a la fin de la course en cours
--          (ou de la prochaine, s il n y en a pas)
--  meuble : ou il est range dans le magasin ("frigo", "rayon", "glaces", "fruits")
-- =========================================================

local Produits = {
	{id = "Energie", nom = "Boisson Flash",       prix = 30, effet = "vitesse", valeur = 70, duree = 30,
		meuble = "frigo", texte = "Cours comme Flash (30 s)"},
	{id = "Ressort", nom = "Bonbon ressort",      prix = 25, effet = "saut",    valeur = 1.6, duree = 30,
		meuble = "rayon", texte = "Saute plus haut (30 s)"},
	{id = "Glace",   nom = "Glace",               prix = 40, effet = "glace",   valeur = 4, duree = 45,
		meuble = "glaces", texte = "Lance des boules de glace (45 s)"},
	{id = "Tomate",  nom = "Tomate volante",      prix = 150, effet = "vol",    duree = "course",
		meuble = "fruits", texte = "Vole jusqu'à la fin de la course"},
	{id = "Pomme",   nom = "Pomme",               prix = 5,  effet = "fun",
		meuble = "fruits", texte = "Croquante !"},
}

-- pour retrouver un produit par son id : Produits.parId.Energie
Produits.parId = {}
for _, p in ipairs(Produits) do Produits.parId[p.id] = p end

return Produits
