import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/widgets/proposal_panel.dart';

import '../support/proposal_source.dart';

Future<LiveOfficeController> _loaded(ProposalSource source) async {
  final controller = LiveOfficeController();
  await controller.load(source);
  return controller;
}

Future<void> _pumpScreen(WidgetTester tester, ProposalSource source) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLeadDeskTheme(),
        home: LiveOfficeScreen(source: source),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

void main() {
  group('LiveOfficeController et propositions', () {
    test('ouvrir une proposition montre son plan sur la carte', () async {
      final controller = await _loaded(ProposalSource());
      final current = controller.plan;
      final revision = controller.revision;

      controller.openProposalPanel(12);

      expect(controller.previewing, isTrue);
      expect(controller.plan, same(controller.openProposal!.plan));
      expect(controller.currentPlan, same(current));
      expect(controller.revision, revision + 1);

      controller.showProposedPlan(proposed: false);
      expect(controller.plan, same(current));

      controller.closeProposalPanel();
      expect(controller.openProposal, isNull);
      expect(controller.plan, same(current));
      controller.dispose();
    });

    test(
      'D-012 : le CEO accepte, la proposition disparaît après rechargement',
      () async {
        final source = ProposalSource();
        final controller = await _loaded(source);
        controller.openProposalPanel(12);

        await controller.decide(accept: true);

        expect(source.decisions, <String>['accept 12']);
        expect(controller.proposals, isEmpty);
        expect(controller.openProposal, isNull);
        expect(controller.previewing, isFalse);
        controller.dispose();
      },
    );

    test('D-012 : le CEO refuse', () async {
      final source = ProposalSource();
      final controller = await _loaded(source);
      controller.openProposalPanel(12);

      await controller.decide(accept: false);

      expect(source.decisions, <String>['reject 12']);
      controller.dispose();
    });

    test('un refus du serveur laisse la proposition ouverte', () async {
      final source = ProposalSource(
        failWith: const ApiException(422, 'Invalide.', <String, List<String>>{
          'layout': <String>['Produit : 2 postes pour 3 personnes.'],
        }),
      );
      final controller = await _loaded(source);
      controller.openProposalPanel(12);

      await controller.decide(accept: true);

      expect(controller.openProposal, isNotNull);
      expect(controller.deciding, isFalse);
      expect(controller.decisionError, 'Produit : 2 postes pour 3 personnes.');
      controller.dispose();
    });
  });

  testWidgets('le bandeau ouvre le panneau de validation', (tester) async {
    await _pumpScreen(tester, ProposalSource());

    expect(find.text('Réaménagement proposé par Lisandre'), findsOneWidget);
    await tester.tap(find.text('Examiner'));
    await tester.pump();

    expect(find.text('Réaménagement'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.textContaining('Trois recrutements arrivent'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Le plan respecte toutes les règles.'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ProposalPanel),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(find.text('Le plan respecte toutes les règles.'), findsOneWidget);
    expect(find.text('Aperçu du plan proposé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepter un plan qui retire des salles demande confirmation', (
    tester,
  ) async {
    final source = ProposalSource();
    await _pumpScreen(tester, source);
    await tester.tap(find.text('Examiner'));
    await tester.pump();

    await tester.tap(find.text('Accepter'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Retirer des salles ?'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.decisions, isEmpty);

    await tester.tap(find.text('Accepter'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await tester.tap(find.text('Accepter le plan'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 400));

    expect(source.decisions, <String>['accept 12']);
    expect(find.text('Réaménagement'), findsNothing);
  });
}
