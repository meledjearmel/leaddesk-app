import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'furniture.dart';
import 'iso.dart';
import 'pixel_people.dart';

/// Nombre d'images d'ambiance de la scène (écrans, voyants, gestes).
const int officeFrameCount = 4;

/// Apparence des agents de la scène.
abstract final class OfficeLooks {
  static const PersonLook forge = PersonLook(
    skin: Color(0xFFE9BE95),
    hair: Color(0xFF2E211C),
    top: Color(0xFF2A3854),
  );
  static const PersonLook atlas = PersonLook(
    skin: Color(0xFFEBC29A),
    hair: Color(0xFF3B2A22),
    top: Color(0xFF3F7650),
    inner: Color(0xFFE9E2D0),
    pants: Color(0xFF30456B),
  );
  static const PersonLook quill = PersonLook(
    skin: Color(0xFFEBC29A),
    hair: Color(0xFF2B1F1C),
    top: Color(0xFF2C2A31),
    inner: Color(0xFFF1EDE4),
    tie: Color(0xFFB8402F),
    pants: Color(0xFF30456B),
  );
  static const PersonLook relay = PersonLook(
    skin: Color(0xFFE9BE95),
    hair: Color(0xFF2B1F1C),
    top: Color(0xFF2E5661),
    inner: Color(0xFFE9E2D0),
  );
  static const PersonLook scout = PersonLook(
    skin: Color(0xFFD9A47A),
    hair: Color(0xFF4A2E1E),
    top: Color(0xFF3C5FA8),
  );
}

/// État du personnage qui se déplace dans la scène.
class WalkerState {
  const WalkerState({
    required this.feet,
    required this.walking,
    required this.faceLeft,
    required this.step,
  });

  final Offset feet;
  final bool walking;
  final bool faceLeft;
  final int step;
}

/// Emplacements des agents dans la scène, en pixels d'art.
abstract final class OfficeLayout {
  /// Point que la caméra centre à l'ouverture : entre le tableau et la table.
  static const Offset focus = Offset(298, 222);

  static final Offset forgeSeat = Iso.pt(6.2, 3.3);
  static final Offset atlasFeet = Iso.pt(20.2, 11);
  static final Offset quillFeet = Iso.pt(21.3, 10.1);
  static final Offset scoutFeet = Iso.pt(21.2, 2.4);

  static final Offset _walkStart = Iso.pt(29.2, 12.4);
  static final Offset _walkEnd = Iso.pt(31, 10.4);
  static const double _walkSeconds = 6;
  static const double _restSeconds = 3.5;

  /// Hauteur d'un personnage debout, des pieds au sommet du crâne.
  static const double personHeight = 44;

  /// Position de l'agent qui fait les cent pas, au temps de scène [time].
  static WalkerState walkerAt(double time) {
    const cycle = 2 * (_walkSeconds + _restSeconds);
    final phase = time % cycle;
    final step = (time * 6).floor() % 4;
    if (phase < _walkSeconds) {
      return WalkerState(
        feet: Offset.lerp(_walkStart, _walkEnd, phase / _walkSeconds)!,
        walking: true,
        faceLeft: false,
        step: step,
      );
    }
    if (phase < _walkSeconds + _restSeconds) {
      return WalkerState(
        feet: _walkEnd,
        walking: false,
        faceLeft: true,
        step: 0,
      );
    }
    if (phase < 2 * _walkSeconds + _restSeconds) {
      final t = (phase - _walkSeconds - _restSeconds) / _walkSeconds;
      return WalkerState(
        feet: Offset.lerp(_walkEnd, _walkStart, t)!,
        walking: true,
        faceLeft: true,
        step: step,
      );
    }
    return WalkerState(
      feet: _walkStart,
      walking: false,
      faceLeft: false,
      step: 0,
    );
  }
}

/// Rend une image d'ambiance de la scène à sa résolution d'art.
///
/// L'image est ensuite agrandie sans lissage : c'est ce qui donne le grain
/// du pixel art. L'appelant libère l'image avec `dispose`.
ui.Image renderOfficeFrame(int frame) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, sceneWidth, sceneHeight),
  );
  OfficeScenePainter(canvas, frame % officeFrameCount).paint();
  final picture = recorder.endRecording();
  final image = picture.toImageSync(sceneWidth.toInt(), sceneHeight.toInt());
  picture.dispose();
  return image;
}

class _Item {
  _Item(this.depth, this.order, this.draw);

  final double depth;
  final int order;
  final void Function() draw;
}

