import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models.dart';

/// Surface en verre dépoli posée sur la scène : flou d'arrière-plan, teinte
/// sombre translucide et liseré clair.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.radius = LdRadius.card,
    this.padding = EdgeInsets.zero,
    this.borderColor = LdColors.border,
    this.borderWidth = 1,
    this.blur = 18,
    this.color = LdColors.glass,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double borderWidth;

  /// Force du flou ; 0 le désactive (étiquettes nombreuses sur la scène).
  final double blur;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: blur <= 0
            ? body
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: body,
              ),
      ),
    );
  }
}

/// Zone cliquable qui réagit au survol.
class LdPressable extends StatefulWidget {
  const LdPressable({
    required this.builder,
    this.onTap,
    this.tooltip,
    super.key,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<LdPressable> createState() => _LdPressableState();
}

class _LdPressableState extends State<LdPressable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _hovered && enabled),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }
    return Semantics(button: enabled, label: tooltip, child: child);
  }
}

/// Bouton carré à icône, utilisé par le rail et les barres de contrôle.
class LdIconButton extends StatelessWidget {
  const LdIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.size = 36,
    this.iconSize = 19,
    this.color,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return LdPressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? LdColors.selected
              : (hovered ? LdColors.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(LdRadius.control),
          border: Border.all(
            color: active ? LdColors.border : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color:
              color ??
              (active || hovered ? LdColors.text : const Color(0xFFB7B2AA)),
        ),
      ),
    );
  }
}

/// Pastille verte qui pulse : une tâche est en cours.
class PulseDot extends StatefulWidget {
  const PulseDot({this.size = 8, this.color = LdColors.green, super.key});

  final double size;
  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // Respecte le réglage « réduire les animations » du système.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _controller.repeat(reverse: true).ignore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25 + 0.45 * t),
                blurRadius: 3 + 6 * t,
                spreadRadius: 1.5 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Trois points animés : l'agent rédige.
class TypingDots extends StatefulWidget {
  const TypingDots({this.color = const Color(0xFFB7B2AA), super.key});

  final Color color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _controller.repeat().ignore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'En train d\'écrire',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: Opacity(
                  opacity:
                      0.35 +
                      0.65 *
                          max(0, sin((_controller.value - i * 0.18) * 2 * pi)),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Portrait rond d'un agent, dessiné par le code (création originale).
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({required this.style, this.size = 36, super.key});

  final AvatarStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AvatarPainter(style)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter(this.style);

  final AvatarStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint();
    canvas
      ..save()
      ..clipPath(Path()..addOval(Offset.zero & size))
      ..drawRect(Offset.zero & size, paint..color = style.background);
    if (style.longHair) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.2, s * 0.22, s * 0.6, s * 0.62),
          Radius.circular(s * 0.26),
        ),
        paint..color = style.hair,
      );
    }
    canvas
      // Épaules.
      ..drawOval(
        Rect.fromCenter(
          center: Offset(s / 2, s * 1.04),
          width: s * 0.86,
          height: s * 0.62,
        ),
        paint..color = style.top,
      )
      // Cou.
      ..drawRect(
        Rect.fromLTWH(s * 0.43, s * 0.62, s * 0.14, s * 0.14),
        paint..color = Color.lerp(style.skin, const Color(0xFF000000), 0.14)!,
      )
      // Chevelure puis visage.
      ..drawCircle(Offset(s / 2, s * 0.42), s * 0.27, paint..color = style.hair)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(s / 2, s * 0.5),
          width: s * 0.42,
          height: s * 0.44,
        ),
        paint..color = style.skin,
      );
    // Frange.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s / 2, s * 0.44),
        width: s * 0.5,
        height: s * 0.42,
      ),
      pi * 1.05,
      pi * 0.9,
      false,
      paint..color = style.hair,
    );
    const ink = Color(0xFF2A1D1A);
    canvas
      ..drawCircle(Offset(s * 0.42, s * 0.51), s * 0.028, paint..color = ink)
      ..drawCircle(Offset(s * 0.58, s * 0.51), s * 0.028, paint);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, s * 0.03)
      ..strokeCap = StrokeCap.round
      ..color = ink;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s / 2, s * 0.58),
        width: s * 0.16,
        height: s * 0.1,
      ),
      pi * 0.15,
      pi * 0.7,
      false,
      stroke,
    );
    if (style.glasses) {
      canvas
        ..drawCircle(Offset(s * 0.42, s * 0.51), s * 0.07, stroke)
        ..drawCircle(Offset(s * 0.58, s * 0.51), s * 0.07, stroke)
        ..drawLine(
          Offset(s * 0.49, s * 0.51),
          Offset(s * 0.51, s * 0.51),
          stroke,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => oldDelegate.style != style;
}

/// Pictogramme du fournisseur, seul ou dans une pastille ronde.
class ProviderBadge extends StatelessWidget {
  const ProviderBadge({
    required this.provider,
    this.size = 28,
    this.framed = true,
    super.key,
  });

  final AgentProvider provider;
  final double size;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      provider.icon,
      size: framed ? size * 0.56 : size,
      color: provider.color,
    );
    if (!framed) {
      return icon;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF282725),
        shape: BoxShape.circle,
        border: Border.all(color: LdColors.border),
      ),
      child: icon,
    );
  }
}

/// Pastille de statut verte (« En cours », « Présent »).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, this.pulse = false, super.key});

  final String label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LdColors.greenSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (pulse) ...<Widget>[
            const PulseDot(size: 6),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: LdColors.green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
