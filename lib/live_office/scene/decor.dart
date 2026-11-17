import 'dart:math';

import 'package:flutter/painting.dart';

import 'furniture.dart';
import 'iso.dart';

/// Couleurs du décor ajouté par la vue « Salle ».
abstract final class DecorTone {
  static const Color frame = Color(0xFF2A1D16);
  static const Color paper = Color(0xFFF2EFE6);
  static const Color paperShade = Color(0xFFCFCABD);
  static const Color steel = Color(0xFF6B7178);
  static const Color steelDark = Color(0xFF4A4F57);
  static const Color clay = Color(0xFFB8643C);
  static const Color clayLight = Color(0xFFD07A4C);
  static const Color cardboard = Color(0xFFB88A52);

  static const List<Color> art = <Color>[
    Color(0xFFE2874A),
    Color(0xFF3F8A8C),
    Color(0xFFF4C84A),
    Color(0xFF8A5AA8),
    Color(0xFFB04A3A),
    Color(0xFF3F5F8A),
  ];

  static const List<Color> notes = <Color>[
    Color(0xFFF4C84A),
    Color(0xFFF08A8A),
    Color(0xFF8AC6F0),
    Color(0xFFF2A04A),
    Color(0xFFA6E08A),
  ];

  /// Tapis : fond, bordure, motif.
  static const List<(Color, Color, Color)> rugs = <(Color, Color, Color)>[
    (Color(0xFF6C3428), Color(0xFF4A231C), Color(0xFFC08A3A)),
    (Color(0xFF3A4A5E), Color(0xFF26313F), Color(0xFFB8A27A)),
    (Color(0xFF5A4A3A), Color(0xFF3A2E24), Color(0xFF8A3A32)),
  ];
}

/// Mobilier et objets du bureau détaillé : décor mural, rangements,
/// plantes, tapis, petits objets des bureaux. Mêmes conventions que
/// [FurnitureKit] : coordonnées de la grille, `z` en pixels d'art.
extension DenseDecor on FurnitureKit {
  // ------------------------------------------------------------- murs

  /// Cadre accroché au mur du fond (le long de x), contre y = [y].
  void poster(double x0, double x1, double y, double z0, double z1, int seed) {
    final random = Random(seed);
    const yy = 0.06;
    g
      ..wallX(x0, x1, y + yy, z0, z1, DecorTone.frame)
      ..wallX(x0 + 0.06, x1 - 0.06, y + yy, z0 + 2, z1 - 2, DecorTone.paper);
    final kind = random.nextInt(3);
    final a = DecorTone.art[random.nextInt(DecorTone.art.length)];
    final b = DecorTone.art[random.nextInt(DecorTone.art.length)];
    final w = x1 - x0;
    switch (kind) {
      case 0:
        // Composition abstraite : deux aplats.
        g
          ..wallX(x0 + w * 0.2, x0 + w * 0.6, y + yy, z0 + 5, z1 - 6, a)
          ..wallX(x0 + w * 0.45, x0 + w * 0.8, y + yy, z0 + 4, z0 + 10, b);
      case 1:
        // Courbe de résultats.
        for (var i = 0; i < 5; i++) {
          final h = 3 + ((i * 5 + seed) % 7).toDouble();
          final xs = x0 + w * (0.15 + i * 0.15);
          g.wallX(xs, xs + w * 0.1, y + yy, z0 + 4, z0 + 4 + h, a);
        }
      default:
        // Paysage : ciel, colline, soleil.
        g
          ..wallX(x0 + 0.06, x1 - 0.06, y + yy, z0 + 2, z0 + 8, b)
          ..wallX(x0 + w * 0.25, x0 + w * 0.4, y + yy, z1 - 9, z1 - 5, a);
    }
  }

