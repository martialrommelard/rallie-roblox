# Documentation technique — le générateur de circuit

Ce document explique **comment le circuit est fabriqué** et **pourquoi ces
choix-là**. C'est la partie technique du projet : si on me demande « comment
ça marche ? », tout est ici.

---

## 1. Le principe : le circuit est calculé, pas dessiné

Un circuit de rally construit à la main, c'est environ **200 blocs** à poser,
tourner et aligner un par un. Compter 4 heures. Et si on veut déplacer un
virage, il faut tout recommencer.

J'ai choisi l'inverse : le circuit est décrit par **33 points de contrôle**, et
un script calcule le reste.

```
33 points de contrôle
        ↓  (spline de Catmull-Rom)
   187 points lissés
        ↓
187 morceaux de route + 342 barrières + talus + rochers + arbres
```

Changer un nombre dans la liste, relancer le script : nouveau tracé en 2
secondes. C'est ce qui m'a permis d'essayer **7 tracés différents** avant de
garder celui-là.

### Un point de contrôle

```lua
{ -455, 150, 54, 50, "tremplin" }
--  x     z   h   l     type
```

| Champ | Rôle |
|---|---|
| `x`, `z` | position sur la carte, vue du dessus |
| `h` | hauteur : 0 dans la vallée, 70 au sommet |
| `l` | largeur de la route : 40 = virage serré, 80 = zone de dépassement |
| `type` | `"tunnel"` ou `"tremplin"` (facultatif) |

**La règle de conception la plus importante :** ce n'est pas le lissage qui
crée la variété d'un circuit, c'est **l'espacement des points**.

- Points **serrés** → virage lent et serré
- Points **écartés** → courbe rapide

Mon premier tracé avait des points régulièrement espacés : tous les virages
avaient le même rayon, le circuit était ennuyeux à piloter.

---

## 2. Pourquoi une spline de Catmull-Rom *centripète*

Relier 33 points par des segments droits donnerait un circuit anguleux. Il faut
une **courbe** qui passe par ces points. J'ai essayé trois méthodes.

### Essai 1 — l'algorithme de Chaikin ❌

Chaikin coupe les angles : à chaque passage, il remplace chaque segment par ses
points à 25 % et 75 %. C'est simple et très lisse.

**Problème :** il ne passe **pas** par les points de contrôle, il les rabote.
Mes virages lents et mes esses étaient gommés — je retrouvais deux grands
ovales. Tout le travail de tracé disparaissait.

### Essai 2 — Catmull-Rom classique ❌

Catmull-Rom passe **exactement** par chaque point de contrôle : la forme
dessinée est respectée.

**Problème :** quand les points sont irrégulièrement espacés — ce qui est
justement le cas, puisque c'est comme ça que je crée la variété — la courbe
**boucle sur elle-même**. Mon diagnostic a détecté un virage de **7 studs de
rayon** : la route faisait un nœud.

### Essai 3 — Catmull-Rom centripète ✅

C'est une variante qui répartit le paramètre de la courbe selon la **racine
carrée** de la distance entre les points (l'exposant `alpha = 0.5` dans le
code).

On démontre mathématiquement qu'avec `alpha = 0.5` la courbe ne peut **jamais**
faire de boucle ni de point de rebroussement. C'est exactement la garantie qu'il
me fallait.

```lua
local t1 = t0 + distance(p0, p1) ^ 0.5   -- <- le 0.5, c'est tout le secret
```

---

## 3. Le diagnostic automatique

À la fin, le script **mesure son propre travail** et affiche :

```
CIRCUIT COMPLET | 187 routes, 342 barrieres | tour 3076 studs (~43 s)
pente max 21.9% | rayon mini 43 | sommet 59 studs
TREMPLIN : trou 30, chute 35, vitesse mini 47 studs/s
Controles : 16 ouvertures, 3 rochers repousses, 0 talus orphelins
```

C'est la partie dont je suis le plus content, parce que **c'est elle qui a
trouvé les bugs**, pas moi à l'œil :

| Mesure | À quoi elle sert |
|---|---|
| Longueur du tour | vérifier que le tour dure ~40 s et pas 2 minutes |
| Pente maximale | au-dessus de 10 % en montée, une voiture n'arrive plus à grimper |
| **Rayon du virage le plus serré** | en dessous de ~40 studs, le virage est physiquement infranchissable |
| Vitesse minimale du saut | vérifier que le tremplin est franchissable |

