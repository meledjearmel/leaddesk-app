# Journal — leaddesk-app

Bilan court de chaque étape et de chaque phase : fait, testé, reste à faire.

## Étape A — Dépôts et outillage (15 novembre 2026)

**Fait**
- Dépôt git indépendant, dépôt GitHub privé `leaddesk-app`.
- Paquet renommé `leaddesk_app`, binaire Windows `leaddesk.exe`, fenêtre « LeadDesk ».
- Analyse stricte, socle d'application minimal, CI Windows (analyse + tests).
- `CLAUDE.md`, `docs/decisions.md`, `docs/journal.md`.

**Testé**
- `flutter analyze` sans alerte, `flutter test` vert.

**Reste à faire**
- Prototypes de la phase 0 dans `prototypes/`.

## Phase 0 — Prototypes de validation (15 novembre 2026)

**Fait**

- Prototype 1, salle isométrique Flame : 64 images par seconde avec 30 agents, 63 avec 100, 37 à 46 avec 300, sur une machine virtuelle à 2 cœurs sans carte graphique.
- Prototype 2, personnage en calques : changement d'un calque en 1 ms environ, sans interrompre l'animation.
- Prototype 3, liaison Sanctum + Reverb : parcours réel validé, 59 ms de latence médiane entre le ping et l'événement.
- Prototype 4, boucle d'agent : appel du modèle, outil de lecture confiné au dossier autorisé, registre des coûts.
- Comptes rendus dans `docs/prototypes/`, approches retenues dans `docs/decisions.md` (D-006).

**Testé**

- 37 tests automatiques verts, analyse stricte sans alerte.
- Prototypes 1 et 2 exécutés sous Windows par la CI (mesures et captures) ; prototype 3 exécuté sur le poste contre Laravel et Reverb réels.

**Critère de fin : atteint avec trois réserves**

- Prototype 4 validé contre un faux fournisseur seulement : l'appel réel et son coût restent à relever quand une clé existe (au plus tard en phase 4).
- Prototypes 1 et 2 vus par capture et non en mouvement, sans carte graphique ; fenêtre du prototype 3 non lancée. À rejouer quand Visual Studio Build Tools est installé sur le poste.
- Les approches retenues sont notées dans `docs/decisions.md` et proposées pour la synthèse, que je ne modifie pas.

**Reste à faire**

- Confirmer avec Armel que le thème sombre et chaleureux (image 04) passe en premier (D-004).
