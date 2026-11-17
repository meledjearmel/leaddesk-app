import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../office/office_plan.dart';
import '../../office/room_catalog.dart';
import 'furniture.dart';
import 'iso.dart';
import 'pixel_people.dart';

/// Hauteur des murs extérieurs et des cloisons, en pixels d'art.
const double _wallHeight = 74;
const double _partitionHeight = 40;
const double _margin = 28;

/// Poste de travail d'une salle, en coordonnées de la grille.
class Seat {
  const Seat(this.room, this.x, this.y);

  final PlacedRoom room;
  final double x;
  final double y;
}

/// Étiquette d'une salle : où l'afficher et quoi y écrire.
class RoomTag {
  const RoomTag({required this.room, required this.anchor, this.department});

  final PlacedRoom room;

  /// Point d'accroche dans l'image de la scène.
  final Offset anchor;
  final OfficeDepartment? department;
}

/// Géométrie d'un plan dessiné : taille de l'image, postes, étiquettes.
///
/// Calculée sans rien dessiner : la vue s'en sert pour poser les étiquettes
/// au bon endroit et la minicarte pour placer les agents.
class PlanGeometry {
  PlanGeometry(this.plan, List<OfficeDepartment> departments)
    : _departments = <String, OfficeDepartment>{
        for (final department in departments) department.id: department,
      } {
    final span = (plan.cols + plan.rows).toDouble();
    size = ui.Size(
      span * Iso.halfTileWidth + 2 * _margin,
      span * Iso.halfTileHeight + _wallHeight + 2 * _margin,
    );
    // Iso.pt(0, rows) est le point le plus à gauche, le haut des murs du
    // fond le point le plus haut.
    shift = Offset(
      _margin - (Iso.originX - plan.rows * Iso.halfTileWidth),
      _margin + _wallHeight - Iso.originY,
    );
  }

  final OfficePlan plan;
  final Map<String, OfficeDepartment> _departments;
  late final ui.Size size;

  /// Décalage à appliquer aux coordonnées de [Iso.pt].
  late final Offset shift;

  OfficeDepartment? departmentOf(PlacedRoom room) {
    final id = room.departmentId;
    return id == null ? null : _departments[id];
  }

  /// Point de l'image correspondant à un point de la grille.
  Offset toImage(double x, double y, [double z = 0]) => Iso.pt(x, y, z) + shift;

  /// Postes de travail, rangés par département puis dans l'ordre du plan.
  late final Map<String, List<Seat>> seats = () {
    final result = <String, List<Seat>>{};
    for (final room in plan.rooms) {
      final department = room.departmentId;
      if (department != null) {
        result.putIfAbsent(department, () => <Seat>[]).addAll(seatsIn(room));
      }
    }
    return result;
  }();

  late final List<RoomTag> tags = <RoomTag>[
    for (final room in plan.rooms)
      RoomTag(
        room: room,
        anchor: toImage(room.x + 0.4, room.bottom - 0.4),
        department: departmentOf(room),
      ),
  ];

  /// Emprise d'un département dans l'image (sol et murs de ses salles) ;
  /// `null` s'il n'a aucune salle.
  Rect? departmentBounds(String departmentId) {
    Rect? bounds;
    for (final room in plan.rooms) {
      if (room.departmentId != departmentId) {
        continue;
      }
      final points = <Offset>[
        toImage(room.x.toDouble(), room.y.toDouble(), _partitionHeight),
        toImage(room.right.toDouble(), room.y.toDouble()),
        toImage(room.x.toDouble(), room.bottom.toDouble()),
        toImage(room.right.toDouble(), room.bottom.toDouble()),
      ];
      for (final point in points) {
        final r = Rect.fromCenter(center: point, width: 0, height: 0);
        bounds = bounds == null ? r : bounds.expandToInclude(r);
      }
    }
    return bounds;
  }

  /// Postes d'une salle : rangées de deux cases, réparties sur la largeur.
  static List<Seat> seatsIn(PlacedRoom room) {
    final type = room.type;
    if (!type.hasDesks) {
      return const <Seat>[];
    }
    final perRow = type.seatsPerRow;
    return <Seat>[
      for (var pair = 0; pair < room.rows ~/ 2; pair++)
        for (var i = 0; i < perRow; i++)
          Seat(
            room,
            room.x + room.cols * (i + 0.5) / perRow,
            room.y + pair * 2 + 1.75,
          ),
    ];
  }
}

