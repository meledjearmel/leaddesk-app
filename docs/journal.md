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

- ~~Confirmer avec Armel que le thème sombre et chaleureux (image 04) passe en premier (D-004).~~ Tranché le 15 novembre 2026 : thème sombre unique (D-007).

## Écran du bureau vivant (15 novembre 2026)

**Fait**

- Thème sombre unique (D-007) et écran complet d'après les images 04 à 09 : rail, panneau des agents (recherche, groupes par poste), carte isométrique en pixel art dessinée par le code, étiquettes et bulles accrochées aux agents, barre de projet, zoom, minicarte, barre de contrôle (pause, direct, vitesse), panneau de conversation (fil, contexte partagé, envoi).
- Déplacement et zoom de la carte bornés (jamais de vide), disposition qui s'adapte à la largeur de la fenêtre, animations coupées si le système le demande.
- Outil de capture pour le contrôle visuel (D-009).

**Testé**

- 56 tests verts (dont 19 nouveaux), analyse stricte sans alerte.
- Écran comparé aux images de référence par capture en 1440 × 900 et 1920 × 1080.

**Réserves**

- Écran vu par capture seulement : jamais lancé sous Windows sur le poste (D-005). Le survol, le glisser et la molette sont couverts par les tests de la caméra, pas par un essai à la main.
- Données de démonstration ; aucun appel à l'API.
- Les boutons sans fonction derrière eux (rail, « Connecter un agent », « Nouvel objectif », choix du projet) sont affichés mais inactifs.

## Salles et plateau (15 novembre 2026)

**Fait**

- Catalogue de 45 types de salle (les 27 demandés, 18 proposés), plan d'aménagement en JSON avec validation (un département par salle), aménageur automatique (D-010, D-011).
- Mobilier extrait dans une bibliothèque réutilisable, enrichie (canapé, lits, arcade, gradins, casiers, photocopieur, cabine d'appel, paillasses, chevalets…) ; la salle de référence reste identique au pixel près.
- Plateau composé à partir du plan : salles vitrées, liseré et étiquette par département, postes vacants visibles, lieux communs en bout d'aile. Bascule « Vue : Plateau / Salle ».

**Testé**

- 74 tests verts, analyse stricte sans alerte ; captures du plateau à 2 et 6 personnes par département et de l'écran en 1440 et 1920.

**Reste à faire**

- IA d'aménagement par le MCP (proposition P-001, à valider) ; départements et plan venant de l'API ; déplacement des salles par le CEO.

## Gestion des salles et aménagement par le MCP : plan de travail (validé le 15 novembre 2026)

Décisions : D-012, D-013. Ordre : 0 → 1 → 2 → 5 → 3 → 4 → 6. Chaque étape se termine par une revue, des tests verts et un commit dans chaque dépôt touché.

0. API : unités système RH et Moyens généraux (`system_role`), créées avec chaque entreprise et impossibles à supprimer. **Fait** (API D-034, 223 tests verts).
1. API : plans d'aménagement sur le serveur (`office_plans`, versions, états, validateur PHP identique à celui de l'app, catalogue servi par l'API, routes accepter / refuser / modifier, audit, Reverb). **Fait** (API D-036, 246 tests verts). Côté app : test de parité avec le serveur (catalogue et cas de validation), et `OfficePlan.validate` ne plante plus sur un type de salle inconnu. Le catalogue compte 44 types (27 demandés, 17 proposés), et non 45.
2. App : départements, postes et agents lus depuis l'API ; le plateau charge le plan accepté. **Fait** (app D-014, API D-037 : activités des unités ; 87 tests verts dans l'app, 248 dans l'API ; écran de démonstration inchangé à la capture).
5. App : écran de validation de la proposition (comparaison, motif, problèmes, Accepter / Refuser). **Fait** (D-015 ; 98 tests verts ; captures `proposition_bandeau` et `proposition_apercu` comparées aux images 06, 07 et 09).
3. API : MCP interne, outils `office.context` et `office.propose_plan`, permission donnée au poste des Moyens généraux, proposition → `Decision` en attente. **Fait** (API D-038, `/mcp/leaddesk` ; 259 tests verts). L'application n'appelle pas encore le MCP : ce sera le rôle du moteur d'exécution des agents.
4. API : déclenchement automatique (embauche, nouvelle unité, capacité dépassée), demandes regroupées. **Fait** (API D-039 : mission `office_layout` au poste qui a l'outil ; 267 tests verts).
6. App : mode « Aménager » (glisser, ajouter, retirer, attribuer, validation en direct, annulation) ; une proposition en attente devient « périmée ».
