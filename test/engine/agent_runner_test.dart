import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/engine/agent_runner.dart';
import 'package:leaddesk_app/engine/anthropic.dart';
import 'package:leaddesk_app/engine/workspace.dart';
import 'package:path/path.dart' as p;

import '../support/engine_fakes.dart';

void main() {
  late Directory tmp;
  late String docs;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ld_engine_');
    docs = p.join(tmp.path, 'docs');
    Directory(docs).createSync();
    File(p.join(docs, 'notes.md')).writeAsStringSync('Réunion : livrer lundi.');
    File(p.join(tmp.path, 'secret.txt')).writeAsStringSync('confidentiel');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  (AgentRunner, FakeServer) build(FakeServer server, ScriptedModel model) {
    server.folder = docs;
    final api = ApiClient(
      ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
      httpClient: server.client,
    );
    return (
      AgentRunner(
        api: api,
        model: model,
        approvalPoll: Duration.zero,
        retryDelay: Duration.zero,
      ),
      server,
    );
  }

  test('lit un fichier, écrit un livrable et consigne le coût', () async {
    final model = ScriptedModel(<Object>[
      toolTurn('read_file', <String, Object?>{
        'path': 'documentation/notes.md',
      }),
      toolTurn('write_file', <String, Object?>{
        'path': 'documentation/livrables/resume.md',
        'content': '# Résumé\nLivrer lundi.',
      }),
      endTurn('Résumé écrit dans livrables/resume.md.'),
    ]);
    final (runner, server) = build(FakeServer(), model);

    final report = await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(report.outcome, RunOutcome.completed);
    expect(report.summary, contains('resume.md'));
    expect(report.costMicros, 2500);
    expect(
      File(p.join(docs, 'livrables', 'resume.md')).readAsStringSync(),
      contains('Livrer lundi'),
    );
    // Le contenu lu est renvoyé au modèle au tour suivant.
    final firstResult =
        (model.seenMessages[1].last['content']! as List<Object?>).first!
            as Map<String, Object?>;
    expect(firstResult['content'], 'Réunion : livrer lundi.');
    expect(server.bodies('POST', 'task-runs/11/usage'), hasLength(3));
    expect(
      server.bodies('POST', 'task-runs/11/usage').first['cost_micros'],
      1000,
    );
    expect(
      server.bodies('POST', 'task-runs/11/approvals').map((b) => b['tool']),
      <String>['read_file', 'write_file'],
    );
    expect(
      server.bodies('POST', 'task-runs/11/finish').single['outcome'],
      'completed',
    );
    // Compte rendu dans la conversation, livrable en référence (pas le texte).
    final message = server.bodies('POST', 'activities/5/messages').single;
    expect(message['body'], contains('resume.md'));
    expect(message['task_id'], 3);
    expect(message['file_references'], <Object?>[
      <String, Object?>{
        'label': 'resume.md',
        'path': 'documentation/livrables/resume.md',
        'device_id': 4,
      },
    ]);
    expect(jsonEncode(message), isNot(contains('Livrer lundi')));
    // Les outils du bureau ne sont pas proposés sans permission.
    expect(
      model.seenTools.first.map((t) => t.name),
      isNot(contains('office_context')),
    );
  });

  test('refuse un chemin hors du dossier autorisé', () async {
    final model = ScriptedModel(<Object>[
      toolTurn('read_file', <String, Object?>{
        'path': 'documentation/../secret.txt',
      }),
      endTurn('Impossible.'),
    ]);
    final (runner, _) = build(FakeServer(), model);

    final report = await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(report.outcome, RunOutcome.completed);
    final result = lastToolResult(model);
    expect(result['is_error'], isTrue);
    expect(result['content'], contains('hors du dossier'));
    expect(jsonEncode(model.seenMessages), isNot(contains('confidentiel')));
  });

  test('refuse un lien symbolique qui sort du dossier', () async {
    final link = Link(p.join(docs, 'raccourci.txt'));
    try {
      link.createSync(p.join(tmp.path, 'secret.txt'));
    } on FileSystemException {
      markTestSkipped('Liens symboliques non permis sur ce poste.');
      return;
    }
    final workspace = Workspace(<String, String>{'documentation': docs});
    expect(
      () => workspace.read('documentation/raccourci.txt'),
      throwsA(isA<WorkspaceException>()),
    );
  });

  test('une action interdite n\'est pas exécutée', () async {
    final model = ScriptedModel(<Object>[
      toolTurn('write_file', <String, Object?>{
        'path': 'documentation/x.md',
        'content': 'x',
      }),
      endTurn('Bloqué.'),
    ]);
    final (runner, _) = build(FakeServer(approval: 'denied'), model);

    await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(File(p.join(docs, 'x.md')).existsSync(), isFalse);
    expect(lastToolResult(model)['is_error'], isTrue);
  });

  test('une action soumise au CEO attend sa décision', () async {
    for (final (decision, written) in <(String, bool)>[
      ('approved', true),
      ('rejected', false),
    ]) {
      final file = File(p.join(docs, 'attente.md'));
      if (file.existsSync()) {
        file.deleteSync();
      }
      final model = ScriptedModel(<Object>[
        toolTurn('write_file', <String, Object?>{
          'path': 'documentation/attente.md',
          'content': 'ok',
        }),
        endTurn('Fini.'),
      ]);
      final server = FakeServer(approval: 'pending', decisionStatus: decision);
      final (runner, _) = build(server, model);

      await runner.start(taskId: 3, agentId: 7, deviceId: 4);

      expect(file.existsSync(), written, reason: decision);
      expect(server.bodies('GET', 'decisions/9'), isNotEmpty);
    }
  });

  test('s\'arrête quand la limite de coût est atteinte', () async {
    final model = ScriptedModel(<Object>[
      toolTurn('read_file', <String, Object?>{
        'path': 'documentation/notes.md',
      }),
      endTurn('jamais atteint'),
    ]);
    final (runner, server) = build(
      FakeServer(usageStatus: 'paused_cost'),
      model,
    );

    final report = await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(report.outcome, RunOutcome.pausedCost);
    expect(model.script, hasLength(1));
    expect(server.bodies('POST', 'task-runs/11/approvals'), isEmpty);
    // La pause n'est pas une fin : le serveur garde l'exécution ouverte.
    expect(server.bodies('POST', 'task-runs/11/finish'), isEmpty);
  });

  test('reprend après une erreur passagère du fournisseur', () async {
    final model = ScriptedModel(<Object>[
      const ProviderException('Surcharge.', status: 529, retryable: true),
      endTurn('Fini après reprise.'),
    ]);
    final (runner, _) = build(FakeServer(), model);

    final report = await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(
      report.outcome,
      RunOutcome.completed,
      reason: report.steps.map((s) => s.text).join('\n'),
    );
    expect(report.summary, 'Fini après reprise.');
  });

  test('échoue sans reprise sur une erreur définitive', () async {
    final model = ScriptedModel(<Object>[
      const ProviderException('Clé refusée.', status: 401),
    ]);
    final (runner, server) = build(FakeServer(), model);

    final report = await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(report.outcome, RunOutcome.failed);
    expect(
      server.bodies('POST', 'task-runs/11/finish').single['outcome'],
      'failed',
    );
  });

  test('les outils du bureau passent par le MCP avec la permission', () async {
    final model = ScriptedModel(<Object>[
      toolTurn('office_context', <String, Object?>{}),
      endTurn('Plan étudié.'),
    ]);
    final server = FakeServer(
      permissions: <String, String>{'office.propose_plan': 'allow'},
    );
    final (runner, _) = build(server, model);

    await runner.start(taskId: 3, agentId: 7, deviceId: 4);

    expect(
      model.seenTools.first.map((t) => t.name),
      containsAll(<String>['office_context', 'office_propose_plan']),
    );
    expect(
      model.seenTools.first.map((t) => t.name),
      isNot(contains('read_file')),
    );
    final call = server.bodies('POST', '/mcp/leaddesk').single;
    expect((call['params']! as Map<String, Object?>)['name'], 'office.context');
    expect(lastToolResult(model)['content'], '{"departments":[]}');
  });
}
