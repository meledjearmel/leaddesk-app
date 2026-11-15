import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../office/office_plan.dart';
import '../office/office_planner.dart';
import '../office/studio_template.dart';
import 'models.dart';

/// Réaménagement proposé par un poste des Moyens généraux, en attente du
/// CEO (D-012).
class OfficeProposal {
  const OfficeProposal({
    required this.id,
    required this.version,
    required this.plan,
    this.reason,
    this.proposerName,
    this.proposerPosition,
  });

  final int id;
  final int version;
  final OfficePlan plan;

  /// Motif donné par le poste qui propose.
  final String? reason;

  /// Agent et poste qui proposent, s'ils sont connus.
  final String? proposerName;
  final String? proposerPosition;
}

/// Décisions du CEO sur une proposition.
abstract interface class ProposalDecider {
  Future<void> accept(int proposalId, {String? comment});
  Future<void> reject(int proposalId, {String? comment});
}

/// Ce que montre le bureau vivant : départements, plan et agents.
class OfficeSnapshot {
  const OfficeSnapshot({
    required this.departments,
    required this.plan,
    required this.agents,
    this.planFromServer = false,
    this.proposals = const <OfficeProposal>[],
  });

  final List<OfficeDepartment> departments;
  final OfficePlan plan;
  final List<OfficeAgent> agents;

  /// Propositions en attente, de la plus récente à la plus ancienne.
  final List<OfficeProposal> proposals;

  /// Plan en vigueur sur le serveur, s'il y en a un et qu'il est affiché.
  OfficePlan? get serverPlan => planFromServer ? plan : null;

  /// Vrai quand le plan est celui en vigueur sur le serveur ; faux quand il
  /// vient de l'aménageur automatique.
  final bool planFromServer;
}

/// Source des données du bureau.
abstract interface class OfficeSource {
  Future<OfficeSnapshot> load();
}

/// Données de démonstration : le modèle studio et ses agents.
class DemoOfficeSource implements OfficeSource {
  const DemoOfficeSource();

  static OfficeSnapshot snapshot() {
    final departments = studioDepartments();
    return OfficeSnapshot(
      departments: departments,
      plan: const OfficePlanner().plan(departments),
      agents: DemoData.agents,
    );
  }

  @override
  Future<OfficeSnapshot> load() async => snapshot();
}

/// Données lues sur le serveur (D-014) : départements d'aménagement, plan en
/// vigueur, unités, postes et agents.
///
/// Sans plan en vigueur, ou si le plan du serveur ne respecte plus les règles
/// (organisation changée depuis), l'aménageur automatique prend le relais.
class ApiOfficeSource implements OfficeSource, ProposalDecider {
  const ApiOfficeSource(this.client);

  final ApiClient client;

