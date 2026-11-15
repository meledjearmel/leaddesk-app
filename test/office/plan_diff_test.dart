import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/plan_diff.dart';

PlacedRoom _room(
  String id, {
  String type = 'open_space',
  String? department = 'a',
  int x = 0,
  int y = 0,
  int cols = 6,
  int rows = 2,
}) => PlacedRoom(
  id: id,
  typeId: type,
  departmentId: department,
  x: x,
  y: y,
  cols: cols,
  rows: rows,
);

OfficePlan _plan(List<PlacedRoom> rooms) =>
    OfficePlan(cols: 40, rows: 20, rooms: rooms);

void main() {
  test('une salle identique ne change pas', () {
    final diff = PlanDiff.compare(
      _plan(<PlacedRoom>[_room('a')]),
      _plan(<PlacedRoom>[_room('a')]),
    );

    expect(diff.isEmpty, isTrue);
    expect(diff.removesRooms, isFalse);
  });

  test('ajout, retrait, déplacement, taille et département', () {
    final diff = PlanDiff.compare(
      _plan(<PlacedRoom>[
        _room('moved'),
        _room('resized'),
        _room('reassigned'),
        _room('gone'),
      ]),
      _plan(<PlacedRoom>[
        _room('moved', x: 4),
        _room('resized', rows: 4, x: 2),
        _room('reassigned', department: 'b', rows: 4),
        _room('new'),
      ]),
    );

    RoomChangeKind kindOf(String id) =>
        diff.changes.firstWhere((change) => change.room.id == id).kind;

    expect(kindOf('moved'), RoomChangeKind.moved);
    // Taille et place changent : la taille l'emporte.
    expect(kindOf('resized'), RoomChangeKind.resized);
    // Le département l'emporte sur tout le reste.
    expect(kindOf('reassigned'), RoomChangeKind.reassigned);
    expect(kindOf('new'), RoomChangeKind.added);
    expect(kindOf('gone'), RoomChangeKind.removed);
    expect(diff.removesRooms, isTrue);
    expect(diff.changeOf('gone'), isNull);
    expect(diff.changeOf('new')!.kind, RoomChangeKind.added);
  });

  test('sans plan en vigueur, toutes les salles sont ajoutées', () {
    final diff = PlanDiff.compare(
      null,
      _plan(<PlacedRoom>[_room('a'), _room('b', y: 3)]),
    );

    expect(diff.of(RoomChangeKind.added), hasLength(2));
    expect(diff.removesRooms, isFalse);
  });
}
