import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../live_office_controller.dart';
import '../models.dart';
import '../office_camera.dart';
import '../scene/office_scene.dart';
import '../scene/pixel_people.dart';
import '../scene/plan_scene.dart';

/// Images d'ambiance par seconde de scène.
const double _framesPerSecond = 3;

/// Images de la scène, rendues une fois puis partagées entre la vue et la
/// minicarte.
///
/// Avec plusieurs niveaux de détail (bureau d'un département), seul le
/// niveau ×1 est rendu tout de suite. Les niveaux ×2 et ×3 sont préparés
/// en arrière-plan la première fois qu'on zoome assez, puis gardés jusqu'à
/// [dispose] ; en attendant, le meilleur niveau prêt est affiché.
class OfficeFrames extends ChangeNotifier {
  OfficeFrames._(
    this.images, {
    required this.showWalker,
    this.levels = 1,
    this.renderLevel,
  });

  /// Vue détaillée : la salle de référence, avec l'agent qui marche.
  factory OfficeFrames.detailed() => OfficeFrames._(<ui.Image>[
    for (var i = 0; i < officeFrameCount; i++) renderOfficeFrame(i),
  ], showWalker: true);

  /// Plateau : le bureau entier, composé à partir du plan d'aménagement.
  ///
  /// [dense] : mobilier dense et habillage, pour le bureau complet d'un
  /// département (vue « Salle »).
  ///
  /// [levels] : niveaux de détail préparés à la demande (3 pour le bureau
  /// d'un département, 1 pour le plateau).
  factory OfficeFrames.plateau(
    PlanGeometry geometry,
    Map<String, List<PersonLook>> occupants, {
    Map<String, List<SeatState>> seatStates = const <String, List<SeatState>>{},
    bool dense = false,
    int levels = 1,
  }) => OfficeFrames._(
    <ui.Image>[
      for (var i = 0; i < officeFrameCount; i++)
        renderPlanFrame(
          geometry,
          occupants: occupants,
          seatStates: seatStates,
          frame: i,
          dense: dense,
        ),
    ],
    showWalker: false,
    levels: levels,
    renderLevel: levels <= 1
        ? null
        : (level) async => <ui.Image>[
            // Une image après l'autre : la mémoire monte sans à-coup.
            for (var i = 0; i < officeFrameCount; i++)
              await renderPlanFrameAsync(
                geometry,
                occupants: occupants,
                seatStates: seatStates,
                frame: i,
                dense: dense,
                lod: level,
              ),
          ],
  );

  /// Images du niveau ×1.
  final List<ui.Image> images;

  /// Vrai si l'agent qui fait les cent pas est dessiné par-dessus.
  final bool showWalker;

  /// Nombre de niveaux de détail (1 à 3).
  final int levels;

  /// Rendu d'un niveau fin, en arrière-plan ; `null` sans niveaux fins.
  final Future<List<ui.Image>> Function(int level)? renderLevel;
  final Map<int, List<ui.Image>> _fine = <int, List<ui.Image>>{};
  final Set<int> _pending = <int>{};
  bool _disposed = false;

  /// Taille de la scène, en pixels d'art.
  Size get size =>
      Size(images.first.width.toDouble(), images.first.height.toDouble());

  /// Niveaux fins déjà prêts.
  Set<int> get readyLevels => <int>{1, ..._fine.keys};

  /// Image à afficher pour [level] et son niveau réel : ce niveau s'il est
  /// prêt, sinon le plus fin des niveaux prêts en dessous. La préparation
  /// du niveau demandé est lancée au besoin.
  (ui.Image, int) at(double sceneTime, [int level = 1]) {
    final index = (sceneTime * _framesPerSecond).floor();
    final wanted = level.clamp(1, levels);
    request(wanted);
    for (var l = wanted; l > 1; l--) {
      if (_fine[l] case final ready?) {
        return (ready[index % ready.length], l);
      }
    }
    return (images[index % images.length], 1);
  }