  /// Cadre accroché au mur de gauche (le long de y), contre x = [x].
  void posterSide(
    double y0,
    double y1,
    double x,
    double z0,
    double z1,
    int seed,
  ) {
    final random = Random(seed);
    final a = DecorTone.art[random.nextInt(DecorTone.art.length)];
    final b = DecorTone.art[random.nextInt(DecorTone.art.length)];
    final w = y1 - y0;
    g
      ..wallY(y0, y1, x + 0.06, z0, z1, DecorTone.frame)
      ..wallY(y0 + 0.06, y1 - 0.06, x + 0.06, z0 + 2, z1 - 2, DecorTone.paper)
      ..wallY(y0 + w * 0.2, y0 + w * 0.65, x + 0.06, z0 + 5, z1 - 5, a)
      ..wallY(y0 + w * 0.5, y0 + w * 0.8, x + 0.06, z0 + 4, z0 + 9, b);
  }

  /// Tableau blanc couvert de notes, au mur de gauche.
  void wallBoardSide(double y0, double y1, double x, int seed) {
    g
      ..wallY(y0, y1, x + 0.05, 22, 50, const Color(0xFFB9BDBF))
      ..wallY(y0 + 0.1, y1 - 0.1, x + 0.05, 24, 48, const Color(0xFFF1F0EA));
    var i = seed;
    for (var y = y0 + 0.25; y < y1 - 0.4; y += 0.42) {
      for (var z = 40.0; z > 27; z -= 7) {
        if ((i * 5 + 3) % 7 < 4) {
          g.wallY(
            y,
            y + 0.28,
            x + 0.05,
            z,
            z + 5,
            DecorTone.notes[i % DecorTone.notes.length],
          );
          noteDetail(y, y + 0.28, x + 0.05, z, z + 5, i, true);
        }
        i++;
      }
    }
    g.wallY(y1 - 0.9, y1 - 0.3, x + 0.05, 30, 31, const Color(0xFF6B7178));
  }

  /// Horloge murale ronde.
  void wallClock(Offset center) {
    g
      ..oval(center, 5, 5, DecorTone.frame)
      ..oval(center, 4, 4, DecorTone.paper)
      ..rect(center.dx, center.dy - 3, 1, 3, DecorTone.frame)
      ..rect(center.dx, center.dy, 2, 1, DecorTone.frame);
  }

  /// Étagère murale avec livres et plante, au mur du fond.
  void wallShelf(double x0, double x1, double y, double z, int seed) {
    final random = Random(seed);
    g.box(
      x0,
      y,
      x1,
      y + 0.35,
      z - 2,
      z,
      top: Tone.shelfTop,
      left: Tone.shelfWood,
      right: Tone.shelfSide,
    );
    var x = x0 + 0.1;
    while (x < x1 - 0.5) {
      final w = 0.1 + random.nextInt(2) * 0.04;
      g.wallX(
        x,
        x + w,
        y + 0.25,
        z,
        z + 6 + random.nextInt(4),
        Tone.books[random.nextInt(Tone.books.length)],
      );
      x += w + 0.02;
    }
    smallPlant(Iso.pt(x1 - 0.25, y + 0.2, z));
  }

  /// Plante suspendue au plafond (cache-pot et feuilles qui retombent).
  void hangingPlant(Offset hook, int seed) {
    final random = Random(seed);
    g
      ..rect(hook.dx, hook.dy, 1, 8, DecorTone.steelDark)
      ..rect(hook.dx - 4, hook.dy + 8, 9, 5, Tone.white)
      ..rect(hook.dx + 2, hook.dy + 8, 3, 5, DecorTone.paperShade);
    for (var i = 0; i < 6; i++) {
      final dx = -5.0 + i * 2;
      final length = 4 + random.nextInt(9);
      for (var t = 0; t < length; t++) {
        g.rect(
          hook.dx + dx + (t.isEven ? 0 : (i.isEven ? -1 : 1)),
          hook.dy + 11 + t,
          2,
          1,
          Tone.greens[(i + t ~/ 3) % Tone.greens.length],
        );
      }
    }
  }

  // ------------------------------------------------------- rangements

