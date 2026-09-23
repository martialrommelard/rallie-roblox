# Leçon 5 — le départ sonore, les cages et la course en 3 tours

*Séance du 2026-09-23.* Au début de la séance, le départ c'était trois lampes
qui changeaient de couleur. À la fin, c'est une vraie course.

---

## 1. Le son : pourquoi on ne peut pas avoir « aigu ET long »

Un son dans Roblox a une propriété `PlaybackSpeed`. C'est la vitesse de
lecture, comme un vinyle qu'on ferait tourner plus ou moins vite.

```
PlaybackSpeed = 2     →  2× plus vite  →  plus AIGU   et 2× plus COURT
PlaybackSpeed = 0.5   →  2× plus lent  →  plus GRAVE  et 2× plus LONG
```

Le problème : je voulais un bip **aigu** et **long**. Or `PlaybackSpeed` change
les deux **en même temps**. Aigu obligeait à court.

### Les trois fausses solutions

| Ce que j'ai essayé | Ce qui n'allait pas |
|---|---|
| Boucler le bip court (`Looped = true`) | on entend *bip-bip-bip*, pas *biiiip* |
| Ralentir beaucoup | ça devient grave **et mou** |
| Monter le volume à fond | un son mou et fort reste mou |

> **Pourquoi « mou » ?** Ralentir un son étale son énergie. Le même coup dure
> 3× plus longtemps, donc il frappe 3× moins fort. Monter le volume ne rend
> pas l'attaque plus sèche.

### La vraie solution : `PitchShiftSoundEffect`

Cet effet ne change **que** la hauteur, sans toucher à la durée. En le
combinant avec `PlaybackSpeed`, on découple enfin les deux :

```lua
bipLong.PlaybackSpeed = 0.25        -- 0,72 / 0,25 = 2,88 s  (long, mais grave)
-- puis 2 PitchShiftSoundEffect, Octave = 2 chacun  →  hauteur × 4
-- hauteur finale : 0,25 × 4 = 1,00  →  exactement le son d'origine
```

⚠️ **Chaque effet coûte cher** : il ajoute des artefacts métalliques *et* de la
latence. Avec 3 effets, le bip sonnait artificiel et arrivait en retard. Avec 2,
c'est propre. **En mettre le moins possible.**

---

## 2. Caler un son sur une lumière

Une lumière s'allume **instantanément**. Un son, non : l'ordre doit partir du
serveur, arriver chez le joueur, et le son met un instant à démarrer.

La solution est de lancer le son **en avance** :

```lua
biper(AIGU, VOL_BIP)
task.wait(AVANCE)                  -- 0,20 s d'avance
peindre(ligne(n), ROUGE, true)
task.wait(DUREE - AVANCE)          -- 0,80 s → le rythme reste à 1 s pile
```

> **Le piège** : si on écrit `task.wait(DUREE)` à la fin, chaque étape dure
> 1,2 s et **tout le compte à rebours ralentit**. L'avance doit être prise
> **sur** l'attente suivante, pas ajoutée après.

Et pour le dernier bip, plus lent à « attaquer », on prend l'avance sur la
dernière seconde :

```
t = 2,00   bip 3
t = 2,20   rouge 3
t = 2,75   BIIIIP        ← part 0,45 s avant
t = 3,20   VERT
```
Les quatre lumières restent espacées d'exactement 1 seconde.

---

## 3. Serveur et client : les deux mondes

C'est la notion la plus importante de la séance.

| | `Script` | `LocalScript` |
|---|---|---|
| Tourne sur | le **serveur** | la machine de **chaque joueur** |
| Combien | 1 seul, pour tous | 1 par joueur |
| Sert à | les règles du jeu | l'affichage, les commandes |

Un texte à l'écran est **personnel** → forcément un `LocalScript`. Mais les
feux sont sur le serveur. Les deux ne peuvent se parler que par un
**`RemoteEvent`**, rangé dans `ReplicatedStorage` (le seul endroit que les
deux voient).

```lua
-- côté SERVEUR
afficher:FireAllClients("GO", VERT)

-- côté JOUEUR
evenement.OnClientEvent:Connect(function(texte, couleur)
	chiffre.Text = texte
end)
```

**Pourquoi c'est le serveur qui compte les tours ?** Parce que si c'était
chaque joueur, chacun pourrait s'inventer des tours. Règle générale : ce qui
décide de qui gagne vit sur le serveur.

---

## 4. Compter un passage sans `Touched`

`LigneDepart` est en `CanCollide = false` : `Touched` ne se déclenche pas.
C'est le même piège que la fosse à piques.

La méthode qui marche :

