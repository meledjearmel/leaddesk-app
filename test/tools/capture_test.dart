// Outil de contrôle visuel, inactif par défaut.
//
// La chaîne de compilation Windows n'est pas installée sur le poste (D-005) :
// ces captures permettent de comparer l'écran aux images de référence sans
// lancer l'application.
//
// Usage (PowerShell) :
//   $env:LD_CAPTURE_DIR = 'C:\chemin\vers\un\dossier'
//   flutter test test/tools/capture_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/admin/admin_controller.dart';
import 'package:leaddesk_app/admin/admin_screen.dart';
import 'package:leaddesk_app/admin/model_catalog.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/auth/auth_screens.dart';
import 'package:leaddesk_app/auth/auth_service.dart';
import 'package:leaddesk_app/auth/session.dart';
import 'package:leaddesk_app/engine/host.dart';
import 'package:leaddesk_app/engine/run_controller.dart';
import 'package:leaddesk_app/engine/run_journal.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';
import 'package:leaddesk_app/live_office/models.dart';
import 'package:leaddesk_app/live_office/scene/department_office.dart';
import 'package:leaddesk_app/live_office/scene/office_scene.dart';
import 'package:leaddesk_app/live_office/scene/pixel_people.dart';
import 'package:leaddesk_app/live_office/scene/plan_scene.dart';
import 'package:leaddesk_app/live_office/widgets/decisions_panel.dart';
import 'package:leaddesk_app/live_office/widgets/run_panel.dart';
import 'package:leaddesk_app/main.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

import '../decisions/decisions_test.dart' show FakeDecisions, controllerFor;
import '../support/admin_fakes.dart';
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

