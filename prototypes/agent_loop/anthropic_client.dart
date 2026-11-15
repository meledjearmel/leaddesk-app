import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pricing.dart';

/// Erreur renvoyée par le fournisseur (statut HTTP hors 2xx).
class ProviderException implements Exception {
  ProviderException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  /// 429 et 5xx peuvent être retentés ; 4xx demandent de corriger la requête.
  bool get isRetryable => statusCode == 429 || statusCode >= 500;

  @override
  String toString() => 'ProviderException($statusCode): $body';
}

/// Réponse d'un appel à l'API Messages.
class ModelResponse {
  const ModelResponse({
    required this.id,
    required this.model,
    required this.stopReason,
    required this.content,
    required this.usage,
  });

  factory ModelResponse.fromJson(Map<String, Object?> json) {
    return ModelResponse(
      id: json['id'] as String? ?? '',
      model: json['model'] as String? ?? '',
      stopReason: json['stop_reason'] as String? ?? '',
      content: <Map<String, Object?>>[
        for (final block in json['content'] as List<Object?>? ?? <Object?>[])
          block! as Map<String, Object?>,
      ],
      usage: TokenUsage.fromJson(
        json['usage'] as Map<String, Object?>? ?? <String, Object?>{},
      ),
    );
  }

  final String id;

  /// Modèle qui a réellement répondu (peut différer du modèle demandé si le
  /// repli côté serveur a joué) : c'est lui qui fixe le tarif.
  final String model;
  final String stopReason;

  /// Blocs de contenu bruts, à renvoyer tels quels au tour suivant (les blocs
  /// de réflexion doivent rester inchangés).
  final List<Map<String, Object?>> content;
  final TokenUsage usage;

  /// Texte visible de la réponse.
  String get text => content
      .where((block) => block['type'] == 'text')
      .map((block) => block['text']! as String)
      .join('\n');

  Iterable<Map<String, Object?>> get toolUses =>
      content.where((block) => block['type'] == 'tool_use');
}

/// Client HTTP minimal de l'API Messages d'Anthropic. Dart n'a pas de SDK
/// officiel : les appels sont faits en HTTP direct.
class AnthropicClient {
  AnthropicClient({
    required this._apiKey,
    http.Client? httpClient,
    Uri? endpoint,
  }) : _http = httpClient ?? http.Client(),
       _endpoint =
           endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages');

  static const String apiVersion = '2026-10-21';
  static const String fallbackBeta = 'server-side-fallback-2026-07-01';

  final String _apiKey;
  final http.Client _http;
  final Uri _endpoint;

  Future<ModelResponse> createMessage({
    required String model,
    required String system,
    required List<Map<String, Object?>> messages,
    required List<Map<String, Object?>> tools,
    String effort = 'low',
    int maxTokens = 16000,
  }) async {
    final response = await _http.post(
      _endpoint,
      headers: <String, String>{
        'content-type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': apiVersion,
        'anthropic-beta': fallbackBeta,
      },
      body: jsonEncode(<String, Object?>{
        'model': model,
        'max_tokens': maxTokens,
        'output_config': <String, Object?>{'effort': effort},
        // En cas de refus des filtres de sécurité, le serveur choisit lui-même
        // un modèle de repli.
        'fallbacks': 'default',
        'system': system,
        'tools': tools,
        'messages': messages,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProviderException(response.statusCode, response.body);
    }
    return ModelResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>,
    );
  }

  void close() => _http.close();
}
