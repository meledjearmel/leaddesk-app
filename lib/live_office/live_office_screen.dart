import 'dart:async';

import 'package:flutter/material.dart';

import '../admin/admin_controller.dart';
import '../admin/admin_screen.dart';
import '../api/api_client.dart';
import '../api/realtime.dart';
import '../app/theme.dart';
import '../decisions/decisions_controller.dart';
import '../engine/run_controller.dart';
import 'agent_sheet.dart';
import 'live_office_controller.dart';
import 'office_camera.dart';
import 'office_source.dart';
import 'scene/iso.dart';
import 'scene/office_scene.dart';
import 'scene/pixel_people.dart';
import 'scene/plan_scene.dart';
import 'widgets/agent_panel.dart';
import 'widgets/agent_sheet_panel.dart';
import 'widgets/common.dart';
import 'widgets/conversation_panel.dart';
import 'widgets/decisions_panel.dart';
import 'widgets/editor_panel.dart';
import 'widgets/icon_rail.dart';
import 'widgets/map_overlays.dart';
import 'widgets/office_view.dart';
import 'widgets/plan_editor_view.dart';
import 'widgets/proposal_panel.dart';
import 'widgets/run_panel.dart';

/// Écran principal : rail d'icônes, panneau des agents, bureau vivant et
/// panneau de conversation.
class LiveOfficeScreen extends StatefulWidget {
  const LiveOfficeScreen({
    super.key,
    this.source,
    this.onSignOut,
    this.realtime,
    this.engine,
    this.decisions,
    this.admin,
  });

  /// Back-office (D-026) ; absent en démonstration.
  final AdminController? admin;

  /// File des décisions du CEO ; absente en démonstration.
  final DecisionsController? decisions;

  /// Moteur d'exécution local (D-022) ; absent en démonstration.
  final RunController? engine;

  /// Temps réel de l'entreprise (D-020) ; absent en démonstration.
  final RealtimeClient? realtime;

  /// Déconnexion, proposée dans le rail d'icônes.
  final VoidCallback? onSignOut;

  /// Source des données ; par défaut le serveur s'il est configuré
  /// (`LD_API_URL`, `LD_API_TOKEN`), sinon la démonstration.
  final OfficeSource? source;

  /// Largeur à partir de laquelle le panneau des agents tient à l'écran.
  static const double agentPanelBreakpoint = 820;

  /// Largeur à partir de laquelle la conversation tient aussi.
  static const double conversationBreakpoint = 1180;

  @override
  State<LiveOfficeScreen> createState() => _LiveOfficeScreenState();
}

class _LiveOfficeScreenState extends State<LiveOfficeScreen> {
  final LiveOfficeController _controller = LiveOfficeController();
  final OfficeCamera _camera = OfficeCamera();
  late PlanGeometry _geometry = _buildGeometry();
  OfficeFrames? _roomFrames;
  OfficeFrames? _plateauFrames;
  OfficeViewMode? _shownMode;
  int _shownRevision = 0;
  ApiClient? _client;
  bool _runOpen = false;
  bool _decisionsOpen = false;
  bool _adminOpen = false;

  void _toggleAdmin() {
    setState(() => _adminOpen = !_adminOpen);
    if (_adminOpen) {
      unawaited(widget.admin?.load());
    } else {
      // Les changements faits dans l'administration se voient au retour.
      unawaited(_sheet?.refresh());
    }
  }

  void _setDecisionsOpen(bool open) {
    setState(() {
      _decisionsOpen = open;
      if (open) {
        _runOpen = false;
      }
    });
    widget.decisions?.watch(watching: open);
  }

  final List<StreamSubscription<Object?>> _realtimeSubscriptions =
      <StreamSubscription<Object?>>[];

  PlanGeometry _buildGeometry() =>
      PlanGeometry(_controller.plan, _controller.departments);

  /// Pieds des agents sur le plateau : chacun à un poste de son département.
  late Map<String, Offset> _plateauFeet = _buildFeet();

