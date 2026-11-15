import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'iso.dart';

/// Couleurs du mobilier : bois, métal, tissus, livres, feuillage.
abstract final class Tone {
  static const Color deskTop = Color(0xFFB8824A);
  static const Color deskEdge = Color(0xFF8C5C31);
  static const Color deskEdgeDark = Color(0xFF6C4425);
  static const Color woodDark = Color(0xFF7A4E2B);
  static const Color shelfWood = Color(0xFF7B4D2A);
  static const Color shelfTop = Color(0xFF8E5C33);
  static const Color shelfSide = Color(0xFF4A2C18);
  static const Color metal = Color(0xFF24272C);
  static const Color metalLight = Color(0xFF4A4F57);
  static const Color chairDark = Color(0xFF2A2C33);
  static const Color chairGrey = Color(0xFF5E636B);
  static const Color white = Color(0xFFF1EEE6);
  static const Color screenGreen = Color(0xFF6DF5B0);
  static const Color amber = Color(0xFFF2C14E);
  static const Color lampGlow = Color(0x66FFC46B);

  static const List<Color> books = <Color>[
    Color(0xFF3F5F8A),
    Color(0xFF2E4468),
    Color(0xFF8A3A32),
    Color(0xFFB04A3A),
    Color(0xFF3F6B4A),
    Color(0xFF3A7A78),
    Color(0xFFC08A3A),
    Color(0xFFD8C8A0),
    Color(0xFF5A4470),
    Color(0xFF27313F),
  ];

  static const List<Color> greens = <Color>[
    Color(0xFF2F6B3A),
    Color(0xFF3F8A4A),
    Color(0xFF56A65A),
    Color(0xFF245230),
  ];
}

/// Halo lumineux ajouté par-dessus la scène (lampes, écrans).
class Glow {
  const Glow(this.center, this.radius, this.color);

  final Offset center;
  final double radius;
  final Color color;
}

/// Bibliothèque de meubles en pixel art isométrique.
///
/// Chaque méthode dessine un meuble à sa place dans la grille ;
/// les lampes et les écrans ajoutent un halo dans [glows].
class FurnitureKit {
  FurnitureKit(this.canvas, this.frame) : g = Iso(canvas);

  final ui.Canvas canvas;

  /// Image d'ambiance en cours (écrans, voyants).
  final int frame;
  final Iso g;
  final List<Glow> glows = <Glow>[];

  void desk(double x0, double y0, double x1, double y1) {
    g.floor(x0 + 0.3, y0 + 0.3, x1 + 0.4, y1 + 0.5, const Color(0x66000000));
    const line = Color(0xFF55331B);
    const brass = Color(0xFFD9B36A);
    for (final xs in <double>[x0 + 0.15, x1 - 1.4]) {
      final face = y1 - 0.2;
      g
        ..solid(xs, y0 + 0.2, xs + 1.25, face, 0, 19, Tone.woodDark)
        ..wallX(xs + 0.1, xs + 1.15, face, 6, 7, line)
        ..wallX(xs + 0.1, xs + 1.15, face, 12, 13, line)
        ..wallX(xs + 0.5, xs + 0.75, face, 8.5, 10, brass)
        ..wallX(xs + 0.5, xs + 0.75, face, 14.5, 16, brass);
    }
    g
      ..box(
        x0,
        y0,
        x1,
        y1,
        19,
        22,
        top: Tone.deskTop,
        left: Tone.deskEdge,
        right: Tone.deskEdgeDark,
      )
      ..floor(
        x0 + 0.3,
        y0 + 0.45,
        x1 - 0.4,
        y0 + 0.55,
        const Color(0xFFC8935A),
        22,
      )
      ..floor(
        x0 + 0.6,
        y1 - 0.5,
        x1 - 1.2,
        y1 - 0.42,
        const Color(0xFFA9743F),
        22,
      );
  }

  /// Écran dont la dalle est tournée vers la caméra (côté y croissant).
  void monitor(double x, double y, {double w = 1.6, int seed = 0}) {
    const z = 22.0;
    g
      ..floor(x - 0.35, y - 0.1, x + 0.35, y + 0.3, Tone.metal, z + 0.5)
      ..wallX(x - 0.08, x + 0.08, y, z, z + 6, Tone.metalLight)
      ..box(
        x - w / 2,
        y - 0.15,
        x + w / 2,
        y,
        z + 5,
        z + 26,
        top: const Color(0xFF3A3D42),
        left: const Color(0xFF16181B),
        right: const Color(0xFF0E0F11),
      )
      ..wallX(
        x - w / 2 + 0.08,
        x + w / 2 - 0.08,
        y,
        z + 7,
        z + 24,
        const Color(0xFF0F2B24),
      );
    const lengths = <double>[0.45, 0.8, 0.35, 0.65, 0.5, 0.85];
    const indents = <double>[0, 0.12, 0.12, 0.24, 0.12, 0];
    final usable = w - 0.4;
    for (var i = 0; i < 6; i++) {
      final row = (i + frame + seed) % 6;
      final start = x - w / 2 + 0.18 + indents[row];
      final zz = z + 22.5 - i * 2.6;
      final color = row == 3
          ? Tone.amber
          : (row == 0 ? const Color(0xFFD8F7E8) : Tone.screenGreen);
      g.wallX(start, start + lengths[row] * usable, y, zz - 1.3, zz, color);
    }
    // Curseur clignotant.
    if (frame.isEven) {
      g.wallX(x + w / 2 - 0.4, x + w / 2 - 0.3, y, z + 8, z + 10, Tone.white);
    }
    glows.add(Glow(Iso.pt(x, y + 0.6, z + 14), 26, const Color(0x335CF2A6)));
  }

