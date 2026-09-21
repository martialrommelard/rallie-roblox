# Projet du trimestre : jeu de rally sur Roblox

Élève de seconde. Projet de classe numérique, durée : un trimestre (~12 semaines).

## Le jeu en une phrase

Un circuit de rally sur Roblox où plusieurs joueurs roulent en même temps,
chacun chronométré sur son tour, avec un classement des records et un podium.

## Cahier des charges

### Le coeur du jeu (obligatoire — c'est ce qui sera noté)
- [ ] Un circuit fermé praticable (route, virages, barrières)
- [ ] Des voitures conduisibles
- [ ] Une ligne départ / arrivée qui déclenche et arrête un chrono
- [ ] Des checkpoints pour empêcher de couper la piste
- [ ] Le temps du joueur affiché à l'écran pendant la course
- [ ] Un classement des meilleurs temps (podium top 3)
- [ ] Plusieurs joueurs sur le même serveur en même temps

### Les bonus (si le temps le permet)
- [ ] Des écuries : un garage avec plusieurs voitures au choix
- [ ] Des gradins avec du public
- [ ] Records sauvegardés d'une partie à l'autre (DataStore)
- [ ] Ambiance : musique, bruit de moteur, éclairage, météo
- [ ] Plusieurs circuits

## LA règle du projet

À la fin de CHAQUE étape, le jeu doit être jouable en appuyant sur Play.
On n'accumule jamais du travail non testé.

## Le piège à éviter

Ne PAS coder soi-même la physique d'une voiture (roues, suspension, adhérence).
C'est un sujet d'expert. On part d'un châssis de voiture existant et on
consacre son temps au circuit, au chrono, aux écuries et au podium.

## Feuille de route

| Étape | Semaines | Ce qu'on construit | Ce qu'on apprend | Statut |
|---|---|---|---|---|
| 1 | 1-2 | Le circuit : route, virages, barrières, ligne de départ | Parts, ancrage, matériaux, organiser l'Explorer | À faire |
| 2 | 3 | La voiture : châssis importé, point de spawn | Models, Toolbox, PrimaryPart | À faire |
| 3 | 4-5 | Le chrono : départ/arrivée + checkpoints | Touched, fonctions, variables, if | À faire |
| 4 | 6-7 | L'affichage : temps à l'écran, meilleur temps perso | ScreenGui, client/serveur, RemoteEvent | À faire |
| 5 | 8-9 | Le classement et le podium | Tables, tri, boucles for, leaderstats | À faire |
| 6 | 10 | Les écuries : choisir sa voiture au garage | ProximityPrompt, clonage de modèles | À faire |
| 7 | 11 | Le décor : gradins, lumière, sons | Ambiance, optimisation | À faire |
| 8 | 12 | Tests, corrections, présentation orale | Débogage, prise de recul | À faire |

## Journal du projet

### 2026-09-15
- Choix du projet de trimestre : jeu de rally multijoueur avec chrono et podium.
- L'obby prévu à l'origine est abandonné : on apprend le code à travers le rally.
- Feuille de route écrite. Prochaine action : étape 1, construire la piste.

### 2026-09-15 (suite)
- Choix du tracé : circuit en 8, croisement à deux niveaux (pont + passage dessous),
  deux zones de dépassement élargies, une chicane sur la boucle Ouest.
- Décision de méthode : le circuit est construit par un SCRIPT GÉNÉRATEUR
  (`scripts/GenerateurCircuit.lua`) à partir d'une liste de points de contrôle,
  au lieu d'être posé Part par Part à la main. Changer un nombre = nouveau tracé
  en 2 secondes. Le tracé reste le choix de l'élève.
- Version 1 générée dans Studio : 208 segments, tour de 3785 studs (~50 s),
  pente max des rampes 8,6 %, pont à 20 studs de haut.
- À améliorer en v2 : virages trop uniformes (lissage trop fort), tour un peu
  long, zones de dépassement peu visibles.

### 2026-09-15 (suite 2) — le circuit est choisi
- Le circuit en 8 est abandonné : l'élève voulait quelque chose d'original.
- Nouveau tracé retenu : **RALLY MONTAGNE**. Grande ligne droite, épingle,
  montée avec lacet, tunnel creusé dans la montagne au sommet (59 studs),
  descente rapide, tremplin, dernier virage. Tour de ~3100 studs (~44 s).
- Bugs trouvés et corrigés en cours de route (à retenir) :
  * Z-fighting : des morceaux de route qui se chevauchent à la MÊME hauteur
    clignotent et donnent l'illusion de trous. Corrigé en décalant une route
    sur deux de 0,04 stud.
  * Barrières trouées dans les virages : elles étaient posées segment par
    segment. Corrigé en les faisant suivre une ligne décalée du bord.
  * Tunnel bouché : le bloc « montagne » était centré sur la route.
  * Rochers qui dépassent : on les écartait PUIS on les faisait pivoter,
    donc leur coin revenait sur la route. Le dégagement tient maintenant
    compte de la rotation, + une vérification automatique en fin de script.
