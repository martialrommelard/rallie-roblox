# Jeu de rally sur Roblox — projet de trimestre

Projet de « classe numérique » (élève de seconde).
Un jeu de course de rally sur Roblox : **circuit de montagne avec tunnel et
tremplin**, chronomètre, records et podium, jouable à plusieurs.

> **L'idée du projet en une phrase : je n'ai pas dessiné le circuit, je l'ai
> programmé.**
> Le tracé est décrit par 33 points de contrôle ; un script en déduit 187
> morceaux de route, 342 barrières, les talus, les rochers et les arbres.

## Le circuit actuel

| | |
|---|---|
| Longueur du tour | 3083 studs (~44 secondes) |
| Dénivelé | 59 studs entre la vallée et le sommet |
| Virage le plus serré | 43 studs de rayon |
| Pente maximale | 21,9 % (la réception du tremplin) |
| Tremplin | trou de 30 studs, il faut rouler à 47 studs/s |

Un tour : **grande ligne droite → épingle → montée → lacet → tunnel dans la
montagne → descente → tremplin → dernier virage**.

## La zone de départ

Elle n'est posée nulle part « à la main » : tout se place **par rapport au 8e
morceau de route**, donc si le tracé change, la ligne, le portique et la grille
suivent.

| Objet | Ce que c'est |
|---|---|
| `Circuit/Damier` | 36 cases enterrées dans le bitume (0,02 stud dépasse) |
| `Circuit/LigneDepart` | une Part invisible — **c'est elle que le chrono lira** |
| `Circuit/FeuxDepart` | portique à 58 studs, 4 colonnes de 3 feux, éteints |
| `Circuit/Grille` | 6 emplacements en quinconce, tracé sobre |

Changer `NB_COL` change le nombre de colonnes de feux **et** la largeur du
panneau **et** l'espacement des ampoules : rien n'est écrit en dur.
Changer `H_MAT` monte ou descend tout le portique.

## La course

Une course complète se joue du début à la fin :

```
un joueur s'assoit
   ├─ une cage invisible se referme autour de chaque voiture
   ├─ 5 s, puis bip + rouge / bip + rouge / bip + rouge   →  3, 2, 1 à l'écran
   └─ BIIIIP + VERT  →  "GO", les cages disparaissent
        ↓
   3 tours comptés au passage de la ligne   →  panneau "TOUR n / 3"
        ↓
   "COURSE TERMINÉE", puis les voitures reviennent en grille
```

Tomber hors du circuit (sous **Y = −60**) tue le pilote et détruit sa voiture.

Les trois scripts serveur se coordonnent par **un seul attribut**,
`workspace:GetAttribute("CourseEnCours")` : il empêche de relancer un départ
en pleine course, et déclenche le retour des voitures quand il retombe à faux.

## Les fichiers

| Fichier | À quoi ça sert |
|---|---|
| [`PROJET-RALLY.md`](PROJET-RALLY.md) | Cahier des charges et feuille de route du trimestre |
| [`DOCUMENTATION.md`](DOCUMENTATION.md) | **Comment le générateur marche**, les maths, les bugs rencontrés |
| [`PRESENTATION.md`](PRESENTATION.md) | Plan de la présentation orale + réponses aux questions |
| [`PROGRESSION.md`](PROGRESSION.md) | Où j'en suis, notions de code déjà vues, journal |
| [`scripts/GenerateurCircuit.lua`](scripts/GenerateurCircuit.lua) | Le générateur de circuit |
| [`scripts/FeuxDepart.lua`](scripts/FeuxDepart.lua) | Bips, feux, cages, `3 2 1 GO` |
| [`scripts/CompteurTours.lua`](scripts/CompteurTours.lua) | Compte les tours, arrête la course à 3 |
| [`scripts/Voitures.lua`](scripts/Voitures.lua) | Pose la grille, gère les chutes, remet les voitures |
| [`scripts/EcranDepart.client.lua`](scripts/EcranDepart.client.lua) | **LocalScript** : l'affichage chez le joueur |
| `lecons/` | Une fiche par étape |

⚠️ Le générateur ne fabrique que le **décor**. Les sons, les cages, les
voitures et les interfaces vivent dans la place Roblox : ils ne se
reconstruisent pas tout seuls.

## Utiliser le générateur

1. Ouvrir `scripts/GenerateurCircuit.lua`, modifier la liste `POINTS`
2. Tout copier
3. Dans Roblox Studio : menu **View → Command Bar**, coller, `Entrée`

Le circuit est reconstruit en quelques secondes, et le script affiche un
diagnostic : longueur du tour, pente maximale, rayon du virage le plus serré,
et la vitesse minimale pour franchir le saut.

Chaque point s'écrit `{ x, z, hauteur, largeur, type }` :

| Champ | Rôle |
|---|---|
| `x`, `z` | position sur la carte, vue du dessus |
| `hauteur` | 0 dans la vallée, 70 au sommet de la montagne |
| `largeur` | 40 pour un virage serré, 80 pour une zone de dépassement |
| `type` | `"tunnel"` ou `"tremplin"` (facultatif) |

**La règle à retenir :** des points **serrés** donnent un virage lent, des
points **écartés** donnent une courbe rapide. C'est l'espacement qui fait la
variété du circuit, pas le lissage.

## Ce qui reste à faire

- [x] Le **compte à rebours** : 3 lignes rouges puis tout vert ✅
- [x] Le **son du départ** : 3 bips, puis un long biiiip ✅
- [x] Le `3 2 1 GO` **à l'écran** ✅
- [x] Les **cages** : impossible de partir avant le vert ✅
- [x] Le **compteur de tours**, la course s'arrête à 3 ✅
- [x] Les voitures **posées sur la grille**, détruites si elles tombent ✅
- [ ] Le **chronomètre** (le point de branchement est prêt : `print("DEPART !")`)
- [ ] Les **checkpoints** anti-triche (on peut encore couper le circuit)
- [ ] Le temps affiché à l'écran, sous le compteur de tours
- [ ] Le classement et le podium
- [ ] Un bouton « abandonner » (sinon une course jamais finie bloque tout)
- [ ] Les écuries : choisir sa voiture au garage
- [ ] Les gradins et l'ambiance
