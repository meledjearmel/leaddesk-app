import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'scene/iso.dart';
import 'scene/office_scene.dart';

/// Cadrage de la scène : déplacement et zoom, toujours bornés.
///
/// Deux cadrages de départ : « couvrir » (la scène remplit la vue, sans
/// vide sur les bords : vue détaillée d'une salle) et « contenir » (toute la
/// scène est visible : plateau entier). Dès qu'on zoome, la scène ne laisse
/// plus de vide que dans la direction où elle est plus petite que la vue.
class OfficeCamera extends ChangeNotifier {
  static const double minZoom = 1;
  static const double maxZoom = 4;
  static const double zoomStep = 1.25;

  Size _viewport = Size.zero;
  Size _scene = const Size(sceneWidth, sceneHeight);
  Offset _focus = OfficeLayout.focus;
  bool _contain = false;
  double _zoom = 1;
  Offset _center = OfficeLayout.focus;

  Size get viewport => _viewport;

  /// Taille de la scène, en pixels d'art.
  Size get scene => _scene;

  /// Zoom relatif au cadrage de départ.
  double get zoom => _zoom;

  /// Point de la scène placé au centre de la vue, en pixels d'art.
  Offset get center => _center;

  /// Pixels d'écran par pixel d'art.
  double get scale {
    if (_viewport.isEmpty) {
      return 1;
    }
    final sx = _viewport.width / _scene.width;
    final sy = _viewport.height / _scene.height;
    return (_contain ? min(sx, sy) : max(sx, sy)) * _zoom;
  }

  /// Partie de la scène visible, en pixels d'art.
  Rect get visibleRect => Rect.fromCenter(
    center: _center,
    width: _viewport.width / scale,
    height: _viewport.height / scale,
  );

  /// Change de scène et revient à son cadrage de départ.
  void setScene(
    Size scene, {
    required Offset focus,
    required bool contain,
    double initialZoom = 1,
  }) {
    _scene = scene;
    _focus = focus;
    _contain = contain;
    _initialZoom = initialZoom.clamp(minZoom, maxZoom);
    reset();
  }

  double _initialZoom = 1;

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

  /// Revient au cadrage de départ.
  void reset() {
    _zoom = _initialZoom;
    _center = _focus;
    _clamp();
    notifyListeners();
  }

  void _clamp() {
    if (_viewport.isEmpty) {
      return;
    }
    double axis(double value, double half, double extent) {
      // Scène plus petite que la vue sur cet axe : on la centre.
      if (half * 2 >= extent) {
        return extent / 2;
      }
      return value.clamp(half, extent - half);
    }

    _center = Offset(
      axis(_center.dx, _viewport.width / scale / 2, _scene.width),
      axis(_center.dy, _viewport.height / scale / 2, _scene.height),
    );
  }
}
