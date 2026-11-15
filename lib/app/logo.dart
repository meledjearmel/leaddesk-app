import 'package:flutter/material.dart';

import 'theme.dart';

/// Marque de LeadDesk (D-018) : neuf postes vus de dessus sur un carreau
/// sombre ; le poste en bas à droite, plus grand et ambré, est celui qui
/// mène. Dessin original, lisible de 16 à 1024 px.
class LeadDeskMarkPainter extends CustomPainter {
  const LeadDeskMarkPainter({this.background = true});

  /// Faux : seulement la grille, sans le carreau (pour un fond déjà sombre).
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    final tile = origin & Size.square(s);

    if (background) {
      final rrect = RRect.fromRectAndRadius(tile, Radius.circular(s * 0.23));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF2B2622), Color(0xFF141312)],
          ).createShader(tile),
      );
      canvas.drawRRect(
        rrect.deflate(s * 0.012),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.024
          ..color = const Color(0x2EFFFFFF),
      );
    }

    // Grille 3 × 3 de postes, centrée.
    final inset = s * 0.2;
    final grid = Rect.fromLTWH(
      origin.dx + inset,
      origin.dy + inset,
      s - inset * 2,
      s - inset * 2,
    );
    final step = grid.width / 3;
    final desk = step * 0.58;
    final lead = step * 0.84;

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final center = Offset(
          grid.left + step * (col + 0.5),
          grid.top + step * (row + 0.5),
        );
        final isLead = row == 2 && col == 2;
        final side = isLead ? lead : desk;
        final rect = Rect.fromCenter(center: center, width: side, height: side);
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(side * 0.28),
        );
        if (isLead) {
          canvas.drawRRect(
            rrect.inflate(s * 0.03),
            Paint()
              ..color = LdColors.amber.withValues(alpha: 0.28)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
          );
          canvas.drawRRect(rrect, Paint()..color = LdColors.amber);
        } else {
          canvas.drawRRect(rrect, Paint()..color = const Color(0xFFEDE8E1));
        }
      }
    }
  }

  @override
  bool shouldRepaint(LeadDeskMarkPainter oldDelegate) =>
      oldDelegate.background != background;
}

/// Logo de LeadDesk à la taille voulue.
class LeadDeskLogo extends StatelessWidget {
  const LeadDeskLogo({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LeadDesk',
      child: CustomPaint(
        size: Size.square(size),
        painter: const LeadDeskMarkPainter(),
      ),
    );
  }
}
