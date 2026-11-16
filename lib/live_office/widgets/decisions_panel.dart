import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../decisions/decisions_controller.dart';
import 'common.dart';

/// Panneau de droite « Décisions » : la file unique des demandes qui
/// attendent le CEO (RM-25), au gabarit de la conversation (image 07).
class DecisionsPanel extends StatelessWidget {
  const DecisionsPanel({required this.controller, this.onClose, super.key});

  static const double width = 348;

  final DecisionsController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
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
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
                child: Row(
                  children: <Widget>[
                    const Flexible(
                      child: Text(
                        'Décisions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LdColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (c.count > 0)
                      StatusChip(label: '${c.count} en attente')
                    else
                      const _Chip('À jour'),
                    const Spacer(),
                    if (onClose != null)
                      LdIconButton(
                        icon: Icons.close,
                        tooltip: 'Fermer les décisions',
                        size: 32,
                        iconSize: 17,
                        onTap: onClose,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: LdColors.border),
              Expanded(
                child: c.loading && c.open.isEmpty
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        children: <Widget>[
                          if (c.error case final message?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                message,
                                style: const TextStyle(
                                  color: Color(0xFFE5776B),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          if (c.open.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: <Widget>[
                                  Icon(
                                    Icons.task_alt,
                                    size: 26,
                                    color: LdColors.textFaint,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Aucune demande en attente.',
                                    style: TextStyle(
                                      color: LdColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final decision in c.open)
                            _DecisionCard(
                              key: ValueKey<int>(decision.id),
                              decision: decision,
                              controller: c,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: LdColors.hover,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: LdColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
  );
}

String _dollars(int micros) =>
    '${(micros / 1000000).toStringAsFixed(2).replaceAll('.', ',')} \$';

class _DecisionCard extends StatefulWidget {
  const _DecisionCard({
    required this.decision,
    required this.controller,
    super.key,
  });

  final CeoDecision decision;
  final DecisionsController controller;

  @override
  State<_DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends State<_DecisionCard> {
  final TextEditingController _note = TextEditingController();
  late final TextEditingController _limit = TextEditingController(
    text: widget.decision.limitMicros == null
        ? ''
        : (widget.decision.limitMicros! * 2 / 1000000)
              .toStringAsFixed(2)
              .replaceAll('.', ','),
  );
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    // « Envoyer » s'active dès qu'une question est écrite.
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _limit.dispose();
    super.dispose();
  }

  int? _newLimit() {
    final value = double.tryParse(_limit.text.trim().replaceAll(',', '.'));
    return value == null || value <= 0 ? null : (value * 1000000).round();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.decision;
    final c = widget.controller;
    final busy = c.isBusy(d.id);
    final details = <String>[
      ?d.summary,
      if (d.kind == 'cost_limit' && d.limitMicros != null)
        'Dépensé ${_dollars(d.spentMicros ?? 0)} sur une limite de '
            '${_dollars(d.limitMicros!)}. L\'exécution attend votre décision.',
      if (d.status == 'needs_info' && d.note != null)
        'Précisions demandées : ${d.note}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(LdRadius.card),
        border: Border.all(color: LdColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[d.kindLabel, ?d.requestedBy].join(' · '),
            style: const TextStyle(color: LdColors.amber, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            d.displayTitle,
            style: const TextStyle(
              color: LdColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          for (final line in details) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              line,
              style: const TextStyle(
                color: LdColors.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (d.kind == 'cost_limit' && d.status == 'pending') ...<Widget>[
            const SizedBox(height: 10),
            _Field(controller: _limit, label: 'Nouvelle limite (\$)'),
          ],
          if (_asking) ...<Widget>[
            const SizedBox(height: 10),
            _Field(controller: _note, label: 'Votre question à l\'agent'),
          ],
          const SizedBox(height: 12),
          if (d.status == 'needs_info')
            const Text(
              'En attente de la réponse de l\'agent.',
              style: TextStyle(color: LdColors.textFaint, fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (_asking) ...<Widget>[
                  _Button(
                    label: 'Envoyer',
                    primary: true,
                    onTap: busy || _note.text.trim().isEmpty
                        ? null
                        : () => c.requestInfo(d, _note.text),
                  ),

                  _Button(
                    label: 'Annuler',
                    onTap: () => setState(() => _asking = false),
                  ),
                ] else ...<Widget>[
                  _Button(
                    label: 'Approuver',
                    primary: true,
                    onTap: busy
                        ? null
                        : () => c.approve(
                            d,
                            newLimitMicros: d.kind == 'cost_limit'
                                ? _newLimit()
                                : null,
                          ),
                  ),

                  _Button(
                    label: 'Refuser',
                    onTap: busy ? null : () => c.reject(d),
                  ),

                  LdIconButton(
                    icon: Icons.help_outline,
                    tooltip: 'Demander des précisions',
                    size: 32,
                    iconSize: 17,
                    onTap: busy ? null : () => setState(() => _asking = true),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(color: LdColors.text, fontSize: 13.5),
    decoration: InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF262625),
      labelText: label,
      labelStyle: const TextStyle(color: LdColors.textMuted, fontSize: 13),
      contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LdColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LdColors.borderStrong),
      ),
    ),
  );
}

class _Button extends StatelessWidget {
  const _Button({required this.label, this.onTap, this.primary = false});

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return LdPressable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary && enabled
              ? (hovered ? const Color(0xFFEDEAE4) : const Color(0xFFFFFFFF))
              : (hovered ? LdColors.hover : const Color(0xFF262625)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary && enabled ? Colors.transparent : LdColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? LdColors.textFaint
                : (primary ? const Color(0xFF161514) : LdColors.text),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
