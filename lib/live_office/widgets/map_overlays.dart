import 'package:flutter/material.dart';

import '../../api/realtime.dart';
import '../../app/theme.dart';
import '../live_office_controller.dart';
import '../models.dart';
import '../office_camera.dart';
import '../scene/office_scene.dart';
import '../scene/plan_scene.dart';
import 'common.dart';
import 'declutter.dart';

/// Pieds d'un agent dans la scène, en pixels d'art, au temps donné ;
/// `null` si l'agent n'est pas dans la scène.
typedef FeetOf = Offset? Function(String agentId, double time);

/// Bandes de la carte occupées par les barres du haut et du bas : aucune
/// étiquette ne s'y glisse.
const EdgeInsets mapSafeArea = EdgeInsets.only(top: 58, bottom: 62);

/// Places de la salle détaillée de référence, dans l'ordre d'attribution.
const List<String> roomSpots = <String>[
  'forge',
  'atlas',
  'quill',
  'scout',
  'relay',
];

/// Pieds d'une place de la salle détaillée.
Offset roomSpotFeet(String spot, double time) => switch (spot) {
  'forge' => OfficeLayout.forgeSeat + const Offset(0, -8),
  'atlas' => OfficeLayout.atlasFeet,
  'quill' => OfficeLayout.quillFeet,
  'scout' => OfficeLayout.scoutFeet,
  _ => OfficeLayout.walkerAt(time).feet,
};

/// Une place par agent dans la salle détaillée : les agents de
/// démonstration gardent la leur, les autres prennent les places libres
/// dans l'ordre. Faute de place, un agent n'est pas montré dans la salle
/// (au lieu d'être empilé sur un autre).
Map<String, String> assignRoomSpots(List<OfficeAgent> agents) {
  final result = <String, String>{};
  final free = List<String>.of(roomSpots);
  for (final agent in agents) {
    if (free.remove(agent.id)) {
      result[agent.id] = agent.id;
    }
  }
  for (final agent in agents) {
    if (!result.containsKey(agent.id) && free.isNotEmpty) {
      result[agent.id] = free.removeAt(0);
    }
  }
  return result;
}

/// Pieds des agents de démonstration dans la salle détaillée.
Offset? roomFeet(String agentId, double time) => roomSpotFeet(agentId, time);

/// Étiquettes des agents, accrochées à leur personnage : elles suivent le
/// déplacement et le zoom de la scène sans changer de taille.
class AgentTagLayer extends StatelessWidget {
  const AgentTagLayer({
    required this.controller,
    required this.camera,
    required this.feetOf,
    this.uniformPlacement = false,
    super.key,
  });

  final LiveOfficeController controller;
  final OfficeCamera camera;
  final FeetOf feetOf;

