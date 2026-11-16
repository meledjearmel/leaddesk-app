import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'agent_runner.dart';
import 'anthropic.dart';
import 'host.dart';
import 'model.dart';

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

/// État du panneau « Exécution » : clé du fournisseur, poste hôte, choix de
/// la tâche et de l'agent, étapes en direct (D-022).
class RunController extends ChangeNotifier {
  RunController({
    required this.api,
    required this.keys,
    required this.host,
    ModelProvider Function(String apiKey)? modelFactory,
  }) : _modelFactory =
           modelFactory ?? ((key) => AnthropicProvider(apiKey: key));

  final ApiClient api;
  final ProviderKeys keys;
  final HostDevice host;
  final ModelProvider Function(String apiKey) _modelFactory;

  String? _keyMask;
  int? _deviceId;
  String? _deviceError;
  List<RunnableTask> _tasks = const <RunnableTask>[];
  int? _taskId;
  int? _agentId;
  bool _loading = false;
  bool _running = false;
  final List<RunStep> _steps = <RunStep>[];
  RunReport? _report;
  String? _error;
  bool _disposed = false;

  /// Fin de la clé enregistrée (`…a1b2`), `null` sans clé.
  String? get keyMask => _keyMask;
  bool get hasKey => _keyMask != null;
  int? get deviceId => _deviceId;
  String? get deviceError => _deviceError;
  List<RunnableTask> get tasks => _tasks;
  bool get loading => _loading;
  bool get running => _running;
  List<RunStep> get steps => List<RunStep>.unmodifiable(_steps);
  RunReport? get report => _report;
  String? get error => _error;

  RunnableTask? get task => _tasks.where((t) => t.id == _taskId).firstOrNull;
  int? get agentId => _agentId;
  String? get agentName =>
      task?.agents.where((a) => a.$1 == _agentId).firstOrNull?.$2;

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

  /// Lit la clé, enregistre le poste et charge les tâches.
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
    _loading = false;
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
    final key = await keys.anthropic();
    final selected = task;
    final agent = _agentId;
    final device = _deviceId;
    if (_running ||
        key == null ||
        selected == null ||
        agent == null ||
        device == null) {
      return;
    }
    _running = true;
    _report = null;
    _error = null;
    _steps.clear();
    _notify();
    final model = _modelFactory(key);
    final runner = AgentRunner(api: api, model: model);
    final subscription = runner.steps.listen((step) {
      _steps.add(step);
      _notify();
    });
    try {
      _report = await runner.start(
        taskId: selected.id,
        agentId: agent,
        deviceId: device,
      );
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
  }

  /// Nouvelle exécution : on revient au choix de la tâche.
  void reset() {
    if (_running) {
      return;
    }
    _report = null;
    _error = null;
    _steps.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    host.dispose();
    super.dispose();
  }
}
