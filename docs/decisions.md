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

## Propositions de mise à jour des documents de conception

- `Synthese_decisions_fonctionnelles_V1.md` : y reporter les approches retenues (D-006), comme le demande le critère de fin de la phase 0.
- `REGLES_METIER_LEADDESK.md` (RM-52), `PLAN_DE_REALISATION_LEADDESK.md` (principe « un seul thème, clair et pastel, jusqu'à la phase 11 ») et `inspiration_design/README.md` : si Armel le confirme, le thème sombre et chaleureux devient le premier thème construit, avec l'image 04 comme référence principale (D-004).