  /// Écran vu de dos : son utilisateur fait face à la caméra.
  void monitorBack(double x, double y, {double w = 1.6}) {
    const z = 22.0;
    g
      ..floor(x - 0.35, y - 0.1, x + 0.35, y + 0.3, Tone.metal, z + 0.5)
      ..wallX(x - 0.08, x + 0.08, y + 0.15, z, z + 6, Tone.metalLight)
      ..box(
        x - w / 2,
        y,
        x + w / 2,
        y + 0.15,
        z + 5,
        z + 25,
        top: const Color(0xFF3F4349),
        left: const Color(0xFF2B2E33),
        right: const Color(0xFF1B1D20),
      )
      ..wallX(
        x - 0.15,
        x + 0.15,
        y + 0.15,
        z + 14,
        z + 16,
        const Color(0xFF4D5158),
      );
    glows.add(Glow(Iso.pt(x, y - 0.7, z + 16), 18, const Color(0x265CF2A6)));
  }

  void keyboard(double x, double y) {
    g
      ..floor(
        x - 0.6,
        y - 0.18,
        x + 0.6,
        y + 0.18,
        const Color(0xFF2B2D32),
        22.5,
      )
      ..floor(x - 0.5, y - 0.1, x + 0.5, y + 0.1, const Color(0xFF45484F), 22.5)
      ..floor(x + 0.8, y - 0.1, x + 1, y + 0.1, const Color(0xFF2B2D32), 22.5);
  }

  void mug(Offset at) {
    g
      ..rect(at.dx - 2, at.dy - 4, 4, 4, Tone.white)
      ..rect(at.dx - 1, at.dy - 4, 2, 1, const Color(0xFF6B4A32))
      ..rect(at.dx + 2, at.dy - 3, 1, 2, Tone.white);
  }

  void binders(double x, double y) {
    const colors = <Color>[
      Color(0xFF2E4468),
      Color(0xFF34383F),
      Color(0xFF3F5F8A),
      Color(0xFF2B2E33),
    ];
    for (var i = 0; i < colors.length; i++) {
      final xs = x + i * 0.2;
      g
        ..solid(xs, y - 0.3, xs + 0.18, y + 0.3, 22, 35, colors[i])
        ..wallX(xs + 0.04, xs + 0.14, y + 0.3, 28, 32, Tone.white);
    }
  }

  void deskLamp(Offset base) {
    g
      ..rect(base.dx - 2, base.dy - 2, 5, 2, Tone.metal)
      ..rect(base.dx, base.dy - 13, 1, 11, Tone.metalLight)
      ..rect(base.dx, base.dy - 14, 6, 1, Tone.metalLight)
      ..rect(base.dx + 3, base.dy - 14, 7, 4, const Color(0xFFD8A24A))
      ..rect(base.dx + 4, base.dy - 10, 5, 1, const Color(0xFFFFE9A8));
    glows.add(Glow(base + const Offset(6, -7), 34, Tone.lampGlow));
  }

  void fronds(Offset center, int count, double length, Random random) {
    for (var i = 0; i < count; i++) {
      final angle =
          pi + (i + 0.5) / count * pi + (random.nextDouble() - 0.5) * 0.3;
      final reach = length * (0.7 + random.nextDouble() * 0.4);
      for (var t = 0.0; t < reach; t += 1) {
        final px = center.dx + cos(angle) * t;
        final py = center.dy + sin(angle) * t * 0.95 + t * t * 0.035;
        g.rect(
          px.roundToDouble() - 1,
          py.roundToDouble() - 1,
          3,
          2,
          Tone.greens[(i + t ~/ 4) % Tone.greens.length],
        );
      }
    }
  }

  /// Grande plante en pot posée au sol.
  void palm(Offset base, {required int seed, double size = 14}) {
    g
      ..oval(base + const Offset(1, 1), 8, 3.5, const Color(0x59000000))
      ..rect(base.dx - 5, base.dy - 9, 10, 9, const Color(0xFFB8643C))
      ..rect(base.dx - 6, base.dy - 10, 12, 2, const Color(0xFFD07A4C))
      ..rect(base.dx + 2, base.dy - 8, 3, 8, const Color(0xFF8E4A2C))
      ..rect(base.dx - 1, base.dy - 17, 2, 8, Tone.greens[3]);
    fronds(base + const Offset(0, -17), 9, size, Random(seed));
  }

