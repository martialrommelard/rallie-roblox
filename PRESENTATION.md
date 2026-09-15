# Présentation orale du projet

Plan pour présenter le jeu de rally devant la classe.
Durée visée : **8 à 10 minutes**, dont 2 minutes de démonstration.

> ⚠️ Avant de présenter : ouvrir Roblox Studio, charger la place, et **faire un
> tour d'essai**. Ne jamais découvrir un bug devant le prof.

---

## Le fil rouge

Si on ne retient qu'une phrase de ma présentation, c'est celle-ci :

> **« Je n'ai pas dessiné le circuit. Je l'ai programmé. »**

Tout le reste en découle : c'est ce choix qui explique le script, les
diagnostics automatiques, et le fait d'avoir pu tester 7 tracés.

---

## 1. Le projet en une phrase — *30 secondes*

> « J'ai créé un jeu de course de rally sur Roblox : un circuit de montagne avec
> un tunnel et un tremplin, chronométré, jouable à plusieurs. »

Montrer la **vue de dessus du circuit** dans Studio. Ne pas encore parler de
code.

---

## 2. Le problème que j'ai dû résoudre — *1 minute*

> « Un circuit de rally, c'est environ 200 blocs à poser, tourner et aligner un
> par un. Ça prend des heures — et si je veux déplacer un virage, je recommence
> tout. »

Laisser la question en suspens. C'est elle qui rend la suite intéressante.

---

## 3. Ma solution : décrire au lieu de construire — *2 minutes*

Montrer la liste `POINTS` à l'écran.

> « J'ai décrit mon circuit avec **33 points**. Chaque point dit : où je suis,
> à quelle hauteur, et quelle largeur fait la route. Un script calcule le
> reste : 187 morceaux de route, 342 barrières, les talus, les rochers, les
> arbres. »

**La démonstration qui marque :** changer un nombre devant la classe, relancer
le script, montrer le circuit modifié en 2 secondes.

> « C'est ce qui m'a permis d'essayer **7 tracés différents**. À la main, je
> n'en aurais essayé qu'un seul. »

### La règle de conception à expliquer

> « Ce qui rend un circuit intéressant, ce n'est pas le lissage, c'est
> **l'espacement des points**. Des points serrés donnent un virage lent, des
> points écartés donnent une courbe rapide. Mon premier tracé avait des points
> réguliers : tous les virages se ressemblaient, c'était ennuyeux. »

---

## 4. La partie mathématique — *2 minutes*

C'est le passage qui montre qu'il y a du fond. Ne pas le sauter.

### La courbe

> « Pour relier mes 33 points par une courbe lisse, j'ai essayé trois méthodes.
> Les deux premières ont échoué :
>
> - **Chaikin** lissait tellement qu'il effaçait mes virages ;
> - **Catmull-Rom classique** faisait **boucler la route sur elle-même** quand
>   mes points étaient irrégulièrement espacés.
>
> La bonne solution, c'est **Catmull-Rom centripète** : une variante où on
> utilise la racine carrée de la distance entre les points. On démontre
> mathématiquement qu'avec cette variante, la courbe ne peut jamais faire de
> boucle. »

### Le tremplin

> « Pour qu'une voiture décolle, il faut que **v² / rayon soit supérieur à la
> gravité**. Avec la gravité de Roblox — 196 studs par seconde carrée — et une
> voiture à 80, ça donne un rayon de crête inférieur à 33 studs.
>
> Or ma courbe lisse tout à 150 studs de rayon. **Donc une simple bosse ne
> décollerait jamais.** Il me fallait une vraie rampe et un vrai trou. »

> « Ensuite j'ai calculé la taille du trou avec les équations de chute libre.
> Résultat : trou de 30 studs, chute de 35 — il faut rouler à **47 studs par
> seconde** minimum. »

---

## 5. Les bugs, et comment je les ai trouvés — *2 minutes*

C'est la partie la plus honnête et souvent la plus appréciée.

