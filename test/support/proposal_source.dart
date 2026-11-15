import 'package:leaddesk_app/live_office/models.dart';
import 'package:leaddesk_app/live_office/office_source.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/office_planner.dart';
import 'package:leaddesk_app/office/studio_template.dart';

/// Source de démonstration avec un plan en vigueur et une proposition des
/// Moyens généraux : le studio grandit, la salle de jeux disparaît.
class ProposalSource implements OfficeSource, ProposalDecider {
  ProposalSource({this.failWith});

  /// Exception levée par les décisions, pour tester les erreurs.
  final Exception? failWith;

  final List<String> decisions = <String>[];
  bool decided = false;

  static OfficePlan currentPlan() =>
      const OfficePlanner().plan(studioDepartments());

  static OfficePlan proposedPlan() {
    final grown = const OfficePlanner().plan(studioDepartments(headcount: 3));
    final removable = grown.rooms.where(
      (room) => room.departmentId == null && room.typeId != 'reception',
    );
    final dropped = removable.isEmpty ? null : removable.last.id;
    return OfficePlan(
      cols: grown.cols,
      rows: grown.rows,
      rooms: <PlacedRoom>[
        for (final room in grown.rooms)
          if (room.id != dropped) room,
      ],
    );
  }

  @override
  Future<OfficeSnapshot> load() async => OfficeSnapshot(
    departments: studioDepartments(),
    plan: currentPlan(),
    planFromServer: true,
    agents: DemoData.agents,
    proposals: decided
        ? const <OfficeProposal>[]
        : <OfficeProposal>[
            OfficeProposal(
              id: 12,
              version: 4,
              plan: proposedPlan(),
              reason:
                  'Trois recrutements arrivent : chaque département gagne '
                  'un poste. La salle de jeux laisse sa place.',
              proposerName: 'Lisandre',
              proposerPosition: 'Responsable Moyens généraux',
            ),
          ],
  );

  @override
  Future<void> accept(int proposalId, {String? comment}) async {
    if (failWith case final error?) {
      throw error;
    }
    decisions.add('accept $proposalId');
    decided = true;
  }

  @override
  Future<void> reject(int proposalId, {String? comment}) async {
    if (failWith case final error?) {
      throw error;
    }
    decisions.add('reject $proposalId');
    decided = true;
  }
}
