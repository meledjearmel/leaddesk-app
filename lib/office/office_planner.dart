import 'office_plan.dart';
import 'room_catalog.dart';

/// Aménageur automatique : à partir des départements, de leur effectif et de
/// leurs activités, il choisit les salles de chacun et les pose sur la grille.
///
/// Règles :
/// - chaque département a ses propres salles ; deux départements ne
///   partagent jamais une salle (seuls les lieux communs sont partagés) ;
/// - une salle de travail par département, assez grande pour son effectif
///   (postes vacants compris) ; bureau de direction pour l'activité
///   `direction`, bureau individuel pour un petit département calme ;
/// - jusqu'à [maxSpecialRooms] salles spécialisées choisies d'après les
///   activités du département ;
/// - lieux communs (accueil, café, réunion, sanitaires, puis salon et
///   bibliothèque quand l'effectif grandit) au début de l'aile avant ;
/// - les départements qui partagent des activités sont voisins, les
///   départements calmes vont au bout du plan.
///
/// C'est aussi la solution de repli quand aucune IA d'aménagement n'est
/// disponible : son résultat respecte toujours [OfficePlan.validate].
class OfficePlanner {
  const OfficePlanner({this.maxSpecialRooms = 2, this.corridorRows = 2});

  final int maxSpecialRooms;

  /// Largeur de l'allée entre les deux ailes, en cases.
  final int corridorRows;

  /// Seuil d'effectif à partir duquel on ajoute un salon, puis une
  /// bibliothèque.
  static const int loungeFrom = 12;
  static const int libraryFrom = 20;

  OfficePlan plan(List<OfficeDepartment> departments) {
    final blocks = <_Block>[
      _sharedBlock(departments.fold(0, (sum, d) => sum + d.headcount)),
      for (final department in _order(departments))
        _departmentBlock(department),
    ];

    // Les blocs remplissent des ailes successives, séparées par des allées,
    // dans l'ordre de voisinage. On choisit la largeur d'aile qui donne le
    // plateau le plus proche du carré.
    final narrowest = blocks.fold(0, (m, b) => b.cols > m ? b.cols : m);
    final total = blocks.fold(0, (sum, b) => sum + b.cols);
    List<List<_Block>>? best;
    var bestScore = double.infinity;
    for (var limit = narrowest; limit <= total; limit++) {
      final wings = _wings(blocks, limit);
      final cols = wings.map(_width).reduce((a, b) => a > b ? a : b);
      final rows = _rowsOf(wings);
      final score = (cols - rows).abs() + (cols * rows) / 1000;
      if (score < bestScore) {
        bestScore = score;
        best = wings;
      }
    }
    final wings = best!;

    // Le bout d'une aile plus courte que les autres accueille un lieu
    // commun : terrasse, salle de jeux ou salle de sieste selon la place.
    final planCols = wings.map(_width).reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < wings.length; i++) {
      final wing = wings[i];
      final free = planCols - _width(wing);
      final depth = _depth(wing);
      for (final id in <String>['terrace', 'game_room', 'nap_room']) {
        final type = RoomCatalog.of(id);
        if (free >= type.minCols && depth >= type.minRows) {
          wing.add(
            _Block(id: 'aile$i', rooms: <_Room>[_Room(id, free, depth)]),
          );
          break;
        }
      }
    }

    final rooms = <PlacedRoom>[];
    var top = 0;
    for (final wing in wings) {
      var x = 0;
      for (final block in wing) {
        var rx = x;
        for (final room in block.rooms) {
          rooms.add(
            PlacedRoom(
              id: '${block.id}-${room.typeId}',
              typeId: room.typeId,
              departmentId: block.departmentId,
              x: rx,
              y: top,
              cols: room.cols,
              rows: block.rows,
            ),
          );
          rx += room.cols;
        }
        x += block.cols;
      }
      top += _depth(wing) + corridorRows;
    }

