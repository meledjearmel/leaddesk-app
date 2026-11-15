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