- Le tremplin ne fait PAS de trou dans la route : une rampe à 12° donne la
  vitesse verticale, et la pente à 35 % juste derrière se dérobe. On saute
  si on arrive vite, on descend simplement si on arrive doucement.
- Étape 1 terminée. Prochaine étape : la voiture puis le CHRONO.

### 2026-09-21 — la ligne de départ et les feux
- **La ligne de départ manquait dans le jeu** alors qu'elle était bien dans le
  générateur. En la refaisant j'ai vu pourquoi elle n'allait pas : sa position
  était écrite **en dur** (`-230 ; 486`) alors que le tracé, lui, est *calculé*.
  Résultat : elle dépassait de 6 studs d'un côté et laissait un trou de l'autre.
  Corrigé en demandant sa position **à la route elle-même** (`segments[8]`).
  C'est la même leçon que pour le tremplin : dans un circuit généré, on ne
  devine jamais une position, on la demande.
- **Damier** de 36 cases de 5x5, **enterré** dans l'asphalte : 0,5 stud
  d'épaisseur dont 0,02 seulement dépasse. Deux raisons : `CanCollide = false`
  + affleurement = aucune bosse sous les roues, et le décalage de 0,02 évite le
  clignotement (z-fighting) qu'on avait déjà eu sur la route.
- **Portique de départ** au-dessus de la ligne : deux mâts hors des barrières,
  une poutre à 58 studs, un panneau et **4 colonnes de 3 ampoules** (12 feux), éteintes.
  Les cylindres présentent leurs faces rondes sur leur axe **X** : il faut les
  tourner de -90° autour de Y pour qu'ils regardent le pilote. Les voitures
  arrivent du côté local **+Z** de la route.
- Les 4 colonnes s'appellent `Feu1` à `Feu4` : le compte à rebours sera une
  boucle `for i = 1, 4`. Largeur et hauteur du panneau se **deduisent** de
  `NB_COL` et `NB_RANGS` : changer ces deux nombres suffit, rien d'autre.
- Pour monter ou descendre le portique, un seul nombre : `H_MAT`. En le montant
  il a fallu aussi **épaissir les mâts** (`EP_MAT`), sinon ils font fil de fer.
- Découvert au passage : il y a **deux voitures** dans le jeu (une Bugatti et
  une Koenigsegg dans `Workspace.Model`), et A-Chassis **désancre tout seul**
  la voiture au lancement — l'ancrage visible dans l'Explorer n'est donc pas
  un problème.
- Prochaine étape : le **chrono**, qui lira la zone invisible `LigneDepart`.
- **Grille de départ** : 6 emplacements, 3 de chaque côté, en quinconce.
  Tracé sobre — le trait à ne pas dépasser et les deux côtés, pas de numéro.
  Boîtes de 11 x 9 studs, une place tous les 17 studs, de 22 à 107 studs
  derrière la ligne, 30 studs d'écart entre les deux colonnes.
  Le placement **remonte la piste segment par segment** en comptant les studs,
  au lieu de prolonger la ligne droite dans le vide : si la ligne d'arrivée se
  retrouvait un jour dans un virage, la grille suivrait la courbe.
  Vérifié par un tir de rayon vers le bas : les 18 traits touchent le bitume.
- **Le compte à rebours des feux marche** (`scripts/FeuxDepart.lua`, installé
  dans `ServerScriptService`). Séquence : ligne 1 rouge → ligne 2 rouge aussi →
  ligne 3 rouge aussi → **tout vert, départ**. Une seconde entre chaque.
  Les ampoules ont été renommées `Ampoule1/2/3` dans chaque colonne : le numéro
  désigne la **ligne**, pas la colonne, donc une ligne entière s'allume d'un
  coup avec `colonne:FindFirstChild("Ampoule" .. n)`.
  Retenu : allumer une ampoule, c'est changer **trois** choses ensemble — la
  couleur, la **matière** (`Neon`, sinon ça reste terne) et le `PointLight`.
  Testé sans lancer Play, en relevant l'état des 12 ampoules à chaque étape.
- Route6 avait été déplacé à la main (enfoncé de 0,5 stud, décalé de 3).
  Retrouvé en mesurant, pour les 187 morceaux, l'écart au milieu de leurs deux
  voisins : `Route6` sortait du lot. Recalé, puis vérifié en « roulant » le long
  de l'axe (152 rayons tirés vers le bas) : plus aucun trou, surface plane.
- Grille de départ : **2 colonnes façon F1** retenues. 6 boîtes de 11 studs
  feraient 66 studs alors que la piste en fait 60 : impossible de donner à
  chacune son couloir sans élargir la piste. Les places 1/3/5 sont donc dans
  le même couloir, comme sur une vraie grille.
