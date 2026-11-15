# Décisions prises pendant le code — leaddesk-app

Chaque entrée : décision, raison, alternatives. Les décisions communes aux deux dépôts sont détaillées dans `leaddesk-api/docs/decisions.md`.

## Étape A — Dépôts et outillage

### D-001 · Paquet `leaddesk_app`, binaire Windows `leaddesk.exe`
- **Décision** : le paquet Dart s'appelle `leaddesk_app` (dossier `apps/` conservé) ; le binaire et le titre de fenêtre Windows deviennent `leaddesk` / « LeadDesk ».
- **Raison** : demandé par la mission ; seul Windows est ciblé en V1, les identifiants des autres plateformes seront renommés quand elles seront activées.
- **Alternatives** : renommer toutes les plateformes dès maintenant (travail non testable en V1).

### D-002 · Analyse stricte
- **Décision** : `flutter_lints` + `strict-casts`, `strict-inference`, `strict-raw-types` et une sélection de règles supplémentaires (`avoid_dynamic_calls`, `unawaited_futures`, `discarded_futures`, `require_trailing_commas`…).
- **Raison** : le moteur d'exécution des agents manipule du JSON et de l'asynchrone ; ces règles attrapent les erreurs les plus coûteuses.
- **Alternatives** : `very_good_analysis` (dépendance de plus).

### D-003 · CI sur runner Windows
- **Décision** : GitHub Actions `windows-latest` : `flutter analyze` + `flutter test`.
- **Raison** : seule plateforme ciblée et testée en V1.
- **Alternatives** : matrice multi-plateforme (V2).

## Phase 0 — Prototypes

### D-004 · Cible visuelle du bureau vivant : l'image de référence 04

- **Décision** : le 15 novembre 2026, Armel a demandé que le design se rapproche le plus possible de l'image `inspiration_design/04-bureau-pixel-detaille-1.png` : bureau sombre et chaleureux, bois, cloisons vitrées, bibliothèques, plantes, lampes, baie de serveurs, coin café, salle de réunion, agents assis à leur poste ou en discussion, très haut niveau de détail du pixel art. C'est la référence principale de composition, de palette et de niveau de détail pour le bureau vivant (phase 5). Aucun nom, logo ni personnage de l'image n'est repris (l'enseigne visible sur l'image ne doit pas apparaître).
- **Raison** : consigne directe d'Armel.
- **Conséquence** : le premier thème construit est le thème sombre et chaleureux. Les documents disent que le thème clair et pastel est le thème par défaut (RM-52) et le seul jusqu'à la phase 11 : cet écart est à confirmer par Armel (voir les propositions ci-dessous). Le thème clair et pastel reste prévu.
- **Alternatives** : garder le thème clair et pastel en premier, comme dans le plan.

### D-005 · Prototypes construits et mesurés par la CI

- **Décision** : les prototypes Flutter sont compilés et exécutés sur le runner Windows de GitHub Actions (workflow `prototypes`) ; mesures et captures sont écrites dans le journal de l'exécution.
- **Raison** : la chaîne de compilation C++ de Windows n'est pas installée sur le poste (installation refusée deux fois par l'élévation Windows) ; Armel a choisi de continuer par la CI. Le quota d'artefacts du compte GitHub est atteint, d'où l'écriture dans le journal.
- **Alternatives** : installer Visual Studio Build Tools sur le poste (mesures avec carte graphique, application visible en mouvement) — à reprendre dès que possible.

### D-006 · Approches retenues à l'issue des prototypes

- **Bureau** : Flame, décor fixe pré-rendu, mobilier et personnages triés par profondeur (`docs/prototypes/01-salle-isometrique.md`).
- **Personnages** : une planche composée par personnage à partir de calques alignés sur une grille commune (`docs/prototypes/02-personnage-en-calques.md`).
- **Liaison** : jeton Sanctum par appareil, client maison du protocole Pusher de Reverb, canaux privés autorisés par jeton (`docs/prototypes/03-liaison-sanctum-reverb.md`).
- **Agents** : boucle écrite en Dart dans l'application, bac à sable par dossier autorisé, fournisseurs derrière une interface commune, un enregistrement de coût par appel (`docs/prototypes/04-boucle-agent.md`).

