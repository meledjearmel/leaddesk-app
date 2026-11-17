import 'dart:ui';

/// Largeur et hauteur de la scène, en pixels d'art (1 pixel d'art = 1 unité).
const double sceneWidth = 512;
const double sceneHeight = 384;

/// Empreinte stable d'un texte (FNV-1a, 32 bits) : la même d'un lancement,
/// d'une plateforme et d'une version de Dart à l'autre, contrairement à
/// `String.hashCode`. Elle sème les tirages du décor : la même organisation
/// donne toujours le même bureau.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Assombrit (`factor` < 1) ou éclaircit (`factor` > 1) une couleur opaque.
Color shade(Color color, double factor) {
  int channel(double value) => (value * 255 * factor).round().clamp(0, 255);
  return Color.fromARGB(
    255,
    channel(color.r),
    channel(color.g),
    channel(color.b),
  );
}

/// Projection isométrique 2:1 et primitives de dessin sans lissage.
///
/// Repère de la grille : `x` descend vers la droite de l'écran, `y` descend
/// vers la gauche, `z` monte (en pixels d'art). Les faces visibles d'un volume
/// sont donc celle de `y` maximal (à gauche) et celle de `x` maximal (à
/// droite).
class Iso {
  Iso(this.canvas);

  static const double originX = 150;
  static const double originY = 30;
  static const double halfTileWidth = 16;
  static const double halfTileHeight = 8;

  final Canvas canvas;
  final Paint _paint = Paint()..isAntiAlias = false;

  /// Position à l'écran d'un point de la grille.
  static Offset pt(double x, double y, [double z = 0]) {
    return Offset(
      originX + (x - y) * halfTileWidth,
      originY + (x + y) * halfTileHeight - z,
    );
  }

  /// Rang de profondeur d'un point posé au sol : plus il est grand, plus le
  /// point est proche de la caméra.
  static double depth(double x, double y) => x + y;

  void quad(Offset a, Offset b, Offset c, Offset d, Color color) {
    _paint.color = color;
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close(),
      _paint,
    );
  }

  /// Rectangle droit, en coordonnées d'écran.
  void rect(double left, double top, double width, double height, Color color) {
    _paint.color = color;
    canvas.drawRect(Rect.fromLTWH(left, top, width, height), _paint);
  }

  /// Ellipse droite, en coordonnées d'écran.
  void oval(Offset center, double radiusX, double radiusY, Color color) {
    _paint.color = color;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      _paint,
    );
  }

  /// Surface horizontale à la hauteur [z].
  void floor(
    double x0,
    double y0,
    double x1,
    double y1,
    Color color, [
    double z = 0,
  ]) {
    quad(pt(x0, y0, z), pt(x1, y0, z), pt(x1, y1, z), pt(x0, y1, z), color);
  }

  /// Paroi verticale le long de l'axe x (tournée vers la gauche de l'écran).
  void wallX(
    double x0,
    double x1,
    double y,
    double z0,
    double z1,
    Color color,
  ) {
    quad(pt(x0, y, z1), pt(x1, y, z1), pt(x1, y, z0), pt(x0, y, z0), color);
  }

  /// Paroi verticale le long de l'axe y (tournée vers la droite de l'écran).
  void wallY(
    double y0,
    double y1,
    double x,
    double z0,
    double z1,
    Color color,
  ) {
    quad(pt(x, y0, z1), pt(x, y1, z1), pt(x, y1, z0), pt(x, y0, z0), color);
  }

  /// Volume droit : dessus, face gauche (y maximal), face droite (x maximal).
  void box(
    double x0,
    double y0,
    double x1,
    double y1,
    double z0,
    double z1, {
    required Color top,
    required Color left,
    required Color right,
  }) {
    wallX(x0, x1, y1, z0, z1, left);
    wallY(y0, y1, x1, z0, z1, right);
    floor(x0, y0, x1, y1, top, z1);
  }

  /// Volume droit ombré à partir d'une seule couleur.
  void solid(
    double x0,
    double y0,
    double x1,
    double y1,
    double z0,
    double z1,
    Color color,
  ) {
    box(
      x0,
      y0,
      x1,
      y1,
      z0,
      z1,
      top: color,
      left: shade(color, 0.76),
      right: shade(color, 0.58),
    );
  }
}
