# Prototype 3 — Liaison application–serveur (Sanctum + Reverb)

**Date :** 15 novembre 2026 · **Code :** `prototypes/realtime/` (application) et `prototypes/realtime/` du dépôt `leaddesk-api` (serveur).

## But

Vérifier, sur Windows, que l'application peut s'authentifier auprès du serveur Laravel avec un jeton Sanctum, puis recevoir un événement diffusé par Reverb sur un canal privé.

## Ce qui a été construit

- **Serveur** (chargé seulement si `PROTOTYPES_ENABLED=true`) :
  - `POST /api/prototypes/realtime/token` : e-mail + mot de passe → jeton Sanctum et nom du canal privé du compte ;
  - `POST /api/prototypes/realtime/ping` (jeton requis) : diffuse `prototype.ping` sur `private-prototypes.user.{id}` ;
  - `POST /api/broadcasting/auth` protégé par `auth:sanctum` : signature de l'abonnement au canal privé.
- **Application** :
  - `reverb_client.dart` : client HTTP du prototype et client minimal du protocole Pusher parlé par Reverb (connexion, abonnement privé signé, réception, réponse `pusher:pong`), en Dart pur (`dart:io`) ;
  - `cli.dart` : enchaîne tout le parcours en ligne de commande et mesure les temps ;
  - `main.dart` : fenêtre Flutter (connexion, bouton « Envoyer un ping », journal des événements).

## Résultat

Le parcours complet fonctionne contre un serveur Laravel et un serveur Reverb réels, lancés en local sous Windows 11 :

| Étape | Temps mesuré |
|---|---|
| Connexion Sanctum (premier appel, serveur à froid) | 1 494 ms |
| Connexion WebSocket à Reverb | 50 ms |
| Abonnement au canal privé (signature comprise) | 64 ms |
| Ping → événement reçu, 5 essais | médiane 59 ms, maximum 103 ms |

Tests automatiques :

- application : 6 tests (`test/prototypes/reverb_client_test.dart`), dont le parcours complet contre un faux serveur local (API + protocole Pusher) ;
- serveur : 5 tests (`tests/Feature/Prototypes/RealtimePrototypeTest.php`).

## Limite de la vérification

Le parcours a été exécuté avec la machine virtuelle Dart de Flutter sous Windows (`dart run prototypes/realtime/cli.dart`), qui utilise la même pile réseau `dart:io` qu'une application Flutter de bureau. **La fenêtre `main.dart` n'a pas encore été lancée** : la chaîne de compilation C++ de Windows (Visual Studio Build Tools) n'est pas installée sur le poste. À relancer dès qu'elle l'est.

## Difficultés

- L'installateur de Reverb ajoute une configuration Echo au front React sans installer le paquet Node : retirée, la page publique n'a pas besoin du temps réel.
- Reverb envoie la charge utile en JSON **dans une chaîne** (`"data": "{...}"`) : il faut décoder deux fois.
- La route d'autorisation des canaux est enregistrée par défaut avec le middleware `web` (session) : pour l'application il faut l'enregistrer avec `auth:sanctum`, ici sous `/api/broadcasting/auth`.
- Le premier appel après le démarrage du serveur est lent (démarrage du cadre + hachage du mot de passe) ; les suivants prennent quelques dizaines de millisecondes.

## Approche retenue pour la suite

- **Authentification** : jeton Sanctum par appareil (`device_name`), envoyé en `Authorization: Bearer`. Le jeton sera gardé dans le stockage sécurisé de Windows.
- **Temps réel** : client maison du protocole Pusher sur `dart:io`, une centaine de lignes, sans dépendance. Il sera repris dans `lib/` avec en plus la reconnexion automatique, le réabonnement et la détection d'inactivité (`activity_timeout`), absents du prototype.
- **Canaux** : privés, autorisés par `POST /api/broadcasting/auth` avec le jeton. Un canal par entreprise est à prévoir en phase 2.
- **Diffusion** : `ShouldBroadcastNow` pour le prototype ; en production les événements passeront par la file d'attente.

**Alternative écartée :** un paquet tiers de client Pusher (par exemple `dart_pusher_channels`). Le protocole utile est petit et le garder chez nous évite une dépendance sur le chemin critique ; à reconsidérer si la reconnexion maison se révèle fragile.
