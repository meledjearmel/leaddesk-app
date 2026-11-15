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

## Salles et aménagement du bureau

### D-010 · Catalogue des salles, plan d'aménagement, un département par salle

- **Décision** : `lib/office/` contient le catalogue des types de salle (les 27 salles demandées par Armel le 15 novembre 2026 et 18 salles proposées en plus), le plan d'aménagement (`OfficePlan`, enregistrable en JSON) et ses règles de validation. Règle centrale, demandée par Armel : **deux départements ne partagent jamais une salle** ; seuls les lieux communs (accueil, café, sanitaires…) n'ont pas de département. Autres règles : salle dans le plan, taille minimale du type, assez de postes pour l'effectif.
- **RM-03** : les salles ne nomment aucun département ; elles servent des activités (étiquettes `code`, `tests`, `recrutement`…). Un test le vérifie.
- **Raison** : le plan de réalisation (phase 5) prévoit déjà « une salle par unité, couleur par département » et la conception du studio virtuel un aménagement par zones (Technique près de Qualité et sécurité, RH et Finances au calme).
- **Alternatives** : une seule scène dessinée à la main (impossible à faire évoluer avec l'organisation).

### D-011 · Aménageur automatique et plateau

- **Décision** : `OfficePlanner` choisit les salles de chaque département d'après ses activités et son effectif (salle de travail, plus jusqu'à deux salles spécialisées), ajoute les lieux communs selon la taille de l'entreprise, enchaîne les départements qui partagent des activités, place les départements calmes au bout, et choisit le nombre d'ailes qui donne un plateau à peu près carré. Le plateau est dessiné par `plan_scene.dart`, avec le même mobilier que la salle de référence (extrait dans `furniture.dart`) et un liseré à la couleur de chaque département. La carte s'ouvre sur le plateau ; « Vue : Salle » montre la salle détaillée de référence.
- **Raison** : demande d'Armel du 15 novembre 2026 ; c'est aussi la solution de repli quand aucune IA d'aménagement n'est disponible.
- **Limites** : les départements viennent du modèle studio (`studio_template.dart`), pas encore de l'API ; le CEO ne peut pas encore déplacer une salle à la main.

### Proposition P-001 · IA d'aménagement reliée au serveur MCP (à valider par Armel)

Comme la RH propose des agents, une IA proposerait l'aménagement. Contrat proposé, côté `leaddesk-api`, dans le MCP interne prévu en phase 6 (`laravel/mcp` est déjà installé) :

- outil `office.context` : départements (unités), effectifs, postes vacants, types d'activité, catalogue des salles, plan actuel ;
- outil `office.propose_plan` : reçoit un plan au format `OfficePlan.toJson()`, le valide avec les mêmes règles que l'application, l'enregistre comme **proposition** et renvoie les problèmes éventuels ;
- le CEO accepte ou refuse la proposition dans l'application ; le plan accepté est conservé sur le serveur (l'aménagement fait partie des designs synchronisés de `CONTEXTE_LEADDESK_CLAUDE_CODE.md`).

Questions ouvertes pour Armel : qui peut proposer un aménagement (une IA dédiée, un poste « Services généraux », la RH ?) ; le CEO doit-il approuver chaque réaménagement ; un réaménagement est-il déclenché automatiquement (embauche, nouveau département) ? Réponses le 15 novembre 2026 : voir D-012.

### D-012 · Qui propose, qui approuve, quand (réponses d'Armel à P-001)

- **Décision** (Armel, 15 novembre 2026) :
  - un **poste des Moyens généraux** propose les aménagements. Rien n'est codé en dur : la permission d'outil `office.propose_plan` est donnée au poste ;
  - le **CEO approuve chaque réaménagement**, sans exception : une proposition ne s'applique qu'après son accord ;
  - le réaménagement se **déclenche tout seul** : une embauche, un nouveau département ou un effectif qui ne tient plus dans le plan crée une demande de proposition. Rien ne s'applique sans le CEO.
- **Conséquence** : P-001 devient le contrat de travail de la gestion des salles (plan de travail dans `journal.md`).
- **Modification manuelle** : si le CEO modifie le plan alors qu'une proposition attend, la proposition est marquée « périmée ». Elle reste visible, et le CEO peut en demander une nouvelle fondée sur son plan.

### D-013 · RH et Moyens généraux toujours présents

- **Décision** (Armel, 15 novembre 2026) : toute entreprise, même vierge, naît avec deux unités, **RH** et **Moyens généraux**. Chacune contient un poste de responsable sans agent. Ces deux unités ne peuvent pas être supprimées ; leur nom et leur couleur restent modifiables.
- **Mise en œuvre** : un champ `system_role` (`hr`, `facilities`) sur l'unité. Le code s'appuie sur ce rôle, jamais sur le nom (RM-03).
- **Raison** : la RH propose les agents et les Moyens généraux proposent l'aménagement (D-012). Sans elles, l'entreprise ne peut ni recruter ni aménager.
- **Écart avec un document** : RM-02 dit qu'« une entreprise vierge existe sans unité, poste ni agent ». Cette décision en est une exception. Voir les propositions de mise à jour ci-dessous.