  /// Petite plante posée sur un meuble.
  void smallPlant(Offset base, {bool big = false}) {
    g
      ..rect(base.dx - 3, base.dy - 5, 6, 5, Tone.white)
      ..rect(base.dx + 1, base.dy - 5, 2, 5, const Color(0xFFCFCABD));
    fronds(
      base + const Offset(0, -6),
      big ? 7 : 5,
      big ? 9 : 6,
      Random(base.dx.toInt()),
    );
  }

  void bookshelf(
    double x0,
    double y0,
    double x1, {
    double depth = 0.85,
    double h = 80,
    int shelves = 5,
    int seed = 1,
  }) {
    final y1 = y0 + depth;
    final random = Random(seed);
    g
      ..floor(x0 + 0.2, y0 + 0.3, x1 + 0.3, y1 + 0.4, const Color(0x66000000))
      ..box(
        x0,
        y0,
        x1,
        y1,
        0,
        h,
        top: Tone.shelfTop,
        left: const Color(0xFF22140C),
        right: Tone.shelfSide,
      );
    const crates = <Color>[
      Color(0xFF4A5A5C),
      Color(0xFFB88A52),
      Color(0xFF39424E),
    ];
    final step = (h - 6) / shelves;
    for (var s = 0; s < shelves; s++) {
      final zb = 3 + s * step;
      var x = x0 + 0.15;
      while (x < x1 - 0.3) {
        final kind = random.nextInt(11);
        if (kind == 0) {
          x += 0.3;
        } else if (kind == 1 && x < x1 - 0.9) {
          final crate = crates[random.nextInt(crates.length)];
          g
            ..wallX(x, x + 0.6, y1, zb, zb + step * 0.55, crate)
            ..wallX(
              x,
              x + 0.6,
              y1,
              zb + step * 0.55 - 2,
              zb + step * 0.55,
              shade(crate, 1.25),
            );
          x += 0.68;
        } else {
          final width = 0.11 + random.nextInt(3) * 0.035;
          final height = step * (0.5 + random.nextDouble() * 0.32);
          g.wallX(
            x,
            x + width,
            y1,
            zb,
            zb + height,
            Tone.books[random.nextInt(Tone.books.length)],
          );
          x += width + 0.02;
        }
      }
      g.wallX(x0, x1, y1, zb - 3, zb, Tone.shelfWood);
    }
    g
      ..wallX(x0, x0 + 0.1, y1, 0, h, Tone.shelfWood)
      ..wallX(x1 - 0.1, x1, y1, 0, h, Tone.shelfWood)
      ..wallX(x0, x1, y1, h - 3, h, Tone.shelfWood);
  }

  void serverRack(double x0, double y0, double x1, double y1) {
    const h = 68.0;
    g
      ..floor(x0 + 0.3, y0 + 0.3, x1 + 0.5, y1 + 0.6, const Color(0x73000000))
      ..box(
        x0,
        y0,
        x1,
        y1,
        0,
        h,
        top: const Color(0xFF30343B),
        left: const Color(0xFF15171B),
        right: const Color(0xFF0D0E11),
      );
    var unit = 0;
    for (var z = 5.0; z < h - 6; z += 6) {
      g.wallX(x0 + 0.15, x1 - 0.15, y1, z, z + 4.5, const Color(0xFF1F2227));
      for (var k = 0; k < 6; k++) {
        final lit = (k * 3 + unit * 5 + frame * (k + 1)) % 4 != 0;
        final color = !lit
            ? const Color(0xFF12331F)
            : (k == 5 && unit.isOdd ? Tone.amber : const Color(0xFF4DF58C));
        final xs = x0 + 0.3 + k * 0.22;
        g.wallX(xs, xs + 0.1, y1, z + 1.5, z + 3, color);
      }
      g.wallY(
        y0 + 0.2,
        y1 - 0.2,
        x1,
        z + 1.5,
        z + 2.5,
        const Color(0xFF1A1C20),
      );
      unit++;
    }
    glows.add(
      Glow(Iso.pt((x0 + x1) / 2, y1 + 0.5, 34), 34, const Color(0x2E4DF58C)),
    );
  }

  void rollingBoard(double x0, double x1, double y) {
    for (final xs in <double>[x0 + 0.15, x1 - 0.15]) {
      g
        ..floor(xs - 0.12, y - 0.45, xs + 0.12, y + 0.45, Tone.metal, 1)
        ..wallX(xs - 0.06, xs + 0.06, y, 0, 16, Tone.metalLight);
    }
    g
      ..wallX(x0, x1, y, 14, 54, const Color(0xFFA9AFB3))
      ..wallX(x0 + 0.12, x1 - 0.12, y, 16, 52, const Color(0xFFECEDE8))
      ..wallX(x0 + 0.4, x1 - 0.4, y, 12.5, 14, const Color(0xFF7C8286));
    const ink = Color(0xFF6B7178);
    const note = Color(0xFFF4C84A);
    // Schéma : un groupe de notes relié à deux blocs.
    final cx = x0 + 0.95;
    g
      ..wallX(cx, cx + 0.3, y, 40, 45, note)
      ..wallX(cx - 0.34, cx - 0.04, y, 34, 39, note)
      ..wallX(cx, cx + 0.3, y, 34, 39, const Color(0xFFF2A04A))
      ..wallX(cx + 0.34, cx + 0.64, y, 34, 39, note)
      ..wallX(cx, cx + 0.3, y, 28, 33, note)
      ..wallX(cx + 0.7, x0 + 2, y, 36, 37, ink)
      ..wallX(x0 + 2, x0 + 2.5, y, 33, 40, const Color(0xFFD5D8D2))
      ..wallX(x0 + 1.4, x0 + 2.4, y, 24, 25, ink)
      ..wallX(x0 + 1.4, x0 + 2.1, y, 21, 22, ink)
      ..wallX(x0 + 0.5, x0 + 1.6, y, 47, 48, ink);
  }

