import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/live_office/scene/department_office.dart';
import 'package:leaddesk_app/live_office/scene/iso.dart';
import 'package:leaddesk_app/live_office/scene/plan_scene.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/room_catalog.dart';
import 'package:leaddesk_app/office/studio_template.dart';

void main() {
  group('Bureau complet d\'un département (vue « Salle »)', () {
    for (final headcount in const <int>[1, 2, 5, 9]) {
      test('un poste de travail par poste du département ($headcount)', () {
        final departments = studioDepartments(headcount: headcount);
        final plan = const OfficePlanner().plan(departments);
        for (final department in departments) {
          final office = DepartmentOffice.compose(plan, department);
          expect(
            office.desks,
            hasLength(department.headcount),
            reason: department.name,
          );
        }
      });
    }

    test('réunit toutes les salles du département, et seulement elles, '
        'avec un coin café commun', () {
      final departments = studioDepartments(headcount: 4);
      final plan = const OfficePlanner().plan(departments);
      for (final department in departments) {
        final office = DepartmentOffice.compose(plan, department);
        expect(
          office.ownRooms.map((r) => r.id).toSet(),
          plan.roomsOf(department.id).map((r) => r.id).toSet(),
        );
        expect(office.cafe.departmentId, isNull);
        expect(office.cafe.type.look, anyOf(RoomLook.cafe, RoomLook.cafeteria));
        // Plan du bureau valable : rien ne se chevauche, assez de postes.
        expect(office.plan.validate(<OfficeDepartment>[department]), isEmpty);
        // Le couloir court devant toutes les salles.
        final deepest = office.plan.rooms
            .map((r) => r.bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(office.plan.rows, deepest + DepartmentOffice.corridorRows);
      }
    });

    test('la même organisation donne le même bureau', () {
      final departments = studioDepartments(headcount: 3);
      final plan = const OfficePlanner().plan(departments);
      for (final department in departments) {
        final a = DepartmentOffice.compose(plan, department);
        final b = DepartmentOffice.compose(
          OfficePlan.fromJson(plan.toJson()),
          department,
        );
        expect(a.plan.toJson(), b.plan.toJson());
        expect(
          <(double, double)>[for (final s in a.desks) (s.x, s.y)],
          <(double, double)>[for (final s in b.desks) (s.x, s.y)],
        );
      }
      // Empreinte stable, indépendante de String.hashCode.
      // Vecteurs de référence de FNV-1a 32 bits.
      expect(stableHash(''), 0x811c9dc5);
      expect(stableHash('a'), 0xe40c292c);
      expect(stableHash('foobar'), 0xbf9cf968);
    });

    testWidgets('le bureau meublé est dessiné à l\'identique d\'une fois '
        'à l\'autre', (tester) async {
      final departments = studioDepartments(headcount: 4);
      final plan = const OfficePlanner().plan(departments);
      for (final department in departments) {
        final office = DepartmentOffice.compose(plan, department);
        final bytes = <List<int>>[];
        await tester.runAsync(() async {
          for (var i = 0; i < 2; i++) {
            final image = renderPlanFrame(office.geometry, dense: true);
            final data = await image.toByteData();
            bytes.add(data!.buffer.asUint8List());
            image.dispose();
          }
        });
        expect(bytes[0], bytes[1], reason: department.name);
      }
    });

    test('rapproche des salles éloignées en gardant leur disposition', () {
      const department = OfficeDepartment(
        id: 'tech',
        name: 'Technique',
        color: 0xFF2BB5B0,
        headcount: 4,
      );
      const plan = OfficePlan(
        cols: 30,
        rows: 20,
        rooms: <PlacedRoom>[
          PlacedRoom(
            id: 'a',
            typeId: 'open_space',
            departmentId: 'tech',
            x: 3,
            y: 5,
            cols: 6,
            rows: 2,
          ),
          PlacedRoom(
            id: 'b',
            typeId: 'server_room',
            departmentId: 'tech',
            x: 20,
            y: 5,
            cols: 4,
            rows: 3,
          ),
        ],
      );
      final office = DepartmentOffice.compose(plan, department);
      final a = office.plan.rooms.firstWhere((r) => r.id == 'a');
      final b = office.plan.rooms.firstWhere((r) => r.id == 'b');
      expect((a.x, a.y), (0, 0));
      expect((b.x, b.y), (6, 0));
      // Pas de café dans le plan : un petit coin café est ajouté au bout.
      expect(office.cafe.id, 'cafe');
      expect(office.cafe.x, 10);
    });

    test('ajoute un open space quand les salles manquent de postes', () {
      const department = OfficeDepartment(
        id: 'tech',
        name: 'Technique',
        color: 0xFF2BB5B0,
        headcount: 7,
      );
      const plan = OfficePlan(
        cols: 10,
        rows: 4,
        rooms: <PlacedRoom>[
          PlacedRoom(
            id: 'a',
            typeId: 'open_space',
            departmentId: 'tech',
            x: 0,
            y: 0,
            cols: 6,
            rows: 2,
          ),
        ],
      );
      final office = DepartmentOffice.compose(plan, department);
      expect(office.desks, hasLength(7));
      expect(office.ownRooms, hasLength(2));
    });

    test('un département sans salle reçoit un open space', () {
      const department = OfficeDepartment(
        id: 'neuf',
        name: 'Nouveau',
        color: 0xFF2BB5B0,
        headcount: 2,
      );
      const plan = OfficePlan(cols: 4, rows: 4, rooms: <PlacedRoom>[]);
      final office = DepartmentOffice.compose(plan, department);
      expect(office.desks, hasLength(2));
      expect(office.ownRooms.single.typeId, 'open_space');
    });
  });
}
