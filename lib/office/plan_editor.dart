import 'package:flutter/foundation.dart';

import 'office_plan.dart';
import 'room_catalog.dart';

/// Brouillon d'aménagement modifié à la main par le CEO (D-016).
///
/// Chaque modification passe par la grille (positions entières, salle dans
/// le plan) et garde un historique pour Annuler / Rétablir. Les règles sont
/// recalculées à chaque changement : un brouillon invalide ne s'enregistre
/// pas.
class PlanEditor extends ChangeNotifier {
  PlanEditor(this.initial, this.departments) : _plan = initial;

  /// Plan de départ (le plan en vigueur).
  final OfficePlan initial;
  final List<OfficeDepartment> departments;

  OfficePlan _plan;
  final List<OfficePlan> _undo = <OfficePlan>[];
  final List<OfficePlan> _redo = <OfficePlan>[];
  String? _selectedId;
  int _counter = 0;

  /// Nombre maximal de cases d'un côté du plan (comme sur le serveur).
  static const int maxSide = 200;

  OfficePlan get plan => _plan;
  String? get selectedId => _selectedId;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Vrai quand le brouillon diffère du plan de départ.
  bool get dirty => !identical(_plan, initial) && _undo.isNotEmpty;

  /// Problèmes du brouillon, mêmes règles que le serveur.
  List<String> get problems => _plan.validate(departments);

  bool get canSave => dirty && problems.isEmpty;

  PlacedRoom? get selected => _roomById(_selectedId);

  PlacedRoom? _roomById(String? id) {
    for (final room in _plan.rooms) {
      if (room.id == id) {
        return room;
      }
    }
    return null;
  }

  void select(String? id) {
    if (_selectedId == id) {
      return;
    }
    _selectedId = id;
    notifyListeners();
  }

  void _commit(OfficePlan next) {
    _undo.add(_plan);
    _redo.clear();
    _plan = next;
    notifyListeners();
  }

  OfficePlan _withRooms(List<PlacedRoom> rooms, {int? cols, int? rows}) =>
      OfficePlan(
        cols: cols ?? _plan.cols,
        rows: rows ?? _plan.rows,
        rooms: rooms,
      );

  PlacedRoom _copy(
    PlacedRoom room, {
    int? x,
    int? y,
    int? cols,
    int? rows,
    String? departmentId,
    bool clearDepartment = false,
  }) => PlacedRoom(
    id: room.id,
    typeId: room.typeId,
    name: room.name,
    departmentId: clearDepartment ? null : (departmentId ?? room.departmentId),
    x: x ?? room.x,
    y: y ?? room.y,
    cols: cols ?? room.cols,
    rows: rows ?? room.rows,
  );

  List<PlacedRoom> _replace(PlacedRoom updated) => <PlacedRoom>[
    for (final room in _plan.rooms) room.id == updated.id ? updated : room,
  ];

  /// Déplace une salle, aimantée à la grille et gardée dans le plan.
  void move(String id, int x, int y) {
    final room = _roomById(id);
    if (room == null) {
      return;
    }
    final nx = x.clamp(0, _plan.cols - room.cols);
    final ny = y.clamp(0, _plan.rows - room.rows);
    if (nx == room.x && ny == room.y) {
      return;
    }
    _commit(_withRooms(_replace(_copy(room, x: nx, y: ny))));
  }

  /// Agrandit ou réduit une salle de [dCols] × [dRows] cases, sans passer
  /// sous la taille minimale de son type ni sortir du plan.
  void resize(String id, {int dCols = 0, int dRows = 0}) {
    final room = _roomById(id);
    final type = room == null ? null : RoomCatalog.byId(room.typeId);
    if (room == null || type == null) {
      return;
    }
    final cols = (room.cols + dCols).clamp(type.minCols, _plan.cols - room.x);
    final rows = (room.rows + dRows).clamp(type.minRows, _plan.rows - room.y);
    if (cols == room.cols && rows == room.rows) {
      return;
    }
    _commit(_withRooms(_replace(_copy(room, cols: cols, rows: rows))));
  }

  /// Attribue une salle à un département, ou en fait un lieu commun.
  void assign(String id, String? departmentId) {
    final room = _roomById(id);
    if (room == null || room.departmentId == departmentId) {
      return;
    }
    _commit(
      _withRooms(
        _replace(
          _copy(
            room,
            departmentId: departmentId,
            clearDepartment: departmentId == null,
          ),
        ),
      ),
    );
  }

  void remove(String id) {
    if (_roomById(id) == null) {
      return;
    }
    if (_selectedId == id) {
      _selectedId = null;
    }
    _commit(
      _withRooms(<PlacedRoom>[
        for (final room in _plan.rooms)
          if (room.id != id) room,
      ]),
    );
  }

  /// Ajoute une salle du catalogue à sa taille minimale (avec assez de
  /// rangées pour deux postes), à la première place libre ; le plan
  /// s'agrandit vers le bas s'il le faut.
  void add(String typeId, {String? departmentId}) {
    final type = RoomCatalog.byId(typeId);
    if (type == null) {
      return;
    }
    final cols = type.minCols;
    final rows = type.hasDesks ? type.rowsFor(2) : type.minRows;
    var id = '';
    do {
      id = '${typeId}_${++_counter}';
    } while (_roomById(id) != null);

    final (x, y) = _freeSpot(cols, rows);
    final room = PlacedRoom(
      id: id,
      typeId: typeId,
      departmentId: type.scope == RoomScope.department ? departmentId : null,
      x: x,
      y: y,
      cols: cols,
      rows: rows,
    );
    final planRows = (y + rows).clamp(_plan.rows, maxSide);
    _selectedId = id;
    _commit(_withRooms(<PlacedRoom>[..._plan.rooms, room], rows: planRows));
  }

  (int, int) _freeSpot(int cols, int rows) {
    bool free(int x, int y) {
      final probe = PlacedRoom(
        id: '_',
        typeId: 'open_space',
        x: x,
        y: y,
        cols: cols,
        rows: rows,
      );
      return !_plan.rooms.any(probe.overlaps);
    }

    for (var y = 0; y + rows <= _plan.rows; y++) {
      for (var x = 0; x + cols <= _plan.cols; x++) {
        if (free(x, y)) {
          return (x, y);
        }
      }
    }
    final bottom = _plan.rooms.fold<int>(
      0,
      (max, room) => room.bottom > max ? room.bottom : max,
    );
    return (0, bottom + 1);
  }

  void undo() {
    if (_undo.isEmpty) {
      return;
    }
    _redo.add(_plan);
    _plan = _undo.removeLast();
    if (_roomById(_selectedId) == null) {
      _selectedId = null;
    }
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) {
      return;
    }
    _undo.add(_plan);
    _plan = _redo.removeLast();
    notifyListeners();
  }
}
