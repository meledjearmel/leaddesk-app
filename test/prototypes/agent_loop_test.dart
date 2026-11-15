import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../prototypes/agent_loop/agent_loop.dart';
import '../../prototypes/agent_loop/anthropic_client.dart';
import '../../prototypes/agent_loop/pricing.dart';
import '../../prototypes/agent_loop/sandbox.dart';

http.Response _json(Map<String, Object?> body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, Object?> _toolUse(String id, String path) => <String, Object?>{
  'id': 'msg_tool',
  'model': 'claude-opus-5-5',
  'stop_reason': 'tool_use',
  'content': <Object?>[
    <String, Object?>{'type': 'thinking', 'thinking': '', 'signature': 's'},
    <String, Object?>{
      'type': 'tool_use',
      'id': id,
      'name': 'read_file',
      'input': <String, Object?>{'path': path},
    },
  ],
  'usage': <String, Object?>{'input_tokens': 1000, 'output_tokens': 100},
};

Map<String, Object?> _final(String text, {String model = 'claude-opus-5-5'}) =>
    <String, Object?>{
      'id': 'msg_end',
      'model': model,
      'stop_reason': 'end_turn',
      'content': <Object?>[
        <String, Object?>{'type': 'text', 'text': text},
      ],
      'usage': <String, Object?>{'input_tokens': 2000, 'output_tokens': 50},
    };

void main() {
  late Directory root;
  late Directory outside;

  setUp(() {
    final base = Directory.systemTemp.createTempSync('leaddesk_agent_loop_');
    root = Directory('${base.path}/projet')..createSync();
    outside = Directory('${base.path}/ailleurs')..createSync();
    File('${root.path}/brief.md').writeAsStringSync('Objectif : livrer lundi.');
    Directory('${root.path}/notes').createSync();
    File('${root.path}/notes/a.txt').writeAsStringSync('note A');
    File('${outside.path}/secret.txt').writeAsStringSync('clé secrète');
  });

  tearDown(() {
    root.parent.deleteSync(recursive: true);
  });

  group('AllowedFolder', () {
    test('lit un fichier du dossier autorisé, sous-dossiers compris', () {
      final folder = AllowedFolder(root.path);
      expect(folder.readText('brief.md'), 'Objectif : livrer lundi.');
      expect(folder.readText('notes/a.txt'), 'note A');
      expect(folder.readText(r'notes\a.txt'), 'note A');
    });

    test('refuse de sortir du dossier par ..', () {
      final folder = AllowedFolder(root.path);
      expect(
        () => folder.readText('../ailleurs/secret.txt'),
        throwsA(isA<SandboxViolation>()),
      );
      expect(
        () => folder.readText('notes/../../ailleurs/secret.txt'),
        throwsA(isA<SandboxViolation>()),
      );
    });

    test('refuse les chemins absolus', () {
      final folder = AllowedFolder(root.path);
      expect(
        () => folder.readText('${outside.path}/secret.txt'),
        throwsA(isA<SandboxViolation>()),
      );
      expect(
        () => folder.readText('/etc/passwd'),
        throwsA(isA<SandboxViolation>()),
      );
      expect(
        () => folder.readText(r'C:\Windows\win.ini'),
        throwsA(isA<SandboxViolation>()),
      );
    });

    test('refuse un fichier absent, vide de nom ou trop gros', () {
      final folder = AllowedFolder(root.path, maxBytes: 10);
      expect(
        () => folder.readText('absent.md'),
        throwsA(isA<SandboxViolation>()),
      );
      expect(() => folder.readText('  '), throwsA(isA<SandboxViolation>()));
      expect(
        () => folder.readText('brief.md'),
        throwsA(isA<SandboxViolation>()),
      );
    });
  });

  group('tarification', () {
    test('calcule le coût réel à partir des jetons', () {
      const usage = TokenUsage(
        inputTokens: 1000000,
        outputTokens: 500000,
        cacheReadTokens: 1000000,
      );
      final price = PriceTable.anthropic.priceFor('claude-opus-5-5')!;
      expect(price.costOf(usage), closeTo(4 + 10 + 0.20, 1e-9));
    });

    test('un modèle inconnu n a pas de tarif inventé', () {
      expect(PriceTable.anthropic.priceFor('modele-inconnu'), isNull);
    });

    test('lit les compteurs de la réponse, absents compris', () {
      final usage = TokenUsage.fromJson(<String, Object?>{
        'input_tokens': 12,
        'output_tokens': 3,
      });
      expect(usage.inputTokens, 12);
      expect(usage.cacheReadTokens, 0);
    });
  });

  group('AgentLoop', () {
    AgentLoop build(MockClient mock, CostLedger ledger) {
      return AgentLoop(
        client: AnthropicClient(apiKey: 'cle-de-test', httpClient: mock),
        folder: AllowedFolder(root.path),
        ledger: ledger,
      );
    }

    test('lit le fichier demandé, répond et enregistre le coût', () async {
      final requests = <Map<String, Object?>>[];
      late Map<String, String> headers;
      final mock = MockClient((request) async {
        headers = request.headers;
        requests.add(jsonDecode(request.body) as Map<String, Object?>);
        return requests.length == 1
            ? _json(_toolUse('toolu_1', 'brief.md'))
            : _json(_final('Livraison lundi.'));
      });
      final ledgerFile = File('${root.parent.path}/couts.jsonl');
      final ledger = CostLedger(file: ledgerFile);

      final result = await build(mock, ledger).run('Quand livre-t-on ?');

      expect(result.completed, isTrue);
      expect(result.answer, 'Livraison lundi.');
      expect(result.turns, 2);
      expect(result.actions.single.allowed, isTrue);

      // Requête : en-têtes, modèle, outil strict, repli côté serveur.
      expect(headers['x-api-key'], 'cle-de-test');
      expect(headers['anthropic-version'], AnthropicClient.apiVersion);
      expect(requests.first['model'], 'claude-opus-5-5');
      expect(requests.first['fallbacks'], 'default');
      final tool =
          (requests.first['tools']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(tool['strict'], isTrue);

      // Second appel : contenu de l'assistant renvoyé tel quel (réflexion
      // comprise), puis le résultat de l'outil.
      final messages = requests[1]['messages']! as List<Object?>;
      expect(messages, hasLength(3));
      final assistant = messages[1]! as Map<String, Object?>;
      expect(
        ((assistant['content']! as List<Object?>).first!
            as Map<String, Object?>)['type'],
        'thinking',
      );
      final toolResult =
          ((messages[2]! as Map<String, Object?>)['content']! as List<Object?>)
                  .single!
              as Map<String, Object?>;
      expect(toolResult['tool_use_id'], 'toolu_1');
      expect(toolResult['content'], 'Objectif : livrer lundi.');
      expect(toolResult.containsKey('is_error'), isFalse);

      // Coût réel : (1000 × 4 + 100 × 20 + 2000 × 4 + 50 × 20) / 1 000 000.
      expect(ledger.records, hasLength(2));
      expect(ledger.totalUsd, closeTo(0.015, 1e-9));
      expect(ledger.hasUnpricedCalls, isFalse);
      final lines = ledgerFile.readAsLinesSync();
      expect(lines, hasLength(2));
      expect(
        (jsonDecode(lines.first) as Map<String, Object?>)['cost_usd'],
        closeTo(0.006, 1e-9),
      );
    });

    test(
      'une lecture hors dossier est refusée et signalée au modèle',
      () async {
        final requests = <Map<String, Object?>>[];
        final mock = MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, Object?>);
          return requests.length == 1
              ? _json(_toolUse('toolu_2', '../ailleurs/secret.txt'))
              : _json(_final('Je ne peux pas lire ce fichier.'));
        });

        final result = await build(mock, CostLedger()).run('Lis le secret.');

        expect(result.actions.single.allowed, isFalse);
        final messages = requests[1]['messages']! as List<Object?>;
        final toolResult =
            ((messages[2]! as Map<String, Object?>)['content']!
                        as List<Object?>)
                    .single!
                as Map<String, Object?>;
        expect(toolResult['is_error'], isTrue);
        expect(toolResult['content'], isNot(contains('clé secrète')));
      },
    );

    test('le coût suit le modèle qui a réellement répondu', () async {
      final mock = MockClient(
        (request) async => _json(_final('ok', model: 'claude-sonnet-5-5')),
      );
      final ledger = CostLedger();

      await build(mock, ledger).run('Bonjour');

      expect(ledger.records.single.model, 'claude-sonnet-5-5');
      // (2000 × 2 + 50 × 10) / 1 000 000.
      expect(ledger.totalUsd, closeTo(0.0045, 1e-9));
    });

    test('un modèle sans tarif connu reste non chiffré', () async {
      final mock = MockClient(
        (request) async => _json(_final('ok', model: 'modele-inconnu')),
      );
      final ledger = CostLedger();

      await build(mock, ledger).run('Bonjour');

      expect(ledger.records.single.costUsd, isNull);
      expect(ledger.hasUnpricedCalls, isTrue);
    });

    test('un refus du modèle arrête la boucle sans exécuter d outil', () async {
      final mock = MockClient(
        (request) async => _json(<String, Object?>{
          'id': 'msg_refus',
          'model': 'claude-opus-5-5',
          'stop_reason': 'refusal',
          'content': <Object?>[],
          'usage': <String, Object?>{'input_tokens': 10, 'output_tokens': 0},
        }),
      );

      final result = await build(mock, CostLedger()).run('…');

      expect(result.completed, isFalse);
      expect(result.stopReason, 'refusal');
      expect(result.actions, isEmpty);
    });

    test('la boucle s arrête au nombre maximal d appels', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return _json(_toolUse('toolu_$calls', 'brief.md'));
      });
      final loop = AgentLoop(
        client: AnthropicClient(apiKey: 'k', httpClient: mock),
        folder: AllowedFolder(root.path),
        ledger: CostLedger(),
        maxTurns: 3,
      );

      final result = await loop.run('Boucle');

      expect(result.stopReason, 'max_turns');
      expect(calls, 3);
    });

    test('une erreur du fournisseur remonte avec son statut', () async {
      final mock = MockClient(
        (request) async => _json(<String, Object?>{'error': 'surcharge'}, 529),
      );

      await expectLater(
        build(mock, CostLedger()).run('Bonjour'),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.statusCode, 'statusCode', 529)
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });
  });
}