  /// Bibliothèque adossée au mur de gauche : les livres regardent vers la
  /// droite de l'écran.
  void bookshelfSide(
    double x0,
    double y0,
    double y1, {
    double depth = 0.85,
    double h = 72,
    int shelves = 4,
    int seed = 1,
  }) {
    final x1 = x0 + depth;
    final random = Random(seed);
    g
      ..floor(x0 + 0.2, y0 + 0.2, x1 + 0.4, y1 + 0.3, const Color(0x66000000))
      ..box(
        x0,
        y0,
        x1,
        y1,
        0,
        h,
        top: Tone.shelfTop,
        left: Tone.shelfSide,
        right: const Color(0xFF22140C),
      );
    final step = (h - 6) / shelves;
    for (var s = 0; s < shelves; s++) {
      final zb = 3 + s * step;
      var y = y0 + 0.15;
      while (y < y1 - 0.3) {
        final kind = random.nextInt(10);
        if (kind == 0) {
          y += 0.3;
        } else if (kind == 1 && y < y1 - 0.9) {
          g.wallY(y, y + 0.55, x1, zb, zb + step * 0.5, DecorTone.cardboard);
          y += 0.62;
        } else {
          final width = 0.11 + random.nextInt(3) * 0.035;
          final top = zb + step * (0.5 + random.nextDouble() * 0.32);
          final color = Tone.books[random.nextInt(Tone.books.length)];
          g.wallY(y, y + width, x1, zb, top, color);
          bookSpine(y, y + width, x1, zb, top, color, side: true);
          y += width + 0.02;
        }
      }
      g.wallY(y0, y1, x1, zb - 3, zb, Tone.shelfWood);
    }
    g
      ..wallY(y0, y0 + 0.1, x1, 0, h, Tone.shelfWood)
      ..wallY(y1 - 0.1, y1, x1, 0, h, Tone.shelfWood)
      ..wallY(y0, y1, x1, h - 3, h, Tone.shelfWood);
  }

  /// Bibliothèque basse sous une fenêtre, au mur du fond.
  void lowShelf(double x0, double y0, double x1, int seed) {
    bookshelf(x0, y0, x1, depth: 0.7, h: 30, shelves: 2, seed: seed);
    smallPlant(Iso.pt(x1 - 0.35, y0 + 0.35, 30));
  }

  /// Caisson métallique à tiroirs.
  void filingCabinet(double x, double y) {
    g
      ..floor(x + 0.1, y + 0.1, x + 0.8, y + 0.8, const Color(0x59000000))
      ..solid(x, y, x + 0.6, y + 0.6, 0, 26, const Color(0xFF5A6068));
    for (var z = 4.0; z < 24; z += 7) {
      g
        ..wallX(x + 0.05, x + 0.55, y + 0.6, z, z + 5, const Color(0xFF6E757E))
        ..wallX(x + 0.22, x + 0.38, y + 0.6, z + 3, z + 4, DecorTone.paper);
    }
  }

  /// Corbeille à papier.
  void trashBin(double x, double y) {
    final p = Iso.pt(x, y);
    g
      ..oval(p + const Offset(1, 1), 4, 2, const Color(0x59000000))
      ..rect(p.dx - 3, p.dy - 8, 6, 8, const Color(0xFF34383F))
      ..rect(p.dx - 3, p.dy - 8, 6, 1, const Color(0xFF4A4F57))
      ..rect(p.dx - 1, p.dy - 9, 3, 2, DecorTone.paper);
  }

  /// Cartons empilés.
  void boxes(double x, double y, int seed) {
    final n = 1 + seed % 3;
    for (var i = 0; i < n; i++) {
      final z = i * 9.0;
      final dx = (i.isOdd ? 0.08 : 0.0);
      g
        ..solid(x + dx, y, x + dx + 0.6, y + 0.5, z, z + 9, DecorTone.cardboard)
        ..floor(
          x + dx + 0.27,
          y,
          x + dx + 0.33,
          y + 0.5,
          const Color(0xFFD9B98A),
          z + 9,
        );
    }
  }

  /// Sac à dos posé au sol.
  void backpack(double x, double y, Color color) {
    final p = Iso.pt(x, y);
    g
      ..oval(p + const Offset(1, 0), 4, 2, const Color(0x59000000))
      ..rect(p.dx - 4, p.dy - 9, 8, 9, color)
      ..rect(p.dx - 3, p.dy - 5, 6, 4, shade(color, 0.8))
      ..rect(p.dx - 2, p.dy - 11, 4, 2, shade(color, 0.7));
  }

