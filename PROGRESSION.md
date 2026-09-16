# Où j'en suis

Projet : **jeu de rally sur Roblox** (voir [`PROJET-RALLY.md`](PROJET-RALLY.md)).
Élève de seconde, a fait du Scratch, débute en Luau.

---

## ⏸️ POUR REPRENDRE LE PROJET — à lire en premier

### État au 2026-09-16

**Étape 1 (le circuit) : TERMINÉE ✅**
**Étape 2 (la fosse à piques) : TERMINÉE ✅ — mon premier script !**

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

Un tour : ligne droite → épingle → montée → lacet → tunnel → descente →
tremplin (+ fosse à piques) → dernier virage.

### ⚠️ La première chose à faire en reprenant

1. **Ouvrir Roblox Studio** et vérifier que le circuit est bien là
   (`Workspace > Circuit` dans l'Explorer).
2. **S'il a disparu** : ouvrir `scripts/GenerateurCircuit.lua`, tout copier, et
   coller dans **View → Command Bar** de Studio. Le circuit se reconstruit en
   quelques secondes, à l'identique.
3. **Penser à sauvegarder la place** (`Ctrl+S` dans Studio) — le générateur est
   sauvegardé sur GitHub, mais la place Roblox, non.

### Ce qui n'est PAS encore fait

- ❌ Pas de chrono, pas de checkpoints, pas de podium
- ❌ La voiture vient du Toolbox, elle n'est pas configurée proprement
- ❌ Aucun décor autre que les arbres et les rochers du circuit
- ⚠️ **Mon script est dans `Workspace > Baseplate > Piques`**, pas dans
  `ServerScriptService`. Il marche très bien là, mais si je supprime le sol je
  perds le script : le glisser dans `ServerScriptService` serait plus sûr.

### La prochaine étape : LE CHRONOMÈTRE

Il faut, dans l'ordre :
1. La Part `LigneDepart` (elle existe déjà dans le dossier `Circuit`)
2. Détecter quand une voiture la franchit
3. Une variable qui retient l'heure de départ
4. Des checkpoints le long du circuit pour empêcher de couper

⚠️ Pour la détection, **ne pas repartir sur `Touched`** : je m'y suis cassé les
dents avec les piques. Réutiliser la méthode du script `Piques` (regarder la
position à chaque image avec `Heartbeat`), qui elle est fiable.


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

## Points à revoir / difficultés

- Le **lacet** dans la montée fait 43 studs de rayon : c'est serré. À vérifier
  en roulant — si ça ne passe pas, écarter les points 12, 13 et 14.
- Le **tremplin** demande 47 studs/s. Si la voiture ne va pas assez vite, il
  faut rallonger la réception (voir `DOCUMENTATION.md`, section 4).
