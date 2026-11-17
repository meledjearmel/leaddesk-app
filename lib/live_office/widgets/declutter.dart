import 'package:flutter/widgets.dart';

/// Étiquette à poser sur la scène sans chevaucher les autres (D-031).
class TagEntry {
  const TagEntry({
    required this.id,
    required this.anchor,
    required this.child,
    this.shift = const Offset(-0.5, -1),
    this.priority = 0,
  });

  final Object id;

  /// Point d'accroche à l'écran.
  final Offset anchor;

  /// Décalage en fraction de la taille de l'étiquette : (-0,5 ; -1) pose
  /// l'étiquette au-dessus du point, centrée.
  final Offset shift;

  /// Les plus prioritaires se placent d'abord (sélection, conversation).
  final int priority;
  final Widget child;
}

/// Pose des étiquettes en évitant qu'elles se recouvrent ou passent sous
/// les barres de la carte. Une étiquette qui ne trouve pas de place libre
/// près de son point est masquée, sauf la plus prioritaire.
class DeclutteredTags extends StatelessWidget {
  const DeclutteredTags({
    required this.entries,
    this.safeArea = EdgeInsets.zero,
    this.gap = 4,
    this.maxVisible,
    super.key,
  });

  final List<TagEntry> entries;

  /// Bandes réservées aux barres (haut et bas de la carte).
  final EdgeInsets safeArea;
  final double gap;

  /// Nombre maximal d'étiquettes visibles ; les plus prioritaires d'abord.
  final int? maxVisible;

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _DeclutterDelegate(entries, safeArea, gap, maxVisible),
    children: <Widget>[
      for (final entry in entries) LayoutId(id: entry.id, child: entry.child),
    ],
  );
}

class _DeclutterDelegate extends MultiChildLayoutDelegate {
  _DeclutterDelegate(this.entries, this.safeArea, this.gap, this.maxVisible);

  final List<TagEntry> entries;
  final EdgeInsets safeArea;
  final double gap;
  final int? maxVisible;

  /// Positions retenues lors du dernier placement, pour les tests.
  static Map<Object, Rect?> lastLayout = <Object, Rect?>{};

  @override
  void performLayout(Size size) {
    final area = safeArea.deflateRect(Offset.zero & size);
    final ordered = List<TagEntry>.of(entries)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final placed = <Rect>[];
    final result = <Object, Rect?>{};
    final top = ordered.isEmpty ? null : ordered.first.priority;
    for (final entry in ordered) {
      final s = layoutChild(entry.id, BoxConstraints.loose(size));
      final desired =
          entry.anchor +
          Offset(entry.shift.dx * s.width, entry.shift.dy * s.height);
      Rect rectAt(Offset at) => at & s;
      // Hors de la vue : rien à arbitrer.
      if (!rectAt(desired).overlaps(Offset.zero & size)) {
        positionChild(entry.id, desired);
        result[entry.id] = rectAt(desired);
        continue;
      }
      final forced = entry.priority == top && entry.priority > 0;
      final full = maxVisible != null && placed.length >= maxVisible!;
      Rect? chosen;
      final step = s.height + gap;
      for (final dy in <double>[
        0,
        -step,
        step,
        -2 * step,
        2 * step,
        -3 * step,
      ]) {
        final candidate = rectAt(desired + Offset(0, dy));
        final free = !placed.any((r) => r.inflate(gap / 2).overlaps(candidate));
        final inside =
            candidate.top >= area.top && candidate.bottom <= area.bottom;
        if (free && inside && !full) {
          chosen = candidate;
          break;
        }
      }
      if (chosen == null && forced) {
        // La sélection reste toujours visible, quitte à chevaucher.
        chosen = rectAt(desired);
      }
      if (chosen == null) {
        positionChild(entry.id, const Offset(-100000, -100000));
        result[entry.id] = null;
        continue;
      }
      placed.add(chosen);
      positionChild(entry.id, chosen.topLeft);
      result[entry.id] = chosen;
    }
    lastLayout = result;
  }

  @override
  bool shouldRelayout(_DeclutterDelegate oldDelegate) => true;
}

/// Positions du dernier placement : `null` pour une étiquette masquée.
Map<Object, Rect?> get lastDeclutterLayout => _DeclutterDelegate.lastLayout;
