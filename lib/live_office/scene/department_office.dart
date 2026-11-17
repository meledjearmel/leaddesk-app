import 'dart:math';
import 'dart:ui';

import '../../office/office_plan.dart';
import '../../office/room_catalog.dart';
import 'plan_scene.dart';

/// Pose d'un agent hors de son poste, en coordonnées de la grille.
class WalkPose {
  const WalkPose(
    this.at, {
    required this.walking,
    required this.faceLeft,
    this.step = 0,
    this.atCafe = false,
  });

  final Offset at;
  final bool walking;
  final bool faceLeft;

  /// Pas de la marche, de 0 à 3.
  final int step;

  /// Vrai quand il est au café (une tasse à la main).
  final bool atCafe;
}

/// Bureau complet d'un département, tel que la vue « Salle » le montre.
///
/// Composé à partir du plan d'aménagement, sans rien dessiner :
/// - toutes les salles que le plan attribue au département, à leur place
///   relative, les cases vides entre elles retirées ;
/// - un couloir devant elles ;
/// - le coin café le plus proche du plan, en annexe au bout (un lieu commun
///   n'appartient à aucun département) ; un petit coin café sinon ;
/// - exactement un poste de travail par poste du département
///   ([OfficeDepartment.headcount]) : les agents s'y assoient dans l'ordre,
///   les postes restants sont vacants (D-031).
///
/// La composition ne dépend que du plan et du département : la même
/// organisation donne toujours le même bureau.
class DepartmentOffice {
  DepartmentOffice._(this.department, this.plan, this._seatLimits);

  factory DepartmentOffice.compose(
    OfficePlan source,
    OfficeDepartment department,
  ) {
    final rooms = _assemble(source.roomsOf(department.id).toList());

    // Postes : autant que de postes du département. Si les salles de
    // travail n'y suffisent pas (plan périmé), un open space s'ajoute.
    final capacity = rooms.fold<int>(0, (sum, room) => sum + room.seats);
    final missing = department.headcount - capacity;
    if (missing > 0) {
      final type = RoomCatalog.of(_extraWorkRoom);
      rooms.add(
        PlacedRoom(
          id: '${department.id}-$_extraWorkRoom-extra',
          typeId: type.id,
          departmentId: department.id,
          x: _right(rooms),
          y: 0,
          cols: type.minCols,
          rows: type.rowsFor(missing),
        ),
      );
    }
    final limits = <String, int>{};
    var remaining = department.headcount;
    for (final room in rooms) {
      if (room.type.hasDesks) {
        final n = min(room.seats, remaining);
        limits[room.id] = n;
        remaining -= n;
      }
    }

    rooms.add(_cafe(source, department, x: _right(rooms)));

    final laid = _layOut(rooms);
    final depth = laid.fold<int>(0, (m, room) => max(m, room.bottom));
    return DepartmentOffice._(
      department,
      OfficePlan(cols: _right(laid), rows: depth + corridorRows, rooms: laid),
      limits,
    );
  }

  /// Rangées du couloir, devant les salles et entre deux rangées de salles.
  static const int corridorRows = 2;

  /// Profondeur minimale d'une rangée de salles : la place du mobilier.
  static const int minDepth = 4;

  /// Largeur au-delà de laquelle une rangée unique passe sur deux rangées,
  /// de part et d'autre du couloir (comme sur les images de référence).
  static const int maxRowCols = 16;

  /// Disposition finale. Quand le plan aligne les salles sur une seule
  /// rangée, celles-ci prennent la même profondeur ; une rangée trop large
  /// est coupée en deux, de part et d'autre d'un couloir, dans l'ordre du
  /// plan. Une disposition sur plusieurs rangées est gardée telle quelle.
  static List<PlacedRoom> _layOut(List<PlacedRoom> rooms) {
    if (rooms.any((room) => room.y != 0)) {
      return rooms;
    }
    final total = rooms.fold<int>(0, (sum, room) => sum + room.cols);
    final widest = rooms.fold<int>(0, (m, room) => max(m, room.cols));
    final limit = total > maxRowCols && rooms.length >= 3
        ? max(widest, (total + 1) ~/ 2)
        : total;
    final lines = <List<PlacedRoom>>[<PlacedRoom>[]];
    var width = 0;
    for (final room in rooms) {
      if (lines.last.isNotEmpty && width + room.cols > limit) {
        lines.add(<PlacedRoom>[]);
        width = 0;
      }
      lines.last.add(room);
      width += room.cols;
    }
    final lineCols = lines
        .map((line) => line.fold<int>(0, (s, r) => s + r.cols))
        .reduce(max);
    final result = <PlacedRoom>[];
    var top = 0;
    for (final line in lines) {
      final depth = max(minDepth, line.map((r) => r.rows).reduce(max));
      var x = 0;
      for (final (i, room) in line.indexed) {
        // La dernière salle de la rangée la complète jusqu'au bout.
        final cols = i == line.length - 1 ? lineCols - x : room.cols;
        result.add(
          PlacedRoom(
            id: room.id,
            typeId: room.typeId,
            departmentId: room.departmentId,
            name: room.name,
            x: x,
            y: top,
            cols: cols,
            rows: depth,
          ),
        );
        x += cols;
      }
      top += depth + corridorRows;
    }
    return result;
  }

