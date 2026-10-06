# Séance du 2026-10-06 (après-midi) — l'épicerie, les pièces et les pouvoirs

Ce fichier garde la séance **telle qu'elle s'est passée** : mes demandes dans
l'ordre, ce qui a été fait, et les allers-retours. Le résumé propre est dans
[`PROGRESSION.md`](../PROGRESSION.md) (journal du 2026-10-06, « l'épicerie »).

> Mes demandes sont recopiées **mot pour mot**, fautes comprises. C'est
> volontaire : ça montre qu'un projet n'avance pas en ligne droite.

---

## 1. Reprendre

- « reprend la discussion et co toi a roblox studio »
  → connecté à Studio ; la salle de sport du matin était bien sauvegardée (441 objets).

## 2. L'épicerie

- « ok mainteant genre dans l'autre moitie du batiment on va crée une sorte dépisserie ou on peut acheter des chose genre des la nouriture qui donne des bosste ect tu vois le delire tout en pouvant passer dans la salle de sport »
  → la moitié côté porte du bâtiment, **mesurée** : 55 × 63 studs, 19,6 de plafond, la porte
  en face du passage vers la salle de sport.
  → 2 questions, parce qu'il n'y avait pas encore d'argent dans le jeu :
  - comment on gagne l'argent ? → **« Seulement en course »** ;
  - qu'est-ce que la nourriture booste ? → **tout** (à pied, salle de sport, voiture, et pour le fun).
- Construit par le générateur `Epicerie.lua` (763 pièces) :
  une **allée libre** de la porte au passage de la salle de sport (vérifiée par le calcul),
  la caisse et la caissière, l'étal de fruits, le bac à glaces, 2 rayons, le frigo à boissons.
- Une **seule liste** des produits : `Produits` (ModuleScript). Le générateur, le serveur et
  l'écran la lisent tous les trois : pour ajouter un produit, une ligne suffit.
- Acheter : on s'approche, **E** (ou clic sur le bouton). Manger : le produit en main, **clic**.

## 3. Les pièces

- « donne moi des piece ilimiter » → 999 999 pièces le temps du Play.
- « piece ilimiter stp » → pareil (elles repartaient à 0 à chaque Play).
- « remet pice ilimiter tout le temps » → j'ai d'abord fait « illimité dans Studio »…
- « nan mes genre que moi le créateur a piece ilimité »
  → **seulement le créateur** (`joueur.UserId == game.CreatorId`), partout, même dans le vrai jeu.
  Vérifié : le créateur de la place, c'est bien mon compte. Mes achats sont gratuits et mon
  compte n'est jamais sauvegardé.
- « fais pour que quand on est premier on gagne 1er 10piece 2eme 5piece 3eme e3piece et apres que 1 si ta fini la cource sinon zero et que quand on quite le jeu et que on revient plus tard on reprend le nombre de piece qu'on avait avant de quitter le jeu et fais que quand je vole ca soit prorpre et que ca ressemble a quelque chose »
  → gains : **10 / 5 / 3**, puis **1** si on finit, **0** si éliminé (`GAINS_PLACE`).
  → la sauvegarde existait déjà (DataStore `Pieces_v1`, quand on quitte) ; ajouté : une
  sauvegarde **toutes les minutes**. Dans Studio, il faut cocher « Enable Studio Access to API
  Services » pour l'essayer ; dans le jeu publié, ça marche.

## 4. Les pouvoirs

- « ok pour la vitesse fait la rapide comme falsh tu vois la tomate fait que ca crée le pouvoir de la tomate volant permet de voler ou on veut pendant un course entière et la gace pendant 45SECONDE on peut j'ettait des boulle de glace qui va congeler un perssonne pendant 15 et en le combinant avec la tomate on pourrat congeler meme un persso faisant une course »
  → 2 questions : pendant une course, qui vole ? → **« Le perso à pied (chasseur) »** ;
  « une course entière » ? → **jusqu'à la fin de la course**.
  - **Boisson Flash** : vitesse 70 pendant 30 s, traînée jaune et rouge ;
  - **Tomate volante** : voler jusqu'à la fin de la course ; en course, on sort de sa voiture
    et on devient **chasseur 🍅** (`CompteurTours` arrête sa course, sinon on gagnerait en
    volant tout droit jusqu'à la ligne) ;
  - **Glace** : 45 s pour lancer des boules (clic) ; touché = **congelé** dans un bloc de glace,
    même un pilote (on ancre le siège : toute la voiture s'arrête).
- « transeforme la glace en 4seconde » → congélation 4 s (au lieu de 15).

## 5. Un vol qui ressemble à quelque chose

- Première version : le corps raide, couché.
- Deuxième version (« propre ») : animations de **nage** de Roblox, accélération douce,
  inclinaison dans les virages, caméra qui s'élargit, traînées de vent, fumée au décollage.
- « euh pour la tomate ca passe mais on a l'impression qiue je nage tu peux ameliorer »
  et « et fait quer on va vite un peu pour voler »
  → plus de nage : **2 poses** posées par le calcul (comme les pilotes des vélos), et vitesse 90.
- « nan mais la on a repris comme la derière fois t upeux pas faire cimme superman quand il avance et quznd il recule d'etre en levitation »
  → on a **mesuré pendant que je volais** : la tête 1,3 devant, le corps à l'horizontale…
  mais **la main droite 1,6 stud DERRIÈRE**. Les hanches prenaient la pose, pas les épaules.
  Cause : le script des exercices (`Exercices.client`) remettait mes bras « au repos »
  **à chaque image** (pour les coups de poing et les haltères) et écrasait la pose.
  Correction : une ligne, il ne touche plus aux bras quand je vole.
- « je vole ca mae=rche enregistre tout sur giltchub et la discudssion » → ce fichier.

---

## Ce que j'ai appris aujourd'hui

| Notion | Où |
|---|---|
| **Une seule liste** (ModuleScript) que plusieurs scripts lisent | `Produits` |
| **leaderstats** : un compteur que Roblox affiche tout seul dans la liste des joueurs | les pièces |
| **DataStore** : garder une valeur quand on quitte le jeu | les pièces |
| **Attributs** pour se parler entre scripts (`Boost_vol`, `EnVol`, `Chasseur`) | serveur, écran, compteur de tours |
| **RemoteEvent** : l'écran demande, le serveur vérifie | voler, lancer une boule |
| Un projectile **sans physique** : un rayon entre la position d'avant et celle d'après | les boules de glace |
| **LinearVelocity** + **AlignOrientation** : pousser et tourner un personnage | le vol |
| Deux scripts qui touchent la même chose **s'écrasent** : mesurer pour trouver lequel | la pose Superman |

## Pas encore fait (prévu)

- Les produits pour la **salle de sport** (ex. banane = zone verte du banc plus large).
- Les produits pour la **voiture**, avec une marque ⚡ au tableau des records.
- Les prix sont restés hauts pour les nouveaux gains (tomate 150 = 15 victoires) : à revoir.
