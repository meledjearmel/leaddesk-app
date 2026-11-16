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
6. App : mode « Aménager » (glisser, ajouter, retirer, attribuer, validation en direct, annulation) ; une proposition en attente devient « périmée ». **Fait** (D-016 ; 112 tests verts ; capture `amenager` comparée aux panneaux des images 06, 07 et 09).

**Bilan de la gestion des salles** : plan en vigueur et propositions sur le serveur, départements lus depuis l'API, MCP interne (`office.context`, `office.propose_plan`) pour le poste des Moyens généraux, demande automatique de réaménagement, écran de validation, aménagement à la main. Reste à faire : le moteur d'exécution local qui fera appeler le MCP par l'agent, l'écran de connexion, le temps réel (Reverb) pour voir arriver une proposition sans recharger.

## Connexion du CEO (15 novembre 2026)

**Fait** : écran de connexion, création de l'entreprise, session dans le stockage sécurisé de Windows, déconnexion dans le rail, retour à la connexion si le jeton est refusé, démonstration toujours accessible (D-017).

**Testé** : 122 tests verts (10 nouveaux, avec un faux serveur) ; captures `connexion` et `creation_entreprise` comparées au style des images 06, 07 et 09.

**Reste à faire** : création de compte et mot de passe oublié dans l'application ; temps réel (Reverb) ; moteur d'exécution local.

## Logo et création de compte (15 novembre 2026)

**Fait** : logo « grille d'agents » (D-018) dans le rail, les écrans d'accueil et l'icône Windows ; création de compte (D-019).

**Testé** : 126 tests verts ; captures `connexion`, `inscription` et `creation_entreprise` ; icône vérifiée en 256 et 32 px.

**Reste à faire** : mot de passe oublié ; temps réel (Reverb) ; moteur d'exécution local.

## Temps réel (15 novembre 2026)

**Fait** : client Reverb (protocole Pusher) avec reconnexion, rechargement du bureau à chaque changement annoncé, état dans l'infobulle « En direct » (D-020) ; route `GET /realtime` côté API (D-040).

**Testé** : 132 tests verts dans l'application (6 nouveaux, avec une fausse prise WebSocket), 270 dans l'API.

**Reste à faire** : vérifier en conditions réelles (Reverb et le worker de file lancés) ; mot de passe oublié ; moteur d'exécution local.

## Mot de passe oublié (15 novembre 2026)

**Fait** : lien, écran et envoi du lien de réinitialisation (app D-021, API D-041).

**Testé** : 134 tests verts dans l'application, 274 dans l'API ; capture `connexion`.

**Reste à faire** : moteur d'exécution local.

## Moteur d'exécution local (16 novembre 2026)

**Fait** : moteur d'agent avec Anthropic (D-022), espace de travail limité aux dossiers autorisés (D-023), clé Anthropic dans le stockage sécurisé, enregistrement du poste et signe de vie, panneau « Exécution » (choix de la tâche et de l'agent, étapes en direct, bilan), compte rendu posté dans la conversation de l'activité.

**Testé** : 148 tests verts. Les nouveaux utilisent un faux serveur et un faux modèle : lecture, livrable, refus hors dossier et lien symbolique, approbations, limite de coût, reprise, outils du bureau, poste, clé et panneau. Captures `execution_choix` et `execution_terminee`.

**Reste à faire** : essai réel avec une clé Anthropic sur le serveur de développement ; reprise d'une exécution en pause ; autres fournisseurs.

## File des décisions (16 novembre 2026)

**Fait** : panneau « Décisions » avec la pastille du nombre de demandes ouvertes ; on y approuve, refuse ou demande des précisions, et on relève une limite de coût (D-024).

**Testé** : 150 tests verts ; capture `decisions`.

**Reste à faire** : essai réel du moteur avec une clé Anthropic ; reprise d'une exécution en pause.

## Reprise des exécutions (16 novembre 2026)

**Fait** : journal local des exécutions, reprise automatique à l'ouverture, reprise après une pause du CEO, reprise dès que la limite de coût est relevée dans « Décisions », section « À reprendre » (D-025). Défaut corrigé : le coût du tour qui déclenche une pause était perdu à la reprise.

**Testé** : 153 tests verts ; capture `execution_choix`.

**Reste à faire** : essai réel du moteur avec une clé Anthropic (chaîne de compilation Windows à installer) ; suite du plan (back-office, Dashboard, activités et tâches dans l'application).
