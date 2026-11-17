import 'package:flutter/foundation.dart';

import '../admin/admin_models.dart';
import '../api/api_client.dart';

/// Affectation passée ou en cours d'un agent.
typedef AgentAssignment = ({
  String position,
  DateTime? startedAt,
  DateTime? endedAt,
});

/// Tâche confiée à un agent.
typedef AgentTask = ({int id, String title, bool done, bool lead});

/// Exécution d'une tâche par l'agent.
typedef AgentRun = ({
  int id,
  int taskId,
  String status,
  int costMicros,
  String? device,
  DateTime? startedAt,
});

/// Tout ce que la fiche montre d'un agent, lu sur le serveur.
class AgentDossier {
  const AgentDossier({
    required this.agent,
    this.position,
    this.unitPath = '',
    this.models = const <(String, bool)>[],
    this.assignments = const <AgentAssignment>[],
    this.tasks = const <AgentTask>[],
    this.runs = const <AgentRun>[],
  });

  final OrgAgent agent;
  final OrgPosition? position;

  /// « Technique › Développement ».
  final String unitPath;

  /// Modèles : nom affiché et « par défaut ».
  final List<(String, bool)> models;
  final List<AgentAssignment> assignments;
  final List<AgentTask> tasks;

  /// Exécutions, de la plus récente à la plus ancienne.
  final List<AgentRun> runs;

  /// Coût réel cumulé de ses exécutions.
  int get costMicros => runs.fold(0, (sum, r) => sum + r.costMicros);

  /// Exécution en cours, s'il y en a une.
  AgentRun? get currentRun {
    for (final run in runs) {
      if (run.status == 'running' ||
          run.status == 'paused' ||
          run.status == 'paused_cost') {
        return run;
      }
    }
    return null;
  }

  String? taskTitle(int id) {
    for (final task in tasks) {
      if (task.id == id) {
        return task.title;
      }
    }
    return null;
  }
}

/// Fiche d'un agent ouverte depuis le bureau (D-029).
class AgentSheetController extends ChangeNotifier {
  AgentSheetController(this.api);

  final ApiClient api;

  int? agentId;
  AgentDossier? dossier;
  bool loading = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;

  /// Charge la fiche ; un identifiant non numérique (démonstration) n'a
  /// pas de fiche sur le serveur.
  Future<void> open(String id) async {
    final parsed = int.tryParse(id);
    if (parsed == agentId && dossier != null) {
      return;
    }
    final generation = ++_generation;
    agentId = parsed;
    dossier = null;
    error = null;
    if (parsed == null) {
      _notify();
      return;
    }
    loading = true;
    _notify();
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        api.get('agents/$parsed'),
        api.getList('agents/$parsed/assignments'),
        api.getList('tasks?agent_id=$parsed'),
        api.getList('task-runs'),
        api.getList('positions'),
        api.getList('units'),
        api.getList('ai-providers'),
      ]);
      if (generation != _generation) {
        return;
      }
      final agent = OrgAgent.fromJson(results[0]! as Map<String, Object?>);
      List<Map<String, Object?>> at(int i) =>
          results[i]! as List<Map<String, Object?>>;
      final positions = at(4).map(OrgPosition.fromJson).toList();
      final units = <int, OrgUnit>{
        for (final u in at(5).map(OrgUnit.fromJson)) u.id: u,
      };
      final modelNames = <int, String>{
        for (final p in at(6).map(AiProviderEntry.fromJson))
          for (final m in p.models) m.id: m.displayName,
      };
      OrgPosition? position;
      for (final p in positions) {
        if (p.id == agent.positionId) {
          position = p;
        }
      }
      final path = <String>[];
      var unit = units[position?.unitId];
      for (var guard = 0; unit != null && guard < 20; guard++) {
        path.insert(0, unit.name);
        unit = units[unit.parentId];
      }
      DateTime? date(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();
      dossier = AgentDossier(
        agent: agent,
        position: position,
        unitPath: path.join(' › '),
        models: <(String, bool)>[
          for (final m in agent.models)
            (modelNames[m.aiModelId] ?? 'Modèle n°${m.aiModelId}', m.isDefault),
        ],
        assignments: <AgentAssignment>[
          for (final a in at(1))
            (
              position: a['position_title'] as String? ?? 'Poste retiré',
              startedAt: date(a['started_at']),
              endedAt: date(a['ended_at']),
            ),
        ],
        tasks: <AgentTask>[
          for (final t in at(2))
            (
              id: (t['id']! as num).toInt(),
              title: t['title'] as String? ?? '',
              done: t['completed_at'] != null,
              lead: <Object?>[...?t['agents'] as List<Object?>?]
                  .whereType<Map<String, Object?>>()
                  .any((a) => a['agent_id'] == parsed && a['is_lead'] == true),
            ),
        ],
        runs: <AgentRun>[
          for (final r in at(3))
            if (r['agent_id'] == parsed)
              (
                id: (r['id']! as num).toInt(),
                taskId: (r['task_id']! as num).toInt(),
                status: r['status'] as String? ?? '',
                costMicros: (r['cost_micros'] as num?)?.toInt() ?? 0,
                device: r['device_name'] as String?,
                startedAt: date(r['started_at']),
              ),
        ],
      );
    } on ApiException catch (e) {
      if (generation == _generation) {
        error = e.message;
      }
    } on Object {
      if (generation == _generation) {
        error = 'Serveur injoignable : la fiche n\'a pas pu être lue.';
      }
    }
    if (generation == _generation) {
      loading = false;
      _notify();
    }
  }

  /// Relit la fiche ouverte (après une modification).
  Future<void> refresh() async {
    final id = agentId;
    if (id == null) {
      return;
    }
    dossier = null;
    await open('$id');
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