### D-014 · Bureau vivant branché sur le serveur

- **Décision** : `ApiOfficeSource` lit sur le serveur les départements d'aménagement (`/office/departments`, avec couleur, effectif et activités), le plan en vigueur (`/office/plan`), les unités, les postes et les agents. Un agent travaille dans les salles du département (unité de premier niveau) de son poste ; un agent sans poste n'est pas au bureau. Le plan du serveur est affiché s'il respecte les règles ; sinon (aucun plan, ou organisation changée depuis), l'aménageur automatique prend le relais. La scène se recompose à chaque nouveau jeu de données.
- **Connexion provisoire** : tant que l'écran de connexion n'existe pas, l'adresse et le jeton viennent de `LD_API_URL` et `LD_API_TOKEN` (`--dart-define` ou variable du système). Sans eux, ou si le serveur ne répond pas, l'application garde ses données de démonstration.
- **Limites** : la conversation reste en démonstration ; les portraits des agents du serveur sont attribués à tour de rôle (pas encore de personnage choisi) ; pas encore de mise à jour en temps réel (Reverb).
### D-015 · Écran de validation d'un réaménagement

- **Décision** : une proposition en attente s'annonce par un bandeau ambré sur la carte (« Réaménagement proposé par … · Examiner »). Le panneau de validation prend la place de la conversation, dans le même style que les panneaux des images 06, 07 et 09 :
  - en-tête avec pastille « En attente » ;
  - onglets « Plan actuel / Plan proposé » qui basculent aussi le plateau sur la carte ;
  - motif ;
  - aperçu vu de dessus avec les changements soulignés (vert ajoutée, rouge retirée en pointillé, ambre déplacée, bleu redimensionnée, violet change de département) ;
  - résumé chiffré et liste des changements, retraits et ajouts d'abord ;
  - contrôle des règles, avec les mêmes messages que le serveur ;
  - boutons Refuser / Accepter.
- **Règles** : « Accepter » est désactivé si le plan ne respecte pas les règles. Une confirmation est demandée quand le plan retire des salles. Après la décision, le bureau est rechargé depuis le serveur. Une erreur du serveur (par exemple une organisation changée depuis la proposition) s'affiche dans le panneau, et rien ne change.
- **Comparaison** (`PlanDiff`) : une salle garde son identifiant d'un plan à l'autre ; un changement de département l'emporte sur un changement de taille, qui l'emporte sur un déplacement.
- **Limites** : sur une fenêtre de moins de 820 px, le panneau ne tient pas ; seul l'aperçu sur la carte reste disponible. Pas de commentaire du CEO pour l'instant, même si l'API le permet.
### D-016 · Mode « Aménager » du CEO

- **Décision** : un bouton de la barre de contrôle (icône d'aménagement) remplace la scène par le plan vu de dessus, et la conversation par un panneau d'outils.
  - Un clic choisit une salle ; un glisser la déplace, aimantée à la grille et gardée dans le plan.
  - Le panneau permet de changer le département, d'agrandir ou de réduire la salle (jamais sous la taille minimale de son type) et de la retirer.
  - On ajoute une salle depuis le catalogue, rangé par famille. Elle est posée à la première place libre et attribuée au département de la salle choisie ; un lieu commun n'a jamais de département.
  - Annuler et Rétablir sont disponibles ; les règles sont vérifiées en direct (les salles qui se chevauchent sont entourées de rouge).
  - « Enregistrer » n'est possible que si le plan est valable et modifié.
- **Effet** : le plan du CEO entre en vigueur sans approbation (`PUT /office/plan`). Les propositions en attente deviennent périmées (D-012), puis le bureau est rechargé. Sans serveur, le plan s'applique à la démonstration.
- **Logique** : `PlanEditor` (lib/office), sans interface, testé à part.
- **Limites** : pas d'édition directe sur la scène isométrique (le plan vu de dessus est plus précis pour placer à la case) ; sous 820 px de large, le panneau ne tient pas et le mode ne s'affiche pas.
### D-017 · Connexion du CEO et session sur le poste

- **Décision** : au lancement, une porte d'entrée (`AppGate`) choisit l'écran.
  - Session gardée → bureau.
  - Compte sans entreprise → création de l'entreprise (nom, modèle « Studio de développement » ou « Entreprise vierge » ; RM-01, RM-02).
  - Sinon → connexion : adresse du serveur, complétée en `https://…/api/v1/` ; e-mail ; mot de passe ; lien vers la démonstration.
- **Jeton** : délivré par `POST /auth/token` pour cet appareil (« LeadDesk · nom du poste ») et gardé avec la session dans le stockage sécurisé de Windows (`flutter_secure_storage`, chiffré par le système), jamais en clair sur le disque.
- **Sortie** : la déconnexion, dans le rail d'icônes, révoque le jeton sur le serveur (`DELETE /auth/token`) et efface la session. Un jeton refusé par le serveur (401) ramène à la connexion.
- **Développement** : `LD_API_URL` et `LD_API_TOKEN` (D-014) ouvrent toujours le bureau directement, sans rien enregistrer.
- **Style** : carte centrée, dans le style des panneaux du bureau (images 06, 07 et 09), sur un fond sombre à lueur chaude ; bouton principal blanc comme « Nouvel objectif ».
- **Limites** : pas de création de compte ni de mot de passe oublié dans l'application (l'API et Fortify les permettent, à ajouter si besoin) ; un seul compte par poste.
### D-018 · Logo de LeadDesk