  @override
  Future<OfficeSnapshot> load() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      client.getList('office/departments'),
      client.get('office/plan'),
      client.getList('units'),
      client.getList('positions'),
      client.getList('agents'),
      client.getList('office/plans?status=proposed'),
    ]);
    final departments = <OfficeDepartment>[
      for (final (i, raw)
          in (results[0]! as List<Map<String, Object?>>).indexed)
        OfficeDepartment(
          id: raw['id']! as String,
          name: raw['name']! as String,
          color: parseColor(raw['color'] as String?) ?? fallbackColor(i),
          headcount: (raw['headcount']! as num).toInt(),
          tags: <String>{...(raw['tags']! as List<Object?>).cast<String>()},
        ),
    ];

    final server = results[1] is Map<String, Object?>
        ? (results[1]! as Map<String, Object?>)['layout']
        : null;
    OfficePlan? plan;
    if (server is Map<String, Object?>) {
      final candidate = OfficePlan.fromJson(server);
      if (candidate.validate(departments).isEmpty) {
        plan = candidate;
      }
    }

    final rawAgents = results[4]! as List<Map<String, Object?>>;
    final positions = results[3]! as List<Map<String, Object?>>;
    return OfficeSnapshot(
      departments: departments,
      plan: plan ?? const OfficePlanner().plan(departments),
      planFromServer: plan != null,
      agents: buildAgents(
        units: results[2]! as List<Map<String, Object?>>,
        positions: positions,
        agents: rawAgents,
      ),
      proposals: <OfficeProposal>[
        for (final raw in results[5]! as List<Map<String, Object?>>)
          if (raw['layout'] case final Map<String, Object?> layout)
            OfficeProposal(
              id: (raw['id']! as num).toInt(),
              version: (raw['version']! as num).toInt(),
              plan: OfficePlan.fromJson(layout),
              reason: raw['reason'] as String?,
              proposerName: _field(
                rawAgents,
                raw['proposed_by_agent_id'],
                'name',
              ),
              proposerPosition: _field(
                positions,
                raw['proposed_by_position_id'],
                'title',
              ),
            ),
      ],
    );
  }

  static String? _field(
    List<Map<String, Object?>> rows,
    Object? id,
    String field,
  ) {
    for (final row in rows) {
      if (id != null && row['id'] == id) {
        return row[field] as String?;
      }
    }
    return null;
  }

  @override
  Future<void> accept(int proposalId, {String? comment}) => client.post(
    'office/plans/$proposalId/accept',
    <String, Object?>{'comment': ?comment},
  );

  @override
  Future<void> reject(int proposalId, {String? comment}) => client.post(
    'office/plans/$proposalId/reject',
    <String, Object?>{'comment': ?comment},
  );

  /// Agents occupant un poste, rattachés au département (unité de premier
  /// niveau) de leur poste. Les agents sans poste ne sont pas au bureau.
  static List<OfficeAgent> buildAgents({
    required List<Map<String, Object?>> units,
    required List<Map<String, Object?>> positions,
    required List<Map<String, Object?>> agents,
  }) {
    final parents = <int, int?>{
      for (final unit in units)
        (unit['id']! as num).toInt(): (unit['parent_id'] as num?)?.toInt(),
    };
    int rootOf(int unit) {
      var current = unit;
      final seen = <int>{};
      while (seen.add(current)) {
        final parent = parents[current];
        if (parent == null || !parents.containsKey(parent)) {
          break;
        }
        current = parent;
      }
      return current;
    }

    final byId = <int, Map<String, Object?>>{
      for (final position in positions)
        (position['id']! as num).toInt(): position,
    };

    return <OfficeAgent>[
      for (final (i, agent) in agents.indexed)
        if (byId[(agent['position_id'] as num?)?.toInt()] case final position?)
          OfficeAgent(
            id: '${agent['id']}',
            name: agent['name']! as String,
            position: position['title']! as String,
            status: statusLabel(agent['status'] as String?),
            provider: AgentProvider.bot,
            avatar: avatarFor(i),
            tagPlacement: TagPlacement.values[i % TagPlacement.values.length],
            departmentId: '${rootOf((position['unit_id']! as num).toInt())}',
            working: agent['status'] == 'active',
          ),
    ];
  }

  static String statusLabel(String? status) => switch (status) {
    'active' => 'En service',
    'draft' => 'En brouillon',
    _ => 'Inconnu',
  };

  /// `#RRGGBB` en couleur ARGB opaque.
  static int? parseColor(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return null;
    }
    return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
  }

  /// Couleurs des départements sans couleur, dans l'esprit du thème.
  static int fallbackColor(int index) => const <int>[
    0xFFF2B34C,
    0xFF8B5CF6,
    0xFF2BB5B0,
    0xFF3B6FE0,
    0xFFE5484D,
    0xFFF08A5D,
    0xFF3FA65A,
    0xFFC08A3A,
  ][index % 8];

  /// Portraits originaux, attribués à tour de rôle.
  static AvatarStyle avatarFor(int index) {
    const backgrounds = <Color>[
      Color(0xFF3A2A22),
      Color(0xFF233238),
      Color(0xFF2F2540),
      Color(0xFF2A3424),
    ];
    const skins = <Color>[
      Color(0xFFEBC29A),
      Color(0xFFA9714B),
      Color(0xFFD9A47A),
      Color(0xFF6B4A32),
    ];
    const hairs = <Color>[
      Color(0xFF2B1F1C),
      Color(0xFF4A2E1E),
      Color(0xFF8A6A4A),
    ];
    const tops = <Color>[
      Color(0xFFC0563A),
      Color(0xFF3B6FE0),
      Color(0xFF3FA65A),
      Color(0xFF8B5CF6),
      Color(0xFFF2B34C),
    ];
    return AvatarStyle(
      background: backgrounds[index % backgrounds.length],
      skin: skins[(index * 3) % skins.length],
      hair: hairs[(index * 2) % hairs.length],
      top: tops[index % tops.length],
      glasses: index % 4 == 1,
      longHair: index % 3 == 0,
    );
  }
}
