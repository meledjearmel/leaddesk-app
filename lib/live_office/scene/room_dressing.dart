part of 'plan_scene.dart';

/// Occupation du sol d'une salle, par demi-case, et usage de ses murs.
///
/// Chaque meuble réserve son emprise ; l'habillage ne pose un objet que là
/// où il reste de la place, sans rien chevaucher.
class _Floor {
  _Floor(this.room)
    : _cols = room.cols * 2,
      _rows = room.rows * 2,
      _cells = List<bool>.filled(room.cols * room.rows * 4, false);

  final PlacedRoom room;
  final int _cols;
  final int _rows;
  final List<bool> _cells;

  /// Meubles hauts : ils cachent le mur derrière eux.
  final List<Rect> tall = <Rect>[];

  /// Portions du mur du fond (en x) et du mur de gauche (en y) déjà
  /// occupées par un tableau, un écran, des placards.
  final List<(double, double)> backWall = <(double, double)>[];
  final List<(double, double)> leftWall = <(double, double)>[];

  bool inside(Rect r) =>
      r.left >= room.x - 1e-9 &&
      r.top >= room.y - 1e-9 &&
      r.right <= room.right + 1e-9 &&
      r.bottom <= room.bottom + 1e-9;

  (int, int, int, int) _span(Rect r) => (
    ((r.left - room.x) * 2 + 1e-9).floor().clamp(0, _cols),
    ((r.right - room.x) * 2 - 1e-9).ceil().clamp(0, _cols),
    ((r.top - room.y) * 2 + 1e-9).floor().clamp(0, _rows),
    ((r.bottom - room.y) * 2 - 1e-9).ceil().clamp(0, _rows),
  );

  /// Vrai si [r] est dans la salle et entièrement libre.
  bool free(Rect r) {
    if (!inside(r)) {
      return false;
    }
    final (c0, c1, r0, r1) = _span(r);
    for (var row = r0; row < r1; row++) {
      for (var col = c0; col < c1; col++) {
        if (_cells[row * _cols + col]) {
          return false;
        }
      }
    }
    return true;
  }

  void take(Rect r) {
    final (c0, c1, r0, r1) = _span(r);
    for (var row = r0; row < r1; row++) {
      for (var col = c0; col < c1; col++) {
        _cells[row * _cols + col] = true;
      }
    }
  }

  /// Vrai si [r] touche un mur ou un meuble par l'arrière ou par la gauche :
  /// un objet y est adossé au lieu de flotter au milieu de la pièce.
  bool anchored(Rect r) {
    bool blocked(Rect s) => !inside(s) || !free(s);
    return blocked(Rect.fromLTRB(r.left - 0.5, r.top, r.left, r.bottom)) ||
        blocked(Rect.fromLTRB(r.left, r.top - 0.5, r.right, r.top)) ||
        blocked(Rect.fromLTRB(r.right, r.top, r.right + 0.5, r.bottom));
  }

  static bool wallFree(List<(double, double)> used, double a, double b) =>
      used.every((u) => b <= u.$1 || a >= u.$2);

  bool tallIn(Rect r) => tall.any((t) => t.overlaps(r));
}

