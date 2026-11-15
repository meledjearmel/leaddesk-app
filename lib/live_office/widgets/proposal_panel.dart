import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../office/office_plan.dart';
import '../../office/plan_diff.dart';
import '../live_office_controller.dart';
import '../office_source.dart';
import 'common.dart';

/// Couleur de chaque nature de changement, sur l'aperçu et dans la liste.
Color changeColor(RoomChangeKind kind) => switch (kind) {
  RoomChangeKind.added => LdColors.green,
  RoomChangeKind.removed => const Color(0xFFF2617A),
  RoomChangeKind.moved => LdColors.amber,
  RoomChangeKind.resized => const Color(0xFF6EA8FE),
  RoomChangeKind.reassigned => const Color(0xFFA78BFA),
};

/// Panneau de validation d'un réaménagement proposé (D-012, D-015) : motif,
/// aperçu comparé, changements, contrôle des règles, Accepter / Refuser.
class ProposalPanel extends StatelessWidget {
  const ProposalPanel({required this.controller, super.key});

  static const double width = 348;

  final LiveOfficeController controller;

  @override
  Widget build(BuildContext context) {
    final proposal = controller.openProposal!;
    final diff = PlanDiff.compare(controller.serverPlan, proposal.plan);
    final problems = proposal.plan.validate(controller.departments);
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
          _Header(proposal: proposal, onClose: controller.closeProposalPanel),
          _PlanTabs(
            proposed: controller.previewing,
            onChanged: (proposed) =>
                controller.showProposedPlan(proposed: proposed),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              children: <Widget>[
                if (proposal.reason case final reason?
                    when reason.trim().isNotEmpty) ...<Widget>[
                  const _SectionTitle('Motif'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: LdColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(reason, style: _body),
                  ),
                  const SizedBox(height: 18),
                ],
                const _SectionTitle('Aperçu'),
                _PlanSketch(
                  plan: controller.previewing
                      ? proposal.plan
                      : (controller.serverPlan ?? controller.currentPlan),
                  diff: controller.previewing ? diff : null,
                  departments: controller.departments,
                ),
                const SizedBox(height: 18),
                _SectionTitle(
                  diff.isEmpty
                      ? 'Changements'
                      : 'Changements (${diff.changes.length})',
                ),
                if (diff.isEmpty)
                  const Text(
                    'Aucune salle ne change.',
                    style: TextStyle(color: LdColors.textMuted, fontSize: 13),
                  )
                else ...<Widget>[
                  _ChangeSummary(diff: diff),
                  const SizedBox(height: 10),
                  for (final change in _ordered(diff))
                    _ChangeRow(
                      change: change,
                      department: _departmentName(change.room),
                    ),
                ],
                const SizedBox(height: 18),
                const _SectionTitle('Règles'),
                if (problems.isEmpty)
                  const _RuleLine(
                    ok: true,
                    text: 'Le plan respecte toutes les règles.',
                  )
                else
                  for (final problem in problems)
                    _RuleLine(ok: false, text: problem),
              ],
            ),
          ),
          _Footer(
            controller: controller,
            canAccept: problems.isEmpty,
            removesRooms: diff.removesRooms,
          ),
        ],
      ),
    );
  }

  /// Retraits et ajouts d'abord : ce sont eux qui changent le bureau.
  static List<RoomChange> _ordered(PlanDiff diff) {
    const order = <RoomChangeKind>[
      RoomChangeKind.removed,
      RoomChangeKind.added,
      RoomChangeKind.reassigned,
      RoomChangeKind.moved,
      RoomChangeKind.resized,
    ];
    return <RoomChange>[for (final kind in order) ...diff.of(kind)];
  }

  String? _departmentName(PlacedRoom room) {
    for (final department in controller.departments) {
      if (department.id == room.departmentId) {
        return department.name;
      }
    }
    return null;
  }
}

const TextStyle _body = TextStyle(
  color: LdColors.text,
  fontSize: 13.5,
  height: 1.4,
);

class _Header extends StatelessWidget {
  const _Header({required this.proposal, required this.onClose});

