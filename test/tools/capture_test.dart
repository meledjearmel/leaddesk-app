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
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/auth/auth_screens.dart';
import 'package:leaddesk_app/auth/auth_service.dart';
import 'package:leaddesk_app/auth/session.dart';
import 'package:leaddesk_app/engine/host.dart';
import 'package:leaddesk_app/engine/run_controller.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/scene/office_scene.dart';
import 'package:leaddesk_app/live_office/scene/pixel_people.dart';
import 'package:leaddesk_app/live_office/scene/plan_scene.dart';
import 'package:leaddesk_app/live_office/widgets/decisions_panel.dart';
import 'package:leaddesk_app/live_office/widgets/run_panel.dart';
import 'package:leaddesk_app/main.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

import '../decisions/decisions_test.dart' show FakeDecisions, controllerFor;
import '../support/engine_fakes.dart';
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
        RepaintBoundary(
          key: key,
          child: const LeadDeskApp(home: LiveOfficeScreen()),
        ),
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

  for (final (setup, signUp) in const <(bool, bool)>[
    (false, false),
    (true, false),
    (false, true),
  ]) {
    testWidgets(
      'capture l\'écran '
      '${setup
          ? 'de création'
          : signUp
          ? 'd\'inscription'
          : 'de connexion'}',
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
        final auth = AuthService();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildLeadDeskTheme(),
              home: setup
                  ? CompanySetupScreen(
                      auth: auth,
                      session: Session(
                        baseUrl: Uri.parse('https://leaddesk.test/api/v1/'),
                        token: 't',
                        userName: 'Armel Meledje',
                        email: 'ceo@exemple.test',
                      ),
                      onCreated: (_) {},
                      onSignOut: () {},
                    )
                  : signUp
                  ? SignUpScreen(
                      auth: auth,
                      initialServer: 'leaddesk.exemple.com',
                      onSignedUp: (_) {},
                      onBack: (_) {},
                    )
                  : SignInScreen(
                      auth: auth,
                      initialServer: 'leaddesk.exemple.com',
                      onSignedIn: (_) {},
                      onDemo: () {},
                      onCreateAccount: (_) {},
                      onForgotPassword: (_) {},
                    ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          await _writePng(
            image,
            '$dir/${setup
                ? 'creation_entreprise'
                : signUp
                ? 'inscription'
                : 'connexion'}.png',
          );
          image.dispose();
        });
      },
    );
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

  for (final finished in const <bool>[false, true]) {
    testWidgets(
      'capture le panneau d\'exécution ${finished ? 'terminé' : 'au choix'}',
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
        tester.view.physicalSize = const Size(380, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final docs = Directory.systemTemp.createTempSync('ld_capture_');
        addTearDown(() => docs.deleteSync(recursive: true));
        File('${docs.path}/notes.md').writeAsStringSync('Livrer lundi.');
        final server = FakeServer()..folder = docs.path;
        final api = ApiClient(
          ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
          httpClient: server.client,
        );
        final vault = MemoryVault();
        await ProviderKeys(vault).setAnthropic('sk-ant-demo-a1b2');
        final engine = RunController(
          api: api,
          keys: ProviderKeys(vault),
          host: HostDevice(api: api, vault: vault, name: 'POSTE-CEO'),
          modelFactory: (_) => ScriptedModel(<Object>[
            toolTurn('read_file', <String, Object?>{
              'path': 'documentation/notes.md',
            }),
            toolTurn('write_file', <String, Object?>{
              'path': 'documentation/livrables/resume.md',
              'content': '# Résumé',
            }),
            endTurn(
              'J\'ai lu les notes et rédigé le résumé dans '
              'livrables/resume.md. Reste : valider la date avec Malo.',
            ),
          ]),
        );
        addTearDown(engine.dispose);

        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildLeadDeskTheme(),
              home: Scaffold(
                backgroundColor: LdColors.background,
                body: Padding(
                  padding: const EdgeInsets.all(8),
                  child: RunPanel(controller: engine, onClose: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await engine.load();
          if (finished) {
            await engine.launch();
          }
        });
        // Deux images : la seconde termine l'animation du bouton.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          await _writePng(
            image,
            '$dir/execution_${finished ? 'terminee' : 'choix'}.png',
          );
          image.dispose();
        });
      },
    );
  }

  testWidgets('capture la file des décisions', skip: skip, (tester) async {
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
    tester.view.physicalSize = const Size(380, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final decisions = controllerFor(FakeDecisions());
    addTearDown(decisions.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildLeadDeskTheme(),
          home: Scaffold(
            backgroundColor: LdColors.background,
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: DecisionsPanel(controller: decisions, onClose: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(decisions.load);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      await _writePng(image, '$dir/decisions.png');
      image.dispose();
    });
  });
}
