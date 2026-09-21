# Où j'en suis

Projet : **jeu de rally sur Roblox** (voir [`PROJET-RALLY.md`](PROJET-RALLY.md)).
Élève de seconde, a fait du Scratch, débute en Luau.

---

## ⏸️ POUR REPRENDRE LE PROJET — à lire en premier

### État au 2026-09-21

**Étape 1 (le circuit) : TERMINÉE ✅**
**Étape 2 (la fosse à piques) : TERMINÉE ✅ — mon premier script !**
**La zone de départ : TERMINÉE ✅ — ligne, portique, grille**

Le circuit « RALLY MONTAGNE » est construit dans Roblox Studio (place
`Projet de circuit`, placeId 99826427812339) et il est jouable.

| | |
|---|---|
| Tour | 3083 studs (~44 s) |
| Sommet | 59 studs de dénivelé |
| Virage le plus serré | 43 studs de rayon (le lacet) |
| Épingle | élargie à 55–66 studs (elle faisait 42–46) |
| Tremplin | trou de 30 studs, il faut 47 studs/s |
| Fosse à piques | 21 piques + zone de mort, 57 studs de chute |
| **Objets dans `Circuit`** | **2281** |

Un tour : ligne droite → épingle → montée → lacet → tunnel → descente →
tremplin (+ fosse à piques) → dernier virage.

### La zone de départ (ajoutée le 2026-09-21)

Tout est posé sur le 8e morceau de route (`segments[8]`), jamais à une
position écrite en dur.

| Objet | Ce que c'est | À quoi ça sert |
|---|---|---|
| `Circuit/LigneDepart` | Part invisible 60 × 10 × 15 | **c'est elle que le chrono lira** |
| `Circuit/Damier` | 36 cases de 5 × 5 enterrées dans le bitume | ce qu'on voit |
| `Circuit/FeuxDepart` | portique à 58 studs, `Feu1` à `Feu4` | le compte à rebours |
| `Circuit/Grille` | 6 emplacements en quinconce, 18 traits | la grille de départ |

Les 12 ampoules (4 colonnes × 3) sont **éteintes** : chacune a déjà son
`PointLight` avec `Enabled = false`. Allumer un feu = `Enabled = true`
et changer la couleur.

### ⚠️ La première chose à faire en reprenant

