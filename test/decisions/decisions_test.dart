import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/decisions/decisions_controller.dart';
import 'package:leaddesk_app/live_office/widgets/decisions_panel.dart';

/// Faux serveur des décisions : deux demandes ouvertes, actions notées.
class FakeDecisions {
  final List<(String, Map<String, Object?>)> actions =
      <(String, Map<String, Object?>)>[];
  final Map<int, String> status = <int, String>{1: 'pending', 2: 'pending'};

  static const Map<int, Map<String, Object?>> base =
      <int, Map<String, Object?>>{
        1: <String, Object?>{
          'id': 1,
          'kind': 'tool_approval',
          'title': 'Approbation demandée : write_file',
          'requested_by_name': 'Inès',
          'payload': <String, Object?>{
            'task_run_id': 11,
            'tool': 'write_file',
            'summary': 'Écrire « documentation/resume.md » (420 caractères)',
          },
        },
        2: <String, Object?>{
          'id': 2,
          'kind': 'cost_limit',
          'title': 'Limite de coût atteinte : Résumer les notes',
          'payload': <String, Object?>{
            'task_run_id': 11,
            'limit_micros': 500000,
            'spent_micros': 512000,
          },
        },
      };

  http.Client get client => MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    if (request.method == 'GET' && path == 'decisions') {
      final wanted = request.url.queryParameters['status'];
      final data = <Object?>[
        for (final MapEntry(:key, :value) in status.entries)
          if (value == wanted)
            <String, Object?>{...base[key]!, 'status': value},
      ];
      return http.Response.bytes(
        utf8.encode(jsonEncode(<String, Object?>{'data': data})),
        200,
      );
    }
    final match = RegExp(r'^decisions/(\d+)/([a-z-]+)$').firstMatch(path);
    if (request.method == 'POST' && match != null) {
      final id = int.parse(match.group(1)!);
      final action = match.group(2)!;
      actions.add((
        '$id/$action',
        jsonDecode(request.body) as Map<String, Object?>,
      ));
      status[id] = switch (action) {
        'approve' => 'approved',
        'reject' => 'rejected',
        _ => 'needs_info',
      };
      return http.Response('{"data":{}}', 200);
    }
    return http.Response('{"message":"Introuvable."}', 404);
  });
}

DecisionsController controllerFor(FakeDecisions server) => DecisionsController(
  ApiClient(
    ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
    httpClient: server.client,
  ),
);

Widget panelApp(DecisionsController controller) => MaterialApp(
  theme: buildLeadDeskTheme(),
  home: Scaffold(
    body: Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 760,
        child: DecisionsPanel(controller: controller, onClose: () {}),
      ),
    ),
  ),
);

void main() {
  test('lit les demandes ouvertes et les tranche', () async {
    final server = FakeDecisions();
    final c = controllerFor(server);

    await c.load();
    expect(c.count, 2);
    final cost = c.open.firstWhere((d) => d.kind == 'cost_limit');
    expect(cost.limitMicros, 500000);

    await c.approve(cost, newLimitMicros: 1000000);
    expect(server.actions.single.$1, '2/approve');
    expect(server.actions.single.$2, <String, Object?>{
      'new_limit_micros': 1000000,
    });
    expect(c.count, 1);

    await c.requestInfo(c.open.single, 'Pourquoi ce fichier ?');
    expect(server.actions.last.$1, '1/request-info');
    // La demande reste ouverte, en attente de la réponse de l'agent.
    expect(c.open.single.status, 'needs_info');
    c.dispose();
  });

  testWidgets('le panneau montre et approuve une action d\'agent', (
    tester,
  ) async {
    final server = FakeDecisions();
    final c = controllerFor(server);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(panelApp(c));
    await tester.runAsync(c.load);
    await tester.pump();

    expect(find.text('2 en attente'), findsOneWidget);
    expect(find.text('Action d\'agent · Inès'), findsOneWidget);
    expect(
      find.text('Écrire « documentation/resume.md » (420 caractères)'),
      findsOneWidget,
    );
    expect(find.textContaining('Dépensé 0,51 \$'), findsOneWidget);
    // Nouvelle limite proposée : le double de l'actuelle.
    expect(find.widgetWithText(TextField, '1,00'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Approuver').last);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(server.actions.single.$1, '1/approve');
    expect(find.text('1 en attente'), findsOneWidget);
    c.dispose();
  });
}