  /// Sur le plateau, toutes les étiquettes se posent au-dessus de l'agent.
  final bool uniformPlacement;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        camera,
        controller.sceneTime,
        controller,
      ]),
      builder: (context, _) {
        final time = controller.sceneTime.value;
        final scale = camera.scale;
        const head = OfficeLayout.personHeight;
        final labelled = <String>{
          for (final agent in controller.agents)
            if (showsTag(agent, scale)) agent.id,
        };
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // Pastille au-dessus de chaque agent sans étiquette : le survol
            // fait apparaître l'étiquette, le clic ouvre la fiche.
            for (final agent in controller.agents)
              if (!labelled.contains(agent.id))
                if (feetOf(agent.id, time) case final feet?)
                  () {
                    final at = camera.toScreen(
                      feet + const Offset(0, -OfficeLayout.personHeight),
                    );
                    return Positioned(
                      left: at.dx - 9,
                      top: at.dy - 22,
                      child: _AgentMarker(
                        agent: agent,
                        onHover: (inside) =>
                            controller.hoverAgent(inside ? agent.id : null),
                        onTap: () => controller.openAgentSheet(agent.id),
                      ),
                    );
                  }(),
            DeclutteredTags(
              safeArea: mapSafeArea,
              maxVisible: controller.tagMode == TagMode.all ? null : maxTags,
              entries: _entries(time, scale, head, labelled),
            ),
          ],
        );
      },
    );
  }

  /// Étiquettes visibles en même temps, hors sélection (D-032).
  static const int maxTags = 6;

  /// Vrai si l'agent garde son étiquette (D-032) : ce qui demande le CEO,
  /// la sélection, le survol, la conversation ; de près, les agents du
  /// bureau visité.
  bool showsTag(OfficeAgent agent, double scale) {
    final c = controller;
    final pinned =
        agent.id == c.selectedAgentId || agent.id == c.hoveredAgentId;
    return switch (c.tagMode) {
      TagMode.none => pinned,
      TagMode.all => true,
      TagMode.essential =>
        pinned ||
            agent.inConversation ||
            agent.state.needsAttention ||
            (scale >= closeUp &&
                (c.mode == OfficeViewMode.room ||
                    agent.departmentId == c.focusedDepartment?.id)),
    };
  }

  /// Zoom à partir duquel les agents du bureau visité sont nommés.
  static const double closeUp = 2.4;

  List<TagEntry> _entries(
    double time,
    double scale,
    double head,
    Set<String> labelled,
  ) {
    return <TagEntry>[
      for (final agent in controller.agents)
        if (labelled.contains(agent.id))
          if (feetOf(agent.id, time) case final feet?)
            () {
              // Point d'accroche, en pixels d'art, puis écart fixe à l'écran.
              final placement = uniformPlacement
                  ? TagPlacement.above
                  : agent.tagPlacement;
              final (anchor, shift, gap) = switch (placement) {
                TagPlacement.aboveLeft => (
                  feet + const Offset(-8, -OfficeLayout.personHeight),
                  const Offset(-1, -1),
                  const Offset(-4, -4),
                ),
                TagPlacement.above => (
                  feet + const Offset(0, -OfficeLayout.personHeight),
                  const Offset(-0.5, -1),
                  const Offset(0, -8),
                ),
                TagPlacement.aboveRight => (
                  feet + const Offset(-12, -OfficeLayout.personHeight),
                  const Offset(0, -1),
                  const Offset(0, -8),
                ),
                TagPlacement.belowRight => (
                  feet + const Offset(-40, 4),
                  Offset.zero,
                  const Offset(0, 8),
                ),
              };
              final selected = agent.id == controller.selectedAgentId;
              final hovered = agent.id == controller.hoveredAgentId;
              return TagEntry(
                id: agent.id,
                anchor: camera.toScreen(anchor) + gap,
                shift: shift,
                priority: selected || hovered
                    ? 4
                    : (agent.state.needsAttention
                          ? 3
                          : (agent.inConversation ? 2 : 0)),
                child: MouseRegion(
                  onEnter: (_) => controller.hoverAgent(agent.id),
                  onExit: (_) => controller.hoverAgent(null),
                  child: _AgentTag(
                    agent: agent,
                    selected: selected,
                    // Les bulles se resserrent quand la scène est
                    // dézoomée.
                    compact: scale < 1.6,
                    onTap: () => controller.openAgentSheet(agent.id),
                  ),
                ),
              );
            }(),
    ];
  }
}

/// Pastille d'un agent sans étiquette : couleur de son état, pulsation
/// quand il travaille.
class _AgentMarker extends StatelessWidget {
  const _AgentMarker({
    required this.agent,
    required this.onHover,
    required this.onTap,
  });

