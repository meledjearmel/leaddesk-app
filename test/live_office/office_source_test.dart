import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/office_source.dart';

/// Faux serveur : une RH (unité 1, avec un pôle 3) et des Moyens généraux
/// (unité 2), deux agents dont un sans poste.
Map<String, Object?> _routes({Object? plan}) => <String, Object?>{
  'office/departments': <Object?>[
    <String, Object?>{
      'id': '1',
      'name': 'Ressources humaines',
      'headcount': 2,
      'color': '#B58BD9',
      'tags': <String>['recrutement', 'calme'],
    },
    <String, Object?>{
      'id': '2',
      'name': 'Moyens généraux',
      'headcount': 1,
      'color': null,
      'tags': <String>[],
    },
  ],
  'office/plan': plan,
  'units': <Object?>[
    <String, Object?>{'id': 1, 'parent_id': null},
    <String, Object?>{'id': 2, 'parent_id': null},
    <String, Object?>{'id': 3, 'parent_id': 1},
  ],
  'positions': <Object?>[
    <String, Object?>{'id': 10, 'unit_id': 3, 'title': 'Recruteur'},
    <String, Object?>{'id': 11, 'unit_id': 2, 'title': 'Responsable'},
  ],
  'agents': <Object?>[
    <String, Object?>{
      'id': 7,
      'name': 'Ysée',
      'position_id': 10,
      'status': 'active',
    },
    <String, Object?>{
      'id': 8,
      'name': 'Sans poste',
      'position_id': null,
      'status': 'draft',
    },
  ],
};

ApiClient _client(Map<String, Object?> routes, {List<String>? calls}) {
  final config = ApiConfig(
    baseUrl: Uri.parse('https://api.test/api/v1/'),
    token: 'secret',
  );
  return ApiClient(
    config,
    httpClient: MockClient((request) async {
      calls?.add('${request.headers['Authorization']} ${request.url.path}');
      final path = request.url.path.replaceFirst('/api/v1/', '');
      if (!routes.containsKey(path)) {
        return http.Response(jsonEncode({'message': 'Introuvable.'}), 404);
      }
      return http.Response(
        jsonEncode(<String, Object?>{'data': routes[path]}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );
}

Map<String, Object?> _validPlan() => <String, Object?>{
  'id': 4,
  'status': 'accepted',
  'layout': <String, Object?>{
    'version': 1,
    'cols': 20,
    'rows': 10,
    'rooms': <Object?>[
      <String, Object?>{
        'id': 'rh',
        'type': 'open_space',
        'department': '1',
        'x': 0,
        'y': 0,
        'cols': 6,
        'rows': 2,
      },
      <String, Object?>{
        'id': 'mg',
        'type': 'private_office',
        'department': '2',
        'x': 7,
        'y': 0,
        'cols': 3,
        'rows': 3,
      },
    ],
  },
};

void main() {
  group('ApiConfig', () {
    test('sans adresse ni jeton, pas de serveur', () {
      expect(ApiConfig.fromEnvironment(const <String, String>{}), isNull);
      expect(
        ApiConfig.fromEnvironment(const <String, String>{
          'LD_API_URL': 'pas une adresse',
          'LD_API_TOKEN': 'x',
        }),
        isNull,
      );
    });

    test('l\'adresse finit toujours par une barre', () {
      final config = ApiConfig.fromEnvironment(const <String, String>{
        'LD_API_URL': 'https://api.test/api/v1',
        'LD_API_TOKEN': 'x',
      });
      expect(config!.baseUrl.toString(), 'https://api.test/api/v1/');
    });
  });

  group('ApiOfficeSource', () {
    test(
      'RM-03 : les départements viennent du serveur, avec leurs activités',
      () async {
        final calls = <String>[];
        final snapshot = await ApiOfficeSource(_client(_routes(), calls: calls))
            .load();

        expect(snapshot.departments.map((d) => d.name), <String>[
          'Ressources humaines',
          'Moyens généraux',
        ]);
        expect(snapshot.departments.first.color, 0xFFB58BD9);
        expect(snapshot.departments.first.tags, <String>{
          'recrutement',
          'calme',
        });
        expect(snapshot.departments.last.headcount, 1);
        expect(calls, everyElement(startsWith('Bearer secret ')));
      },
    );

    test('un agent est rattaché au département de son poste', () async {
      final snapshot = await ApiOfficeSource(_client(_routes())).load();

      expect(snapshot.agents, hasLength(1));
      final agent = snapshot.agents.single;
      expect(agent.id, '7');
      expect(agent.position, 'Recruteur');
      // Le pôle 3 est sous l'unité 1 : l'agent travaille dans ses salles.
      expect(agent.departmentId, '1');
      expect(agent.status, 'En service');
    });

    test('le plan en vigueur sur le serveur est affiché', () async {
      final snapshot = await ApiOfficeSource(
        _client(_routes(plan: _validPlan())),
      ).load();

      expect(snapshot.planFromServer, isTrue);
      expect(snapshot.plan.rooms.map((room) => room.id), <String>['rh', 'mg']);
    });

    test('sans plan, l\'aménageur automatique prend le relais', () async {
      final snapshot = await ApiOfficeSource(_client(_routes())).load();

      expect(snapshot.planFromServer, isFalse);
      expect(snapshot.plan.validate(snapshot.departments), isEmpty);
    });

    test(
      'un plan du serveur devenu invalide est remplacé par l\'aménageur',
      () async {
        final plan = _validPlan();
        final layout = plan['layout']! as Map<String, Object?>;
        (layout['rooms']! as List<Object?>).removeLast();

        final snapshot = await ApiOfficeSource(_client(_routes(plan: plan)))
            .load();

        expect(snapshot.planFromServer, isFalse);
        expect(snapshot.plan.validate(snapshot.departments), isEmpty);
      },
    );
  });

  group('LiveOfficeController', () {
    test('les données du serveur remplacent la démonstration', () async {
      final controller = LiveOfficeController();
      final before = controller.revision;

      await controller.load(ApiOfficeSource(_client(_routes())));

      expect(controller.revision, before + 1);
      expect(controller.fromServer, isTrue);
      expect(controller.departments, hasLength(2));
      expect(controller.selectedAgentId, '7');
      // La conversation de démonstration garde ses agents.
      expect(controller.agentById('atlas').name, isNotEmpty);
      controller.dispose();
    });

    test('un serveur en erreur laisse les données affichées', () async {
      final controller = LiveOfficeController();
      final departments = controller.departments;

      await controller.load(
        ApiOfficeSource(_client(const <String, Object?>{})),
      );

      expect(controller.departments, same(departments));
      expect(controller.fromServer, isFalse);
      expect(controller.loadError, 'Introuvable.');
      controller.dispose();
    });
  });

  testWidgets('l\'écran recompose le plateau avec les données du serveur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLeadDeskTheme(),
          home: LiveOfficeScreen(
            source: ApiOfficeSource(_client(_routes(plan: _validPlan()))),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Ysée'), findsWidgets);
  });
}
