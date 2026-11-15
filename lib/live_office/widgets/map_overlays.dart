import 'package:flutter/material.dart';

import '../../api/realtime.dart';
import '../../app/theme.dart';
import '../live_office_controller.dart';
import '../models.dart';
import '../office_camera.dart';
import '../scene/office_scene.dart';
import '../scene/plan_scene.dart';
import 'common.dart';

/// Pieds d'un agent dans la scène, en pixels d'art, au temps donné ;
/// `null` si l'agent n'est pas dans la scène.
typedef FeetOf = Offset? Function(String agentId, double time);

/// Pieds des agents dans la salle détaillée de référence.
Offset? roomFeet(String agentId, double time) {
  return switch (agentId) {
    'forge' => OfficeLayout.forgeSeat + const Offset(0, -8),
    'atlas' => OfficeLayout.atlasFeet,
    'quill' => OfficeLayout.quillFeet,
    'scout' => OfficeLayout.scoutFeet,
    _ => OfficeLayout.walkerAt(time).feet,
  };
}

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
      listenable: Listenable.merge(<Listenable>[camera, controller.sceneTime]),
      builder: (context, _) {
        final time = controller.sceneTime.value;
        final scale = camera.scale;
        const head = OfficeLayout.personHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final agent in controller.agents)
              // Vue d'ensemble du plateau : seuls les agents en
              // conversation ou sélectionnés gardent leur étiquette.
              if (!uniformPlacement ||
                  scale >= 1.6 ||
                  agent.inConversation ||
                  agent.id == controller.selectedAgentId)
                if (feetOf(agent.id, time) case final feet?)
                  () {
                    // Point d'accroche, en pixels d'art, puis écart fixe à l'écran.
                    final placement = uniformPlacement
                        ? TagPlacement.above
                        : agent.tagPlacement;
                    final (anchor, shift, gap) = switch (placement) {
                      TagPlacement.aboveLeft => (
                        feet + const Offset(-8, -head),
                        const Offset(-1, -1),
                        const Offset(-4, -4),
                      ),
                      TagPlacement.above => (
                        feet + const Offset(0, -head),
                        const Offset(-0.5, -1),
                        const Offset(0, -8),
                      ),
                      TagPlacement.aboveRight => (
                        feet + const Offset(-12, -head),
                        const Offset(0, -1),
                        const Offset(0, -8),
                      ),
                      TagPlacement.belowRight => (
                        feet + const Offset(-40, 4),
                        Offset.zero,
                        const Offset(0, 8),
                      ),
                    };
                    final at = camera.toScreen(anchor) + gap;
                    return Positioned(
                      left: at.dx,
                      top: at.dy,
                      child: FractionalTranslation(
                        translation: shift,
                        child: _AgentTag(
                          agent: agent,
                          selected: agent.id == controller.selectedAgentId,
                          // Les bulles se resserrent quand la scène est dézoomée.
                          compact: scale < 1.6,
                          onTap: () => controller.selectAgent(agent.id),
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

/// Étiquettes des départements sur le plateau : une par département, posée
/// sur sa première salle, avec sa couleur, son nom et son effectif ; les
/// noms des salles apparaissent quand on zoome.
class DepartmentTagLayer extends StatelessWidget {
  const DepartmentTagLayer({
    required this.camera,
    required this.geometry,
    required this.presentOf,
    super.key,
  });

  final OfficeCamera camera;
  final PlanGeometry geometry;

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
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final tag in geometry.tags)
              if (tag.department == null
                  ? detailed
                  : (seen.add(tag.department!.id) || detailed))
                () {
                  final at = camera.toScreen(tag.anchor);
                  final department = tag.department;
                  return Positioned(
                    left: at.dx,
                    top: at.dy,
                    child: FractionalTranslation(
                      translation: const Offset(0, -1),
                      child: IgnorePointer(
                        child: _DepartmentTag(
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
  const _DepartmentTag({required this.title, required this.color, this.detail});

  final String title;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 5),
      decoration: BoxDecoration(
        color: const Color(0xE6141312),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
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
        borderColor: highlighted ? LdColors.amber : LdColors.borderStrong,
        borderWidth: highlighted ? 1.5 : 1,
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