  /// Portemanteau et manteau.
  void coatRack(double x, double y, Color coat) {
    final p = Iso.pt(x, y);
    g
      ..oval(p, 5, 2, Tone.metal)
      ..rect(p.dx, p.dy - 40, 1, 40, Tone.woodDark)
      ..rect(p.dx - 3, p.dy - 40, 7, 1, Tone.woodDark)
      ..rect(p.dx - 4, p.dy - 37, 5, 14, coat)
      ..rect(p.dx - 4, p.dy - 37, 5, 2, shade(coat, 0.8));
  }

  // -------------------------------------------------------- plantes, sol

  /// Plante haute aux feuilles dressées (pot en terre).
  void tallPlant(Offset base, int seed) {
    final random = Random(seed);
    g
      ..oval(base + const Offset(1, 1), 6, 3, const Color(0x59000000))
      ..rect(base.dx - 4, base.dy - 8, 8, 8, DecorTone.clay)
      ..rect(base.dx - 5, base.dy - 9, 10, 2, DecorTone.clayLight)
      ..rect(base.dx + 1, base.dy - 7, 3, 7, const Color(0xFF8E4A2C));
    for (var i = 0; i < 7; i++) {
      final dx = -4.0 + i * 1.3;
      final h = 12 + random.nextInt(14);
      final lean = (i - 3) * 0.12;
      for (var t = 0; t < h; t++) {
        g.rect(
          (base.dx + dx + lean * t).roundToDouble(),
          base.dy - 9 - t.toDouble(),
          2,
          1,
          Tone.greens[(i + (t > h * 0.6 ? 2 : 0)) % Tone.greens.length],
        );
      }
    }
  }

  /// Buisson en pot rond.
  void bushPlant(Offset base, int seed) {
    final random = Random(seed);
    g
      ..oval(base + const Offset(1, 1), 7, 3, const Color(0x59000000))
      ..rect(base.dx - 5, base.dy - 9, 10, 9, const Color(0xFF39424E))
      ..rect(base.dx - 6, base.dy - 10, 12, 2, const Color(0xFF4A5560));
    for (var i = 0; i < 26; i++) {
      final a = random.nextDouble() * pi;
      final r = random.nextDouble() * 8;
      g.rect(
        (base.dx + cos(a) * r * (random.nextBool() ? 1 : -1)).roundToDouble(),
        (base.dy - 14 - sin(a) * r * 0.8).roundToDouble(),
        3,
        2,
        Tone.greens[random.nextInt(Tone.greens.length)],
      );
    }
  }

  /// Tapis à motif, posé au sol.
  void rug(double x0, double y0, double x1, double y1, int seed) {
    final (base, border, motif) = DecorTone.rugs[seed % DecorTone.rugs.length];
    g
      ..floor(x0, y0, x1, y1, border, 0.2)
      ..floor(x0 + 0.15, y0 + 0.15, x1 - 0.15, y1 - 0.15, base, 0.3)
      ..floor(x0 + 0.3, y0 + 0.3, x1 - 0.3, y0 + 0.36, motif, 0.4)
      ..floor(x0 + 0.3, y1 - 0.36, x1 - 0.3, y1 - 0.3, motif, 0.4)
      ..floor(x0 + 0.3, y0 + 0.3, x0 + 0.36, y1 - 0.3, motif, 0.4)
      ..floor(x1 - 0.36, y0 + 0.3, x1 - 0.3, y1 - 0.3, motif, 0.4);
    final cx = (x0 + x1) / 2;
    final cy = (y0 + y1) / 2;
    g
      ..floor(cx - 0.35, cy - 0.35, cx + 0.35, cy + 0.35, motif, 0.4)
      ..floor(cx - 0.2, cy - 0.2, cx + 0.2, cy + 0.2, border, 0.5);
  }

