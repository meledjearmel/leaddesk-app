import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../live_office_controller.dart';
import '../models.dart';
import 'common.dart';

/// Panneau de gauche : connexion d'agents, recherche, agents par poste.
class AgentPanel extends StatelessWidget {
  const AgentPanel({required this.controller, super.key});

  static const double width = 300;

  final LiveOfficeController controller;

  @override
  Widget build(BuildContext context) {
    final groups = controller.agentsByPosition;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: LdColors.surface,
        borderRadius: BorderRadius.circular(LdRadius.panel),
        border: Border.all(color: LdColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'LeadDesk',
                    style: TextStyle(
                      color: LdColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                LdIconButton(
                  icon: Icons.keyboard_double_arrow_left,
                  tooltip: 'Replier le panneau',
                  size: 32,
                  iconSize: 18,
                  onTap: controller.toggleAgentPanel,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: _ConnectCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: _SearchField(onChanged: controller.search),
          ),
          Expanded(
            child: groups.isEmpty
                ? const _EmptySearch()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    children: <Widget>[
                      for (final group in groups.entries) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                          child: Text(
                            '${group.key} (${group.value.length})',
                            style: const TextStyle(
                              color: LdColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        for (final agent in group.value)
                          _AgentRow(
                            agent: agent,
                            selected:
                                agent.id == controller.selectedAgentId ||
                                agent.typing,
                            onTap: () => controller.openAgentSheet(agent.id),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(LdRadius.card),
        border: Border.all(color: LdColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Réunissez vos agents',
            style: TextStyle(
              color: LdColors.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Connectez les agents que vous utilisez déjà.',
            style: TextStyle(color: LdColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (final provider in AgentProvider.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ProviderBadge(provider: provider, size: 26),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LdPressable(
                  onTap: () {},
                  builder: (context, hovered) => AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 36,
                    decoration: BoxDecoration(
                      color: hovered
                          ? const Color(0xFF333230)
                          : LdColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(LdRadius.control),
                      border: Border.all(color: LdColors.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.add, size: 17, color: LdColors.text),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Connecter un agent',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: LdColors.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LdPressable(
                onTap: () {},
                tooltip: 'Copier le lien d\'invitation',
                builder: (context, hovered) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hovered
                        ? const Color(0xFF333230)
                        : LdColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(LdRadius.control),
                    border: Border.all(color: LdColors.border),
                  ),
                  child: const Icon(
                    Icons.link,
                    size: 17,
                    color: Color(0xFFB7B2AA),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: LdColors.text, fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF262625),
          hintText: 'Rechercher un agent',
          hintStyle: const TextStyle(color: LdColors.textFaint, fontSize: 13.5),
          prefixIcon: const Icon(
            Icons.search,
            size: 17,
            color: LdColors.textFaint,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LdRadius.control),
            borderSide: const BorderSide(color: LdColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LdRadius.control),
            borderSide: const BorderSide(color: LdColors.borderStrong),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Text(
        'Aucun agent ne correspond à cette recherche.',
        style: TextStyle(color: LdColors.textMuted, fontSize: 13),
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final OfficeAgent agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: LdPressable(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? LdColors.selected
                : (hovered ? LdColors.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(LdRadius.control),
          ),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AgentAvatar(style: agent.avatar),
                  if (agent.working)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: LdColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const PulseDot(size: 7),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      agent.name,
                      style: const TextStyle(
                        color: LdColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      agent.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LdColors.textMuted,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProviderBadge(provider: agent.provider, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
