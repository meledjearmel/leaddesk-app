import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'live_office_controller.dart';
import 'office_camera.dart';
import 'widgets/agent_panel.dart';
import 'widgets/common.dart';
import 'widgets/conversation_panel.dart';
import 'widgets/icon_rail.dart';
import 'widgets/map_overlays.dart';
import 'widgets/office_view.dart';

/// Écran principal : rail d'icônes, panneau des agents, bureau vivant et
/// panneau de conversation.
class LiveOfficeScreen extends StatefulWidget {
  const LiveOfficeScreen({super.key});

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
  late final OfficeFrames _frames = OfficeFrames();

  @override
  void dispose() {
    _controller.dispose();
    _camera.dispose();
    _frames.dispose();
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
                final showConversation =
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
                    if (showConversation) ...<Widget>[
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
                OfficeView(
                  controller: _controller,
                  camera: _camera,
                  frames: _frames,
                ),
                AgentTagLayer(controller: _controller, camera: _camera),
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
                Positioned(
                  top: 12,
                  right: 12,
                  child: MapZoomControl(camera: _camera),
                ),
                if (roomy)
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
                              (
                                agentFeet(agent.id, time),
                                agent.avatar.background,
                              ),
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