/// Mobilier dense et habillage des salles de la vue « Salle ».
extension _DenseRoom on PlanScenePainter {
  void _furnishDense(PlacedRoom room) {
    final f = _Floor(room);
    final x0 = room.x.toDouble();
    final y0 = room.y.toDouble();
    final x1 = room.right.toDouble();
    final y1 = room.bottom.toDouble();
    final cx = (x0 + x1) / 2;
    final cy = (y0 + y1) / 2;
    final back = x0 + y0 + 0.5;
    final seed = stableHash(room.id);

    void put(Rect r, double depth, void Function() draw, {bool tall = false}) {
      f.take(r);
      if (tall) {
        f.tall.add(r);
      }
      _add(depth, draw);
    }

    bool tryPut(
      Rect r,
      double depth,
      void Function() draw, {
      bool tall = false,
    }) {
      if (!f.free(r)) {
        return false;
      }
      put(r, depth, draw, tall: tall);
      return true;
    }

    // Les portes restent dégagées.
    if (room.y > 0) {
      final d = (room.x + room.cols ~/ 2).toDouble();
      f.take(Rect.fromLTRB(d - 0.25, y0, d + 1.25, y0 + 1.5));
    }
    if (room.x > 0) {
      final d = (room.y + room.rows ~/ 2).toDouble();
      f.take(Rect.fromLTRB(x0, d - 0.25, x0 + 1.5, d + 1.25));
    }

    switch (room.type.look) {
      case RoomLook.workDesks || RoomLook.privateOffice || RoomLook.executive:
        _desks(room);
        for (final (top, rx0, rx1, _) in _deskRows(room)) {
          f.take(Rect.fromLTRB(rx0 + 0.2, top - 0.2, rx1 - 0.2, top + 2.2));
          // Derrière les chaises, un passage reste libre.
          f.take(Rect.fromLTRB(rx0, top + 2.2, rx1, top + 2.7));
        }
      case RoomLook.creative:
        final bx1 = min(x1 - 0.4, x0 + 4);
        f.backWall.add((x0 + 0.4, bx1));
        _add(back, () => wallBoard(x0 + 0.4, bx1, y0));
        final ty0 = y1 - 1.8;
        final ty1 = y1 - 0.9;
        put(
          Rect.fromLTRB(cx - 1.4, ty0 - 1, cx + 1.4, ty1 + 0.9),
          cx - 1.2 + ty1 + 0.2,
          () => longTable(cx - 1.2, ty0, cx + 1.2, ty1, laptops: false),
        );
        tryPut(
          Rect.fromLTRB(x0 + 0.8, cy - 0.6, x0 + 1.6, cy + 0.2),
          x0 + 1.2 + cy,
          () => easel(x0 + 1.2, cy - 0.2, seed: room.x),
          tall: true,
        );
        tryPut(
          Rect.fromLTRB(x1 - 1.6, cy - 1.2, x1 - 0.8, cy - 0.4),
          x1 - 1.2 + cy - 0.6,
          () => easel(x1 - 1.2, cy - 0.8, seed: room.y + 1),
          tall: true,
        );
      case RoomLook.lab:
        for (var y = y0 + 0.5; y + 1.2 <= y1 - 0.3; y += 2.4) {
          final ys = y;
          put(
            Rect.fromLTRB(x0 + 0.5, ys - 0.2, x1 - 0.5, ys + 1.6),
            x0 + 0.5 + ys + 1.2,
            () => labBench(x0 + 0.5, ys, x1 - 0.5),
          );
        }
      case RoomLook.servers:
        // Rangées d'armoires, une allée entre deux rangées.
        for (var y = y0 + 0.3; y + 1.2 <= y1 - 0.9; y += 2.1) {
          for (var x = x0 + 0.3; x + 0.95 <= x1 - 0.3; x += 1.0) {
            final xs = x;
            final ys = y;
            put(
              Rect.fromLTRB(xs, ys, xs + 0.95, ys + 1.3),
              xs + 1 + ys + 1.2,
              () => serverRack(xs, ys, xs + 0.95, ys + 1.2),
              tall: true,
            );
          }
        }
        // Poste de surveillance : petite table et écran.
        tryPut(
          Rect.fromLTRB(x1 - 1.7, y1 - 1.4, x1 - 0.2, y1 - 0.2),
          x1 - 1.6 + y1 - 0.4,
          () {
            g.box(
              x1 - 1.6,
              y1 - 1.3,
              x1 - 0.3,
              y1 - 0.8,
              0,
              19,
              top: Tone.deskTop,
              left: Tone.deskEdge,
              right: Tone.deskEdgeDark,
            );
            monitor(x1 - 0.95, y1 - 1.1, w: 0.9, seed: seed);
            chair(x1 - 0.95, y1 - 0.4, back: 3, color: Tone.chairDark);
          },
        );
      case RoomLook.archives:
        for (var y = y0 + 0.1; y + 0.8 <= y1 - 0.8; y += 1.8) {
          final ys = y;
          put(
            Rect.fromLTRB(x0 + 0.2, ys, x1 - 0.6, ys + 0.9),
            x0 + 0.2 + ys + 0.9,
            () => archiveShelf(x0 + 0.2, ys, x1 - 0.6),
            tall: true,
          );
        }
      case RoomLook.meeting || RoomLook.brainstorm:
        final radius = max(0.9, min(room.cols, room.rows) / 2 - 1.3);
        if (room.type.look == RoomLook.brainstorm) {
          f.backWall.add((x0 + 0.3, x1 - 0.3));
          _add(back, () => wallBoard(x0 + 0.3, x1 - 0.3, y0));
        } else {
          f.backWall.add((cx - 1, cx + 1));
          _add(back, () => wallScreen(cx - 1, cx + 1, y0));
        }
        _rugUnder(
          room,
          cx - radius - 1.1,
          cy - radius - 1.1,
          cx + radius + 1.1,
          cy + radius + 1.1,
          seed,
        );
        f.take(
          Rect.fromLTRB(
            cx - radius - 0.9,
            cy - radius - 0.9,
            cx + radius + 0.9,
            cy + radius + 0.9,
          ),
        );
        _add(
          cx + cy - radius - 0.4,
          () => chair(cx, cy - radius - 0.4, back: 1, color: Tone.chairGrey),
        );
        _add(
          cx + cy - 0.5,
          () => chair(cx - radius - 0.4, cy, back: 0, color: Tone.chairGrey),
        );
        _add(cx + cy, () => roundTable(cx, cy, radius));
        _add(
          cx + cy + radius + 0.4,
          () => chair(cx + radius + 0.4, cy, back: 2, color: Tone.chairGrey),
        );
        _add(
          cx + cy + radius + 0.5,
          () => chair(cx, cy + radius + 0.4, back: 3, color: Tone.chairGrey),
        );
      case RoomLook.boardroom || RoomLook.warRoom || RoomLook.videoCall:
        final war = room.type.look == RoomLook.warRoom;
        f.backWall.add((x0 + 0.4, x1 - 0.4));
        _add(
          back,
          () => wallScreen(
            x0 + 0.4,
            x1 - 0.4,
            y0,
            chart: war || room.type.look == RoomLook.boardroom,
          ),
        );
        final tx0 = x0 + 0.8;
        final tx1 = max(tx0 + 1.4, x1 - 0.8);
        _rugUnder(room, tx0 - 0.5, cy - 1.4, tx1 + 0.5, cy + 1.7, seed);
        put(
          Rect.fromLTRB(tx0, cy - 1.3, tx1, cy + 1.6),
          cx + cy + 0.6,
          () => longTable(tx0, cy - 0.3, tx1, cy + 0.6),
        );
        if (war) {
          glows.add(Glow(Iso.pt(cx, cy, 20), 70, const Color(0x26F25C4C)));
        }
      case RoomLook.phoneBooth:
        var i = 0;
        for (var x = x0 + 0.2; x + 1.6 <= x1 - 0.1; x += 1.9) {
          final xs = x;
          final guest = room.x + i;
          final occupied = (seed + i++).isEven;
          put(
            Rect.fromLTRB(xs, y0 + 0.2, xs + 1.6, y0 + 1.8),
            xs + y0 + 1.7,
            () => booth(
              xs,
              y0 + 0.2,
              occupant: occupied
                  ? (feet) => drawPerson(
                      canvas,
                      feet,
                      _guest(guest),
                      raiseArm: true,
                      lod: lod,
                    )
                  : null,
            ),
            tall: true,
          );
        }
      case RoomLook.training:
        f.backWall.add((cx - 1.4, cx + 1.4));
        _add(back, () => wallScreen(cx - 1.4, cx + 1.4, y0));
        for (var y = y0 + 1.6; y < y1 - 1; y += 1.6) {
          final ys = y;
          put(Rect.fromLTRB(x0 + 0.6, ys, x1 - 0.6, ys + 1.6), cx + ys + 1, () {
            g.box(
              x0 + 0.6,
              ys,
              x1 - 0.6,
              ys + 0.6,
              14,
              17,
              top: Tone.deskTop,
              left: Tone.deskEdge,
              right: Tone.deskEdgeDark,
            );
            for (var x = x0 + 1.1; x < x1 - 0.8; x += 1.2) {
              chair(x, ys + 1.1, back: 3, color: Tone.chairGrey);
            }
          });
        }
      case RoomLook.controlRoom:
        f.backWall.add((x0 + 0.3, x1 - 0.3));
        _add(back, () => wallScreen(x0 + 0.3, x1 - 0.3, y0, chart: true));
        put(
          Rect.fromLTRB(x0 + 0.6, y0 + 1.3, x1 - 0.6, y0 + 3.2),
          cx + y0 + 2.4,
          () {
            g.box(
              x0 + 0.6,
              y0 + 1.4,
              x1 - 0.6,
              y0 + 2.1,
              0,
              18,
              top: const Color(0xFF39424E),
              left: const Color(0xFF2B2E33),
              right: const Color(0xFF1F2227),
            );
            for (var x = x0 + 1; x < x1 - 1; x += 1.3) {
              g.wallX(x, x + 0.8, y0 + 1.4, 18, 26, const Color(0xFF13303A));
              chair(x + 0.4, y0 + 2.7, back: 3, color: Tone.chairDark);
            }
          },
        );
      case RoomLook.studio:
        f.backWall.add((x0 + 0.2, x1 - 0.2));
        _add(back, () => acousticPanels(x0 + 0.2, x1 - 0.2, y0));
        tryPut(
          Rect.fromLTRB(cx - 0.9, cy - 0.3, cx - 0.3, cy + 0.3),
          cx + cy,
          () => microphone(cx - 0.6, cy),
          tall: true,
        );
        tryPut(
          Rect.fromLTRB(cx + 0.4, cy, cx + 1, cy + 0.6),
          cx + cy + 0.6,
          () => microphone(cx + 0.7, cy + 0.3),
          tall: true,
        );
        put(
          Rect.fromLTRB(cx - 1.2, y1 - 1.3, cx + 1.2, y1 - 0.1),
          cx + y1 - 0.6,
          () => sofa(
            cx - 1.2,
            y1 - 1.3,
            cx + 1.2,
            color: const Color(0xFF2E4468),
          ),
        );
      case RoomLook.cafe || RoomLook.cafeteria:
        _cafe(room, f, put, tryPut);
      default:
        // Lieux sans version détaillée : mobilier du plateau.
        _furnish(room);
        f.take(Rect.fromLTRB(x0, y0, x1, y1));
    }

    _dress(room, f, put, tryPut);
  }

