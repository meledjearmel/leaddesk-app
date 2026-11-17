import 'dart:convert';

import 'package:http/http.dart' as http;

/// Modèle proposé par le compte du CEO chez un fournisseur.
typedef RemoteModel = ({String identifier, String? label});

/// Erreur de lecture d'un catalogue, au message prêt à afficher. Il ne
/// contient jamais la clé.
class CatalogException implements Exception {
  const CatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lit la liste des modèles d'un fournisseur avec la clé du CEO (D-027).
///
/// L'appel part de cet ordinateur vers le fournisseur : la clé ne passe
/// jamais par le serveur LeadDesk.
class ModelCatalog {
  ModelCatalog([http.Client? client]) : _http = client ?? http.Client();

  final http.Client _http;

  static const Duration timeout = Duration(seconds: 20);

  /// Adresse de la liste des modèles, pour les fournisseurs compatibles
  /// OpenAI (`GET …/models`, en-tête `Authorization: Bearer`).
  static const Map<String, String> openAiCompatible = <String, String>{
    'openai': 'https://api.openai.com/v1/models',
    'openrouter': 'https://openrouter.ai/api/v1/models',
    'mistral': 'https://api.mistral.ai/v1/models',
    'groq': 'https://api.groq.com/openai/v1/models',
    'nvidia': 'https://integrate.api.nvidia.com/v1/models',
    'deepseek': 'https://api.deepseek.com/models',
    'together': 'https://api.together.xyz/v1/models',
    'fireworks': 'https://api.fireworks.ai/inference/v1/models',
    'deepinfra': 'https://api.deepinfra.com/v1/openai/models',
    'cerebras': 'https://api.cerebras.ai/v1/models',
    'huggingface': 'https://router.huggingface.co/v1/models',
  };

  /// Vrai si l'import est possible pour ce type, avec cette adresse.
  static bool supports(String driver, String? baseUrl) =>
      driver == 'anthropic' ||
      driver == 'google' ||
      openAiCompatible.containsKey(driver) ||
      (baseUrl != null && baseUrl.trim().isNotEmpty);

  Future<List<RemoteModel>> fetch({
    required String driver,
    required String providerName,
    required String key,
    String? baseUrl,
  }) async {
    final custom = baseUrl?.trim() ?? '';
    final List<RemoteModel> models;
    try {
      models = switch (driver) {
        'anthropic' => await _anthropic(key, custom, providerName),
        'google' => await _google(key, custom, providerName),
        _ => await _openAi(
          custom.isNotEmpty
              ? '${custom.replaceFirst(RegExp(r'/+$'), '')}/models'
              : openAiCompatible[driver] ??
                    (throw const CatalogException(
                      'Indiquez l\'adresse de l\'API de ce fournisseur pour '
                      'importer ses modèles.',
                    )),
          key,
          providerName,
        ),
      };
    } on CatalogException {
      rethrow;
    } on Object {
      throw CatalogException('$providerName est injoignable.');
    }
    final seen = <String>{};
    return <RemoteModel>[
      for (final m in models)
        if (m.identifier.isNotEmpty && seen.add(m.identifier)) m,
    ]..sort((a, b) => a.identifier.compareTo(b.identifier));
  }

  Future<List<RemoteModel>> _anthropic(
    String key,
    String custom,
    String name,
  ) async {
    final base = custom.isNotEmpty
        ? custom.replaceFirst(RegExp(r'/+$'), '')
        : 'https://api.anthropic.com/v1';
    final result = <RemoteModel>[];
    String? after;
    for (var page = 0; page < 20; page++) {
      final json = await _get(
        Uri.parse(
          '$base/models?limit=1000${after == null ? '' : '&after_id=$after'}',
        ),
        <String, String>{'x-api-key': key, 'anthropic-version': '2023-06-01'},
        name,
      );
      for (final m in _list(json['data'])) {
        result.add((
          identifier: m['id'] as String? ?? '',
          label: m['display_name'] as String?,
        ));
      }
      if (json['has_more'] != true || json['last_id'] is! String) {
        break;
      }
      after = json['last_id']! as String;
    }
    return result;
  }

  Future<List<RemoteModel>> _google(
    String key,
    String custom,
    String name,
  ) async {
    final base = custom.isNotEmpty
        ? custom.replaceFirst(RegExp(r'/+$'), '')
        : 'https://generativelanguage.googleapis.com/v1beta';
    final result = <RemoteModel>[];
    String? token;
    for (var page = 0; page < 20; page++) {
      final json = await _get(
        Uri.parse(
          '$base/models?pageSize=1000'
          '${token == null ? '' : '&pageToken=${Uri.encodeQueryComponent(token)}'}',
        ),
        <String, String>{'x-goog-api-key': key},
        name,
      );
      for (final m in _list(json['models'])) {
        final methods = m['supportedGenerationMethods'];
        // Seuls les modèles qui génèrent du texte servent aux agents.
        if (methods is List<Object?> && !methods.contains('generateContent')) {
          continue;
        }
        result.add((
          identifier: (m['name'] as String? ?? '').replaceFirst('models/', ''),
          label: m['displayName'] as String?,
        ));
      }
      token = json['nextPageToken'] as String?;
      if (token == null || token.isEmpty) {
        break;
      }
    }
    return result;
  }

  Future<List<RemoteModel>> _openAi(String url, String key, String name) async {
    final json = await _get(Uri.parse(url), <String, String>{
      'Authorization': 'Bearer $key',
    }, name);
    return <RemoteModel>[
      for (final m in _list(json['data'] ?? json['models'] ?? json[r'$list']))
        (
          identifier: m['id'] as String? ?? '',
          label: (m['name'] ?? m['display_name']) as String?,
        ),
    ];
  }

  Future<Map<String, Object?>> _get(
    Uri uri,
    Map<String, String> headers,
    String name,
  ) async {
    final response = await _http
        .get(
          uri,
          headers: <String, String>{'accept': 'application/json', ...headers},
        )
        .timeout(timeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CatalogException(
        'Clé refusée par $name. Vérifiez-la, ou ses droits.',
      );
    }
    if (response.statusCode >= 400) {
      throw CatalogException(
        '$name a répondu par une erreur (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    // Certains fournisseurs renvoient directement une liste.
    return decoded is Map<String, Object?>
        ? decoded
        : <String, Object?>{r'$list': decoded};
  }

  static List<Map<String, Object?>> _list(Object? value) =>
      <Map<String, Object?>>[
        if (value is List<Object?>)
          for (final item in value)
            if (item is Map<String, Object?>) item,
      ];

  void close() => _http.close();
}
