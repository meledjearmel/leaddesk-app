import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/plan_editor.dart';

const _departments = <OfficeDepartment>[
  OfficeDepartment(id: 'a', name: 'Technique', color: 0xFF2BB5B0, headcount: 4),
  OfficeDepartment(id: 'b', name: 'Produit', color: 0xFF8B5CF6, headcount: 1),
];

OfficePlan _plan() => const OfficePlan(
  cols: 20,
  rows: 10,
  rooms: <PlacedRoom>[
    PlacedRoom(
      id: 'tech',
      typeId: 'open_space',
      departmentId: 'a',
      x: 0,
      y: 0,
      cols: 6,
      rows: 2,
    ),
    PlacedRoom(
      id: 'prod',
      typeId: 'private_office',
      departmentId: 'b',
      x: 8,
      y: 0,
      cols: 3,
      rows: 3,
    ),
  ],
);

void main() {
  test('le plan de départ est valable et rien n\'est à enregistrer', () {
    final editor = PlanEditor(_plan(), _departments);

    expect(editor.problems, isEmpty);
    expect(editor.dirty, isFalse);
    expect(editor.canSave, isFalse);
  });

  test('déplacer aimante à la grille et garde la salle dans le plan', () {
    final editor = PlanEditor(_plan(), _departments)..move('prod', 30, -4);

    final room = editor.plan.rooms.last;
    expect((room.x, room.y), (17, 0));
    expect(editor.dirty, isTrue);
    expect(editor.canSave, isTrue);
  });

  test('D-010 : un chevauchement est signalé en direct et bloque l\'enregistrement', () {
    final editor = PlanEditor(_plan(), _departments)..move('prod', 2, 0);

    expect(editor.problems.single, contains('se chevauchent'));
    expect(editor.canSave, isFalse);
  });

  test('annuler et rétablir', () {
    final editor = PlanEditor(_plan(), _departments)
      ..move('prod', 12, 4)
      ..remove('tech');
    expect(editor.plan.rooms, hasLength(1));

    editor.undo();
    expect(editor.plan.rooms, hasLength(2));
    editor.undo();
    expect(editor.dirty, isFalse);
    expect(editor.canUndo, isFalse);

    editor.redo();
    expect(editor.plan.rooms.last.x, 12);
  });

  test('la taille ne passe jamais sous le minimum du type', () {
    final editor = PlanEditor(_plan(), _departments)
      ..resize('tech', dCols: -3, dRows: -1);
    expect(editor.canUndo, isFalse);

    editor.resize('tech', dRows: 2);
    final room = editor.plan.rooms.first;
    expect(room.rows, 4);
    expect(room.seats, 8);
  });

  test('ajouter pose la salle à la première place libre et la choisit', () {
    final editor = PlanEditor(_plan(), _departments)
      ..add('private_office', departmentId: 'a');

    final added = editor.selected!;
    expect(added.typeId, 'private_office');
    expect(added.departmentId, 'a');
    expect(
      editor.plan.rooms.where((r) => r.id != added.id).any(added.overlaps),
      isFalse,
    );
  });

  test('un lieu commun ajouté n\'a jamais de département', () {
    final editor = PlanEditor(_plan(), _departments)
      ..add('micro_kitchen', departmentId: 'a');

    expect(editor.selected!.departmentId, isNull);
  });

  test('attribuer une salle à un autre département', () {
    final editor = PlanEditor(_plan(), _departments)..assign('prod', 'a');

    expect(editor.plan.rooms.last.departmentId, 'a');
    // Produit n'a plus de poste : la règle le signale.
    expect(editor.problems, contains("Produit n'a aucun poste de travail."));
  });
}
