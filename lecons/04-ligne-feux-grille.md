# Étape 3 — La ligne de départ, le portique et la grille

*Séance du 2026-09-21. La séance où j'ai compris pourquoi il ne faut jamais
écrire une position en dur.*

## Ce qu'on a fait, dans l'ordre

1. Constaté que **la ligne de départ avait disparu** du jeu
2. Découvert qu'elle était **fausse depuis le début** (position écrite en dur)
3. Refait la ligne en la calant sur la route + un **damier enterré**
4. Construit un **portique** avec 12 feux éteints
5. Tracé une **grille de départ** de 6 emplacements
6. Vérifié le tout **par le calcul**, pas à l'œil

---

## 1. Une ligne qui existait dans le code mais pas dans le jeu

Premier constat de la séance : le dossier `Circuit` ne contenait pas de
`LigneDepart`, alors que `GenerateurCircuit.lua` la crée bien.

> **La leçon :** un fichier juste ne suffit pas. Tant qu'on ne l'a pas
> **exécuté**, on ne sait pas ce qu'il y a vraiment dans le jeu.

C'est exactement le risque qu'on s'était noté la fois d'avant avec la montagne.

## 2. Pourquoi la ligne était fausse

```lua
-- L'ANCIENNE VERSION
ligne.CFrame = CFrame.lookAt(Vector3.new(-230*ECHELLE, 1.3, 486*ECHELLE), ...)
```

`-230` et `486`, c'est **moi qui devine** où passe la piste. Sauf que la piste,
elle, est **calculée** par la spline. J'ai mesuré : la ligne dépassait de
**6 studs** d'un côté et laissait un trou de l'autre.

```lua
-- LA NOUVELLE VERSION : on demande à la route
local rDep  = segments[8].p          -- le 8e morceau de route
local largD = rDep.Size.X            -- sa largeur exacte
ligne.CFrame = rDep.CFrame * CFrame.new(0, dessD + 5, 0)
```

> **La règle :** dans un circuit *calculé*, on ne devine jamais une position.
> **On la demande à la route.**

C'est le troisième objet qui tombe dans ce piège après la rampe du tremplin et
les rochers. À force, ça finit par rentrer.

## 3. Le CFrame relatif : la notion clé de la séance

```lua
rDep.CFrame * CFrame.new(x, y, z)
```

Ça veut dire : « pars du repère de la route, puis avance de `x` sur **sa**
droite, `y` vers **son** haut, `z` vers **son** arrière ».

Du coup **tout suit la route automatiquement**. Si le circuit tourne, la ligne
tourne avec, le portique aussi, la grille aussi. Je n'ai jamais eu à calculer
un angle.

## 4. Peindre sur la route sans faire de bosse

Le damier est fait de 36 cases de 5 × 5 studs. Mais elles ne sont pas
**posées** sur la route, elles sont **enterrées dedans** :

```lua
local EP_CASE = 0.5                        -- la case fait 0,5 d'épaisseur
local yCase   = dessD + 0.02 - EP_CASE/2   -- mais seuls 0,02 dépassent
```

Pourquoi 0,02 et pas 0 ? Parce qu'à hauteur **exactement** égale, les deux
surfaces clignotent : c'est le **z-fighting**, le même bug que sur la route au
début du projet.

## 5. Orienter un cylindre

Les ampoules sont des Parts en `Shape = Cylinder`. Un cylindre présente ses
faces rondes sur son **axe X**. Sans rien faire, le pilote voit la **tranche**.

```lua
* CFrame.Angles(0, math.rad(-90), 0)
```

Cette rotation envoie l'axe X local sur le +Z local, c'est-à-dire vers les
voitures qui arrivent.

## 6. Un seul chiffre pour tout changer

C'est le moment le plus parlant de la séance. J'ai essayé le panneau avec
5 colonnes, puis 3, puis 4. À chaque fois, **un seul chiffre change** :

```lua
local NB_COL = 4              -- <<< ici
local LARG_PAN = NB_COL * (DIAM + 3.5)     -- la largeur se DÉDUIT
local PAS_F    = LARG_PAN / NB_COL         -- l'espacement aussi
```

Le panneau se redimensionne, les ampoules se répartissent. Si j'avais posé les
12 ampoules à la main, chaque essai m'aurait pris dix minutes.

C'est la même idée que le circuit entier, appliquée à un petit objet.

## 7. La grille : suivre la piste, pas une droite

Pour reculer de 107 studs derrière la ligne, le réflexe serait de prolonger
`Route8`. Ça marcherait **ici**, parce que le départ est sur une ligne droite.
Mais si la ligne se retrouvait dans un virage, les emplacements partiraient
dans l'herbe.

Donc on **remonte la piste segment par segment** en comptant les studs :

```lua
dist += (r.Position - segments[kp].p.Position).Magnitude
```

## 8. Vérifier par le calcul, pas à l'œil

À la fin, un rayon tiré **vers le bas** depuis chaque trait de grille, en ne
visant que le dossier `Route` :

```lua
if not WS:Raycast(p.Position + Vector3.new(0,4,0), Vector3.new(0,-12,0), rp) then
    horsPiste += 1
end
```

Résultat : **0 trait sur 18 hors du bitume**. Plus rapide et plus sûr que de
tourner autour à la caméra — d'autant que les captures d'écran partaient en
vrille dès que je bougeais dans le viewport.

---

## Le tableau des erreurs de la séance

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| Position de la ligne écrite en dur | elle dépassait de 6 studs | on **demande** sa position à la route |
| Peinture à la même hauteur que le bitume | ça clignote | toujours décaler, même de 0,02 stud |
| Cylindre non tourné | on voit la tranche | les faces rondes sont sur l'axe **X** |
| Grille posée en prolongeant une droite | partirait dans l'herbe dans un virage | remonter la piste **segment par segment** |
| `NB_RANGS` déclaré deux fois | Lua l'accepte en silence | renommer : sinon on lit une valeur en croyant en lire une autre |
| « la voiture est ancrée » | fausse alerte | **A-Chassis désancre tout seul** au lancement |

---

## La prochaine fois

Les 12 ampoules ont déjà leur `PointLight` avec `Enabled = false`, et les
colonnes s'appellent `Feu1` à `Feu4`. Donc le compte à rebours, c'est :

```lua
for i = 1, 4 do
    allumer("Feu" .. i)
    task.wait(1)
end
eteindreTout()          -- GO : le chrono démarre ICI
```

Et le chrono suivra **le joueur**, pas la voiture : comme on est assis dans le
siège, le personnage se déplace avec elle. Ça marche donc avec n'importe
quelle voiture.