  void roundTable(double cx, double cy, double radius) {
    const z = 15.0;
    final foot = Iso.pt(cx, cy);
    final top = Iso.pt(cx, cy, z);
    final rw = radius * Iso.halfTileWidth * sqrt2;
    final rh = radius * Iso.halfTileHeight * sqrt2;
    g
      ..oval(foot + const Offset(3, 3), rw, rh, const Color(0x66000000))
      ..oval(foot, 9, 4, Tone.shelfSide)
      ..rect(foot.dx - 3, foot.dy - z, 6, z, Tone.shelfSide)
      ..oval(top + const Offset(0, 3), rw, rh, Tone.deskEdge)
      ..rect(top.dx - rw, top.dy, rw * 2, 3, Tone.deskEdge)
      ..oval(top, rw, rh, Tone.deskTop)
      ..oval(top, rw - 4, rh - 2, const Color(0xFFC08A50))
      ..oval(top, rw - 6, rh - 3, Tone.deskTop);
    // Ordinateurs portables, pot à crayons, carnet.
    void laptop(double x, double y, {required bool open}) {
      g.floor(
        x - 0.4,
        y - 0.3,
        x + 0.4,
        y + 0.3,
        const Color(0xFF8E9399),
        z + 0.5,
      );
      if (open) {
        g
          ..wallX(
            x - 0.4,
            x + 0.4,
            y - 0.3,
            z + 0.5,
            z + 8,
            const Color(0xFF8E9399),
          )
          ..wallX(
            x - 0.32,
            x + 0.32,
            y - 0.3,
            z + 1.5,
            z + 7,
            const Color(0xFF1C3D4A),
          );
      }
    }

    laptop(cx - 0.9, cy - 0.9, open: true);
    laptop(cx + 0.9, cy - 0.6, open: true);
    laptop(cx + 0.5, cy + 1, open: false);
    g
      ..floor(cx - 0.9, cy + 0.6, cx - 0.3, cy + 1.2, Tone.white, z + 0.5)
      ..solid(
        cx - 0.15,
        cy - 0.15,
        cx + 0.15,
        cy + 0.15,
        z,
        z + 5,
        const Color(0xFF6E8A6A),
      )
      ..rect(top.dx - 1, top.dy - 9, 1, 4, Tone.amber)
      ..rect(top.dx + 1, top.dy - 8, 1, 3, const Color(0xFFE2574A));
  }

  /// Fauteuil de bureau. [back] indique le côté du dossier : 0 = x décroissant,
  /// 1 = y décroissant, 2 = x croissant, 3 = y croissant.
  void chair(double x, double y, {required int back, required Color color}) {
    final foot = Iso.pt(x, y);
    final backColor = shade(color, 1.12);
    void backrest() {
      switch (back) {
        case 0:
          g.solid(x - 0.5, y - 0.45, x - 0.36, y + 0.45, 12, 29, backColor);
        case 1:
          g.solid(x - 0.45, y - 0.5, x + 0.45, y - 0.36, 12, 29, backColor);
        case 2:
          g.solid(x + 0.36, y - 0.45, x + 0.5, y + 0.45, 12, 29, backColor);
        default:
          g.solid(x - 0.45, y + 0.36, x + 0.45, y + 0.5, 12, 29, backColor);
      }
    }

    g
      ..oval(foot + const Offset(1, 1), 9, 4, const Color(0x59000000))
      ..rect(foot.dx - 6, foot.dy - 1, 12, 2, Tone.metal)
      ..rect(foot.dx - 1, foot.dy - 9, 2, 9, Tone.metalLight);
    if (back < 2) {
      backrest();
    }
    g.solid(x - 0.45, y - 0.45, x + 0.45, y + 0.45, 9, 12, color);
    if (back >= 2) {
      backrest();
    }
  }

  void armchair(double x, double y) {
    const leather = Color(0xFF7A4E32);
    g
      ..floor(x - 0.6, y - 0.6, x + 1, y + 1, const Color(0x66000000))
      ..solid(x - 0.8, y - 0.8, x + 0.8, y - 0.5, 0, 22, leather)
      ..solid(x - 0.8, y - 0.5, x - 0.5, y + 0.8, 0, 15, leather)
      ..solid(
        x - 0.5,
        y - 0.5,
        x + 0.8,
        y + 0.8,
        0,
        10,
        const Color(0xFF8A5A3A),
      )
      ..solid(x + 0.5, y - 0.5, x + 0.8, y + 0.8, 10, 15, leather);
  }

