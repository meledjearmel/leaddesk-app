import 'dart:math';
import 'dart:ui';

/// Grille isométrique en losanges (projection 2:1).
///
/// Les coordonnées de grille sont continues : un agent peut se trouver
/// entre deux cases. L'origine écran (0, 0) est le sommet haut de la case
/// (0, 0).
class IsoGrid {
  const IsoGrid({
    required this.columns,
    required this.rows,
    this.tileWidth = 64,
    this.tileHeight = 32,
  });

  final int columns;
  final int rows;
  final double tileWidth;
  final double tileHeight;

  /// Position écran du centre haut de la case (ou du point) `(col, row)`.
  Offset toScreen(double col, double row) {
    return Offset((col - row) * tileWidth / 2, (col + row) * tileHeight / 2);
  }

  /// Inverse de [toScreen].
  Point<double> toGrid(Offset screen) {
    final a = screen.dx / (tileWidth / 2);
    final b = screen.dy / (tileHeight / 2);
    return Point<double>((a + b) / 2, (b - a) / 2);
  }

  bool contains(double col, double row) {
    return col >= 0 && row >= 0 && col <= columns && row <= rows;
  }

  /// Ordre d'affichage : plus un point est « bas » à l'écran, plus il est
  /// dessiné tard. Dix pas par case suffisent à départager deux agents.
  int depthOf(double col, double row) => ((col + row) * 10).round();

  /// Point aléatoire à l'intérieur de la salle, à distance des murs.
  Point<double> randomPoint(Random random, {double margin = 0.6}) {
    return Point<double>(
      margin + random.nextDouble() * (columns - 2 * margin),
      margin + random.nextDouble() * (rows - 2 * margin),
    );
  }
}

/// Avance de [from] vers [to] d'au plus [maxDistance] (en cases).
///
/// Renvoie le nouveau point ; il vaut [to] quand la cible est atteinte.
Point<double> stepTowards(
  Point<double> from,
  Point<double> to,
  double maxDistance,
) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final distance = sqrt(dx * dx + dy * dy);
  if (distance <= maxDistance || distance == 0) {
    return to;
  }
  final ratio = maxDistance / distance;
  return Point<double>(from.x + dx * ratio, from.y + dy * ratio);
}