1. **Ouvrir Roblox Studio** et vérifier que le circuit est bien là
   (`Workspace > Circuit` dans l'Explorer).
2. **S'il a disparu** : ouvrir `scripts/GenerateurCircuit.lua`, tout copier, et
   coller dans **View → Command Bar** de Studio. Le circuit se reconstruit en
   quelques secondes, à l'identique.
3. **Penser à sauvegarder la place** (`Ctrl+S` dans Studio) — le générateur est
   sauvegardé sur GitHub, mais la place Roblox, non.

### État de vérification du générateur (1009 lignes)

| Partie | Vérifiée comment |
|---|---|
| Circuit, tremplin, montagne, podium | exécutée, le résultat est dans la place |
| Ligne, damier, portique, grille | **les 3 blocs ont été exécutés mot pour mot** le 2026-09-21 |
| Le fichier entier d'un seul tenant | ❌ **jamais relancé en une seule fois** |

Blocs équilibrés : 109 ouvrants (`function`/`if`/`for`/`while`) pour 109 `end`.
C'est un contrôle de structure, pas une preuve que tout le fichier tourne.

### Ce qui n'est PAS encore fait

- ❌ Pas de chrono, pas de checkpoints
- ❌ Le compte à rebours des feux (ils existent mais restent éteints)
- ⚠️ **Deux voitures traînent dans le Workspace** : une Bugatti La Voiture
  Noire et une Koenigsegg Jesko (dans `Workspace.Model`). À ranger dans un
  dossier `Voitures` — ça servira pour les écuries (étape 6).
- ⚠️ **Mon script est dans `Workspace > Baseplate > Piques`**, pas dans
  `ServerScriptService`. Il marche très bien là, mais si je supprime le sol je
  perds le script : le glisser dans `ServerScriptService` serait plus sûr.
- ⚠️ Les sons du moteur ne se chargent pas : les assets du modèle Toolbox ne
  m'appartiennent pas (`not authorized to access Asset`). La voiture est muette.

### La prochaine étape : LE COMPTE À REBOURS + LE CHRONOMÈTRE

C'est **un seul et même script** : les feux s'allument un par un, le dernier
s'éteint, et le chrono démarre à cet instant précis.

1. Allumer `Feu1` à `Feu4` une seconde après l'autre (`for i = 1, 4`)
2. Tout éteindre → **départ**, on note l'heure avec `os.clock()`
3. Détecter quand un joueur franchit `Circuit/LigneDepart`
4. Des checkpoints le long du circuit pour empêcher de couper

⚠️ Pour la détection, **ne pas repartir sur `Touched`** : je m'y suis cassé les
dents avec les piques, et de toute façon `LigneDepart` est en
`CanCollide = false`. Réutiliser la méthode du script `Piques` (regarder la
position à chaque image avec `Heartbeat`), qui elle est fiable.

💡 **L'idée qui simplifie tout** : le chrono ne suit pas la voiture, il suit
**le joueur**. Comme on est assis dans le siège, le personnage se déplace avec
la voiture. Ça marche donc avec la Bugatti, la Koenigsegg, ou même à pied.

---

## Notions de code déjà vues

| Notion | Vue le | Où je m'en sers |
|---|---|---|
| L'interface de Studio (Explorer, Properties, Output) | 2026-09-10 | Partout (`lecons/01-interface.md`) |
| Lire et modifier un script Luau (la liste `POINTS`) | 2026-09-15 | Le générateur de circuit |
| Git : `add`, `commit`, `push` | 2026-09-15 | Sauvegarder le projet sur GitHub |
| **Variables** (`local piques = ...`) | 2026-09-16 | Le script `Piques` |
| **Fonctions** (`local function ... end`) | 2026-09-16 | Le script `Piques` |
| **Conditions** (`if ... then ... end`) | 2026-09-16 | Le script `Piques` |
| **Boucles** (`for ... in ipairs(...) do`) | 2026-09-16 | Le script `Piques` |
| **Événements** : `Heartbeat` (60 fois/s) | 2026-09-16 | Le script `Piques` |
| Pourquoi `Touched` est peu fiable | 2026-09-16 | Découvert en déboguant les piques |
| **Boucles imbriquées** (`for` dans un `for`) | 2026-09-21 | Le damier et le panneau de feux |
| **CFrame relatif** (`a.CFrame * CFrame.new(x, y, z)`) | 2026-09-21 | Tout poser *par rapport à* la route |
| **Paramétrer au lieu d'écrire en dur** | 2026-09-21 | `NB_COL`, `H_MAT` : un chiffre change tout |
| **Raycast** pour vérifier son propre travail | 2026-09-21 | Chaque trait de grille est-il sur le bitume ? |

✅ **J'ai écrit mon premier script le 2026-09-16** : la fosse à piques.

---

## Journal

### 2026-09-10
- Début du parcours. Leçon 1 : l'interface de Studio.

### 2026-09-15
- Changement de cap : projet noté du trimestre = jeu de rally.
- Choix de méthode : le circuit est **généré par un script** au lieu d'être
  construit Part par Part.
- Tracés essayés : circuit en 8 avec pont (abandonné, pas assez original),
  puis **RALLY MONTAGNE** (retenu) — 7 versions au total.
- Cinq bugs trouvés et corrigés (détaillés dans `DOCUMENTATION.md`).
- Projet sauvegardé sur GitHub : https://github.com/martialrommelard/rallie-roblox
- Documentation technique et plan de présentation orale écrits.

### 2026-09-16
- Nettoyage du circuit. Le « doublon » `MarqueTremplin` n'en était pas un :
  ce sont les deux bandes jaunes du tremplin.
- **Épingle élargie** : 42–46 → 55–66 studs. Le rayon (43) était au lacet, pas
  à l'épingle : ce qui gênait, c'était la largeur, pas la courbure.
- **Le sol avait disparu** (Baseplate supprimée par erreur) → le générateur le
  CRÉE maintenant s'il manque, et sa surface est calée sous le bitume
  (avant, la route flottait 12,6 studs au-dessus de l'herbe).
- **Tremplin** : mis à la largeur de la réception (49 → 71) et recentré.
- **Couloir du saut redressé** (points 21 à 25 alignés) : le décalage
  rampe/route est passé de 6,9 studs à 0,04.
- **Fosse à piques** sous le tremplin + **mon premier script Luau**.
- Trois erreurs instructives, gardées en commentaire dans le code :
  `SpecialMesh "Pyramid"` rend la Part invisible ; deux `WedgePart` croisés
  s'additionnent au lieu de se couper (colonne, pas pointe) ; `Touched` ne se
  déclenche pas de façon fiable sur une Part qu'on traverse.

---

### 2026-09-16 (suite) — la montagne et le podium
- **Vraie montagne** autour du tunnel : une grille de colonnes de roche,
  hautes au centre, basses sur les bords. Sommet à ~600 studs (la piste
  culmine à 60). Neige à partir de 262.
- **Éboulis** : 1000 blocs accrochés aux parois pour casser les faces planes.
- **Terrasse** taillée à mi-pente, côté ligne d'arrivée, et **podium** dessus
  (argent / or / bronze) avec panneau « RALLY MONTAGNE » dans la neige.
- Tout est écrit dans le générateur : il reconstruit le décor tout seul.

**Ce que j'ai appris en me plantant** (c'est écrit en commentaire dans le code) :

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| `SpecialMesh` type `Pyramid` | la Part devenait invisible | ce type n'est plus affiché par Roblox |
| Deux `WedgePart` croisés à 90° | on obtenait une colonne carrée | les volumes s'**additionnent**, ils ne se coupent pas : il faut 4 `CornerWedgePart` |
| `Touched` sur une Part traversable | rien ne se déclenchait | `CanCollide = false` → surveiller la position avec `Heartbeat` |
| Faire varier R, V et B séparément | rochers verts et violets | pour nuancer un gris, décaler les **trois canaux ensemble** |
| Agrandir `TextSize` | le texte ne grossissait pas | `TextSize` est **plafonné à 100** : pour écrire gros, il faut **rétrécir le canvas** |
| Enneiger les rochers | cubes blancs géants | seul le **sol** s'enneige, la roche nue s'éclaircit sans blanchir |

⚠️ Le circuit est passé de 877 à environ 2160 objets. Si ça rame en jeu,
c'est l'éboulis qu'il faudra alléger en premier.

---

### 2026-09-21 — la zone de départ
- **La ligne de départ avait disparu du jeu.** Elle était pourtant écrite dans
  le générateur : preuve qu'un fichier juste ne suffit pas, il faut l'exécuter.
- En la refaisant, j'ai trouvé **pourquoi** elle n'allait pas : sa position
  était écrite **en dur** (`-230 ; 486`) alors que le tracé, lui, est *calculé*
  par la spline. Elle dépassait de 6 studs d'un côté du bitume et laissait un
  trou de l'autre. Corrigé en demandant sa position **à la route elle-même**
  (`segments[8].p.CFrame`).
- **Damier** de 36 cases, **enterré** dans l'asphalte : 0,5 stud d'épaisseur
  dont 0,02 seulement dépasse. Ça donne de la peinture sur la route, pas une
  marche — et le décalage de 0,02 évite le z-fighting.
- **Portique** à 58 studs avec **4 colonnes de 3 ampoules** (12 feux éteints),
  chacune avec son `PointLight` déjà prêt.
- **Grille de départ** : 6 emplacements en quinconce, tracé sobre.
- J'ai essayé 5 colonnes, puis 3, puis 4 : à chaque fois **un seul
  chiffre à changer**, parce que la largeur du panneau et l'espacement des
  ampoules se *déduisent* de `NB_COL`. À la main, ça aurait été 10 minutes de
  repositionnement à chaque essai.

**Ce que j'ai appris en me plantant** :

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Position de la ligne écrite en dur | elle dépassait de 6 studs | dans un circuit *calculé*, on ne devine jamais une position : on la **demande** à la route |
| Peinture posée à la même hauteur que le bitume | ça clignote | il faut toujours décaler, même de 0,02 stud |
| Cylindre orienté par défaut | on voit la tranche, pas le rond | un cylindre présente ses faces rondes sur son axe **X** → `CFrame.Angles(0, math.rad(-90), 0)` |
| Grille posée en prolongeant la ligne droite | partirait dans l'herbe si la piste tournait | **remonter la piste segment par segment** en comptant les studs |
| `NB_RANGS` déclaré deux fois | Lua l'accepte en silence | renommer, sinon on lit une valeur en croyant en lire une autre |
| « la voiture est ancrée, elle ne roulera pas » | fausse alerte de ma part | **A-Chassis désancre tout seul** au lancement |

---

## Points à revoir / difficultés

- Le **lacet** dans la montée fait 43 studs de rayon : c'est serré. À vérifier
  en roulant — si ça ne passe pas, écarter les points 12, 13 et 14.
- Le **tremplin** demande 47 studs/s. Si la voiture ne va pas assez vite, il
  faut rallonger la réception (voir `DOCUMENTATION.md`, section 4).