  /// Prépare un niveau en arrière-plan ; prévient les écouteurs quand il
  /// est prêt.
  void request(int level) {
    final render = renderLevel;
    if (render == null ||
        level <= 1 ||
        level > levels ||
        _disposed ||
        _fine.containsKey(level) ||
        !_pending.add(level)) {
      return;
    }
    render(level)
        .then(
          (ready) {
            _pending.remove(level);
            if (_disposed) {
              for (final image in ready) {
                image.dispose();
              }
              return;
            }
            _fine[level] = ready;
            notifyListeners();
          },
          onError: (Object _) {
            _pending.remove(level);
          },
        )
        .ignore();
  }

  /// Prépare un niveau et attend qu'il soit prêt (captures, tests).
  Future<void> prepare(int level) async {
    final render = renderLevel;
    if (render == null || level <= 1 || _fine.containsKey(level)) {
      return;
    }
    _fine[level] = await render(level);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final image in images) {
      image.dispose();
    }
    for (final level in _fine.values) {
      for (final image in level) {
        image.dispose();
      }
    }
    _fine.clear();
    super.dispose();
  }
}

/// Dessin en direct par-dessus la scène, en pixels d'art : [canvas] est
/// déjà calé sur l'image ; [level] est le niveau de détail affiché.
typedef SceneOverlay = void Function(
  Canvas canvas,
  double sceneTime,
  int level,
);

/// La scène du bureau : déplacement à la souris, zoom à la molette ou par
/// pincement, animation d'ambiance.
class OfficeView extends StatefulWidget {
  const OfficeView({
    required this.controller,
    required this.camera,
    required this.frames,
    this.overlay,
    super.key,
  });

  final LiveOfficeController controller;
  final OfficeCamera camera;
  final OfficeFrames frames;

  /// Personnages qui bougent (café, couloir), dessinés en direct par-dessus
  /// les images.
  final SceneOverlay? overlay;

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
                overlay: widget.overlay,
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
    this.overlay,
  }) : super(repaint: Listenable.merge(<Listenable>[camera, time, frames]));

  final OfficeCamera camera;
  final ValueNotifier<double> time;
  final OfficeFrames frames;
  final SceneOverlay? overlay;

  @override
  void paint(Canvas canvas, Size size) {
    // Niveau de détail voulu par le zoom ; tant qu'il se prépare, le
    // niveau précédent reste affiché, à la même taille.
    final (image, level) = frames.at(time.value, camera.level);
    // Origine calée sur un pixel physique : chaque pixel d'art tombe sur la
    // grille de l'écran.
    final origin = camera.snap(camera.toScreen(Offset.zero));
    // Même fond que la scène : le plateau entier se fond dans la vue.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0908),
    );
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(origin.dx, origin.dy)
      // Un pixel du dessin couvre 1 ou 2 pixels physiques au plus.
      ..scale(camera.scale / level)
      // Agrandissement entier sans lissage : le grain du pixel art est
      // conservé ; une réduction, elle, est lissée pour rester lisible.
      ..drawImage(
        image,
        Offset.zero,
        Paint()
          ..filterQuality = camera.crisp
              ? FilterQuality.none
              : FilterQuality.medium
          ..isAntiAlias = false,
      );
    // Ce qui bouge se dessine en direct, en pixels d'art, au niveau de
    // détail affiché.
    canvas.scale(level.toDouble());
    if (frames.showWalker) {
      final walker = OfficeLayout.walkerAt(time.value);
      drawPerson(
        canvas,
        walker.feet,
        OfficeLooks.relay,
        pose: walker.walking ? PersonPose.walk : PersonPose.stand,
        faceLeft: walker.faceLeft,
        step: walker.step,
        paper: true,
        lod: level,
      );
    }
    overlay?.call(canvas, time.value, level);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OfficePainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.time != time ||
        oldDelegate.frames != frames ||
        oldDelegate.overlay != overlay;
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
    final scene = frames.size;
    final size = Size(width, width * scene.height / scene.width);
    void moveTo(Offset local) {
      camera.centerOn(local * (scene.width / width));
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
    final scene = frames.size;
    final ratio = size.width / scene.width;
    canvas
      ..drawImageRect(
        frames.images.first,
        Offset.zero & scene,
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