  static const String _extraWorkRoom = 'open_space';
  static const String _cafeRoom = 'micro_kitchen';

  final OfficeDepartment department;

  /// Plan du bureau, dans son propre repère (origine au coin du fond).
  final OfficePlan plan;
  final Map<String, int> _seatLimits;

  /// Géométrie de la scène : taille, postes, emprise.
  late final PlanGeometry geometry = PlanGeometry(plan, <OfficeDepartment>[
    department,
  ], seatLimits: _seatLimits);

  /// Postes de travail, dans l'ordre où les agents s'assoient.
  List<Seat> get desks => geometry.seats[department.id] ?? const <Seat>[];

  /// Coin café du bureau (lieu commun, sans département).
  PlacedRoom get cafe => plan.rooms.last;

  /// Salles du département, sans le coin café.
  List<PlacedRoom> get ownRooms =>
      plan.rooms.where((room) => room.departmentId == department.id).toList();

  // ------------------------------------------------- agents hors du poste

  /// Où l'agent du poste [desk] se tient quand il attend le CEO.
  Offset standingSpot(int desk) => standingSpotOf(desks[desk]);

  /// Places debout autour de la table du café, en coordonnées de la grille.
  late final List<Offset> cafeSpots = () {
    final table = cafeTableOf(cafe);
    final spots = <Offset>[
      table + const Offset(0.95, 0.35),
      table + const Offset(-0.7, 1.0),
      table + const Offset(0.85, -0.75),
      table + const Offset(-1.0, -0.85),
      table + const Offset(0.2, 1.55),
    ];
    return <Offset>[
      for (final s in spots)
        Offset(
          s.dx.clamp(cafe.x + 0.4, cafe.right - 0.4),
          s.dy.clamp(cafe.y + 1.2, cafe.bottom - 0.3),
        ),
    ];
  }();

  /// Allée du couloir qui dessert le café, et l'entrée du café (sa porte,
  /// côté intérieur).
  late final (double, Offset) _cafeAccess = () {
    final doorX = cafe.x + cafe.cols ~/ 2 + 0.5;
    // Café dans une rangée de devant : il s'ouvre sur l'allée du fond.
    final front = plan.rooms.any((room) => room.bottom <= cafe.y);
    if (front) {
      return (cafe.y - corridorRows / 2, Offset(doorX, cafe.y + 0.7));
    }
    return (cafe.bottom + corridorRows / 2, Offset(doorX, cafe.bottom - 0.7));
  }();

  /// Vitesse de marche, en cases par seconde.
  static const double walkSpeed = 1.1;

