# CLAUDE.md — leaddesk-app (application de bureau)

LeadDesk est un logiciel pour créer et piloter des entreprises d'agents IA. Ce dépôt est l'**application de bureau Flutter** (paquet `leaddesk_app`). Le serveur vit dans le dépôt frère `leaddesk-api` (dossier `../api`).

## Documentation de conception (à lire avant toute tâche importante)

Dossier : `C:\Users\armel.meledje\OneDrive\Documents\LeadDeck`

1. `PLAN_DE_REALISATION_LEADDESK.md` — feuille de route (phases 0 à 12, critères de fin).
2. `Synthese_decisions_fonctionnelles_V1.md` — décisions confirmées, propositions, sujets ouverts.
3. `REGLES_METIER_LEADDESK.md` — règles RM-01 à RM-63.
4. `CONTEXTE_LEADDESK_CLAUDE_CODE.md` — architecture confirmée.
5. `inspiration_design/` — **regarder chaque image avant tout travail d'interface** ; le rendu doit s'en rapprocher le plus possible (ambiance, composition, proportions, couleurs, détail du pixel art, interactions). S'inspirer sans reproduire : aucun nom, logo, marque ni personnage de ces images ; tous les graphismes sont originaux. Comparer chaque écran terminé aux images avant de commiter.

**Cible visuelle principale du bureau vivant (consigne d'Armel, 15 novembre 2026) :** l'image `04-bureau-pixel-detaille-1.png` — bureau sombre et chaleureux, bois, cloisons vitrées, bibliothèques, plantes, lampes, serveurs, agents à leur poste, très haut niveau de détail. Voir `docs/decisions.md` (D-004).

**Thème unique (consigne d'Armel, 15 novembre 2026) :** plus de version claire du bureau. L'interface suit les images 04 à 09 dans le moindre détail ; voir D-007 et D-008. Contrôle visuel sans lancer l'application : `test/tools/capture_test.dart` (D-009).

Ne jamais modifier ces documents : proposer les changements dans `docs/decisions.md`. Ne pas transformer une proposition en décision, ne pas inventer d'exigence.

## Rôle du dépôt et frontière serveur / application

**L'application détient** : l'interface du CEO, le bureau vivant (Flame, 2D isométrique, pixel art), le Dashboard, et le **moteur d'exécution des agents en local** (comme Claude Code) : le modèle IA est appelé à distance chez le fournisseur, les outils (fichiers, commandes, MCP locaux) agissent sur l'ordinateur hôte, dans les dossiers autorisés et avec les droits du poste.

**L'application ne détient pas** les données métier : elles vivent sur le serveur, lues et écrites par l'API `/api/v1` (jeton Sanctum) et mises à jour en temps réel par Reverb.

**Jamais** : envoyer un fichier de travail d'agent au serveur ; stocker une clé d'API dans le dépôt ou dans un dossier de projet (stockage sécurisé Windows uniquement).

## Contrat d'API

Source de vérité : `../api/docs/api/` (dépôt `leaddesk-api`). L'application s'y conforme. Un changement qui touche l'API et l'application donne un commit dans chaque dépôt, avec le même intitulé.

## Pile

Flutter (canal stable), Dart 3.13+, Flame pour le bureau. **Windows uniquement en V1** : les dossiers des autres plateformes sont conservés mais ni ciblés ni testés. Graphismes Aseprite / Tiled, personnages en calques superposés.

## Vocabulaire

Anglais dans le code, français dans l'interface et la documentation : entreprise `Company`, unité `Unit`, poste `Position`, agent `Agent`, type d'activité `ActivityType`, activité `Activity`, tâche `Task`, projet `Project`, règle `Rule`, décision `Decision`, Skill `Skill`.

## Conventions

- Répondre et documenter en français ; code et identifiants en anglais ; messages de commit courts en français, au présent.
- Travail direct sur `main` : coder → tester → corriger → retester ; commit puis push seulement quand `flutter analyze` et `flutter test` sont verts.
- Analyse stricte (`analysis_options.yaml`) : aucune alerte tolérée.
- Chaque règle métier (RM-xx) concernée par un changement est couverte par un test qui la cite.
- Les règles déclarées configurables ne sont jamais codées en dur (RM-03).
- Les prototypes vivent dans `prototypes/` (hors du code de production) et leurs comptes rendus dans `docs/prototypes/`.
- Pas de build release pendant le développement : analyse + tests suffisent, la CI construit.
- Aucune action destructive sans accord d'Armel.

## Commandes

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
dart format lib test
```

## Suivi

- `docs/decisions.md` — décisions prises pendant le code et propositions de mise à jour des documents.
- `docs/journal.md` — bilan court de chaque phase.
- `docs/prototypes/` — comptes rendus des prototypes de la phase 0.
