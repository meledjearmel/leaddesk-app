import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/engine/host.dart';
import 'package:leaddesk_app/engine/run_controller.dart';
import 'package:leaddesk_app/live_office/widgets/run_panel.dart';
import 'package:path/path.dart' as p;

import '../support/engine_fakes.dart';

/// Contrôleur branché sur le faux serveur, avec ou sans clé.
Future<RunController> engineFor(
  FakeServer server,
  ScriptedModel model, {
  String? key = 'sk-ant-test-a1b2',
}) async {
  final api = ApiClient(
    ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
    httpClient: server.client,
  );
  final vault = MemoryVault();
  if (key != null) {
    await ProviderKeys(vault).setAnthropic(key);
  }
  return RunController(
    api: api,
    keys: ProviderKeys(vault),
    host: HostDevice(api: api, vault: vault, name: 'POSTE-CEO'),
    modelFactory: (_) => model,
  );
}

Widget panelApp(RunController controller) => MaterialApp(
  theme: buildLeadDeskTheme(),
  home: Scaffold(
    backgroundColor: LdColors.background,
    body: Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 720,
        child: RunPanel(controller: controller, onClose: () {}),
      ),
    ),
  ),
);

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ld_panel_');
    File(p.join(tmp.path, 'notes.md')).writeAsStringSync('Livrer lundi.');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('sans clé, le lancement est expliqué et bloqué', (tester) async {
    final server = FakeServer()..folder = tmp.path;
    final engine = await engineFor(
      server,
      ScriptedModel(<Object>[]),
      key: null,
    );
    await tester.binding.setSurfaceSize(const Size(400, 760));
    await tester.pumpWidget(panelApp(engine));
    await tester.runAsync(engine.load);
    await tester.pump();

    // En-tête et liste des tâches.
    expect(find.text('Résumer les notes de réunion'), findsNWidgets(2));
    expect(find.textContaining('Ajoutez une clé Anthropic'), findsOneWidget);
    expect(engine.canLaunch, isFalse);
    engine.dispose();
  });

  testWidgets('lance la tâche et montre les étapes puis le bilan', (
    tester,
  ) async {
    final server = FakeServer()..folder = tmp.path;
    final model = ScriptedModel(<Object>[
      toolTurn('read_file', <String, Object?>{
        'path': 'documentation/notes.md',
      }),
      endTurn('Notes lues : livraison lundi.'),
    ]);
    final engine = await engineFor(server, model);
    await tester.binding.setSurfaceSize(const Size(400, 760));
    await tester.pumpWidget(panelApp(engine));
    await tester.runAsync(engine.load);
    await tester.pump();

    expect(engine.agentName, 'Inès');
    expect(find.text('Prête'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Lancer la tâche'));
      var waited = 0;
      while (engine.running && waited++ < 500) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('Terminée'), findsOneWidget);
    expect(find.text('Lire « documentation/notes.md »'), findsOneWidget);
    expect(find.text('Notes lues : livraison lundi.'), findsOneWidget);
    expect(find.textContaining('Compte rendu publié'), findsOneWidget);
    expect(find.text('Nouvelle exécution'), findsOneWidget);
    expect(server.bodies('POST', 'activities/5/messages'), hasLength(1));
    engine.dispose();
  });

  testWidgets('la clé saisie est gardée et masquée', (tester) async {
    final engine = await engineFor(
      FakeServer()..folder = tmp.path,
      ScriptedModel(<Object>[]),
      key: null,
    );
    await tester.binding.setSurfaceSize(const Size(400, 760));
    await tester.pumpWidget(panelApp(engine));
    await tester.runAsync(engine.load);
    await tester.tap(find.text('Réglages'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'sk-ant-nouvelle-9z8y');
    await tester.runAsync(
      () => tester.tap(find.byTooltip('Enregistrer la clé')),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(engine.keyMask, '…9z8y');
    expect(find.text('POSTE-CEO · enregistré, en ligne'), findsOneWidget);
    engine.dispose();
  });
}