  void waterCooler(double x, double y) {
    g
      ..floor(x + 0.1, y + 0.1, x + 1, y + 1, const Color(0x59000000))
      ..solid(x, y, x + 0.8, y + 0.8, 0, 27, const Color(0xFFDADDE0))
      ..wallX(x + 0.2, x + 0.6, y + 0.8, 14, 21, const Color(0xFF8E9399))
      ..wallX(x + 0.25, x + 0.35, y + 0.8, 16, 18, const Color(0xFF4A8AD8))
      ..wallX(x + 0.45, x + 0.55, y + 0.8, 16, 18, const Color(0xFFE2574A))
      ..box(
        x + 0.1,
        y + 0.1,
        x + 0.7,
        y + 0.7,
        27,
        42,
        top: const Color(0xFFB8DCF5),
        left: const Color(0xFF7FB4E0),
        right: const Color(0xFF5E96C8),
      )
      ..wallX(x + 0.15, x + 0.3, y + 0.7, 30, 40, const Color(0xFFB8DCF5));
  }

  // ------------------------------------------------- meubles des salles

  /// Canapé dont le dossier est contre y = [y0].
  void sofa(
    double x0,
    double y0,
    double x1, {
    Color color = const Color(0xFF7A4E32),
  }) {
    final y1 = y0 + 1.1;
    g
      ..floor(x0 + 0.2, y0 + 0.2, x1 + 0.3, y1 + 0.3, const Color(0x59000000))
      ..solid(x0, y0, x1, y1, 0, 9, shade(color, 1.1))
      ..solid(x0, y0, x1, y0 + 0.35, 9, 20, color)
      ..solid(x0, y0, x0 + 0.3, y1, 9, 14, color)
      ..solid(x1 - 0.3, y0, x1, y1, 9, 14, color);
    for (var x = x0 + 0.5; x < x1 - 0.8; x += 1.1) {
      g.solid(x, y0 + 0.4, x + 0.5, y0 + 0.7, 9, 15, const Color(0xFF3F7A68));
    }
  }

  /// Table basse.
  void lowTable(double x0, double y0, double x1, double y1) {
    g
      ..solid(x0, y0, x1, y1, 0, 7, Tone.deskEdge)
      ..floor(x0, y0, x1, y1, Tone.deskTop, 7);
    mug(Iso.pt((x0 + x1) / 2, (y0 + y1) / 2, 7));
  }

  /// Table rectangulaire et ses chaises de chaque côté.
  void longTable(
    double x0,
    double y0,
    double x1,
    double y1, {
    bool laptops = true,
  }) {
    for (var x = x0 + 0.6; x < x1 - 0.3; x += 1.2) {
      chair(x, y0 - 0.5, back: 1, color: Tone.chairGrey);
    }
    g
      ..floor(x0 + 0.3, y0 + 0.3, x1 + 0.4, y1 + 0.4, const Color(0x59000000))
      ..solid(x0 + 0.3, y0 + 0.3, x0 + 0.5, y1 - 0.3, 0, 14, Tone.shelfSide)
      ..solid(x1 - 0.5, y0 + 0.3, x1 - 0.3, y1 - 0.3, 0, 14, Tone.shelfSide)
      ..box(
        x0,
        y0,
        x1,
        y1,
        14,
        17,
        top: Tone.deskTop,
        left: Tone.deskEdge,
        right: Tone.deskEdgeDark,
      );
    if (laptops) {
      for (var x = x0 + 0.4; x < x1 - 0.8; x += 1.2) {
        g
          ..floor(
            x,
            y0 + 0.15,
            x + 0.6,
            y0 + 0.6,
            const Color(0xFF8E9399),
            17.5,
          )
          ..wallX(x, x + 0.6, y0 + 0.15, 17.5, 23, const Color(0xFF8E9399))
          ..wallX(
            x + 0.06,
            x + 0.54,
            y0 + 0.15,
            18.5,
            22.5,
            const Color(0xFF1C3D4A),
          );
      }
    }
    for (var x = x0 + 0.6; x < x1 - 0.3; x += 1.2) {
      chair(x, y1 + 0.5, back: 3, color: Tone.chairGrey);
    }
  }