  final OfficeProposal proposal;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final author = <String>[
      ?proposal.proposerName,
      ?proposal.proposerPosition,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x24F2B34C),
              borderRadius: BorderRadius.circular(LdRadius.control),
            ),
            child: const Icon(
              Icons.space_dashboard_outlined,
              size: 19,
              color: LdColors.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Réaménagement',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LdColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    _PendingChip(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  author.isEmpty
                      ? 'Version ${proposal.version}'
                      : 'Version ${proposal.version} · $author',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LdColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          LdIconButton(
            icon: Icons.close,
            tooltip: 'Fermer la proposition',
            size: 32,
            iconSize: 17,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x24F2B34C),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        'En attente',
        style: TextStyle(
          color: LdColors.amber,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PlanTabs extends StatelessWidget {
  const _PlanTabs({required this.proposed, required this.onChanged});

  final bool proposed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Plan actuel', 'Plan proposé'];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LdColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: LdPressable(
                  onTap: () => onChanged(i == 1),
                  builder: (context, hovered) {
                    final active = (i == 1) == proposed;
                    return Container(
                      padding: const EdgeInsets.only(top: 6, bottom: 9),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: active ? LdColors.amber : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: active || hovered
                              ? LdColors.text
                              : LdColors.textMuted,
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: LdColors.textMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, this.department});

  final RoomChange change;
  final String? department;

  @override
  Widget build(BuildContext context) {
    final color = changeColor(change.kind);
    final room = change.room;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  room.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LdColors.text, fontSize: 13.5),
                ),
                Text(
                  department ?? 'Lieu commun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LdColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            change.kind.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nombre de salles par nature de changement.
class _ChangeSummary extends StatelessWidget {
  const _ChangeSummary({required this.diff});

  final PlanDiff diff;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final kind in RoomChangeKind.values)
          if (diff.of(kind).length case final count when count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: changeColor(kind).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$count · ${count > 1 ? kind.plural : kind.label.toLowerCase()}',
                style: TextStyle(
                  color: changeColor(kind),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: ok ? LdColors.green : changeColor(RoomChangeKind.removed),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok ? LdColors.textMuted : LdColors.text,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plan vu de dessus : salles à la couleur de leur département, changements
/// soulignés de leur couleur, salles retirées en pointillé.
class _PlanSketch extends StatelessWidget {
  const _PlanSketch({
    required this.plan,
    required this.diff,
    required this.departments,
  });

  final OfficePlan plan;
  final PlanDiff? diff;
  final List<OfficeDepartment> departments;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161514),
          borderRadius: BorderRadius.circular(LdRadius.card),
          border: Border.all(color: LdColors.border),
        ),
        padding: const EdgeInsets.all(10),
        child: CustomPaint(
          painter: _SketchPainter(plan, diff, <String, int>{
            for (final department in departments)
              department.id: department.color,
          }),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.plan, this.diff, this.colors);

  final OfficePlan plan;
  final PlanDiff? diff;
  final Map<String, int> colors;

  @override
  void paint(Canvas canvas, Size size) {
    var cols = plan.cols;
    var rows = plan.rows;
    final removed = diff?.of(RoomChangeKind.removed) ?? const <RoomChange>[];
    for (final change in removed) {
      final room = change.room;
      cols = room.right > cols ? room.right : cols;
      rows = room.bottom > rows ? room.bottom : rows;
    }
    final cell = (size.width / cols) < (size.height / rows)
        ? size.width / cols
        : size.height / rows;
    final origin = Offset(
      (size.width - cols * cell) / 2,
      (size.height - rows * cell) / 2,
    );
    Rect rectOf(PlacedRoom room) => Rect.fromLTWH(
      origin.dx + room.x * cell,
      origin.dy + room.y * cell,
      room.cols * cell,
      room.rows * cell,
    ).deflate(0.8);

    for (final room in plan.rooms) {
      final base = Color(colors[room.departmentId] ?? 0xFF5A5650);
      final rect = RRect.fromRectAndRadius(
        rectOf(room),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = base.withValues(alpha: 0.32));
      final change = diff?.changeOf(room.id);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = change == null ? 1 : 2
          ..color = change == null
              ? base.withValues(alpha: 0.7)
              : changeColor(change.kind),
      );
    }

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = changeColor(RoomChangeKind.removed);
    for (final change in removed) {
      final rect = rectOf(change.room);
      for (final (from, to) in <(Offset, Offset)>[
        (rect.topLeft, rect.topRight),
        (rect.topRight, rect.bottomRight),
        (rect.bottomRight, rect.bottomLeft),
        (rect.bottomLeft, rect.topLeft),
      ]) {
        final length = (to - from).distance;
        final step = (to - from) / length;
        for (var d = 0.0; d < length; d += 6) {
          final end = d + 3 < length ? d + 3 : length;
          canvas.drawLine(from + step * d, from + step * end, dash);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SketchPainter oldDelegate) =>
      oldDelegate.plan != plan || oldDelegate.diff != diff;
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.controller,
    required this.canAccept,
    required this.removesRooms,
  });

  final LiveOfficeController controller;
  final bool canAccept;
  final bool removesRooms;

  @override
  Widget build(BuildContext context) {
    final busy = controller.deciding;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LdColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (controller.decisionError case final error?) ...<Widget>[
            _RuleLine(ok: false, text: error),
            const SizedBox(height: 6),
          ],
          if (!canAccept) ...<Widget>[
            const Text(
              'Ce plan ne respecte pas les règles : il ne peut pas être '
              'accepté.',
              style: TextStyle(color: LdColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: _Button(
                  label: 'Refuser',
                  enabled: !busy,
                  onTap: () => controller.decide(accept: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Button(
                  label: busy ? 'Envoi…' : 'Accepter',
                  primary: true,
                  enabled: canAccept && !busy,
                  onTap: () => _accept(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    if (removesRooms) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: LdColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LdRadius.panel),
            side: const BorderSide(color: LdColors.border),
          ),
          title: const Text(
            'Retirer des salles ?',
            style: TextStyle(color: LdColors.text, fontSize: 17),
          ),
          content: const Text(
            'Ce plan retire des salles du bureau. Les agents qui y '
            'travaillent seront installés dans les autres salles de leur '
            'département.',
            style: TextStyle(color: LdColors.textMuted, fontSize: 13.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: LdColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accepter le plan'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    await controller.decide(accept: true);
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: LdPressable(
        onTap: enabled ? onTap : null,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary
                ? (hovered && enabled
                      ? const Color(0xFFE9E6E1)
                      : const Color(0xFFFFFFFF))
                : (hovered && enabled ? LdColors.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(LdRadius.control),
            border: primary ? null : Border.all(color: LdColors.borderStrong),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: primary ? const Color(0xFF161514) : LdColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau posé sur la carte : une proposition attend le CEO, ou la carte
/// montre l'aperçu du plan proposé.
class ProposalNotice extends StatelessWidget {
  const ProposalNotice({required this.controller, super.key});

  final LiveOfficeController controller;

  @override
  Widget build(BuildContext context) {
    final previewing = controller.previewing;
    final first = controller.proposals.first;
    final count = controller.proposals.length;
    final text = previewing
        ? 'Aperçu du plan proposé'
        : count == 1
        ? 'Réaménagement proposé${first.proposerName == null ? '' : ' par ${first.proposerName}'}'
        : '$count réaménagements proposés';
    return LdPressable(
      onTap: previewing
          ? () => controller.showProposedPlan(proposed: false)
          : () => controller.openProposalPanel(first.id),
      tooltip: previewing ? 'Revenir au plan actuel' : null,
      builder: (context, hovered) => GlassSurface(
        radius: 12,
        borderColor: hovered ? LdColors.amber : const Color(0x66F2B34C),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.space_dashboard_outlined,
              size: 16,
              color: LdColors.amber,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: LdColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              previewing ? 'Plan actuel' : 'Examiner',
              style: const TextStyle(
                color: LdColors.amber,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
