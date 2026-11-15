import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../live_office_controller.dart';
import '../office_camera.dart';
import '../scene/iso.dart';
import '../scene/office_scene.dart';
import '../scene/pixel_people.dart';

/// Images d'ambiance par seconde de scène.
const double _framesPerSecond = 3;

/// Images de la scène, rendues une fois puis partagées entre la vue et la
/// minicarte.
class OfficeFrames {
  OfficeFrames()
    : images = <ui.Image>[
        for (var i = 0; i < officeFrameCount; i++) renderOfficeFrame(i),
      ];

  final List<ui.Image> images;

  ui.Image at(double sceneTime) {
    return images[(sceneTime * _framesPerSecond).floor() % images.length];
  }

  void dispose() {
    for (final image in images) {
      image.dispose();
    }
  }
}

/// La scène du bureau : déplacement à la souris, zoom à la molette ou par
/// pincement, animation d'ambiance.
class OfficeView extends StatefulWidget {
  const OfficeView({
    required this.controller,
    required this.camera,
    required this.frames,
    super.key,
  });

  final LiveOfficeController controller;
  final OfficeCamera camera;
  final OfficeFrames frames;

  @override
  State<OfficeView> createState() => _OfficeViewState();
}

class _OfficeViewState extends State<OfficeView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _pinchScale = 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      widget.controller.advance(elapsed - _last);
      _last = elapsed;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Sans animation si le système demande de les réduire.
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _ticker.start().ignore();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          camera.zoomAt(
            event.localPosition,
            event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
          );
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _pinchScale = 1,
          onScaleUpdate: (details) {
            if (details.scale != 1) {
              camera.zoomAt(
                details.localFocalPoint,
                details.scale / _pinchScale,
              );
              _pinchScale = details.scale;
            }
            camera.panBy(details.focalPointDelta);
          },
          child: Semantics(
            label: 'Bureau vivant : plan isométrique des agents au travail',
            child: CustomPaint(
              size: Size.infinite,
              painter: _OfficePainter(
                camera: camera,
                time: widget.controller.sceneTime,
                frames: widget.frames,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficePainter extends CustomPainter {
  _OfficePainter({
    required this.camera,
    required this.time,
    required this.frames,
  }) : super(repaint: Listenable.merge(<Listenable>[camera, time]));

  final OfficeCamera camera;
  final ValueNotifier<double> time;
  final OfficeFrames frames;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera.toScreen(Offset.zero);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(origin.dx, origin.dy)
      ..scale(camera.scale)
      // Agrandissement sans lissage : le grain du pixel art est conservé.
      ..drawImage(
        frames.at(time.value),
        Offset.zero,
        Paint()..filterQuality = FilterQuality.none,
      );
    final walker = OfficeLayout.walkerAt(time.value);
    drawPerson(
      canvas,
      walker.feet,
      OfficeLooks.relay,
      pose: walker.walking ? PersonPose.walk : PersonPose.stand,
      faceLeft: walker.faceLeft,
      step: walker.step,
      paper: true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OfficePainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.time != time ||
        oldDelegate.frames != frames;
  }
}

/// Minicarte : la scène entière, le cadre de la vue et un point par agent.
class OfficeMinimap extends StatelessWidget {
  const OfficeMinimap({
    required this.camera,
    required this.frames,
    required this.time,
    required this.markers,
    super.key,
  });

  static const double width = 132;

  final OfficeCamera camera;
  final OfficeFrames frames;
  final ValueNotifier<double> time;

  /// Position (en pixels d'art) et couleur de chaque agent.
  final List<(Offset, Color)> Function(double time) markers;

  @override
  Widget build(BuildContext context) {
    const size = Size(width, width * sceneHeight / sceneWidth);
    void moveTo(Offset local) {
      camera.centerOn(local * (sceneWidth / width));
    }

    return Semantics(
      label: 'Minicarte du bureau',
      child: GestureDetector(
        onTapDown: (details) => moveTo(details.localPosition),
        onPanUpdate: (details) => moveTo(details.localPosition),
        child: CustomPaint(
          size: size,
          painter: _MinimapPainter(
            camera: camera,
            frames: frames,
            time: time,
            markers: markers,
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.camera,
    required this.frames,
    required this.time,
    required this.markers,
  }) : super(repaint: Listenable.merge(<Listenable>[camera, time]));

  final OfficeCamera camera;
  final OfficeFrames frames;
  final ValueNotifier<double> time;
  final List<(Offset, Color)> Function(double time) markers;

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = size.width / sceneWidth;
    canvas
      ..drawImageRect(
        frames.images.first,
        const Rect.fromLTWH(0, 0, sceneWidth, sceneHeight),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      )
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0x8C000000));
    final view = camera.visibleRect;
    canvas.drawRect(
      Rect.fromLTRB(
        view.left * ratio,
        view.top * ratio,
        view.right * ratio,
        view.bottom * ratio,
      ).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFF5F3EF),
    );
    final dot = Paint();
    for (final (position, color) in markers(time.value)) {
      canvas.drawCircle(position * ratio, 3.2, dot..color = color);
    }
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) => true;
}
