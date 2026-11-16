import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'agent_runner.dart';
import 'anthropic.dart';
import 'host.dart';
import 'model.dart';
import 'run_journal.dart';

/// Tâche proposée au lancement, avec les agents qui y sont affectés.
class RunnableTask {
  const RunnableTask({
    required this.id,
    required this.title,
    required this.agents,
  });

  factory RunnableTask.fromJson(Map<String, Object?> json) => RunnableTask(
    id: (json['id']! as num).toInt(),
    title: json['title'] as String? ?? 'Tâche ${json['id']}',
    agents: <(int, String, bool)>[
      for (final agent
          in (json['agents'] as List<Object?>? ?? const <Object?>[])
              .whereType<Map<String, Object?>>())
        (
          (agent['agent_id']! as num).toInt(),
          agent['name'] as String? ?? '',
          agent['is_lead'] == true,
        ),
    ],
  );

  final int id;
  final String title;

  /// (identifiant, nom, responsable).
  final List<(int, String, bool)> agents;
}

/// Exécution ouverte sur cet ordinateur, à reprendre (D-025).
class PendingRun {
  const PendingRun({
    required this.id,
    required this.taskId,
    required this.agentId,
    required this.status,
    this.reason,
  });

  factory PendingRun.fromJson(Map<String, Object?> json) => PendingRun(
    id: (json['id']! as num).toInt(),
    taskId: (json['task_id']! as num).toInt(),
    agentId: (json['agent_id']! as num).toInt(),
    status: json['status'] as String? ?? 'running',
    reason: json['status_reason'] as String?,
  );

  final int id;
  final int taskId;
  final int agentId;

  /// `running` (application fermée en cours de route), `paused` (par le
  /// CEO) ou `paused_cost` (limite de coût, en attente d'une décision).
  final String status;
  final String? reason;
}

/// État du panneau « Exécution » : clé du fournisseur, poste hôte, choix de
/// la tâche et de l'agent, étapes en direct (D-022), reprise (D-025).
class RunController extends ChangeNotifier {
  RunController({
    required this.api,
    required this.keys,
    required this.host,
    ModelProvider Function(String apiKey)? modelFactory,
    RunJournal? journal,
    this.watchEvery = const Duration(seconds: 5),
  }) : _modelFactory =
           modelFactory ?? ((key) => AnthropicProvider(apiKey: key)),
       journal = journal ?? FileRunJournal();

  final ApiClient api;
  final ProviderKeys keys;
  final HostDevice host;
  final RunJournal journal;

  /// Intervalle de surveillance d'une exécution en pause pour coût.
  final Duration watchEvery;
  final ModelProvider Function(String apiKey) _modelFactory;

  String? _keyMask;
  int? _deviceId;
  String? _deviceError;
  List<RunnableTask> _tasks = const <RunnableTask>[];
  List<PendingRun> _pending = const <PendingRun>[];
  int? _taskId;
  int? _agentId;
  bool _loading = false;
  bool _running = false;
  final List<RunStep> _steps = <RunStep>[];
  RunReport? _report;
  String? _error;
  Timer? _watch;
  bool _disposed = false;

  /// Fin de la clé enregistrée (`…a1b2`), `null` sans clé.
  String? get keyMask => _keyMask;
  bool get hasKey => _keyMask != null;
  int? get deviceId => _deviceId;
  String? get deviceError => _deviceError;
  List<RunnableTask> get tasks => _tasks;

  /// Exécutions ouvertes sur ce poste, hors celle qui tourne.
  List<PendingRun> get pending => _pending;
  bool get loading => _loading;
  bool get running => _running;
  List<RunStep> get steps => List<RunStep>.unmodifiable(_steps);
  RunReport? get report => _report;
  String? get error => _error;

  /// Vrai tant qu'une exécution en pause pour coût est surveillée.
  bool get waitingForDecision => _watch != null;

  RunnableTask? get task => _tasks.where((t) => t.id == _taskId).firstOrNull;
  int? get agentId => _agentId;
  String? get agentName =>
      task?.agents.where((a) => a.$1 == _agentId).firstOrNull?.$2;

  /// Titre d'une tâche connue, pour une exécution à reprendre.
  String taskTitle(int id) =>
      _tasks.where((t) => t.id == id).firstOrNull?.title ?? 'Tâche $id';

  /// Nom d'un agent connu par les tâches chargées.
  String agentNameOf(int id) =>
      _tasks.expand((t) => t.agents).where((a) => a.$1 == id).firstOrNull?.$2 ??
      'Agent $id';

  bool get canLaunch =>
      !_running &&
      hasKey &&
      _deviceId != null &&
      task != null &&
      _agentId != null;

