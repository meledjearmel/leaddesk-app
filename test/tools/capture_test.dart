// Outil de contrôle visuel, inactif par défaut.
//
// La chaîne de compilation Windows n'est pas installée sur le poste (D-005) :
// ces captures permettent de comparer l'écran aux images de référence sans
// lancer l'application.
//
// Usage (PowerShell) :
//   $env:LD_CAPTURE_DIR = 'C:\chemin\vers\un\dossier'
//   flutter test test/tools/capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/scene/office_scene.dart';
import 'package:leaddesk_app/live_office/scene/pixel_people.dart';
import 'package:leaddesk_app/live_office/scene/plan_scene.dart';
import 'package:leaddesk_app/main.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

import '../support/proposal_source.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
  }
  await loader.load();
}

Future<void> _writePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  final dir = Platform.environment['LD_CAPTURE_DIR'];
  final skip = dir == null || dir.isEmpty;

  testWidgets('capture la scène seule', skip: skip, (tester) async {
    await tester.runAsync(() async {
      final image = renderOfficeFrame(0);
      await _writePng(image, '$dir/scene.png');
      image.dispose();
    });
  });

  for (final headcount in const <int>[2, 6]) {
    testWidgets(
      'capture le plan du studio à $headcount par département',
      skip: skip,
      (tester) async {
        await tester.runAsync(() async {
          final departments = studioDepartments(headcount: headcount);
          final geometry = PlanGeometry(
            const OfficePlanner().plan(departments),
            departments,
          );
          final image = renderPlanFrame(
            geometry,
            occupants: <String, List<PersonLook>>{
              for (final d in departments)
                d.id: <PersonLook>[
                  for (var i = 0; i < d.headcount - 1; i++)
                    PersonLook(
                      skin: const <Color>[
                        Color(0xFFEBC29A),
                        Color(0xFFA9714B),
                        Color(0xFFD9A47A),
                      ][i % 3],
                      hair: const Color(0xFF2B1F1C),
                      top: Color(d.color),
                    ),
                ],
            },
          );
          await _writePng(image, '$dir/plan_$headcount.png');
          image.dispose();
        });
      },
    );
  }

  for (final size in const <Size>[Size(1440, 900), Size(1920, 1080)]) {
    testWidgets('capture l\'écran en ${size.width.toInt()}', skip: skip, (
      tester,
    ) async {
      // flutter_tester se trouve dans bin/cache/artifacts/engine/<plateforme>.
      final flutterRoot =
          Platform.environment['FLUTTER_ROOT'] ??
          File(Platform.resolvedExecutable)
              .parent
              .parent
              .parent
              .parent
              .parent
              .parent
              .path;
      await _loadFont('Segoe UI', const <String>[
        r'C:\Windows\Fonts\segoeui.ttf',
        r'C:\Windows\Fonts\seguisb.ttf',
        r'C:\Windows\Fonts\segoeuib.ttf',
      ]);
      await _loadFont('MaterialIcons', <String>[
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ]);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const LeadDeskApp()),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        await _writePng(image, '$dir/ecran_${size.width.toInt()}.png');
        image.dispose();
      });
    });
  }

  for (final (preview, edit) in const <(bool, bool)>[
    (false, false),
    (true, false),
    (false, true),
  ]) {
    testWidgets(
      'capture ${edit ? 'l\'aménagement' : 'la validation d\'une proposition'}'
      '${preview ? ' (aperçu)' : ''}',
      skip: skip,
      (tester) async {
        await _loadFont('Segoe UI', const <String>[
          r'C:\Windows\Fonts\segoeui.ttf',
          r'C:\Windows\Fonts\seguisb.ttf',
          r'C:\Windows\Fonts\segoeuib.ttf',
        ]);
        final flutterRoot =
            Platform.environment['FLUTTER_ROOT'] ??
            File(Platform.resolvedExecutable)
                .parent
                .parent
                .parent
                .parent
                .parent
                .parent
                .path;
        await _loadFont('MaterialIcons', <String>[
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ]);
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        await tester.runAsync(() async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildLeadDeskTheme(),
                home: LiveOfficeScreen(source: ProposalSource()),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 300));
        if (preview) {
          await tester.tap(find.text('Examiner'));
          await tester.pump(const Duration(milliseconds: 600));
        }
        if (edit) {
          await tester.tap(find.byIcon(Icons.design_services_outlined));
          await tester.pump(const Duration(milliseconds: 300));
          // Une salle ajoutée depuis le catalogue est aussitôt choisie.
          await tester.tap(find.text('Bureau individuel'));
          await tester.pump(const Duration(milliseconds: 300));
        }

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          await _writePng(
            image,
            edit
                ? '$dir/amenager.png'
                : '$dir/proposition_${preview ? 'apercu' : 'bandeau'}.png',
          );
          image.dispose();
        });
      },
    );
  }
}
