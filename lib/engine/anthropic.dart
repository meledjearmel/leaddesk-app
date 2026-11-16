import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model.dart';

/// Erreur renvoyée par le fournisseur, en français.
class ProviderException implements Exception {
  const ProviderException(this.message, {this.status, this.retryable = false});

  final String message;
  final int? status;

  /// Vrai pour une erreur passagère (429, 5xx, réseau).
  final bool retryable;

  @override
  String toString() => 'ProviderException($status) : $message';
}

/// Tarifs Anthropic en dollars par million de jetons (entrée, sortie,
/// lecture du cache) ; l'écriture du cache coûte 1,25 fois l'entrée.
const Map<String, (double, double, double)> anthropicPrices =
    <String, (double, double, double)>{
      'claude-opus-5-5': (4, 20, 0.20),
      'claude-sonnet-5-5': (2, 10, 0.10),
      'claude-fable-5-2': (8, 40, 0.20),
    };

/// Coût réel d'un appel en millionièmes de dollar ; `null` si le modèle n'a
/// pas de tarif connu (D-030 de l'API : jamais de coût inventé).
int? anthropicCostMicros(String model, ModelUsage usage) {
  final price = anthropicPrices[model];
  if (price == null) {
    return null;
  }
  final (input, output, cacheRead) = price;
  // Dollars par million de jetons = millionièmes de dollar par jeton.
  final micros =
      usage.inputTokens * input +
      usage.outputTokens * output +
      usage.cacheReadTokens * cacheRead +
      usage.cacheWriteTokens * input * 1.25;
  return micros.round();
}

/// Adaptateur de l'API Messages d'Anthropic (D-022), en HTTP direct : Dart
/// n'a pas de SDK officiel. Réflexion adaptative, effort réglable ; la clé
/// vient du stockage sécurisé du poste et ne passe jamais par le serveur
/// LeadDesk.
class AnthropicProvider implements ModelProvider {
  AnthropicProvider({
    required this.apiKey,
    this.model = 'claude-opus-5-5',
    this.effort = 'high',
    this.maxTokens = 16000,
    http.Client? httpClient,
    Uri? baseUrl,
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? Uri.parse('https://api.anthropic.com/');

  final String apiKey;
  final String model;

  /// `low`, `medium`, `high`, `xhigh` ou `max`.
  final String effort;
  final int maxTokens;
  final http.Client _http;
  final Uri _baseUrl;

  static const String apiVersion = '2026-10-21';
  static const Duration timeout = Duration(minutes: 10);

  @override
  String get provider => 'anthropic';

  @override
  Future<ModelTurn> next({
    required String system,
    required List<ToolSpec> tools,
    required List<Map<String, Object?>> messages,
  }) async {
    final body = <String, Object?>{
      'model': model,
      'max_tokens': maxTokens,
      // Consigne et outils stables d'un tour à l'autre : mis en cache.
      'cache_control': <String, Object?>{'type': 'ephemeral'},
      'system': system,
      'thinking': <String, Object?>{'type': 'adaptive'},
      'output_config': <String, Object?>{'effort': effort},
      if (tools.isNotEmpty)
        'tools': <Map<String, Object?>>[
          for (final tool in tools) tool.toJson(),
        ],
      'messages': messages,
    };

    final http.Response response;
    try {
      response = await _http
          .post(
            _baseUrl.resolve('v1/messages'),
            headers: <String, String>{
              'x-api-key': apiKey,
              'anthropic-version': apiVersion,
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ProviderException(
        'Le modèle n\'a pas répondu à temps.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ProviderException(
        'Fournisseur IA injoignable.',
        retryable: true,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final json = decoded is Map<String, Object?>
        ? decoded
        : const <String, Object?>{};
    if (response.statusCode >= 400) {
      final error = json['error'];
      final message = error is Map<String, Object?>
          ? error['message'] as String?
          : null;
      throw ProviderException(
        switch (response.statusCode) {
          401 => 'Clé Anthropic refusée : vérifiez-la dans les réglages.',
          403 =>
            'Accès refusé par Anthropic : ${message ?? 'droits insuffisants'}.',
          429 =>
            'Trop de demandes au fournisseur : nouvelle tentative plus tard.',
          _ =>
            'Erreur du fournisseur (${response.statusCode}) : ${message ?? 'inconnue'}.',
        },
        status: response.statusCode,
        retryable:
            response.statusCode == 429 ||
            response.statusCode == 529 ||
            response.statusCode >= 500,
      );
    }
    return parseTurn(json);
  }

  /// Lit une réponse de l'API Messages.
  static ModelTurn parseTurn(Map<String, Object?> json) {
    final content = (json['content'] as List<Object?>?) ?? const <Object?>[];
    final calls = <ToolCall>[];
    final text = StringBuffer();
    for (final block in content.whereType<Map<String, Object?>>()) {
      switch (block['type']) {
        case 'text':
          text.write(block['text'] as String? ?? '');
        case 'tool_use':
          final input = block['input'];
          calls.add(
            ToolCall(
              id: block['id']! as String,
              name: block['name']! as String,
              input: input is Map<String, Object?>
                  ? input
                  : const <String, Object?>{},
            ),
          );
      }
    }
    final rawUsage = json['usage'];
    final usageJson = rawUsage is Map<String, Object?>
        ? rawUsage
        : const <String, Object?>{};
    int tokens(String key) => (usageJson[key] as num?)?.toInt() ?? 0;
    final usage = ModelUsage(
      inputTokens: tokens('input_tokens'),
      outputTokens: tokens('output_tokens'),
      cacheReadTokens: tokens('cache_read_input_tokens'),
      cacheWriteTokens: tokens('cache_creation_input_tokens'),
    );
    final model = json['model'] as String? ?? '';
    return ModelTurn(
      assistantContent: content,
      stopReason: switch (json['stop_reason']) {
        'end_turn' => StopReason.endTurn,
        'tool_use' => StopReason.toolUse,
        'max_tokens' => StopReason.maxTokens,
        'refusal' => StopReason.refusal,
        'pause_turn' => StopReason.pauseTurn,
        _ => StopReason.other,
      },
      usage: usage,
      model: model,
      text: text.toString(),
      toolCalls: calls,
      costMicros: anthropicCostMicros(model, usage),
    );
  }
}
