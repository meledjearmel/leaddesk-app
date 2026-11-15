// Prototype 2 (phase 0) : personnage composé de calques superposés, avec
// changement d'un calque à la volée.
//
// Lancement :
//   flutter run -d windows -t prototypes/layered_character/main.dart
// Mesure (écrit un fichier JSON puis quitte) :
//   variable d'environnement BENCH_SWAPS=200, puis
//   flutter run -d windows --profile -t prototypes/layered_character/main.dart
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

import '../bench_support.dart';
import 'layers.dart';
import 'prototype_layers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LayeredCharacterApp());
}

class LayeredCharacterApp extends StatefulWidget {
  const LayeredCharacterApp({super.key});

  @override
  State<LayeredCharacterApp> createState() => _LayeredCharacterAppState();
}

class _LayeredCharacterAppState extends State<LayeredCharacterApp> {
  final LayerLibrary _library = buildPrototypeLibrary();
  final GlobalKey _screenKey = GlobalKey();
  final String _benchOut = envString(
    'BENCH_OUT',
    'bench_layered_character.json',
  );
  late final LayeredCharacterGame _game = LayeredCharacterGame(
    library: _library,
    benchSwaps: envInt('BENCH_SWAPS', 0),
    benchOut: _benchOut,
    onBeforeExit: () async {
      // Laisse l'interface afficher la dernière apparence avant la capture.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await saveScreenshot(
        _screenKey,
        _benchOut.replaceAll(RegExp(r'\.json$'), '.png'),
      );
    },
    onChanged: () => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final appearance = _game.appearance;
    return RepaintBoundary(
      key: _screenKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFBBA8EA),
          body: Row(
            children: <Widget>[
              Expanded(child: GameWidget<LayeredCharacterGame>(game: _game)),
              Container(
                width: 300,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Calques du personnage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final kind in LayerKind.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: () => _game.cycle(kind),
                          child: Text(
                            '${kind.label} : '
                            '${_library.find(kind, appearance.optionId(kind))?.label ?? '—'}',
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'Dernière composition : '
                      '${_game.lastComposeMs.toStringAsFixed(2)} ms',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LayeredCharacterGame extends FlameGame {
  LayeredCharacterGame({
    required this.library,
    required this.onChanged,
    this.benchSwaps = 0,
    this.benchOut = 'bench_layered_character.json',
    this.onBeforeExit,
  }) : composer = CharacterComposer(library),
       appearance = library.defaultAppearance();

  final LayerLibrary library;
  final CharacterComposer composer;
  final VoidCallback onChanged;
  final int benchSwaps;
  final String benchOut;
  final Future<void> Function()? onBeforeExit;

  CharacterAppearance appearance;
  double lastComposeMs = 0;
  late final CharacterComponent _character;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _character = CharacterComponent()..position = size / 2;
    await add(_character);
    await _apply(appearance);
  }

  bool _benchStarted = false;

  @override
  void update(double dt) {
    super.update(dt);
    // La mesure démarre après le chargement : le personnage est alors affiché
    // et chaque changement de calque se voit à l'écran.
    if (benchSwaps > 0 && !_benchStarted) {
      _benchStarted = true;
      unawaited(_runBench());
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _character.position = size / 2;
    }
  }

  /// Passe à la variante suivante du calque [kind].
  Future<void> cycle(LayerKind kind) {
    final next = library.next(kind, appearance.optionId(kind));
    return _apply(appearance.withLayer(kind, next.id));
  }

  Future<double> _apply(CharacterAppearance next) async {
    final watch = Stopwatch()..start();
    final sheet = await composer.compose(next);
    watch.stop();
    appearance = next;
    lastComposeMs = watch.elapsedMicroseconds / 1000;
    _character.useSheet(sheet);
    onChanged();
    return lastComposeMs;
  }

  Future<void> _runBench() async {
    final random = Random(11);
    final cold = <double>[];
    final warm = <double>[];
    for (var i = 0; i < benchSwaps; i++) {
      final kind = LayerKind.values[random.nextInt(LayerKind.values.length)];
      final options = library.optionsFor(kind);
      final option = options[random.nextInt(options.length)];
      final cachedBefore = composer.cachedLayerCount;
      final ms = await _apply(appearance.withLayer(kind, option.id));
      (composer.cachedLayerCount > cachedBefore ? cold : warm).add(ms);
    }
    double average(List<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
    double worst(List<double> values) =>
        values.isEmpty ? 0 : values.reduce(max);
    double round(double value) => (value * 1000).roundToDouble() / 1000;

    final report = <String, Object>{
      'prototype': 'layered_character',
      'swaps': benchSwaps,
      'layer_kinds': LayerKind.values.length,
      'cached_layer_sheets': composer.cachedLayerCount,
      'compose_ms_average_cache_warm': round(average(warm)),
      'compose_ms_worst_cache_warm': round(worst(warm)),
      'compose_ms_average_cache_cold': round(average(cold)),
      'compose_ms_worst_cache_cold': round(worst(cold)),
    };
    File(benchOut)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    await onBeforeExit?.call();
    exit(0);
  }
}

/// Personnage affiché en grand, qui marche sur place.
class CharacterComponent extends SpriteAnimationComponent {
  CharacterComponent()
    : super(
        size: Vector2(layerFrameWidth * 14, layerFrameHeight * 14),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none,
      );

  /// Remplace la planche sans interrompre le cycle de marche en cours.
  void useSheet(ui.Image sheet) {
    final index = animationTicker?.currentIndex ?? 0;
    final clock = animationTicker?.clock ?? 0;
    animation = SpriteAnimation.spriteList(<Sprite>[
      for (var i = 1; i < layerFrameCount; i++)
        Sprite(
          sheet,
          srcPosition: Vector2((i * layerFrameWidth).toDouble(), 0),
          srcSize: Vector2(
            layerFrameWidth.toDouble(),
            layerFrameHeight.toDouble(),
          ),
        ),
    ], stepTime: 0.14);
    animationTicker
      ?..currentIndex = index
      ..clock = clock;
  }
}
