# Prompt : vue « Salle », le bureau complet d'un département

À coller tel quel au début d'une nouvelle session Claude Code, ouverte dans
`C:\Users\armel.meledje\PhpstormProjects\leaddesk\apps`.

---

Tu reprends LeadDesk, l'application Flutter de bureau (Windows) du dépôt `leaddesk-app`, dans `C:\Users\armel.meledje\PhpstormProjects\leaddesk\apps`. L'API Laravel est dans `..\api` (dépôt `leaddesk-api`).

**Règles de travail (obligatoires)**
- Tout en français avec moi ; code et identifiants en anglais.
- Messages de commit courts, en français, au présent.
- Avant chaque commit : `flutter analyze` sans erreur et `flutter test` vert. Pas de build release.
- Contrôle visuel par capture, sans lancer l'application : `$env:LD_CAPTURE_DIR='<dossier>'` puis `flutter test test/tools/capture_test.dart`. Regarde chaque capture produite et corrige jusqu'à ce que le rendu soit juste.
- Aucune action destructive sans mon accord. Une autre session travaille parfois dans `api/` : ne commite que tes propres fichiers.
- Note chaque décision dans `docs/decisions.md` (prochain numéro libre après D-032) et chaque étape dans `docs/journal.md`. Lis d'abord ces deux fichiers, surtout D-016, D-028, D-031 et D-032.
- RM-03 : rien n'est codé en dur. Les départements, unités, postes et agents viennent du serveur. RM-53 : personnages et décor originaux, aucune reprise d'un jeu existant.
- Documents de conception, en lecture seule : `C:\Users\armel.meledje\OneDrive\Documents\LeadDeck`. Les images de référence de style sont `04-bureau-pixel-detaille-1.png` et `05-bureau-pixel-detaille-2.png`.

**Ce que je veux**

Aujourd'hui, la vue « Salle » (bouton « Vue : Salle » de la barre du bas) montre toujours la même salle de référence, dessinée à la main dans `lib/live_office/scene/office_scene.dart`. Elle ne représente pas mon entreprise. Je veux qu'en entrant dans un département (fil d'Ariane « Bureau › Technique », D-028), la vue « Salle » montre **le bureau complet de ce département, en détail**, comme sur les images 04 et 05 :

1. **Toutes ses salles réunies** : celles que le plan d'aménagement attribue au département (open space, salle de réunion, salle des serveurs, atelier, coin café…), avec des cloisons vitrées, des portes, des couloirs et un sol en parquet ou en moquette selon la salle.
2. **Un mobilier dense et varié** selon le type de salle et les activités de l'unité : bureaux avec écrans et lampes, chaises, bibliothèques, plantes, tableaux blancs avec post-it, armoires de serveurs, fontaine à eau, machine à café, tapis, table de réunion avec ordinateurs portables. Il faut le même niveau de détail et la même chaleur que les images 04 et 05 (bois, lumière chaude des lampes, verre sombre).
3. **Généré, pas figé** : construit à partir de `OfficePlan` (`lib/office/office_plan.dart`, `PlacedRoom`), du catalogue des salles (`lib/office/room_catalog.dart`) et de l'organisation.
   - Autant de postes de travail que de postes du département.
   - Chaque agent est assis à son poste.
   - Un poste vacant reste un bureau vide, chaise rentrée (D-031).
   - Le rendu doit être déterministe : la même organisation donne le même bureau.
4. **Des agents vivants selon leur état réel** (`AgentState` dans `lib/live_office/models.dart`) :
   - au travail : assis, écran allumé ;
   - attend une décision ou en limite de coût : debout près de son bureau ;
   - en pause ou disponible : au café ou en train de circuler, sur des chemins simples.
   - Personnages en pixel art d'après `lib/live_office/scene/pixel_people.dart`.
5. **Un pixel art net** :
   - même résolution d'art que le plateau ;
   - affichage par `OfficeFrames` et `OfficeCamera`, qui arrondissent déjà l'agrandissement à un nombre entier de pixels physiques (D-031) ;
   - pas plus de 3 points par pixel d'art (D-032) ;
   - à l'ouverture, toute la salle doit être visible, cadrée comme sur les images.
6. **Les étiquettes suivent D-032** : une pastille au-dessus de chaque agent, et une étiquette seulement pour ce qui compte (attention requise, sélection, survol, conversation, et les noms des agents de la salle de près). Elles ne se chevauchent pas et ne passent jamais sous les barres (`DeclutteredTags`, `mapSafeArea`).
7. **Navigation** :
   - les flèches du fil d'Ariane passent au département suivant ou précédent en vue « Salle » aussi ;
   - sans département visité, « Vue : Salle » ouvre le premier département ;
   - « Vue : Plateau » ramène au plateau sur le même département ;
   - un clic sur un agent ouvre sa fiche (D-029).
8. **Performance** :
   - les images sont rendues une fois par département et par jeu de données, comme `OfficeFrames.plateau`, et libérées en quittant le département ;
   - la salle de référence actuelle peut rester pour la démonstration si elle sert encore, sinon remplace-la.

**Repères dans le code**
- `lib/live_office/scene/plan_scene.dart` : `PlanGeometry` (postes, emprise d'un département), `PlanScenePainter` (rendu du plateau, base réutilisable : sols, cloisons, meubles, personnes).
- `lib/live_office/scene/furniture.dart` : la boîte à meubles.
- `lib/live_office/scene/office_scene.dart` : la salle de référence actuelle et `OfficeLayout`.
- `lib/live_office/widgets/office_view.dart` : `OfficeFrames`, `OfficeView`, minicarte.
- `lib/live_office/live_office_screen.dart` :
  - `_syncScene` (changement de scène et de caméra) ;
  - `_feetOf` (position des agents pour les étiquettes) ;
  - `_roomSpots` (places actuelles en vue « Salle », à remplacer par les vrais postes).
- `lib/live_office/live_office_controller.dart` : `OfficeViewMode`, `focusedDepartment`, `stepDepartment`, `tagMode`.
- `lib/live_office/widgets/map_overlays.dart` : `AgentTagLayer` (`showsTag`), `DepartmentTagLayer`, `DepartmentNavigator`.

**Démarche attendue**
1. Lis le code ci-dessus et les images 04 et 05. Puis décris-moi en quelques lignes le plan de rendu, la composition et le découpage en étapes, et attends mon accord avant de coder.
2. Avance par étapes, chacune testée et vérifiée sur capture (une capture par étape, par exemple `salle_technique.png`, `salle_produit.png`) :
   1. salles assemblées ;
   2. mobilier dense ;
   3. agents à leur poste selon leur état ;
   4. déplacements simples ;
   5. navigation.
3. Ajoute des tests :
   - génération déterministe ;
   - un poste par poste du département ;
   - un poste vacant reste vide ;
   - les agents sont à leur place ;
   - la navigation fonctionne en vue « Salle ».
4. Commite et pousse sur `main` quand tout est vert, puis fais-moi un bilan court avec les captures.
