import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app/theme.dart';
import 'live_office_controller.dart';
import 'office_camera.dart';
import 'office_source.dart';
import 'scene/iso.dart';
import 'scene/office_scene.dart';
import 'scene/pixel_people.dart';
import 'scene/plan_scene.dart';
import 'widgets/agent_panel.dart';
import 'widgets/common.dart';
import 'widgets/conversation_panel.dart';
import 'widgets/editor_panel.dart';
import 'widgets/icon_rail.dart';
import 'widgets/map_overlays.dart';
import 'widgets/office_view.dart';
import 'widgets/plan_editor_view.dart';
import 'widgets/proposal_panel.dart';

/// Écran principal : rail d'icônes, panneau des agents, bureau vivant et
/// panneau de conversation.
class LiveOfficeScreen extends StatefulWidget {
  const LiveOfficeScreen({super.key, this.source});

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
    final source = widget.source ?? _defaultSource();
    if (source != null) {
      unawaited(_controller.load(source));
    }
  }

  OfficeSource? _defaultSource() {
    final config = ApiConfig.fromEnvironment();
    if (config == null) {
      return null;
    }
    return ApiOfficeSource(_client = ApiClient(config));
  }

  /// Change la scène de la caméra quand on passe du plateau à la salle, et
  /// recompose le plateau quand les données changent.
  void _syncScene() {
    final mode = _controller.mode;
    final revision = _controller.revision;
    if (mode == _shownMode && revision == _shownRevision) {
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
  }

  Offset? _feetOf(String agentId, double time) {
    return _controller.mode == OfficeViewMode.plateau
        ? _plateauFeet[agentId]
        : roomFeet(agentId, time);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncScene)
      ..dispose();
    _camera.dispose();
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
            listenable: _controller,
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
                final showProposal =
                    !editing &&
                    _controller.openProposal != null &&
                    width >= LiveOfficeScreen.agentPanelBreakpoint;
                final showConversation =
                    !showProposal &&
                    _controller.conversationOpen &&
                    width >= LiveOfficeScreen.conversationBreakpoint;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    IconRail(
                      agentPanelOpen: showAgents,
                      onToggleAgentPanel: _controller.toggleAgentPanel,
                    ),
                    const SizedBox(width: 6),
                    if (showAgents) ...<Widget>[
                      AgentPanel(controller: _controller),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: _buildMap()),
                    if (editing) ...<Widget>[
                      const SizedBox(width: 8),
                      EditorPanel(controller: _controller),
                    ] else if (showProposal) ...<Widget>[
                      const SizedBox(width: 8),
                      ProposalPanel(controller: _controller),
                    ] else if (showConversation) ...<Widget>[
                      const SizedBox(width: 8),
                      ConversationPanel(controller: _controller),
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