  Map<String, Offset> _buildFeet() => <String, Offset>{
    for (final department in _controller.departments)
      for (final (i, agent) in _controller.agentsOf(department.id).indexed)
        if (_geometry.seats[department.id] case final seats?
            when i < seats.length)
          agent.id:
              _geometry.toImage(seats[i].x, seats[i].y) + const Offset(0, -8),
  };

  OfficeFrames get _frames => _controller.mode == OfficeViewMode.plateau
      ? (_plateauFrames ??= OfficeFrames.plateau(_geometry, _occupants()))
      : (_roomFrames ??= OfficeFrames.detailed());

  /// Personnes assises : les agents de chaque département d'abord, puis des
  /// collègues jusqu'à l'effectif ; les postes restants sont vacants.
  Map<String, List<PersonLook>> _occupants() {
    const looks = <String, PersonLook>{
      'atlas': OfficeLooks.atlas,
      'forge': OfficeLooks.forge,
      'scout': OfficeLooks.scout,
      'relay': OfficeLooks.relay,
      'quill': OfficeLooks.quill,
    };
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
    var n = 0;
    return <String, List<PersonLook>>{
      for (final department in _controller.departments)
        department.id: () {
          final people = <PersonLook>[
            for (final agent in _controller.agentsOf(department.id))
              looks[agent.id] ??
                  PersonLook(
                    skin: agent.avatar.skin,
                    hair: agent.avatar.hair,
                    top: agent.avatar.top,
                    longHair: agent.avatar.longHair,
                  ),
          ];
          while (people.length < department.headcount) {
            n++;
            people.add(
              PersonLook(
                skin: skins[n % skins.length],
                hair: hairs[(n * 2) % hairs.length],
                top: shade(Color(department.color), 0.75),
                longHair: n % 3 == 0,
              ),
            );
          }
          return people;
        }(),
    };
  }

  @override
  void initState() {
    super.initState();
    _syncScene();
    _controller.addListener(_syncScene);
    if (widget.realtime case final realtime?) {
      _realtimeSubscriptions.addAll(<StreamSubscription<Object?>>[
        realtime.changes.listen(_controller.onRemoteChange),
        realtime.statuses.listen(_controller.setRealtimeStatus),
      ]);
      unawaited(realtime.start());
    }
    unawaited(widget.decisions?.load());
    if (widget.engine case final engine?) {
      unawaited(engine.load());
    }
    final source = widget.source ?? _defaultSource();
    if (source != null) {
      unawaited(
        _controller.load(source, fromServer: source is! DemoOfficeSource),
      );
    }
  }

  OfficeSource? _defaultSource() {
    final config = ApiConfig.fromEnvironment();
    if (config == null) {
      return null;
    }
    return _defaultSourceCache = ApiOfficeSource(_client = ApiClient(config));
  }

