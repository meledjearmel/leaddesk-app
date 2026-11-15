import 'room_catalog.dart';

/// Département vu par l'aménagement : son nom, sa couleur, son effectif et
/// ses activités. Il vient de l'organisation de l'entreprise (unités).
class OfficeDepartment {
  const OfficeDepartment({
    required this.id,
    required this.name,
    required this.color,
    required this.headcount,
    this.tags = const <String>{},
  });

  final String id;
  final String name;

  /// Couleur ARGB du département (liserés, étiquettes).
  final int color;

  /// Postes à installer : agents et postes vacants.
  final int headcount;
  final Set<String> tags;
}

/// Salle posée sur la grille du plan.
class PlacedRoom {
  const PlacedRoom({
    required this.id,
    required this.typeId,
    required this.x,
    required this.y,
    required this.cols,
    required this.rows,
    this.departmentId,
    this.name,
  });

  factory PlacedRoom.fromJson(Map<String, Object?> json) {
    return PlacedRoom(
      id: json['id']! as String,
      typeId: json['type']! as String,
      departmentId: json['department'] as String?,
      name: json['name'] as String?,
      x: (json['x']! as num).toInt(),
      y: (json['y']! as num).toInt(),
      cols: (json['cols']! as num).toInt(),
      rows: (json['rows']! as num).toInt(),
    );
  }

  final String id;
  final String typeId;

  /// Département propriétaire ; `null` pour un lieu commun.
  final String? departmentId;

  /// Nom affiché, si différent du nom du type.
  final String? name;
  final int x;
  final int y;
  final int cols;
  final int rows;

  RoomType get type => RoomCatalog.of(typeId);
  String get label => name ?? type.name;
  int get right => x + cols;
  int get bottom => y + rows;

  /// Postes de travail de la salle.
  int get seats => type.seatsFor(rows);

  bool overlaps(PlacedRoom other) {
    return x < other.right &&
        other.x < right &&
        y < other.bottom &&
        other.y < bottom;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': typeId,
    if (departmentId != null) 'department': departmentId,
    if (name != null) 'name': name,
    'x': x,
    'y': y,
    'cols': cols,
    'rows': rows,
  };
}

/// Plan d'aménagement : une grille et les salles qui l'occupent.
///
/// Un plan peut venir de l'aménageur automatique, d'une IA reliée au serveur
/// MCP de LeadDesk ou du CEO : dans tous les cas il passe par [validate].
class OfficePlan {
  const OfficePlan({
    required this.cols,
    required this.rows,
    required this.rooms,
  });

  factory OfficePlan.fromJson(Map<String, Object?> json) {
    final rooms = json['rooms']! as List<Object?>;
    return OfficePlan(
      cols: (json['cols']! as num).toInt(),
      rows: (json['rows']! as num).toInt(),
      rooms: <PlacedRoom>[
        for (final room in rooms)
          PlacedRoom.fromJson(room! as Map<String, Object?>),
      ],
    );
  }

  final int cols;
  final int rows;
  final List<PlacedRoom> rooms;

  Iterable<PlacedRoom> roomsOf(String departmentId) =>
      rooms.where((room) => room.departmentId == departmentId);

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'cols': cols,
    'rows': rows,
    'rooms': <Map<String, Object?>>[for (final room in rooms) room.toJson()],
  };

  /// Problèmes du plan, en français ; liste vide si le plan est valable.
  List<String> validate(List<OfficeDepartment> departments) {
    final problems = <String>[];
    final known = <String, OfficeDepartment>{
      for (final department in departments) department.id: department,
    };
    final ids = <String>{};

    for (final room in rooms) {
      final type = RoomCatalog.byId(room.typeId);
      if (!ids.add(room.id)) {
        problems.add('La salle « ${room.id} » apparaît deux fois.');
      }
      if (type == null) {
        problems.add('Type de salle inconnu : « ${room.typeId} ».');
        continue;
      }
      if (room.x < 0 || room.y < 0 || room.right > cols || room.bottom > rows) {
        problems.add('${room.label} dépasse du plan.');
      }
      if (room.cols < type.minCols || room.rows < type.minRows) {
        problems.add(
          '${room.label} est trop petite '
          '(${type.minCols} × ${type.minRows} cases au minimum).',
        );
      }
      final owner = room.departmentId;
      if (type.scope == RoomScope.shared && owner != null) {
        problems.add('${room.label} est un lieu commun : pas de département.');
      }
      if (type.scope == RoomScope.department) {
        if (owner == null) {
          problems.add('${room.label} doit appartenir à un département.');
        } else if (!known.containsKey(owner)) {
          problems.add('${room.label} : département inconnu « $owner ».');
        }
      }
    }

    for (var i = 0; i < rooms.length; i++) {
      for (var j = i + 1; j < rooms.length; j++) {
        if (rooms[i].overlaps(rooms[j])) {
          problems.add(
            '${rooms[i].label} et ${rooms[j].label} se chevauchent : '
            'deux départements ne partagent jamais une salle.',
          );
        }
      }
    }

    for (final department in departments) {
      final own = roomsOf(department.id).toList();
      final seats = own.fold<int>(0, (sum, room) => sum + room.seats);
      if (department.headcount > 0 && seats == 0) {
        problems.add('${department.name} n\'a aucun poste de travail.');
      } else if (seats < department.headcount) {
        problems.add(
          '${department.name} : $seats postes pour '
          '${department.headcount} personnes.',
        );
      }
    }
    return problems;
  }
}
