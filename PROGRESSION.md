# Où j'en suis

Projet : **jeu de rally sur Roblox** (voir [`PROJET-RALLY.md`](PROJET-RALLY.md)).
Élève de seconde, a fait du Scratch, débute en Luau.

---

## ⏸️ POUR REPRENDRE LE PROJET — à lire en premier

### État au 2026-09-15

**Étape 1 (le circuit) : TERMINÉE ✅**

Le circuit « RALLY MONTAGNE » est construit dans Roblox Studio (place `Place1`)
et il est jouable : on peut en faire le tour en voiture.

| | |
|---|---|
| Tour | 3076 studs (~43 s) |
| Sommet | 59 studs de dénivelé |
| Virage le plus serré | 43 studs de rayon |
| Tremplin | trou de 30 studs, il faut 47 studs/s |

Un tour : ligne droite → épingle → montée → lacet → tunnel → descente →
tremplin → dernier virage.

### ⚠️ La première chose à faire en reprenant

1. **Ouvrir Roblox Studio** et vérifier que le circuit est bien là
   (`Workspace > Circuit` dans l'Explorer).
2. **S'il a disparu** : ouvrir `scripts/GenerateurCircuit.lua`, tout copier, et
   coller dans **View → Command Bar** de Studio. Le circuit se reconstruit en
   quelques secondes, à l'identique.
3. **Penser à sauvegarder la place** (`Ctrl+S` dans Studio) — le générateur est
   sauvegardé sur GitHub, mais la place Roblox, non.

### Ce qui n'est PAS encore fait

- ❌ Aucun script de jeu : pas de chrono, pas de checkpoints, pas de podium
- ❌ La voiture vient du Toolbox, elle n'est pas configurée proprement
- ❌ Aucun décor autre que les arbres et les rochers du circuit

### La prochaine étape : LE CHRONOMÈTRE

C'est là que j'écrirai mes **premières vraies lignes de Luau**.

Il faut, dans l'ordre :
1. Une Part nommée `LigneDepart` (elle existe déjà dans le dossier `Circuit`)
2. Un script qui détecte quand une voiture la touche → événement `Touched`
3. Une variable qui retient l'heure de départ
4. Des checkpoints le long du circuit pour empêcher de couper

Notions à apprendre à ce moment-là : `Touched`, les fonctions, les variables,
les conditions `if`.

---

## Notions de code déjà vues

| Notion | Vue le | Où je m'en sers |
|---|---|---|
| L'interface de Studio (Explorer, Properties, Output) | 2026-09-10 | Partout (`lecons/01-interface.md`) |
| Lire et modifier un script Luau (la liste `POINTS`) | 2026-09-15 | Le générateur de circuit |
| Git : `add`, `commit`, `push` | 2026-09-15 | Sauvegarder le projet sur GitHub |

⚠️ Je n'ai pas encore **écrit** de Luau moi-même — j'ai lu et modifié le
générateur. La vraie programmation commence à l'étape du chronomètre.

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

---

## Points à revoir / difficultés

- Le **lacet** dans la montée fait 43 studs de rayon : c'est serré. À vérifier
  en roulant — si ça ne passe pas, écarter les points 12, 13 et 14.
- Le **tremplin** demande 47 studs/s. Si la voiture ne va pas assez vite, il
  faut rallonger la réception (voir `DOCUMENTATION.md`, section 4).
