import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';

/// Faux serveur du back-office : données en mémoire, journal des appels.
class FakeAdminServer {
  FakeAdminServer() {
    client = MockClient(_handle);
  }

  late final http.Client client;

  /// Appels reçus : « MÉTHODE chemin » et corps.
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];

  /// Réponse d'erreur forcée pour « MÉTHODE chemin ».
  final Map<String, (int, Map<String, Object?>)> failures =
      <String, (int, Map<String, Object?>)>{};

  String companyName = 'Studio Nova';
  final List<Map<String, Object?>> units = <Map<String, Object?>>[
    <String, Object?>{
      'id': 1,
      'name': 'Technique',
      'parent_id': null,
      'kind': 'Département',
      'color': '#4C8BF5',
      'activity_tags': <String>['code'],
    },
    <String, Object?>{
      'id': 2,
      'name': 'Développement',
      'parent_id': 1,
      'kind': 'Pôle',
      'activity_tags': <String>[],
    },
    <String, Object?>{
      'id': 3,
      'name': 'Ressources humaines',
      'parent_id': null,
      'system_role': 'hr',
      'activity_tags': <String>['recrutement'],
    },
  ];
  final List<Map<String, Object?>> trashedUnits = <Map<String, Object?>>[];
  final List<Map<String, Object?>> positions = <Map<String, Object?>>[
    <String, Object?>{
      'id': 10,
      'title': 'Développeuse',
      'unit_id': 2,
      'status': 'active',
      'responsibilities': <String>['Écrire le code'],
    },
  ];
  final List<Map<String, Object?>> agents = <Map<String, Object?>>[
    <String, Object?>{
      'id': 7,
      'name': 'Inès',
      'position_id': 10,
      'status': 'active',
      'ai_models': <Map<String, Object?>>[
        <String, Object?>{'ai_model_id': 100, 'is_default': true},
      ],
    },
  ];
  final List<Map<String, Object?>> trashedAgents = <Map<String, Object?>>[];
  final List<Map<String, Object?>> providers = <Map<String, Object?>>[
    <String, Object?>{
      'id': 50,
      'name': 'Anthropic',
      'driver': 'anthropic',
      'models': <Map<String, Object?>>[
        <String, Object?>{
          'id': 100,
          'ai_provider_id': 50,
          'identifier': 'claude-opus-5-5',
          'label': 'Opus',
        },
        <String, Object?>{
          'id': 101,
          'ai_provider_id': 50,
          'identifier': 'claude-haiku-5-5',
        },
      ],
    },
  ];

  int _next = 200;

  ApiClient api() => ApiClient(
    ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
    httpClient: client,
  );

  List<String> get routes => <String>[for (final c in calls) c.$1];

  /// Appels d'écriture seulement.
  List<String> get writes => <String>[
    for (final r in routes)
      if (!r.startsWith('GET ')) r,
  ];

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    final query = request.url.query;
    final route = '${request.method} $path${query.isEmpty ? '' : '?$query'}';
    final body = request.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(request.body) as Map<String, Object?>;
    calls.add((route, body));
    if (failures[route] case (final status, final json)) {
      return _json(json, status);
    }
    final segments = path.split('/');
    Map<String, Object?>? byId(List<Map<String, Object?>> list, String id) {
      for (final item in list) {
        if ('${item['id']}' == id) {
          return item;
        }
      }
      return null;
    }

    switch ((request.method, segments)) {
      case ('GET', ['company']):
        return _data(<String, Object?>{'id': 1, 'name': companyName});
      case ('PATCH', ['company']):
        companyName = body['name']! as String;
        return _data(<String, Object?>{'id': 1, 'name': companyName});
      case ('GET', ['units']):
        return _data(query.contains('trashed') ? trashedUnits : units);
      case ('GET', ['positions']):
        return _data(query.contains('trashed') ? <Object?>[] : positions);
      case ('GET', ['agents']):
        return _data(query.contains('trashed') ? trashedAgents : agents);
      case ('GET', ['ai-providers', 'catalog']):
        return _data(<Object?>[
          <String, Object?>{'driver': 'anthropic', 'label': 'Anthropic'},
          <String, Object?>{'driver': 'openai', 'label': 'OpenAI'},
        ]);
      case ('GET', ['ai-providers']):
        return _data(providers);
      case ('GET', ['office', 'activity-tags']):
        return _data(<String>['code', 'recrutement', 'tests']);
      case ('POST', ['units']):
        final unit = <String, Object?>{...body, 'id': _next++};
        units.add(unit);
        return _data(unit, 201);
      case ('PATCH', ['units', final id]):
        final unit = byId(units, id)!..addAll(body);
        return _data(unit);
      case ('DELETE', ['units', final id]):
        final unit = byId(units, id)!;
        units.remove(unit);
        trashedUnits.add(unit);
        return http.Response('', 204);
      case ('POST', ['units', final id, 'restore']):
        final unit = byId(trashedUnits, id)!;
        trashedUnits.remove(unit);
        units.add(unit);
        return _data(unit);
      case ('POST', ['agents']):
        final agent = <String, Object?>{
          ...body,
          'id': _next++,
          'status': 'draft',
          'ai_models': <Object?>[],
        };
        agents.add(agent);
        return _data(agent, 201);
      case ('PATCH', ['agents', final id]):
        return _data(byId(agents, id)!..addAll(body));
      case ('POST', ['agents', final id, 'position']):
        return _data(byId(agents, id)!..['position_id'] = body['position_id']);
      case ('PUT', ['agents', final id, 'ai-models']):
        return _data(byId(agents, id)!..['ai_models'] = body['models']);
      case ('POST', ['agents', final id, 'activate']):
        return _data(byId(agents, id)!..['status'] = 'active');
      case ('POST', ['agents', final id, 'deactivate']):
        return _data(byId(agents, id)!..['status'] = 'draft');
      case ('POST', ['ai-providers', final id, 'models']):
        final provider = byId(providers, id)!;
        final model = <String, Object?>{
          ...body,
          'id': _next++,
          'ai_provider_id': provider['id'],
        };
        (provider['models']! as List<Map<String, Object?>>).add(model);
        return _data(model, 201);
    }
    return _json(<String, Object?>{'message': 'Introuvable : $route'}, 404);
  }

  static http.Response _data(Object? data, [int status = 200]) =>
      _json(<String, Object?>{'data': data}, status);

  static http.Response _json(Map<String, Object?> json, int status) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(json)),
        status,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
}
