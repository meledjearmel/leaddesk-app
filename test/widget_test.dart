import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/main.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const LeadDeskApp(home: LiveOfficeScreen()));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  const desktop = Size(1440, 900);

  testWidgets("l'application démarre sur le bureau vivant", (tester) async {
    await _pumpApp(tester, desktop);

    expect(find.text('LeadDesk'), findsOneWidget);
    expect(find.text('Campagne de lancement'), findsOneWidget);
    expect(find.text('Atlas, Quill et vous'), findsOneWidget);
  });

  testWidgets('le bureau n\'a qu\'un thème, sombre (D-007, écart à RM-52)', (
    tester,
  ) async {
    await _pumpApp(tester, desktop);

    final context = tester.element(find.text('LeadDesk'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('Thème : Bureau'), findsOneWidget);
  });

  testWidgets('les agents sont regroupés par poste avec leur activité', (
    tester,
  ) async {
    await _pumpApp(tester, desktop);

    expect(find.text('Développeur (2)'), findsOneWidget);
    expect(find.text('Chef de projet (1)'), findsOneWidget);
    expect(find.text('Écrit du code · étape 14 sur 22'), findsOneWidget);
    expect(find.text('Lit l\'API de publication'), findsOneWidget);
  });

  testWidgets('la recherche filtre la liste des agents', (tester) async {
    await _pumpApp(tester, desktop);

    await tester.enterText(
      find.widgetWithText(TextField, 'Rechercher un agent'),
      'relay',
    );
    await tester.pump();

    expect(find.text('Testeur QA (1)'), findsOneWidget);
    expect(find.text('Développeur (2)'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Rechercher un agent'),
      'zzz',
    );
    await tester.pump();

    expect(
      find.text('Aucun agent ne correspond à cette recherche.'),
      findsOneWidget,
    );
  });

  testWidgets('la vitesse passe de 1x à 2x puis 4x et revient à 1x', (
    tester,
  ) async {
    await _pumpApp(tester, desktop);

    await tester.tap(find.text('Vitesse 1x'));
    await tester.pump();
    expect(find.text('Vitesse 2x'), findsOneWidget);

    await tester.tap(find.text('Vitesse 2x'));
    await tester.pump();
    await tester.tap(find.text('Vitesse 4x'));
    await tester.pump();
    expect(find.text('Vitesse 1x'), findsOneWidget);
  });

  testWidgets('la pause remplace « En cours » par « En pause »', (
    tester,
  ) async {
    await _pumpApp(tester, desktop);

    await tester.tap(find.byTooltip('Mettre en pause'));
    await tester.pump();

    expect(find.text('En pause'), findsOneWidget);
    expect(find.text('En cours'), findsNothing);
    expect(find.byTooltip('Reprendre'), findsOneWidget);
  });

  testWidgets('un message envoyé apparaît dans la conversation', (
    tester,
  ) async {
    await _pumpApp(tester, desktop);

    await tester.enterText(
      find.widgetWithText(TextField, 'Message à Atlas et Quill'),
      'Merci, on publie demain.',
    );
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();

    expect(find.text('Merci, on publie demain.'), findsOneWidget);
  });

  testWidgets('la conversation se ferme et se rouvre', (tester) async {
    await _pumpApp(tester, desktop);

    await tester.tap(find.byTooltip('Fermer la conversation'));
    await tester.pump();
    expect(find.text('Atlas, Quill et vous'), findsNothing);

    await tester.tap(find.byTooltip('Afficher la conversation'));
    await tester.pump();
    expect(find.text('Atlas, Quill et vous'), findsOneWidget);
  });

  testWidgets('la carte s\'ouvre sur le plateau, un département par salle, '
      'et bascule sur la salle détaillée', (tester) async {
    await _pumpApp(tester, desktop);

    expect(find.text('Vue : Plateau'), findsOneWidget);
    expect(find.text('Technique'), findsOneWidget);
    expect(find.text('Qualité et sécurité'), findsOneWidget);

    // Sans département visité, la vue « Salle » ouvre le premier.
    await tester.tap(find.text('Vue : Plateau'));
    await tester.pump();

    expect(find.text('Vue : Salle'), findsOneWidget);
    expect(find.text('Direction'), findsOneWidget);
    expect(find.text('Technique'), findsNothing);

    // Les flèches du fil d'Ariane passent d'un bureau à l'autre, en vue
    // « Salle » aussi.
    await tester.tap(find.byTooltip('Bureau suivant'));
    await tester.pump();
    await tester.tap(find.byTooltip('Bureau suivant'));
    await tester.pump();
    expect(find.text('Vue : Salle'), findsOneWidget);
    expect(find.text('Technique'), findsOneWidget);
    expect(find.text('Forge'), findsWidgets);

    // « Vue : Plateau » ramène au plateau, sur le même département.
    await tester.tap(find.text('Vue : Salle'));
    await tester.pump();
    expect(find.text('Vue : Plateau'), findsOneWidget);
    expect(find.text('Technique'), findsWidgets);
  });

  testWidgets('le panneau des agents se replie', (tester) async {
    await _pumpApp(tester, desktop);

    await tester.tap(find.byTooltip('Replier le panneau'));
    await tester.pump();

    expect(find.text('Réunissez vos agents'), findsNothing);
  });

  testWidgets('une fenêtre étroite ne garde que la carte, sans débordement', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(640, 480));

    expect(find.text('Réunissez vos agents'), findsNothing);
    expect(find.text('Atlas, Quill et vous'), findsNothing);
    expect(find.text('Campagne de lancement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