  /// Écran mural fixé contre y = [y] (face à la caméra).
  void wallScreen(
    double x0,
    double x1,
    double y, {
    double z = 26,
    bool chart = false,
  }) {
    g
      ..wallX(x0, x1, y + 0.05, z, z + 24, const Color(0xFF15171B))
      ..wallX(
        x0 + 0.1,
        x1 - 0.1,
        y + 0.05,
        z + 2,
        z + 22,
        const Color(0xFF13303A),
      );
    if (chart) {
      final bars = ((x1 - x0) / 0.35).floor() - 1;
      for (var i = 0; i < bars; i++) {
        final h = 4 + ((i * 7 + frame * 3) % 13).toDouble();
        final xs = x0 + 0.25 + i * 0.35;
        g.wallX(
          xs,
          xs + 0.2,
          y + 0.05,
          z + 3,
          z + 3 + h,
          i.isEven ? Tone.screenGreen : Tone.amber,
        );
      }
    } else {
      for (var i = 0; i < 4; i++) {
        final w = (x1 - x0 - 0.5) * (0.4 + ((i + frame) % 3) * 0.2);
        g.wallX(
          x0 + 0.25,
          x0 + 0.25 + w,
          y + 0.05,
          z + 17 - i * 4,
          z + 18.5 - i * 4,
          i == 1 ? Tone.amber : Tone.screenGreen,
        );
      }
    }
    glows.add(
      Glow(Iso.pt((x0 + x1) / 2, y + 0.8, z + 12), 30, const Color(0x2E5CF2A6)),
    );
  }

  /// Tableau blanc mural, notes collées, contre y = [y].
  void wallBoard(double x0, double x1, double y) {
    g
      ..wallX(x0, x1, y + 0.05, 22, 52, const Color(0xFFB9BDBF))
      ..wallX(x0 + 0.1, x1 - 0.1, y + 0.05, 24, 50, const Color(0xFFF1F0EA));
    const notes = <Color>[
      Color(0xFFF4C84A),
      Color(0xFFF08A8A),
      Color(0xFF8AC6F0),
      Color(0xFFF2A04A),
    ];
    var i = 0;
    for (var x = x0 + 0.3; x < x1 - 0.5; x += 0.45) {
      for (var z = 42.0; z > 27; z -= 8) {
        if ((i * 5 + 3) % 7 < 4) {
          g.wallX(x, x + 0.3, y + 0.05, z, z + 5, notes[i % notes.length]);
        }
        i++;
      }
    }
  }

  /// Étagère d'archives : boîtes et classeurs.
  void archiveShelf(double x0, double y0, double x1) {
    const boxes = <Color>[
      Color(0xFFB88A52),
      Color(0xFFA67A46),
      Color(0xFFC9A06A),
      Color(0xFF8C6A42),
    ];
    final y1 = y0 + 0.8;
    g.box(
      x0,
      y0,
      x1,
      y1,
      0,
      62,
      top: const Color(0xFF5A6068),
      left: const Color(0xFF2B2E33),
      right: const Color(0xFF3A3F47),
    );
    var k = 0;
    for (var z = 4.0; z < 56; z += 13) {
      for (var x = x0 + 0.1; x < x1 - 0.5; x += 0.55) {
        final color = boxes[k++ % boxes.length];
        g
          ..wallX(x, x + 0.5, y1, z, z + 10, color)
          ..wallX(x + 0.15, x + 0.35, y1, z + 6, z + 8, Tone.white);
      }
      g.wallX(x0, x1, y1, z - 2, z, const Color(0xFF6B7178));
    }
  }

  /// Paillasse de laboratoire avec ses instruments.
  void labBench(double x0, double y0, double x1) {
    final y1 = y0 + 1.2;
    g
      ..floor(x0 + 0.2, y0 + 0.2, x1 + 0.3, y1 + 0.3, const Color(0x59000000))
      ..solid(x0, y0, x1, y1, 0, 19, const Color(0xFFD5D8D2))
      ..floor(x0, y0, x1, y1, const Color(0xFF39424E), 20)
      ..wallX(x0, x1, y1, 19, 20, const Color(0xFF2B2E33));
    var i = 0;
    for (var x = x0 + 0.3; x < x1 - 0.4; x += 0.9) {
      switch (i++ % 3) {
        case 0:
          // Fiole verte.
          final p = Iso.pt(x, y0 + 0.6, 20);
          g
            ..rect(p.dx - 2, p.dy - 9, 4, 9, const Color(0xCC9FE8C8))
            ..rect(p.dx - 1, p.dy - 12, 2, 3, const Color(0xCCD5D8D2))
            ..rect(p.dx - 2, p.dy - 4, 4, 4, Tone.screenGreen);
        case 1:
          // Petit appareil à écran.
          g
            ..solid(
              x - 0.25,
              y0 + 0.3,
              x + 0.35,
              y0 + 0.9,
              20,
              28,
              const Color(0xFF8E9399),
            )
            ..wallX(
              x - 0.15,
              x + 0.25,
              y0 + 0.9,
              22,
              26,
              const Color(0xFF13303A),
            );
        default:
          // Prototype : un boîtier ambre.
          g.solid(x - 0.2, y0 + 0.35, x + 0.3, y0 + 0.85, 20, 24, Tone.amber);
      }
    }
  }

