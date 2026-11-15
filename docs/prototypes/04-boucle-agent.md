# Prototype 4 — Boucle d'agent minimale

**Date :** 15 novembre 2026 · **Code :** `prototypes/agent_loop/` · **Tests :** `test/prototypes/agent_loop_test.dart`.

## But

Depuis l'application, appeler un fournisseur IA, lui donner un outil « lire un fichier » limité à un dossier autorisé, récupérer la réponse et enregistrer le coût réel de chaque appel.

## Ce qui a été construit

- `sandbox.dart` — `AllowedFolder` : toute lecture est confinée au dossier autorisé. Refus des chemins absolus, des remontées par `..`, des liens symboliques qui sortent du dossier, des fichiers absents ou trop gros (200 Ko par défaut).
- `anthropic_client.dart` — appel HTTP direct à l'API Messages d'Anthropic (Dart n'a pas de SDK officiel) : version d'API `2026-10-21`, modèle `claude-opus-5-5` par défaut, effort `low`, outil déclaré en mode strict, repli côté serveur en cas de refus des filtres de sécurité (`fallbacks: "default"`).
- `agent_loop.dart` — la boucle : appel du modèle, exécution locale des demandes d'outil, renvoi des résultats, jusqu'à la réponse finale. Garde-fou de 8 appels. Chaque appel est écrit dans un registre (`CostLedger`, une ligne JSON par appel) ; chaque lecture, acceptée ou refusée, est tracée (`ToolAction`).
- `pricing.dart` — grille tarifaire en dollars par million de jetons, passée en paramètre (une donnée de configuration, pas une constante du moteur).
- `cli.dart` — lancement en ligne de commande ; la clé est lue dans `ANTHROPIC_API_KEY`, jamais dans le dépôt.

## Résultat

**Validé contre un faux fournisseur uniquement.** Les 14 tests rejouent des réponses au format de l'API et vérifient :

| Vérification | Résultat |
|---|---|
| Lecture d'un fichier du dossier autorisé, sous-dossiers compris | OK |
| Sortie par `..`, chemin absolu (`/etc/passwd`, `C:\Windows\win.ini`), fichier absent, trop gros | refusés |
| Refus transmis au modèle (`is_error`), sans fuite du contenu interdit | OK |
| Contenu de l'assistant renvoyé inchangé au tour suivant (réflexion comprise) | OK |
| Coût calculé à partir des jetons : 1 000 + 2 000 en entrée, 100 + 50 en sortie → 0,015 $ | OK |
| Coût chiffré au tarif du modèle qui a réellement répondu (repli) | OK |
| Modèle sans tarif connu : appel enregistré « non chiffré », pas de coût inventé | OK |
| Arrêt sur refus du modèle, sur limite d'appels, remontée des erreurs du fournisseur | OK |

## Ce qui n'a pas été fait

- **Aucun appel réel à un fournisseur.** Aucune clé n'était disponible sur le poste ; Armel a choisi de reporter l'appel réel. Les mesures attendues (coût réel d'une demande, durée d'un appel, nombre de jetons) restent donc à relever. À rejouer dès qu'une clé existe, au plus tard au début de la phase 4 :

  ```bash
  setx ANTHROPIC_API_KEY "..."   # une fois, hors dépôt
  dart run prototypes/agent_loop/cli.dart --folder=<dossier> --task="Résume brief.md en trois points."
  ```

- **Pas de fenêtre Flutter** pour ce prototype : la boucle est du Dart pur, identique dans une fenêtre et en ligne de commande. L'interface viendra avec la phase 4.
- Les tarifs d'écriture en cache (1,25 fois l'entrée) sont une hypothèse à confirmer ; le prototype n'utilise pas le cache.

## Difficultés

- Sous Windows, un chemin peut s'écrire avec `/` ou `\` et un chemin « absolu » peut commencer par une lettre de lecteur ou par une barre : les deux formes sont refusées explicitement, puis le chemin réel est comparé au dossier autorisé.
- Les modèles récents renvoient des blocs de réflexion qu'il faut renvoyer tels quels au tour suivant : la boucle conserve le contenu brut de l'assistant au lieu de n'en garder que le texte.
- Le modèle qui répond peut ne pas être celui demandé (repli) : le coût doit se calculer sur le champ `model` de la réponse.

## Approche retenue pour la suite

- **Boucle écrite à la main en Dart**, dans l'application : appel distant du modèle, outils exécutés en local. Elle tournera hors du fil d'interface (isolat) pour ne pas gêner le bureau vivant.
- **Bac à sable par dossier autorisé**, vérifié sur le chemin réel ; il sera étendu à plusieurs dossiers par projet et aux droits du poste (phase 4).
- **Fournisseurs derrière une interface commune** (`createMessage` → contenu, motif d'arrêt, usage) : Anthropic d'abord, les autres ensuite, puisque l'entreprise peut en connecter plusieurs (RM-10).
- **Coûts** : un enregistrement par appel avec modèle réel, jetons, coût et durée, envoyé au serveur et rattaché à l'agent, la tâche, l'activité et le projet (RM-35). La grille tarifaire est servie par le serveur ; un modèle sans tarif reste « non chiffré ».
- **Clés** : stockage sécurisé de Windows, jamais dans un dépôt ni dans un dossier de projet.
- **À ajouter en phase 4** : diffusion en continu de la réponse, reprise après erreur réseau (429 et 5xx retentés), cache de requêtes, limite de coût avec pause (RM-36), permissions d'exécution par poste.
