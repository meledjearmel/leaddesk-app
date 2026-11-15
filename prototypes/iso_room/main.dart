// Prototype 1 (phase 0) : salle isométrique Flame avec une trentaine d'agents
// animés, et mesure de la fluidité.
//
// Lancement :
//   flutter run -d windows -t prototypes/iso_room/main.dart
// Mesure (écrit un fichier JSON puis quitte) :
//   variables d'environnement AGENTS=30 et BENCH_SECONDS=20, puis
//   flutter run -d windows --profile -t prototypes/iso_room/main.dart
// La mesure écrit aussi une capture PNG à côté du fichier JSON.
//
// Code jetable : rien ici n'est importé par lib/.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../bench_support.dart';
import 'frame_stats.dart';
import 'iso_math.dart';
import 'pixel_sprites.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final benchOut = envString('BENCH_OUT', 'bench_iso_room.json');
  final screenKey = GlobalKey();
  runApp(
    RepaintBoundary(
      key: screenKey,
      child: GameWidget<IsoRoomGame>(
        game: IsoRoomGame(
          agentCount: envInt('AGENTS', 30),
          benchSeconds: envInt('BENCH_SECONDS', 0),
          benchOut: benchOut,
          onBeforeExit: () => saveScreenshot(
            screenKey,
            benchOut.replaceAll(RegExp(r'\.json$'), '.png'),
          ),
        ),
      ),
    ),
  );
}

class IsoRoomGame extends FlameGame {
  IsoRoomGame({
    this.agentCount = 30,
    this.benchSeconds = 0,
    this.benchOut = 'bench_iso_room.json',
    this.onBeforeExit,
    Random? random,
  }) : _random = random ?? Random(7);

  static const double warmupSeconds = 2;
  static const IsoGrid grid = IsoGrid(columns: 18, rows: 18);

  final int agentCount;
  final int benchSeconds;
  final String benchOut;

  /// Appelé après l'écriture du rapport, juste avant de quitter.
  final Future<void> Function()? onBeforeExit;
  final Random _random;

  final FrameStats stats = FrameStats();
  late final TextComponent _hud;
  double _elapsed = 0;
  double _hudTimer = 0;
  int _hudFrames = 0;
  bool _warm = false;
  bool _reported = false;

  @override
  Color backgroundColor() => const Color(0xFFBBA8EA);

  @override
  Future<void> onLoad() async {
    final center = grid.toScreen(grid.columns / 2, grid.rows / 2);
    camera.viewfinder
      ..anchor = Anchor.center
      ..position = Vector2(center.dx, center.dy - 20);
    _fitCamera(size);

    await world.add(RoomComponent(grid));
    for (final desk in _deskCells) {
      await world.add(DeskComponent(grid: grid, col: desk.x, row: desk.y));
    }

    // Une planche par palette, partagée entre les agents de même palette.
    final sheets = <int, ui.Image>{};
    for (var i = 0; i < agentCount; i++) {
      final key = i % 35;
      final sheet = sheets[key] ??= await buildAgentSheet(paletteFor(key));
      await world.add(
        AgentComponent(
          grid: grid,
          random: Random(_random.nextInt(1 << 30)),
          sheet: sheet,
          start: grid.randomPoint(_random),
        ),
      );
    }

    _hud = TextComponent(
      text: '',
      position: Vector2(16, 12),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF2A2233),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    await camera.viewport.add(_hud);

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static const List<Point<int>> _deskCells = <Point<int>>[
    Point<int>(3, 3),
    Point<int>(3, 6),
    Point<int>(6, 3),
    Point<int>(6, 6),
    Point<int>(12, 3),
    Point<int>(12, 6),
    Point<int>(15, 3),
    Point<int>(3, 12),
    Point<int>(6, 12),
    Point<int>(6, 15),
    Point<int>(12, 12),
    Point<int>(15, 12),
    Point<int>(12, 15),
  ];

  void _onTimings(List<ui.FrameTiming> timings) {
    if (!_warm || _reported) {
      return;
    }
    timings.forEach(stats.add);
  }

  void _fitCamera(Vector2 canvasSize) {
    if (canvasSize.x <= 0 || canvasSize.y <= 0) {
      return;
    }
    camera.viewfinder.zoom = min(canvasSize.x / 1300, canvasSize.y / 760);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitCamera(size);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _hudTimer += dt;
    _hudFrames++;

    if (!_warm && _elapsed >= warmupSeconds) {
      _warm = true;
      stats.clear();
    }

    if (_hudTimer >= 0.5) {
      final fps = _hudFrames / _hudTimer;
      _hud.text = '$agentCount agents · ${fps.toStringAsFixed(0)} images/s';
      _hudTimer = 0;
      _hudFrames = 0;
    }

    if (benchSeconds > 0 &&
        !_reported &&
        _elapsed >= warmupSeconds + benchSeconds) {
      _reported = true;
      _writeReport();
    }
  }

  void _writeReport() {
    final report = <String, Object>{
      'prototype': 'iso_room',
      'agents': agentCount,
      'components': world.children.length,
      'window': <String, double>{'width': size.x, 'height': size.y},
      ...stats.summary(elapsedSeconds: _elapsed - warmupSeconds),
    };
    File(benchOut)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    unawaited(_finish());
  }

  Future<void> _finish() async {
    await onBeforeExit?.call();
    exit(0);
  }
}

/// Décor fixe : dalle, sol en damier pastel par zone, murs du fond.
/// Dessiné une fois dans une [ui.Picture], rejoué à chaque image.
class RoomComponent extends Component {
  RoomComponent(this.grid) : super(priority: -100000);

