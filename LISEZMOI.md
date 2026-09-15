# Jeu de rally sur Roblox — projet de trimestre

Projet de « classe numérique » (élève de seconde).
Un jeu de course de rally sur Roblox : circuit de montagne, chronomètre,
records et podium, jouable à plusieurs.

## Ce que contient ce dépôt

| Fichier | À quoi ça sert |
|---|---|
| `PROJET-RALLY.md` | Le cahier des charges et la feuille de route du trimestre |
| `PROGRESSION.md` | Où j'en suis + les notions de code déjà vues |
| `lecons/` | Une fiche par étape |
| `scripts/GenerateurCircuit.lua` | **Le générateur du circuit** |

## Le générateur de circuit

Le circuit n'est pas construit à la main, Part par Part : il est **généré par
un script** à partir d'une liste de points de contrôle.

Pour modifier le tracé : ouvrir `scripts/GenerateurCircuit.lua`, changer la
liste `POINTS`, puis coller le script dans la barre de commande de Roblox
Studio (menu View > Command Bar). Le circuit est reconstruit en quelques
secondes.

Chaque point s'écrit `{ x, z, hauteur, largeur, type }` :
- `x`, `z` : la position sur la carte, vue du dessus
- `hauteur` : 0 en bas de la vallée, 70 au sommet de la montagne
- `largeur` : 40 pour un virage serré, 80 pour une zone de dépassement
- `type` : `"tunnel"` ou `"tremplin"` (facultatif)

Règle à retenir : **des points serrés donnent un virage lent, des points
écartés donnent une courbe rapide.**

Le script affiche un diagnostic à la fin : longueur du tour, pente maximale,
rayon du virage le plus serré, et la vitesse minimale pour franchir le saut.
