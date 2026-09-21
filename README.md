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

## Les fichiers

| Fichier | À quoi ça sert |
|---|---|
| [`PROJET-RALLY.md`](PROJET-RALLY.md) | Cahier des charges et feuille de route du trimestre |
| [`DOCUMENTATION.md`](DOCUMENTATION.md) | **Comment le générateur marche**, les maths, les bugs rencontrés |
| [`PRESENTATION.md`](PRESENTATION.md) | Plan de la présentation orale + réponses aux questions |
| [`PROGRESSION.md`](PROGRESSION.md) | Où j'en suis, notions de code déjà vues, journal |
| [`scripts/GenerateurCircuit.lua`](scripts/GenerateurCircuit.lua) | Le générateur de circuit |
| `lecons/` | Une fiche par étape |

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

- [ ] Le **compte à rebours** : allumer `Feu1`…`Feu4`, tout éteindre → départ
- [ ] Le **chronomètre** (`Circuit/LigneDepart` existe déjà et l'attend)
- [ ] Les **checkpoints** anti-triche
- [ ] Le temps affiché à l'écran
- [ ] Le classement et le podium
- [ ] Les écuries : choisir sa voiture au garage
- [ ] Les gradins et l'ambiance