  final IsoGrid grid;
  late final ui.Picture _picture;

  static const List<Color> _zoneLight = <Color>[
    Color(0xFFBFE8E0),
    Color(0xFFFAD4C0),
    Color(0xFFC9D8FB),
    Color(0xFFF8C8DA),
  ];
  static const List<Color> _zoneDark = <Color>[
    Color(0xFFAEDDD4),
    Color(0xFFF5C4AC),
    Color(0xFFB8CAF6),
    Color(0xFFF2B6CC),
  ];

  @override
  Future<void> onLoad() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;

    final top = grid.toScreen(0, 0);
    final right = grid.toScreen(grid.columns.toDouble(), 0);
    final bottom = grid.toScreen(grid.columns.toDouble(), grid.rows.toDouble());
    final left = grid.toScreen(0, grid.rows.toDouble());

    void quad(Offset a, Offset b, Offset c, Offset d, Color color) {
      paint.color = color;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
        paint,
      );
    }

    // Épaisseur de l'île : herbe puis terre.
    const grass = Offset(0, 12);
    const earth = Offset(0, 52);
    quad(left, bottom, bottom + earth, left + earth, const Color(0xFF8A5A3C));
    quad(bottom, right, right + earth, bottom + earth, const Color(0xFF74492F));
    quad(left, bottom, bottom + grass, left + grass, const Color(0xFF7CC66A));
    quad(bottom, right, right + grass, bottom + grass, const Color(0xFF63AE55));

    // Sol : une couleur par quart de salle, en damier.
    for (var col = 0; col < grid.columns; col++) {
      for (var row = 0; row < grid.rows; row++) {
        final zone =
            (col < grid.columns / 2 ? 0 : 1) + (row < grid.rows / 2 ? 0 : 2);
        final corridor =
            col == grid.columns ~/ 2 - 1 ||
            col == grid.columns ~/ 2 ||
            row == grid.rows ~/ 2 - 1 ||
            row == grid.rows ~/ 2;
        final even = (col + row).isEven;
        final Color color;
        if (corridor) {
          color = even ? const Color(0xFFF3E7D3) : const Color(0xFFEBDDC6);
        } else {
          color = even ? _zoneLight[zone] : _zoneDark[zone];
        }
        final c = col.toDouble();
        final r = row.toDouble();
        quad(
          grid.toScreen(c, r),
          grid.toScreen(c + 1, r),
          grid.toScreen(c + 1, r + 1),
          grid.toScreen(c, r + 1),
          color,
        );
      }
    }

    // Murs du fond et fenêtres.
    const wall = Offset(0, -64);
    quad(top, right, right + wall, top + wall, const Color(0xFFF6EBD8));
    quad(top, left, left + wall, top + wall, const Color(0xFFE9DCC6));
    for (var i = 1; i < grid.columns; i += 3) {
      final a = grid.toScreen(i.toDouble(), 0) + const Offset(0, -48);
      final b = grid.toScreen(i + 1.4, 0) + const Offset(0, -48);
      quad(
        a,
        b,
        b + const Offset(0, 26),
        a + const Offset(0, 26),
        const Color(0xFFBFE3F7),
      );
      final c = grid.toScreen(0, i.toDouble()) + const Offset(0, -48);
      final d = grid.toScreen(0, i + 1.4) + const Offset(0, -48);
      quad(
        c,
        d,
        d + const Offset(0, 26),
        c + const Offset(0, 26),
        const Color(0xFFA9D3EC),
      );
    }

    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(_picture);
  }
}

