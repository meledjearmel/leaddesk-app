import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/live_office/office_camera.dart';
import 'package:leaddesk_app/live_office/scene/department_office.dart';
import 'package:leaddesk_app/live_office/scene/plan_scene.dart';
import 'package:leaddesk_app/live_office/widgets/office_view.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

void main() {
  group('Niveaux de détail de la vue « Salle »', () {
    test('agrandissements permis et niveau de chacun', () {
      expect(OfficeCamera.allowedPixels(3), <int>[1, 2, 3, 4, 6]);
      expect(OfficeCamera.allowedPixels(1), <int>[1, 2]);
      expect(
        <int>[
          for (final p in OfficeCamera.allowedPixels(3))
            OfficeCamera.levelFor(p.toDouble(), 3),
        ],
        <int>[1, 2, 3, 2, 3],
      );
    });

    for (final ratio in const <double>[1, 1.25, 1.5, 2]) {
      test('le niveau suit le zoom sans dépasser 2 pixels physiques par '
          'pixel du dessin (échelle Windows $ratio)', () {
        final camera = OfficeCamera()
          ..pixelRatio = ratio
          ..setViewport(const Size(900, 700))
          ..setScene(
            const Size(480, 330),
            focus: const Offset(240, 165),
            contain: true,
            levels: 3,
          );
        var previous = 0.0;
        final levels = <int>{};
        for (var i = 0; i < 40; i++) {
          final physical = camera.scale * ratio;
          final level = camera.level;
          levels.add(level);
          // Échelle qui croît avec le zoom.
          expect(physical, greaterThanOrEqualTo(previous - 1e-9));
          previous = physical;
          if (physical >= 1) {
            // Un pixel du dessin couvre un nombre entier de pixels
            // physiques, 2 au plus.
            final perDrawn = physical / level;
            expect(perDrawn, closeTo(perDrawn.roundToDouble(), 1e-9));
            expect(perDrawn, lessThanOrEqualTo(2 + 1e-9));
          }
          camera.zoomIn();
        }
        // Le zoom passe par les trois niveaux et plafonne au plus fin.
        expect(levels, containsAll(<int>[2, 3]));
        expect(camera.level, 3);
        expect(
          camera.scale * ratio,
          closeTo(OfficeCamera.maxPixelsPerArt(3).toDouble(), 1e-9),
        );
        camera.dispose();
      });
    }

    test('le plateau garde un seul niveau et son plafond (D-032)', () {
      final camera = OfficeCamera()
        ..setViewport(const Size(900, 700))
        ..setScene(
          const Size(1000, 700),
          focus: const Offset(500, 350),
          contain: true,
        );
      for (var i = 0; i < 40; i++) {
        camera.zoomIn();
        expect(camera.level, 1);
      }
      expect(camera.scale, OfficeCamera.maxScale);
      camera.dispose();
    });

    testWidgets('un niveau fin est préparé à la demande, puis libéré', (
      tester,
    ) async {
      final departments = studioDepartments(headcount: 2);
      final plan = const OfficePlanner().plan(departments);
      final office = DepartmentOffice.compose(plan, departments.first);
      late OfficeFrames frames;
      await tester.runAsync(() async {
        frames = OfficeFrames.plateau(
          office.geometry,
          const {},
          dense: true,
          levels: 3,
        );
        // Pas encore prêt : on montre le niveau ×1.
        final (_, shown) = frames.at(0, 3);
        expect(shown, 1);
        await frames.prepare(3);
        final (image, level) = frames.at(0, 3);
        expect(level, 3);
        expect(image.width, (office.geometry.size.width * 3).ceil());
        // Niveau ×2 demandé mais pas prêt : le ×1 reste affiché, jamais un
        // niveau plus fin que demandé.
        expect(frames.at(0, 2).$2, 1);
      });
      frames.dispose();
    });

    testWidgets('chaque niveau ajoute des détails au même bureau', (
      tester,
    ) async {
      final departments = studioDepartments(headcount: 4);
      final plan = const OfficePlanner().plan(departments);
      final office = DepartmentOffice.compose(
        plan,
        departments.firstWhere((d) => d.id == 'technique'),
      );
      final colors = <int>[];
      await tester.runAsync(() async {
        for (var lod = 1; lod <= 3; lod++) {
          final image = renderPlanFrame(office.geometry, dense: true, lod: lod);
          final data = await image.toByteData();
          final bytes = data!.buffer.asUint32List();
          // Nombre de couleurs distinctes : plus de détails, plus de teintes.
          colors.add(bytes.toSet().length);
          image.dispose();
        }
      });
      expect(colors[1], greaterThan(colors[0]));
      expect(colors[2], greaterThan(colors[1]));
    });
  });
}
