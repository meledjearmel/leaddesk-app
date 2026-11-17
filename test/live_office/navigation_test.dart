import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/live_office/agent_sheet.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/office_camera.dart';
import 'package:leaddesk_app/live_office/scene/plan_scene.dart';
import 'package:leaddesk_app/main.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

void main() {
  test('passe de bureau en bureau dans l\'ordre de l\'organisation', () {
    final c = LiveOfficeController();
    final ids = c.departments.map((d) => d.id).toList();

    c.stepDepartment(1);
    expect(c.focusedDepartment?.id, ids.first);
    c.stepDepartment(1);
    expect(c.focusedDepartment?.id, ids[1]);
    c
      ..focusDepartment(ids.first)
      ..stepDepartment(-1);
    expect(c.focusedDepartment?.id, ids.last);

    // Dans un bureau, seuls ses agents sont listés.
    final listed = c.agentsByPosition.values.expand((a) => a);
    expect(listed.every((a) => a.departmentId == ids.last), isTrue);

    c.focusDepartment(null);
    expect(c.focusedDepartment, isNull);
    c.dispose();
  });

  test('chaque département a une emprise ; la caméra la cadre', () {
    final departments = studioDepartments();
    final geometry = PlanGeometry(
      const OfficePlanner().plan(departments),
      departments,
    );
    for (final d in departments) {
      expect(geometry.departmentBounds(d.id), isNotNull, reason: d.name);
    }
    expect(geometry.departmentBounds('inconnu'), isNull);

    final bounds = geometry.departmentBounds(departments.first.id)!;
    final camera = OfficeCamera()
      ..setScene(
        geometry.size,
        focus: geometry.size.center(Offset.zero),
        contain: true,
      )
      ..setViewport(const Size(900, 600))
      ..frame(bounds);
    expect(camera.zoom, greaterThan(1));
    expect(camera.visibleRect.overlaps(bounds), isTrue);
    camera.dispose();
  });

  test('la fiche lit poste, modèles, tâches, exécutions et parcours', () async {
    http.Response json(Object? data) => http.Response.bytes(
      utf8.encode(jsonEncode(<String, Object?>{'data': data})),
      200,
    );
    final api = ApiClient(
      ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
      httpClient: MockClient((request) async {
        final path = request.url.path.replaceFirst('/api/v1/', '');
        return switch (path) {
          'agents/7' => json(<String, Object?>{
            'id': 7,
            'name': 'Inès',
            'position_id': 10,
            'status': 'active',
            'bio': 'Aime le code propre.',
            'ai_models': <Object?>[
              <String, Object?>{'ai_model_id': 100, 'is_default': true},
            ],
          }),
          'agents/7/assignments' => json(<Object?>[
            <String, Object?>{
              'position_title': 'Développeuse',
              'started_at': '2026-11-01T09:00:00Z',
            },
          ]),
          'tasks' => json(<Object?>[
            <String, Object?>{
              'id': 3,
              'title': 'Résumer les notes',
              'agents': <Object?>[
                <String, Object?>{'agent_id': 7, 'is_lead': true},
              ],
            },
          ]),
          'task-runs' => json(<Object?>[
            <String, Object?>{
              'id': 11,
              'task_id': 3,
              'agent_id': 7,
              'status': 'running',
              'cost_micros': 1500000,
              'device_name': 'POSTE-CEO',
            },
            <String, Object?>{
              'id': 12,
              'task_id': 4,
              'agent_id': 8,
              'status': 'completed',
              'cost_micros': 9000000,
            },
          ]),
          'positions' => json(<Object?>[
            <String, Object?>{'id': 10, 'title': 'Développeuse', 'unit_id': 2},
          ]),
          'units' => json(<Object?>[
            <String, Object?>{'id': 1, 'name': 'Technique'},
            <String, Object?>{'id': 2, 'name': 'Développement', 'parent_id': 1},
          ]),
          'ai-providers' => json(<Object?>[
            <String, Object?>{
              'id': 50,
              'name': 'Anthropic',
              'driver': 'anthropic',
              'models': <Object?>[
                <String, Object?>{
                  'id': 100,
                  'ai_provider_id': 50,
                  'identifier': 'claude-opus-5-5',
                  'label': 'Opus',
                },
              ],
            },
          ]),
          _ => http.Response('{}', 404),
        };
      }),
    );
    final sheet = AgentSheetController(api);

    await sheet.open('7');
    final d = sheet.dossier!;

    expect(sheet.error, isNull);
    expect(d.unitPath, 'Technique › Développement');
    expect(d.models, <(String, bool)>[('Opus', true)]);
    expect(d.tasks.single.lead, isTrue);
    expect(d.runs, hasLength(1));
    expect(d.currentRun?.id, 11);
    expect(d.costMicros, 1500000);
    expect(d.assignments.single.endedAt, isNull);

    // Démonstration : pas de fiche serveur.
    await sheet.open('atlas');
    expect(sheet.agentId, isNull);
    expect(sheet.dossier, isNull);
    sheet.dispose();
  });

  testWidgets('clic sur un département puis sur un agent', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LeadDeskApp(home: LiveOfficeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('vue d\'ensemble'), findsOneWidget);
    await tester.tap(find.byTooltip('Entrer dans le bureau Technique'));
    await tester.pump();
    expect(find.text('vue d\'ensemble'), findsNothing);
    expect(find.textContaining('/'), findsWidgets);
    expect(find.byTooltip('Revenir à la vue d\'ensemble'), findsOneWidget);

    await tester.tap(find.text('Forge').first);
    await tester.pump();
    expect(find.byTooltip('Fermer la fiche'), findsOneWidget);
    expect(find.textContaining('Agent de démonstration'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer la fiche'));
    await tester.pump();
    expect(find.byTooltip('Fermer la fiche'), findsNothing);
  });
}
