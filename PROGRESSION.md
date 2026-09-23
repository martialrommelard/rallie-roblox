# Où j'en suis

Projet : **jeu de rally sur Roblox** (voir [`PROJET-RALLY.md`](PROJET-RALLY.md)).
Élève de seconde, a fait du Scratch, débute en Luau.

---

## ⏸️ POUR REPRENDRE LE PROJET — à lire en premier

### État au 2026-09-23

**Étape 1 (le circuit) : TERMINÉE ✅**
**Étape 2 (la fosse à piques) : TERMINÉE ✅ — mon premier script !**
**La zone de départ : TERMINÉE ✅ — ligne, portique, grille**
**Étape 3 (le départ complet et la course en 3 tours) : TERMINÉE ✅**

Le circuit « RALLY MONTAGNE » est construit dans Roblox Studio (place
`Projet de circuit`, placeId 99826427812339) et **une course entière se joue
du début à la fin**.

| | |
|---|---|
| Tour | 3083 studs (~44 s) |
| Sommet | 59 studs de dénivelé |
| Virage le plus serré | 43 studs de rayon (le lacet) |
| Épingle | élargie à 55–66 studs |
| Tremplin | trou de 30 studs, il faut 47 studs/s |
| Fosse à piques | 21 piques + zone de mort, 57 studs de chute |
| Point le plus bas du décor | Y = −27,8 (le talus) |
| **Objets dans `Circuit`** | **~2280** |

### Le déroulement d'une course (ajouté le 2026-09-23)

```
un joueur s'assoit
   ├─ cages fermées autour de chaque voiture
   ├─ 5 s d'attente
   ├─ bip + rouge 1  →  "3" à l'écran
   ├─ bip + rouge 2  →  "2"
   ├─ bip + rouge 3  →  "1"
   └─ BIIIIP + VERT  →  "GO", cages détruites, CourseEnCours = true
                        panneau "TOUR 1 / 3" en bas à gauche
        ↓
   3 tours comptés au passage de LigneDepart
        ↓
   "COURSE TERMINÉE"  →  CourseEnCours = false
        ↓
   5 s plus tard : les 6 voitures sont reposées sur la grille
```

### Les scripts du jeu

| Où | Script | Rôle |
|---|---|---|
| `ServerScriptService` | `FeuxDepart` | bips, feux, cages, `3 2 1 GO` |
| `ServerScriptService` | `CompteurTours` | compte les tours, arrête la course à 3 |
| `ServerScriptService` | `Voitures` | pose la grille, gère les chutes, remet les voitures |
| `StarterGui/EcranDepart` | `Affichage` | **LocalScript** : l'écran du joueur |
| `Workspace/Baseplate` | `Piques` | la fosse (à déplacer dans `ServerScriptService`) |

Les trois scripts serveur se parlent par **un seul attribut** :
`workspace:GetAttribute("CourseEnCours")`. `FeuxDepart` le met à `true` au
vert, `CompteurTours` le remet à `false` à la fin. `Voitures` écoute son
**passage** de vrai à faux (pas sa valeur — voir le journal du 23).

### Les objets ajoutés le 2026-09-23

| Objet | Ce que c'est |
|---|---|
| `Circuit/FeuxDepart/Poutre/Bip` | le son des 3 bips |
| `Circuit/FeuxDepart/Poutre/BipLong` | le bip du départ, + 2 `PitchShiftSoundEffect` |
| `Circuit/CagesDepart` | dossier vide : les cages sont construites à la demande |
| `Workspace/Voitures` | les 6 voitures, posées sur les 6 `PlaceN` |
| `ServerStorage/VoitureModele` | la copie de référence, clonée à chaque reset |
| `ReplicatedStorage/CompteARebours` | RemoteEvent : le `3 2 1 GO` |
| `ReplicatedStorage/MajTours` | RemoteEvent : le panneau des tours |
| `StarterGui/EcranDepart` | ScreenGui : `Chiffre` (centre) + `Panneau` (bas gauche) |

### ⚠️ La première chose à faire en reprenant

