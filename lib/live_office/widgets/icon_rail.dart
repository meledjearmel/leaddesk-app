import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'common.dart';

/// Rail d'icônes : logo, navigation principale, réglages.
class IconRail extends StatelessWidget {
  const IconRail({
    required this.agentPanelOpen,
    required this.onToggleAgentPanel,
    super.key,
  });

  static const double width = 52;

  final bool agentPanelOpen;
  final VoidCallback onToggleAgentPanel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 4),
          const _LogoTile(),
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Logo de LeadDesk : une grille de neuf points dont un point ambre.
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LeadDesk',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A19),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LdColors.borderStrong),
        ),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CustomPaint(painter: _LogoPainter()),
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final step = size.width / 3;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final accent = row == 2 && col == 2;
        canvas.drawCircle(
          Offset(step * (col + 0.5), step * (row + 0.5)),
          accent ? step * 0.36 : step * 0.28,
          paint..color = accent ? LdColors.amber : LdColors.text,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
