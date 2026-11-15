# Prototype 2 — Personnage en calques superposés

**Date :** 15 novembre 2026 · **Code :** `prototypes/layered_character/` · **Tests :** `test/prototypes/layered_character_test.dart`.

## But

Composer un personnage à partir de calques (corps, tenue, cheveux…) et en changer un à la volée, sans interrompre son animation.

## Ce qui a été construit

- `layers.dart` — le modèle : cinq calques dans l'ordre d'empilement (silhouette, tenue, visage, cheveux, accessoire), des variantes par calque (`LayerOption`), une apparence immuable (`CharacterAppearance`, une variante par calque), un catalogue (`LayerLibrary`) et un compositeur (`CharacterComposer`).
- `prototype_layers.dart` — 19 variantes dessinées par le code : 4 silhouettes, 4 tenues, 2 visages, 5 coiffures, 4 accessoires. Créations originales.
- `main.dart` — une fenêtre : le personnage en grand qui marche sur place, un panneau avec un bouton par calque pour passer à la variante suivante, et le temps de la dernière composition.

**Principe de composition :** chaque variante de calque est une planche de 5 images de 16 × 24 pixels sur fond transparent, toutes sur la même grille. La planche de chaque variante est dessinée une fois puis gardée en cache. L'apparence d'un personnage est la superposition de ses planches dans une **seule planche composée** ; changer un calque recompose cette planche et la donne à l'animation en conservant l'image et l'instant en cours.

## Mesures

Machine : runner Windows de GitHub Actions, 2 cœurs, sans carte graphique. 200 changements de calque aléatoires, trois exécutions.

| Composition d'une planche | Moyenne | Pire cas |
|---|---|---|
| Calque déjà en cache | 0,87 à 1,42 ms | 12,2 à 17,7 ms |
| Calque rencontré pour la première fois | 3,5 à 5,2 ms | 8,9 à 21,9 ms |

Un changement de tenue tient donc largement dans une image (16,7 ms) en moyenne ; les pires cas, rares, restent de l'ordre d'une image.

## Rendu obtenu

La capture prise après la mesure montre le personnage composé de ses cinq calques (silhouette foncée, chemise violette, yeux sombres, cheveux longs gris, casque audio) à côté du panneau des calques. Le test automatique vérifie que changer les cheveux modifie le haut de la tête sans toucher un seul pixel des jambes.

Défaut visible, sans conséquence pour la suite : sur l'image de marche capturée, un pixel de peau dépasse à côté d'une chaussure (la jambe de la silhouette n'est pas raccourcie comme celle de la tenue). Les calques dessinés par le code sont jetables.

## Limites de la vérification

- Vérifié par capture et par tests, sur le runner de la CI : la chaîne de compilation C++ de Windows n'est pas installée sur le poste de développement. Les boutons du panneau n'ont pas été cliqués à la main ; la mesure appelle le même chemin de code que les boutons.
- Les calques sont de petites planches dessinées par le code : de vraies planches Aseprite (plus d'images, plusieurs directions, plus grandes) coûteront plus cher à composer. À remesurer avec les premiers graphismes réels.

## Difficultés

- La mesure lancée pendant le chargement du jeu empêchait tout affichage : la première capture ne montrait pas le personnage. La mesure démarre maintenant après le chargement.
- Remplacer l'animation remet son horloge à zéro : il faut reporter l'image et l'instant en cours sur la nouvelle animation pour que la marche ne saute pas.

## Approche retenue pour la suite

- **Une planche composée par personnage**, recomposée seulement quand son apparence change : un seul sprite à dessiner par agent, quel que soit le nombre de calques (c'est ce que suppose la mesure de fluidité du prototype 1).
- **Planches de calques alignées sur une grille commune** (même taille d'image, mêmes animations), exportées d'Aseprite ; le serveur ne stocke que les identifiants de variantes (`CharacterAppearance`), pas d'image.
- **Cache des planches de calques** partagé entre tous les personnages ; cache des planches composées par apparence.
- **Ordre des calques** défini une fois ; l'éditeur de personnage (phase 9) y ajoutera ses catégories (poste de travail, attitude).
- La règle RM-48 (un agent ne change jamais lui-même coiffure, visage ni silhouette) se traduira par une liste de calques modifiables selon l'auteur du changement.

**Alternative écartée :** empiler un composant animé par calque. Plus simple à changer, mais cinq sprites ou plus à dessiner et à synchroniser par agent ; inutile puisque la recomposition coûte environ une milliseconde.
