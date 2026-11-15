/// Jetons consommés par un appel au modèle, tels que renvoyés dans `usage`.
class TokenUsage {
  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
  });

  factory TokenUsage.fromJson(Map<String, Object?> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return TokenUsage(
      inputTokens: read('input_tokens'),
      outputTokens: read('output_tokens'),
      cacheReadTokens: read('cache_read_input_tokens'),
      cacheWriteTokens: read('cache_creation_input_tokens'),
    );
  }

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;

  Map<String, Object> toJson() => <String, Object>{
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'cache_read_input_tokens': cacheReadTokens,
    'cache_creation_input_tokens': cacheWriteTokens,
  };
}

/// Tarif d'un modèle, en dollars par million de jetons.
class ModelPrice {
  const ModelPrice({
    required this.input,
    required this.output,
    required this.cacheRead,
    required this.cacheWrite,
  });

  final double input;
  final double output;
  final double cacheRead;
  final double cacheWrite;

  /// Coût réel d'un appel, en dollars.
  double costOf(TokenUsage usage) {
    return (usage.inputTokens * input +
            usage.outputTokens * output +
            usage.cacheReadTokens * cacheRead +
            usage.cacheWriteTokens * cacheWrite) /
        1000000;
  }
}

/// Grille tarifaire : une donnée de configuration, jamais une constante du
/// moteur. En production elle viendra du serveur, par fournisseur et modèle.
class PriceTable {
  const PriceTable(this.prices);

  final Map<String, ModelPrice> prices;

  /// Tarifs publics Anthropic relevés le 15 novembre 2026 (dollars par million
  /// de jetons). L'écriture en cache est comptée à 1,25 fois l'entrée : à
  /// confirmer sur la page des tarifs avant tout usage du cache.
  static const PriceTable anthropic = PriceTable(<String, ModelPrice>{
    'claude-opus-5-5': ModelPrice(
      input: 4,
      output: 20,
      cacheRead: 0.20,
      cacheWrite: 5,
    ),
    'claude-sonnet-5-5': ModelPrice(
      input: 2,
      output: 10,
      cacheRead: 0.10,
      cacheWrite: 2.5,
    ),
    'claude-haiku-5-5': ModelPrice(
      input: 0.10,
      output: 0.50,
      cacheRead: 0.01,
      cacheWrite: 0.125,
    ),
  });

  /// Tarif du modèle réellement utilisé, ou `null` s'il est inconnu : le coût
  /// est alors enregistré comme non chiffré plutôt qu'inventé.
  ModelPrice? priceFor(String model) => prices[model];
}
