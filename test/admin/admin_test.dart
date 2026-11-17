import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/admin/admin_controller.dart';
import 'package:leaddesk_app/admin/admin_models.dart';
import 'package:leaddesk_app/admin/admin_screen.dart';
import 'package:leaddesk_app/app/theme.dart';

import '../support/admin_fakes.dart';

Widget adminApp(AdminController controller) => MaterialApp(
  theme: buildLeadDeskTheme(),
  home: Scaffold(
    backgroundColor: LdColors.background,
    body: AdminScreen(controller: controller),
  ),
);

void main() {
  test('charge l\'organisation et la range en arbre', () async {
    final server = FakeAdminServer();
    final admin = AdminController(server.api());
    await admin.load();

    expect(admin.error, isNull);
    expect(admin.companyName, 'Studio Nova');
    expect(
      <(String, int)>[for (final (u, d) in admin.unitTree) (u.name, d)],
      <(String, int)>[
        ('Technique', 0),
        ('Développement', 1),
        ('Ressources humaines', 0),
      ],
    );
    expect(admin.unitPath(2), 'Technique › Développement');
    expect(admin.isSelfOrDescendant(2, 1), isTrue);
    expect(admin.isSelfOrDescendant(3, 1), isFalse);
    expect(admin.allModels, hasLength(2));
    expect(admin.drivers.first, ('anthropic', 'Anthropic'));
    admin.dispose();
  });

  test('crée un agent, lui donne un modèle puis le met en service', () async {
    final server = FakeAdminServer();
    final admin = AdminController(server.api());
    await admin.load();

    final ok = await admin.saveAgent(
      name: 'Malo',
      positionId: 10,
      models: const <AgentModelLink>[
        AgentModelLink(aiModelId: 101, isDefault: true),
      ],
      active: true,
    );

    expect(ok, isTrue);
    expect(server.writes, <String>[
      'POST agents',
      'PUT agents/200/ai-models',
      'POST agents/200/activate',
    ]);
    expect(admin.selectedId, 200);
    expect(admin.agent(200)?.active, isTrue);
    expect(admin.notice, 'Agent créé.');
    admin.dispose();
  });

  test('repasse en brouillon avant de retirer les modèles', () async {
    final server = FakeAdminServer();
    final admin = AdminController(server.api());
    await admin.load();

    await admin.saveAgent(
      id: 7,
      name: 'Inès',
      positionId: null,
      models: const <AgentModelLink>[],
      active: false,
    );

    expect(server.writes, <String>[
      'PATCH agents/7',
      'POST agents/7/position',
      'POST agents/7/deactivate',
      'PUT agents/7/ai-models',
    ]);
    expect(admin.agent(7)?.positionId, isNull);
    admin.dispose();
  });

  test('montre le message de validation du serveur', () async {
    final server = FakeAdminServer()
      ..failures['POST units'] = (
        422,
        <String, Object?>{
          'message': 'Données invalides.',
          'errors': <String, Object?>{
            'color': <String>['Le format de la couleur est invalide.'],
          },
        },
      );
    final admin = AdminController(server.api());
    await admin.load();
    admin.startCreating();

    final ok = await admin.saveUnit(
      name: 'Design',
      color: 'bleu',
      activityTags: const <String>[],
    );

    expect(ok, isFalse);
    expect(admin.error, 'Le format de la couleur est invalide.');
    expect(admin.creating, isTrue);
    admin.dispose();
  });

  test(
    'une clé collée à la place de l\'adresse n\'est jamais envoyée',
    () async {
      final server = FakeAdminServer();
      final admin = AdminController(server.api());
      await admin.load();

      final ok = await admin.saveProvider(
        name: 'Claude',
        driver: 'anthropic',
        baseUrl: 'sk-ant-usr-1YA2l****Qv3qzQ8mwEpAAA',
      );

      expect(ok, isFalse);
      expect(server.writes, isEmpty);
      expect(admin.error, contains('clé d\'API'));
      expect(
        await admin.saveProvider(
          name: 'X',
          driver: 'openai',
          baseUrl: 'ftp://a',
        ),
        isFalse,
      );
      expect(server.writes, isEmpty);
      expect(
        AdminController.looksLikeSecret('https://api.example.com'),
        isFalse,
      );
      admin.dispose();
    },
  );

  testWidgets('la corbeille demande confirmation et se restaure', (
    tester,
  ) async {
    final server = FakeAdminServer();
    final admin = AdminController(server.api());
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    await tester.pumpWidget(adminApp(admin));
    await tester.runAsync(admin.load);
    await tester.pump();

    await tester.tap(find.text('Développement'));
    await tester.pump();
    expect(find.text('Mettre à la corbeille'), findsOneWidget);

    // Annuler : rien n'est supprimé.
    await tester.tap(find.text('Mettre à la corbeille'));
    await tester.pumpAndSettle();
    expect(find.text('Mettre « Développement » à la corbeille ?'), findsOne);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(server.writes, isEmpty);

    // Confirmer.
    await tester.tap(find.text('Mettre à la corbeille'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Mettre à la corbeille').last);
      for (var i = 0; i < 50 && admin.busy == false; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      for (var i = 0; i < 200 && admin.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(server.writes, <String>['DELETE units/2']);
    expect(find.text('Corbeille (1)'), findsOneWidget);

    await tester.tap(find.text('Corbeille (1)'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Restaurer'));
      for (var i = 0; i < 200 && admin.trashedUnits.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    expect(server.writes.last, 'POST units/2/restore');
    expect(admin.units.map((u) => u.name), contains('Développement'));
    admin.dispose();
  });

  testWidgets('une unité système ne propose pas la corbeille', (tester) async {
    final admin = AdminController(FakeAdminServer().api());
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    await tester.pumpWidget(adminApp(admin));
    await tester.runAsync(admin.load);
    await tester.pump();

    await tester.tap(find.text('Ressources humaines'));
    await tester.pump();

    expect(find.text('Mettre à la corbeille'), findsNothing);
    expect(find.textContaining('ne se supprime pas'), findsOneWidget);
    admin.dispose();
  });
}