  /// Tabouret haut.
  void stool(double x, double y) {
    final p = Iso.pt(x, y);
    g
      ..oval(p + const Offset(1, 1), 4, 2, const Color(0x59000000))
      ..rect(p.dx - 3, p.dy - 12, 1, 12, Tone.woodDark)
      ..rect(p.dx + 2, p.dy - 12, 1, 12, Tone.woodDark)
      ..rect(p.dx - 3, p.dy - 6, 6, 1, Tone.woodDark)
      ..oval(p + const Offset(0, -13), 5, 2.5, Tone.deskEdge)
      ..oval(p + const Offset(0, -14), 5, 2.5, Tone.deskTop);
  }

  /// Distributeur de boissons, vitrine éclairée.
  void vendingMachine(double x, double y) {
    g
      ..floor(x + 0.1, y + 0.1, x + 1.1, y + 1, const Color(0x73000000))
      ..solid(x, y, x + 0.9, y + 0.8, 0, 52, const Color(0xFF2B2E33))
      ..wallX(x + 0.08, x + 0.65, y + 0.8, 14, 48, const Color(0xFF1C3D4A));
    for (var z = 18.0; z < 46; z += 7) {
      for (var i = 0; i < 4; i++) {
        final xs = x + 0.12 + i * 0.13;
        g.wallX(
          xs,
          xs + 0.08,
          y + 0.8,
          z,
          z + 4,
          DecorTone.art[(i + z ~/ 7) % DecorTone.art.length],
        );
      }
    }
    g.wallX(x + 0.7, x + 0.82, y + 0.8, 26, 34, DecorTone.steel);
    glows.add(Glow(Iso.pt(x + 0.4, y + 1.2, 30), 26, const Color(0x2E8AC6F0)));
  }

  /// Réfrigérateur.
  void fridge(double x, double y) {
    g
      ..floor(x + 0.1, y + 0.1, x + 1, y + 0.9, const Color(0x59000000))
      ..solid(x, y, x + 0.8, y + 0.75, 0, 46, const Color(0xFFD5D8D2))
      ..wallX(x, x + 0.8, y + 0.75, 30, 31, const Color(0xFF9EA3A8))
      ..wallX(x + 0.65, x + 0.7, y + 0.75, 34, 42, DecorTone.steel)
      ..wallX(x + 0.65, x + 0.7, y + 0.75, 14, 26, DecorTone.steel);
  }

  /// Four à micro-ondes posé à la hauteur [z].
  void microwave(double x, double y, double z) {
    g
      ..solid(x, y, x + 0.7, y + 0.5, z, z + 8, const Color(0xFFD5D8D2))
      ..wallX(
        x + 0.06,
        x + 0.45,
        y + 0.5,
        z + 1.5,
        z + 6.5,
        const Color(0xFF26292E),
      )
      ..wallX(x + 0.52, x + 0.64, y + 0.5, z + 2, z + 6, DecorTone.steel);
  }

  // ------------------------------------------------ objets des bureaux

  /// Feuilles posées à plat.
  void papers(double x, double y, double z) {
    g
      ..floor(x - 0.22, y - 0.16, x + 0.22, y + 0.16, DecorTone.paperShade, z)
      ..floor(x - 0.18, y - 0.2, x + 0.26, y + 0.12, DecorTone.paper, z + 0.4)
      ..floor(
        x - 0.1,
        y - 0.1,
        x + 0.14,
        y - 0.07,
        const Color(0xFF9EA3A8),
        z + 0.5,
      );
  }

  /// Carnet fermé.
  void notebook(double x, double y, double z, Color cover) {
    g.solid(x - 0.18, y - 0.13, x + 0.18, y + 0.13, z, z + 1.5, cover);
  }

  /// Souris d'ordinateur.
  void mouse(double x, double y, double z) {
    g.floor(x - 0.06, y - 0.09, x + 0.06, y + 0.09, const Color(0xFF2B2D32), z);
  }

  /// Pot à crayons.
  void penCup(double x, double y, double z) {
    final p = Iso.pt(x, y, z);
    g
      ..rect(p.dx - 2, p.dy - 4, 4, 4, const Color(0xFF39424E))
      ..rect(p.dx - 1, p.dy - 7, 1, 3, Tone.amber)
      ..rect(p.dx + 1, p.dy - 6, 1, 2, const Color(0xFFE2574A));
  }
}