  /// Tapis posé sous un meuble, gardé dans la salle.
  void _rugUnder(
    PlacedRoom room,
    double ax0,
    double ay0,
    double ax1,
    double ay1,
    int seed,
  ) {
    final rx0 = max(ax0, room.x + 0.2);
    final ry0 = max(ay0, room.y + 0.2);
    final rx1 = min(ax1, room.right - 0.2);
    final ry1 = min(ay1, room.bottom - 0.2);
    if (rx1 - rx0 < 1 || ry1 - ry0 < 1) {
      return;
    }
    // Au sol : dessiné avant tous les meubles.
    _add(-1e9, () => rug(rx0, ry0, rx1, ry1, seed));
  }

  /// Coin café : comptoir et placards, réfrigérateur, distributeur,
  /// fontaine, tables hautes.
  void _cafe(
    PlacedRoom room,
    _Floor f,
    void Function(Rect, double, void Function(), {bool tall}) put,
    bool Function(Rect, double, void Function(), {bool tall}) tryPut,
  ) {
    final x0 = room.x.toDouble();
    final y0 = room.y.toDouble();
    final x1 = room.right.toDouble();
    final y1 = room.bottom.toDouble();
    final cw = min(x1 - x0 - 1.6, 3.4);
    final cx1 = x0 + 0.3 + cw;
    f.backWall.add((x0 + 0.3, cx1));
    put(Rect.fromLTRB(x0 + 0.3, y0, cx1, y0 + 1.1), x0 + y0 + 1.1, () {
      // Placards hauts.
      for (var x = x0 + 0.3; x < cx1 - 0.85; x += 0.85) {
        g
          ..box(
            x,
            y0,
            x + 0.85,
            y0 + 0.45,
            46,
            62,
            top: Tone.shelfTop,
            left: const Color(0xFF9A6A3C),
            right: Tone.shelfSide,
          )
          ..wallX(
            x + 0.04,
            x + 0.81,
            y0 + 0.45,
            47,
            61,
            const Color(0xFF8A5C33),
          )
          ..wallX(x + 0.38, x + 0.46, y0 + 0.45, 49, 52, Tone.metalLight);
      }
      counter(x0 + 0.3, y0 + 0.15, cx1);
      if (cw >= 3) {
        microwave(x0 + 1.3, y0 + 0.25, 20.5);
      }
    });
    tryPut(
      Rect.fromLTRB(cx1 + 0.1, y0 + 0.05, cx1 + 0.95, y0 + 0.9),
      cx1 + 0.1 + y0 + 0.9,
      () => fridge(cx1 + 0.1, y0 + 0.1),
      tall: true,
    );
    tryPut(
      Rect.fromLTRB(x1 - 1.05, y0 + 1.2, x1 - 0.1, y0 + 2.1),
      x1 - 1 + y0 + 2,
      () => vendingMachine(x1 - 1, y0 + 1.25),
      tall: true,
    );
    tryPut(
      Rect.fromLTRB(x0 + 0.15, y1 - 1.15, x0 + 1.05, y1 - 0.2),
      x0 + 0.2 + y1 - 0.3,
      () => waterCooler(x0 + 0.2, y1 - 1.1),
      tall: true,
    );
    final table = cafeTableOf(room);
    final tx = table.dx;
    final ty = table.dy;
    if (f.free(Rect.fromLTRB(tx - 1.1, ty - 0.9, tx + 1.1, ty + 1.2))) {
      f.take(Rect.fromLTRB(tx - 1.1, ty - 0.9, tx + 1.1, ty + 1.2));
      _add(tx + ty - 0.9, () => stool(tx + 0.1, ty - 0.85));
      _add(tx + ty - 0.6, () => stool(tx - 0.95, ty - 0.1));
      _add(tx + ty, () => roundTable(tx, ty, 0.65, laptops: false));
      _add(tx + ty + 1.0, () => stool(tx + 0.1, ty + 0.95));
    }
    if (room.type.look == RoomLook.cafeteria && y1 - y0 >= 5) {
      tryPut(
        Rect.fromLTRB(x0 + 0.8, y1 - 2.6, x1 - 1.2, y1 - 0.5),
        x0 + 0.8 + y1 - 1,
        () => longTable(x0 + 0.8, y1 - 1.9, x1 - 1.2, y1 - 1.3, laptops: false),
      );
    }
  }

