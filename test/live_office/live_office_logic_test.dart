import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/models.dart';
import 'package:leaddesk_app/live_office/office_camera.dart';
import 'package:leaddesk_app/live_office/scene/iso.dart';
import 'package:leaddesk_app/live_office/scene/office_scene.dart';

void main() {
  group('LiveOfficeController', () {
    test('regroupe les agents par poste et filtre sans tenir compte de la '
        'casse', () {
      final controller = LiveOfficeController();
      addTearDown(controller.dispose);

      expect(controller.agentsByPosition.keys, <String>[
        'Chef de projet',
        'Développeur',
        'Testeur QA',
        'Rédacteur technique',
      ]);

      controller.search('  FORGE ');
      expect(controller.agentsByPosition.keys, <String>['Développeur']);
      expect(controller.agentsByPosition['Développeur'], hasLength(1));
    });

    test('ignore un message vide et horodate les autres à l\'heure réelle', () {
      final controller = LiveOfficeController(
        now: () => DateTime(2026, 11, 15, 9, 5),
      );
      addTearDown(controller.dispose);
      final before = controller.entries.length;

      controller.sendMessage('   ');
      expect(controller.entries, hasLength(before));

      controller.sendMessage(' Bien reçu. ');
      final last = controller.entries.last as UserMessage;
      expect(last.text, 'Bien reçu.');
      expect(last.time, '09:05');
    });

    test('RM-51 : la vitesse et la pause ne changent que le temps de la '
        'scène, jamais l\'heure des messages', () {
      final controller = LiveOfficeController(
        now: () => DateTime(2026, 11, 15, 14, 35),
      );
      addTearDown(controller.dispose);

      controller.advance(const Duration(seconds: 2));
      expect(controller.sceneTime.value, 2);

      controller.cycleSpeed();
      controller.advance(const Duration(seconds: 2));
      expect(controller.sceneTime.value, 6);

      controller.togglePaused();
      controller.advance(const Duration(seconds: 10));
      expect(controller.sceneTime.value, 6);

      controller.sendMessage('Toujours à l\'heure réelle.');
      expect((controller.entries.last as UserMessage).time, '14:35');
    });
  });

  group('OfficeCamera', () {
    Rect scene() => const Rect.fromLTWH(0, 0, sceneWidth, sceneHeight);

    bool covers(OfficeCamera camera) {
      final view = camera.visibleRect;
      const epsilon = 1e-6;
      return view.left >= scene().left - epsilon &&
          view.top >= scene().top - epsilon &&
          view.right <= scene().right + epsilon &&
          view.bottom <= scene().bottom + epsilon;
    }

    test('la scène remplit toujours la vue, quel que soit le déplacement', () {
      final camera = OfficeCamera()..setViewport(const Size(700, 880));
      addTearDown(camera.dispose);

      expect(covers(camera), isTrue);
      camera.panBy(const Offset(5000, -5000));
      expect(covers(camera), isTrue);
      camera.panBy(const Offset(-9000, 9000));
      expect(covers(camera), isTrue);
    });

    test('le zoom est borné et garde le point visé sous le curseur', () {
      final camera = OfficeCamera()..setViewport(const Size(900, 700));
      addTearDown(camera.dispose);
      const cursor = Offset(450, 350);
      final target = camera.toScene(cursor);

      camera.zoomAt(cursor, 1.5);
      expect(camera.zoom, 1.5);
      expect((camera.toScene(cursor) - target).distance, lessThan(1e-6));

      for (var i = 0; i < 20; i++) {
        camera.zoomIn();
      }
      // Plafonné : un pixel d'art ne dépasse pas 3 points (D-032).
      expect(camera.scale, lessThanOrEqualTo(OfficeCamera.maxScale));
      final capped = camera.zoom;
      camera.zoomIn();
      expect(camera.zoom, capped);

      for (var i = 0; i < 40; i++) {
        camera.zoomOut();
      }
      expect(camera.zoom, OfficeCamera.minZoom);
      expect(covers(camera), isTrue);
    });

    test('le recadrage revient au cadrage d\'ouverture', () {
      final camera = OfficeCamera()..setViewport(const Size(900, 700));
      addTearDown(camera.dispose);
      final opening = camera.center;

      camera
        ..zoomIn()
        ..panBy(const Offset(120, 80))
        ..reset();

      expect(camera.zoom, 1);
      expect(camera.center, opening);
    });

    test('les conversions écran ↔ scène sont inverses', () {
      final camera = OfficeCamera()..setViewport(const Size(900, 700));
      addTearDown(camera.dispose);
      const point = Offset(210, 140);

      expect(
        (camera.toScene(camera.toScreen(point)) - point).distance,
        lessThan(1e-6),
      );
    });
  });

  group('Scène', () {
    test('la projection isométrique est en 2:1', () {
      final origin = Iso.pt(0, 0);
      expect(Iso.pt(1, 0) - origin, const Offset(16, 8));
      expect(Iso.pt(0, 1) - origin, const Offset(-16, 8));
      expect(Iso.pt(0, 0, 10) - origin, const Offset(0, -10));
    });

    test('l\'agent qui marche reste dans la scène et fait demi-tour', () {
      const bounds = Rect.fromLTWH(0, 0, sceneWidth, sceneHeight);
      var sawLeft = false;
      var sawRight = false;
      for (var t = 0.0; t < 40; t += 0.25) {
        final walker = OfficeLayout.walkerAt(t);
        expect(bounds.contains(walker.feet), isTrue, reason: 't = $t');
        if (walker.walking) {
          sawLeft |= walker.faceLeft;
          sawRight |= !walker.faceLeft;
        }
      }
      expect(sawLeft && sawRight, isTrue);
    });

    testWidgets('chaque image d\'ambiance est rendue à la résolution d\'art', (
      tester,
    ) async {
      for (var frame = 0; frame < officeFrameCount; frame++) {
        final image = renderOfficeFrame(frame);
        expect(image.width, sceneWidth);
        expect(image.height, sceneHeight);
        image.dispose();
      }
    });
  });
}
