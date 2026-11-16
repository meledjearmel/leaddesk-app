import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/engine/model.dart';

/// Faux serveur LeadDesk : réponses par « MÉTHODE chemin », requêtes notées.
class FakeServer {
  FakeServer({
    Map<String, String>? permissions,
    this.approval = 'allowed',
    this.usageStatus = 'running',
    this.decisionStatus = 'approved',
    this.mcpText = '{"departments":[]}',
  }) : permissions =
           permissions ??
           <String, String>{'read_file': 'allow', 'write_file': 'allow'};

  final Map<String, String> permissions;
  String approval;
  String usageStatus;
  String decisionStatus;

  /// Statut renvoyé par GET task-runs/11.
  String runStatus = 'running';

  /// Si renseigné, la limite de coût est atteinte à cet enregistrement.
  int? pauseCostAt;

  /// Exécutions ouvertes de l'ordinateur 4.
  List<Map<String, Object?>> openRuns = <Map<String, Object?>>[];
  final String mcpText;
  String folder = '';
  final List<(String, String, Map<String, Object?>)> requests =
      <(String, String, Map<String, Object?>)>[];

  Iterable<Map<String, Object?>> bodies(String method, String path) => requests
      .where((r) => r.$1 == method && r.$2.endsWith(path))
      .map((r) => r.$3);

  http.Client get client => MockClient((request) async {
    final body = request.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(request.body) as Map<String, Object?>;
    final path = request.url.path;
    requests.add((request.method, path, body));
    expect(request.headers['X-LeadDesk-Agent'] ?? '7', '7');
    Object? data;
    if (path == '/mcp/leaddesk') {
      return http.Response(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': <String, Object?>{
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': mcpText},
            ],
          },
        }),
        200,
      );
    }
    switch ((request.method, path.replaceFirst('/api/v1/', ''))) {
      case ('POST', 'tasks/3/runs'):
        data = <String, Object?>{'id': 11, 'status': 'running'};
      case ('GET', 'agents/7/tasks/3/context'):
        data = <String, Object?>{
          'agent': <String, Object?>{'id': 7, 'name': 'Inès'},
          'task': <String, Object?>{'id': 3, 'title': 'Résumer les notes'},
          'activity': <String, Object?>{'id': 5},
          'tool_permissions': permissions,
        };
      case ('GET', 'activities/5'):
        data = <String, Object?>{'id': 5, 'project_id': 2};
      case ('GET', 'projects/2/folders'):
        data = <Object?>[
          <String, Object?>{'kind': 'documentation', 'path': folder},
        ];
      case ('POST', 'task-runs/11/usage'):
        final count = bodies('POST', 'task-runs/11/usage').length;
        data = <String, Object?>{
          'status': count == pauseCostAt ? 'paused_cost' : usageStatus,
        };
      case ('POST', 'task-runs/11/approvals'):
        data = <String, Object?>{
          'outcome': approval,
          if (approval == 'pending') 'decision': <String, Object?>{'id': 9},
        };
      case ('GET', 'decisions/9'):
        data = <String, Object?>{'id': 9, 'status': decisionStatus};
      case ('GET', 'task-runs/11'):
        data = <String, Object?>{'id': 11, 'status': runStatus};
      case ('GET', 'task-runs'):
        data = openRuns;
      case ('POST', 'task-runs/11/resume'):
        runStatus = 'running';
        data = <String, Object?>{'id': 11, 'status': 'running'};
      case ('POST', 'task-runs/11/finish'):
        data = <String, Object?>{'id': 11};
      case ('GET', 'tasks'):
        data = <Object?>[
          <String, Object?>{
            'id': 3,
            'title': 'Résumer les notes de réunion',
            'completed_at': null,
            'agents': <Object?>[
              <String, Object?>{'agent_id': 7, 'name': 'Inès', 'is_lead': true},
              <String, Object?>{
                'agent_id': 8,
                'name': 'Malo',
                'is_lead': false,
              },
            ],
          },
          <String, Object?>{
            'id': 4,
            'title': 'Préparer la note de version',
            'completed_at': null,
            'agents': <Object?>[],
          },
        ];
      case ('POST', 'devices'):
        data = <String, Object?>{'id': 4};
      case ('POST', 'devices/4/heartbeat'):
        data = <String, Object?>{'id': 4};
      case ('POST', 'activities/5/messages'):
        data = <String, Object?>{'id': 1};
      default:
        return http.Response('{"message":"Introuvable."}', 404);
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(<String, Object?>{'data': data})),
      200,
    );
  });
}

/// Faux modèle : rejoue des tours écrits d'avance.
class ScriptedModel implements ModelProvider {
  ScriptedModel(this.script);

  final List<Object> script;
  final List<List<ToolSpec>> seenTools = <List<ToolSpec>>[];
  final List<List<Map<String, Object?>>> seenMessages =
      <List<Map<String, Object?>>>[];

  @override
  String get provider => 'anthropic';

  @override
  Future<ModelTurn> next({
    required String system,
    required List<ToolSpec> tools,
    required List<Map<String, Object?>> messages,
  }) async {
    seenTools.add(tools);
    seenMessages.add(List<Map<String, Object?>>.of(messages));
    final step = script.removeAt(0);
    if (step is Exception) {
      throw step;
    }
    return step as ModelTurn;
  }
}

ModelTurn toolTurn(String name, Map<String, Object?> input) => ModelTurn(
  assistantContent: <Object?>[
    <String, Object?>{
      'type': 'tool_use',
      'id': 'call-$name',
      'name': name,
      'input': input,
    },
  ],
  stopReason: StopReason.toolUse,
  usage: const ModelUsage(inputTokens: 100, outputTokens: 20),
  model: 'claude-opus-5-5',
  toolCalls: <ToolCall>[ToolCall(id: 'call-$name', name: name, input: input)],
  costMicros: 1000,
);

ModelTurn endTurn(String text) => ModelTurn(
  assistantContent: <Object?>[
    <String, Object?>{'type': 'text', 'text': text},
  ],
  stopReason: StopReason.endTurn,
  usage: const ModelUsage(inputTokens: 50, outputTokens: 10),
  model: 'claude-opus-5-5',
  text: text,
  costMicros: 500,
);

/// Dernier résultat d'outil envoyé au modèle.
Map<String, Object?> lastToolResult(ScriptedModel model) {
  final content = model.seenMessages.last.last['content']! as List<Object?>;
  return content.first! as Map<String, Object?>;
}
