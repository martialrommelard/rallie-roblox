# Étape 1 — Construire le circuit (en 8, avec pont et vrais virages)

## Le but

Une piste FERMÉE en forme de 8, assez large pour se dépasser, avec des virages
variés et un croisement à deux niveaux : à chaque tour on passe UNE FOIS sur le
pont et UNE FOIS dessous.
Pas encore de voiture, pas encore de code. Juste la piste.

## Le tracé

      ╔══════ LIGNE DROITE / DÉPART (400) ══════╗
      ║                                         ║
   ╭──╯                                    ⟳    ╰──╮
   │   courbe rapide                    ÉPINGLE    │   BOUCLE A
   ╰──╮                                         ╭──╯   « la rapide »
       ╲                                       ╱
        ╲  rampe ↗    ═══ PONT ═══    ↘ rampe ╱
         ╳ ─────────── au sol, passe dessous
        ╱                                     ╲
   ╭───╯                                       ╰──╮
   │  ∿∿∿ LES ESSES              CHICANE ⌐|_      │   BOUCLE B
   ╰──────────────────────────────────────────────╯   « la technique »

Un tour = ligne droite → épingle → courbe rapide → PONT → esses → chicane
→ passage SOUS le pont → retour à la ligne droite.

Dans un 8, la route se croise elle-même une seule fois : c'est ce qui donne le
pont "gratuitement", sans tracé compliqué.

## Le principe de conception : ALTERNER

Un circuit tout en virages = ennuyeux. Tout en lignes droites = ennuyeux.
Rapide, lent, rapide, lent.

**Où se font les dépassements :** jamais dans un virage. Un dépassement se fait
AU FREINAGE, c'est-à-dire sur une longue ligne droite suivie d'un virage LENT.
Il faut donc au moins deux endroits construits comme ça dans le circuit :
ici la ligne droite → épingle, et la sortie du pont → chicane.

## La largeur

| | Largeur |
|---|---|
| Une voiture Roblox | ~12 studs |
| **La route partout** | **48 studs** = 4 voitures côte à côte |
| **Zones de dépassement** | **80 studs**, sur les 150 studs avant un virage lent |

## Les recettes de virages

Un virage = plusieurs Parts tournées les unes après les autres.
Le nombre de degrés entre deux Parts décide si le virage est serré ou large.

| Virage | Longueur de chaque Part | Rotation à chaque fois | Nb de Parts |
|---|---|---|---|
| Épingle (demi-tour, 180°) | 40 | +30° | 6 |
| Virage serré (90°) | 40 | +30° | 3 |
| Virage moyen (90°) | 40 | +15° | 6 |
| Courbe rapide | 80 | +10° | 6 |
| Chicane | 40 | +25° puis -25° | 4 |

⚠️ Jamais plus serré que +30° par Part : la voiture ne pourra pas passer.

Astuce : onglet **Model** → régler le **Rotate snap sur 15°**. Ensuite c'est
`Ctrl+D`, tourner, poser. Faire GÉNÉREUSEMENT chevaucher les Parts dans les
virages, sinon il reste des trous en triangle sur l'extérieur. Si ça clignote
à l'endroit du chevauchement, descendre une des deux Parts de 0.05.

## Les dimensions

| Élément | Valeur |
|---|---|
| Sol (Baseplate) | `Size` = 2048, 20, 2048 |
| Largeur de route | **48 studs** (80 dans les zones de dépassement) |
| Épaisseur de route | 2 studs |
| Taille d'une boucle | environ 400 x 300 studs |
| Longueur d'une diagonale | au moins 450 studs |
| Hauteur de la route du pont | **Y = 20** |
| Longueur d'une rampe | **160 studs**, inclinée à **7°** |
| Longueur du tablier du pont | environ 130 studs, bien plat |

Tour complet : environ 2000 studs, soit ~30 secondes en voiture.

## Les 2 chiffres du pont

**Le dégagement.** Une voiture Roblox fait ~5 studs de haut. Route du pont à
Y = 20 → il reste ~18 studs de vide dessous. Confortable. Trop juste, la
voiture accroche le tablier et explose.

**La pente.** Environ 1 de hauteur pour 8 de longueur. Monter 20 studs → rampe
de 160 studs de long inclinée à 7°. Trop raide : la voiture décolle en haut ou
n'arrive pas à monter.

Une rampe = UNE SEULE Part :
- `Size` = `48, 2, 160`
- `Anchored` coché
- dans `Orientation`, mettre **7** (ou **-7**) sur l'axe qui la fait basculer
  vers le haut — essayer X puis Z selon le sens de la route

⚠️ PAS dix petites Parts bout à bout pour une rampe. Chaque raccord fait une
micro-marche, et une micro-marche à pleine vitesse envoie la voiture en l'air.

## L'ordre de construction

1. Agrandir la Baseplate
2. La boucle A (ligne droite + épingle + courbe rapide), à plat, au sol
3. La boucle B (esses + chicane), à plat, au sol
4. La diagonale qui RESTE AU SOL : la traverser complètement d'un bout à l'autre
5. Seulement après : la diagonale du pont, dans l'ordre rampe → tablier → rampe,
   posée par-dessus celle du sol
6. Élargir à 80 les zones de dépassement
7. Les barrières partout, et surtout sur le pont (20 studs de chute)
8. La `LigneDepart` : une Part blanche fine en travers de la ligne droite,
   nommée EXACTEMENT comme ça. Elle servira au chrono à l'étape 3.

Tester à pied (bouton Play) après CHAQUE point de la liste.

## Les règles qui restent valables

1. **Large** : 48 studs. Une route étroite est injouable en voiture.
2. **Ancré** : `Anchored` coché sur chaque Part, sinon tout tombe au Play.
3. **Rangé** : tout dans un Folder `Circuit` dans le Workspace.
   Sous-dossiers : `BoucleA`, `BoucleB`, `Pont`, `Barrieres`.
4. **Fermé** : on doit pouvoir tourner en boucle sans fin.
5. **Des Parts, pas du Terrain.** Le Terrain est lourd et dur à corriger.

## Astuces

- `Ctrl + D` duplique la Part sélectionnée
- Maintenir `Alt` en déplaçant : la Part se colle sur la surface d'en face
- Si une rampe fait une bosse au raccord : la descendre très légèrement pour
  qu'elle s'enfonce un peu dans la route plate plutôt que de dépasser

## Comment je sais que c'est fini

Je clique sur Play, je fais un tour complet du 8 à pied, je passe sur le pont
puis dessous, et je reviens à mon point de départ sans jamais tomber.
