import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'scene/iso.dart';
import 'scene/office_scene.dart';

/// Cadrage de la scène : déplacement et zoom, toujours bornés pour que la
/// scène remplisse la vue (aucun vide sur les bords).
class OfficeCamera extends ChangeNotifier {
  static const double minZoom = 1;
  static const double maxZoom = 4;
  static const double zoomStep = 1.25;

  Size _viewport = Size.zero;
  double _zoom = 1;
  Offset _center = OfficeLayout.focus;

  Size get viewport => _viewport;

  /// Zoom relatif au cadrage minimal (1 = la scène couvre juste la vue).
  double get zoom => _zoom;

  /// Point de la scène placé au centre de la vue, en pixels d'art.
  Offset get center => _center;

  /// Pixels d'écran par pixel d'art.
  double get scale {
    if (_viewport.isEmpty) {
      return 1;
    }
    final cover = max(
      _viewport.width / sceneWidth,
      _viewport.height / sceneHeight,
    );
    return cover * _zoom;
  }

  /// Partie de la scène visible, en pixels d'art.
  Rect get visibleRect => Rect.fromCenter(
    center: _center,
    width: _viewport.width / scale,
    height: _viewport.height / scale,
  );

  /// Met à jour la taille de la vue. Appelé pendant la mise en page : ne
  /// prévient pas les écouteurs.
  void setViewport(Size size) {
    if (size == _viewport) {
      return;
    }
    _viewport = size;
    _clamp();
  }

  Offset toScreen(Offset scenePoint) {
    return (scenePoint - _center) * scale + _viewport.center(Offset.zero);
  }

  Offset toScene(Offset screenPoint) {
    return (screenPoint - _viewport.center(Offset.zero)) / scale + _center;
  }

  void panBy(Offset screenDelta) {
    _center -= screenDelta / scale;
    _clamp();
    notifyListeners();
  }

  /// Zoome en gardant sous le curseur le point de la scène visé.
  void zoomAt(Offset screenFocal, double factor) {
    final anchor = toScene(screenFocal);
    _zoom = (_zoom * factor).clamp(minZoom, maxZoom);
    _center = anchor - (screenFocal - _viewport.center(Offset.zero)) / scale;
    _clamp();
    notifyListeners();
  }

  void zoomIn() => zoomAt(_viewport.center(Offset.zero), zoomStep);

  void zoomOut() => zoomAt(_viewport.center(Offset.zero), 1 / zoomStep);

  void centerOn(Offset scenePoint) {
    _center = scenePoint;
    _clamp();
    notifyListeners();
  }

  /// Revient au cadrage d'ouverture.
  void reset() {
    _zoom = 1;
    _center = OfficeLayout.focus;
    _clamp();
    notifyListeners();
  }

  void _clamp() {
    if (_viewport.isEmpty) {
      return;
    }
    final halfW = _viewport.width / scale / 2;
    final halfH = _viewport.height / scale / 2;
    _center = Offset(
      _center.dx.clamp(halfW, max(halfW, sceneWidth - halfW)),
      _center.dy.clamp(halfH, max(halfH, sceneHeight - halfH)),
    );
  }
}