  /// Chevalet et toile.
  void easel(double x, double y, {int seed = 0}) {
    final p = Iso.pt(x, y);
    const colors = <Color>[
      Color(0xFFE2874A),
      Color(0xFF3F8A8C),
      Color(0xFFF4C84A),
      Color(0xFF8A5AA8),
    ];
    g
      ..oval(p + const Offset(1, 1), 7, 3, const Color(0x59000000))
      ..rect(p.dx - 6, p.dy - 34, 1, 34, Tone.woodDark)
      ..rect(p.dx + 5, p.dy - 34, 1, 34, Tone.woodDark)
      ..rect(p.dx - 9, p.dy - 40, 18, 22, Tone.white)
      ..rect(p.dx - 7, p.dy - 37, 9, 8, colors[seed % 4])
      ..rect(p.dx - 2, p.dy - 32, 8, 10, colors[(seed + 1) % 4])
      ..rect(p.dx - 10, p.dy - 18, 20, 2, Tone.woodDark);
  }

  /// Borne d'arcade (création originale, écran animé).
  void arcade(double x, double y, Color body) {
    g
      ..floor(x + 0.1, y + 0.1, x + 1.1, y + 1.1, const Color(0x59000000))
      ..solid(x, y, x + 0.9, y + 0.9, 0, 50, body)
      ..wallX(x + 0.1, x + 0.8, y + 0.9, 30, 45, const Color(0xFF101418))
      ..wallX(
        x + 0.2,
        x + 0.7,
        y + 0.9,
        32 + (frame % 2) * 2,
        36 + (frame % 2) * 2,
        Tone.screenGreen,
      )
      ..wallX(x + 0.3, x + 0.4, y + 0.9, 39, 42, Tone.amber)
      ..solid(x - 0.1, y + 0.7, x + 1, y + 1.1, 22, 26, shade(body, 0.7))
      ..wallX(x + 0.2, x + 0.3, y + 1.1, 26, 28, const Color(0xFFE2574A))
      ..wallX(x + 0.6, x + 0.7, y + 1.1, 26, 28, const Color(0xFF4A8AD8));
    glows.add(Glow(Iso.pt(x + 0.45, y + 1.4, 36), 22, const Color(0x335CF2A6)));
  }

  /// Lit de repos.
  void bed(double x, double y, Color blanket) {
    g
      ..floor(x + 0.2, y + 0.2, x + 1.4, y + 2.3, const Color(0x59000000))
      ..solid(x, y, x + 1.2, y + 2.1, 0, 8, Tone.woodDark)
      ..solid(x + 0.05, y + 0.05, x + 1.15, y + 2.05, 8, 11, Tone.white)
      ..solid(x + 0.05, y + 0.7, x + 1.15, y + 2.05, 11, 12, blanket)
      ..solid(
        x + 0.2,
        y + 0.15,
        x + 1,
        y + 0.55,
        11,
        14,
        const Color(0xFFDAD6CC),
      )
      ..solid(x, y, x + 1.2, y + 0.15, 8, 22, Tone.woodDark);
  }

  /// Tapis de sport posé au sol.
  void mat(double x, double y, Color color) {
    g
      ..floor(x, y, x + 0.9, y + 2, shade(color, 0.7), 0.5)
      ..floor(x + 0.05, y + 0.05, x + 0.85, y + 1.95, color, 1);
  }

  /// Gradin : marche et sièges, du fond vers l'avant.
  void bleacher(double x0, double x1, double y, double z) {
    g.solid(x0, y, x1, y + 1, 0, z, const Color(0xFF4A3524));
    for (var x = x0 + 0.2; x < x1 - 0.5; x += 0.8) {
      g
        ..solid(x, y + 0.3, x + 0.6, y + 0.8, z, z + 4, const Color(0xFF8A3A32))
        ..solid(
          x,
          y + 0.2,
          x + 0.6,
          y + 0.3,
          z,
          z + 12,
          const Color(0xFF7A3028),
        );
    }
  }

  /// Comptoir de cuisine avec évier et machine à café.
  void counter(double x0, double y0, double x1) {
    final y1 = y0 + 0.9;
    g
      ..solid(x0, y0, x1, y1, 0, 20, const Color(0xFF9A6A3C))
      ..floor(x0, y0, x1, y1, const Color(0xFFC4B8A4), 20.5)
      ..floor(
        x0 + 0.4,
        y0 + 0.2,
        x0 + 1.1,
        y0 + 0.7,
        const Color(0xFF8E9399),
        20.6,
      )
      ..solid(
        x1 - 1,
        y0 + 0.15,
        x1 - 0.3,
        y0 + 0.75,
        20.5,
        36,
        const Color(0xFF30333A),
      )
      ..wallX(x1 - 0.85, x1 - 0.45, y0 + 0.75, 25, 31, const Color(0xFF15171B))
      ..wallX(x1 - 0.85, x1 - 0.75, y0 + 0.75, 32, 34, const Color(0xFFE2574A));
    for (var x = x0 + 0.3; x < x1 - 0.4; x += 0.7) {
      g.wallX(x, x + 0.5, y1, 4, 16, shade(const Color(0xFF9A6A3C), 1.12));
    }
  }

