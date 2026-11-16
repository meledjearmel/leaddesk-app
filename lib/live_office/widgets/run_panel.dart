import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../engine/agent_runner.dart';
import '../../engine/run_controller.dart';
import 'common.dart';

const Color _red = Color(0xFFE5776B);
const Color _redSoft = Color(0x29E5776B);
const Color _amberSoft = Color(0x29F0B54B);

/// Panneau de droite « Exécution » : lancer une tâche avec un agent sur cet
/// ordinateur et suivre ses étapes (D-022). Même gabarit que la
/// conversation (image de référence 07).
class RunPanel extends StatefulWidget {
  const RunPanel({required this.controller, this.onClose, super.key});

  static const double width = 348;

  final RunController controller;
  final VoidCallback? onClose;

  @override
  State<RunPanel> createState() => _RunPanelState();
}

class _RunPanelState extends State<RunPanel> {
  final ScrollController _scroll = ScrollController();
  int _tab = 0;
  int _shownSteps = 0;

  RunController get _c => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followSteps() {
    if (_c.steps.length == _shownSteps) {
      return;
    }
    _shownSteps = _c.steps.length;
    // La dernière étape est en bas : on la garde en vue.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        _followSteps();
        final tracking = _c.running || _c.report != null || _c.steps.isNotEmpty;
        return Container(
          width: RunPanel.width,
          decoration: BoxDecoration(
            color: LdColors.surface,
            borderRadius: BorderRadius.circular(LdRadius.panel),
            border: Border.all(color: LdColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(controller: _c, onClose: widget.onClose),
              _Tabs(
                index: _tab,
                labels: const <String>['Étapes', 'Réglages'],
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(
                child: _tab == 1
                    ? _Settings(controller: _c)
                    : tracking
                    ? _StepList(controller: _c, scroll: _scroll)
                    : _Launcher(controller: _c),
              ),
              if (_tab == 0) _Footer(controller: _c),
            ],
          ),
        );
      },
    );
  }
}

/// État de l'exécution, pour l'en-tête.
(String, Color, Color, bool) _status(RunController c) {
  if (c.running) {
    return ('En cours', LdColors.green, LdColors.greenSoft, true);
  }
  if (c.error != null) {
    return ('Erreur', _red, _redSoft, false);
  }
  return switch (c.report?.outcome) {
    RunOutcome.completed => (
      'Terminée',
      LdColors.green,
      LdColors.greenSoft,
      false,
    ),
    RunOutcome.failed => ('Échec', _red, _redSoft, false),
    RunOutcome.pausedCost => ('En pause', LdColors.amber, _amberSoft, false),
    RunOutcome.stoppedByCeo => ('Arrêtée', LdColors.amber, _amberSoft, false),
    null => ('Prête', LdColors.textMuted, LdColors.hover, false),
  };
}