  /// Reflet sur un pan de vitre, au niveau ×3 : deux traits clairs en biais.
  /// [alongX] : vitre le long de x (sinon le long de y).
  void _glare(double x, double y, {required bool alongX}) {
    // Un pan sur deux : le verre reste sombre, le reflet ponctue.
    if (lod < 3 || (x + y).round().isOdd) {
      return;
    }
    const light = Color(0x26FFFFFF);
    const faint = Color(0x12FFFFFF);
    for (var k = 0; k < 5; k++) {
      final a = 0.18 + k * 0.025;
      final z = 12.0 + k * 2.2;
      if (alongX) {
        g
          ..wallX(x + a, x + a + 0.03, y, z, z + 7, light)
          ..wallX(x + a + 0.14, x + a + 0.16, y, z + 2, z + 6, faint);
      } else {
        g
          ..wallY(y + a, y + a + 0.03, x, z, z + 7, light)
          ..wallY(y + a + 0.14, y + a + 0.16, x, z + 2, z + 6, faint);
      }
    }
  }

  /// Objets posés sur un plan de travail : lampe, tasses, plantes, souris,
  /// classeurs, selon le poste.
  void _deskClutter(PlacedRoom room, (double, double, double, List<Seat>) row) {
    final (top, x0, x1, seats) = row;
    const z = 22.0;
    final solo = room.type.seatsPerRow == 1;
    for (final seat in seats) {
      final r = Random(stableHash('${room.id}:${seat.x}:${seat.y}'));
      mouse(seat.x + 0.72, top + 0.82, z + 0.5);
      // Derrière, entre deux écrans : une seule chose, ou rien.
      final behind = Iso.pt(seat.x + 0.75, top + 0.3, z);
      switch (r.nextInt(5)) {
        case 0:
          mug(behind);
        case 1:
          penCup(seat.x + 0.75, top + 0.3, z);
        case 2:
          smallPlant(behind);
        case 3:
          mug(behind);
          papers(seat.x - 0.3, top + 0.95, z + 0.2);
        default:
          break;
      }
      if (lod >= 3) {
        // De près : post-it collé au bord de l'écran, câble de l'écran,
        // carnet ou téléphone devant le clavier.
        g
          ..wallX(
            seat.x - 0.48,
            seat.x - 0.36,
            top + 0.36,
            44,
            47.5,
            DecorTone.notes[r.nextInt(DecorTone.notes.length)],
          )
          ..floor(
            seat.x + 0.05,
            top + 0.2,
            seat.x + 0.09,
            top + 0.55,
            const Color(0xFF15171B),
            z + 0.3,
          );
        switch (r.nextInt(3)) {
          case 0:
            notebook(seat.x - 0.75, top + 0.6, z, const Color(0xFF3F5F8A));
          case 1:
            g
              ..solid(
                seat.x - 0.82,
                top + 0.55,
                seat.x - 0.62,
                top + 0.68,
                z,
                z + 1,
                const Color(0xFF26292E),
              )
              ..floor(
                seat.x - 0.8,
                top + 0.57,
                seat.x - 0.64,
                top + 0.66,
                const Color(0xFF3A6F8A),
                z + 1.05,
              );
          default:
            break;
        }
      }
    }
    if (solo) {
      // Grand bureau : lampe, classeurs, carnet.
      deskLamp(Iso.pt(x0 + 0.6, top + 0.3, z));
      binders(x1 - 1.15, top + 0.3);
      notebook(x1 - 0.7, top + 0.8, z, const Color(0xFF8A3A32));
    } else {
      // Lampe au bout de la rangée, côté gauche.
      deskLamp(Iso.pt(x0 + 0.42, top + 0.85, z));
    }
  }

