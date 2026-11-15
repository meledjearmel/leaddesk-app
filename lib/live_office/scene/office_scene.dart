import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

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

class _Glow {
  const _Glow(this.center, this.radius, this.color);

  final Offset center;
  final double radius;
  final Color color;
}

// Bois, métal et tissus.
const Color _deskTop = Color(0xFFB8824A);
const Color _deskEdge = Color(0xFF8C5C31);
const Color _deskEdgeDark = Color(0xFF6C4425);
const Color _woodDark = Color(0xFF7A4E2B);
const Color _shelfWood = Color(0xFF7B4D2A);
const Color _shelfTop = Color(0xFF8E5C33);
const Color _shelfSide = Color(0xFF4A2C18);
const Color _metal = Color(0xFF24272C);
const Color _metalLight = Color(0xFF4A4F57);
const Color _chairDark = Color(0xFF2A2C33);
const Color _chairGrey = Color(0xFF5E636B);
const Color _white = Color(0xFFF1EEE6);
const Color _screenGreen = Color(0xFF6DF5B0);
const Color _amber = Color(0xFFF2C14E);
const Color _lampGlow = Color(0x66FFC46B);

const List<Color> _books = <Color>[
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

const List<Color> _greens = <Color>[
  Color(0xFF2F6B3A),
  Color(0xFF3F8A4A),
  Color(0xFF56A65A),
  Color(0xFF245230),
];

/// Dessine le bureau : décor, mobilier, personnages à leur poste, lumières.
///
/// Tout est dessiné par le code, sans lissage, à la résolution d'art. Le
/// mobilier et les personnages sont triés par profondeur avant d'être peints.
class OfficeScenePainter {
  OfficeScenePainter(this.canvas, this.frame) : g = Iso(canvas);

  final ui.Canvas canvas;
  final int frame;
  final Iso g;

  final List<_Item> _items = <_Item>[];
  final List<_Glow> _glows = <_Glow>[];

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
      ..solid(4, -4.8, 4.5, -3.6, 0, 14, _woodDark)
      ..solid(7.5, -4.8, 8, -3.6, 0, 14, _woodDark)
      ..box(
        3.4,
        -5.4,
        8.6,
        -3.1,
        14,
        17,
        top: _deskTop,
        left: _deskEdge,
        right: _deskEdgeDark,
      )
      ..floor(5.2, -4.7, 6, -4.1, _white, 17.5)
      ..floor(6.6, -4.5, 7.3, -3.8, const Color(0xFF3A3D42), 17.5);
    _chair(4.6, -6.1, back: 1, color: _chairDark);
    _chair(7.2, -6.1, back: 1, color: _chairDark);
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
    _chair(5.6, -2.2, back: 3, color: _chairDark);
    _chair(7.6, -2.2, back: 3, color: _chairDark);
    // Voile bleu nuit : la salle est vue à travers la vitre.
    g.floor(0, -14, 12, 0, const Color(0x8C070B10));
    _bookshelf(10, -6.6, 13, seed: 21, h: 82);
    _bookshelf(13.3, -6.6, 16.6, seed: 22, h: 82);
    _glows.add(_Glow(Iso.pt(13.2, -5, 40), 60, const Color(0x40FFC46B)));
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
      ..wallY(6.8, 7.15, 0.02, 44, 52, _white);

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
          _greens[(i + k ~/ 2) % 3],
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
      _desk(4, 0.6, 9, 2.6);
      _monitor(6.2, 1.2, w: 1.9);
      _keyboard(6.2, 1.9);
      _deskLamp(Iso.pt(4.5, 1.1, 22));
      _binders(7.9, 1);
      _mug(Iso.pt(5, 2.1, 22));
      g.floor(7.5, 1.8, 8.2, 2.3, const Color(0xFF2F3238), 22.5);
    });
    _add(11.4, () => _palm(Iso.pt(10.4, 0.9), seed: 3, size: 15));
    _add(4.6, () => _palm(Iso.pt(3.3, 0.9), seed: 9, size: 11));

    // Grand plan de travail partagé.
    _add(13.4, () {
      _desk(2.5, 6.4, 9.5, 8.4);
      _monitorBack(4, 6.9);
      _monitorBack(7.6, 6.9);
      _monitor(5.8, 7.2, seed: 2);
      _keyboard(5.8, 7.9);
      _mug(Iso.pt(3.3, 7.8, 22));
      _mug(Iso.pt(8.6, 7.9, 22));
      _deskLamp(Iso.pt(2.9, 6.9, 22));
      _smallPlant(Iso.pt(9.1, 7.2, 22));
      g
        ..floor(7.1, 7.6, 7.9, 8.1, _white, 22.5)
        ..floor(4.3, 7.7, 4.9, 8.1, const Color(0xFFD9D4C6), 22.5);
    });

    // Coin café, le long du mur.
    _add(8.4, () {
      g
        ..solid(0.1, 6.5, 1.3, 8.3, 0, 20, const Color(0xFF9A6A3C))
        ..floor(0.1, 6.5, 1.3, 8.3, const Color(0xFFC4B8A4), 20.5)
        ..solid(0.25, 6.8, 1.05, 7.6, 20.5, 39, const Color(0xFF30333A))
        ..wallX(0.4, 0.9, 7.6, 26, 33, const Color(0xFF15171B))
        ..wallX(0.55, 0.75, 7.6, 21, 25, _white)
        ..wallX(0.4, 0.5, 7.6, 35, 37, const Color(0xFFE2574A))
        ..solid(0.3, 7.8, 0.9, 8.2, 20.5, 25, _white);
    });
    _add(9.8, () => _waterCooler(0.3, 8.5));

    // Table haute et tabourets.
    _add(19.6, () {
      final top = Iso.pt(6.2, 13.2, 26);
      g
        ..oval(Iso.pt(6.4, 13.4), 15, 7, const Color(0x59000000))
        ..rect(top.dx - 1, top.dy, 3, 25, _metalLight)
        ..oval(Iso.pt(6.2, 13.2), 6, 3, _metal)
        ..rect(top.dx - 17, top.dy - 1, 34, 3, _deskEdge)
        ..oval(top + const Offset(0, 2), 17, 8, _deskEdge)
        ..oval(top, 17, 8, _deskTop);
      _mug(top + const Offset(-6, 1));
      _mug(top + const Offset(7, -1));
    });
    for (final stool in <Offset>[
      const Offset(4.9, 14.1),
      const Offset(7.6, 14.3),
    ]) {
      _add(Iso.depth(stool.dx, stool.dy), () {
        final seat = Iso.pt(stool.dx, stool.dy, 15);
        g
          ..rect(seat.dx - 1, seat.dy, 2, 14, _woodDark)
          ..rect(seat.dx - 4, seat.dy + 9, 8, 1, _woodDark)
          ..oval(seat, 6, 3, _deskTop);
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
    _add(19.9, () => _rollingBoard(11.9, 15.1, 6.3));
    _add(20.6, () {
      _bookshelf(10.2, 8.4, 13.4, h: 42, shelves: 3, seed: 4);
      _smallPlant(Iso.pt(10.8, 8.8, 42), big: true);
      _smallPlant(Iso.pt(12.7, 8.8, 42));
      g.solid(11.5, 8.6, 12, 9, 42, 46, const Color(0xFF3F5F8A));
    });
    _add(19.4, () => _palm(Iso.pt(9.5, 9.4), seed: 6, size: 13));

    // Baie de serveurs.
    _add(21.4, () => _serverRack(15.7, 3.2, 17.7, 5.2));

    // Rayonnages hauts contre le mur du fond.
    _add(13.8, () => _bookshelf(12.6, 0.1, 15.7, seed: 7));
    _add(17.3, () => _bookshelf(16, 0.1, 19, seed: 8));
    _add(20.7, () {
      _bookshelf(19.3, 0.1, 21.5, h: 38, shelves: 3, seed: 9);
      _smallPlant(Iso.pt(19.8, 0.5, 38), big: true);
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
    _add(31.8, () => _roundTable(23.8, 8, 2.1));
    _chairItem(26.8, 8.6, 2);
    _chairItem(25.6, 10.6, 3);
    _chairItem(22.9, 10.9, 3);

    // Portemanteau.
    _add(33.6, () {
      final foot = Iso.pt(19.7, 13.9);
      g
        ..oval(foot + const Offset(1, 1), 8, 3, const Color(0x59000000))
        ..rect(foot.dx - 6, foot.dy - 1, 13, 2, _woodDark)
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
      _desk(14.5, 16.8, 19.5, 18.8);
      _monitor(16.1, 17.4, seed: 1);
      _keyboard(16.1, 18.1);
      _deskLamp(Iso.pt(17.6, 17.2, 22));
      g
        ..solid(18.2, 17.2, 18.9, 17.9, 22, 30, const Color(0xFF8F9396))
        ..wallX(18.3, 18.8, 17.9, 24, 28, const Color(0xFF55595E))
        ..floor(17.1, 18, 17.9, 18.5, _white, 22.5);
      _mug(Iso.pt(15, 18.3, 22));
    });
    _chairItem(16.3, 19.8, 3, color: _chairDark);
    _add(34.4, () {
      g
        ..solid(14, 19.6, 14.6, 20.3, 0, 13, const Color(0xFF2E4468))
        ..wallX(14.1, 14.5, 20.3, 3, 8, const Color(0xFF3F5F8A));
    });
    _add(31.4, () => _waterCooler(12.2, 18.5));

    // Bureau du bas, au centre.
    _add(42.2, () {
      _desk(21.5, 16.4, 27.5, 18.4);
      _monitor(24, 17, seed: 3);
      _monitor(25.8, 17.1, seed: 5);
      _keyboard(24, 17.8);
      _keyboard(25.8, 17.9);
      _deskLamp(Iso.pt(22, 17.8, 22));
      _deskLamp(Iso.pt(27, 16.9, 22));
      _smallPlant(Iso.pt(27.1, 17.8, 22));
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
    _add(33.2, () => _palm(Iso.pt(12.7, 20.5), seed: 12, size: 16));

    // Salon d'attente et fontaine, en bas.
    _add(39.4, () => _armchair(16.3, 22.8));
    _add(41.9, () => _armchair(18.1, 23.6));
    _add(42.6, () => _waterCooler(20.1, 21.9));
    _add(41.2, () {
      final foot = Iso.pt(26.5, 14.6);
      g
        ..oval(foot, 5, 2.5, _metal)
        ..rect(foot.dx - 1, foot.dy - 34, 1, 34, _metalLight)
        ..rect(foot.dx - 5, foot.dy - 40, 10, 6, const Color(0xFFD8A24A))
        ..rect(foot.dx - 4, foot.dy - 34, 8, 1, const Color(0xFFFFE9A8));
      _glows.add(_Glow(foot + const Offset(0, -30), 46, _lampGlow));
    });
  }

  void _chairItem(double x, double y, int back, {Color color = _chairGrey}) {
    _add(Iso.depth(x, y), () => _chair(x, y, back: back, color: color));
  }

  void _desk(double x0, double y0, double x1, double y1) {
    g.floor(x0 + 0.3, y0 + 0.3, x1 + 0.4, y1 + 0.5, const Color(0x66000000));
    const line = Color(0xFF55331B);
    const brass = Color(0xFFD9B36A);
    for (final xs in <double>[x0 + 0.15, x1 - 1.4]) {
      final face = y1 - 0.2;
      g
        ..solid(xs, y0 + 0.2, xs + 1.25, face, 0, 19, _woodDark)
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
        top: _deskTop,
        left: _deskEdge,
        right: _deskEdgeDark,
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
  void _monitor(double x, double y, {double w = 1.6, int seed = 0}) {
    const z = 22.0;
    g
      ..floor(x - 0.35, y - 0.1, x + 0.35, y + 0.3, _metal, z + 0.5)
      ..wallX(x - 0.08, x + 0.08, y, z, z + 6, _metalLight)
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
          ? _amber
          : (row == 0 ? const Color(0xFFD8F7E8) : _screenGreen);
      g.wallX(start, start + lengths[row] * usable, y, zz - 1.3, zz, color);
    }
    // Curseur clignotant.
    if (frame.isEven) {
      g.wallX(x + w / 2 - 0.4, x + w / 2 - 0.3, y, z + 8, z + 10, _white);
    }
    _glows.add(_Glow(Iso.pt(x, y + 0.6, z + 14), 26, const Color(0x335CF2A6)));
  }

  /// Écran vu de dos : son utilisateur fait face à la caméra.
  void _monitorBack(double x, double y, {double w = 1.6}) {
    const z = 22.0;
    g
      ..floor(x - 0.35, y - 0.1, x + 0.35, y + 0.3, _metal, z + 0.5)
      ..wallX(x - 0.08, x + 0.08, y + 0.15, z, z + 6, _metalLight)
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
    _glows.add(_Glow(Iso.pt(x, y - 0.7, z + 16), 18, const Color(0x265CF2A6)));
  }

  void _keyboard(double x, double y) {
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

  void _mug(Offset at) {
    g
      ..rect(at.dx - 2, at.dy - 4, 4, 4, _white)
      ..rect(at.dx - 1, at.dy - 4, 2, 1, const Color(0xFF6B4A32))
      ..rect(at.dx + 2, at.dy - 3, 1, 2, _white);
  }

  void _binders(double x, double y) {
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
        ..wallX(xs + 0.04, xs + 0.14, y + 0.3, 28, 32, _white);
    }
  }

  void _deskLamp(Offset base) {
    g
      ..rect(base.dx - 2, base.dy - 2, 5, 2, _metal)
      ..rect(base.dx, base.dy - 13, 1, 11, _metalLight)
      ..rect(base.dx, base.dy - 14, 6, 1, _metalLight)
      ..rect(base.dx + 3, base.dy - 14, 7, 4, const Color(0xFFD8A24A))
      ..rect(base.dx + 4, base.dy - 10, 5, 1, const Color(0xFFFFE9A8));
    _glows.add(_Glow(base + const Offset(6, -7), 34, _lampGlow));
  }

  void _fronds(Offset center, int count, double length, Random random) {
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
          _greens[(i + t ~/ 4) % _greens.length],
        );
      }
    }
  }

  /// Grande plante en pot posée au sol.
  void _palm(Offset base, {required int seed, double size = 14}) {
    g
      ..oval(base + const Offset(1, 1), 8, 3.5, const Color(0x59000000))
      ..rect(base.dx - 5, base.dy - 9, 10, 9, const Color(0xFFB8643C))
      ..rect(base.dx - 6, base.dy - 10, 12, 2, const Color(0xFFD07A4C))
      ..rect(base.dx + 2, base.dy - 8, 3, 8, const Color(0xFF8E4A2C))
      ..rect(base.dx - 1, base.dy - 17, 2, 8, _greens[3]);
    _fronds(base + const Offset(0, -17), 9, size, Random(seed));
  }

  /// Petite plante posée sur un meuble.
  void _smallPlant(Offset base, {bool big = false}) {
    g
      ..rect(base.dx - 3, base.dy - 5, 6, 5, _white)
      ..rect(base.dx + 1, base.dy - 5, 2, 5, const Color(0xFFCFCABD));
    _fronds(
      base + const Offset(0, -6),
      big ? 7 : 5,
      big ? 9 : 6,
      Random(base.dx.toInt()),
    );
  }

  void _bookshelf(
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
        top: _shelfTop,
        left: const Color(0xFF22140C),
        right: _shelfSide,
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
            _books[random.nextInt(_books.length)],
          );
          x += width + 0.02;
        }
      }
      g.wallX(x0, x1, y1, zb - 3, zb, _shelfWood);
    }
    g
      ..wallX(x0, x0 + 0.1, y1, 0, h, _shelfWood)
      ..wallX(x1 - 0.1, x1, y1, 0, h, _shelfWood)
      ..wallX(x0, x1, y1, h - 3, h, _shelfWood);
  }

  void _serverRack(double x0, double y0, double x1, double y1) {
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
            : (k == 5 && unit.isOdd ? _amber : const Color(0xFF4DF58C));
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
    _glows.add(
      _Glow(Iso.pt((x0 + x1) / 2, y1 + 0.5, 34), 34, const Color(0x2E4DF58C)),
    );
  }

  void _rollingBoard(double x0, double x1, double y) {
    for (final xs in <double>[x0 + 0.15, x1 - 0.15]) {
      g
        ..floor(xs - 0.12, y - 0.45, xs + 0.12, y + 0.45, _metal, 1)
        ..wallX(xs - 0.06, xs + 0.06, y, 0, 16, _metalLight);
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

  void _roundTable(double cx, double cy, double radius) {
    const z = 15.0;
    final foot = Iso.pt(cx, cy);
    final top = Iso.pt(cx, cy, z);
    final rw = radius * Iso.halfTileWidth * sqrt2;
    final rh = radius * Iso.halfTileHeight * sqrt2;
    g
      ..oval(foot + const Offset(3, 3), rw, rh, const Color(0x66000000))
      ..oval(foot, 9, 4, _shelfSide)
      ..rect(foot.dx - 3, foot.dy - z, 6, z, _shelfSide)
      ..oval(top + const Offset(0, 3), rw, rh, _deskEdge)
      ..rect(top.dx - rw, top.dy, rw * 2, 3, _deskEdge)
      ..oval(top, rw, rh, _deskTop)
      ..oval(top, rw - 4, rh - 2, const Color(0xFFC08A50))
      ..oval(top, rw - 6, rh - 3, _deskTop);
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
      ..floor(cx - 0.9, cy + 0.6, cx - 0.3, cy + 1.2, _white, z + 0.5)
      ..solid(
        cx - 0.15,
        cy - 0.15,
        cx + 0.15,
        cy + 0.15,
        z,
        z + 5,
        const Color(0xFF6E8A6A),
      )
      ..rect(top.dx - 1, top.dy - 9, 1, 4, _amber)
      ..rect(top.dx + 1, top.dy - 8, 1, 3, const Color(0xFFE2574A));
  }

  /// Fauteuil de bureau. [back] indique le côté du dossier : 0 = x décroissant,
  /// 1 = y décroissant, 2 = x croissant, 3 = y croissant.
  void _chair(double x, double y, {required int back, required Color color}) {
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
      ..rect(foot.dx - 6, foot.dy - 1, 12, 2, _metal)
      ..rect(foot.dx - 1, foot.dy - 9, 2, 9, _metalLight);
    if (back < 2) {
      backrest();
    }
    g.solid(x - 0.45, y - 0.45, x + 0.45, y + 0.45, 9, 12, color);
    if (back >= 2) {
      backrest();
    }
  }

  void _armchair(double x, double y) {
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

  void _waterCooler(double x, double y) {
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
    _glows.add(_Glow(Iso.pt(22.3, 1.8, 30), 30, const Color(0x2E6FD0E0)));
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
        ..rect(forge.dx - 6, forge.dy - 1, 12, 2, _metal)
        ..rect(forge.dx - 1, forge.dy - 9, 2, 9, _metalLight)
        ..solid(5.7, 2.8, 6.7, 3.8, 9, 12, _chairDark);
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
        ..rect(seat.dx - 6, seat.dy - 1, 12, 2, _metal)
        ..rect(seat.dx - 1, seat.dy - 9, 2, 9, _metalLight);
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
      g.solid(x - 0.5, y - 0.6, x + 0.5, y - 0.45, 11, 30, _chairDark);
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
    for (final glow in _glows) {
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
