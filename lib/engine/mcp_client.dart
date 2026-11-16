import 'dart:convert';

import '../api/api_client.dart';

/// Réponse d'un outil MCP.
class McpResult {
  const McpResult(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// Client du MCP interne de LeadDesk (`/mcp/leaddesk`, API D-038), au nom
/// d'un agent : même jeton que l'API, agent dans `X-LeadDesk-Agent`.
class LeadDeskMcp {
  LeadDeskMcp(this.api);

  /// Client d'API déjà placé au nom de l'agent ([ApiClient.asAgent]).
  final ApiClient api;
  int _id = 0;

  Uri get endpoint => api.config.baseUrl.resolve('/mcp/leaddesk');

  Future<McpResult> call(String tool, Map<String, Object?> arguments) async {
    final response = await api.httpClient
        .post(
          endpoint,
          headers: api.headers,
          body: jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': ++_id,
            'method': 'tools/call',
            'params': <String, Object?>{'name': tool, 'arguments': arguments},
          }),
        )
        .timeout(ApiClient.timeout);
    if (response.statusCode >= 400) {
      return McpResult(
        'Le MCP de LeadDesk a refusé l\'appel (${response.statusCode}).',
        isError: true,
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, Object?>) {
      return const McpResult('Réponse MCP illisible.', isError: true);
    }
    if (json['error'] case final Map<String, Object?> error) {
      return McpResult(
        error['message'] as String? ?? 'Erreur MCP.',
        isError: true,
      );
    }
    final result = json['result'];
    if (result is! Map<String, Object?>) {
      return const McpResult('Réponse MCP vide.', isError: true);
    }
    final text = <String>[
      for (final block
          in (result['content'] as List<Object?>? ?? const <Object?>[])
              .whereType<Map<String, Object?>>())
        if (block['text'] case final String value) value,
    ].join('\n');
    return McpResult(text, isError: result['isError'] == true);
  }
}