/// Rend une image d'ambiance d'un plan d'aménagement.
///
/// [occupants] donne, pour chaque département, l'apparence des personnes
/// assises dans l'ordre des postes ; les postes restants sont vacants.
ui.Image renderPlanFrame(
  PlanGeometry geometry, {
  Map<String, List<PersonLook>> occupants = const <String, List<PersonLook>>{},
  int frame = 0,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Offset.zero & geometry.size);
  PlanScenePainter(canvas, frame, geometry, occupants).paint();
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    geometry.size.width.ceil(),
    geometry.size.height.ceil(),
  );
  picture.dispose();
  return image;
}

class _Item {
  _Item(this.depth, this.order, this.draw);

  final double depth;
  final int order;
  final void Function() draw;
}

/// Dessine un plan : sols, murs, cloisons vitrées entre les salles, mobilier
/// propre à chaque type de salle, personnes à leur poste, lumières.
class PlanScenePainter extends FurnitureKit {
  PlanScenePainter(super.canvas, super.frame, this.geometry, this.occupants);

  final PlanGeometry geometry;
  final Map<String, List<PersonLook>> occupants;
  final List<_Item> _items = <_Item>[];

  OfficePlan get plan => geometry.plan;

  void paint() {
    final size = geometry.size;
    g.rect(0, 0, size.width, size.height, const Color(0xFF0B0908));
    canvas
      ..save()
      ..translate(geometry.shift.dx, geometry.shift.dy);
    _corridor();
    for (final room in plan.rooms) {
      _floor(room);
    }
    _outerWalls();
    for (final room in plan.rooms) {
      _partitions(room);
      _furnish(room);
    }
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

  // ------------------------------------------------------------ sols, murs

  void _corridor() {
    for (var x = 0; x < plan.cols; x++) {
      for (var y = 0; y < plan.rows; y++) {
        g.floor(
          x.toDouble(),
          y.toDouble(),
          x + 1.0,
          y + 1.0,
          (x + y).isEven ? const Color(0xFF2B2622) : const Color(0xFF27221F),
        );
      }
    }
  }

  void _floor(PlacedRoom room) {
    final look = room.type.look;
    final x0 = room.x.toDouble();
    final y0 = room.y.toDouble();
    final x1 = room.right.toDouble();
    final y1 = room.bottom.toDouble();
    final random = Random(room.id.hashCode);

    switch (look) {
      case RoomLook.cafe ||
          RoomLook.cafeteria ||
          RoomLook.lockers ||
          RoomLook.lab ||
          RoomLook.printRoom:
        for (var x = room.x; x < room.right; x++) {
          for (var y = room.y; y < room.bottom; y++) {
            g.floor(
              x.toDouble(),
              y.toDouble(),
              x + 1.0,
              y + 1.0,
              (x + y).isEven
                  ? const Color(0xFFB9AE98)
                  : const Color(0xFF9E937E),
            );
          }
        }
      case RoomLook.servers || RoomLook.controlRoom:
        g.floor(x0, y0, x1, y1, const Color(0xFF3A3F45));
        for (var x = room.x; x <= room.right; x++) {
          g.floor(x - 0.04, y0, x + 0.04, y1, const Color(0xFF2A2E33));
        }
        for (var y = room.y; y <= room.bottom; y++) {
          g.floor(x0, y - 0.04, x1, y + 0.04, const Color(0xFF2A2E33));
        }
      case RoomLook.terrace:
        g.floor(x0, y0, x1, y1, const Color(0xFF3F6B3A));
        for (var i = 0; i < room.cols * room.rows * 3; i++) {
          final x = x0 + random.nextDouble() * (room.cols - 0.3);
          final y = y0 + random.nextDouble() * (room.rows - 0.3);
          g.floor(x, y, x + 0.2, y + 0.2, Tone.greens[random.nextInt(4)]);
        }
        g.floor(
          x0 + 0.5,
          y1 - 1.6,
          x1 - 0.5,
          y1 - 0.4,
          const Color(0xFF8A5A33),
        );
      case RoomLook.gym || RoomLook.nap:
        g.floor(
          x0,
          y0,
          x1,
          y1,
          look == RoomLook.gym
              ? const Color(0xFF34393F)
              : const Color(0xFF3A3346),
        );
      case RoomLook.meeting ||
          RoomLook.boardroom ||
          RoomLook.executive ||
          RoomLook.lounge ||
          RoomLook.auditorium ||
          RoomLook.library ||
          RoomLook.waiting:
        _planks(room, random);
        final inset = min(1.0, min(room.cols, room.rows) / 4);
        g
          ..floor(
            x0 + inset,
            y0 + inset,
            x1 - inset,
            y1 - inset,
            const Color(0xFF6C3428),
          )
          ..floor(
            x0 + inset + 0.2,
            y0 + inset + 0.2,
            x1 - inset - 0.2,
            y1 - inset - 0.2,
            look == RoomLook.auditorium
                ? const Color(0xFF55261F)
                : const Color(0xFF4B433C),
          );
      default:
        _planks(room, random);
    }

    // Liseré de la couleur du département, le long du bord avant.
    final department = geometry.departmentOf(room);
    if (department != null) {
      g.floor(x0, y1 - 0.16, x1, y1, Color(department.color), 0.2);
    }
  }

  void _planks(PlacedRoom room, Random random) {
    const planks = <Color>[
      Color(0xFF3A2317),
      Color(0xFF41281A),
      Color(0xFF48301F),
      Color(0xFF36201A),
      Color(0xFF4D3322),
    ];
    const seam = Color(0xFF26160F);
    for (var y = room.y.toDouble(); y < room.bottom; y += 0.5) {
      var x = room.x - random.nextDouble() * 2;
      while (x < room.right) {
        final length = 2.0 + random.nextInt(3);
        final from = max(x, room.x.toDouble());
        final to = min(x + length, room.right.toDouble());
        g.floor(from, y, to, y + 0.5, planks[random.nextInt(planks.length)]);
        if (x + length < room.right) {
          g.floor(to - 0.07, y, to, y + 0.5, seam);
        }
        x += length;
      }
      g.floor(room.x.toDouble(), y, room.right.toDouble(), y + 0.06, seam);
    }
  }

  void _outerWalls() {
    final cols = plan.cols.toDouble();
    final rows = plan.rows.toDouble();
    g
      ..wallY(0, rows, 0, 0, _wallHeight, const Color(0xFFCDB999))
      ..wallY(
        0,
        rows,
        0,
        _wallHeight - 16,
        _wallHeight,
        const Color(0xFFD6C4A6),
      )
      ..wallY(0, rows, 0, 0, 4, const Color(0xFF4A3524))
      ..wallX(0, cols, 0, 0, _wallHeight, const Color(0xFF465350))
      ..wallX(
        0,
        cols,
        0,
        _wallHeight - 16,
        _wallHeight,
        const Color(0xFF4E5C58),
      )
      ..wallX(0, cols, 0, 0, 4, const Color(0xFF2A322F))
      ..floor(0, -0.4, cols, 0, const Color(0xFF67756F), _wallHeight)
      ..quad(
        Iso.pt(0, 0, _wallHeight),
        Iso.pt(0, rows, _wallHeight),
        Iso.pt(-0.4, rows, _wallHeight),
        Iso.pt(-0.4, 0, _wallHeight),
        const Color(0xFFE6D8BE),
      );
    // Fenêtres hautes du mur du fond.
    for (var x = 1.0; x < cols - 1; x += 4) {
      g
        ..wallX(x, x + 2.4, 0, 40, 64, const Color(0xFF1C2A33))
        ..wallX(x + 0.1, x + 2.3, 0, 42, 62, const Color(0xFF2E4A5A))
        ..wallX(x + 1.15, x + 1.25, 0, 42, 62, const Color(0xFF1C2A33));
    }
  }

  /// Cloisons vitrées sur les bords arrière d'une salle, avec une porte.
  void _partitions(PlacedRoom room) {
    final department = geometry.departmentOf(room);
    final trim = department == null
        ? const Color(0xFF22262A)
        : shade(Color(department.color), 0.8);
    const frame = Color(0xFF22262A);
    const glass = Color(0x386FA0A8);
    final door = room.cols ~/ 2;

    if (room.y > 0) {
      for (var i = 0; i < room.cols; i++) {
        final x = (room.x + i).toDouble();
        final y = room.y.toDouble();
        _add(x + 0.5 + y - 0.01, () {
          if (i != door) {
            g.wallX(x, x + 1, y, 3, _partitionHeight, glass);
          }
          g
            ..wallX(x, x + 1, y, 0, 3, frame)
            ..wallX(x - 0.05, x + 0.05, y, 0, _partitionHeight, frame)
            ..wallX(x, x + 1, y, _partitionHeight - 2, _partitionHeight, trim);
        });
      }
    }
    if (room.x > 0) {
      final rowDoor = room.rows ~/ 2;
      for (var i = 0; i < room.rows; i++) {
        final x = room.x.toDouble();
        final y = (room.y + i).toDouble();
        _add(x + y + 0.5 - 0.01, () {
          if (i != rowDoor) {
            g.wallY(y, y + 1, x, 3, _partitionHeight, glass);
          }
          g
            ..wallY(y, y + 1, x, 0, 3, frame)
            ..wallY(y - 0.05, y + 0.05, x, 0, _partitionHeight, frame)
            ..wallY(y, y + 1, x, _partitionHeight - 2, _partitionHeight, trim);
        });
      }
    }
  }

  // --------------------------------------------------------------- mobilier

  void _furnish(PlacedRoom room) {
    final x0 = room.x.toDouble();
    final y0 = room.y.toDouble();
    final x1 = room.right.toDouble();
    final y1 = room.bottom.toDouble();
    final cx = (x0 + x1) / 2;
    final cy = (y0 + y1) / 2;
    // Profondeur d'un meuble posé au fond de la salle.
    final back = x0 + y0 + 0.5;

    switch (room.type.look) {
      case RoomLook.workDesks || RoomLook.privateOffice || RoomLook.executive:
        _desks(room);
        if (room.type.look == RoomLook.executive) {
          _add(
            back + 1,
            () => bookshelf(x0 + 0.3, y0 + 0.05, x0 + 2.6, h: 58, seed: room.x),
          );
          _add(
            x1 + y0,
            () => palm(Iso.pt(x1 - 0.6, y0 + 0.7), seed: room.y, size: 13),
          );
        } else if (room.type.look == RoomLook.privateOffice) {
          _add(
            back + 0.8,
            () => bookshelf(
              x1 - 1.6,
              y0 + 0.05,
              x1 - 0.2,
              h: 44,
              shelves: 3,
              seed: room.y,
            ),
          );
        } else {
          _add(
            x1 + y0 + 0.2,
            () => palm(Iso.pt(x1 - 0.5, y0 + 0.6), seed: room.x, size: 12),
          );
        }
      case RoomLook.creative:
        _add(back, () => wallBoard(x0 + 0.4, min(x1 - 0.4, x0 + 4), y0));
        _add(
          x0 + 1.2 + cy + 0.6,
          () => easel(x0 + 1.2, cy + 0.6, seed: room.x),
        );
        _add(x1 - 1.2 + cy, () => easel(x1 - 1.2, cy, seed: room.y + 1));
        _add(
          cx + y1 - 0.8,
          () =>
              longTable(cx - 1.2, y1 - 1.8, cx + 1.2, y1 - 0.9, laptops: false),
        );
      case RoomLook.lab:
        _add(cx + y0 + 1.4, () => labBench(x0 + 0.5, y0 + 0.5, x1 - 0.5));
        if (room.rows >= 4) {
          _add(cx + y0 + 3.4, () => labBench(x0 + 0.5, y0 + 2.4, x1 - 0.5));
        }
        _add(x0 + y1, () => waterCooler(x0 + 0.2, y1 - 1));
      case RoomLook.servers:
        for (var x = x0 + 0.3; x < x1 - 1.5; x += 2.2) {
          final xs = x;
          _add(
            xs + 2 + y0 + 2,
            () => serverRack(xs, y0 + 0.3, xs + 1.8, y0 + 1.9),
          );
        }
      case RoomLook.archives:
        _add(back + 1, () => archiveShelf(x0 + 0.2, y0 + 0.1, x1 - 0.2));
        if (room.rows >= 3) {
          _add(cx + y0 + 2.6, () => archiveShelf(x0 + 0.2, y0 + 1.8, x1 - 0.8));
        }
      case RoomLook.meeting || RoomLook.brainstorm:
        final radius = max(0.9, min(room.cols, room.rows) / 2 - 1.3);
        if (room.type.look == RoomLook.brainstorm) {
          _add(back, () => wallBoard(x0 + 0.3, x1 - 0.3, y0));
        } else {
          _add(back, () => wallScreen(cx - 1, cx + 1, y0));
        }
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
        _add(cx + cy + 0.6, () => longTable(tx0, cy - 0.3, tx1, cy + 0.6));
        if (war) {
          glows.add(Glow(Iso.pt(cx, cy, 20), 70, const Color(0x26F25C4C)));
        }
      case RoomLook.phoneBooth:
        final occupant = (room.id.hashCode).isEven;
        _add(
          x0 + y0 + 1.7,
          () => booth(
            x0 + 0.2,
            y0 + 0.2,
            occupant: occupant
                ? (feet) =>
                      drawPerson(canvas, feet, _guest(room.x), raiseArm: true)
                : null,
          ),
        );
      case RoomLook.cafe:
        _add(back + 0.6, () => counter(x0 + 0.3, y0 + 0.15, x1 - 0.3));
        _add(x0 + y1 - 0.5, () => waterCooler(x0 + 0.2, y1 - 1.1));
        _add(cx + cy + 0.8, () => roundTable(cx + 0.4, cy + 0.6, 0.8));
      case RoomLook.cafeteria:
        _add(back + 0.6, () => counter(x0 + 0.3, y0 + 0.15, x1 - 0.3));
        _add(
          cx + y0 + 2.2,
          () =>
              longTable(x0 + 0.8, y0 + 1.9, x1 - 0.8, y0 + 2.5, laptops: false),
        );
        if (room.rows >= 5) {
          _add(
            cx + y1 - 0.8,
            () =>
                longTable(x0 + 0.8, y1 - 1.6, x1 - 0.8, y1 - 1, laptops: false),
          );
        }
      case RoomLook.lounge:
        _add(back + 1, () => sofa(x0 + 0.6, y0 + 0.3, x1 - 0.8));
        _add(
          cx + cy + 0.5,
          () => lowTable(cx - 0.8, cy - 0.1, cx + 0.8, cy + 0.6),
        );
        _add(x0 + y1 - 0.4, () => armchair(x0 + 1, y1 - 1.1));
        _add(x1 + y1 - 1.4, () => floorLamp(x1 - 0.6, y1 - 1));
      case RoomLook.arcade:
        const bodies = <Color>[
          Color(0xFF8A3A32),
          Color(0xFF2E4468),
          Color(0xFF3F6B4A),
        ];
        var i = 0;
        for (var x = x0 + 0.4; x < x1 - 1; x += 1.3) {
          final xs = x;
          final body = bodies[i++ % bodies.length];
          _add(xs + y0 + 1.6, () => arcade(xs, y0 + 0.3, body));
        }
        _add(
          cx + y1 - 0.5,
          () => sofa(
            cx - 1.2,
            y1 - 1.3,
            cx + 1.2,
            color: const Color(0xFF5A4470),
          ),
        );
      case RoomLook.nap:
        const blankets = <Color>[
          Color(0xFF3F5F8A),
          Color(0xFF5A4470),
          Color(0xFF3F6B4A),
        ];
        var i = 0;
        for (var x = x0 + 0.4; x < x1 - 1.2; x += 1.6) {
          final xs = x;
          final blanket = blankets[i++ % blankets.length];
          _add(xs + y0 + 2.5, () => bed(xs, y0 + 0.3, blanket));
        }
      case RoomLook.gym:
        const mats = <Color>[
          Color(0xFF3F8A8C),
          Color(0xFF8A5AA8),
          Color(0xFFE2874A),
        ];
        var i = 0;
        for (var x = x0 + 0.5; x < x1 - 0.9; x += 1.3) {
          final xs = x;
          final color = mats[i++ % mats.length];
          _add(xs + y0 + 0.6, () => mat(xs, y0 + 0.6, color));
        }
        _add(x1 + y1 - 1.4, () => palm(Iso.pt(x1 - 0.6, y1 - 0.8), seed: 4));
      case RoomLook.terrace:
        _add(
          x0 + y0 + 1.2,
          () => palm(Iso.pt(x0 + 0.7, y0 + 0.7), seed: 1, size: 16),
        );
        _add(
          x1 + y0 + 0.2,
          () => palm(Iso.pt(x1 - 0.7, y0 + 0.7), seed: 2, size: 15),
        );
        _add(cx + cy + 0.4, () => bench(cx - 1.2, cy - 0.3, cx + 1.2));
        _add(
          x1 + y1 - 1.4,
          () => palm(Iso.pt(x1 - 0.8, y1 - 0.7), seed: 5, size: 13),
        );
      case RoomLook.auditorium:
        _add(back, () => wallScreen(cx - 2, cx + 2, y0, z: 18, chart: true));
        var z = 3.0;
        for (var y = y0 + 1.8; y < y1 - 0.6; y += 1.1) {
          final ys = y;
          final zs = z;
          _add(cx + ys + 1, () => bleacher(x0 + 0.4, x1 - 0.4, ys, zs));
          z += 5;
        }
      case RoomLook.training:
        _add(back, () => wallScreen(cx - 1.4, cx + 1.4, y0));
        for (var y = y0 + 1.6; y < y1 - 1; y += 1.6) {
          final ys = y;
          _add(cx + ys + 1, () {
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
      case RoomLook.library:
        _add(
          back + 1,
          () => bookshelf(x0 + 0.2, y0 + 0.05, x1 - 0.2, seed: room.x + room.y),
        );
        _add(x0 + y1 - 0.4, () => armchair(x0 + 1, y1 - 1.1));
        _add(x1 + y1 - 1.4, () => floorLamp(x1 - 0.6, y1 - 1));
      case RoomLook.reception:
        _add(back, () => _welcomeSign(cx, y0));
        _add(cx + cy, () {
          g.box(
            cx - 1.4,
            cy - 0.5,
            cx + 1.4,
            cy + 0.3,
            0,
            20,
            top: Tone.deskTop,
            left: const Color(0xFFD9C8A9),
            right: Tone.deskEdgeDark,
          );
          monitorBack(cx - 0.4, cy - 0.45);
        });
        _add(cx + cy - 0.6, () {
          g.solid(
            cx - 0.4,
            cy - 1.4,
            cx + 0.4,
            cy - 1.25,
            11,
            30,
            Tone.chairDark,
          );
          drawPerson(
            canvas,
            Iso.pt(cx, cy - 0.9, 8),
            _guest(7),
            pose: PersonPose.seated,
          );
        });
        _add(
          x0 + y1 - 0.6,
          () => palm(Iso.pt(x0 + 0.7, y1 - 0.8), seed: 9, size: 14),
        );
        _add(x1 + y1 - 1.2, () => waterCooler(x1 - 1, y1 - 1.2));
      case RoomLook.waiting:
        _add(cx + y0 + 1.6, () => armchair(cx - 0.6, y0 + 1));
        _add(cx + y0 + 2.6, () => armchair(cx + 0.9, y0 + 1.4));
        _add(
          x0 + y1 - 0.5,
          () => smallPlant(Iso.pt(x0 + 0.5, y1 - 0.5), big: true),
        );
      case RoomLook.printRoom:
        _add(x0 + y0 + 1.6, () => copier(x0 + 0.3, y0 + 0.3));
        if (room.cols >= 3) {
          _add(x1 + y0, () => lockers(x1 - 1.2, y0 + 0.1, x1 - 0.2));
        }
      case RoomLook.lockers:
        _add(back + 0.6, () => lockers(x0 + 0.2, y0 + 0.1, x1 - 1.2));
        _add(x1 + y0, () => sink(x1 - 1, y0 + 0.05));
      case RoomLook.studio:
        _add(back, () => acousticPanels(x0 + 0.2, x1 - 0.2, y0));
        _add(cx + cy, () => microphone(cx - 0.6, cy));
        _add(cx + cy + 0.6, () => microphone(cx + 0.7, cy + 0.3));
        _add(
          cx + y1 - 0.6,
          () => sofa(
            cx - 1.2,
            y1 - 1.3,
            cx + 1.2,
            color: const Color(0xFF2E4468),
          ),
        );
      case RoomLook.controlRoom:
        _add(back, () => wallScreen(x0 + 0.3, x1 - 0.3, y0, chart: true));
        _add(cx + y0 + 2.4, () {
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
        });
    }
  }

  /// Bureaux en rangées : un plan de travail par rangée de deux cases,
  /// un écran et un fauteuil par poste.
  void _desks(PlacedRoom room) {
    final seats = PlanGeometry.seatsIn(room);
    final x0 = room.x.toDouble();
    final x1 = room.right.toDouble();
    for (var pair = 0; pair < room.rows ~/ 2; pair++) {
      final top = room.y + pair * 2 + 0.2;
      final rowSeats = seats
          .where((s) => (s.y - top - 1.55).abs() < 0.01)
          .toList();
      // Profondeur du coin gauche : les postes, devant, passent après.
      _add(x0 + top + 1.1, () {
        desk(x0 + 0.3, top, x1 - 0.3, top + 1.05);
        for (final seat in rowSeats) {
          monitor(seat.x, top + 0.35, w: 1.2, seed: seat.x.toInt());
          keyboard(seat.x, top + 0.8);
        }
        if (room.type.look != RoomLook.workDesks) {
          deskLamp(Iso.pt(x0 + 0.8, top + 0.4, 22));
        }
      });
    }
  }

  // ----------------------------------------------------------- personnes

  void _people() {
    for (final entry in geometry.seats.entries) {
      final looks = occupants[entry.key] ?? const <PersonLook>[];
      for (var i = 0; i < entry.value.length; i++) {
        final seat = entry.value[i];
        final look = i < looks.length ? looks[i] : null;
        _add(seat.x + seat.y, () => _seat(seat, look));
      }
    }
  }

  /// Fauteuil d'un poste, vu de dos ; vide si le poste est vacant.
  void _seat(Seat seat, PersonLook? look) {
    if (look == null) {
      chair(seat.x, seat.y, back: 3, color: Tone.chairDark);
      return;
    }
    final at = Iso.pt(seat.x, seat.y);
    g
      ..oval(at + const Offset(1, 1), 9, 4, const Color(0x59000000))
      ..rect(at.dx - 6, at.dy - 1, 12, 2, Tone.metal)
      ..rect(at.dx - 1, at.dy - 9, 2, 9, Tone.metalLight)
      ..solid(
        seat.x - 0.5,
        seat.y - 0.5,
        seat.x + 0.5,
        seat.y + 0.5,
        9,
        12,
        Tone.chairDark,
      );
    drawPerson(
      canvas,
      at + const Offset(0, -8),
      look,
      pose: PersonPose.seated,
      back: true,
      raiseArm: (frame + seat.x.toInt()).isEven,
    );
    final rest = Iso.pt(seat.x, seat.y + 0.5, 12);
    g
      ..rect(rest.dx - 8, rest.dy - 19, 16, 18, const Color(0xFF1F2126))
      ..rect(rest.dx - 6, rest.dy - 17, 12, 1, const Color(0xFF34373E));
  }

  PersonLook _guest(int seed) {
    const skins = <Color>[
      Color(0xFFEBC29A),
      Color(0xFFA9714B),
      Color(0xFFD9A47A),
    ];
    const tops = <Color>[
      Color(0xFF8A5AA8),
      Color(0xFF3F6B4A),
      Color(0xFF6B7078),
    ];
    return PersonLook(
      skin: skins[seed % 3],
      hair: const Color(0xFF2B1F1C),
      top: tops[(seed ~/ 3) % 3],
      longHair: seed.isOdd,
    );
  }

  /// Monogramme de LeadDesk sur le mur du fond de l'accueil.
  void _welcomeSign(double cx, double y) {
    const mark = Color(0xFFF2B34C);
    g
      ..wallX(cx - 1.2, cx + 1.2, y + 0.05, 22, 52, const Color(0xFF2A2522))
      ..wallX(cx - 0.4, cx + 0.4, y + 0.05, 30, 46, mark)
      ..wallX(cx - 0.3, cx + 0.3, y + 0.05, 32, 44, const Color(0xFF2A2522))
      ..wallX(cx - 0.18, cx - 0.06, y + 0.05, 34, 42, mark)
      ..wallX(cx - 0.18, cx + 0.16, y + 0.05, 34, 36, mark);
  }

  // ------------------------------------------------------------- lumières

  void _lighting() {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final glow in glows) {
      paint.shader = ui.Gradient.radial(glow.center, glow.radius, <Color>[
        glow.color,
        glow.color.withValues(alpha: 0),
      ]);
      canvas.drawCircle(glow.center, glow.radius, paint);
    }
  }
}