  /// Change la scène de la caméra quand on passe du plateau à la salle, et
  /// recompose le plateau quand les données changent.
  void _syncScene() {
    if (_controller.signedOut && widget.onSignOut != null) {
      // Jeton refusé par le serveur : retour à l'écran de connexion.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onSignOut?.call(),
      );
      return;
    }
    _syncSheet();
    final mode = _controller.mode;
    final revision = _controller.revision;
    final focus = _controller.focusedDepartment?.id;
    if (mode == _shownMode && revision == _shownRevision) {
      if (focus != _shownFocus) {
        _frameFocus();
      }
      return;
    }
    if (revision != _shownRevision) {
      _shownRevision = revision;
      _geometry = _buildGeometry();
      _plateauFeet = _buildFeet();
      _plateauFrames?.dispose();
      _plateauFrames = null;
    }
    _shownMode = mode;
    final plateau = mode == OfficeViewMode.plateau;
    final size = _frames.size;
    _camera.setScene(
      size,
      focus: plateau ? size.center(Offset.zero) : OfficeLayout.focus,
      contain: plateau,
      // Le plateau s'ouvre à mi-distance : lisible, le reste se parcourt.
      initialZoom: plateau ? 1.6 : 1,
    );
    _shownFocus = null;
    if (plateau && focus != null) {
      _frameFocus();
    }
  }

  String? _shownFocus;

  /// Cadre le bureau du département visité, ou revient à la vue d'ensemble.
  void _frameFocus() {
    final focus = _controller.focusedDepartment?.id;
    _shownFocus = focus;
    if (_controller.mode != OfficeViewMode.plateau) {
      return;
    }
    final bounds = focus == null ? null : _geometry.departmentBounds(focus);
    if (bounds == null) {
      _camera.reset();
    } else {
      _camera.frame(bounds);
    }
  }

  late final AgentSheetController? _sheet = () {
    final api =
        widget.admin?.api ??
        switch (widget.source ?? _defaultSourceCache) {
          final ApiOfficeSource source => source.client,
          _ => null,
        };
    return api == null ? null : AgentSheetController(api);
  }();

  OfficeSource? _defaultSourceCache;

  /// Charge la fiche de l'agent ouvert, si elle a changé.
  void _syncSheet() {
    final id = _controller.sheetAgentId;
    final sheet = _sheet;
    if (id != null && sheet != null && '${sheet.agentId}' != id) {
      unawaited(sheet.open(id));
    }
  }

  /// Ouvre l'agent dans l'administration.
  void _editAgent(String id) {
    final admin = widget.admin;
    final agentId = int.tryParse(id);
    if (admin == null || agentId == null) {
      return;
    }
    setState(() => _adminOpen = true);
    unawaited(
      admin.load().then((_) {
        admin
          ..open(AdminSection.agents)
          ..select(agentId);
      }),
    );
  }

  Offset? _feetOf(String agentId, double time) {
    return _controller.mode == OfficeViewMode.plateau
        ? _plateauFeet[agentId]
        : roomFeet(agentId, time);
  }

  @override
  void dispose() {
    for (final subscription in _realtimeSubscriptions) {
      unawaited(subscription.cancel());
    }
    _controller
      ..removeListener(_syncScene)
      ..dispose();
    _camera.dispose();
    _sheet?.dispose();
    _roomFrames?.dispose();
    _plateauFrames?.dispose();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable?>[
              _controller,
              widget.decisions,
            ]),
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // Sur une fenêtre étroite, les panneaux cèdent la place à
                // la carte.
                final showAgents =
                    _controller.agentPanelOpen &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                // La proposition ouverte prend la place de la conversation.
                final editing =
                    _controller.editing &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                final sheetAgent = _controller.agents
                    .where((a) => a.id == _controller.sheetAgentId)
                    .firstOrNull;
                final showSheet =
                    !editing &&
                    sheetAgent != null &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                final showProposal =
                    !editing &&
                    !showSheet &&
                    _controller.openProposal != null &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                final engine = widget.engine;
                final showRun =
                    engine != null &&
                    _runOpen &&
                    !editing &&
                    !showProposal &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                final decisions = widget.decisions;
                final showDecisions =
                    decisions != null &&
                    _decisionsOpen &&
                    !editing &&
                    !showProposal &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                final admin = widget.admin;
                final showAdmin = admin != null && _adminOpen;
                final showConversation =
                    !showSheet &&
                    !showProposal &&
                    !showRun &&
                    !showDecisions &&
                    _controller.conversationOpen &&
                    width >= LiveOfficeScreen.conversationBreakpoint;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    IconRail(
                      agentPanelOpen: showAgents,
                      onToggleAgentPanel: _controller.toggleAgentPanel,
                      onSignOut: widget.onSignOut,
                      runPanelOpen: showRun,
                      onToggleRunPanel: engine == null
                          ? null
                          : () => setState(() {
                              _runOpen = !_runOpen;
                              if (_runOpen && _decisionsOpen) {
                                _setDecisionsOpen(false);
                              }
                            }),
                      decisionsOpen: showDecisions,
                      decisionCount: decisions?.count ?? 0,
                      onToggleDecisions: decisions == null
                          ? null
                          : () => _setDecisionsOpen(!_decisionsOpen),
                      adminOpen: showAdmin,
                      onToggleAdmin: admin == null ? null : _toggleAdmin,
                    ),
                    const SizedBox(width: 6),
                    if (showAdmin)
                      Expanded(
                        child: AdminScreen(
                          controller: admin,
                          onClose: _toggleAdmin,
                        ),
                      )
                    else ...<Widget>[
                      if (showAgents) ...<Widget>[
                        AgentPanel(controller: _controller),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _buildMap()),
                      if (editing) ...<Widget>[
                        const SizedBox(width: 8),
                        EditorPanel(controller: _controller),
                      ] else if (showSheet) ...<Widget>[
                        const SizedBox(width: 8),
                        AgentSheetPanel(
                          office: _controller,
                          agent: sheetAgent,
                          sheet: _sheet,
                          onEdit: widget.admin == null
                              ? null
                              : () => _editAgent(sheetAgent.id),
                        ),
                      ] else if (showProposal) ...<Widget>[
                        const SizedBox(width: 8),
                        ProposalPanel(controller: _controller),
                      ] else if (showDecisions) ...<Widget>[
                        const SizedBox(width: 8),
                        DecisionsPanel(
                          controller: decisions,
                          onClose: () => _setDecisionsOpen(false),
                        ),
                      ] else if (showRun) ...<Widget>[
                        const SizedBox(width: 8),
                        RunPanel(
                          controller: engine,
                          onClose: () => setState(() => _runOpen = false),
                        ),
                      ] else if (showConversation) ...<Widget>[
                        const SizedBox(width: 8),
                        ConversationPanel(controller: _controller),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(LdRadius.panel),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LdRadius.panel),
          border: Border.all(color: LdColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _camera.setViewport(constraints.biggest);
            final roomy = constraints.maxWidth >= 520;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (_controller.editor case final editor?)
                  PlanEditorView(editor: editor)
                else
                  OfficeView(
                    controller: _controller,
                    camera: _camera,
                    frames: _frames,
                  ),
                if (!_controller.editing &&
                    _controller.mode == OfficeViewMode.plateau)
                  DepartmentTagLayer(
                    camera: _camera,
                    geometry: _geometry,
                    presentOf: (id) => _controller.agentsOf(id).length,
                    onOpen: _controller.focusDepartment,
                    focusedId: _controller.focusedDepartment?.id,
                  ),
                if (!_controller.editing &&
                    _controller.mode == OfficeViewMode.plateau)
                  Positioned(
                    left: 12,
                    top: 64,
                    child: DepartmentNavigator(controller: _controller),
                  ),
                if (!_controller.editing)
                  AgentTagLayer(
                    controller: _controller,
                    camera: _camera,
                    feetOf: _feetOf,
                    uniformPlacement:
                        _controller.mode == OfficeViewMode.plateau,
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MapTopBar(controller: _controller),
                    ),
                  ),
                ),
                if (!_controller.editing &&
                    _controller.proposals.isNotEmpty &&
                    (_controller.openProposal == null ||
                        _controller.previewing))
                  Positioned(
                    top: 68,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ProposalNotice(controller: _controller),
                      ),
                    ),
                  ),
                if (!_controller.editing)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: MapZoomControl(camera: _camera),
                  ),
                if (roomy && !_controller.editing)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: GlassSurface(
                      radius: 12,
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: OfficeMinimap(
                          camera: _camera,
                          frames: _frames,
                          time: _controller.sceneTime,
                          markers: (time) => <(Offset, Color)>[
                            for (final agent in _controller.agents)
                              if (_feetOf(agent.id, time) case final feet?)
                                (feet, agent.avatar.background),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: roomy ? OfficeMinimap.width + 32 : 12,
                  right: 12,
                  bottom: 12,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MapControlBar(controller: _controller),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
