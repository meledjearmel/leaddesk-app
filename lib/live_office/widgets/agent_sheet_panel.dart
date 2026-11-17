import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../agent_sheet.dart';
import '../live_office_controller.dart';
import '../models.dart';
import 'common.dart';

/// Fiche d'un agent, à droite du bureau (D-029) : qui il est, ce qu'il
/// fait, ce qu'il coûte, son parcours.
class AgentSheetPanel extends StatelessWidget {
  const AgentSheetPanel({
    required this.office,
    required this.agent,
    this.sheet,
    this.onEdit,
    super.key,
  });

  static const double width = 348;

  final LiveOfficeController office;
  final OfficeAgent agent;

  /// Données du serveur ; absentes en démonstration.
  final AgentSheetController? sheet;

  /// Ouvre l'agent dans l'administration.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final sheet = this.sheet;
    final body = sheet == null
        ? _content(context, null)
        : ListenableBuilder(
            listenable: sheet,
            builder: (context, _) => _content(context, sheet),
          );
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: LdColors.surface,
        borderRadius: BorderRadius.circular(LdRadius.panel),
        border: Border.all(color: LdColors.border),
      ),
      child: body,
    );
  }

  Widget _content(BuildContext context, AgentSheetController? sheet) {
    final dossier = sheet?.dossier;
    final department = office.departments
        .where((d) => d.id == agent.departmentId)
        .firstOrNull;
    final current = dossier?.currentRun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: <Widget>[
              AgentAvatar(style: agent.avatar, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LdColors.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dossier?.position?.title ?? agent.position,
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
                tooltip: 'Fermer la fiche',
                size: 32,
                iconSize: 17,
                onTap: office.closeAgentSheet,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: LdColors.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: <Widget>[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (current != null)
                    StatusChip(label: _runLabel(current.status), pulse: true)
                  else if (dossier?.agent.active ?? agent.working)
                    const StatusChip(label: 'En service')
                  else
                    _Chip(agent.status),
                  if (department != null)
                    _Chip(department.name, dot: Color(department.color)),
                ],
              ),
              if (dossier != null && dossier.unitPath.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  dossier.unitPath,
                  style: const TextStyle(
                    color: LdColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
              if (dossier?.agent.bio case final bio?
                  when bio.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  bio,
                  style: const TextStyle(
                    color: LdColors.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (sheet == null || sheet.agentId == null) ...<Widget>[
                const SizedBox(height: 16),
                const Text(
                  'Agent de démonstration : connectez-vous à votre '
                  'entreprise pour voir sa fiche réelle.',
                  style: TextStyle(color: LdColors.textFaint, fontSize: 12.5),
                ),
              ] else if (sheet.loading && dossier == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (sheet.error case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFE5776B),
                      fontSize: 12.5,
                    ),
                  ),
                )
              else if (dossier != null)
                ..._sections(dossier),
              if (onEdit != null && sheet?.agentId != null) ...<Widget>[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LdPressable(
                    onTap: onEdit,
                    builder: (context, hovered) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: hovered
                            ? LdColors.hover
                            : const Color(0xFF262625),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: LdColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.settings_outlined,
                            size: 15,
                            color: LdColors.text,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Modifier dans l\'administration',
                            style: TextStyle(
                              color: LdColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _sections(AgentDossier d) {
    final current = d.currentRun;
    final open = d.tasks.where((t) => !t.done).toList();
    return <Widget>[
      const _Title('En ce moment'),
      _Line(
        current == null
            ? (open.isEmpty
                  ? 'Aucune tâche en cours.'
                  : 'Disponible · ${open.length} tâche'
                        '${open.length > 1 ? 's' : ''} à faire.')
            : '${d.taskTitle(current.taskId) ?? 'Tâche n°${current.taskId}'}'
                  ' · ${_runLabel(current.status).toLowerCase()}'
                  '${current.device == null ? '' : ' sur ${current.device}'}',
      ),
      const _Title('Coût réel'),
      _Line(
        '${_dollars(d.costMicros)} sur ${d.runs.length} exécution'
        '${d.runs.length > 1 ? 's' : ''}',
      ),
      const _Title('Modèles IA'),
      if (d.models.isEmpty)
        const _Line('Aucun modèle : l\'agent ne peut pas travailler.')
      else
        for (final (name, isDefault) in d.models)
          _Line(isDefault ? '$name · par défaut' : name),
      const _Title('Tâches'),
      if (d.tasks.isEmpty)
        const _Line('Aucune tâche confiée.')
      else
        for (final t in d.tasks.take(8))
          _Line(
            '${t.done ? '✓ ' : ''}${t.title}${t.lead ? ' · responsable' : ''}',
            faint: t.done,
          ),
      const _Title('Parcours'),
      if (d.assignments.isEmpty)
        const _Line('Jamais affecté à un poste.')
      else
        for (final a in d.assignments)
          _Line(
            '${a.position} · ${_date(a.startedAt)}'
            '${a.endedAt == null ? ' → aujourd\'hui' : ' → ${_date(a.endedAt)}'}',
            faint: a.endedAt != null,
          ),
    ];
  }

  static String _runLabel(String status) => switch (status) {
    'running' => 'Au travail',
    'paused' => 'En pause',
    'paused_cost' => 'Limite de coût atteinte',
    'completed' => 'Terminée',
    'failed' => 'Échec',
    _ => status,
  };

  static String _dollars(int micros) =>
      '${(micros / 1000000).toStringAsFixed(2).replaceAll('.', ',')} \$';

  static String _date(DateTime? d) => d == null
      ? '?'
      : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: LdColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.faint = false});

  final String text;
  final bool faint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        color: faint ? LdColors.textFaint : LdColors.textMuted,
        fontSize: 12.5,
        height: 1.35,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.dot});

  final String label;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: LdColors.hover,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (dot case final color?) ...<Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            color: LdColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}