/// Bureau avec écran, occupant une case. Trié en profondeur avec les agents.
class DeskComponent extends PositionComponent {
  DeskComponent({required IsoGrid grid, required int col, required int row})
    : _grid = grid,
      super(priority: grid.depthOf(col + 0.5, row + 0.5)) {
    final origin = grid.toScreen(col.toDouble(), row.toDouble());
    position = Vector2(origin.dx, origin.dy);
  }

  final IsoGrid _grid;
  final Paint _paint = Paint()..isAntiAlias = false;

  @override
  void render(Canvas canvas) {
    const height = 16.0;
    const a = Offset.zero;
    final b = _grid.toScreen(1, 0);
    final c = _grid.toScreen(1, 1);
    final d = _grid.toScreen(0, 1);
    const up = Offset(0, -height);

    void quad(Offset p, Offset q, Offset r, Offset s, Color color) {
      _paint.color = color;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy)
          ..lineTo(q.dx, q.dy)
          ..lineTo(r.dx, r.dy)
          ..lineTo(s.dx, s.dy)
          ..close(),
        _paint,
      );
    }

    quad(d, c, c + up, d + up, const Color(0xFFD8D3E3));
    quad(c, b, b + up, c + up, const Color(0xFFC4BED3));
    quad(a + up, b + up, c + up, d + up, const Color(0xFFFFFFFF));

    // Écran.
    _paint.color = const Color(0xFF2F3A56);
    canvas.drawRect(const Rect.fromLTWH(-9, -4 - height, 18, 12), _paint);
    _paint.color = const Color(0xFF8FE3C8);
    canvas.drawRect(const Rect.fromLTWH(-7, -2 - height, 14, 8), _paint);
  }
}

/// Agent qui flâne : il choisit un point, s'y rend, patiente, recommence.
class AgentComponent extends SpriteAnimationComponent {
  AgentComponent({
    required this.grid,
    required this.random,
    required ui.Image sheet,
    required Point<double> start,
  }) : _cell = start,
       super(
         size: Vector2(agentFrameWidth * 2, agentFrameHeight * 2),
         anchor: Anchor.bottomCenter,
       ) {
    final frames = <Sprite>[
      for (var i = 0; i < agentFrameCount; i++)
        Sprite(
          sheet,
          srcPosition: Vector2((i * agentFrameWidth).toDouble(), 0),
          srcSize: Vector2(
            agentFrameWidth.toDouble(),
            agentFrameHeight.toDouble(),
          ),
        ),
    ];
    _idle = SpriteAnimation.spriteList(<Sprite>[frames[0]], stepTime: 1);
    _walk = SpriteAnimation.spriteList(frames.sublist(1), stepTime: 0.12);
    animation = _idle;
    paint = Paint()..filterQuality = FilterQuality.none;
    _pause = random.nextDouble() * 2;
    _sync();
  }

  /// Vitesse de marche, en cases par seconde.
  static const double speed = 1.6;

  final IsoGrid grid;
  final Random random;
  late final SpriteAnimation _idle;
  late final SpriteAnimation _walk;
  final Paint _shadow = Paint()..color = const Color(0x33000000);

  Point<double> _cell;
  Point<double>? _target;
  double _pause = 0;
  bool _facingLeft = false;

  void _sync() {
    final screen = grid.toScreen(_cell.x, _cell.y);
    position.setValues(screen.dx, screen.dy);
    final depth = grid.depthOf(_cell.x, _cell.y);
    if (depth != priority) {
      priority = depth;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = _target;
    if (target == null) {
      _pause -= dt;
      if (_pause <= 0) {
        _target = grid.randomPoint(random);
        animation = _walk;
      }
      return;
    }

    final next = stepTowards(_cell, target, speed * dt);
    final screenDx = (next.x - _cell.x) - (next.y - _cell.y);
    final facingLeft = screenDx < 0;
    if (screenDx != 0 && facingLeft != _facingLeft) {
      _facingLeft = facingLeft;
      flipHorizontallyAroundCenter();
    }
    _cell = next;
    if (next == target) {
      _target = null;
      _pause = 1 + random.nextDouble() * 3;
      animation = _idle;
    }
    _sync();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 1),
        width: 20,
        height: 7,
      ),
      _shadow,
    );
    super.render(canvas);
  }
}
