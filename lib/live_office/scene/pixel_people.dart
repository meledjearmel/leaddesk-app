import 'dart:ui';

import 'iso.dart';

/// Apparence d'un personnage en pixel art (création originale, RM-53).
class PersonLook {
  const PersonLook({
    required this.skin,
    required this.hair,
    required this.top,
    this.pants = const Color(0xFF2A3246),
    this.inner,
    this.tie,
    this.glasses = false,
    this.longHair = false,
  });

  final Color skin;
  final Color hair;

  /// Haut : chemise, pull ou veste.
  final Color top;
  final Color pants;

  /// Chemise visible sous une veste ouverte.
  final Color? inner;
  final Color? tie;
  final bool glasses;
  final bool longHair;
}

enum PersonPose { stand, walk, seated }

final Paint _paint = Paint()..isAntiAlias = false;

/// Dessine un personnage, pieds posés en [feet] (coordonnées d'écran).
///
/// Uniquement des rectangles droits : le dessin reste net quelle que soit
/// l'échelle. [step] (0 à 3) anime la marche ; [back] montre le dos ;
/// [raiseArm] lève le bras du côté du regard.
void drawPerson(
  Canvas canvas,
  Offset feet,
  PersonLook look, {
  PersonPose pose = PersonPose.stand,
  bool faceLeft = false,
  bool back = false,
  int step = 0,
  bool raiseArm = false,
  bool paper = false,
  bool mug = false,
  bool shadow = true,
}) {
  final x = feet.dx.roundToDouble();
  final seated = pose == PersonPose.seated;
  final walking = pose == PersonPose.walk;
  final bob = walking && step.isOdd ? -1.0 : 0.0;
  // Assis, le buste descend de deux pixels et les jambes sont cachées.
  final y = feet.dy.roundToDouble() + (seated ? 2 : 0) + bob;
  final dir = faceLeft ? -1.0 : 1.0;

  void r(double dx, double dy, double w, double h, Color color) {
    _paint.color = color;
    canvas.drawRect(Rect.fromLTWH(x + dx, y + dy, w, h), _paint);
  }

  const shoe = Color(0xFF17151A);
  const ink = Color(0xFF2A1D1A);
  final topDark = shade(look.top, 0.78);
  final skinDark = shade(look.skin, 0.82);

  if (shadow && !seated) {
    _paint.color = const Color(0x59000000);
    canvas.drawOval(
      Rect.fromLTWH(x - 9, feet.dy.roundToDouble() - 3, 18, 6),
      _paint,
    );
  }

  if (!seated) {
    final leftUp = walking && step == 1;
    final rightUp = walking && step == 3;
    r(-5, -13, 4, leftUp ? 10 : 12, look.pants);
    r(1, -13, 4, rightUp ? 10 : 12, look.pants);
    r(-5, -13, 10, 3, look.pants);
    r(leftUp ? -6 + dir : -6, leftUp ? -4 : -2, 5, 2, shoe);
    r(rightUp ? 1 + dir : 1, rightUp ? -4 : -2, 5, 2, shoe);
  }

  // Buste.
  r(-6, -27, 12, 15, look.top);
  r(-6, -14, 12, 2, topDark);
  final inner = look.inner;
  if (inner != null && !back) {
    r(-2 + dir, -27, 4, 10, inner);
  }
  final tie = look.tie;
  if (tie != null && !back) {
    r(-1 + dir, -26, 2, 7, tie);
  }

  // Bras : celui du côté opposé au regard reste le long du corps.
  final swing = walking ? (step == 1 ? 1.0 : (step == 3 ? -1.0 : 0.0)) : 0.0;
  final nearSide = faceLeft ? -8.0 : 5.0;
  final farSide = faceLeft ? 5.0 : -8.0;
  r(farSide, -26 - swing, 3, 11, topDark);
  r(farSide, -15 - swing, 3, 2, look.skin);
  if (raiseArm || paper || mug) {
    r(nearSide, -26, 3, 6, topDark);
    r(nearSide + dir * 2, -22, 4, 3, topDark);
    r(nearSide + dir * 5, -22, 2, 3, look.skin);
    if (paper) {
      r(
        nearSide + dir * 5 - (faceLeft ? 4 : 0),
        -27,
        6,
        7,
        const Color(0xFFF2EFE6),
      );
      r(
        nearSide + dir * 5 - (faceLeft ? 3 : -1),
        -25,
        4,
        1,
        const Color(0xFFB9B4A6),
      );
      r(
        nearSide + dir * 5 - (faceLeft ? 3 : -1),
        -23,
        3,
        1,
        const Color(0xFFB9B4A6),
      );
    }
    if (mug) {
      r(
        nearSide + dir * 5 - (faceLeft ? 2 : 0),
        -25,
        4,
        4,
        const Color(0xFFF2EFE6),
      );
    }
  } else {
    r(nearSide, -26 + swing, 3, 11, topDark);
    r(nearSide, -15 + swing, 3, 2, look.skin);
  }

  // Tête.
  r(-1, -29, 3, 2, skinDark);
  r(-6, -42, 12, 14, look.skin);
  r(-7, -40, 14, 10, look.skin);

  // Cheveux.
  if (back) {
    r(-6, -44, 12, 13, look.hair);
    r(-7, -42, 14, 10, look.hair);
  } else {
    r(-6, -44, 12, 4, look.hair);
    r(-7, -42, 14, 4, look.hair);
    r(-7, -38, 2, 4, look.hair);
    r(5, -38, 2, 4, look.hair);
    // Mèche du côté opposé au regard.
    r(faceLeft ? 3 : -6, -40, 4, 2, look.hair);
  }
  if (look.longHair) {
    r(-8, -40, 2, 13, look.hair);
    r(6, -40, 2, 13, look.hair);
    if (back) {
      r(-6, -31, 12, 5, look.hair);
    }
  }

  if (!back) {
    // Visage, décalé d'un pixel vers le regard.
    if (look.glasses) {
      const frame = Color(0xFFE7E3D8);
      r(-5 + dir, -37, 4, 4, frame);
      r(1 + dir, -37, 4, 4, frame);
      r(-1 + dir, -36, 2, 1, frame);
    }
    r(-4 + dir, -36, 2, 2, ink);
    r(2 + dir, -36, 2, 2, ink);
    r(-1 + dir, -32, 3, 1, skinDark);
  }
}