String _cost(int micros) {
  final dollars = micros / 1000000;
  return dollars < 0.01 && micros > 0
      ? '< 0,01 \$'
      : '${dollars.toStringAsFixed(2).replaceAll('.', ',')} \$';
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, this.onClose});

  final RunController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final (label, color, background, pulse) = _status(controller);
    final name = controller.agentName;
    final task = controller.task?.title;
    final cost = controller.report?.costMicros;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Initials(name: name ?? '?'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name ?? 'Exécution',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LdColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: label,
                      color: color,
                      background: background,
                      pulse: pulse,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    task ?? 'Aucune tâche choisie',
                    if (cost != null) _cost(cost),
                  ].join(' · '),
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
          if (onClose != null)
            LdIconButton(
              icon: Icons.close,
              tooltip: 'Fermer l\'exécution',
              size: 32,
              iconSize: 17,
              onTap: onClose,
            ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF3A3937),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFFD9D5CE),
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.background,
    this.pulse = false,
  });

  final String label;
  final Color color;
  final Color background;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    if (color == LdColors.green) {
      return StatusChip(label: label, pulse: pulse);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => onChanged(i),
                  builder: (context, hovered) => Container(
                    padding: const EdgeInsets.only(top: 6, bottom: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i == index
                              ? LdColors.amber
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: i == index || hovered
                            ? LdColors.text
                            : LdColors.textMuted,
                        fontSize: 14,
                        fontWeight: i == index
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
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

const TextStyle _sectionStyle = TextStyle(
  color: LdColors.textMuted,
  fontSize: 12.5,
);

/// Choix de la tâche et de l'agent.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.controller});

  final RunController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.loading && c.tasks.isEmpty) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final task = c.task;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: <Widget>[
        if (c.tasks.isNotEmpty) ...<Widget>[
          const _Section('Tâche'),
          for (final t in c.tasks)
            _Choice(
              title: t.title,
              subtitle: t.agents.isEmpty
                  ? 'Aucun agent affecté'
                  : t.agents.map((a) => a.$2).join(', '),
              selected: t.id == task?.id,
              onTap: () => c.selectTask(t.id),
            ),
        ],
        if (task != null && task.agents.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const _Section('Agent'),
          for (final (id, name, lead) in task.agents)
            _Choice(
              leading: _Initials(name: name, size: 30),
              title: name,
              subtitle: lead ? 'Responsable de la tâche' : 'Affecté',
              selected: id == c.agentId,
              onTap: () => c.selectAgent(id),
            ),
        ],
        if (c.blocker ?? c.error case final message?)
          _Note(icon: Icons.info_outline, text: message),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(label, style: _sectionStyle),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LdPressable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? LdColors.selected
                : (hovered ? LdColors.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(LdRadius.control),
            border: Border.all(
              color: selected ? LdColors.borderStrong : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              if (leading case final widget?) ...<Widget>[
                widget,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LdColors.text,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
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
              if (selected)
                const Icon(Icons.check, size: 16, color: LdColors.amber),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fil des étapes : texte de l'agent en bulles, actions en notes.
class _StepList extends StatelessWidget {
  const _StepList({required this.controller, required this.scroll});

  final RunController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final name = c.agentName ?? 'Agent';
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: <Widget>[
        for (final step in c.steps)
          switch (step.kind) {
            'model' => _Bubble(name: name, text: step.text),
            'tool' => _Note(icon: Icons.description_outlined, text: step.text),
            'approval' => _Note(
              icon: Icons.front_hand_outlined,
              text: step.text,
              color: LdColors.amber,
            ),
            'error' => _Note(
              icon: Icons.error_outline,
              text: step.text,
              color: _red,
            ),
            _ => _Note(icon: Icons.bolt_outlined, text: step.text),
          },
        if (c.running)
          _Bubble(
            name: name,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: TypingDots(),
            ),
          ),
        if (c.report case final report? when !c.running)
          _Note(
            icon: report.outcome == RunOutcome.completed
                ? Icons.task_alt
                : Icons.pause_circle_outline,
            text: report.outcome == RunOutcome.completed
                ? 'Compte rendu publié dans la conversation de l\'activité · '
                      '${_cost(report.costMicros)}'
                : report.summary,
            color: report.outcome == RunOutcome.completed
                ? LdColors.green
                : LdColors.amber,
          ),
        if (c.error case final message? when !c.running)
          _Note(icon: Icons.error_outline, text: message, color: _red),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.name, this.text, this.child});

  final String name;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 42, bottom: 5),
            child: Text(
              name,
              style: const TextStyle(color: LdColors.textMuted, fontSize: 12),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _Initials(name: name, size: 32),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: LdColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      child ??
                      Text(
                        text ?? '',
                        style: const TextStyle(
                          color: LdColors.text,
                          fontSize: 14,
                          height: 1.4,
                        ),
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

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color ?? LdColors.textFaint),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? LdColors.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal : lancer, ou relancer une fois l'exécution finie.
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final RunController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final done = !c.running && (c.report != null || c.error != null);
    final enabled = done || c.canLaunch;
    final label = c.running
        ? 'L\'agent travaille…'
        : (done ? 'Nouvelle exécution' : 'Lancer la tâche');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: LdPressable(
        onTap: !enabled ? null : (done ? c.reset : c.launch),
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? (hovered ? const Color(0xFFEDEAE4) : const Color(0xFFFFFFFF))
                : const Color(0xFF262625),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                done ? Icons.refresh : Icons.play_arrow_rounded,
                size: 18,
                color: enabled ? const Color(0xFF161514) : LdColors.textFaint,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? const Color(0xFF161514) : LdColors.textFaint,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clé du fournisseur et poste hôte.
class _Settings extends StatefulWidget {
  const _Settings({required this.controller});

  final RunController controller;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final TextEditingController _key = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.saveKey(_key.text);
    _key.clear();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: <Widget>[
        const _Section('Clé Anthropic'),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _save(),
          style: const TextStyle(color: LdColors.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF262625),
            hintText: c.keyMask == null
                ? 'sk-ant-…'
                : 'Clé enregistrée ${c.keyMask}',
            hintStyle: const TextStyle(color: LdColors.textFaint, fontSize: 14),
            contentPadding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: LdIconButton(
                icon: Icons.check,
                tooltip: 'Enregistrer la clé',
                size: 32,
                iconSize: 17,
                onTap: _saving ? null : _save,
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 32,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: LdColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: LdColors.borderStrong),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _Note(
          icon: Icons.lock_outline,
          text:
              'La clé reste dans le coffre de Windows sur cet ordinateur. Elle '
              'n\'est envoyée qu\'à Anthropic, jamais au serveur LeadDesk.',
        ),
        if (c.keyMask != null)
          LdPressable(
            onTap: () => c.saveKey(''),
            builder: (context, hovered) => Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 12),
              child: Text(
                'Retirer la clé',
                style: TextStyle(
                  color: hovered ? LdColors.text : LdColors.textMuted,
                  fontSize: 12.5,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        const _Section('Cet ordinateur'),
        _Note(
          icon: Icons.computer_outlined,
          text: c.deviceId != null
              ? '${c.host.name} · enregistré, en ligne'
              : (c.deviceError ?? 'Enregistrement en cours…'),
          color: c.deviceId != null ? null : _red,
        ),
      ],
    );
  }
}
