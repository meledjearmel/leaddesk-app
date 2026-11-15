import 'office_plan.dart';

/// Nature d'un changement entre deux plans.
enum RoomChangeKind {
  added('Ajoutée', 'ajoutées'),
  removed('Retirée', 'retirées'),
  moved('Déplacée', 'déplacées'),
  resized('Redimensionnée', 'redimensionnées'),
  reassigned('Change de département', 'changent de département');

  const RoomChangeKind(this.label, this.plural);

  final String label;

  /// Libellé après un nombre de salles supérieur à un.
  final String plural;
}

/// Changement d'une salle, repérée par son identifiant dans le plan.
class RoomChange {
  const RoomChange(this.kind, {this.before, this.after});

  final RoomChangeKind kind;
  final PlacedRoom? before;
  final PlacedRoom? after;

  /// La salle telle qu'elle sera (ou telle qu'elle était si elle disparaît).
  PlacedRoom get room => after ?? before!;
}

/// Différences entre le plan en vigueur et un plan proposé (D-015).
///
/// Une salle garde son identifiant d'un plan à l'autre ; une salle qui change
/// à la fois de place et de taille est « redimensionnée », une salle qui
/// change de département l'est avant tout.
class PlanDiff {
  PlanDiff._(this.changes);

  factory PlanDiff.compare(OfficePlan? current, OfficePlan proposed) {
    final before = <String, PlacedRoom>{
      for (final room in current?.rooms ?? const <PlacedRoom>[]) room.id: room,
    };
    final after = <String, PlacedRoom>{
      for (final room in proposed.rooms) room.id: room,
    };
    final changes = <RoomChange>[];

    for (final room in proposed.rooms) {
      final old = before[room.id];
      if (old == null) {
        changes.add(RoomChange(RoomChangeKind.added, after: room));
      } else if (old.departmentId != room.departmentId ||
          old.typeId != room.typeId) {
        changes.add(
          RoomChange(RoomChangeKind.reassigned, before: old, after: room),
        );
      } else if (old.cols != room.cols || old.rows != room.rows) {
        changes.add(
          RoomChange(RoomChangeKind.resized, before: old, after: room),
        );
      } else if (old.x != room.x || old.y != room.y) {
        changes.add(RoomChange(RoomChangeKind.moved, before: old, after: room));
      }
    }
    for (final room in current?.rooms ?? const <PlacedRoom>[]) {
      if (!after.containsKey(room.id)) {
        changes.add(RoomChange(RoomChangeKind.removed, before: room));
      }
    }
    return PlanDiff._(List<RoomChange>.unmodifiable(changes));
  }

  final List<RoomChange> changes;

  bool get isEmpty => changes.isEmpty;

  Iterable<RoomChange> of(RoomChangeKind kind) =>
      changes.where((change) => change.kind == kind);

  /// Vrai quand des salles disparaissent : l'acceptation demande une
  /// confirmation.
  bool get removesRooms => of(RoomChangeKind.removed).isNotEmpty;

  /// Changement d'une salle du plan proposé, s'il y en a un.
  RoomChange? changeOf(String roomId) {
    for (final change in changes) {
      if (change.after?.id == roomId) {
        return change;
      }
    }
    return null;
  }
}