  /// Position, à l'instant [time] (secondes de scène), du [slot]-ième agent
  /// parti de son poste (en pause ou disponible). Il boit un café, sort,
  /// longe le couloir jusqu'à une porte, s'arrête, puis revient : chemins
  /// simples, en lignes droites. Tout dépend de [slot] et de [time] : le
  /// mouvement est le même d'une fois à l'autre.
  WalkPose awayPose(int slot, double time) {
    final spot = cafeSpots[slot % cafeSpots.length];
    final (lane, entry) = _cafeAccess;
    // Une porte du couloir, la plus éloignée du café d'abord, à tour de
    // rôle ; le bout du couloir s'il n'y en a pas d'autre.
    final targets =
        <double>{
          for (final room in plan.rooms) room.x + room.cols ~/ 2 + 0.5,
          0.8,
          plan.cols - 0.8,
        }.where((x) => (x - entry.dx).abs() >= 2).toList()..sort(
          (a, b) => (b - entry.dx).abs().compareTo((a - entry.dx).abs()),
        );
    final targetX = targets.isEmpty ? entry.dx : targets[slot % targets.length];
    final path = <Offset>[
      spot,
      entry,
      Offset(entry.dx, lane),
      Offset(targetX.clamp(0.5, plan.cols - 0.5), lane),
    ];
    final legs = <double>[
      for (var i = 1; i < path.length; i++) (path[i] - path[i - 1]).distance,
    ];
    final length = legs.fold<double>(0, (a, b) => a + b);
    final stay = 9.0 + (slot % 3) * 2;
    const pause = 3.0;
    final walk = length / walkSpeed;
    final cycle = stay + 2 * walk + pause;
    final t = (time + slot * 5.3) % cycle;

    final table = cafeTableOf(cafe);
    if (t < stay || length == 0) {
      // Au café, tourné vers la table.
      return WalkPose(
        spot,
        walking: false,
        faceLeft: (table.dx - spot.dx) - (table.dy - spot.dy) < 0,
        atCafe: true,
      );
    }
    final double along;
    if (t < stay + walk) {
      along = (t - stay) * walkSpeed;
    } else if (t < stay + walk + pause) {
      return WalkPose(path.last, walking: false, faceLeft: slot.isOdd);
    } else {
      along = length - (t - stay - walk - pause) * walkSpeed;
    }
    final returning = t >= stay + walk + pause;
    var rest = along.clamp(0.0, length);
    for (var i = 1; i < path.length; i++) {
      final leg = legs[i - 1];
      if (rest <= leg || i == path.length - 1) {
        final from = path[i - 1];
        final to = path[i];
        final k = leg == 0 ? 0.0 : (rest / leg).clamp(0.0, 1.0);
        final at = Offset.lerp(from, to, k)!;
        var dx = to.dx - from.dx;
        var dy = to.dy - from.dy;
        if (returning) {
          dx = -dx;
          dy = -dy;
        }
        return WalkPose(
          at,
          walking: true,
          // Vers la gauche de l'écran quand x décroît plus que y.
          faceLeft: dx - dy < 0,
          step: (along * 4).floor() % 4,
        );
      }
      rest -= leg;
    }
    return WalkPose(spot, walking: false, faceLeft: false, atCafe: true);
  }

  static int _right(List<PlacedRoom> rooms) =>
      rooms.fold<int>(0, (m, room) => max(m, room.right));

  /// Rapproche les salles : garde leur disposition relative, retire les
  /// colonnes et les rangées qu'aucune d'elles n'occupe, puis cale le tout
  /// sur l'origine. Sans salle, un open space minimal.
  static List<PlacedRoom> _assemble(List<PlacedRoom> own) {
    if (own.isEmpty) {
      return <PlacedRoom>[];
    }
    final cols = <int>{
      for (final room in own)
        for (var c = room.x; c < room.right; c++) c,
    }.toList()..sort();
    final rows = <int>{
      for (final room in own)
        for (var r = room.y; r < room.bottom; r++) r,
    }.toList()..sort();
    int rank(List<int> sorted, int value) {
      var n = 0;
      for (final v in sorted) {
        if (v < value) {
          n++;
        }
      }
      return n;
    }

    return <PlacedRoom>[
      for (final room in own)
        PlacedRoom(
          id: room.id,
          typeId: room.typeId,
          departmentId: room.departmentId,
          name: room.name,
          x: rank(cols, room.x),
          y: rank(rows, room.y),
          cols: room.cols,
          rows: room.rows,
        ),
    ];
  }

  /// Coin café : celui du plan le plus proche du département, à sa taille ;
  /// un coin café minimal si le plan n'en a pas.
  static PlacedRoom _cafe(
    OfficePlan source,
    OfficeDepartment department, {
    required int x,
  }) {
    final own = source.roomsOf(department.id).toList();
    double distance(PlacedRoom room) {
      if (own.isEmpty) {
        return 0;
      }
      return own
          .map(
            (o) =>
                ((o.x + o.cols / 2) - (room.x + room.cols / 2)).abs() +
                ((o.y + o.rows / 2) - (room.y + room.rows / 2)).abs(),
          )
          .reduce(min);
    }

    final cafes =
        source.rooms
            .where(
              (room) =>
                  room.departmentId == null &&
                  (room.type.look == RoomLook.cafe ||
                      room.type.look == RoomLook.cafeteria),
            )
            .toList()
          ..sort((a, b) {
            final byDistance = distance(a).compareTo(distance(b));
            return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
          });
    final type = RoomCatalog.of(_cafeRoom);
    final found = cafes.firstOrNull;
    return PlacedRoom(
      id: found?.id ?? 'cafe',
      typeId: found?.typeId ?? type.id,
      name: found?.name,
      x: x,
      y: 0,
      cols: found?.cols ?? type.minCols,
      rows: found?.rows ?? type.minRows,
    );
  }
}
