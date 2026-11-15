# Prototype 1 — Salle isométrique Flame avec agents animés

**Date :** 15 novembre 2026 · **Code :** `prototypes/iso_room/` · **Tests :** `test/prototypes/iso_room_test.dart`.

## But

Afficher avec Flame une salle isométrique en pixel art où une trentaine d'agents animés se déplacent, et mesurer la fluidité.

## Ce qui a été construit

- `iso_math.dart` — grille isométrique en losanges 2:1 (cases de 64 × 32), conversion grille ↔ écran, ordre de profondeur, déplacement vers une cible.
- `pixel_sprites.dart` — planche de 5 images de 16 × 24 pixels par personnage (1 immobile, 4 de marche), dessinée par le code, affichée à l'échelle 2 sans lissage.
- `main.dart` — le jeu : une île de 18 × 18 cases sur ciel lavande (épaisseur herbe et terre, sol en damier pastel par quart de salle, couloirs, murs du fond avec fenêtres), 13 bureaux avec écran, et N agents qui choisissent un point, s'y rendent, patientent et recommencent. Agents et bureaux sont triés en profondeur à chaque déplacement.
- `frame_stats.dart` — statistiques tirées des temps d'image du moteur (construction et rendu).
- Mode mesure : variables d'environnement `AGENTS` et `BENCH_SECONDS` ; l'application écrit un rapport JSON et une capture PNG, puis quitte.

## Mesures

Machine : runner Windows de GitHub Actions — 2 cœurs AMD EPYC, **aucune carte graphique** (« Microsoft Hyper-V Video », rendu logiciel). Fenêtre de 1028 × 681, mode profil, 15 secondes après 2 secondes de chauffe. Deux exécutions.

| Agents | Images par seconde | Temps moyen par image | 99ᵉ centile | Images au-delà de 16,7 ms |
|---|---|---|---|---|
| 30 | 64,0 et 63,9 | 8,4 ms | 17,5 ms | 1,35 % et 0 % |
| 100 | 63,5 et 64,2 | 10,8 ms | 20,4 ms | 3,0 % et 1,25 % |
| 300 | 38,3 et 46,3 | 28,2 ms | 40,7 ms | 100 % et 96 % |

Le temps passé dans le code Dart (mise à jour du jeu) reste négligeable : 0,5 ms à 30 agents, 0,7 ms à 100, 2,3 ms à 300. Tout le reste est du rendu, ici calculé par le processeur.

**Lecture :** la cible de 30 agents tient à 64 images par seconde même sans carte graphique, avec une marge d'un facteur trois. Sur un PC de bureau avec carte graphique les chiffres seront meilleurs ; ils restent à relever.

## Rendu obtenu

La capture montre l'île isométrique, les quatre zones pastel, les couloirs, les murs à fenêtres, les bureaux blancs avec écran et les 30 personnages aux palettes variées, correctement triés en profondeur. L'ambiance générale va dans le sens des images de référence 01 à 03 (île sur ciel lavande, zones de couleur). Il manque, par rapport à elles : les murets de couleur autour des pôles, les étiquettes de pôle, le mobilier détaillé, les arbres et la décoration, les agents assis à leur poste. C'est attendu pour un prototype de mesure ; ce travail appartient à la phase 5.

## Limites de la vérification

- Mesures prises sur une machine virtuelle sans carte graphique, pas sur le poste de développement : la chaîne de compilation C++ de Windows n'y est pas installée. Le prototype n'a donc été vu qu'à travers sa capture, pas en mouvement.
- Les personnages sont dessinés par le code : la charge d'une planche Aseprite réelle (plus d'images, plus de directions) n'est pas mesurée.

## Difficultés

- Trier en profondeur : la priorité Flame de chaque agent change quand il se déplace ; ne la modifier que lorsqu'elle change réellement évite de retrier la scène à chaque image.
- Le décor fixe est dessiné une seule fois dans une image vectorielle rejouée à chaque image ; le dessiner case par case à chaque image aurait coûté 324 tracés.
- L'application doit pouvoir se capturer elle-même (`RepaintBoundary`) pour être vérifiée sur une machine sans écran.

## Approche retenue pour la suite

- **Flame convient** pour le bureau vivant : composants `SpriteAnimationComponent`, monde et caméra, tri par priorité.
- **Décor en couches** : le sol et les murs fixes dans une image pré-rendue par salle ; seuls le mobilier et les personnages sont des composants triés.
- **Profondeur** : priorité calculée depuis la position sur la grille (`colonne + ligne`), mise à jour seulement au changement.
- **Planches de sprites** en pixel art affichées sans lissage, une planche composée par personnage (voir le prototype 2).
- **Au-delà de 100 agents visibles**, regrouper les sprites dans un atlas et dessiner par lots (`SpriteBatch`) : à faire seulement si une entreprise réelle l'exige.
- **Plateau** : le prototype dessine la salle par le code ; la production partira de cartes Tiled générées depuis l'organisation (phase 5).
- Garder le mode mesure et le workflow `prototypes` pour suivre la fluidité quand le décor s'enrichit.