  /// Pourquoi le lancement est impossible, pour l'expliquer au CEO.
  String? get blocker {
    if (!hasKey) {
      return 'Ajoutez une clé Anthropic dans les réglages pour lancer un agent.';
    }
    if (_deviceId == null) {
      return _deviceError ?? 'Enregistrement de cet ordinateur…';
    }
    if (_tasks.isEmpty && !_loading) {
      return 'Aucune tâche à lancer : créez-en une dans une activité.';
    }
    return null;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Lit la clé, enregistre le poste, charge les tâches et les exécutions
  /// ouvertes ; reprend d'elle-même une exécution interrompue par la
  /// fermeture de l'application.
  Future<void> load() async {
    _loading = true;
    _notify();
    final key = await keys.anthropic();
    _keyMask = key == null ? null : ProviderKeys.mask(key);
    try {
      _deviceId = await host.register();
      _deviceError = null;
    } on Object {
      _deviceError = 'Cet ordinateur n\'a pas pu être enregistré.';
    }
    try {
      _tasks = <RunnableTask>[
        for (final raw in await api.getList('tasks'))
          if (raw['completed_at'] == null) RunnableTask.fromJson(raw),
      ];
    } on Object {
      _error = 'Tâches illisibles : vérifiez la connexion au serveur.';
    }
    if (task == null && _tasks.isNotEmpty) {
      selectTask(_tasks.first.id);
    }
    await refreshPending();
    _loading = false;
    _notify();
    final interrupted = _pending
        .where((r) => r.status == 'running')
        .firstOrNull;
    if (interrupted != null && hasKey && !_running) {
      await resume(interrupted);
    }
  }

  /// Relit les exécutions ouvertes de ce poste.
  Future<void> refreshPending() async {
    final device = _deviceId;
    if (device == null) {
      return;
    }
    try {
      _pending = <PendingRun>[
        for (final raw in await api.getList(
          'task-runs?device_id=$device&open=1',
        ))
          PendingRun.fromJson(raw),
      ];
    } on Object {
      // Liste indisponible : on garde la précédente.
    }
    _notify();
  }

  void selectTask(int id) {
    _taskId = id;
    final agents = task?.agents ?? const <(int, String, bool)>[];
    _agentId =
        (agents.where((a) => a.$3).firstOrNull ?? agents.firstOrNull)?.$1;
    _notify();
  }

  void selectAgent(int id) {
    _agentId = id;
    _notify();
  }

  /// Enregistre la clé dans le stockage sécurisé ; vide, l'efface.
  Future<void> saveKey(String key) async {
    await keys.setAnthropic(key);
    final saved = await keys.anthropic();
    _keyMask = saved == null ? null : ProviderKeys.mask(saved);
    _notify();
  }

  /// Lance la tâche choisie avec l'agent choisi et suit ses étapes.
  Future<void> launch() async {
    final selected = task;
    final agent = _agentId;
    final device = _deviceId;
    if (selected == null || agent == null || device == null) {
      return;
    }
    await _execute(
      (runner) =>
          runner.start(taskId: selected.id, agentId: agent, deviceId: device),
    );
  }

  /// Reprend une exécution ouverte de ce poste. Une pause du CEO est levée ;
  /// une pause pour coût attend la décision dans « Décisions ».
  Future<void> resume(PendingRun run) async {
    final device = _deviceId;
    if (device == null || _running) {
      return;
    }
    if (run.status == 'paused_cost') {
      _error =
          'Cette exécution attend votre décision sur la limite de coût, '
          'dans « Décisions ».';
      _watchCost(run.id, run.taskId, run.agentId);
      _notify();
      return;
    }
    if (_tasks.any((t) => t.id == run.taskId)) {
      _taskId = run.taskId;
    }
    _agentId = run.agentId;
    await _execute((runner) async {
      if (run.status == 'paused') {
        await api.post('task-runs/${run.id}/resume');
      }
      return runner.run(
        TaskRunRef(
          id: run.id,
          taskId: run.taskId,
          agentId: run.agentId,
          deviceId: device,
        ),
      );
    });
  }

  Future<void> _execute(
    Future<RunReport> Function(AgentRunner runner) body,
  ) async {
    final key = await keys.anthropic();
    if (_running || key == null) {
      return;
    }
    _stopWatch();
    _running = true;
    _report = null;
    _error = null;
    _steps.clear();
    _notify();
    final runner = AgentRunner(
      api: api,
      model: _modelFactory(key),
      journal: journal,
    );
    final subscription = runner.steps.listen((step) {
      _steps.add(step);
      _notify();
    });
    try {
      _report = await body(runner);
    } on ApiException catch (error) {
      _error = error.message;
    } on Object catch (error) {
      _error = 'Exécution impossible : $error';
    } finally {
      await subscription.cancel();
      await runner.dispose();
      _running = false;
      _notify();
    }
    final report = _report;
    if (report?.outcome == RunOutcome.pausedCost && report?.runId != null) {
      final device = _deviceId;
      if (device != null) {
        _watchCost(report!.runId!, _taskId ?? 0, _agentId ?? 0);
      }
    }
    await refreshPending();
  }

  /// Surveille une exécution en pause pour coût : dès que le CEO relève la
  /// limite, elle reprend ; s'il refuse, la surveillance s'arrête.
  void _watchCost(int runId, int taskId, int agentId) {
    _stopWatch();
    _watch = Timer.periodic(watchEvery, (_) async {
      final Object? data;
      try {
        data = await api.get('task-runs/$runId');
      } on Object {
        return;
      }
      final status = data is Map<String, Object?> ? data['status'] : null;
      if (status == 'paused_cost' || _running || _disposed) {
        return;
      }
      _stopWatch();
      if (status == 'running') {
        await resume(
          PendingRun(
            id: runId,
            taskId: taskId,
            agentId: agentId,
            status: 'running',
          ),
        );
      } else {
        await journal.delete(runId);
        _error = 'Le CEO a arrêté cette exécution.';
        await refreshPending();
      }
    });
    _notify();
  }

  void _stopWatch() {
    _watch?.cancel();
    _watch = null;
  }

  /// Nouvelle exécution : on revient au choix de la tâche.
  void reset() {
    if (_running) {
      return;
    }
    _stopWatch();
    _report = null;
    _error = null;
    _steps.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopWatch();
    host.dispose();
    super.dispose();
  }
}
