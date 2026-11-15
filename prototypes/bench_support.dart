import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Réglage entier lu au lancement dans l'environnement, sinon [fallback].
/// Permet de rejouer une mesure avec d'autres valeurs sans recompiler.
int envInt(String name, int fallback) {
  return int.tryParse(Platform.environment[name] ?? '') ?? fallback;
}

/// Réglage texte lu au lancement dans l'environnement, sinon [fallback].
String envString(String name, String fallback) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? fallback : value;
}

/// Enregistre en PNG ce qu'affiche le [RepaintBoundary] portant [key].
///
/// La capture est faite par l'application elle-même : elle fonctionne aussi
/// sur une machine sans écran, comme un runner d'intégration continue.
Future<void> saveScreenshot(GlobalKey key, String path) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    return;
  }
  final image = await boundary.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    return;
  }
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
}