Le rayon minimum est calculé entre trois points consécutifs :

```lua
local angle = math.acos(produit_scalaire(v1, v2))
local rayon = longueur / angle      -- angle petit -> grand rayon -> virage rapide
```

C'est ce calcul qui m'a signalé les rayons de **7**, puis **21**, puis **33**
studs — trois virages impossibles que je n'aurais jamais repérés sur une vue de
dessus.

---

## 4. Le tremplin : un calcul de physique

Pour qu'une voiture **décolle**, il ne suffit pas d'une bosse. La condition
physique est :

```
v² / rayon  >  gravité
```

Avec la gravité de Roblox (**196 studs/s²**) et une voiture à 80 studs/s :

```
rayon < v² / g = 6400 / 196 = 33 studs
```

Le rayon de la crête doit donc être **inférieur à 33 studs**. Or ma spline
lisse tout à environ 150 studs de rayon : **une simple bosse ne décollera
jamais**. Il faut une vraie rampe rigide et un vrai trou.

### Dimensionner le trou

Une fois en l'air, la voiture suit une trajectoire de chute libre. En partant
d'une rampe inclinée de 15° :

```
vx = v · cos(15°)        vy = v · sin(15°)
t  = ( vy + √(vy² + 2·g·chute) ) / g
portée = vx · t
```

Le script résout cette équation pour trouver la **vitesse minimale** :

| Vitesse | Distance parcourue en l'air |
|---|---|
| 35 studs/s | 19 studs ❌ |
| 47 studs/s | 30 studs ✅ (tout juste) |
| 70 studs/s | 48 studs ✅ |
| 100 studs/s | 73 studs ✅ |

Réglage retenu : **trou de 30 studs, chute de 35 studs → il faut 47 studs/s**.
Il faut être lancé, mais ce n'est pas injouable.

---

## 5. Les cinq bugs rencontrés (et ce qu'ils m'ont appris)

### Le Z-fighting — des trous fantômes dans la route

Les morceaux de route se chevauchent de 40 % (sinon il reste des trous en
triangle dans les virages). Mais leurs surfaces étaient **exactement à la même
hauteur**. La carte graphique ne sait alors pas laquelle afficher devant : elle
clignote entre les deux. En roulant, ça donne l'impression de trous dans le
bitume.

**Correction :** une route sur deux est descendue de **0,04 stud**.

```lua
local cf = cfBrut * CFrame.new(0, ((i % 2 == 0) and 0 or -0.04), 0)
```

Invisible pour le joueur, et le clignotement disparaît.

### Les barrières trouées dans les virages

Je posais chaque barrière à côté de son morceau de route, avec la **même
longueur**. Mais à l'extérieur d'un virage, le bord est **plus long** que l'axe
de la route : il restait donc un écart entre chaque barrière.

**Correction :** les barrières forment une **chaîne** — chaque barrière relie
le bord d'une route au bord de la suivante. Plus aucun trou possible, et plus
aucun bout qui dépasse dans le vide.

### Le tunnel bouché

Mon bloc « montagne » faisait `largeur + 130` et était centré **sur la route** :
j'avais rempli le tunnel de roche massive. Impossible de passer.

**Correction :** les rochers sont décalés sur les côtés.

### Le rocher qui dépasse malgré tout

J'écartais le rocher **puis** je le faisais pivoter de ±25°. En tournant, son
coin revenait sur la route.

**Correction :** calculer la demi-largeur **réelle après rotation** :

```lua
local demi = (w/2)*cos(angle) + (profondeur/2)*sin(angle)
```

Plus une **vérification automatique** : le script teste chaque morceau de route
et pousse dehors tout rocher qui empiète encore.

### La rampe qui écrase la voiture

J'avais posé la rampe avec un angle **relatif à la route**. Mais à cet endroit
la route monte : les deux pentes s'additionnaient, et l'arrière de la rampe se
retrouvait **3,7 studs au-dessus du bitume**. La voiture tapait dans une marche.

