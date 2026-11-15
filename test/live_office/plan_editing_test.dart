import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/widgets/plan_editor_view.dart';

import '../support/proposal_source.dart';

Future<LiveOfficeController> _loaded(ProposalSource source) async {
  final controller = LiveOfficeController();
  await controller.load(source);
  return controller;
}

/// Déplace une salle vers une case libre à droite du plan.
void _moveSomewhereFree(LiveOfficeController controller) {
  final editor = controller.editor!;
  final room = editor.plan.rooms.first;
  editor.add('micro_kitchen');
  final added = editor.selected!;
  editor.remove(added.id);
  editor.move(room.id, room.x, room.y);
}

void main() {
  group('LiveOfficeController et mode « Aménager »', () {
    test(
      'entrer ferme la proposition ouverte et part du plan en vigueur',
      () async {
        final controller = await _loaded(ProposalSource());
        controller
          ..openProposalPanel(12)
          ..startEditing();

        expect(controller.editing, isTrue);
        expect(controller.openProposal, isNull);
        expect(controller.editor!.plan, same(controller.currentPlan));
        controller.dispose();
      },
    );

    test('D-016 : le plan du CEO est enregistré puis rechargé', () async {
      final source = ProposalSource();
      final controller = await _loaded(source);
      controller.startEditing();
      final editor = controller.editor!;
      final victim = editor.plan.rooms.firstWhere(
        (room) => room.departmentId == null,
      );
      editor.remove(victim.id);

      await controller.saveEditing();

      expect(source.saved, hasLength(1));
      expect(source.saved.single.rooms.any((r) => r.id == victim.id), isFalse);
      expect(controller.editing, isFalse);
      expect(controller.plan.rooms.any((r) => r.id == victim.id), isFalse);
      controller.dispose();
    });

    test('un brouillon invalide ne s\'enregistre pas', () async {
      final source = ProposalSource();
      final controller = await _loaded(source);
      controller.startEditing();
      final editor = controller.editor!;
      final first = editor.plan.rooms.first;
      final second = editor.plan.rooms[1];
      editor.move(second.id, first.x, first.y);

      expect(editor.canSave, isFalse);
      await controller.saveEditing();

      expect(source.saved, isEmpty);
      expect(controller.editing, isTrue);
      controller.dispose();
    });

    test(
      'un refus du serveur garde le brouillon et affiche l\'erreur',
      () async {
        final source = ProposalSource(
          failWith: const ApiException(422, 'Invalide.', <String, List<String>>{
            'layout': <String>['Produit : 2 postes pour 3 personnes.'],
          }),
        );
        final controller = await _loaded(source);
        controller.startEditing();
        final editor = controller.editor!;
        editor.remove(
          editor.plan.rooms.firstWhere((room) => room.departmentId == null).id,
        );

        await controller.saveEditing();

        expect(controller.editing, isTrue);
        expect(controller.saveError, 'Produit : 2 postes pour 3 personnes.');
        controller.dispose();
      },
    );

    test('annuler quitte sans rien enregistrer', () async {
      final source = ProposalSource();
      final controller = await _loaded(source);
      final plan = controller.plan;
      controller.startEditing();
      _moveSomewhereFree(controller);

      controller.cancelEditing();

      expect(controller.editing, isFalse);
      expect(controller.plan, same(plan));
      expect(source.saved, isEmpty);
      controller.dispose();
    });
  });

  testWidgets(
    'le bouton Aménager ouvre l\'éditeur ; un glisser déplace la salle',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLeadDeskTheme(),
            home: LiveOfficeScreen(source: ProposalSource()),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      await tester.tap(find.byIcon(Icons.design_services_outlined));
      await tester.pump();
      expect(find.text('Aménager le bureau'), findsOneWidget);
      expect(find.byType(PlanEditorView), findsOneWidget);
      expect(find.text('Aucune modification'), findsOneWidget);

      // Le plateau occupe le haut gauche de la vue ; on attrape la première
      // salle et on la glisse vers le bas.
      final view = tester.getRect(find.byType(PlanEditorView));
      await tester.dragFrom(
        view.topLeft + const Offset(80, 165),
        const Offset(0, 600),
      );
      await tester.pump();

      expect(find.text('Modifications non enregistrées'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Annuler'));
      await tester.pump();
      expect(find.byType(PlanEditorView), findsNothing);
    },
  );
}