1. **Ouvrir Roblox Studio** et vérifier que le circuit est là
   (`Workspace > Circuit` dans l'Explorer).
2. **S'il a disparu** : ouvrir `scripts/GenerateurCircuit.lua`, tout copier,
   coller dans **View → Command Bar**. ⚠️ Le générateur ne contient PAS les
   sons, ni les cages, ni les voitures : il faudrait les refaire à la main.
3. **Penser à `Ctrl+S`** — la place Roblox ne se sauvegarde pas toute seule.

### État de vérification du générateur (1009 lignes)

| Partie | Vérifiée comment |
|---|---|
| Circuit, tremplin, montagne, podium | exécutée, le résultat est dans la place |
| Ligne, damier, portique, grille | les 3 blocs exécutés mot pour mot le 2026-09-21 |
| Le fichier entier d'un seul tenant | ❌ **jamais relancé en une seule fois** |

### Ce qui n'est PAS encore fait

- ❌ **Pas de chronomètre** : on compte les tours, mais pas le temps.
  Le point de branchement est prêt : `print("DEPART !")` dans `FeuxDepart`.
- ❌ **Pas de checkpoints** : rien n'empêche de couper le circuit. Seule la
  largeur de la ligne (±40 studs) est vérifiée au passage.
- ❌ Pas de records, pas de podium à la fin.
- ⚠️ **Pas de bouton « abandonner »** : si un joueur descend de voiture au
  milieu d'un tour sans jamais finir, `CourseEnCours` reste à `true` et plus
  aucun départ ne peut se lancer. Il faudrait un temps limite ou un bouton.
- ⚠️ **Le son du moteur ne marche pas** : les assets du modèle Toolbox ne
  m'appartiennent pas (`Asset is not approved for the requester`).
- ⚠️ **Erreur dans la voiture** : `A-Chassis Tune.Initialize` ligne 286,
  « value of type nil cannot be converted to a number », répétée en boucle.
  Ça noie l'Output. Pas encore cherché.
- ⚠️ **Le script `Piques` est dans `Workspace > Baseplate`** : si je supprime
  le sol, je perds le script.

### La prochaine étape : LE CHRONOMÈTRE

Tout est prêt pour l'accrocher :

1. Noter l'heure avec `os.clock()` au moment du `print("DEPART !")`
2. À chaque passage compté par `CompteurTours`, calculer le temps du tour
3. L'afficher dans le `Panneau` (il y a la place sous « TOUR n / 3 »)
4. Garder le meilleur temps → les records, puis le podium

⚠️ Ne PAS repartir sur `Touched` : `LigneDepart` est en `CanCollide = false`.
La méthode qui marche est déjà écrite dans `CompteurTours` — le changement de
signe de `PointToObjectSpace`.
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
| **`task.wait()`** : faire attendre un script | 2026-09-21 | Le compte à rebours des feux |
| **Matière `Neon`** : ce qui fait « allumé » | 2026-09-21 | Les ampoules du portique |
| Nommer pour pouvoir chercher (`Ampoule1..3`) | 2026-09-21 | `FindFirstChild("Ampoule" .. n)` |

✅ **J'ai écrit mon premier script le 2026-09-16** : la fosse à piques.

| **Le son** : `PlaybackSpeed`, `Volume`, `Looped` | 2026-09-23 | Les bips du départ |
| **`PitchShiftSoundEffect`** : la hauteur sans la durée | 2026-09-23 | Le BIIIIP du départ |
| **`TweenService`** : faire varier une valeur en douceur | 2026-09-23 | Le fondu du bip, le `3 2 1 GO` |
| **`GetBoundingBox()`** : la boîte d'un modèle *et* son sens | 2026-09-23 | Les cages, poser les voitures |
| **`CFrame.lookAt`** et `cf * CFrame.new(…)` | 2026-09-23 | Cages, placement en grille |
| **Serveur ≠ client** : `Script` / `LocalScript` | 2026-09-23 | L'affichage à l'écran |
| **`RemoteEvent`** : `FireAllClients` / `OnClientEvent` | 2026-09-23 | `3 2 1 GO`, panneau des tours |
| **Les interfaces** : `ScreenGui`, `TextLabel`, `Frame`, `UICorner` | 2026-09-23 | L'écran de départ |
| **Les attributs** : `SetAttribute` / `GetAttributeChangedSignal` | 2026-09-23 | `CourseEnCours` |
| **`PointToObjectSpace`** : de quel côté d'un objet je suis | 2026-09-23 | Compter les tours |
| **Les tables associatives** (`passages[joueur]`) | 2026-09-23 | Retenir l'état de chaque joueur |
| **`SeatPart`, `Health`, `Players`** | 2026-09-23 | Les chutes hors du circuit |
| **`Clone()` et `PivotTo()`** | 2026-09-23 | Remettre les voitures en grille |

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

### 2026-09-23 — le départ sonore, les cages, et la course en 3 tours

Grosse séance. Le départ est passé de « trois lampes qui changent de couleur »
à un vrai départ de course.

**Le son.** Un seul fichier, `rbxasset://sounds/electronicpingshort.wav`
(0,72 s), sert pour tout. Les sons intégrés à Roblox marchent toujours,
contrairement aux assets du Toolbox qui, eux, sont bloqués.

**Les cages.** Chaque voiture est enfermée dans 4 murs tant que le feu n'est
pas vert. Ils sont invisibles (`TRANSP = 1`) mais solides — `Transparency` et
`CanCollide` sont deux propriétés indépendantes.

**L'écran.** Premier `LocalScript` du projet, et premier `RemoteEvent`.
Le serveur ne peut pas écrire sur l'écran d'un joueur : il envoie un message,
et un script qui tourne chez le joueur l'affiche.

**Les tours.** Comptés par le changement de signe de `PointToObjectSpace` —
la même méthode que les piques, jamais `Touched`.

**Les voitures.** Rangées dans `Workspace/Voitures`, posées sur les 6
emplacements en demandant sa position et sa direction au trait `Avant` de
chaque `PlaceN`. Elles réapparaissent 5 s après la fin de la course.

**Ce que j'ai appris en me plantant** :

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Vouloir un bip aigu **et** long | impossible avec `PlaybackSpeed` seul | il change la vitesse ET la hauteur ensemble ; pour les séparer il faut `PitchShiftSoundEffect` |
| Boucler un bip court pour le faire durer | on entendait *bip-bip-bip*, pas *biiiip* | une boucle s'entend toujours ; il faut un son qui dure vraiment |
| Ralentir un son pour le rendre grave | il devenait **mou**, on ne l'entendait plus | ralentir étale l'énergie : même coup, 3× plus long = 3× moins fort |
| Empiler 3 `PitchShiftSoundEffect` | son métallique, artificiel | chaque effet ajoute des artefacts **et** de la latence : en mettre le moins possible |
| Le bip en retard sur la lumière | une lumière est instantanée, un son non | lancer le son **en avance**, et prendre cette avance **sur** l'attente suivante, sinon tout le rythme ralentit |
| Mesurer le son en mode Edit | `TimePosition` restait à 0 | le moteur audio ne tourne pas pareil hors du jeu : mesurer en Play |
| Cage calée sur le marquage au sol | la voiture faisait 18 studs pour une case de 9 | demander ses mesures à la **voiture** (`GetBoundingBox`), pas au décor |
| `if attribut == false then` | les voitures étaient rasées 5 s après le lancement | un attribut faux ne dit pas si la course vient de finir ou n'a **jamais** commencé : il faut détecter le **passage** de vrai à faux |
| Ranger les voitures dans un dossier | plus aucune cage, **sans aucune erreur** | le code cherchait « les modèles à la racine du Workspace » ; déplacer des objets oblige à relire tout ce qui les cherchait |
| Un 2ᵉ joueur s'assoit pendant la course | le compte à rebours repartait et une cage apparaissait en pleine piste | `enCours` protège le compte à rebours, `CourseEnCours` protège toute la course — il faut les deux |

---

## Points à revoir / difficultés

- Le **lacet** dans la montée fait 43 studs de rayon : c'est serré. À vérifier
  en roulant — si ça ne passe pas, écarter les points 12, 13 et 14.
- Le **tremplin** demande 47 studs/s. Si la voiture ne va pas assez vite, il
  faut rallonger la réception (voir `DOCUMENTATION.md`, section 4).
