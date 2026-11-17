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

  /// Agrandissement maximal : un pixel d'art couvre au plus 3 points.
  static const double maxScale = 3;

  /// Agrandissement d'un bureau visité : assez pour reconnaître les
  /// agents, assez peu pour voir toutes ses salles (D-032).
  static const double focusScale = 2;

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

  /// Pixels physiques par pixel logique (échelle de Windows : 1, 1,25,
  /// 1,5…).
  double pixelRatio = 1;

  /// Pixels d'écran (logiques) par pixel d'art.
  ///
  /// Arrondi pour qu'un pixel d'art couvre un nombre entier de pixels
  /// physiques : sans cela, certains pixels font 2 points et d'autres 3, et
  /// le pixel art paraît flou (D-031). En dessous d'un pixel physique,
  /// l'image est réduite avec lissage et l'échelle reste libre.
  double get scale {
    if (_viewport.isEmpty) {
      return 1;
    }
    final sx = _viewport.width / _scene.width;
    final sy = _viewport.height / _scene.height;
    // Au-delà, le pixel art devient trop gros pour qu'on voie la pièce.
    final raw = min((_contain ? min(sx, sy) : max(sx, sy)) * _zoom, _maxScale);
    if (_levels > 1) {
      return snapLevelScale(raw, pixelRatio, _levels, up: !_contain);
    }
    // « Couvrir » arrondit vers le haut : pas de vide sur les bords.
    return snapScale(raw, pixelRatio, up: !_contain);
  }

  int _levels = 1;

  /// Niveaux de détail de la scène : 1 (plateau) ou 3 (bureau d'un
  /// département, rendu ×1, ×2 ou ×3).
  int get levels => _levels;

  /// Agrandissement maximal : 3 points par pixel d'art sur le plateau
  /// (D-032) ; avec des niveaux de détail, 2 pixels physiques par pixel du
  /// dessin au niveau le plus fin.
  double get _maxScale =>
      _levels > 1 ? maxPixelsPerArt(_levels) / pixelRatio : maxScale;

  /// Pixels physiques par pixel d'art au plus, avec [levels] niveaux.
  static int maxPixelsPerArt(int levels) => 2 * levels;

  /// Niveau de détail à afficher : le plus fin dont chaque pixel du dessin
  /// couvre un nombre entier de pixels physiques, au plus 2 (×1 en vue
  /// d'ensemble, ×2 et ×3 de près).
  int get level => levelFor(scale * pixelRatio, _levels);

  /// Niveau pour [physical] pixels physiques par pixel d'art.
  static int levelFor(double physical, int levels) {
    final p = physical.round();
    for (var l = levels; l > 1; l--) {
      if (p % l == 0 && p ~/ l <= 2) {
        return l;
      }
    }
    return 1;
  }

  /// Agrandissements permis avec [levels] niveaux, en pixels physiques par
  /// pixel d'art : ceux qui tombent juste sur un niveau, sans dépasser
  /// 2 pixels physiques par pixel du dessin (1, 2, 3, 4, 6 avec trois
  /// niveaux).
  static List<int> allowedPixels(int levels) => <int>[
    for (var p = 1; p <= maxPixelsPerArt(levels); p++)
      if (p <= 2 || levelFor(p.toDouble(), levels) > 1) p,
  ];

  /// Échelle permise la plus proche, avec niveaux de détail ; en dessous
  /// d'un pixel physique, l'image est réduite avec lissage.
  static double snapLevelScale(
    double raw,
    double pixelRatio,
    int levels, {
    bool up = false,
  }) {
    final physical = raw * pixelRatio;
    if (physical < 1) {
      return raw;
    }
    final allowed = allowedPixels(levels);
    var best = allowed.first;
    for (final p in allowed) {
      final better = up
          ? (p >= physical - 1e-9 && (best < physical - 1e-9 || p < best))
          : (physical - p).abs() < (physical - best).abs() - 1e-9;
      if (better) {
        best = p;
      }
    }
    if (up && best < physical - 1e-9) {
      best = allowed.last;
    }
    return best / pixelRatio;
  }

  /// Échelle du cadrage de départ, sans zoom ni arrondi.
  double get _baseScale {
    final sx = _viewport.width / _scene.width;
    final sy = _viewport.height / _scene.height;
    return _contain ? min(sx, sy) : max(sx, sy);
  }

  /// Zoom au-delà duquel l'agrandissement plafonne.
  double get _zoomCap {
    if (_viewport.isEmpty) {
      return maxZoom;
    }
    final cap = max(minZoom, _maxScale / _baseScale);
    // Avec niveaux de détail, le zoom va jusqu'au niveau le plus fin.
    return _levels > 1 ? cap : min(maxZoom, cap);
  }

  /// Échelle la plus proche qui tombe juste sur la grille des pixels
  /// physiques.
  static double snapScale(double raw, double pixelRatio, {bool up = false}) {
    final physical = raw * pixelRatio;
    if (physical >= 1) {
      return (up ? physical.ceil() : physical.round()) / pixelRatio;
    }
    // Réduction : l'image est lissée, inutile d'arrondir.
    return raw;
  }

  /// Vrai si l'image est agrandie d'un nombre entier de pixels physiques :
  /// elle se dessine alors sans lissage.
  bool get crisp => scale * pixelRatio >= 1;

  /// Arrondit un point à l'écran sur la grille des pixels physiques.
  Offset snap(Offset screenPoint) => Offset(
    (screenPoint.dx * pixelRatio).roundToDouble() / pixelRatio,
    (screenPoint.dy * pixelRatio).roundToDouble() / pixelRatio,
  );

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
    int levels = 1,
  }) {
    _levels = levels.clamp(1, 3);
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
    final before = scale;
    _zoom = (_zoom * factor).clamp(minZoom, _zoomCap);
    // L'échelle avance par crans entiers : on force au moins un cran pour
    // que chaque clic de zoom ait un effet.
    for (
      var i = 0;
      i < 40 && scale == before && _zoom > minZoom && _zoom < _zoomCap;
      i++
    ) {
      _zoom = (_zoom * factor).clamp(minZoom, _zoomCap);
    }
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

  /// Cadre une zone de la scène (un département) : elle remplit la vue,
  /// avec une marge, dans les limites du zoom.
  void frame(Rect sceneRect, {double margin = 0.18}) {
    if (_viewport.isEmpty || sceneRect.isEmpty) {
      centerOn(sceneRect.center);
      return;
    }
    final base = _baseScale;
    final fit = min(
      _viewport.width / sceneRect.width,
      _viewport.height / sceneRect.height,
    );
    _zoom = (min(fit * (1 - margin), focusScale) / base).clamp(
      minZoom,
      maxZoom,
    );
    _center = sceneRect.center;
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