/// Dessine le bureau : décor, mobilier, personnages à leur poste, lumières.
///
/// Tout est dessiné par le code, sans lissage, à la résolution d'art. Le
/// mobilier et les personnages sont triés par profondeur avant d'être peints.
class OfficeScenePainter extends FurnitureKit {
  OfficeScenePainter(super.canvas, super.frame);

  final List<_Item> _items = <_Item>[];

  void paint() {
    canvas
      ..save()
      ..clipRect(const Rect.fromLTWH(0, 0, sceneWidth, sceneHeight));
    g.rect(0, 0, sceneWidth, sceneHeight, const Color(0xFF0B0908));
    _floor();
    _rug();
    _backRoom();
    _leftWall();
    _backWall();
    _furniture();
    _people();
    _items.sort((a, b) {
      final byDepth = a.depth.compareTo(b.depth);
      return byDepth != 0 ? byDepth : a.order.compareTo(b.order);
    });
    for (final item in _items) {
      item.draw();
    }
    _lighting();
    canvas.restore();
  }

  void _add(double depth, void Function() draw) {
    _items.add(_Item(depth, _items.length, draw));
  }

  // ---------------------------------------------------------------- décor

  void _floor() {
    final random = Random(11);
    const planks = <Color>[
      Color(0xFF3A2317),
      Color(0xFF41281A),
      Color(0xFF48301F),
      Color(0xFF36201A),
      Color(0xFF4D3322),
    ];
    const seam = Color(0xFF26160F);
    for (var i = -28; i < 56; i++) {
      final y = i / 2;
      var x = -random.nextDouble() * 3;
      while (x < 35) {
        final length = 2.5 + random.nextInt(4);
        final start = max(x, 0.0);
        g
          ..floor(
            start,
            y,
            x + length,
            y + 0.5,
            planks[random.nextInt(planks.length)],
          )
          ..floor(x + length - 0.08, y, x + length, y + 0.5, seam);
        x += length;
      }
      g.floor(0, y, 35, y + 0.08, seam);
    }
  }

  void _rug() {
    const x0 = 17.4;
    const y0 = 4.4;
    const x1 = 29.8;
    const y1 = 12.0;
    const red = Color(0xFF6C3428);
    const beige = Color(0xFFB49062);
    const field = Color(0xFF4B433C);
    g
      ..floor(x0, y0, x1, y1, const Color(0xFF2A1512))
      ..floor(x0 + 0.2, y0 + 0.2, x1 - 0.2, y1 - 0.2, red)
      ..floor(x0 + 0.5, y0 + 0.5, x1 - 0.5, y1 - 0.5, beige)
      ..floor(
        x0 + 0.65,
        y0 + 0.65,
        x1 - 0.65,
        y1 - 0.65,
        const Color(0xFF55261F),
      );
    for (var x = x0 + 1.0; x < x1 - 1.2; x += 0.8) {
      g
        ..floor(x, y0 + 0.85, x + 0.4, y0 + 1.15, beige)
        ..floor(x, y1 - 1.15, x + 0.4, y1 - 0.85, beige);
    }
    for (var y = y0 + 1.0; y < y1 - 1.2; y += 0.8) {
      g
        ..floor(x0 + 0.85, y, x0 + 1.15, y + 0.4, beige)
        ..floor(x1 - 1.15, y, x1 - 0.85, y + 0.4, beige);
    }
    g
      ..floor(x0 + 1.4, y0 + 1.4, x1 - 1.4, y1 - 1.4, red)
      ..floor(x0 + 1.6, y0 + 1.6, x1 - 1.6, y1 - 1.6, field);
    // Semis de motifs dans le champ.
    final random = Random(5);
    for (var x = x0 + 2.0; x < x1 - 2.2; x += 0.9) {
      for (var y = y0 + 2.0; y < y1 - 2.2; y += 0.9) {
        final pick = random.nextInt(5);
        if (pick < 2) {
          g.floor(x, y, x + 0.3, y + 0.3, pick == 0 ? red : beige);
        }
      }
    }
    // Médaillons.
    for (final cx in <double>[x0 + 3.2, (x0 + x1) / 2, x1 - 3.2]) {
      const cy = (y0 + y1) / 2;
      void diamond(double size, Color color) {
        g.quad(
          Iso.pt(cx - size, cy),
          Iso.pt(cx, cy - size),
          Iso.pt(cx + size, cy),
          Iso.pt(cx, cy + size),
          color,
        );
      }

      diamond(1.5, red);
      diamond(1.15, beige);
      diamond(0.95, const Color(0xFF55261F));
      diamond(0.45, beige);
    }
  }

