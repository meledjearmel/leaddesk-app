import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../office/office_plan.dart';
import '../../office/plan_editor.dart';

/// Plan vu de dessus, à modifier à la main (D-016) : un clic choisit une
/// salle, un glisser la déplace, aimantée à la grille.
class PlanEditorView extends StatefulWidget {
  const PlanEditorView({required this.editor, super.key});

  final PlanEditor editor;

  @override
  State<PlanEditorView> createState() => _PlanEditorViewState();
}

class _PlanEditorViewState extends State<PlanEditorView> {
  String? _dragId;
  Offset _dragDelta = Offset.zero;

  static const double _padding = 36;

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    return ColoredBox(
      color: const Color(0xFF141312),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plan = editor.plan;
          final cell = _cellFor(constraints.biggest, plan);
          final origin = Offset(
            (constraints.maxWidth - plan.cols * cell) / 2,
            (constraints.maxHeight - plan.rows * cell) / 2 + 12,
          );
          final overlapping = _overlapping(plan);

          Rect rectOf(PlacedRoom room) {
            final drag = room.id == _dragId ? _dragDelta : Offset.zero;
            return Rect.fromLTWH(
              origin.dx + room.x * cell + drag.dx,
              origin.dy + room.y * cell + drag.dy,
              room.cols * cell,
              room.rows * cell,
            );
          }

          String? hit(Offset position) {
            for (final room in plan.rooms.reversed) {
              if (rectOf(room).contains(position)) {
                return room.id;
              }
            }
            return null;
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => editor.select(hit(details.localPosition)),
            onPanStart: (details) {
              final id = hit(details.localPosition);
              editor.select(id);
              setState(() {
                _dragId = id;
                _dragDelta = Offset.zero;
              });
            },
            onPanUpdate: (details) {
              if (_dragId != null) {
                setState(() => _dragDelta += details.delta);
              }
            },
            onPanEnd: (_) => _drop(cell),
            onPanCancel: () => _drop(cell),
            child: CustomPaint(
              size: constraints.biggest,
              painter: _EditorPainter(
                plan: plan,
                rectOf: rectOf,
                origin: origin,
                cell: cell,
                selectedId: editor.selectedId,
                overlapping: overlapping,
                colors: <String, int>{
                  for (final department in editor.departments)
                    department.id: department.color,
                },
              ),
            ),
          );
        },
      ),
    );
  }

  double _cellFor(Size size, OfficePlan plan) {
    final width = (size.width - _padding * 2) / plan.cols;
    final height = (size.height - _padding * 2 - 60) / plan.rows;
    return (width < height ? width : height).clamp(6, 40);
  }

  void _drop(double cell) {
    final id = _dragId;
    if (id == null) {
      return;
    }
    final room = widget.editor.plan.rooms.firstWhere((r) => r.id == id);
    final dx = (_dragDelta.dx / cell).round();
    final dy = (_dragDelta.dy / cell).round();
    setState(() {
      _dragId = null;
      _dragDelta = Offset.zero;
    });
    if (dx != 0 || dy != 0) {
      widget.editor.move(id, room.x + dx, room.y + dy);
    }
  }

  static Set<String> _overlapping(OfficePlan plan) {
    final ids = <String>{};
    for (var i = 0; i < plan.rooms.length; i++) {
      for (var j = i + 1; j < plan.rooms.length; j++) {
        if (plan.rooms[i].overlaps(plan.rooms[j])) {
          ids
            ..add(plan.rooms[i].id)
            ..add(plan.rooms[j].id);
        }
      }
    }
    return ids;
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.plan,
    required this.rectOf,
    required this.origin,
    required this.cell,
    required this.selectedId,
    required this.overlapping,
    required this.colors,
  });

  final OfficePlan plan;
  final Rect Function(PlacedRoom) rectOf;
  final Offset origin;
  final double cell;
  final String? selectedId;
  final Set<String> overlapping;
  final Map<String, int> colors;

  static const Color _danger = Color(0xFFF2617A);

  @override
  void paint(Canvas canvas, Size size) {
    final floor = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      plan.cols * cell,
      plan.rows * cell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(floor.inflate(6), const Radius.circular(10)),
      Paint()..color = const Color(0xFF1C1A18),
    );
    final dot = Paint()..color = const Color(0x22FFFFFF);
    for (var x = 0; x <= plan.cols; x++) {
      for (var y = 0; y <= plan.rows; y++) {
        canvas.drawCircle(
          Offset(origin.dx + x * cell, origin.dy + y * cell),
          0.9,
          dot,
        );
      }
    }

    PlacedRoom? selected;
    for (final room in plan.rooms) {
      if (room.id == selectedId) {
        selected = room;
        continue;
      }
      _paintRoom(canvas, room, selected: false);
    }
    if (selected != null) {
      _paintRoom(canvas, selected, selected: true);
    }
  }

  void _paintRoom(Canvas canvas, PlacedRoom room, {required bool selected}) {
    final rect = rectOf(room).deflate(1.5);
    final base = Color(colors[room.departmentId] ?? 0xFF6E6A64);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(
      rrect,
      Paint()..color = base.withValues(alpha: selected ? 0.42 : 0.26),
    );
    final clash = overlapping.contains(room.id);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.2 : 1.2
        ..color = clash
            ? _danger
            : selected
            ? LdColors.amber
            : base.withValues(alpha: 0.85),
    );

    final seats = room.seats;
    final painter = TextPainter(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: room.label,
            style: const TextStyle(
              fontFamily: 'Segoe UI',
              color: LdColors.text,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (seats > 0)
            TextSpan(
              text: '\n$seats ${seats > 1 ? 'postes' : 'poste'}',
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                color: LdColors.textMuted,
                fontSize: 10.5,
              ),
            ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: (rect.width - 10).clamp(0, double.infinity));
    if (painter.height < rect.height - 6) {
      canvas.save();
      canvas.clipRect(rect);
      painter.paint(canvas, rect.topLeft + const Offset(6, 5));
      canvas.restore();
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_EditorPainter oldDelegate) => true;
}
