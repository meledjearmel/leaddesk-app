import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/models.dart';
import 'package:leaddesk_app/live_office/office_camera.dart';
import 'package:leaddesk_app/live_office/widgets/declutter.dart';
import 'package:leaddesk_app/live_office/widgets/map_overlays.dart';

OfficeAgent _agent(String id, {AgentState? state, String dept = 'd1'}) =>
    OfficeAgent(
      id: id,
      name: id,
      position: 'Poste',
      status: '',
      provider: AgentProvider.bot,
      avatar: const AvatarStyle(
        background: Color(0xFF000000),
        skin: Color(0xFF000000),
        hair: Color(0xFF000000),
        top: Color(0xFF000000),
      ),
      tagPlacement: TagPlacement.above,
      departmentId: dept,
      state: state,
    );

void main() {
  test('seuls les agents qui comptent gardent leur étiquette', () {
    final c = LiveOfficeController(
      agents: <OfficeAgent>[
        _agent('calme', state: AgentState.idle),
        _agent('travail', state: AgentState.working),
        _agent('attend', state: AgentState.waitingDecision),
        _agent('autre', state: AgentState.idle, dept: 'd2'),
      ],
    )..selectAgent(null);
    final layer = AgentTagLayer(
      controller: c,
      camera: OfficeCamera(),
      feetOf: (_, _) => null,
    );
    bool shown(String id, [double scale = 1]) =>
        layer.showsTag(c.agents.firstWhere((a) => a.id == id), scale);

    // Essentielles : l'attente d'une décision seulement.
    expect(shown('calme'), isFalse);
    expect(shown('travail'), isFalse);
    expect(shown('attend'), isTrue);

    // Survol et sélection font apparaître l'étiquette.
    c.hoverAgent('calme');
    expect(shown('calme'), isTrue);
    c
      ..hoverAgent(null)
      ..selectAgent('travail');
    expect(shown('travail'), isTrue);

    // De près, sans bureau visité : rien de plus.
    expect(shown('calme', 3), isFalse);

    // Toutes / aucune.
    c.cycleTagMode();
    expect(c.tagMode, TagMode.all);
    expect(shown('autre'), isTrue);
    c.cycleTagMode();
    expect(c.tagMode, TagMode.none);
    expect(shown('attend'), isFalse);
    expect(shown('travail'), isTrue);
    c.cycleTagMode();
    expect(c.tagMode, TagMode.essential);
    c.dispose();
  });

  testWidgets('au plus N étiquettes, la plus prioritaire toujours', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: DeclutteredTags(
            maxVisible: 2,
            entries: <TagEntry>[
              for (var i = 0; i < 5; i++)
                TagEntry(
                  id: 't$i',
                  anchor: Offset(100.0 + i * 150, 300),
                  priority: i == 4 ? 5 : 0,
                  child: const SizedBox(width: 100, height: 20),
                ),
            ],
          ),
        ),
      ),
    );

    final layout = lastDeclutterLayout;
    expect(layout['t4'], isNotNull);
    expect(layout.values.whereType<Rect>(), hasLength(2));
  });
}
