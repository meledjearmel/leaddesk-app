import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/realtime.dart';
import '../office/office_plan.dart';
import '../office/office_planner.dart';
import '../office/plan_editor.dart';
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

/// Étiquettes affichées sur la scène.
enum TagMode {
  /// Seulement ce qui compte : attention requise, sélection, survol,
  /// conversation, agents du bureau visité de près.
  essential('essentielles', 'Essentielles'),

  /// Toutes, sans se chevaucher.
  all('toutes', 'Toutes'),

  /// Aucune, sauf la sélection et le survol.
  none('aucune', 'Aucune');

  const TagMode(this.label, this.short);

  final String label;

  /// Libellé de la barre du bas.
  final String short;
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

  PlanEditor? _editor;
  bool _saving = false;
  String? _saveError;

  /// Brouillon du mode « Aménager », ou `null` hors de ce mode (D-016).
  PlanEditor? get editor => _editor;
  bool get editing => _editor != null;
  bool get saving => _saving;
  String? get saveError => _saveError;

  /// Passe en mode « Aménager » à partir du plan en vigueur.
  void startEditing() {
    if (_editor != null) {
      return;
    }
    closeProposalPanel();
    _mode = OfficeViewMode.plateau;
    _saveError = null;
    _editor = PlanEditor(_plan, _departments)..addListener(notifyListeners);
    notifyListeners();
  }

  /// Quitte le mode « Aménager » sans rien enregistrer.
  void cancelEditing() {
    final editor = _editor;
    if (editor == null) {
      return;
    }
    _editor = null;
    _saveError = null;
    editor.dispose();
    notifyListeners();
  }

  /// Enregistre le brouillon : sur le serveur s'il y en a un, sinon dans la
  /// démonstration. Les propositions en attente deviennent périmées.
  Future<void> saveEditing() async {
    final editor = _editor;
    if (editor == null || !editor.canSave || _saving) {
      return;
    }
    final source = _source;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      if (source is PlanSaver) {
        await (source as PlanSaver).savePlan(editor.plan);
      }
      _saving = false;
      _plan = editor.plan;
      _revision++;
      cancelEditing();
      if (source != null && source is PlanSaver) {
        await load(source);
      }
    } on ApiException catch (error) {
      _saving = false;
      _saveError = error.errors['layout']?.join('\n') ?? error.message;
      notifyListeners();
    } on Exception {
      _saving = false;
      _saveError = 'Serveur injoignable : le plan n\'est pas enregistré.';
      notifyListeners();
    }
  }

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

  /// Vrai quand le serveur a refusé le jeton (révoqué ou expiré) : il faut
  /// se reconnecter.
  bool get signedOut => _signedOut;
  bool _signedOut = false;

  RealtimeStatus _realtimeStatus = RealtimeStatus.idle;
  Timer? _reloadTimer;
  bool _pendingRemote = false;

  /// Délai qui regroupe les changements rapprochés avant de recharger.
  static const Duration remoteDebounce = Duration(milliseconds: 400);

  /// État de la connexion au temps réel (D-020).
  RealtimeStatus get realtimeStatus => _realtimeStatus;

  void setRealtimeStatus(RealtimeStatus status) {
    if (_realtimeStatus == status) {
      return;
    }
    _realtimeStatus = status;
    notifyListeners();
  }

  /// Le serveur annonce un changement : le bureau se recharge, sauf si le
  /// suivi en direct est coupé ; il se rechargera alors à sa reprise.
  void onRemoteChange(CompanyChange change) {
    if (_source == null) {
      return;
    }
    if (!_live) {
      _pendingRemote = true;
      return;
    }
    _reloadTimer?.cancel();
    _reloadTimer = Timer(remoteDebounce, () {
      final source = _source;
      if (source != null) {
        unawaited(load(source, fromServer: _fromServer));
      }
    });
  }

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
    if (_focusedDepartmentId != null &&
        !_departments.any((d) => d.id == _focusedDepartmentId)) {
      _focusedDepartmentId = null;
    }
    if (_sheetAgentId != null &&
        !_agents.any((agent) => agent.id == _sheetAgentId)) {
      _sheetAgentId = null;
    }
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
      _signedOut = error.status == 401;
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

  String? _focusedDepartmentId;

  /// Département dont on visite le bureau ; `null` pour la vue d'ensemble
  /// (D-028).
  OfficeDepartment? get focusedDepartment {
    for (final department in _departments) {
      if (department.id == _focusedDepartmentId) {
        return department;
      }
    }
    return null;
  }

  /// Va au bureau d'un département, sur le plateau.
  void focusDepartment(String? id) {
    if (_editor != null) {
      return;
    }
    _focusedDepartmentId = id;
    _mode = OfficeViewMode.plateau;
    notifyListeners();
  }

  /// Passe au bureau suivant (ou précédent), dans l'ordre de l'organisation.
  void stepDepartment(int delta) {
    if (_departments.isEmpty) {
      return;
    }
    final index = _departments.indexWhere((d) => d.id == _focusedDepartmentId);
    final next = index < 0
        ? (delta > 0 ? 0 : _departments.length - 1)
        : (index + delta) % _departments.length;
    focusDepartment(_departments[next].id);
  }

  TagMode _tagMode = TagMode.essential;

  /// Quelles étiquettes la scène montre (D-032).
  TagMode get tagMode => _tagMode;

  /// Essentielles → toutes → aucune → essentielles.
  void cycleTagMode() {
    _tagMode = TagMode.values[(_tagMode.index + 1) % TagMode.values.length];
    notifyListeners();
  }

  String? _hoveredAgentId;

  /// Agent survolé : son étiquette apparaît.
  String? get hoveredAgentId => _hoveredAgentId;

  void hoverAgent(String? id) {
    if (_hoveredAgentId == id) {
      return;
    }
    _hoveredAgentId = id;
    notifyListeners();
  }

  String? _sheetAgentId;

  /// Agent dont la fiche est ouverte (D-029).
  String? get sheetAgentId => _sheetAgentId;

  /// Ouvre la fiche d'un agent (et le sélectionne).
  void openAgentSheet(String id) {
    _selectedAgentId = id;
    _sheetAgentId = id;
    notifyListeners();
  }

  void closeAgentSheet() {
    if (_sheetAgentId == null) {
      return;
    }
    _sheetAgentId = null;
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
    final focused = _focusedDepartmentId;
    for (final agent in agents) {
      // Dans le bureau d'un département, seuls ses agents sont listés.
      if (focused != null && agent.departmentId != focused) {
        continue;
      }
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
    if (_live && _pendingRemote) {
      _pendingRemote = false;
      onRemoteChange(const CompanyChange(id: 0, event: 'reprise'));
    }
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
    _editor?.dispose();
    _reloadTimer?.cancel();
    sceneTime.dispose();
    super.dispose();
  }
}