  /// Habillage : décor mural, rangements, coin salon, plantes, petits
  /// objets, là où il reste de la place.
  void _dress(
    PlacedRoom room,
    _Floor f,
    void Function(Rect, double, void Function(), {bool tall}) put,
    bool Function(Rect, double, void Function(), {bool tall}) tryPut,
  ) {
    final random = Random(stableHash('${room.id}/habillage'));
    final x0 = room.x.toDouble();
    final y0 = room.y.toDouble();
    final x1 = room.right.toDouble();
    final y1 = room.bottom.toDouble();
    final look = room.type.look;
    final work =
        look == RoomLook.workDesks ||
        look == RoomLook.privateOffice ||
        look == RoomLook.executive;
    final cafe = look == RoomLook.cafe || look == RoomLook.cafeteria;

    // 1. Mur du fond extérieur : bibliothèque basse sous les fenêtres,
    //    cadre, horloge ou plante suspendue entre elles.
    if (room.y == 0) {
      for (var wx = 1.0; wx < plan.cols - 1; wx += 4) {
        final a = max(wx, x0 + 0.2);
        final b = min(wx + 2.4, x1 - 0.2);
        if (b - a >= 1.4 && random.nextDouble() < 0.75) {
          final shelf = Rect.fromLTRB(a, y0 + 0.05, b, y0 + 0.8);
          final s = random.nextInt(1000);
          tryPut(shelf, a + y0 + 0.75, () => lowShelf(a, y0 + 0.05, b, s));
        }
        final gx = wx + 2.4;
        if (gx + 0.2 >= x0 &&
            gx + 1.4 <= x1 &&
            _Floor.wallFree(f.backWall, gx, gx + 1.6) &&
            !f.tallIn(Rect.fromLTRB(gx, y0, gx + 1.6, y0 + 1))) {
          f.backWall.add((gx, gx + 1.6));
          final s = random.nextInt(1000);
          switch (random.nextInt(4)) {
            case 0 || 1:
              _add(
                gx + y0 + 0.1,
                () => poster(gx + 0.35, gx + 1.25, y0, 30, 54, s),
              );
            case 2:
              _add(gx + y0 + 0.1, () {
                wallClock(Iso.pt(gx + 0.8, y0 + 0.06, 58));
                poster(gx + 0.45, gx + 1.15, y0, 30, 46, s);
              });
            default:
              _add(
                gx + y0 + 0.4,
                () => hangingPlant(Iso.pt(gx + 0.8, y0 + 0.5, 72), s),
              );
          }
        }
      }
    } else {
      // Cloison vitrée au fond : une bibliothèque adossée, au bout.
      final r = Rect.fromLTRB(x1 - 2.3, y0 + 0.05, x1 - 0.2, y0 + 0.95);
      if (!cafe && random.nextDouble() < 0.8) {
        final s = random.nextInt(1000);
        tryPut(
          r,
          x1 - 2.3 + y0 + 1.1,
          () => bookshelf(
            x1 - 2.3,
            y0 + 0.05,
            x1 - 0.2,
            h: 64,
            shelves: 4,
            seed: s,
          ),
          tall: true,
        );
      }
    }

    // 2. Mur de gauche extérieur : bibliothèques, tableau blanc, cadres.
    if (room.x == 0) {
      var y = y0 + 0.3;
      var board = !(work || look == RoomLook.brainstorm);
      while (y + 1.2 <= y1 - 0.2) {
        final len = min(2.2, y1 - 0.2 - y);
        final strip = Rect.fromLTRB(x0 + 0.05, y, x0 + 0.95, y + len);
        final s = random.nextInt(1000);
        final ys = y;
        if (!cafe && len >= 1.4 && random.nextDouble() < 0.5 && f.free(strip)) {
          put(
            strip,
            x0 + ys + len,
            () => bookshelfSide(x0 + 0.05, ys, ys + len, seed: s),
            tall: true,
          );
        } else if (!f.tallIn(strip) &&
            _Floor.wallFree(f.leftWall, ys, ys + len)) {
          f.leftWall.add((ys, ys + len));
          if (!board && len >= 1.8) {
            board = true;
            _add(x0 + ys, () => wallBoardSide(ys + 0.1, ys + len - 0.1, x0, s));
          } else {
            _add(
              x0 + ys,
              () => posterSide(ys + 0.5, ys + len - 0.5, x0, 30, 52, s),
            );
          }
        }
        y += len + 0.3;
      }
    }

    // 3. Grand espace libre : coin salon, petite réunion ou tableau mobile.
    for (var n = 0; n < 2; n++) {
      final spot = _freeArea(f, cafe ? 2 : 2.5, cafe ? 2 : 2.5);
      if (spot == null) {
        break;
      }
      f.take(spot);
      final s = random.nextInt(1000);
      final ax = spot.left;
      final ay = spot.top;
      final kind = cafe ? 3 : random.nextInt(work ? 3 : 2);
      switch (kind) {
        case 0:
          // Coin salon : tapis, fauteuil, table basse, lampadaire.
          _add(-1e9, () => rug(ax + 0.15, ay + 0.15, ax + 2.35, ay + 2.35, s));
          _add(ax + ay + 2.6, () => armchair(ax + 0.95, ay + 0.95));
          _add(
            ax + ay + 3.6,
            () => lowTable(ax + 1.3, ay + 1.7, ax + 2.1, ay + 2.2),
          );
          _add(ax + ay + 2.6, () => floorLamp(ax + 0.35, ay + 2.15));
        case 1:
          // Petite table ronde et deux chaises.
          final tx = ax + 1.25;
          final ty = ay + 1.25;
          _add(-1e9, () => rug(ax + 0.1, ay + 0.1, ax + 2.4, ay + 2.4, s));
          _add(
            tx + ty - 1,
            () => chair(tx, ty - 1, back: 1, color: Tone.chairGrey),
          );
          _add(tx + ty, () => roundTable(tx, ty, 0.7));
          _add(
            tx + ty + 1,
            () => chair(tx, ty + 1, back: 3, color: Tone.chairGrey),
          );
        case 2:
          // Tableau mobile couvert de notes, une plante à côté.
          _add(ax + ay + 1.4, () => rollingBoard(ax + 0.2, ax + 2.3, ay + 1.1));
          _add(ax + ay + 2.3, () => bushPlant(Iso.pt(ax + 2, ay + 2), s));
        default:
          // Table haute du café.
          final tx = ax + 1;
          final ty = ay + 1;
          _add(tx + ty - 0.8, () => stool(tx + 0.1, ty - 0.8));
          _add(tx + ty, () => roundTable(tx, ty, 0.6, laptops: false));
          _add(tx + ty + 0.9, () => stool(tx, ty + 0.85));
      }
    }

    // 4. Plantes dans les coins libres.
    var plants = 0;
    for (final (px, py) in <(double, double)>[
      (x1 - 0.55, y0 + 0.55),
      (x0 + 0.55, y1 - 0.55),
      (x1 - 0.55, y1 - 0.55),
      (x0 + 0.55, y0 + 0.55),
    ]) {
      if (plants >= 2) {
        break;
      }
      final r = Rect.fromLTRB(px - 0.45, py - 0.45, px + 0.45, py + 0.45);
      final s = random.nextInt(1000);
      final kind = random.nextInt(3);
      if (tryPut(r, px + py + 0.4, () {
        switch (kind) {
          case 0:
            palm(Iso.pt(px, py), seed: s, size: 13);
          case 1:
            tallPlant(Iso.pt(px, py), s);
          default:
            bushPlant(Iso.pt(px, py), s);
        }
      }, tall: true)) {
        plants++;
      }
    }

    // 5. Petits objets adossés aux murs et aux meubles.
    final props = <int>[
      if (work) ...<int>[0, 1, 2, 3, 4, 5],
      if (look == RoomLook.workDesks) 6,
      if (!work && !cafe) ...<int>[1, 2, 5],
      if (cafe) ...<int>[1, 5],
    ];
    if (props.isEmpty) {
      return;
    }
    final budget = max(2, room.cols * room.rows ~/ 7);
    var placed = 0;
    var cooler = false;
    for (var attempt = 0; attempt < 60 && placed < budget; attempt++) {
      final px = x0 + random.nextInt(room.cols * 2) / 2;
      final py = y0 + random.nextInt(room.rows * 2) / 2;
      final kind = props[random.nextInt(props.length)];
      final s = random.nextInt(1000);
      final r = Rect.fromLTRB(px, py, px + 0.7, py + 0.7);
      if (!f.free(r) || !f.anchored(r)) {
        continue;
      }
      if (kind == 6 && cooler) {
        continue;
      }
      final depth = px + py + 0.7;
      put(r, depth, () {
        switch (kind) {
          case 0:
            filingCabinet(px, py);
          case 1:
            trashBin(px + 0.35, py + 0.4);
          case 2:
            boxes(px, py + 0.1, s);
          case 3:
            backpack(
              px + 0.35,
              py + 0.4,
              DecorTone.art[s % DecorTone.art.length],
            );
          case 4:
            coatRack(
              px + 0.35,
              py + 0.35,
              DecorTone.art[s % DecorTone.art.length],
            );
          case 5:
            bushPlant(Iso.pt(px + 0.35, py + 0.4), s);
          default:
            waterCooler(px - 0.05, py - 0.05);
        }
      }, tall: kind == 0 || kind == 4 || kind == 6);
      cooler |= kind == 6;
      placed++;
    }
  }

  /// Premier espace libre de [w] × [h] cases, en partant de l'avant de la
  /// salle ; `null` s'il n'y en a pas.
  Rect? _freeArea(_Floor f, double w, double h) {
    final room = f.room;
    for (var y = room.bottom - h; y >= room.y; y -= 0.5) {
      for (var x = room.right - w; x >= room.x; x -= 0.5) {
        final r = Rect.fromLTRB(x, y, x + w, y + h);
        if (f.free(r)) {
          return r;
        }
      }
    }
    return null;
  }
}
