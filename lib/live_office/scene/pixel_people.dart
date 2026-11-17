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

/// Expression du visage, visible au niveau de détail ×3.
enum PersonMood {
  neutral,

  /// Sourire : pause, café, conversation.
  happy,

  /// Concentré : bouche courte, sourcils froncés.
  focused,

  /// Inquiet : coins de la bouche vers le bas, sourcils relevés.
  worried,
}

final Paint _paint = Paint()..isAntiAlias = false;

/// Dessine un personnage, pieds posés en [feet] (coordonnées d'écran).
///
/// Uniquement des rectangles droits : le dessin reste net quelle que soit
/// l'échelle. [step] (0 à 3) anime la marche ; [back] montre le dos ;
/// [raiseArm] lève le bras du côté du regard.
///
/// [lod] : niveau de détail. Au niveau ×2, les pixels fins (1/[lod] pixel
/// d'art) dessinent yeux, sourcils, mèches et col ; au niveau ×3,
/// l'expression ([mood]), les doigts, les boutons, le reflet des lunettes.
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
  int lod = 1,
  PersonMood mood = PersonMood.neutral,
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

  if (!back && lod >= 2) {
    _fineFace(r, look, dir, lod, mood);
  } else if (!back) {
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
  if (lod >= 2) {
    _fineBody(
      r,
      look,
      dir: dir,
      lod: lod,
      back: back,
      seated: seated,
      raised: raiseArm || paper || mug,
      nearSide: nearSide,
    );
  }
}

typedef _Rect = void Function(
  double dx,
  double dy,
  double w,
  double h,
  Color c,
);

/// Visage aux niveaux fins : yeux (blanc et pupille tournée vers le
/// regard), sourcils, nez, bouche ; au niveau ×3, expression, joues,
/// reflet des lunettes.
void _fineFace(_Rect r, PersonLook look, double dir, int lod, PersonMood mood) {
  final f = 1 / lod;
  const ink = Color(0xFF2A1D1A);
  const white = Color(0xFFF5F1E8);
  final skinDark = shade(look.skin, 0.82);
  final brow = shade(look.hair, 0.8);
  final look1 = dir > 0 ? 1 - f : 0.0;
  for (final ex in <double>[-4 + dir, 2 + dir]) {
    r(ex, -36, 2, 2, white);
    r(ex + look1, -36 + f, 1 + f, 2 - f, ink);
    // Sourcils : froncés quand on se concentre, levés quand on s'inquiète.
    final lift = switch (mood) {
      PersonMood.worried when lod >= 3 => -f,
      PersonMood.focused when lod >= 3 => f,
      _ => 0.0,
    };
    r(ex, -37.5 + lift, 2, f, brow);
  }
  // Nez : une ombre du côté opposé à la lumière.
  r(dir > 0 ? 1 : -1, -34, f, 1, skinDark);
  // Bouche.
  const mouth = Color(0xFF8A4A3A);
  final mx = -1 + dir;
  if (lod >= 3) {
    switch (mood) {
      case PersonMood.happy:
        r(mx, -32 + f, 3, f, mouth);
        r(mx - f, -32, f, f, mouth);
        r(mx + 3, -32, f, f, mouth);
      case PersonMood.worried:
        r(mx, -32, 3, f, mouth);
        r(mx - f, -32 + f, f, f, mouth);
        r(mx + 3, -32 + f, f, f, mouth);
      case PersonMood.focused:
        r(mx + f, -32, 2, f, mouth);
      case PersonMood.neutral:
        r(mx, -32, 3, f, mouth);
    }
    // Joues.
    final blush = Color.lerp(look.skin, const Color(0xFFE2574A), 0.25)!;
    r(-5 + dir, -33 - f, 1, f, blush);
    r(4 + dir, -33 - f, 1, f, blush);
  } else {
    r(mx, -32, 3, f, mouth);
  }
  if (look.glasses) {
    const frame = Color(0xFFE7E3D8);
    for (final gx in <double>[-5 + dir, 1 + dir]) {
      r(gx, -37, 4, f, frame);
      r(gx, -33 - f, 4, f, frame);
      r(gx, -37, f, 4, frame);
      r(gx + 4 - f, -37, f, 4, frame);
      if (lod >= 3) {
        r(gx + 4 - 3 * f, -37 + 2 * f, f, f, const Color(0xCCFFFFFF));
      }
    }
    r(-1 + dir, -36, 2, f, frame);
  }
}

/// Corps aux niveaux fins : mèches éclairées, col, ourlet, semelles ;
/// au niveau ×3, boutons, doigts et poignets.
void _fineBody(
  _Rect r,
  PersonLook look, {
  required double dir,
  required int lod,
  required bool back,
  required bool seated,
  required bool raised,
  required double nearSide,
}) {
  final f = 1 / lod;
  final light = shade(look.hair, 1.45);
  final dark = shade(look.hair, 0.7);
  // Mèches : reflets sur le dessus, raie du côté du regard.
  r(-4, -43.5, 3, f, light);
  r(1, -43, 2, f, light);
  r(dir > 0 ? -2 : 2, -44, f, 2, dark);
  if (back) {
    // Nuque : quelques mèches de longueurs inégales, col du haut.
    final strand = shade(look.hair, 0.85);
    for (final (x, length) in <(double, double)>[
      (-4, 3),
      (-1.5, 5),
      (2, 2.5),
      (4, 4),
    ]) {
      r(x, -40 + (5 - length), f, length, strand);
    }
    r(-4, -27, 8, 2 * f, shade(look.top, 0.7));
  } else {
    // Col ouvert et ourlet.
    r(-3, -27, 2, 2 * f, shade(look.top, 1.25));
    r(1, -27, 2, 2 * f, shade(look.top, 1.25));
    r(-6, -15 - f, 12, f, shade(look.top, 0.65));
    if (lod >= 3 && look.inner == null) {
      // Boutons de la chemise.
      final b = shade(look.top, 0.6);
      r(-f / 2 + dir * f, -24, f, f, b);
      r(-f / 2 + dir * f, -21, f, f, b);
      r(-f / 2 + dir * f, -18, f, f, b);
    }
  }
  if (!seated) {
    // Semelles et lacets.
    const sole = Color(0xFF3A3640);
    r(-6, -f, 5, f, sole);
    r(1, -f, 5, f, sole);
  }
  if (lod >= 3) {
    // Poignets et doigts.
    final cuff = shade(look.top, 1.2);
    final skin = look.skin;
    if (raised) {
      r(nearSide + dir * 5 - (dir > 0 ? 0 : f), -22 - f, f, f, skin);
      r(nearSide + dir * 5 + (dir > 0 ? 2 - f : -f), -21, f, 2, skin);
      r(nearSide + dir * 2, -22, f, 3, cuff);
    } else {
      r(nearSide, -15 - f, 3, f, cuff);
      r(nearSide + 1, -13, f, f, skin);
    }
  }
}
