import 'package:flutter/material.dart';

import '../../app/logo.dart';
import 'common.dart';

/// Rail d'icônes : logo, navigation principale, réglages.
class IconRail extends StatelessWidget {
  const IconRail({
    required this.agentPanelOpen,
    required this.onToggleAgentPanel,
    this.onSignOut,
    this.runPanelOpen = false,
    this.onToggleRunPanel,
    super.key,
  });

  static const double width = 52;

  final bool agentPanelOpen;
  final VoidCallback onToggleAgentPanel;

  /// Panneau « Exécution » (moteur local) ; absent en démonstration.
  final bool runPanelOpen;
  final VoidCallback? onToggleRunPanel;

  /// Déconnexion du compte ; absente en démonstration.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 4),
          const LeadDeskLogo(),
          const SizedBox(height: 18),
          const LdIconButton(icon: Icons.search, tooltip: 'Rechercher'),
          const SizedBox(height: 6),
          LdIconButton(
            icon: Icons.map_outlined,
            tooltip: agentPanelOpen
                ? 'Bureau vivant'
                : 'Bureau vivant · afficher les agents',
            active: true,
            onTap: onToggleAgentPanel,
          ),
          const SizedBox(height: 6),
          const LdIconButton(
            icon: Icons.monitor_heart_outlined,
            tooltip: 'Activité',
          ),
          if (onToggleRunPanel case final toggle?) ...<Widget>[
            const SizedBox(height: 6),
            LdIconButton(
              icon: Icons.play_circle_outline,
              tooltip: 'Exécution',
              active: runPanelOpen,
              onTap: toggle,
            ),
          ],
          const SizedBox(height: 6),
          const LdIconButton(icon: Icons.power_outlined, tooltip: 'Connexions'),
          const SizedBox(height: 6),
          const LdIconButton(icon: Icons.group_outlined, tooltip: 'Équipe'),
          const SizedBox(height: 6),
          const LdIconButton(
            icon: Icons.notifications_none,
            tooltip: 'Notifications',
          ),
          const Spacer(),
          const LdIconButton(icon: Icons.layers_outlined, tooltip: 'Projets'),
          const SizedBox(height: 6),
          const LdIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Réglages',
          ),
          if (onSignOut case final signOut?) ...<Widget>[
            const SizedBox(height: 6),
            LdIconButton(
              icon: Icons.logout,
              tooltip: 'Se déconnecter',
              onTap: signOut,
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