- **Décision** (piste choisie par Armel, 15 novembre 2026 : « grille d'agents ») : neuf postes vus de dessus sur un carreau sombre à coins arrondis. Le poste en bas à droite, plus grand, ambré et légèrement lumineux, est celui qui mène. Dessin original, dans la palette du thème unique.
- **Source unique** : `LeadDeskMarkPainter` (`lib/app/logo.dart`). Il sert au rail d'icônes, aux écrans d'accueil et à l'icône de l'application. `test/tools/icon_test.dart` (avec `LD_ICON_DIR`) génère `windows/runner/resources/app_icon.ico` (16 à 256 px) et `assets/branding/leaddesk_1024.png`.
- **Alternatives écartées** : bureau isométrique en pixel art (moins lisible en 16 px) ; monogramme « LD ».

### D-019 · Création de compte dans l'application

- **Décision** : « Créer un compte » depuis l'écran de connexion. Champs : adresse du serveur (reprise d'un écran à l'autre), nom, e-mail, mot de passe et confirmation. L'application envoie `POST /auth/register` ; le compte reçoit le jeton de l'appareil et passe directement à la création de l'entreprise.
- **Contrôles** : champs vides et confirmation différente vérifiés avant l'envoi ; les règles du serveur (e-mail déjà pris, mot de passe trop faible en production) s'affichent telles quelles.
- **Reste à faire** : mot de passe oublié.
### D-020 · Temps réel dans l'application

- **Décision** : `RealtimeClient` (`lib/api/realtime.dart`) suit le protocole Pusher de Reverb directement sur le WebSocket de Dart, sans dépendance de plus. Étapes :
  1. `GET /realtime` donne l'adresse, la clé et le canal (API D-040) ;
  2. connexion, puis `POST /broadcasting/auth` avec le jeton ;
  3. abonnement au canal privé de l'entreprise.
- **Protocole** : il répond aux `pusher:ping` et envoie lui-même un ping après le délai d'inactivité annoncé. Il ignore tout autre canal. En cas de coupure, il se reconnecte, de plus en plus espacé (1, 2, 4… jusqu'à 30 s).
- **Effet** : chaque `company.changed` recharge le bureau (départements, plan, agents, propositions), après 400 ms qui regroupent les rafales. Une proposition des Moyens généraux apparaît donc sans recharger. Si « En direct » est coupé, le rechargement attend sa reprise. L'infobulle de « En direct » donne l'état de la connexion (connecté, connexion, hors ligne).
- **Portée** : session connectée seulement ; ni la démonstration ni `LD_API_URL` sans serveur Reverb n'en ont besoin. Si Reverb n'est pas configuré, le client reste hors ligne sans gêner le reste.
- **Limites** : tout est rechargé à chaque changement, sans tri selon la ressource touchée ; c'est simple et suffisant à cette taille.
## Propositions de mise à jour des documents de conception

- `REGLES_METIER_LEADDESK.md` (RM-02) : ajouter qu'une entreprise vierge contient toujours les unités RH et Moyens généraux, chacune avec un poste de responsable sans agent (D-013).

- `Synthese_decisions_fonctionnelles_V1.md` : y reporter les approches retenues (D-006), comme le demande le critère de fin de la phase 0.
- `REGLES_METIER_LEADDESK.md` (RM-52), `Synthese_decisions_fonctionnelles_V1.md` (section 9), `CONTEXTE_LEADDESK_CLAUDE_CODE.md`, `PLAN_DE_REALISATION_LEADDESK.md` (« un seul thème, clair et pastel, jusqu'à la phase 11 », « thème sombre » en phase 11, « calques (thème clair) ») et `inspiration_design/README.md` : remplacer les deux thèmes par un thème unique, sombre et chaleureux, avec les images 04 à 09 comme référence (D-004, D-007).
