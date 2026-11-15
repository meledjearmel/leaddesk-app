import 'dart:convert';
import 'dart:io';

import 'anthropic_client.dart';
import 'pricing.dart';
import 'sandbox.dart';

/// Trace d'un appel au modèle : ce qui a été consommé et ce que cela a coûté.
class CallRecord {
  const CallRecord({
    required this.at,
    required this.model,
    required this.usage,
    required this.costUsd,
    required this.durationMs,
    required this.stopReason,
  });

  final DateTime at;
  final String model;
  final TokenUsage usage;

  /// Coût réel en dollars, ou `null` si le tarif du modèle est inconnu.
  final double? costUsd;
  final int durationMs;
  final String stopReason;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toUtc().toIso8601String(),
    'model': model,
    'usage': usage.toJson(),
    'cost_usd': costUsd,
    'duration_ms': durationMs,
    'stop_reason': stopReason,
  };
}

/// Registre des coûts réels : une ligne JSON par appel, ajoutée à un fichier
/// local. En production chaque ligne sera envoyée au serveur, rattachée à
/// l'agent, à la tâche, à l'activité et au projet (RM-35).
class CostLedger {
  CostLedger({this.file});

  final File? file;
  final List<CallRecord> records = <CallRecord>[];

  void add(CallRecord record) {
    records.add(record);
    file
      ?..createSync(recursive: true)
      ..writeAsStringSync(
        '${jsonEncode(record.toJson())}\n',
        mode: FileMode.append,
      );
  }

  /// Total des appels chiffrés, en dollars.
  double get totalUsd =>
      records.fold<double>(0, (sum, record) => sum + (record.costUsd ?? 0));

  /// Vrai si au moins un appel n'a pas pu être chiffré.
  bool get hasUnpricedCalls => records.any((record) => record.costUsd == null);
}

/// Action d'outil exécutée pendant la boucle (consultation tracée, RM-34).
class ToolAction {
  const ToolAction({
    required this.tool,
    required this.input,
    required this.allowed,
    required this.detail,
  });

  final String tool;
  final Map<String, Object?> input;
  final bool allowed;
  final String detail;
}

class AgentResult {
  const AgentResult({
    required this.answer,
    required this.stopReason,
    required this.turns,
    required this.actions,
  });

  final String answer;
  final String stopReason;
  final int turns;
  final List<ToolAction> actions;

  /// Vrai si le modèle a terminé normalement.
  bool get completed => stopReason == 'end_turn';
}

/// Boucle d'agent minimale : le modèle est appelé à distance, l'outil
/// « lire un fichier » s'exécute en local, confiné au dossier autorisé.
class AgentLoop {
  AgentLoop({
    required this.client,
    required this.folder,
    required this.ledger,
    this.model = 'claude-opus-5-5',
    this.effort = 'low',
    this.prices = PriceTable.anthropic,
    this.maxTurns = 8,
  });

  final AnthropicClient client;
  final AllowedFolder folder;
  final CostLedger ledger;
  final String model;
  final String effort;
  final PriceTable prices;

  /// Garde-fou : nombre maximal d'appels au modèle pour une demande.
  final int maxTurns;

  static const String readFileTool = 'read_file';

  static const List<Map<String, Object?>> tools = <Map<String, Object?>>[
    <String, Object?>{
      'name': readFileTool,
      'description':
          'Lit un fichier texte du dossier de travail autorisé. Le chemin est '
          'relatif à ce dossier. Toute lecture en dehors est refusée.',
      'strict': true,
      'input_schema': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'path': <String, Object?>{
            'type': 'string',
            'description': 'Chemin relatif, par exemple "notes/brief.md".',
          },
        },
        'required': <String>['path'],
        'additionalProperties': false,
      },
    },
  ];

  static const String systemPrompt =
      'Tu es un agent de LeadDesk. Tu travailles uniquement à partir des '
      'fichiers du dossier autorisé, lus avec l\'outil read_file. Si une '
      'information manque ou si un fichier est refusé, dis-le clairement au '
      'lieu de deviner. Réponds en français, brièvement.';

  Future<AgentResult> run(String task) async {
    final messages = <Map<String, Object?>>[
      <String, Object?>{'role': 'user', 'content': task},
    ];
    final actions = <ToolAction>[];

    for (var turn = 1; turn <= maxTurns; turn++) {
      final watch = Stopwatch()..start();
      final response = await client.createMessage(
        model: model,
        system: systemPrompt,
        messages: messages,
        tools: tools,
        effort: effort,
      );
      watch.stop();
      ledger.add(
        CallRecord(
          at: DateTime.now(),
          model: response.model,
          usage: response.usage,
          costUsd: prices.priceFor(response.model)?.costOf(response.usage),
          durationMs: watch.elapsedMilliseconds,
          stopReason: response.stopReason,
        ),
      );

      if (response.stopReason != 'tool_use') {
        // end_turn, mais aussi refusal ou max_tokens : on s'arrête sans
        // exécuter d'outil et on rend le motif à l'appelant.
        return AgentResult(
          answer: response.text,
          stopReason: response.stopReason,
          turns: turn,
          actions: actions,
        );
      }

      // Le contenu de l'assistant est renvoyé tel quel (réflexion comprise),
      // puis tous les résultats d'outils dans un seul message utilisateur.
      messages.add(<String, Object?>{
        'role': 'assistant',
        'content': response.content,
      });
      messages.add(<String, Object?>{
        'role': 'user',
        'content': <Map<String, Object?>>[
          for (final call in response.toolUses) _execute(call, actions),
        ],
      });
    }

    return AgentResult(
      answer: '',
      stopReason: 'max_turns',
      turns: maxTurns,
      actions: actions,
    );
  }

  Map<String, Object?> _execute(
    Map<String, Object?> call,
    List<ToolAction> actions,
  ) {
    final name = call['name'] as String? ?? '';
    final input = call['input'] as Map<String, Object?>? ?? <String, Object?>{};
    String content;
    var allowed = true;
    try {
      if (name != readFileTool) {
        throw SandboxViolation('Outil inconnu : $name');
      }
      final path = input['path'];
      if (path is! String) {
        throw SandboxViolation('Le paramètre "path" est requis.');
      }
      content = folder.readText(path);
    } on SandboxViolation catch (violation) {
      allowed = false;
      content = violation.message;
    }
    actions.add(
      ToolAction(
        tool: name,
        input: input,
        allowed: allowed,
        detail: allowed ? '${content.length} caractères lus' : content,
      ),
    );
    return <String, Object?>{
      'type': 'tool_result',
      'tool_use_id': call['id'],
      'content': content,
      if (!allowed) 'is_error': true,
    };
  }
}