/// Agrandit une image d'un facteur entier, sans lissage.
ui.Image _upscale(ui.Image image, int factor) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..scale(factor.toDouble())
    ..drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.none,
    );
  final picture = recorder.endRecording();
  final big = picture.toImageSync(image.width * factor, image.height * factor);
  picture.dispose();
  return big;
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

  // Vue « Salle » : le bureau complet d'un département, image d'art seule.
  for (final id in const <String>['technique', 'produit', 'direction']) {
    testWidgets('capture la salle $id', skip: skip, (tester) async {
      await tester.runAsync(() async {
        final departments = studioDepartments(headcount: 4);
        final plan = const OfficePlanner().plan(departments);
        final department = departments.firstWhere((d) => d.id == id);
        final office = DepartmentOffice.compose(plan, department);
        final image = renderPlanFrame(
          office.geometry,
          dense: true,
          occupants: <String, List<PersonLook>>{
            id: <PersonLook>[
              for (var i = 0; i < department.headcount - 1; i++)
                PersonLook(
                  skin: const <Color>[
                    Color(0xFFEBC29A),
                    Color(0xFFA9714B),
                    Color(0xFFD9A47A),
                  ][i % 3],
                  hair: const Color(0xFF2B1F1C),
                  top: Color(department.color),
                ),
            ],
          },
        );
        await _writePng(image, '$dir/salle_$id.png');
        // Même image agrandie trois fois sans lissage, pour juger du détail.
        final big = _upscale(image, 3);
        await _writePng(big, '$dir/salle_${id}_zoom.png');
        big.dispose();
        image.dispose();
      });
    });
  }

  // Niveaux de détail : le même coin du bureau Technique aux niveaux ×1, ×2
  // et ×3, affiché à la même taille (6 pixels par pixel d'art), puis le
  // bureau entier au niveau ×3.
  testWidgets('capture les niveaux de détail', skip: skip, (tester) async {
    await tester.runAsync(() async {
      final departments = studioDepartments(headcount: 4);
      final plan = const OfficePlanner().plan(departments);
      final department = departments.firstWhere((d) => d.id == 'technique');
      final office = DepartmentOffice.compose(plan, department);
      final looks = <String, List<PersonLook>>{
        department.id: <PersonLook>[
          for (var i = 0; i < department.headcount - 1; i++)
            PersonLook(
              skin: const <Color>[
                Color(0xFFEBC29A),
                Color(0xFFA9714B),
                Color(0xFFD9A47A),
              ][i % 3],
              hair: const <Color>[
                Color(0xFF2B1F1C),
                Color(0xFF7A3A22),
                Color(0xFF4A2E1E),
              ][i % 3],
              top: Color(department.color),
              glasses: i == 1,
            ),
        ],
      };
      final seat = office.desks[1];
      final focus = office.geometry.toImage(seat.x, seat.y);
      final crop = Rect.fromCenter(
        center: focus + const Offset(0, -12),
        width: 180,
        height: 120,
      );
      for (var lod = 1; lod <= 3; lod++) {
        final image = renderPlanFrame(
          office.geometry,
          occupants: looks,
          dense: true,
          lod: lod,
        );
        final recorder = ui.PictureRecorder();
        final factor = 6 / lod;
        Canvas(recorder)
          ..scale(factor)
          ..drawImageRect(
            image,
            Rect.fromLTWH(
              crop.left * lod,
              crop.top * lod,
              crop.width * lod,
              crop.height * lod,
            ),
            Rect.fromLTWH(0, 0, crop.width * lod, crop.height * lod),
            Paint()..filterQuality = FilterQuality.none,
          );
        final picture = recorder.endRecording();
        final out = picture.toImageSync(
          (crop.width * 6).round(),
          (crop.height * 6).round(),
        );
        picture.dispose();
        await _writePng(out, '$dir/niveau_x$lod.png');
        out.dispose();
        if (lod == 3) {
          await _writePng(image, '$dir/salle_technique_x3.png');
        }
        image.dispose();
      }
    });
  });

  // Agents selon leur état réel : assis au travail, debout (décision,
  // limite de coût), bloqué, en veille, au café ou en marche, poste vacant.
  testWidgets('capture les agents selon leur état', skip: skip, (tester) async {
    await tester.runAsync(() async {
      final departments = studioDepartments(headcount: 6);
      final plan = const OfficePlanner().plan(departments);
      final department = departments.firstWhere((d) => d.id == 'technique');
      final office = DepartmentOffice.compose(plan, department);
      const states = <AgentState>[
        AgentState.working,
        AgentState.waitingDecision,
        AgentState.pausedCost,
        AgentState.blocked,
        AgentState.waitingHost,
        AgentState.idle,
        AgentState.paused,
      ];
      final looks = <PersonLook>[
        for (var i = 0; i < states.length; i++)
          PersonLook(
            skin: const <Color>[
              Color(0xFFEBC29A),
              Color(0xFFA9714B),
              Color(0xFFD9A47A),
            ][i % 3],
            hair: const <Color>[
              Color(0xFF2B1F1C),
              Color(0xFF7A3A22),
              Color(0xFF4A2E1E),
            ][i % 3],
            top: const <Color>[
              Color(0xFF2A3854),
              Color(0xFF3F7650),
              Color(0xFF8A3A32),
              Color(0xFF3C5FA8),
            ][i % 4],
            glasses: i == 2,
            longHair: i == 1 || i == 5,
          ),
      ];
      for (final lod in const <int>[1, 3]) {
        final image = renderPlanFrame(
          office.geometry,
          occupants: <String, List<PersonLook>>{department.id: looks},
          seatStates: <String, List<SeatState>>{
            department.id: <SeatState>[for (final s in states) s.seat],
          },
          dense: true,
          lod: lod,
        );
        // Les agents partis (café, couloir) sont dessinés en direct.
        final recorder = ui.PictureRecorder();
        final scale = lod == 1 ? 3.0 : 1.0;
        final canvas = Canvas(recorder)
          ..scale(scale)
          ..drawImage(
            image,
            Offset.zero,
            Paint()..filterQuality = FilterQuality.none,
          )
          ..scale(lod.toDouble());
        var slot = 0;
        for (final (i, state) in states.indexed) {
          if (state.seat.presence != SeatPresence.away) {
            continue;
          }
          final pose = office.awayPose(slot++, 4.0 + i * 6);
          drawPerson(
            canvas,
            office.geometry.toImage(pose.at.dx, pose.at.dy),
            looks[i],
            pose: pose.walking ? PersonPose.walk : PersonPose.stand,
            faceLeft: pose.faceLeft,
            step: pose.step,
            mug: pose.atCafe,
            lod: lod,
            mood: PersonMood.happy,
          );
        }
        final picture = recorder.endRecording();
        final out = picture.toImageSync(
          (image.width * scale).round(),
          (image.height * scale).round(),
        );
        picture.dispose();
        await _writePng(out, '$dir/etats_x$lod.png');
        out.dispose();
        image.dispose();
      }
    });
  });

  // Vue « Salle » dans l'écran : à l'ouverture, puis de près (niveau fin
  // préparé en arrière-plan).
  testWidgets('capture la vue salle dans l\'écran', skip: skip, (tester) async {
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
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const LeadDeskApp(home: LiveOfficeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Bureau suivant'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Vue : Plateau'));
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> shoot(String name) async {
      // Laisse le niveau fin se préparer, puis l'affiche.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        await _writePng(image, '$dir/$name.png');
        image.dispose();
      });
    }

    await shoot('salle_ecran');
    for (var zoom = 0; zoom < 2; zoom++) {
      await tester.tap(find.byTooltip('Zoom avant'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot('salle_ecran_pres');
    for (var zoom = 0; zoom < 2; zoom++) {
      await tester.tap(find.byTooltip('Zoom avant'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot('salle_ecran_tres_pres');

    // Bureau précédent, toujours en vue « Salle » : Produit, où Atlas,
    // disponible, est au café ou dans le couloir.
    await tester.tap(find.byTooltip('Bureau précédent'));
    await tester.pump(const Duration(milliseconds: 100));
    await shoot('salle_ecran_produit');
    for (var zoom = 0; zoom < 3; zoom++) {
      await tester.tap(find.byTooltip('Zoom avant'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot('salle_ecran_produit_pres');
  });

  testWidgets('capture un bureau visité et une fiche agent', skip: skip, (
    tester,
  ) async {
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
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const LeadDeskApp(home: LiveOfficeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Bureau suivant'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Forge').first);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      await _writePng(image, '$dir/bureau_visite.png');
      image.dispose();
    });
  });

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
        if (!finished) {
          server.openRuns = <Map<String, Object?>>[
            <String, Object?>{
              'id': 11,
              'task_id': 4,
              'agent_id': 8,
              'status': 'paused_cost',
            },
          ];
        }
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
          journal: MemoryRunJournal(),
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

  for (final (name, section, selected) in const <(String, AdminSection, int)>[
    ('admin_unites', AdminSection.units, 1),
    ('admin_agent', AdminSection.agents, 7),
    ('admin_modeles', AdminSection.providers, 50),
  ]) {
    testWidgets('capture le back-office : $name', skip: skip, (tester) async {
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
      tester.view.physicalSize = const Size(1280, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final vault = MemoryVault();
      await ProviderKeys(vault).setAnthropic('sk-ant-capture-a1b2');
      final admin = AdminController(
        FakeAdminServer().api(),
        keys: ProviderKeys(vault),
        catalog: ModelCatalog(
          MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(
                jsonEncode(<String, Object?>{
                  'data': <Object?>[
                    for (final (id, label) in const <(String, String)>[
                      ('claude-opus-5-5', 'Claude Opus 5.5'),
                      ('claude-sonnet-5-5', 'Claude Sonnet 5.5'),
                      ('claude-haiku-5-5', 'Claude Haiku 5.5'),
                    ])
                      <String, Object?>{'id': id, 'display_name': label},
                  ],
                  'has_more': false,
                }),
              ),
              200,
            ),
          ),
        ),
      );
      addTearDown(admin.dispose);
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
                child: AdminScreen(controller: admin, onClose: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(admin.load);
      admin
        ..open(section)
        ..select(selected);
      if (section == AdminSection.providers) {
        await tester.runAsync(
          () => admin.fetchRemoteModels(admin.provider(selected)!),
        );
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        await _writePng(image, '$dir/$name.png');
        image.dispose();
      });
    });
  }
}