```lua
local p = ligne.CFrame:PointToObjectSpace(torse.Position)
local cotePresent = (p.Z > 0) and 1 or -1

if cote[joueur] == 1 and cotePresent == -1 and dansLaLargeur then
	passages[joueur] += 1
end
```

`PointToObjectSpace` donne ma position **vue depuis la ligne**. Le signe de
`p.Z` dit de quel côté je suis : `+` derrière, `−` devant.

> **Pourquoi le CHANGEMENT de signe et pas « je suis sur la ligne » ?**
> À 60 images par seconde, on reste une dizaine d'images au-dessus de la
> ligne → on gagnerait 10 tours d'un coup. Un changement de signe n'arrive
> **qu'une fois** par passage.

Et `dansLaLargeur` (`|p.X| < 40`) évite de compter quelqu'un qui coupe par
l'herbe 50 studs à côté.

---

## 5. Demander ses mesures à l'objet, pas au décor

Pour enfermer les voitures avant le départ, ma première idée était de caler
les cages sur le marquage au sol. Les chiffres m'ont arrêté :

```
un emplacement de grille : 9 studs de long
une voiture              : 18,1 studs de long
```

La cage aurait été **deux fois trop courte**. La bonne source, c'est la
voiture elle-même :

```lua
local cf, taille = m:GetBoundingBox()   -- la boîte ET son orientation
local demiL = taille.X / 2 + MARGE
local demiP = taille.Z / 2 + MARGE

poserMur(cage, cf * CFrame.new(0, 0, -demiP), …)   -- devant
poserMur(cage, cf * CFrame.new(-demiL, 0, 0), …)   -- côté gauche
```

`cf * CFrame.new(...)` veut dire *« à partir de la voiture, avance de tant »*,
**dans son repère à elle**. La cage tourne donc avec la voiture, sans un seul
calcul d'angle. Et elle s'adapte à n'importe quelle voiture.

C'est exactement le principe de la ligne de départ, qui demande sa position à
la route au lieu de la deviner.

---

## 6. `Transparency` et `CanCollide` sont indépendants

Un mur peut être **totalement invisible et parfaitement solide**. Une seule
ligne suffit à ouvrir ou fermer la piste :

```lua
p.Transparency = TRANSP   -- 1 = invisible
p.CanCollide   = true     -- mais ça bloque quand même
```

---

## 7. Les attributs : faire parler trois scripts entre eux

Trois scripts serveur doivent se coordonner. Ils se passent **une seule
information**, accrochée au Workspace :

```lua
workspace:SetAttribute("CourseEnCours", true)     -- FeuxDepart, au vert
workspace:GetAttribute("CourseEnCours")           -- les autres, pour lire
workspace:GetAttributeChangedSignal("CourseEnCours"):Connect(…)
```

| Script | Ce qu'il en fait |
|---|---|
| `FeuxDepart` | le met à `true` au vert, et refuse de relancer tant qu'il est `true` |
| `CompteurTours` | ne compte rien tant qu'il est `false`, le remet à `false` à la fin |
| `Voitures` | remet les voitures en grille quand il **passe** de vrai à faux |

---

## 8. Mes erreurs de la séance

| L'erreur | Ce qui se passait | La règle |
|---|---|---|
| `if attribut == false then` | les voitures étaient rasées 5 s après le lancement du jeu | un attribut faux ne dit pas si la course vient de finir ou n'a **jamais** commencé → détecter le **passage** de vrai à faux |
| Ranger les voitures dans un dossier | plus aucune cage, **sans la moindre erreur dans l'Output** | du code cherchait « les modèles à la racine du Workspace » → déplacer des objets oblige à relire tout ce qui les cherchait |
| Oublier le 2ᵉ joueur | s'asseoir en pleine course relançait les bips et plantait une cage devant celui qui roulait | il fallait **deux** verrous : `enCours` pour le compte à rebours, `CourseEnCours` pour toute la course |
| Mesurer un son en mode Edit | `TimePosition` restait bloqué à 0 | le moteur audio ne tourne pas pareil hors du jeu |
| Un joueur qui quitte en pleine course | `CourseEnCours` restait à `true` **pour toujours**, plus aucun départ possible | toujours se demander : « et si celui qu'on attend ne revient jamais ? » |

---

## Ce que je sais faire maintenant

- régler un son : hauteur, volume, durée, fondu
- caler un son sur une image
- afficher quelque chose à l'écran d'un joueur depuis le serveur
- détecter un passage de façon fiable, sans `Touched`
- construire un objet à partir des mesures d'un autre
- faire coopérer plusieurs scripts par un attribut partagé