> « Mon script ne fait pas que construire : à la fin, **il mesure son propre
> travail**. »

Montrer le diagnostic affiché :

```
tour 3076 studs (~43 s) | pente max 21.9% | rayon mini 43 studs
TREMPLIN : trou 30, chute 35, vitesse mini 47 studs/s
```

> « C'est ce diagnostic qui a trouvé les bugs, pas moi. Il m'a signalé des
> virages de **7**, puis **21**, puis **33 studs de rayon** — trois virages
> physiquement infranchissables. Vus de dessus, ils étaient parfaitement jolis.
> Je ne les aurais jamais repérés à l'œil. »

Puis **un seul** bug raconté en détail — le plus parlant :

> « Le meilleur exemple, c'est les faux trous dans la route. Mes morceaux de
> route se chevauchent, et leurs surfaces étaient exactement à la même hauteur.
> La carte graphique ne sait pas laquelle afficher devant : elle clignote. En
> roulant, on croit voir des trous dans le bitume. Ça s'appelle le
> **Z-fighting**. La correction : descendre une route sur deux de **4
> centièmes de stud**. Invisible, et le problème disparaît. »

**La conclusion de cette partie :**

> « Les cinq bugs que j'ai eus ont la même forme : je vérifiais à l'œil, alors
> que le défaut était dans les chiffres. C'est pour ça que la moitié de mon
> script sert à se vérifier lui-même. »

---

## 6. Démonstration — *2 minutes*

Ordre à respecter, du plus sûr au plus spectaculaire :

1. La **ligne droite de départ** et le freinage dans l'épingle
2. La **montée** vers la montagne et le lacet
3. Le **tunnel**
4. La descente et le **tremplin** ← finir là-dessus

> Répéter le tour au moins deux fois avant la présentation. Si le saut rate en
> direct, le dire et le refaire : « il faut arriver à 47 studs par seconde,
> j'étais trop lent ».

---

## 7. La suite du projet — *30 secondes*

> « Le circuit est terminé. Il reste à programmer :
> le **chronomètre**, les **checkpoints** anti-triche, l'affichage du temps à
> l'écran, le **classement et le podium**, et les **écuries** pour choisir sa
> voiture. »

---

## Les questions probables — et quoi répondre

**« Tu as tout codé toi-même ? »**
> « J'ai écrit le générateur de circuit et je l'ai réglé moi-même, tracé par
> tracé. Pour la voiture, j'utilise un châssis existant : coder une physique de
> véhicule, c'est un sujet d'expert, et ça m'aurait pris tout le trimestre pour
> un résultat moins bon. J'ai préféré passer mon temps sur ce qui fait *mon*
> jeu : le circuit, le chrono et le podium. »

**« Pourquoi Roblox et pas un vrai moteur de jeu ? »**
> « Parce que le multijoueur est déjà intégré, et que mon objectif c'est
> d'apprendre à programmer, pas à installer un moteur. Le langage, le Luau, est
> un vrai langage de programmation avec variables, conditions, boucles,
> fonctions et tableaux. »

**« Combien de temps ça t'a pris ? »**
> Être honnête. Dire aussi que **le générateur a fait gagner du temps** : 7
> versions du tracé, là où une construction à la main n'en aurait permis qu'une.

**« C'est quoi un stud ? »**
> « L'unité de longueur de Roblox. Ma route fait 48 studs de large, soit à peu
> près 4 voitures côte à côte. »

**« Et si on te demande de changer le circuit ? »**
> Le faire en direct. C'est l'argument le plus fort du projet.

---

## Checklist avant de présenter

- [ ] Studio ouvert, place chargée, **un tour d'essai fait**
- [ ] Le fichier `GenerateurCircuit.lua` ouvert dans un onglet, sur la liste `POINTS`
- [ ] La barre de commande (View → Command Bar) déjà affichée
- [ ] Le dépôt GitHub ouvert dans un onglet du navigateur
- [ ] Savoir dire **une phrase** sur : la spline centripète, le Z-fighting, le calcul du saut