## Écran du bureau vivant

### D-007 · Un seul thème pour le bureau : sombre et chaleureux

- **Décision** : le 15 novembre 2026, Armel a tranché la question laissée ouverte par D-004 : il n'y a plus de version claire du bureau. Le thème sombre et chaleureux est le seul thème ; l'écran doit suivre les images 04 à 09 dans le moindre détail (disposition, proportions, couleurs, composants).
- **Raison** : consigne directe d'Armel.
- **Conséquence** : écart assumé à RM-52 et au plan (« deux thèmes », « thème clair par défaut ») ; le bouton « Thème : Bureau » de la barre de contrôle reste affiché comme sur la référence mais ne bascule rien. Un test cite cet écart (`test/widget_test.dart`).
- **Alternatives** : garder le thème clair pour la phase 11 (écarté par Armel).

### D-008 · Écran construit en widgets Flutter, scène dessinée par le code

- **Décision** : l'écran (`lib/live_office/`) reprend la disposition de la référence : rail d'icônes, panneau des agents, carte au centre avec étiquettes, barre de projet, zoom, minicarte et barre de contrôle en verre dépoli, panneau de conversation. La scène isométrique est dessinée par le code (`scene/office_scene.dart`), sans lissage, à 512 × 384 pixels d'art, puis agrandie sans filtrage ; quatre images d'ambiance alternent (écrans, voyants, gestes) et un agent se déplace.
- **Ce qui n'est pas repris de la référence** (consigne du `CLAUDE.md`, RM-53) : le nom et l'enseigne (remplacés par LeadDesk et son monogramme), les logos des fournisseurs de modèles (remplacés par des pictogrammes génériques), les dessins eux-mêmes (tous les graphismes sont originaux). L'interface est en français.
- **Raison** : obtenir tout de suite un écran fidèle et léger, sans attendre les planches Aseprite / Tiled.
- **Lien avec D-006** : Flame reste l'approche retenue pour le bureau de la phase 5 (agents nombreux, tri par profondeur dynamique). Le dessin actuel n'utilise que `Canvas` : il se réutilise tel quel dans un composant Flame. Les données affichées sont des données de démonstration (`DemoData`), à remplacer par l'API à partir de la phase 2.
- **Alternatives** : brancher Flame dès maintenant (plus lourd pour un écran encore statique) ; attendre les graphismes dessinés à la main.

### D-009 · Contrôle visuel par capture de test

- **Décision** : `test/tools/capture_test.dart` rend la scène et l'écran complet en PNG quand la variable `LD_CAPTURE_DIR` est définie ; sans elle, ces tests sont ignorés.
- **Raison** : la chaîne de compilation Windows manque toujours sur le poste (D-005) ; la capture permet de comparer l'écran aux images de référence avant de commiter, comme le demande le `CLAUDE.md`.
- **Alternatives** : tests « golden » versionnés (fragiles tant que le dessin évolue).

## Propositions de mise à jour des documents de conception

- `Synthese_decisions_fonctionnelles_V1.md` : y reporter les approches retenues (D-006), comme le demande le critère de fin de la phase 0.
- `REGLES_METIER_LEADDESK.md` (RM-52), `Synthese_decisions_fonctionnelles_V1.md` (section 9), `CONTEXTE_LEADDESK_CLAUDE_CODE.md`, `PLAN_DE_REALISATION_LEADDESK.md` (« un seul thème, clair et pastel, jusqu'à la phase 11 », « thème sombre » en phase 11, « calques (thème clair) ») et `inspiration_design/README.md` : remplacer les deux thèmes par un thème unique, sombre et chaleureux, avec les images 04 à 09 comme référence (D-004, D-007).
