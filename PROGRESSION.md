# Où j'en suis

Projet : **jeu de rally sur Roblox** (voir [`PROJET-RALLY.md`](PROJET-RALLY.md)).
Élève de seconde, a fait du Scratch, débute en Luau.

---

## ⏸️ POUR REPRENDRE LE PROJET — à lire en premier

### État au 2026-10-05

**Les bureaux de la direction de course sont VIVANTS ✅ (2026-10-05)** —
s'asseoir à un bureau ouvre un menu (caméras de la piste, pilotes en direct
avec caméra TV ou embarquée, météo) ; éclairage de nuit (réverbères jaunes,
néons bleus au spawn) ; 18 employés PNJ qui tapent au clavier ; au fond, le
directeur de course avec **mon avatar** montre le tremplin sur le croquis.
Tout est construit **en Play** par des scripts (voir le journal du 05).

**Le sous-sol et la salle de sport ✅ (2026-10-05, suite)** — une grande salle
creusée sous le spawn et sous les deux bâtiments (sol noir, murs blancs,
plafonniers), entrées : les 2 escaliers derrière le spawn (portes en face des
marches) et 2 grands garages côté piste. Dans le bâtiment vide : salle de
sport (tapis, banc, sacs de frappe, vélos).
⚠️ Le sous-sol et la salle de sport **modifient la place** (générateurs à
lancer une fois en Edit) : sans `Ctrl+S`, ils sont perdus.
❌ **Les simulateurs ont été SUPPRIMÉS le 2026-10-06** : l'écran de la borne
restait bleu (la 3D ne s'affichait pas). Voir le journal du 06.

**Étape 1 (le circuit) : TERMINÉE ✅**
**Étape 2 (la fosse à piques) : TERMINÉE ✅ — mon premier script !**
**La zone de départ : TERMINÉE ✅ — ligne, portique, grille**
**Étape 3 (le départ complet et la course en 3 tours) : TERMINÉE ✅**
**Sorties de route : TERMINÉ ✅ — rouler hors de la route élimine (2026-10-03)**
**Le chronomètre : TERMINÉ ✅ — en haut au milieu, du vert à l'arrivée (2026-10-03)**
**La zone de spawn : TERMINÉE ✅ (2026-10-03)** — tout est construit par le
générateur `scripts/ZoneSpawn.lua` (1781 lignes ; copie dans Studio :
`ServerStorage/Outils/ZoneSpawn`, lancée par `loadstring`). Demi-rond blanc
en hauteur, gradins calculés par la ligne de vue, murs de verre fondus, toit
blanc, deux bâtiments à portes coulissantes, tableau des records, bouton
« DÉMARRAGE DE LA COURSE », tableau de la dernière course, voiture
d'exposition qui tourne, bancs, jardin, massif le long du verre, mousse
derrière le bouton, et **les bureaux de la direction de course** (13 îlots,
croquis du circuit au fond).
**Records, bouton de départ, podium, minimap : TERMINÉS ✅ (2026-10-03)**

Aussi le 2026-10-03 : voitures recalées sur les traits de la grille, cages
rouges qui ne grandissent plus, voitures vides qui disparaissent au vert,
glissières en entonnoir sur le tremplin.

⚠️ **Objets de la place qui ne sont PAS dans le dépôt** (refaits à la main
dans Studio, perdus sans `Ctrl+S`) : `StarterGui/EcranDepart/BoiteChrono`
(Frame 170 × 46 en haut au milieu, avec le TextLabel `Chrono` en RobotoMono).

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
| `ServerScriptService` | `PosteDirection` | les bureaux : caméras, classement en direct, météo (vérifie qu'on est assis) |
| `StarterPlayerScripts` | `PosteDirection` | **LocalScript** : le menu du bureau, la caméra, la pluie |
| `ServerScriptService` | `EclairageNuit` | réverbères, lampes du tunnel, néons bleus du spawn, la nuit |
| `ServerScriptService` | `PnjBureaux` | les 18 employés et le directeur |
| `StarterPlayerScripts` | `PnjBureaux` | **LocalScript** : les mains qui tapent, les têtes qui tournent |
| `ServerScriptService` | `SalleSportServeur` | banc, vélos, sacs de frappe, tapis, et les bornes d'arcade (record, partie recopiée) |
| `StarterPlayerScripts` | `Arcade` | **LocalScript** : le jeu de course 3D sur l'écran des simulateurs |
| `StarterPlayerScripts` | `Exercices` | **LocalScript** : bras et jambes qui bougent (banc, vélo, coups de poing) |
| `StarterPlayerScripts` | `LumiereSpawn` | **LocalScript** : un peu moins de lumière quand on est sur le spawn |
| (à lancer en Edit) | `SalleSousSpawn.lua`, `SalleSport.lua`, `MachineSimulateur.lua` | les générateurs du sous-sol, de la salle de sport et des simulateurs |

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

- ❌ **Pas de checkpoints** : rien n'empêche de couper le circuit. Seule la
  largeur de la ligne (±40 studs) est vérifiée au passage.
- ⚠️ **Jamais essayé à plusieurs joueurs** : l'attente du choix des places,
  les places 2 et 3, le podium à 3 statues.
- ⚠️ **Les records (DataStore) ne sont pas sauvegardés dans Studio** tant que
  *Game Settings > Security > Enable Studio Access to API Services* n'est pas
  coché. Une fois le jeu publié, ça marche.
- ⚠️ **Pas de bouton « abandonner »** : depuis le 2026-10-03, un pilote qui
  **meurt** est éliminé et ne bloque plus la course. Mais un joueur qui
  **descend** de voiture (touche Espace) sans mourir est toujours attendu :
  `CourseEnCours` reste à `true`. Il faudrait un temps limite ou un bouton.
- ⚠️ **Les glissières du tremplin** n'ont pas encore été essayées en roulant
  (posées et vérifiées par le calcul le 2026-10-03).
- ⚠️ **Élimination à l'entrée du tunnel** (2026-10-03, 2 fois, ~25 s après
  le départ) : la route y est propre (62 000 rayons, jonctions, murs). Pas
  reproduit ensuite. Si ça revient : rebrancher un « mouchard » qui imprime
  ce qu'il y a sous le siège à chaque image.
- ⚠️ **Le son du moteur ne marche pas** : les assets du modèle Toolbox ne
  m'appartiennent pas (`Asset is not approved for the requester`).
- ⚠️ **Erreur dans la voiture** : `A-Chassis Tune.Initialize` ligne 286,
  « value of type nil cannot be converted to a number », répétée en boucle.
  Ça noie l'Output. Pas encore cherché.
- ⚠️ **Le script `Piques` est dans `Workspace > Baseplate`** : si je supprime
  le sol, je perds le script.

### La prochaine étape : LES CHECKPOINTS

C'est **obligatoire** dans le cahier des charges : des portes invisibles le
long du circuit, à passer dans l'ordre ; un tour ne compte que si on les a
toutes passées (sinon on peut couper).

Ensuite : un essai à plusieurs joueurs, et cocher l'accès aux API dans Studio.
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
| **`RaycastParams`** : un rayon qui traverse certains objets | 2026-10-03 | Savoir sur quoi roule la voiture |
| **`os.clock()`** : mesurer une durée | 2026-10-03 | La tolérance d'1 s hors de la route |
| **Ne pas croire le client** : le serveur vérifie avant d'obéir | 2026-10-05 | Seul un joueur assis au bureau peut changer la météo |
| **`ReplicationFocus`** : choisir ce que le streaming envoie | 2026-10-05 | Les caméras du bureau voient la piste au loin |
| **`SpotLight` / `PointLight`**, `Lighting.ClockTime` | 2026-10-05 | L'éclairage de nuit |
| **Les PNJ** : `CreateHumanoidModelFromDescription`, `AnimationConstraint` | 2026-10-05 | Les employés et le directeur |

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

> Le déroulé complet de la séance, avec mes demandes dans l.ordre et les
> allers-retours, est dans [`lecons/05-discussion-2026-09-23.md`](lecons/05-discussion-2026-09-23.md).

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

### 2026-10-03 — les sorties de route

**Ce que je voulais** : quand la voiture sort du circuit, le pilote meurt,
réapparaît au spawn, et sa voiture revient à la fin de la course.

**Ce qui existait déjà** : seule la **chute** sous Y = −60 tuait. Rouler dans
l'herbe ou sur le talus sans tomber ne faisait rien.

**Ce qui a été ajouté** :

| Script | Changement |
|---|---|
| `Voitures` | un **rayon** part du siège vers le bas : s'il touche autre chose que la route pendant plus de `TOLERANCE` = 1 s, le pilote meurt et sa voiture est détruite |
| `CompteurTours` | un pilote mort pendant la course est **éliminé** (compté comme « fini »), sinon la course l'attendait pour toujours |
| `Affichage` | le panneau affiche « COURSE / ELIMINE » en rouge |

**Comment on sait ce qui est « la route »** : par le **nom** du dossier dans
`Circuit` (`Route`, `Damier`, `Grille`, `LigneDepart`, `Tremplin`…). Rien
n'est écrit en coordonnées : si on régénère le circuit, ça marche toujours.

**Vérifié par le calcul, pas à l'œil** : 15 147 rayons tirés sur toute la
route. 9 tombaient sur `PilierTremplin`, qui dépasse de 2 studs de chaque
côté sous le bord de la rampe → ajouté à la liste de la route.

**Testé en jeu** : sortie dans l'herbe → mort, réapparition au spawn, voitures
revenues sur la grille. ✅

| L'erreur évitée | Ce qui se serait passé | La règle |
|---|---|---|
| Juger le sol en plein saut | au-dessus de la fosse, le rayon touche les piques → éliminé en l'air | on ne juge que si le sol est à moins de 8 studs (`EN_L_AIR`) ; et le rayon traverse le dossier `Piques` |
| Tuer dès qu'une roue touche l'herbe | éliminé au moindre écart | une **tolérance** d'1 s : il faut **rester** dehors |
| Oublier le compteur de tours | le pilote mort était encore attendu → course jamais finie → voitures jamais revenues | quand on ajoute une façon de quitter la course, relire qui attend la fin de la course |

### 2026-10-03 (suite) — le chrono, la grille, les cages, le tremplin

| Ce que j'ai demandé | Ce qui a été fait |
|---|---|
| Les voitures mal placées sur la grille | le pivot de la voiture, c'est son **siège** (pilote à gauche) : la carrosserie dépassait de 1,2 stud. On centre maintenant sa **boîte** entre les traits, nez à 0,5 stud du trait Avant |
| Voir les cages | `TRANSP = 0.6` dans `FeuxDepart` : murs rouges translucides |
| Les cages grandissent au départ | en jeu, A-Chassis gonfle la boîte de la voiture de **18 à 32,8 studs**. On mesure la voiture de **référence** de `ServerStorage` (qui n'a jamais roulé) |
| Le chronomètre | `FeuxDepart` note `GetServerTimeNow()` au vert dans l'attribut `HeureDepart` ; l'écran calcule « maintenant − départ » à chaque image ; le serveur donne le temps final |
| Les voitures inutilisées | au vert, celles sans pilote disparaissent ; les 6 reviennent à la fin |
| La voiture plantée dans la barrière après le tremplin | on pouvait décoller sur 70 studs de large, mais en bas les barrières sont à 30 studs de l'axe → glissières en entonnoir, le couloir est **demandé aux barrières d'en bas** |

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Mesurer une voiture qui roule | sa boîte passe de 18 à 32,8 studs | mesurer la copie de référence, jamais celle en piste |
| Centrer le pivot d'un modèle | la voiture était décalée | le pivot n'est pas forcément le milieu : demander la boîte |
| Un spectateur au feu vert | la course l'attendait pour toujours | qui court = qui est assis **au vert** ; les autres sont spectateurs |
| Mesurer une barrière en biais par son centre | couloir trop large de 2 studs | tester les deux bouts |
| Laisser un objet sélectionné | le tremplin a été déplacé à la souris | vider la sélection après avoir montré un objet ; Ctrl+Z existe |

### 2026-10-03 (fin) — le spawn, le bouton, les records, les bureaux

> Le déroulé complet de la séance, avec mes demandes mot pour mot, est dans
> [`lecons/06-discussion-2026-10-03.md`](lecons/06-discussion-2026-10-03.md).

| Ce que j'ai demandé | Ce qui a été fait |
|---|---|
| Un spawn en demi-rond devant la ligne, avec des gradins | plateforme blanche à 43 studs de haut, gradins de 10 rangées **calculés par la ligne de vue**, 477 sièges bleus à dossier, garde-fous en verre, zone de chute mortelle |
| Murs de verre et toit | les morceaux de verre sont **fondus** (`UnionAsync`) : plus de traits ; toit blanc plein |
| Les deux carrés → des bâtiments | collés au rond, portes coulissantes futuristes (`PortesCoulissantes`), intérieur néon, fenêtres sur la cour |
| Un classement des meilleurs temps | `Classement` : `OrderedDataStore`, tableau mis à jour en direct, bandeau « NOUVEAU RECORD ! » |
| Un bouton pour lancer la course | `DepartCourse` + `ChoixPlace` : on choisit sa place, on attend les autres (30 s max), on est téléporté dans la voiture ; bouton bloqué pendant la course |
| Après la course | retour au spawn, « ÉLIMINÉ » en rouge ou « 1er — temps » en vert, tableau de la dernière course |
| Un podium | statues géantes des 3 premiers + confettis (`Podium`) |
| Minimap | façon Mario Kart, le circuit entier, données envoyées par le serveur (`CarteCircuit`) |
| Déco du spawn | voiture d'exposition qui tourne, lignes néon, bancs, musique B puis D (`AmbianceSpawn`), jardin, massif le long du verre, mousse derrière le bouton |
| Des bureaux qui s'occupent de la course | bâtiment de gauche (vu en regardant la piste) : 13 îlots de 4 bureaux, tableau avec le **croquis du circuit dessiné à partir des 187 morceaux de route**, départ en bas |

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Minimap faite côté joueur | seulement 20 morceaux de route sur 187 | **streaming** : le joueur ne reçoit que ce qui est près de lui → demander au serveur |
| Écran caméra du podium | écran noir | une caméra créée par le serveur n'arrive pas chez le joueur (abandonné) |
| Croquis tout petit | le circuit est tout en longueur | choisir le sens du dessin (quart de tour) pour remplir le tableau |
| « Le bâtiment de droite » | je me suis trompé de bâtiment | la droite dépend d'où on regarde : demander ou montrer |

### 2026-10-05 — les bureaux prennent vie

| Ce que j'ai demandé | Ce qui a été fait |
|---|---|
| « quand on s'assoit sur un bureau on peut faire quelque chose avec » | `PosteDirection` (serveur) + `PosteDirection` (LocalScript) : menu CAMÉRAS / PILOTES / MÉTÉO ; l'écran du bureau affiche « EN LIGNE : moi » |
| Caméras plus hautes, moins nombreuses | 30 studs de haut, 15 du bord ; 7 dans le menu (DÉPART, TREMPLIN, TUNNEL + 4) ; 32 caméras TV pour suivre un pilote |
| Enlever les drapeaux | fait (ils n'avaient pas d'effet sur la course) |
| La nuit : lumière jaune sur la route, bleue au spawn | `EclairageNuit` : 40 réverbères dont le bras va **jusqu'au milieu de la route**, 10 lampes dans le tunnel, 52 lumières bleues sur les néons du spawn ; s'allume avec l'heure (`ClockTime`) |
| Des PNJ qui travaillent aux bureaux | `PnjBureaux` : 18 employés, 18 métiers différents, casque radio, clavier ; ils tapent et tournent la tête (LocalScript) |
| Au fond, quelqu'un qui montre la piste, avec mon avatar | le directeur (avatar de `game.CreatorId`), de face, montre le tremplin avec une baguette, point rouge sur le croquis, jambes naturelles |

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Caméras à 9 studs | les barrières cachaient la route à presque toutes | vérifier **par un rayon** que la caméra voit la route |
| Réverbère au bord | il n'éclairait que le bord : la route fait 44 à 80 studs | mesurer la largeur, mettre la lampe au milieu (99 % de la route éclairée) |
| Poteaux de 76 studs | au-dessus d'un ravin, le poteau descendait jusqu'en bas | l'accrocher au bord de la route |
| `C0` en lecture seule | les avatars récents n'ont plus de `Motor6D` | tourner l'`Attachment0` des `AnimationConstraint` |
| PNJ qui flottent / reculent | la soudure de la chaise est **tournée** | `CFrame.new(…) * C0` (à gauche) pour descendre dans le repère de la chaise |
| Étiquettes énormes | taille en pixels | taille en **studs** : elle rapetisse de loin |
| Le bras ne visait pas le point | 25° d'écart | viser en 4 essais, chacun corrige l'erreur du précédent |

### 2026-10-05 (suite) — le sous-sol, la salle de sport, les simulateurs

| Ce que j'ai demandé | Ce qui a été fait |
|---|---|
| Une grande salle en bas des escaliers derrière le spawn, sans le trou à côté | `SalleSousSpawn.lua` creuse le demi-rond **et** les deux bâtiments (une seule salle de ~370 studs) ; les 2 puits de 96 studs bouchés |
| Les côtés qui dépassent, mal coupés, le petit trou, la ligne bleue | mur rond d'un seul tenant, coupé au mur des bâtiments (tournés de 0,6°) ; coins bouchés ; ligne néon posée au sol au pied de tous les murs |
| Sol noir (comme la rampe du garage), murs blancs, lumière classique sans ombres | sol en *Plastic* noir ; plafonniers ronds, lumière à mi-hauteur, aucune ombre |
| L'entrée devant l'escalier, puis un garage devant la piste, en très grand | portes en face des marches ; 2 portails de garage de 107 × 39 avec rampe |
| Lumière du spawn trop forte | lumière du jeu remise comme avant ; `LumiereSpawn` baisse l'exposition **seulement** sur le spawn |
| Salle de sport utilisable + simulateur « comme dans les films » | tapis qui poussent, banc, sacs qu'on frappe (E), vélos ; simulateurs = **bornes d'arcade 3D** : on reste assis, on joue sur l'écran |

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Suppression « des petits murs » | un vrai morceau de mur effacé → fente | filtrer par nom, pas par taille |
| Rayon qui part DANS une pièce | carte des hauteurs fausse | coupes horizontales avec `GetPartBoundsInBox` |
| `CorrugatedSteel`, `PlayerModule` | n'existent pas ici | vérifier avant d'utiliser |
| Appuyer sur Z à la borne | le personnage se levait | `ContextActionService` « avale » les touches pendant la partie |
| Siège penché et baquet solide | le joueur était éjecté | siège à plat, décor traversable |
| Caméra à 4,4 studs de l'écran | elle était dans le volant | 2,8 studs, angle calculé |

⚠️ Les réverbères et les PNJ sont **construits au lancement du Play** : on ne
les voit pas dans l'éditeur, c'est normal.

### 2026-10-06 — les simulateurs, abandonnés

| Ce que j'ai demandé | Ce qui a été fait |
|---|---|
| « le simulateur, l'écran est bleu » | on a cherché : le bleu, c'est le « ciel » du ViewportFrame ; le chrono et les km/h s'affichent, mais pas la 3D |
| « c'est bon, abandonne, ça marche pas, supprime » → les simulateurs entiers | les 2 machines (162 pièces) supprimées de la salle de sport ; `Arcade.client.lua` et `MachineSimulateur.lua` supprimés ; la partie « simulateurs » enlevée de `SalleSportServeur` et de `SalleSport.lua` |

Ce que les tests ont montré (sans trouver la cause) : un écran avec un cube
seul marche ; chaque dossier du circuit tout seul marche ; 208 morceaux sur un
petit panneau marchent… mais les mêmes 208 sur l'écran de la borne restent
bleus. Restent dans la salle : la moquette et le panneau « SIMULATEURS DE
COURSE ».

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Écran de test laissé en place | pendant le Play, mon écran de test (bleu) était posé par-dessus celui du jeu | enlever ses tests avant de faire essayer |

---

## Points à revoir / difficultés

- Le **lacet** dans la montée fait 43 studs de rayon : c'est serré. À vérifier
  en roulant — si ça ne passe pas, écarter les points 12, 13 et 14.
- Le **tremplin** demande 47 studs/s. Si la voiture ne va pas assez vite, il
  faut rallonger la réception (voir `DOCUMENTATION.md`, section 4).
