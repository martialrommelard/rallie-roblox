# Idées d'amélioration

Liste d'idées pour la suite du jeu de rally (notée le 2026-10-06).
On coche une case quand l'idée est faite. **On avance dans l'ordre des priorités.**

---

## 🔴 PRIORITÉ 1 — le cœur du jeu (c'est ce qui est noté)

> ⚠️ **À faire AVANT toute nouvelle idée.** Rappel à chaque séance tant que ce
> n'est pas fini.

- [x] **Checkpoints** : empêcher de couper le circuit. *(2026-10-30 : 5
  portiques, à passer dans l'ordre ; testé : couper = « checkpoint manqué ».)*
- [ ] **Tester à plusieurs joueurs** : choix des places, places 2 et 3, podium
  à 3 statues (Studio → Test → plusieurs joueurs, ou avec un copain).
  *(2026-10-30 : bug corrigé en préparant ce test — un joueur qui arrivait
  pendant une course la bloquait. Le vrai test à 2 reste à faire.)*
- [x] **Bouton « Abandonner »** ET temps limite. *(2026-10-30 : bouton,
  abandon automatique 8 s après être descendu de voiture, 10 min maximum,
  90 s pour les autres après l'arrivée du 1er.)*

## 🟠 PRIORITÉ 2 — bugs à corriger

- [x] **Bureaux : le bouton « Se lever » ne marche pas.** *(2026-10-30 : c'est
  le serveur qui défait la soudure de la chaise.)*
- [x] **Son du moteur.** *(2026-10-30 : le son moteur se charge bien ; c'était
  le crissement des pneus qui était bloqué (remplacé), et le script son
  d'A-Chassis plantait quand on descendait de voiture (corrigé).)*
- [x] **Erreur A-Chassis en boucle** (`Tune.Initialize` ligne 286).
  *(2026-10-30 : faute de frappe dans la voiture du Toolbox, `FAntiRoll`
  écrit deux fois au lieu de `RAntiRoll` : la suspension arrière plantait.)*

## 🟡 PRIORITÉ 3 — mode entraînement (solo / simulateur)

- [ ] **Mode entraînement** (« simulateur de conduite ») : ouvre le circuit sans
  compétition, sans dégâts, juste avec un chrono. Pour tester sa voiture et le
  circuit sans que le temps compte dans les records.
- [ ] **Fantôme du meilleur tour** (dans ce mode) : une voiture transparente
  refait ton record pendant que tu roules.
- [ ] **Temps intermédiaires vert / rouge** (dans ce mode) : à chaque checkpoint,
  vert = en avance sur ton record, rouge = en retard. *(Il faut les checkpoints
  de la priorité 1.)*

## 🟢 PRIORITÉ 4 — voitures et garage

- [x] **La voiture s'abîme pendant la course** en cas de choc. *(2026-10-30 :
  chaque MORCEAU s'use à part (seul celui touché), noircit, puis se détache
  et reste sur la piste comme obstacle. La voiture, elle, n'est JAMAIS
  détruite. Les dégâts restent après la course : on répare aux 4 postes du garage.)*
- [x] **Piste secondaire qui passe par les garages** (comme un arrêt au stand) :
  on y répare la voiture, mais on perd quelques secondes. *(2026-10-30 : les
  STANDS en face du spawn, 6 écuries, limiteur 40, réparation « un peu »
  à l'arrêt devant SON écurie. Pas de boost.)*
- [x] **Configurer sa voiture sans être dedans** : le GARAGE sous le spawn
  (2026-10-30), bornes « Ouvrir le garage ».
- [x] **Améliorer sa voiture avec des pièces** 🪙, sauvegardé (DataStore
  `Garage_v1`) : moteur, boîte, freins, carrosserie, 3 niveaux.
- [x] **Créer d'autres voitures** : 5 au choix (Jesko, Éclair, Comète, Bélier,
  Panthère). ⚠️ Même carrosserie (la Jesko) : ce sont la peinture et les
  réglages qui changent.

## 🔵 PRIORITÉ 5 — confort et ambiance

- [ ] **Menu d'accueil** à l'arrivée : « Course », « Entraînement », « Garage ».
- [ ] **Choisir la musique** depuis le bureau.
- [ ] **Obliger à reposer les haltères** avant de sortir de la salle de sport.
- [ ] **Écrans de publicité** le long du parcours et dans les salles.
- [ ] **Gagner des pièces en regardant une pub Roblox.**

## 🎤 À la fin (semaine 12)

- [ ] **Mettre à jour `PRESENTATION.md`** pour l'oral, avec tout ce qui a été
  ajouté (épicerie, salle de sport, bureaux…).

---

## Mes idées telles que je les ai écrites

> obligation de rposer halteres en sortant de la salle
> gagner des pices en regardant une pub robblox
> ajouter quelques ecran de publicite sur le parcour et dans les salles
> dans le bureau la possibilité de choisir la musique
> dans les burea le bouton se lever ne fonctionne pas
> la possibilité de configurer sans voiture une fois les garage effectué
> avec des pieces amelioré sa voiture et la sauvegarder
> creer differente voiture autre que celle de roblox pour utilisation
> creation d'une piste secondaire passant dans les garages opour reparation et boost mais perte de quelques seconde de temps
> voiture qui sabime sur la course en cas d'impact
> simulateur de conduire qui ouvre la course sans competition, sans impact et juste un chrono - permet de tester sa voiture et le circuit non officielement

> je pense que le mode fantome et temps rouge ou vert et a faire en mode solo/simulateur