  final OfficeAgent agent;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = agent.state;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${agent.name}, ${state.label}',
          child: SizedBox.square(
            dimension: 18,
            child: Center(
              child: state == AgentState.working
                  ? const PulseDot(size: 8)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: state.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xCC0B0908),
                          width: 1.5,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Étiquettes des départements sur le plateau : une par département, posée
/// sur sa première salle, avec sa couleur, son nom et son effectif ; les
/// noms des salles apparaissent quand on zoome.
class DepartmentTagLayer extends StatelessWidget {
  const DepartmentTagLayer({
    required this.camera,
    required this.geometry,
    required this.presentOf,
    this.onOpen,
    this.focusedId,
    this.tagMode = TagMode.essential,
    super.key,
  });

  final TagMode tagMode;

  final OfficeCamera camera;
  final PlanGeometry geometry;

  /// Clic sur l'étiquette d'un département : on entre dans son bureau.
  final void Function(String departmentId)? onOpen;

  /// Département visité : son étiquette est mise en avant.
  final String? focusedId;

  /// Agents présents d'un département.
  final int Function(String departmentId) presentOf;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: camera,
      builder: (context, _) {
        final detailed = camera.scale >= 1.6;
        // De loin, le nom du département suffit.
        final far = camera.scale < 0.9;
        final seen = <String>{};
        return DeclutteredTags(
          safeArea: mapSafeArea,
          entries: <TagEntry>[
            for (final (index, tag) in geometry.tags.indexed)
              // Une étiquette par département ; les noms de salles
              // seulement de près dans le bureau visité, ou en mode
              // « toutes » (D-032).
              if (tag.department == null
                  ? (tagMode == TagMode.all && detailed)
                  : (seen.add(tag.department!.id) ||
                        (tagMode == TagMode.all && detailed) ||
                        (tag.department!.id == focusedId &&
                            camera.scale >= AgentTagLayer.closeUp)))
                () {
                  final department = tag.department;
                  final open = onOpen;
                  final first =
                      department != null &&
                      geometry.tags.indexWhere(
                            (t) => t.department?.id == department.id,
                          ) ==
                          index;
                  return TagEntry(
                    id: 'room-$index',
                    anchor: camera.toScreen(tag.anchor),
                    shift: const Offset(0, -1),
                    // Le bureau visité, puis une étiquette par département,
                    // passent avant les noms de salles.
                    priority: department != null && department.id == focusedId
                        ? 2
                        : (first ? 1 : 0),
                    child: LdPressable(
                      tooltip: department == null || open == null
                          ? null
                          : 'Entrer dans le bureau ${department.name}',
                      onTap: department == null || open == null
                          ? null
                          : () => open(department.id),
                      builder: (context, hovered) => _DepartmentTag(
                        highlighted: hovered || department?.id == focusedId,
                        title: department?.name ?? tag.room.label,
                        detail: department == null || far
                            ? null
                            : (detailed
                                  ? tag.room.label
                                  : '${presentOf(department.id)} présent'
                                        '${presentOf(department.id) > 1 ? 's' : ''}'
                                        ' · ${department.headcount} postes'),
                        color: department == null
                            ? LdColors.textMuted
                            : Color(department.color),
                      ),
                    ),
                  );
                }(),
          ],
        );
      },
    );
  }
}

class _DepartmentTag extends StatelessWidget {
  const _DepartmentTag({
    required this.title,
    required this.color,
    this.detail,
    this.highlighted = false,
  });

