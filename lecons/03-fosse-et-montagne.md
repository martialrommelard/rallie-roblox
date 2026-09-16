# Étape 2 — La fosse à piques, la montagne et le podium

*Séance du 2026-09-16. C'est la séance où j'ai écrit mon premier script.*

## Ce qu'on a fait, dans l'ordre

1. Nettoyage du circuit (l'épingle était trop étroite)
2. Le sol avait disparu — on l'a recréé et calé sous la route
3. Le tremplin n'avait ni la bonne largeur ni le bon alignement
4. **La fosse à piques** sous le tremplin + **mon premier script Luau**
5. **Une vraie montagne** autour du tunnel, avec neige et éboulis
6. **Un podium** sur une terrasse taillée à mi-pente

---

## 1. Le circuit

### L'épingle était trop étroite

Je la trouvais serrée en la regardant. Les chiffres ont dit pourquoi :

| | |
|---|---|
| Largeur de l'épingle | 42 studs (le minimum du circuit) |
| Largeur juste avant | 80 studs |
| Rayon du virage | 64 studs |

Le rayon **le plus serré du circuit** (43 studs) n'est pas là : il est au
lacet. Ce qui me gênait à l'épingle, c'était donc la **largeur**, pas la
courbure — et surtout l'entonnoir 80 → 42.

Corrigé en passant les points 5 à 8 à **56–62**, soit `80 → 62 → 56 → 56 → 62`.

> **La leçon** : quand quelque chose « semble » faux, mesurer avant de corriger.
> J'aurais pu écarter les points de l'épingle pour rien.

### Le sol manquait

`Workspace > Baseplate` avait été supprimée par erreur. Le jeu n'avait
littéralement plus de sol : **0 voxel de terrain**, et un rayon lancé sous la
ligne de départ ne touchait rien.

En plus, l'ancien sol avait sa surface à **y = −14** alors que le dessous de la
route est à **y = −1,4** : la route **flottait de 12,6 studs** au-dessus de
l'herbe. Ça ne se voyait pas d'en haut.

Le générateur ne savait que *modifier* un sol existant. Il le **crée**
maintenant s'il manque.

### Le saut était de travers

| | Avant | Après |
|---|---|---|
| Largeur de la rampe | 49 | **71** (celle de la réception) |
| Décalage rampe / réception | 7,1 studs | **0,00** |
| Décalage rampe / route d'avant | 6,9 studs | **0,04** |

Ma première correction ne marchait pas : je déplaçais la rampe pour compenser,
donc je la désalignais de l'autre côté. La cause était ailleurs — **la spline
tournait pendant le vol**, parce que les points 22, 23 et 24 n'étaient pas
alignés (x = −450, −455, −448).

En redressant les points 21 à 25 sur x = −452, le décalage tombe à zéro **des
deux côtés à la fois**.

> **La leçon** : je traitais le symptôme. Le défaut n'était pas dans la rampe,
> il était dans le tracé.

---

## 2. Mon premier script Luau

### Le but

Si on rate le saut et qu'on tombe dans le trou, on meurt.

### Les notions

| Notion | La ligne, dans mon script |
|---|---|
| **variable** | `local piques = workspace.Circuit.Piques` |
| **fonction** | `local function dansLaZone(pos)` |
| **condition** | `if corps and vie and vie.Health > 0 then` |
| **boucle** | `for _, joueur in ipairs(Players:GetPlayers()) do` |
| **événement** | `RunService.Heartbeat:Connect(...)` |

### Pourquoi PAS `Touched`

C'est ce qu'on avait essayé en premier, et ça **ne marchait pas** : on tombait
en plein milieu de la fosse et il ne se passait rien.

Deux raisons :

- les piques sont en `CanCollide = false` (on les traverse), et `Touched` se
  déclenche mal sur une pièce qu'on traverse ;
- elles sont espacées de 9 studs : on peut tomber **entre deux pointes** sans
  en toucher une seule.

La solution : une **zone de mort** invisible qui remplit tout le fond du trou,
et le script regarde la **position** du joueur à chaque image (`Heartbeat`,
60 fois par seconde) au lieu d'attendre un contact.

```lua
RunService.Heartbeat:Connect(function()
    for _, joueur in ipairs(Players:GetPlayers()) do
        local perso = joueur.Character
        if perso then
            local corps = perso:FindFirstChild("HumanoidRootPart")
            local vie   = perso:FindFirstChildOfClass("Humanoid")
            if corps and vie and vie.Health > 0 and dansLaZone(corps.Position) then
                vie.Health = 0
            end
        end
    end
end)
```

Bonus : en voiture, le corps du joueur suit la voiture. Ce seul test couvre
donc **aussi** le cas où on tombe au volant.

Test : téléporté au fond de la fosse, `vie 100 → 0 en 1 seconde`. ✅

---

## 3. La montagne

Le problème de départ : **ma montagne n'était pas un volume.** C'était un ruban
de route posé sur un talus de 25 studs de large. Impossible d'y planter quoi que
ce soit — mes 152 sapins finissaient tous au pied, parce que le rayon qui
cherchait le sol passait à côté du talus et descendait jusqu'à l'herbe.

### La méthode

Une grille de **colonnes de roche** autour du tunnel, hautes au centre, basses
sur les bords :

```
hauteur = HAUTEUR_MAX × (1 − distance/RAYON) ^ 1,25
```

Puis trois contrôles automatiques :

- une colonne qui traverse le **tunnel** repart au-dessus de son plafond,
  sinon le tunnel est bouché ;
- une colonne qui touche la **piste** est supprimée : la route reste à ciel
  ouvert ;
- la **neige** est une pièce *séparée* posée sur la colonne.

### Les proportions comptent

| Essai | Rayon | Hauteur | Résultat |
|---|---|---|---|
| 1 | 430 | 170 | un carrelage de dalles plates |
| 2 | 300 | 215 | ça ressemble enfin à une montagne |
| 3 | 330 | 470 | un vrai pic |
| 4 | 370 | 640 | **retenu** — sommet à 603 studs, pente 58° |

En montant la hauteur, il faut **élargir la base** en même temps : à rayon
constant, le flanc dépassait 65° et ça devenait une tour posée sur l'herbe.

### L'éboulis

Les flancs restaient des faces planes de 40 studs. Pour chacun des ~1000
rochers : un rayon **horizontal** cherche la paroi, et le bloc est posé à
l'endroit exact touché, **enfoncé à 45 %**.

- enfoncé à 38 % → il ressort comme une écaille de travers
- enfoncé à 62 % → il disparaît, la paroi redevient lisse

---

## 4. Les six pièges de la séance

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| `SpecialMesh` type `Pyramid` | la Part devient **invisible** | ce type n'est plus affiché par Roblox |
| Deux `WedgePart` croisés à 90° | on obtient une colonne carrée | les volumes s'**additionnent**, ils ne se coupent pas → il faut 4 `CornerWedgePart` |
| `Touched` sur une Part traversable | rien ne se déclenche | `CanCollide = false` → surveiller la position avec `Heartbeat` |
| R, V et B variés séparément | rochers **verts et violets** | pour nuancer un gris, décaler les **trois canaux ensemble** |
| Agrandir `TextSize` | le texte ne grossit pas | `TextSize` est **plafonné à 100** → pour écrire gros, **rétrécir le canvas** |
| Enneiger la roche | cubes blancs géants | seul le **sol** s'enneige ; la roche nue s'éclaircit sans blanchir |

Le plus instructif est celui des textes : j'ai essayé **quatre fois**
d'agrandir les chiffres du podium, avec deux diagnostics faux en chemin
(`SizingMode`, forme du canvas), avant de trouver que la vraie limite était le
plafond de `TextSize`. La solution était l'inverse de l'intuition :
**rétrécir** le canvas pour que le texte paraisse plus grand.

---

## Le circuit à la fin de la séance

| | |
|---|---|
| Tour | 3083 studs (~44 s) |
| Sommet de la piste | 60 studs |
| Sommet de la montagne | **603 studs** |
| Tremplin | trou 30 studs, il faut 47 studs/s |
| Fosse | 21 piques + zone de mort, 57 studs de chute |
| Podium | terrasse à 260 studs, face à la ligne d'arrivée |
| Total | ~2160 objets (877 en début de séance) |

⚠️ Si le jeu rame en multijoueur, l'**éboulis** (1000 blocs) est le premier
endroit où alléger.

## La suite

Sur les 7 points obligatoires du projet, il en reste **5** : le chrono, les
checkpoints, le temps affiché à l'écran, le classement, le multijoueur.

Et je n'ai toujours pas fait **un seul tour complet en voiture**.