    return OfficePlan(
      cols: wings.map(_width).reduce((a, b) => a > b ? a : b),
      rows: _rowsOf(wings),
      rooms: rooms,
    );
  }

  static int _width(List<_Block> wing) => wing.fold(0, (s, b) => s + b.cols);

  static int _depth(List<_Block> wing) =>
      wing.fold(0, (m, b) => b.rows > m ? b.rows : m);

  int _rowsOf(List<List<_Block>> wings) =>
      wings.fold(0, (s, w) => s + _depth(w)) +
      corridorRows * (wings.length - 1);

  static List<List<_Block>> _wings(List<_Block> blocks, int limit) {
    final wings = <List<_Block>>[<_Block>[]];
    for (final block in blocks) {
      if (wings.last.isNotEmpty && _width(wings.last) + block.cols > limit) {
        wings.add(<_Block>[]);
      }
      wings.last.add(block);
    }
    return wings;
  }

  /// Ordre des départements : on part de la direction (ou du plus grand),
  /// puis on enchaîne chaque fois sur le département qui partage le plus
  /// d'activités avec le précédent ; les départements calmes ferment la
  /// marche.
  List<OfficeDepartment> _order(List<OfficeDepartment> departments) {
    bool calm(OfficeDepartment d) => d.tags.contains(ActivityTag.calm);
    final busy = departments.where((d) => !calm(d)).toList();
    final quiet = departments.where(calm).toList();

    final ordered = <OfficeDepartment>[];
    if (busy.isNotEmpty) {
      var current = busy.firstWhere(
        (d) => d.tags.contains(ActivityTag.management),
        orElse: () => busy.reduce((a, b) => b.headcount > a.headcount ? b : a),
      );
      busy.remove(current);
      ordered.add(current);
      while (busy.isNotEmpty) {
        final previous = current;
        int shared(OfficeDepartment d) =>
            d.tags.intersection(previous.tags).length;
        current = busy.reduce((a, b) => shared(b) > shared(a) ? b : a);
        busy.remove(current);
        ordered.add(current);
      }
    }
    return <OfficeDepartment>[...ordered, ...quiet];
  }

  _Block _departmentBlock(OfficeDepartment department) {
    final tags = department.tags;
    final RoomType work;
    if (tags.contains(ActivityTag.management)) {
      work = RoomCatalog.of('executive_office');
    } else if (tags.contains(ActivityTag.calm) && department.headcount <= 2) {
      work = RoomCatalog.of('private_office');
    } else {
      work = RoomCatalog.of('open_space');
    }

    // Salles spécialisées : celles qui servent le plus d'activités du
    // département, dans l'ordre du catalogue à égalité.
    final candidates =
        RoomCatalog.all
            .where(
              (type) =>
                  type.scope == RoomScope.department &&
                  !type.hasDesks &&
                  type.tags.intersection(tags).isNotEmpty,
            )
            .toList()
          ..sort(
            (a, b) => b.tags
                .intersection(tags)
                .length
                .compareTo(a.tags.intersection(tags).length),
          );
    final special = <RoomType>[];
    final looks = <RoomLook>{};
    for (final type in candidates) {
      // Pas deux salles qui se ressemblent dans le même département.
      if (special.length < maxSpecialRooms && looks.add(type.look)) {
        special.add(type);
      }
    }

    final workRows = work.rowsFor(department.headcount);
    return _Block(
      id: department.id,
      departmentId: department.id,
      rooms: <_Room>[
        _Room(work.id, work.minCols, workRows),
        for (final type in special) _Room(type.id, type.minCols, type.minRows),
      ],
    );
  }

  _Block _sharedBlock(int headcount) {
    final ids = <String>[
      'reception',
      'micro_kitchen',
      'meeting_room',
      if (headcount >= loungeFrom) 'lounge',
      if (headcount >= libraryFrom) 'library',
      'restrooms',
    ];
    return _Block(
      id: 'commun',
      rooms: <_Room>[
        for (final id in ids)
          _Room(id, RoomCatalog.of(id).minCols, RoomCatalog.of(id).minRows),
      ],
    );
  }
}

class _Room {
  const _Room(this.typeId, this.cols, this.rows);

  final String typeId;
  final int cols;
  final int rows;
}

class _Block {
  _Block({required this.id, required this.rooms, this.departmentId});

  final String id;
  final String? departmentId;
  final List<_Room> rooms;

  int get cols => rooms.fold(0, (sum, room) => sum + room.cols);
  int get rows =>
      rooms.fold(0, (max, room) => room.rows > max ? room.rows : max);
}