  /// Rangée de casiers.
  void lockers(double x0, double y0, double x1) {
    final y1 = y0 + 0.7;
    g.box(
      x0,
      y0,
      x1,
      y1,
      0,
      50,
      top: const Color(0xFF6E8AA0),
      left: const Color(0xFF4A6478),
      right: const Color(0xFF3A5062),
    );
    for (var x = x0; x < x1 - 0.1; x += 0.5) {
      g
        ..wallX(x, x + 0.04, y1, 0, 50, const Color(0xFF2F4252))
        ..wallX(x + 0.32, x + 0.4, y1, 26, 28, Tone.white)
        ..wallX(x + 0.1, x + 0.4, y1, 42, 43, const Color(0xFF2F4252));
    }
  }

  /// Lavabo et miroir contre y = [y].
  void sink(double x, double y) {
    g
      ..wallX(x, x + 0.8, y + 0.05, 28, 46, const Color(0xFF9FC4D8))
      ..solid(x, y, x + 0.8, y + 0.6, 16, 20, Tone.white)
      ..floor(
        x + 0.15,
        y + 0.1,
        x + 0.65,
        y + 0.45,
        const Color(0xFFB8DCF5),
        20.2,
      );
  }

  /// Photocopieur.
  void copier(double x, double y) {
    g
      ..floor(x + 0.2, y + 0.2, x + 1.4, y + 1.1, const Color(0x59000000))
      ..solid(x, y, x + 1.2, y + 0.9, 0, 24, const Color(0xFFDADDE0))
      ..solid(
        x + 0.05,
        y + 0.05,
        x + 1.15,
        y + 0.85,
        24,
        27,
        const Color(0xFF8E9399),
      )
      ..floor(x + 0.2, y + 0.55, x + 0.6, y + 0.8, Tone.white, 27.5)
      ..wallX(x + 0.75, x + 1.05, y + 0.9, 18, 21, Tone.screenGreen)
      ..wallX(x + 0.1, x + 0.6, y + 0.9, 8, 10, const Color(0xFF6B7178));
  }

  /// Cabine téléphonique vitrée, ouverte vers l'avant.
  void booth(double x, double y, {PersonDraw? occupant}) {
    const frame = Color(0xFF22262A);
    g
      ..floor(x, y, x + 1.6, y + 1.6, const Color(0xFF2E3A3A))
      ..wallX(x, x + 1.6, y, 0, 52, const Color(0xFF3F5A55))
      ..wallY(y, y + 1.6, x, 0, 52, const Color(0xFF34504B))
      ..solid(x + 0.1, y + 0.1, x + 1.5, y + 0.5, 14, 17, Tone.deskTop);
    occupant?.call(Iso.pt(x + 0.8, y + 1));
    g
      ..wallY(y, y + 1.6, x + 1.6, 0, 52, const Color(0x336FA0A8))
      ..wallY(y - 0.05, y + 0.05, x + 1.6, 0, 52, frame)
      ..wallY(y + 1.55, y + 1.65, x + 1.6, 0, 52, frame)
      ..floor(x, y, x + 1.6, y + 1.6, const Color(0xFF3A4046), 52);
    glows.add(Glow(Iso.pt(x + 0.8, y + 0.8, 44), 18, Tone.lampGlow));
  }

  /// Lampadaire.
  void floorLamp(double x, double y) {
    final foot = Iso.pt(x, y);
    g
      ..oval(foot, 5, 2.5, Tone.metal)
      ..rect(foot.dx - 1, foot.dy - 34, 1, 34, Tone.metalLight)
      ..rect(foot.dx - 5, foot.dy - 40, 10, 6, const Color(0xFFD8A24A))
      ..rect(foot.dx - 4, foot.dy - 34, 8, 1, const Color(0xFFFFE9A8));
    glows.add(Glow(foot + const Offset(0, -30), 46, Tone.lampGlow));
  }

  /// Banc de jardin.
  void bench(double x0, double y, double x1) {
    g
      ..solid(x0 + 0.1, y, x0 + 0.25, y + 0.6, 0, 9, Tone.metal)
      ..solid(x1 - 0.25, y, x1 - 0.1, y + 0.6, 0, 9, Tone.metal)
      ..solid(x0, y, x1, y + 0.6, 9, 11, Tone.deskTop)
      ..solid(x0, y, x1, y + 0.12, 11, 20, Tone.deskEdge);
  }

  /// Micro et pied, pour le studio.
  void microphone(double x, double y) {
    final p = Iso.pt(x, y);
    g
      ..oval(p, 4, 2, Tone.metal)
      ..rect(p.dx, p.dy - 30, 1, 30, Tone.metalLight)
      ..rect(p.dx - 2, p.dy - 36, 5, 7, const Color(0xFF30333A))
      ..rect(p.dx - 1, p.dy - 35, 3, 1, Tone.metalLight);
  }

  /// Panneau mural acoustique, contre y = [y].
  void acousticPanels(double x0, double x1, double y) {
    var i = 0;
    for (var x = x0; x < x1 - 0.5; x += 0.6) {
      final dark = i.isEven;
      i++;
      g.wallX(
        x + 0.05,
        x + 0.55,
        y + 0.05,
        20,
        50,
        dark ? const Color(0xFF3A3340) : const Color(0xFF4A3F52),
      );
    }
  }
}

/// Dessine un personnage aux pieds indiqués.
typedef PersonDraw = void Function(Offset feet);