**Correction :** angle **absolu** par rapport à l'horizontale, rampe construite
depuis le bord réel de la route et **enterrée de 14 studs** sous le bitume.
Vérification : marche mesurée = **0,00 stud**.

---

## 6. La leçon générale

Les cinq bugs ont la même forme : **je vérifiais à l'œil sur une vue de dessus,
alors que le défaut était dans les chiffres.**

Un virage de 21 studs de rayon est parfaitement joli vu d'en haut. Il est
simplement impossible à prendre en voiture.

C'est pour ça que la moitié du script sert à **mesurer et à se vérifier
lui-même**, et pas seulement à construire.

---

## 7. Modifier le circuit

1. Ouvrir `scripts/GenerateurCircuit.lua`
2. Modifier la liste `POINTS`
3. Tout sélectionner, copier
4. Dans Studio : menu **View → Command Bar**, coller, `Entrée`
5. Lire le diagnostic affiché

### Les garde-fous à respecter

| Mesure | Limite | Sinon |
|---|---|---|
| Rayon d'un virage | **> 40 studs** | infranchissable en voiture |
| Pente en montée | **< 10 %** | la voiture n'arrive plus à grimper |
| Largeur de route | **> 40 studs** | on ne peut plus se doubler |
| Dégagement sous le tunnel | **> 15 studs** | la voiture accroche le plafond |

### Les réglages en haut du fichier

```lua
local EPAISSEUR, PAS, ECHELLE = 2, 18, 0.85
```

- `PAS` : longueur d'un morceau de route. Plus petit = plus lisse, mais plus de
  blocs (donc le jeu rame).
- `ECHELLE` : agrandit ou réduit tout le circuit d'un coup. `0.85` actuellement.

---

## 8. La zone de départ : ligne, portique, grille

### Le problème de départ

La ligne d'arrivée existait dans le générateur mais **avait disparu du jeu**.
En la refaisant, j'ai compris qu'elle était fausse depuis le début :

```lua
-- AVANT : la position est écrite en dur
ligne.CFrame = CFrame.lookAt(Vector3.new(-230*ECHELLE, 1.3, 486*ECHELLE),
                             Vector3.new(0, 1.3, 480*ECHELLE))
```

Le circuit est **calculé** par la spline. Écrire `-230 ; 486` à la main, c'est
deviner où la spline est passée. Résultat mesuré : la ligne dépassait de
**6 studs** d'un côté du bitume et laissait un trou de l'autre.

```lua
-- APRÈS : on DEMANDE sa position à la route
local SEG_DEPART = 8
local rDep  = segments[SEG_DEPART].p
local largD = rDep.Size.X               -- la largeur exacte, à cet endroit
ligne.CFrame = rDep.CFrame * CFrame.new(0, dessD + 5, 0)
```

C'est le même piège que la rampe du tremplin (section 5). **Dans un circuit
généré, on ne devine jamais une position : on la demande.**

### La ligne est en DEUX morceaux

| Objet | Visible ? | Rôle |
|---|---|---|
| `LigneDepart` | non (`Transparency = 1`) | la zone que le chrono va lire |
| `Damier` | oui, 36 cases | ce que le joueur voit |

Séparer les deux évite un piège : une belle ligne en damier faite de 36 Parts
serait pénible à tester (« quelle case a été touchée ? »), alors qu'une seule
Part invisible se teste en une ligne de code.

### Peindre sur la route sans faire de marche

```lua
local EP_CASE = 0.5
local yCase   = dessD + 0.02 - EP_CASE/2
```

La case fait 0,5 stud d'épaisseur mais elle est **enterrée** : seuls 0,02 stud
dépassent du bitume. Deux effets :

- `CanCollide = false` + affleurement = **aucune bosse** sous les roues ;
- le décalage de 0,02 évite le **z-fighting** (section 5) : à hauteur
  exactement égale, les deux surfaces clignotent.

### Orienter les ampoules

Les voitures roulent vers le **-Z local** de la route, donc elles arrivent du
côté **+Z**. Les feux doivent regarder vers +Z.

Un `Part` en `Shape = Cylinder` présente ses faces rondes sur son axe **X**.
Sans rotation, le pilote verrait la tranche :

```lua
amp.CFrame = panneau.CFrame * CFrame.new(dx, dy, 1.4)
                            * CFrame.Angles(0, math.rad(-90), 0)
```

