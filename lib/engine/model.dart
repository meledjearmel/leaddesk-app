/// Interface des fournisseurs IA du moteur (D-022). Anthropic d'abord ;
/// les autres fournisseurs viendront derrière la même interface.
library;

/// Outil proposé au modèle.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  /// Nom vu par le modèle (`[a-zA-Z0-9_-]`, 64 caractères au plus).
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    'input_schema': inputSchema,
  };
}

/// Appel d'outil demandé par le modèle.
class ToolCall {
  const ToolCall({required this.id, required this.name, required this.input});

  final String id;
  final String name;
  final Map<String, Object?> input;
}

/// Consommation réelle d'un appel de modèle.
class ModelUsage {
  const ModelUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
  });

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
}

/// Pourquoi le modèle s'est arrêté.
enum StopReason { endTurn, toolUse, maxTokens, refusal, pauseTurn, other }

/// Réponse d'un tour.
class ModelTurn {
  const ModelTurn({
    required this.assistantContent,
    required this.stopReason,
    required this.usage,
    required this.model,
    this.text = '',
    this.toolCalls = const <ToolCall>[],
    this.costMicros,
  });

  /// Contenu brut du message assistant, à renvoyer tel quel au tour suivant
  /// (blocs de réflexion compris).
  final List<Object?> assistantContent;
  final StopReason stopReason;
  final ModelUsage usage;

  /// Modèle qui a réellement répondu.
  final String model;
  final String text;
  final List<ToolCall> toolCalls;

  /// Coût réel en millionièmes de dollar ; `null` si le tarif est inconnu.
  final int? costMicros;
}

/// Résultat d'un outil, renvoyé au modèle.
class ToolResult {
  const ToolResult(this.callId, this.content, {this.isError = false});

  final String callId;
  final String content;
  final bool isError;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'tool_result',
    'tool_use_id': callId,
    'content': content,
    if (isError) 'is_error': true,
  };
}

/// Un fournisseur de modèles.
abstract interface class ModelProvider {
  /// Identifiant du fournisseur pour la traçabilité (`anthropic`).
  String get provider;

  /// Un tour : le modèle lit la conversation et répond.
  Future<ModelTurn> next({
    required String system,
    required List<ToolSpec> tools,
    required List<Map<String, Object?>> messages,
  });
}