  final String title;
  final String? detail;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 5),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xF2232120) : const Color(0xE6141312),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: highlighted ? 1 : 0.7),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: LdColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (detail != null)
                Text(
                  detail,
                  style: const TextStyle(
                    color: LdColors.textMuted,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentTag extends StatelessWidget {
  const _AgentTag({
    required this.agent,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final OfficeAgent agent;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = agent.inConversation || selected;
    final detail = agent.tagDetail;
    final speech = agent.speech;
    final tag = LdPressable(
      onTap: onTap,
      builder: (context, hovered) => GlassSurface(
        radius: 10,
        blur: 0,
        color: hovered ? const Color(0xF2262523) : const Color(0xEB1B1A19),
        borderColor: highlighted
            ? LdColors.amber
            : (agent.state.needsAttention
                  ? agent.state.color
                  : LdColors.borderStrong),
        borderWidth: highlighted || agent.state.needsAttention ? 1.5 : 1,
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ProviderBadge(provider: agent.provider, size: 18, framed: false),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      agent.name,
                      style: const TextStyle(
                        color: LdColors.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (agent.working) ...<Widget>[
                      const SizedBox(width: 7),
                      const PulseDot(size: 6),
                    ] else if (agent.state != AgentState.idle) ...<Widget>[
                      const SizedBox(width: 7),
                      Tooltip(
                        message: agent.state.label,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: agent.state.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  detail == null
                      ? agent.position
                      : '${agent.position} · $detail',
                  style: const TextStyle(
                    color: LdColors.textMuted,
                    fontSize: 12.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (speech != null && !compact) ...<Widget>[
          Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xF21B1A19),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LdColors.border),
            ),
            child: Text(
              speech,
              style: const TextStyle(color: LdColors.text, fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            tag,
            if (agent.typing) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF21B1A19),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LdColors.border),
                ),
                child: const TypingDots(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Barre du haut de la carte : projet, état, nouvel objectif.
class MapTopBar extends StatelessWidget {
  const MapTopBar({required this.controller, super.key});

  final LiveOfficeController controller;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 14,
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LdPressable(
            onTap: () {},
            tooltip: 'Changer de projet',
            builder: (context, hovered) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
              decoration: BoxDecoration(
                color: hovered ? LdColors.hover : Colors.transparent,
                borderRadius: BorderRadius.circular(LdRadius.control),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DemoData.projectName,
                    style: TextStyle(
                      color: LdColors.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Color(0xFFB7B2AA),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (controller.paused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: LdColors.hover,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'En pause',
                style: TextStyle(
                  color: LdColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            )
          else
            const StatusChip(label: 'En cours', pulse: true),
          const SizedBox(width: 10),
          LdPressable(
            onTap: () {},
            builder: (context, hovered) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
              decoration: BoxDecoration(
                color: hovered
                    ? const Color(0xFFE6E3DD)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(LdRadius.control),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.add, size: 17, color: Color(0xFF161514)),
                  SizedBox(width: 6),
                  Text(
                    'Nouvel objectif',
                    style: TextStyle(
                      color: Color(0xFF161514),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Commandes de zoom, en haut à droite de la carte.
class MapZoomControl extends StatelessWidget {
  const MapZoomControl({required this.camera, super.key});

  final OfficeCamera camera;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 14,
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LdIconButton(
            icon: Icons.add,
            tooltip: 'Zoom avant',
            onTap: camera.zoomIn,
          ),
          LdIconButton(
            icon: Icons.remove,
            tooltip: 'Zoom arrière',
            onTap: camera.zoomOut,
          ),
          LdIconButton(
            icon: Icons.fullscreen,
            tooltip: 'Recadrer le bureau',
            onTap: camera.reset,
          ),
        ],
      ),
    );
  }
}

/// Barre du bas : pause, direct, vitesse, thème, conversation.
class MapControlBar extends StatelessWidget {
  const MapControlBar({required this.controller, super.key});

  final LiveOfficeController controller;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LdIconButton(
            icon: controller.paused ? Icons.play_arrow : Icons.pause,
            tooltip: controller.paused ? 'Reprendre' : 'Mettre en pause',
            onTap: controller.togglePaused,
          ),
          _BarButton(
            label: 'En direct',
            tooltip: switch ((controller.live, controller.realtimeStatus)) {
              (false, _) => 'Suivre l\'activité en direct',
              (true, RealtimeStatus.live) =>
                'En direct : les changements arrivent sans recharger',
              (true, RealtimeStatus.offline) =>
                'Temps réel hors ligne : nouvelle tentative en cours',
              (true, RealtimeStatus.connecting) => 'Connexion au temps réel…',
              (true, RealtimeStatus.idle) => 'Suivi en direct activé',
            },
            onTap: controller.toggleLive,
            leading: controller.live && !controller.paused
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: PulseDot(),
                  )
                : const Icon(Icons.adjust, size: 17, color: Color(0xFFB7B2AA)),
          ),
          _BarButton(
            label: 'Vitesse ${controller.speed}x',
            tooltip: 'Changer la vitesse de la scène',
            onTap: controller.cycleSpeed,
          ),
          _BarButton(
            label: controller.mode == OfficeViewMode.plateau
                ? 'Vue : Plateau'
                : 'Vue : Salle',
            tooltip: controller.mode == OfficeViewMode.plateau
                ? 'Voir la salle en détail'
                : 'Voir tout le bureau',
            onTap: controller.toggleMode,
            leading: Icon(
              controller.mode == OfficeViewMode.plateau
                  ? Icons.grid_view
                  : Icons.crop_square,
              size: 17,
              color: const Color(0xFFB7B2AA),
            ),
          ),
          _BarButton(
            label: controller.tagMode.short,
            tooltip:
                'Étiquettes : ${controller.tagMode.label} · cliquer pour changer',
            onTap: controller.cycleTagMode,
            leading: const Icon(
              Icons.label_outline,
              size: 17,
              color: Color(0xFFB7B2AA),
            ),
          ),
          LdIconButton(
            icon: Icons.design_services_outlined,
            tooltip: controller.editing
                ? 'Quitter l\'aménagement sans enregistrer'
                : 'Aménager : déplacer, ajouter ou retirer des salles',
            active: controller.editing,
            iconSize: 17,
            onTap: controller.editing
                ? controller.cancelEditing
                : controller.startEditing,
          ),
          const _BarButton(
            label: 'Thème : Bureau',
            tooltip: 'Bureau sombre et chaleureux',
            leading: Icon(
              Icons.layers_outlined,
              size: 17,
              color: Color(0xFFB7B2AA),
            ),
          ),
          LdIconButton(
            icon: Icons.chat_bubble_outline,
            tooltip: controller.conversationOpen
                ? 'Masquer la conversation'
                : 'Afficher la conversation',
            active: controller.conversationOpen,
            iconSize: 17,
            onTap: controller.toggleConversation,
          ),
          const LdIconButton(
            icon: Icons.more_horiz,
            tooltip: 'Plus d\'options',
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.tooltip,
    this.onTap,
    this.leading,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return LdPressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hovered ? LdColors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(LdRadius.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[leading, const SizedBox(width: 7)],
            Text(
              label,
              style: const TextStyle(
                color: LdColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fil d'Ariane du bureau (D-028) : « Bureau › Technique », bureau
/// précédent et suivant dans l'ordre de l'organisation, retour à la vue
/// d'ensemble.
class DepartmentNavigator extends StatelessWidget {
  const DepartmentNavigator({required this.controller, super.key});

  final LiveOfficeController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final focused = c.focusedDepartment;
    final departments = c.departments;
    final index = focused == null ? -1 : departments.indexOf(focused);
    return GlassSurface(
      radius: 12,
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LdIconButton(
            icon: Icons.chevron_left,
            tooltip: 'Bureau précédent',
            size: 30,
            iconSize: 18,
            onTap: departments.isEmpty ? null : () => c.stepDepartment(-1),
          ),
          LdPressable(
            tooltip: focused == null ? null : 'Revenir à la vue d\'ensemble',
            onTap: focused == null ? null : () => c.focusDepartment(null),
            builder: (context, hovered) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Bureau',
                style: TextStyle(
                  color: focused == null || hovered
                      ? LdColors.text
                      : LdColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (focused != null) ...<Widget>[
            const Icon(
              Icons.chevron_right,
              size: 14,
              color: LdColors.textFaint,
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(focused.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              focused.name,
              style: const TextStyle(
                color: LdColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${index + 1}/${departments.length}',
              style: const TextStyle(color: LdColors.textFaint, fontSize: 11.5),
            ),
          ] else
            const Text(
              'vue d\'ensemble',
              style: TextStyle(color: LdColors.textFaint, fontSize: 12),
            ),
          LdIconButton(
            icon: Icons.chevron_right,
            tooltip: 'Bureau suivant',
            size: 30,
            iconSize: 18,
            onTap: departments.isEmpty ? null : () => c.stepDepartment(1),
          ),
        ],
      ),
    );
  }
}
