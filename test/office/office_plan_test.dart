import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/room_catalog.dart';
import 'package:leaddesk_app/office/studio_template.dart';

void main() {
  group('Catalogue des salles', () {
    test('contient les 27 salles demandées et des salles proposées', () {
      final requested = RoomCatalog.all.where((t) => !t.proposed);
      final proposed = RoomCatalog.all.where((t) => t.proposed);
      expect(requested, hasLength(27));
      expect(proposed, isNotEmpty);
    });

    test('les identifiants sont uniques et les étiquettes connues', () {
      final ids = RoomCatalog.all.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final type in RoomCatalog.all) {
        expect(ActivityTag.all, containsAll(type.tags), reason: type.id);
      }
    });

    test('RM-03 : aucune salle ne nomme un département', () {
      final names = studioDepartments().map((d) => d.id).toSet();
      for (final type in RoomCatalog.all) {
        expect(type.tags.intersection(names), isEmpty, reason: type.id);
      }
    });

    test('le nombre de rangées suffit à asseoir tout le monde', () {
      final openSpace = RoomCatalog.of('open_space');
      for (var people = 1; people <= 30; people++) {
        expect(
          openSpace.seatsFor(openSpace.rowsFor(people)),
          greaterThanOrEqualTo(people),
        );
      }
    });
  });

  group('Aménageur automatique', () {
    for (final headcount in <int>[1, 2, 5, 12]) {
      test('le plan du studio est valable avec $headcount personnes par '
          'département', () {
        final departments = studioDepartments(headcount: headcount);
        final plan = const OfficePlanner().plan(departments);
        expect(plan.validate(departments), isEmpty);
      });
    }

    test('chaque département a ses propres salles, jamais partagées', () {
      final departments = studioDepartments();
      final plan = const OfficePlanner().plan(departments);

      for (final department in departments) {
        expect(plan.roomsOf(department.id), isNotEmpty);
      }
      for (final room in plan.rooms) {
        if (room.type.scope == RoomScope.shared) {
          expect(room.departmentId, isNull);
        }
      }
    });

    test('les salles spécialisées suivent les activités', () {
      final departments = studioDepartments();
      final plan = const OfficePlanner().plan(departments);
      Set<String> typesOf(String id) =>
          plan.roomsOf(id).map((room) => room.typeId).toSet();

      expect(typesOf('direction'), contains('executive_office'));
      expect(typesOf('technique'), contains('server_room'));
      expect(typesOf('qualite'), contains('qa_lab'));
      expect(typesOf('rh'), contains('private_office'));
    });

    test('les lieux communs grandissent avec l\'entreprise', () {
      Set<String> shared(int headcount) => const OfficePlanner()
          .plan(studioDepartments(headcount: headcount))
          .rooms
          .where((room) => room.departmentId == null)
          .map((room) => room.typeId)
          .toSet();

      expect(shared(1), isNot(contains('lounge')));
      expect(shared(3), containsAll(<String>['lounge', 'library']));
      expect(
        shared(1),
        containsAll(<String>['reception', 'micro_kitchen', 'restrooms']),
      );
    });

    test(
      'les départements calmes sont au bout du plan, loin de l\'accueil',
      () {
        final departments = studioDepartments();
        final plan = const OfficePlanner().plan(departments);
        // Rang de lecture : aile par aile, de gauche à droite.
        int rank(String id) => plan
            .roomsOf(id)
            .map((r) => r.y * 1000 + r.x)
            .reduce((a, b) => a < b ? a : b);
        final busy = departments
            .where((d) => !d.tags.contains(ActivityTag.calm))
            .map((d) => rank(d.id));
        final quiet = departments
            .where((d) => d.tags.contains(ActivityTag.calm))
            .map((d) => rank(d.id));

        expect(
          quiet.reduce((a, b) => a < b ? a : b),
          greaterThan(busy.reduce((a, b) => a > b ? a : b)),
        );
      },
    );

    test('le plateau reste à peu près carré, même pour une grande '
        'entreprise', () {
      for (final headcount in <int>[1, 2, 6, 12]) {
        final plan = const OfficePlanner().plan(
          studioDepartments(headcount: headcount),
        );
        final ratio = plan.cols / plan.rows;
        expect(ratio, inInclusiveRange(0.5, 2.0), reason: '$headcount');
      }
    });

    test('une entreprise vierge garde les lieux communs (RM-02)', () {
      final plan = const OfficePlanner().plan(const <OfficeDepartment>[]);
      expect(plan.validate(const <OfficeDepartment>[]), isEmpty);
      expect(plan.rooms.map((r) => r.typeId), contains('reception'));
    });
  });

  group('Validation d\'un plan (proposé par une IA ou par le CEO)', () {
    const tech = OfficeDepartment(
      id: 'tech',
      name: 'Technique',
      color: 0xFF2BB5B0,
      headcount: 4,
    );
    const product = OfficeDepartment(
      id: 'produit',
      name: 'Produit',
      color: 0xFF8B5CF6,
      headcount: 2,
    );

    test('refuse deux départements dans la même salle', () {
      const plan = OfficePlan(
        cols: 20,
        rows: 10,
        rooms: <PlacedRoom>[
          PlacedRoom(
            id: 'a',
            typeId: 'open_space',
            departmentId: 'tech',
            x: 0,
            y: 0,
            cols: 6,
            rows: 4,
          ),
          PlacedRoom(
            id: 'b',
            typeId: 'open_space',
            departmentId: 'produit',
            x: 3,
            y: 2,
            cols: 6,
            rows: 4,
          ),
        ],
      );
      expect(
        plan.validate(const <OfficeDepartment>[tech, product]),
        contains(contains('ne partagent jamais une salle')),
      );
    });

    test('refuse les erreurs courantes d\'un plan', () {
      const plan = OfficePlan(
        cols: 10,
        rows: 6,
        rooms: <PlacedRoom>[
          PlacedRoom(id: 'x', typeId: 'piscine', x: 0, y: 0, cols: 2, rows: 2),
          PlacedRoom(
            id: 'cafe',
            typeId: 'micro_kitchen',
            departmentId: 'tech',
            x: 2,
            y: 0,
            cols: 4,
            rows: 3,
          ),
          PlacedRoom(
            id: 'srv',
            typeId: 'server_room',
            x: 6,
            y: 0,
            cols: 4,
            rows: 3,
          ),
          PlacedRoom(
            id: 'os',
            typeId: 'open_space',
            departmentId: 'tech',
            x: 7,
            y: 3,
            cols: 4,
            rows: 2,
          ),
        ],
      );
      final problems = plan.validate(const <OfficeDepartment>[tech, product]);

      expect(problems, contains(contains('Type de salle inconnu')));
      expect(problems, contains(contains('lieu commun')));
      expect(problems, contains(contains('doit appartenir à un département')));
      expect(problems, contains(contains('dépasse du plan')));
      expect(problems, contains(contains('trop petite')));
      expect(problems, contains('Produit n\'a aucun poste de travail.'));
    });

    test('un plan fait l\'aller-retour en JSON sans perte', () {
      final departments = studioDepartments();
      final plan = const OfficePlanner().plan(departments);
      final copy = OfficePlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, Object?>,
      );

      expect(jsonEncode(copy.toJson()), jsonEncode(plan.toJson()));
      expect(copy.validate(departments), isEmpty);
    });
  });
}