Une rotation de -90° autour de Y envoie l'axe X local sur le +Z local.

### Le panneau se déduit, il ne se dessine pas

```lua
local NB_COL, NB_RANGS, DIAM = 4, 3, 6.5
local LARG_PAN = NB_COL * (DIAM + 3.5)
local PAS_F    = LARG_PAN / NB_COL
local dx       = -LARG_PAN/2 + PAS_F/2 + (i - 1) * PAS_F
```

J'ai essayé 5 colonnes, puis 3, puis 4. À chaque fois **un seul chiffre
à changer** : le panneau se redimensionne et les ampoules se répartissent
toutes seules. À la main, chaque essai aurait demandé de repositionner 12 à 15
pièces une par une.

C'est le même principe que le circuit lui-même, appliqué à un petit objet.

### La grille : remonter la piste, pas prolonger une droite

Pour poser 6 emplacements derrière la ligne, le réflexe serait :

```lua
-- NAÏF : on recule le long de Route8
base = rDep.CFrame * CFrame.new(x, y, recul)
```

Ça marche ici parce que le départ est sur une ligne droite. Mais si la ligne se
retrouvait un jour dans un virage, les emplacements partiraient **tout droit
dans l'herbe**. Le générateur remonte donc la piste segment par segment en
comptant les studs parcourus :

```lua
local ordre, dist, k = {}, 0, SEG_DEPART
while garde < 60 do
    local r = segments[k].p
    table.insert(ordre, {p = r, d = dist})     -- ce segment est à "dist" en arrière
    if dist > 200 then break end
    local kp = k - 1; if kp < 1 then kp = #segments end
    dist += (r.Position - segments[kp].p.Position).Magnitude
    k = kp
end
```

Ensuite `surLaPiste(recul)` rend le segment qui se trouve à cette distance,
et le reste à parcourir dessus. La grille **suit la courbe** de la piste.

### Vérifier son travail par le calcul

Le générateur vérifie déjà ses talus et ses rochers. Même méthode pour la
grille : on tire un rayon **vers le bas** depuis chaque trait, en ne gardant
que le dossier `Route` comme cible.

```lua
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = {circuit.Route}
if not WS:Raycast(p.Position + Vector3.new(0,4,0), Vector3.new(0,-12,0), rp) then
    horsPiste += 1
end
```

Résultat : **0 trait sur 18 hors du bitume**. C'est plus rapide et plus sûr que
de tourner autour à la caméra.

### Le compte à rebours se lit en LIGNES, pas en colonnes

Les ampoules s'appellent `Ampoule1`, `Ampoule2`, `Ampoule3` **dans chaque
colonne** : le numéro, c'est la **ligne** (1 = en haut). Du coup une ligne
entière s'allume d'un coup, quelle que soit la colonne :

```lua
local function ligne(n)
    local t = {}
    for _, colonne in ipairs(feux:GetChildren()) do
        if colonne:IsA("Model") then
            local a = colonne:FindFirstChild("Ampoule" .. n)
            if a then table.insert(t, a) end
        end
    end
    return t
end
```

La séquence tient alors en une boucle, **sans éteindre la ligne précédente** :

```lua
for n = 1, 3 do
    peindre(ligne(n), ROUGE, true)
    task.wait(1)
end
peindre(tout, VERT, true)     -- DEPART
```

| Temps | Ce qu'on voit |
|---|---|
| 0 s | ligne 1 rouge |
| 1 s | lignes 1 **et** 2 rouges |
| 2 s | les 3 lignes rouges |
| 3 s | **tout vert → départ** |

### Pourquoi changer la matière et pas seulement la couleur

Une ampoule rouge vif en `SmoothPlastic` reste **terne** : elle est éclairée
par le soleil comme n'importe quelle Part. C'est la matière `Neon` qui donne
l'effet « allumé », parce qu'elle émet sa propre lumière.

```lua
a.Color = couleur
a.Material = allumee and Enum.Material.Neon or Enum.Material.SmoothPlastic
lumiere.Enabled = allumee          -- le PointLight éclaire le portique autour
```

Trois choses changent ensemble : la **couleur**, la **matière**, et le
**PointLight**. Oublier la matière, c'est le piège classique.
