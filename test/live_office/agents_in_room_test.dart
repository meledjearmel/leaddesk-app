import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/live_office/models.dart';
import 'package:leaddesk_app/live_office/scene/department_office.dart';
import 'package:leaddesk_app/live_office/scene/presence.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

void main() {
  group('Agents dans le bureau de leur département', () {
    test('chaque état réel a sa place', () {
      // Au travail : assis, écran allumé.
      expect(AgentState.working.seat.presence, SeatPresence.seated);
      expect(AgentState.working.seat.screen, ScreenMode.code);
      // Attend une décision ou limite de coût : debout près du bureau.
      for (final state in <AgentState>[
        AgentState.waitingDecision,
        AgentState.pausedCost,
      ]) {
        expect(state.seat.presence, SeatPresence.standing, reason: '$state');
        expect(state.seat.screen, ScreenMode.waiting, reason: '$state');
      }
      // En pause ou disponible : au café ou dans le couloir.
      for (final state in <AgentState>[AgentState.paused, AgentState.idle]) {
        expect(state.seat.presence, SeatPresence.away, reason: '$state');
      }
      // Bloqué : assis devant un écran rouge.
      expect(AgentState.blocked.seat.screen, ScreenMode.error);
      // Attend son ordinateur, brouillon : assis, écran en veille.
      expect(AgentState.waitingHost.seat.screen, ScreenMode.standby);
      expect(AgentState.draft.seat.presence, SeatPresence.seated);
    });

    test('un poste vacant reste un bureau vide, chaise rentrée (D-031)', () {
      for (final state in AgentState.values) {
        expect(seatViewOf(occupied: false, state: state.seat), (
          ChairPosition.tucked,
          ScreenMode.off,
          null,
        ), reason: '$state');
      }
      // Un agent parti laisse sa chaise reculée, pas rentrée.
      expect(
        seatViewOf(occupied: true, state: AgentState.idle.seat).$1,
        ChairPosition.pulledOut,
      );
      expect(seatViewOf(occupied: true, state: AgentState.working.seat), (
        ChairPosition.occupied,
        ScreenMode.code,
        SeatPresence.seated,
      ));
    });

    test('debout, l\'agent reste à côté de son propre bureau', () {
      final departments = studioDepartments(headcount: 5);
      final plan = const OfficePlanner().plan(departments);
      for (final department in departments) {
        final office = DepartmentOffice.compose(plan, department);
        for (var i = 0; i < office.desks.length; i++) {
          final desk = office.desks[i];
          final spot = office.standingSpot(i);
          expect(
            (spot - Offset(desk.x, desk.y)).distance,
            lessThan(1),
            reason: '${department.name}, poste $i',
          );
        }
      }
    });

    group('agents en pause : café et couloir', () {
      final departments = studioDepartments(headcount: 4);
      final plan = const OfficePlanner().plan(departments);

      for (final department in departments) {
        test('chemins simples et continus (${department.name})', () {
          final office = DepartmentOffice.compose(plan, department);
          final cafe = office.cafe;
          for (var slot = 0; slot < 4; slot++) {
            var sawCafe = false;
            var sawWalk = false;
            WalkPose? previous;
            for (var t = 0.0; t < 90; t += 0.1) {
              final pose = office.awayPose(slot, t);
              sawCafe |= pose.atCafe;
              sawWalk |= pose.walking;
              final at = pose.at;
              // Toujours dans le bureau.
              expect(at.dx, inInclusiveRange(0, office.plan.cols));
              expect(at.dy, inInclusiveRange(0, office.plan.rows));
              // Jamais dans une autre salle que le café : on reste au café,
              // dans le couloir ou dans l'embrasure de sa porte.
              for (final room in office.plan.rooms) {
                if (room == cafe) {
                  continue;
                }
                final inside =
                    at.dx > room.x + 0.05 &&
                    at.dx < room.right - 0.05 &&
                    at.dy > room.y + 0.05 &&
                    at.dy < room.bottom - 0.05;
                expect(
                  inside,
                  isFalse,
                  reason: '${room.id} à t=$t (slot $slot) : $at',
                );
              }
              // Pas de saut : au plus la vitesse de marche.
              if (previous != null) {
                expect(
                  (at - previous.at).distance,
                  lessThanOrEqualTo(DepartmentOffice.walkSpeed * 0.1 + 1e-6),
                  reason: 't=$t (slot $slot)',
                );
              }
              previous = pose;
            }
            expect(sawCafe, isTrue);
            expect(sawWalk, isTrue);
          }
        });
      }

      test('mouvement déterministe', () {
        final a = DepartmentOffice.compose(plan, departments[2]);
        final b = DepartmentOffice.compose(
          OfficePlan.fromJson(plan.toJson()),
          departments[2],
        );
        for (var t = 0.0; t < 60; t += 1.7) {
          expect(a.awayPose(1, t).at, b.awayPose(1, t).at);
        }
      });
    });
  });
}