  /// Pièces du fond : salle de réunion derrière la cloison vitrée, rayonnages.
  void _backRoom() {
    g
      ..floor(3.3, -5.2, 9, -2.8, const Color(0x66000000))
      ..solid(4, -4.8, 4.5, -3.6, 0, 14, Tone.woodDark)
      ..solid(7.5, -4.8, 8, -3.6, 0, 14, Tone.woodDark)
      ..box(
        3.4,
        -5.4,
        8.6,
        -3.1,
        14,
        17,
        top: Tone.deskTop,
        left: Tone.deskEdge,
        right: Tone.deskEdgeDark,
      )
      ..floor(5.2, -4.7, 6, -4.1, Tone.white, 17.5)
      ..floor(6.6, -4.5, 7.3, -3.8, const Color(0xFF3A3D42), 17.5);
    chair(4.6, -6.1, back: 1, color: Tone.chairDark);
    chair(7.2, -6.1, back: 1, color: Tone.chairDark);
    drawPerson(
      canvas,
      Iso.pt(5.6, -2.3),
      const PersonLook(
        skin: Color(0xFFD9A47A),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFF5B4A7A),
      ),
      pose: PersonPose.seated,
      back: true,
    );
    chair(5.6, -2.2, back: 3, color: Tone.chairDark);
    chair(7.6, -2.2, back: 3, color: Tone.chairDark);
    // Voile bleu nuit : la salle est vue à travers la vitre.
    g.floor(0, -14, 12, 0, const Color(0x8C070B10));
    bookshelf(10, -6.6, 13, seed: 21, h: 82);
    bookshelf(13.3, -6.6, 16.6, seed: 22, h: 82);
    glows.add(Glow(Iso.pt(13.2, -5, 40), 60, const Color(0x40FFC46B)));
  }

  void _leftWall() {
    const wall = Color(0xFFCDB999);
    const x = 0.0;
    g
      ..wallY(-14, 0, x, 0, 78, const Color(0xFF8A7B66))
      ..wallY(0, 10.6, x, 0, 78, wall)
      ..wallY(0, 10.6, x, 60, 78, const Color(0xFFD6C4A6))
      ..wallY(-14, 10.6, x, 0, 4, const Color(0xFF4A3524))
      ..quad(
        Iso.pt(0, -14, 78),
        Iso.pt(0, 10.6, 78),
        Iso.pt(-0.45, 10.6, 78),
        Iso.pt(-0.45, -14, 78),
        const Color(0xFFE6D8BE),
      );

    // Tableau blanc mural et ses notes repositionnables.
    g
      ..wallY(2.5, 6.5, 0.02, 24, 66, const Color(0xFFB9BDBF))
      ..wallY(2.65, 6.35, 0.02, 26, 64, const Color(0xFFF1F0EA))
      ..wallY(2.9, 6.1, 0.02, 22, 24, const Color(0xFF8D9194));
    const notes = <Color>[
      Color(0xFFF4C84A),
      Color(0xFFF08A8A),
      Color(0xFFF2A04A),
      Color(0xFFF4C84A),
      Color(0xFF8AC6F0),
      Color(0xFFF4C84A),
    ];
    for (var i = 0; i < notes.length; i++) {
      final y = 2.95 + (i % 3) * 0.55;
      final z = 52.0 - (i ~/ 3) * 9;
      g.wallY(y, y + 0.36, 0.02, z, z + 6, notes[i]);
    }
    const ink = Color(0xFF5A6068);
    g
      ..wallY(4.9, 6, 0.02, 55, 56, ink)
      ..wallY(4.9, 5.7, 0.02, 50, 51, ink)
      ..wallY(5.1, 6.1, 0.02, 45, 46, ink)
      ..wallY(4.85, 5.35, 0.02, 34, 41, const Color(0xFFDADCD6))
      ..wallY(5.6, 6.1, 0.02, 34, 41, const Color(0xFFDADCD6))
      ..wallY(5.35, 5.6, 0.02, 37, 38, ink);

    // Affiche et note.
    g
      ..wallY(7.4, 8.7, 0.02, 30, 58, const Color(0xFF6B5B46))
      ..wallY(7.5, 8.6, 0.02, 32, 56, const Color(0xFFEFE3C8))
      ..wallY(7.75, 8.35, 0.02, 40, 52, const Color(0xFFE2874A))
      ..wallY(7.75, 8.05, 0.02, 46, 52, const Color(0xFF3F8A8C))
      ..wallY(7.7, 8.4, 0.02, 35, 36, ink)
      ..wallY(6.8, 7.15, 0.02, 44, 52, Tone.white);

    // Plante suspendue près de l'angle.
    final hook = Iso.pt(0.5, 1.1, 78);
    g
      ..rect(hook.dx, hook.dy, 1, 8, const Color(0xFF3A2A1E))
      ..rect(hook.dx - 4, hook.dy + 8, 9, 5, const Color(0xFF8A5A3A));
    for (var i = 0; i < 4; i++) {
      final vx = hook.dx - 5 + i * 3.0;
      final length = 12 + (i * 7) % 11;
      for (var k = 0; k < length; k += 2) {
        g.rect(
          vx + ((k ~/ 2).isEven ? 1 : 0),
          hook.dy + 10 + k,
          2,
          2,
          Tone.greens[(i + k ~/ 2) % 3],
        );
      }
    }
  }

  void _backWall() {
    const frame = Color(0xFF22262A);
    // Cloison vitrée.
    for (var x = 0.0; x < 12; x += 3) {
      g
        ..wallX(x + 0.1, x + 2.9, 0, 4, 58, const Color(0x3D6FA0A8))
        ..quad(
          Iso.pt(x + 0.5, 0, 58),
          Iso.pt(x + 1, 0, 58),
          Iso.pt(x + 0.5, 0, 22),
          Iso.pt(x + 0.1, 0, 30),
          const Color(0x24FFFFFF),
        )
        ..quad(
          Iso.pt(x + 1.5, 0, 58),
          Iso.pt(x + 1.7, 0, 58),
          Iso.pt(x + 1, 0, 12),
          Iso.pt(x + 0.8, 0, 12),
          const Color(0x18FFFFFF),
        );
    }
    for (var x = 0.0; x <= 12; x += 3) {
      g.wallX(x - 0.09, x + 0.09, 0, 0, 62, frame);
    }
    g
      ..wallX(0, 12, 0, 58, 62, frame)
      ..wallX(0, 12, 0, 0, 4, frame)
      ..floor(0, -0.25, 12, 0, const Color(0xFF3A4046), 62);

    // Mur plein, vert-de-gris.
    g
      ..wallX(12, 35, 0, 0, 78, const Color(0xFF465350))
      ..wallX(12, 35, 0, 62, 78, const Color(0xFF4E5C58))
      ..wallX(12, 35, 0, 0, 4, const Color(0xFF2A322F))
      ..floor(12, -0.4, 35, 0, const Color(0xFF67756F), 78)
      ..wallY(-0.4, 0, 12, 0, 78, const Color(0xFF39433F));
  }

  // -------------------------------------------------------------- mobilier

  void _furniture() {
    // Poste de Forge, contre la cloison vitrée.
    _add(8.1, () {
      desk(4, 0.6, 9, 2.6);
      monitor(6.2, 1.2, w: 1.9);
      keyboard(6.2, 1.9);
      deskLamp(Iso.pt(4.5, 1.1, 22));
      binders(7.9, 1);
      mug(Iso.pt(5, 2.1, 22));
      g.floor(7.5, 1.8, 8.2, 2.3, const Color(0xFF2F3238), 22.5);
    });
    _add(11.4, () => palm(Iso.pt(10.4, 0.9), seed: 3, size: 15));
    _add(4.6, () => palm(Iso.pt(3.3, 0.9), seed: 9, size: 11));

    // Grand plan de travail partagé.
    _add(13.4, () {
      desk(2.5, 6.4, 9.5, 8.4);
      monitorBack(4, 6.9);
      monitorBack(7.6, 6.9);
      monitor(5.8, 7.2, seed: 2);
      keyboard(5.8, 7.9);
      mug(Iso.pt(3.3, 7.8, 22));
      mug(Iso.pt(8.6, 7.9, 22));
      deskLamp(Iso.pt(2.9, 6.9, 22));
      smallPlant(Iso.pt(9.1, 7.2, 22));
      g
        ..floor(7.1, 7.6, 7.9, 8.1, Tone.white, 22.5)
        ..floor(4.3, 7.7, 4.9, 8.1, const Color(0xFFD9D4C6), 22.5);
    });

    // Coin café, le long du mur.
    _add(8.4, () {
      g
        ..solid(0.1, 6.5, 1.3, 8.3, 0, 20, const Color(0xFF9A6A3C))
        ..floor(0.1, 6.5, 1.3, 8.3, const Color(0xFFC4B8A4), 20.5)
        ..solid(0.25, 6.8, 1.05, 7.6, 20.5, 39, const Color(0xFF30333A))
        ..wallX(0.4, 0.9, 7.6, 26, 33, const Color(0xFF15171B))
        ..wallX(0.55, 0.75, 7.6, 21, 25, Tone.white)
        ..wallX(0.4, 0.5, 7.6, 35, 37, const Color(0xFFE2574A))
        ..solid(0.3, 7.8, 0.9, 8.2, 20.5, 25, Tone.white);
    });
    _add(9.8, () => waterCooler(0.3, 8.5));

    // Table haute et tabourets.
    _add(19.6, () {
      final top = Iso.pt(6.2, 13.2, 26);
      g
        ..oval(Iso.pt(6.4, 13.4), 15, 7, const Color(0x59000000))
        ..rect(top.dx - 1, top.dy, 3, 25, Tone.metalLight)
        ..oval(Iso.pt(6.2, 13.2), 6, 3, Tone.metal)
        ..rect(top.dx - 17, top.dy - 1, 34, 3, Tone.deskEdge)
        ..oval(top + const Offset(0, 2), 17, 8, Tone.deskEdge)
        ..oval(top, 17, 8, Tone.deskTop);
      mug(top + const Offset(-6, 1));
      mug(top + const Offset(7, -1));
    });
    for (final stool in <Offset>[
      const Offset(4.9, 14.1),
      const Offset(7.6, 14.3),
    ]) {
      _add(Iso.depth(stool.dx, stool.dy), () {
        final seat = Iso.pt(stool.dx, stool.dy, 15);
        g
          ..rect(seat.dx - 1, seat.dy, 2, 14, Tone.woodDark)
          ..rect(seat.dx - 4, seat.dy + 9, 8, 1, Tone.woodDark)
          ..oval(seat, 6, 3, Tone.deskTop);
      });
    }

    // Cloison grise, tableau roulant, bibliothèque basse.
    _add(18.6, () {
      g.box(
        10.8,
        5.3,
        15.4,
        5.5,
        0,
        52,
        top: const Color(0xFF7C8682),
        left: const Color(0xFF59625F),
        right: const Color(0xFF3F4744),
      );
    });
    _add(19.9, () => rollingBoard(11.9, 15.1, 6.3));
    _add(20.6, () {
      bookshelf(10.2, 8.4, 13.4, h: 42, shelves: 3, seed: 4);
      smallPlant(Iso.pt(10.8, 8.8, 42), big: true);
      smallPlant(Iso.pt(12.7, 8.8, 42));
      g.solid(11.5, 8.6, 12, 9, 42, 46, const Color(0xFF3F5F8A));
    });
    _add(19.4, () => palm(Iso.pt(9.5, 9.4), seed: 6, size: 13));

    // Baie de serveurs.
    _add(21.4, () => serverRack(15.7, 3.2, 17.7, 5.2));

    // Rayonnages hauts contre le mur du fond.
    _add(13.8, () => bookshelf(12.6, 0.1, 15.7, seed: 7));
    _add(17.3, () => bookshelf(16, 0.1, 19, seed: 8));
    _add(20.7, () {
      bookshelf(19.3, 0.1, 21.5, h: 38, shelves: 3, seed: 9);
      smallPlant(Iso.pt(19.8, 0.5, 38), big: true);
      g
        ..solid(20.6, 0.4, 20.9, 0.7, 38, 45, const Color(0xFFD8C8A0))
        ..solid(21, 0.4, 21.3, 0.7, 38, 42, const Color(0xFFB04A3A));
    });
    _add(22.4, _vendingMachine);
    _add(20.9, () {
      final bin = Iso.pt(19.2, 1.8);
      g
        ..oval(bin + const Offset(1, 1), 6, 3, const Color(0x59000000))
        ..rect(bin.dx - 5, bin.dy - 12, 10, 12, const Color(0xFF2B2E33))
        ..oval(bin, 5, 2.5, const Color(0xFF2B2E33))
        ..oval(bin + const Offset(0, -12), 5, 2.5, const Color(0xFF15171A));
    });

    // Table ronde et ses fauteuils.
    _chairItem(23.6, 5.2, 1);
    _chairItem(25.9, 5.9, 1);
    _chairItem(21, 7.4, 0);
    _add(31.8, () => roundTable(23.8, 8, 2.1));
    _chairItem(26.8, 8.6, 2);
    _chairItem(25.6, 10.6, 3);
    _chairItem(22.9, 10.9, 3);

    // Portemanteau.
    _add(33.6, () {
      final foot = Iso.pt(19.7, 13.9);
      g
        ..oval(foot + const Offset(1, 1), 8, 3, const Color(0x59000000))
        ..rect(foot.dx - 6, foot.dy - 1, 13, 2, Tone.woodDark)
        ..rect(foot.dx - 1, foot.dy - 46, 2, 46, const Color(0xFF8A5A33))
        ..rect(foot.dx - 6, foot.dy - 40, 12, 1, const Color(0xFF8A5A33))
        ..rect(foot.dx - 6, foot.dy - 42, 1, 3, const Color(0xFF8A5A33))
        ..rect(foot.dx + 5, foot.dy - 42, 1, 3, const Color(0xFF8A5A33))
        ..rect(foot.dx - 6, foot.dy - 54, 12, 8, const Color(0xFFC98A5A))
        ..rect(foot.dx - 8, foot.dy - 48, 16, 2, const Color(0xFFA86E44))
        ..rect(foot.dx + 3, foot.dy - 39, 4, 14, const Color(0xFF3F5F8A));
    });

    // Bureau du bas, à gauche.
    _add(35.2, () {
      desk(14.5, 16.8, 19.5, 18.8);
      monitor(16.1, 17.4, seed: 1);
      keyboard(16.1, 18.1);
      deskLamp(Iso.pt(17.6, 17.2, 22));
      g
        ..solid(18.2, 17.2, 18.9, 17.9, 22, 30, const Color(0xFF8F9396))
        ..wallX(18.3, 18.8, 17.9, 24, 28, const Color(0xFF55595E))
        ..floor(17.1, 18, 17.9, 18.5, Tone.white, 22.5);
      mug(Iso.pt(15, 18.3, 22));
    });
    _chairItem(16.3, 19.8, 3, color: Tone.chairDark);
    _add(34.4, () {
      g
        ..solid(14, 19.6, 14.6, 20.3, 0, 13, const Color(0xFF2E4468))
        ..wallX(14.1, 14.5, 20.3, 3, 8, const Color(0xFF3F5F8A));
    });
    _add(31.4, () => waterCooler(12.2, 18.5));

    // Bureau du bas, au centre.
    _add(42.2, () {
      desk(21.5, 16.4, 27.5, 18.4);
      monitor(24, 17, seed: 3);
      monitor(25.8, 17.1, seed: 5);
      keyboard(24, 17.8);
      keyboard(25.8, 17.9);
      deskLamp(Iso.pt(22, 17.8, 22));
      deskLamp(Iso.pt(27, 16.9, 22));
      smallPlant(Iso.pt(27.1, 17.8, 22));
      g
        ..solid(26.4, 17.6, 26.8, 18.2, 22, 26, const Color(0xFF8A3A32))
        ..solid(26.45, 17.65, 26.8, 18.15, 26, 29, const Color(0xFFC08A3A));
    });

    // Panneau d'accueil et cloison vitrée de l'entrée.
    _add(27, () {
      const frame = Color(0xFF22262A);
      g.wallY(14.2, 18.1, 11, 4, 56, const Color(0x336FA0A8));
      for (final y in <double>[14.2, 16.15, 18.1]) {
        g.wallY(y - 0.08, y + 0.08, 11, 0, 60, frame);
      }
      g
        ..wallY(14.2, 18.1, 11, 56, 60, frame)
        ..wallY(14.2, 18.1, 11, 0, 4, frame);
    });
    _add(29.6, _welcomePanel);
    _add(33.2, () => palm(Iso.pt(12.7, 20.5), seed: 12, size: 16));

    // Salon d'attente et fontaine, en bas.
    _add(39.4, () => armchair(16.3, 22.8));
    _add(41.9, () => armchair(18.1, 23.6));
    _add(42.6, () => waterCooler(20.1, 21.9));
    _add(41.2, () {
      final foot = Iso.pt(26.5, 14.6);
      g
        ..oval(foot, 5, 2.5, Tone.metal)
        ..rect(foot.dx - 1, foot.dy - 34, 1, 34, Tone.metalLight)
        ..rect(foot.dx - 5, foot.dy - 40, 10, 6, const Color(0xFFD8A24A))
        ..rect(foot.dx - 4, foot.dy - 34, 8, 1, const Color(0xFFFFE9A8));
      glows.add(Glow(foot + const Offset(0, -30), 46, Tone.lampGlow));
    });
  }

  void _chairItem(
    double x,
    double y,
    int back, {
    Color color = Tone.chairGrey,
  }) {
    _add(Iso.depth(x, y), () => chair(x, y, back: back, color: color));
  }

  void _vendingMachine() {
    const x0 = 21.8;
    const x1 = 23.2;
    const y1 = 1.2;
    g
      ..box(
        x0,
        0.1,
        x1,
        y1,
        0,
        58,
        top: const Color(0xFF3A3F47),
        left: const Color(0xFF1E2126),
        right: const Color(0xFF121418),
      )
      ..wallX(x0 + 0.12, x1 - 0.4, y1, 14, 54, const Color(0xFF16323A));
    const drinks = <Color>[
      Color(0xFFE2574A),
      Color(0xFF4A8AD8),
      Color(0xFF56A65A),
      Color(0xFFF2C14E),
    ];
    for (var row = 0; row < 4; row++) {
      for (var k = 0; k < 4; k++) {
        final xs = x0 + 0.2 + k * 0.2;
        final z = 18.0 + row * 9;
        g.wallX(xs, xs + 0.13, y1, z, z + 6, drinks[(row + k) % drinks.length]);
      }
    }
    g.wallX(x0 + 0.12, x1 - 0.4, y1, 4, 10, const Color(0xFF0D0E11));
    glows.add(Glow(Iso.pt(22.3, 1.8, 30), 30, const Color(0x2E6FD0E0)));
  }

  /// Panneau d'accueil, avec le monogramme de LeadDesk (création originale).
  void _welcomePanel() {
    const x = 11.0;
    const mark = Color(0xFF7A4A2A);
    const paper = Color(0xFFD9C8A9);
    g
      ..box(
        10.75,
        18.2,
        x,
        24.6,
        0,
        66,
        top: const Color(0xFFE6D8BE),
        left: const Color(0xFFB09C7E),
        right: paper,
      )
      ..wallY(18.2, 24.6, x, 0, 4, const Color(0xFF8C7A60));
    // Monogramme : un « L » dans un carré.
    g
      ..wallY(19.4, 20.8, x, 36, 54, mark)
      ..wallY(19.55, 20.65, x, 38, 52, paper)
      ..wallY(19.75, 20, x, 41, 50, mark)
      ..wallY(19.75, 20.45, x, 41, 44, mark);
    // Nom en lettres stylisées, sous le monogramme.
    for (var i = 0; i < 8; i++) {
      final y = 18.85 + i * 0.3;
      g.wallY(y, y + 0.2, x, 26, 31, mark);
      if (i.isEven) {
        g.wallY(y + 0.06, y + 0.14, x, 27.5, 29.5, paper);
      }
    }
  }

  // ----------------------------------------------------------- personnages

  void _people() {
    // Forge, de dos, devant son écran.
    final forge = OfficeLayout.forgeSeat;
    _add(9.5, () {
      g
        ..oval(forge + const Offset(1, 1), 9, 4, const Color(0x59000000))
        ..rect(forge.dx - 6, forge.dy - 1, 12, 2, Tone.metal)
        ..rect(forge.dx - 1, forge.dy - 9, 2, 9, Tone.metalLight)
        ..solid(5.7, 2.8, 6.7, 3.8, 9, 12, Tone.chairDark);
      drawPerson(
        canvas,
        forge + const Offset(0, -8),
        OfficeLooks.forge,
        pose: PersonPose.seated,
        back: true,
        raiseArm: true,
      );
      // Dossier du fauteuil, par-dessus le buste.
      final rest = Iso.pt(6.2, 3.8, 12);
      g
        ..rect(rest.dx - 8, rest.dy - 19, 16, 18, const Color(0xFF1F2126))
        ..rect(rest.dx - 7, rest.dy - 20, 14, 1, const Color(0xFF1F2126))
        ..rect(rest.dx - 6, rest.dy - 17, 12, 1, const Color(0xFF34373E));
    });

    // Plan de travail partagé : deux agents de face, un de dos.
    _seatedFront(
      4,
      5.7,
      const PersonLook(
        skin: Color(0xFFA9714B),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFFE9E2D0),
        tie: Color(0xFFB8402F),
      ),
    );
    _seatedFront(
      7.6,
      5.7,
      const PersonLook(
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF3B2A22),
        top: Color(0xFF8A5A3A),
      ),
      faceLeft: true,
    );
    _add(14.9, () {
      final seat = Iso.pt(5.8, 9.2);
      g
        ..oval(seat + const Offset(1, 1), 9, 4, const Color(0x59000000))
        ..rect(seat.dx - 6, seat.dy - 1, 12, 2, Tone.metal)
        ..rect(seat.dx - 1, seat.dy - 9, 2, 9, Tone.metalLight);
      drawPerson(
        canvas,
        seat + const Offset(0, -8),
        const PersonLook(
          skin: Color(0xFFEBC29A),
          hair: Color(0xFF2B1F1C),
          top: Color(0xFFDCD6C8),
        ),
        pose: PersonPose.seated,
        back: true,
      );
      final rest = Iso.pt(5.8, 9.7, 12);
      g
        ..rect(rest.dx - 8, rest.dy - 17, 16, 16, const Color(0xFF3A3024))
        ..rect(rest.dx - 6, rest.dy - 15, 12, 1, const Color(0xFF54463A));
    });

    // Coin café.
    _standing(
      5.3,
      12.2,
      const PersonLook(
        skin: Color(0xFFA9714B),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFF8A5AA8),
        longHair: true,
      ),
      mug: true,
    );
    _standing(
      7.5,
      12.6,
      const PersonLook(
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF4A2E1E),
        top: Color(0xFF6B7078),
        longHair: true,
      ),
      faceLeft: true,
      mug: true,
    );
    _standing(
      9.2,
      14.3,
      const PersonLook(
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFF3F6B4A),
      ),
      faceLeft: true,
    );

    // Atlas et Quill, en pleine passation près de la table ronde.
    _add(31.2, () {
      drawPerson(
        canvas,
        OfficeLayout.atlasFeet,
        OfficeLooks.atlas,
        raiseArm: frame.isOdd,
      );
    });
    _add(31.4, () {
      drawPerson(
        canvas,
        OfficeLayout.quillFeet,
        OfficeLooks.quill,
        faceLeft: true,
        raiseArm: frame == 2,
      );
    });

    // Groupe près des rayonnages : Scout lit, deux collègues discutent.
    _add(23.6, () {
      drawPerson(
        canvas,
        OfficeLayout.scoutFeet,
        OfficeLooks.scout,
        faceLeft: true,
        paper: true,
      );
    });
    _standing(
      20.1,
      3,
      const PersonLook(
        skin: Color(0xFFA9714B),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFF3F8A5A),
      ),
      raise: frame == 1,
    );
    _standing(
      21.9,
      3.7,
      const PersonLook(
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF8A6A4A),
        top: Color(0xFF9A6A4A),
        pants: Color(0xFF4A4038),
      ),
      faceLeft: true,
      back: true,
    );

    // Bureau du bas, à gauche : deux collègues debout.
    _standing(
      13.3,
      17.1,
      const PersonLook(
        skin: Color(0xFFA9714B),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFF8A5AA8),
        longHair: true,
      ),
      mug: true,
    );
    _standing(
      14,
      16.2,
      const PersonLook(
        skin: Color(0xFFEBC29A),
        hair: Color(0xFFC96A32),
        top: Color(0xFF3F6B4A),
      ),
    );

    // Bureau du bas, au centre : un agent à lunettes.
    _seatedFront(
      22.4,
      15.7,
      const PersonLook(
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF9A9A9A),
        top: Color(0xFF8A3A32),
        glasses: true,
      ),
    );
  }

  void _standing(
    double x,
    double y,
    PersonLook look, {
    bool faceLeft = false,
    bool back = false,
    bool mug = false,
    bool raise = false,
  }) {
    _add(Iso.depth(x, y), () {
      drawPerson(
        canvas,
        Iso.pt(x, y),
        look,
        faceLeft: faceLeft,
        back: back,
        mug: mug,
        raiseArm: raise,
      );
    });
  }

  /// Agent assis face à la caméra, derrière son bureau.
  void _seatedFront(
    double x,
    double y,
    PersonLook look, {
    bool faceLeft = false,
  }) {
    _add(Iso.depth(x, y), () {
      g.solid(x - 0.5, y - 0.6, x + 0.5, y - 0.45, 11, 30, Tone.chairDark);
      drawPerson(
        canvas,
        Iso.pt(x, y, 8),
        look,
        pose: PersonPose.seated,
        faceLeft: faceLeft,
      );
    });
  }

  // -------------------------------------------------------------- lumières

  void _lighting() {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final glow in glows) {
      paint.shader = ui.Gradient.radial(glow.center, glow.radius, <Color>[
        glow.color,
        glow.color.withValues(alpha: 0),
      ]);
      canvas.drawCircle(glow.center, glow.radius, paint);
    }
    // Pénombre des bords : le regard reste au centre de la pièce.
    const center = Offset(sceneWidth / 2, sceneHeight / 2);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, sceneWidth, sceneHeight),
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          sceneWidth * 0.72,
          const <Color>[
            Color(0x00000000),
            Color(0x00000000),
            Color(0x8C000000),
          ],
          const <double>[0, 0.55, 1],
        ),
    );
  }
}
