import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../prototypes/iso_room/frame_stats.dart';
import '../../prototypes/iso_room/iso_math.dart';
import '../../prototypes/iso_room/pixel_sprites.dart';

void main() {
  const grid = IsoGrid(columns: 18, rows: 18);

  group('IsoGrid', () {
    test('projette les coins de la salle en losange 2:1', () {
      expect(grid.toScreen(0, 0), Offset.zero);
      expect(grid.toScreen(18, 0), const Offset(576, 288));
      expect(grid.toScreen(0, 18), const Offset(-576, 288));
      expect(grid.toScreen(18, 18), const Offset(0, 576));
    });

    test('toGrid est l inverse de toScreen', () {
      final point = grid.toGrid(grid.toScreen(4.25, 11.5));
      expect(point.x, closeTo(4.25, 1e-9));
      expect(point.y, closeTo(11.5, 1e-9));
    });

    test('la profondeur croît vers le bas de l écran', () {
      expect(grid.depthOf(3, 3), lessThan(grid.depthOf(3, 4)));
      expect(grid.depthOf(3, 3), lessThan(grid.depthOf(4, 3)));
    });

    test('les points aléatoires restent dans la salle', () {
      final random = Random(1);
      for (var i = 0; i < 500; i++) {
        final point = grid.randomPoint(random);
        expect(grid.contains(point.x, point.y), isTrue);
      }
    });
  });

  group('stepTowards', () {
    test('avance sans dépasser la distance demandée', () {
      final next = stepTowards(
        const Point<double>(0, 0),
        const Point<double>(3, 4),
        1,
      );
      expect(next.x, closeTo(0.6, 1e-9));
      expect(next.y, closeTo(0.8, 1e-9));
    });

    test('s arrête exactement sur la cible', () {
      const target = Point<double>(1, 1);
      expect(stepTowards(const Point<double>(0.9, 1), target, 0.5), target);
      expect(stepTowards(target, target, 0.5), target);
    });
  });

  group('FrameStats', () {
    test('résume les temps et compte les images lentes', () {
      final stats = FrameStats();
      for (var i = 0; i < 9; i++) {
        stats.addDurations(
          build: const Duration(milliseconds: 2),
          raster: const Duration(milliseconds: 3),
        );
      }
      stats.addDurations(
        build: const Duration(milliseconds: 10),
        raster: const Duration(milliseconds: 15),
      );

      final summary = stats.summary(elapsedSeconds: 0.2);
      expect(summary['frames'], 10);
      expect(summary['average_fps'], 50);
      expect(summary['total_ms_worst'], 25);
      expect(summary['slow_frame_percent'], 10);
    });

    test('reste à zéro sans image', () {
      final summary = FrameStats().summary(elapsedSeconds: 0);
      expect(summary['frames'], 0);
      expect(summary['average_fps'], 0);
    });
  });

  testWidgets('la planche d un agent contient cinq images de 16 x 24', (
    tester,
  ) async {
    final sheet = await tester.runAsync(() => buildAgentSheet(paletteFor(3)));
    expect(sheet!.width, agentFrameWidth * agentFrameCount);
    expect(sheet.height, agentFrameHeight);
  });

  test('deux agents voisins n ont pas la même palette', () {
    final a = paletteFor(0);
    final b = paletteFor(1);
    expect(a.shirt == b.shirt && a.hair == b.hair && a.skin == b.skin, isFalse);
  });
}
