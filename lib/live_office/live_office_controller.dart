import 'package:flutter/foundation.dart';

import '../office/office_plan.dart';
import '../office/office_planner.dart';
import '../office/studio_template.dart';
import 'models.dart';

/// Ce que montre la carte.
enum OfficeViewMode {
  /// Le bureau entier : une ou plusieurs salles par département.
  plateau,

  /// La salle détaillée de référence.
  room,
}

/// État de l'écran du bureau vivant : sélection, panneaux, simulation,
/// conversation ouverte.
class LiveOfficeController extends ChangeNotifier {
  LiveOfficeController({
    this.agents = DemoData.agents,
    List<ChatEntry> conversation = DemoData.conversation,
    DateTime Function() now = DateTime.now,
    List<OfficeDepartment>? departments,
  }) : _entries = List<ChatEntry>.of(conversation),
       _clock = now,
       departments = departments ?? studioDepartments() {
    plan = const OfficePlanner().plan(this.departments);
  }

  /// Départements de l'entreprise, tels que l'aménagement les voit.
  final List<OfficeDepartment> departments;

  /// Plan d'aménagement en vigueur.
  late OfficePlan plan;

  OfficeViewMode _mode = OfficeViewMode.plateau;
  OfficeViewMode get mode => _mode;

  void toggleMode() {
    _mode = _mode == OfficeViewMode.plateau
        ? OfficeViewMode.room
        : OfficeViewMode.plateau;
    notifyListeners();
  }

  /// Agents d'un département, dans l'ordre de la liste.
  List<OfficeAgent> agentsOf(String departmentId) =>
      agents.where((a) => a.departmentId == departmentId).toList();

  /// Vitesses proposées par la barre de contrôle.
  static const List<int> speeds = <int>[1, 2, 4];

  final List<OfficeAgent> agents;
  final List<ChatEntry> _entries;
  final DateTime Function() _clock;

  /// Temps de la scène, en secondes : il avance selon la vitesse choisie et
  /// ne sert qu'à l'ambiance (RM-51).
  final ValueNotifier<double> sceneTime = ValueNotifier<double>(0);

  String? _selectedAgentId = 'atlas';
  String _query = '';
  bool _paused = false;
  bool _live = true;
  int _speed = speeds.first;
  bool _agentPanelOpen = true;
  bool _conversationOpen = true;

  List<ChatEntry> get entries => List<ChatEntry>.unmodifiable(_entries);
  String? get selectedAgentId => _selectedAgentId;
  String get query => _query;
  bool get paused => _paused;
  bool get live => _live;
  int get speed => _speed;
  bool get agentPanelOpen => _agentPanelOpen;
  bool get conversationOpen => _conversationOpen;

  OfficeAgent agentById(String id) => agents.firstWhere((a) => a.id == id);

  /// Agents correspondant à la recherche, regroupés par poste dans l'ordre
  /// de la liste.
  Map<String, List<OfficeAgent>> get agentsByPosition {
    final needle = _query.trim().toLowerCase();
    final groups = <String, List<OfficeAgent>>{};
    for (final agent in agents) {
      final matches =
          needle.isEmpty ||
          agent.name.toLowerCase().contains(needle) ||
          agent.position.toLowerCase().contains(needle) ||
          agent.status.toLowerCase().contains(needle);
      if (matches) {
        groups.putIfAbsent(agent.position, () => <OfficeAgent>[]).add(agent);
      }
    }
    return groups;
  }

  void selectAgent(String? id) {
    if (_selectedAgentId == id) {
      return;
    }
    _selectedAgentId = id;
    notifyListeners();
  }

  void search(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  void togglePaused() {
    _paused = !_paused;
    notifyListeners();
  }

  void toggleLive() {
    _live = !_live;
    notifyListeners();
  }

  /// Passe à la vitesse suivante, puis revient à la première.
  void cycleSpeed() {
    _speed = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    notifyListeners();
  }

  void toggleAgentPanel() {
    _agentPanelOpen = !_agentPanelOpen;
    notifyListeners();
  }

  void toggleConversation() {
    _conversationOpen = !_conversationOpen;
    notifyListeners();
  }

  /// Ajoute le message du CEO au fil. Un message vide est ignoré.
  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final now = _clock();
    String two(int value) => value.toString().padLeft(2, '0');
    _entries.add(
      UserMessage(time: '${two(now.hour)}:${two(now.minute)}', text: trimmed),
    );
    notifyListeners();
  }

  /// Fait avancer la scène du temps réel écoulé, multiplié par la vitesse.
  void advance(Duration elapsed) {
    if (_paused) {
      return;
    }
    sceneTime.value +=
        elapsed.inMicroseconds / Duration.microsecondsPerSecond * _speed;
  }

  @override
  void dispose() {
    sceneTime.dispose();
    super.dispose();
  }
}
