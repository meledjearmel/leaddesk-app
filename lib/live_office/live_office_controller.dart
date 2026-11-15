import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../office/office_plan.dart';
import '../office/office_planner.dart';
import '../office/studio_template.dart';
import 'models.dart';
import 'office_source.dart';

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
    List<OfficeAgent>? agents,
    List<ChatEntry> conversation = DemoData.conversation,
    DateTime Function() now = DateTime.now,
    List<OfficeDepartment>? departments,
  }) : _entries = List<ChatEntry>.of(conversation),
       _clock = now,
       _agents = agents ?? DemoData.agents,
       _departments = departments ?? studioDepartments() {
    _plan = const OfficePlanner().plan(_departments);
  }

  List<OfficeDepartment> _departments;
  late OfficePlan _plan;
  List<OfficeAgent> _agents;
  int _revision = 0;
  bool _fromServer = false;
  String? _loadError;

  /// Départements de l'entreprise, tels que l'aménagement les voit.
  List<OfficeDepartment> get departments => _departments;

  /// Plan d'aménagement affiché : celui en vigueur sur le serveur, ou celui
  /// de l'aménageur automatique ; le plan proposé pendant son aperçu.
  OfficePlan get plan => previewing ? openProposal!.plan : _plan;

  /// Plan en vigueur, même pendant l'aperçu d'une proposition.
  OfficePlan get currentPlan => _plan;

  List<OfficeProposal> _proposals = const <OfficeProposal>[];
  OfficePlan? _serverPlan;
  int? _openProposalId;
  bool _previewing = false;
  bool _deciding = false;
  String? _decisionError;
  OfficeSource? _source;

  /// Propositions d'aménagement en attente du CEO (D-012).
  List<OfficeProposal> get proposals => _proposals;

  /// Plan en vigueur sur le serveur, base de la comparaison.
  OfficePlan? get serverPlan => _serverPlan;

  /// Proposition ouverte dans le panneau de validation.
  OfficeProposal? get openProposal {
    for (final proposal in _proposals) {
      if (proposal.id == _openProposalId) {
        return proposal;
      }
    }
    return null;
  }

  /// Vrai quand la carte montre le plan proposé au lieu du plan en vigueur.
  bool get previewing => _previewing && openProposal != null;

  bool get deciding => _deciding;
  String? get decisionError => _decisionError;

  /// Ouvre une proposition et montre son plan sur la carte.
  void openProposalPanel(int id) {
    _openProposalId = id;
    _previewing = true;
    _decisionError = null;
    _mode = OfficeViewMode.plateau;
    _revision++;
    notifyListeners();
  }

  void closeProposalPanel() {
    if (_openProposalId == null) {
      return;
    }
    final wasPreviewing = previewing;
    _openProposalId = null;
    _previewing = false;
    _decisionError = null;
    if (wasPreviewing) {
      _revision++;
    }
    notifyListeners();
  }

  /// Bascule la carte entre le plan en vigueur et le plan proposé.
  void showProposedPlan({required bool proposed}) {
    if (_previewing == proposed || openProposal == null) {
      return;
    }
    _previewing = proposed;
    _revision++;
    notifyListeners();
  }

  /// Accepte ou refuse la proposition ouverte, puis recharge le bureau.
  Future<void> decide({required bool accept, String? comment}) async {
    final proposal = openProposal;
    final source = _source;
    if (proposal == null || source == null || _deciding) {
      return;
    }
    if (source is! ProposalDecider) {
      return;
    }
    final decider = source as ProposalDecider;
    _deciding = true;
    _decisionError = null;
    notifyListeners();
    try {
      if (accept) {
        await decider.accept(proposal.id, comment: comment);
      } else {
        await decider.reject(proposal.id, comment: comment);
      }
      _deciding = false;
      closeProposalPanel();
      await load(source);
    } on ApiException catch (error) {
      _deciding = false;
      _decisionError = error.errors['layout']?.join('\n') ?? error.message;
      notifyListeners();
    } on Exception {
      _deciding = false;
      _decisionError = 'Serveur injoignable : rien n\'a changé.';
      notifyListeners();
    }
  }

  /// Agents installés au bureau.
  List<OfficeAgent> get agents => _agents;

  /// Augmente à chaque nouveau jeu de données : la scène se recompose.
  int get revision => _revision;

  /// Vrai quand les données viennent du serveur.
  bool get fromServer => _fromServer;

  /// Dernière erreur de chargement, en français ; `null` si tout va bien.
  String? get loadError => _loadError;

  /// Remplace les départements, le plan et les agents.
  void apply(OfficeSnapshot snapshot, {bool fromServer = false}) {
    _departments = snapshot.departments;
    _plan = snapshot.plan;
    _agents = snapshot.agents;
    _proposals = snapshot.proposals;
    _serverPlan = snapshot.serverPlan;
    if (openProposal == null) {
      _openProposalId = null;
      _previewing = false;
    }
    _fromServer = fromServer;
    _loadError = null;
    _revision++;
    if (_selectedAgentId != null &&
        !_agents.any((agent) => agent.id == _selectedAgentId)) {
      _selectedAgentId = _agents.isEmpty ? null : _agents.first.id;
    }
    notifyListeners();
  }

  /// Charge les données d'une source ; en cas d'échec, garde celles qui sont
  /// affichées et retient l'erreur.
  Future<void> load(OfficeSource source, {bool fromServer = true}) async {
    _source = source;
    try {
      apply(await source.load(), fromServer: fromServer);
    } on ApiException catch (error) {
      _loadError = error.message;
      notifyListeners();
    } on Exception {
      _loadError = 'Serveur injoignable : données de démonstration.';
      notifyListeners();
    }
  }

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

  /// Agent par identifiant. La conversation reste en démonstration tant
  /// qu'elle n'est pas lue sur le serveur : ses agents sont cherchés aussi
  /// parmi ceux de la démonstration.
  OfficeAgent agentById(String id) {
    for (final agent in _agents) {
      if (agent.id == id) {
        return agent;
      }
    }
    return DemoData.agents.firstWhere((a) => a.id == id);
  }

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
