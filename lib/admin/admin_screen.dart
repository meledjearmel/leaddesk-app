import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../live_office/widgets/common.dart';
import 'admin_controller.dart';
import 'admin_models.dart';
import 'model_catalog.dart';

/// Espace « Administration » (D-026) : le back-office prend la place du
/// bureau. Rubriques en haut, liste à gauche, éditeur à droite.
class AdminScreen extends StatelessWidget {
  const AdminScreen({required this.controller, this.onClose, super.key});

  final AdminController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Container(
          decoration: BoxDecoration(
            color: LdColors.surface,
            borderRadius: BorderRadius.circular(LdRadius.panel),
            border: Border.all(color: LdColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                child: Row(
                  children: <Widget>[
                    const Text(
                      'Administration',
                      style: TextStyle(
                        color: LdColors.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (final s in AdminSection.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _Tab(
                                  label: s.label,
                                  active: c.section == s,
                                  onTap: () => c.open(s),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (onClose != null)
                      LdIconButton(
                        icon: Icons.close,
                        tooltip: 'Fermer l\'administration',
                        size: 32,
                        iconSize: 17,
                        onTap: onClose,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: LdColors.border),
              Expanded(
                child: c.loading && c.units.isEmpty && c.companyName.isEmpty
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : c.section == AdminSection.company
                    ? _CompanyEditor(
                        key: ValueKey<String>('company-${c.companyName}'),
                        controller: c,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final listWidth = constraints.maxWidth < 760
                              ? constraints.maxWidth * 0.42
                              : 320.0;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(
                                width: listWidth,
                                child: _RecordList(controller: c),
                              ),
                              const VerticalDivider(
                                width: 1,
                                color: LdColors.border,
                              ),
                              Expanded(child: _Editor(controller: c)),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LdPressable(
    onTap: onTap,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? LdColors.selected
            : (hovered ? LdColors.hover : Colors.transparent),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active ? LdColors.border : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? LdColors.text : LdColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

// Liste.

/// Une ligne de liste : titre, sous-titre, pastille d'état.
typedef _Row = ({
  int id,
  String title,
  String? subtitle,
  String? badge,
  bool badgeOn,
  int depth,
  Color? color,
});

class _RecordList extends StatelessWidget {
  const _RecordList({required this.controller});

  final AdminController controller;

  List<_Row> _rows() {
    final c = controller;
    String status(String s) => s == 'active' ? 'En service' : 'Brouillon';
    Color? hex(String? v) {
      final n = int.tryParse((v ?? '').replaceFirst('#', ''), radix: 16);
      return n == null ? null : Color(0xFF000000 | n);
    }

    return switch ((c.section, c.showTrash)) {
      (AdminSection.units, false) => <_Row>[
        for (final (u, depth) in c.unitTree)
          (
            id: u.id,
            title: u.name,
            subtitle: u.kind,
            badge: u.systemRole == null ? null : 'Système',
            badgeOn: false,
            depth: depth,
            color: hex(u.color),
          ),
      ],
      (AdminSection.units, true) => <_Row>[
        for (final u in c.trashedUnits)
          (
            id: u.id,
            title: u.name,
            subtitle: u.kind,
            badge: null,
            badgeOn: false,
            depth: 0,
            color: hex(u.color),
          ),
      ],
      (AdminSection.positions, final trash) => <_Row>[
        for (final p in trash ? c.trashedPositions : c.positions)
          (
            id: p.id,
            title: p.title,
            subtitle: c.unitPath(p.unitId),
            badge: trash ? null : status(p.status),
            badgeOn: p.status == 'active',
            depth: 0,
            color: null,
          ),
      ],
      (AdminSection.agents, final trash) => <_Row>[
        for (final a in trash ? c.trashedAgents : c.agents)
          (
            id: a.id,
            title: a.name,
            subtitle: c.position(a.positionId)?.title ?? 'Sans poste',
            badge: trash ? null : status(a.status),
            badgeOn: a.active,
            depth: 0,
            color: null,
          ),
      ],
      (AdminSection.providers, _) => <_Row>[
        for (final p in c.providers)
          (
            id: p.id,
            title: p.name,
            subtitle: switch (p.models.length) {
              0 => 'Aucun modèle',
              1 => '1 modèle',
              final n => '$n modèles',
            },
            badge: null,
            badgeOn: false,
            depth: 0,
            color: null,
          ),
      ],
      (AdminSection.company, _) => const <_Row>[],
    };
  }

  int get _trashCount => switch (controller.section) {
    AdminSection.units => controller.trashedUnits.length,
    AdminSection.positions => controller.trashedPositions.length,
    AdminSection.agents => controller.trashedAgents.length,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rows = _rows();
    final addLabel = switch (c.section) {
      AdminSection.units => 'Nouvelle unité',
      AdminSection.positions => 'Nouveau poste',
      AdminSection.agents => 'Nouvel agent',
      _ => 'Ajouter un fournisseur',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!c.showTrash)
                AdminButton(
                  label: addLabel,
                  icon: Icons.add,
                  primary: true,
                  onTap: c.busy ? null : c.startCreating,
                ),
              if (c.section.hasTrash)
                AdminButton(
                  label: c.showTrash
                      ? 'Retour à la liste'
                      : 'Corbeille ($_trashCount)',
                  icon: c.showTrash ? Icons.arrow_back : Icons.delete_outline,
                  onTap: c.toggleTrash,
                ),
            ],
          ),
        ),
        if (c.showTrash)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              'Les éléments restent ici jusqu\'à leur restauration.',
              style: TextStyle(color: LdColors.textFaint, fontSize: 12),
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      c.showTrash
                          ? 'La corbeille est vide.'
                          : 'Rien pour le moment.',
                      style: const TextStyle(
                        color: LdColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: <Widget>[
                    for (final row in rows)
                      _ListTile(
                        row: row,
                        selected: !c.showTrash && c.selectedId == row.id,
                        trailing: c.showTrash
                            ? AdminButton(
                                label: 'Restaurer',
                                onTap: c.busy ? null : () => c.restore(row.id),
                              )
                            : null,
                        onTap: c.showTrash ? null : () => c.select(row.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.row,
    required this.selected,
    this.trailing,
    this.onTap,
  });

  final _Row row;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LdPressable(
    onTap: onTap,
    builder: (context, hovered) => Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.fromLTRB(10 + row.depth * 16.0, 9, 10, 9),
      decoration: BoxDecoration(
        color: selected
            ? LdColors.selected
            : (hovered ? LdColors.hover : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          if (row.color case final color?) ...<Widget>[
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LdColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (row.subtitle case final sub? when sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LdColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (row.badge case final badge?) ...<Widget>[
            const SizedBox(width: 8),
            row.badgeOn ? StatusChip(label: badge) : _MutedChip(badge),
          ],
          if (trailing case final t?) ...<Widget>[const SizedBox(width: 8), t],
        ],
      ),
    ),
  );
}

class _MutedChip extends StatelessWidget {
  const _MutedChip(this.label);

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

// Éditeurs.

class _Editor extends StatelessWidget {
  const _Editor({required this.controller});

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.showTrash || (c.selectedId == null && !c.creating)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            c.showTrash
                ? 'Restaurez un élément pour le modifier.'
                : 'Choisissez un élément dans la liste, ou créez-en un.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: LdColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }
    final key = ValueKey<String>('${c.section.name}-${c.selectedId}');
    return switch (c.section) {
      AdminSection.units => _UnitEditor(
        key: key,
        controller: c,
        unit: c.unit(c.selectedId),
      ),
      AdminSection.positions => _PositionEditor(
        key: key,
        controller: c,
        position: c.position(c.selectedId),
      ),
      AdminSection.agents => _AgentEditor(
        key: key,
        controller: c,
        agent: c.agent(c.selectedId),
      ),
      AdminSection.providers => _ProviderEditor(
        key: key,
        controller: c,
        provider: c.provider(c.selectedId),
      ),
      AdminSection.company => const SizedBox.shrink(),
    };
  }
}

/// Gabarit commun : titre, champs, messages, boutons.
class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.controller,
    required this.title,
    required this.children,
    required this.onSave,
    this.onTrash,
    this.trashLabel = 'Mettre à la corbeille',
    this.extra = const <Widget>[],
  });

  final AdminController controller;
  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final VoidCallback? onTrash;
  final String trashLabel;

  /// Blocs placés sous les boutons (modèles d'un fournisseur).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: LdColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
        if (c.error case final message?)
          _Message(message, color: const Color(0xFFE5776B)),
        if (c.notice case final message? when c.error == null)
          _Message(message, color: LdColors.green),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            AdminButton(
              label: 'Enregistrer',
              primary: true,
              onTap: c.busy ? null : onSave,
            ),
            AdminButton(label: 'Fermer', onTap: c.closeEditor),
            if (onTrash case final trash?)
              AdminButton(
                label: trashLabel,
                icon: Icons.delete_outline,
                danger: true,
                onTap: c.busy ? null : trash,
              ),
          ],
        ),
        ...extra,
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: TextStyle(color: color, fontSize: 12.5)),
  );
}

/// Demande confirmation avant une action dangereuse.
Future<bool> confirmDanger(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: LdColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LdRadius.panel),
        side: const BorderSide(color: LdColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: LdColors.text,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: LdColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  AdminButton(
                    label: action,
                    danger: true,
                    primary: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                  AdminButton(
                    label: 'Annuler',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}

class _CompanyEditor extends StatefulWidget {
  const _CompanyEditor({required this.controller, super.key});

  final AdminController controller;

  @override
  State<_CompanyEditor> createState() => _CompanyEditorState();
}

class _CompanyEditorState extends State<_CompanyEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.companyName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _EditorFrame(
          controller: c,
          title: 'Entreprise',
          onSave: () => c.saveCompany(_name.text),
          children: <Widget>[
            AdminField(controller: _name, label: 'Nom de l\'entreprise'),
            const _Hint(
              'Les départements, postes et agents se règlent dans les '
              'rubriques suivantes.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        color: LdColors.textFaint,
        fontSize: 12.5,
        height: 1.35,
      ),
    ),
  );
}

class _UnitEditor extends StatefulWidget {
  const _UnitEditor({required this.controller, this.unit, super.key});

  final AdminController controller;
  final OrgUnit? unit;

  @override
  State<_UnitEditor> createState() => _UnitEditorState();
}

class _UnitEditorState extends State<_UnitEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.unit?.name,
  );
  late final TextEditingController _kind = TextEditingController(
    text: widget.unit?.kind,
  );
  late final TextEditingController _color = TextEditingController(
    text: widget.unit?.color,
  );
  late int? _parent = widget.unit?.parentId;
  late final Set<String> _tags = <String>{...?widget.unit?.activityTags};

  @override
  void dispose() {
    _name.dispose();
    _kind.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final unit = widget.unit;
    return _EditorFrame(
      controller: c,
      title: unit == null ? 'Nouvelle unité' : unit.name,
      onSave: () => c.saveUnit(
        id: unit?.id,
        name: _name.text,
        parentId: _parent,
        kind: _kind.text,
        color: _color.text,
        activityTags: <String>[
          for (final t in c.activityTags)
            if (_tags.contains(t)) t,
        ],
      ),
      onTrash: unit == null || unit.systemRole != null
          ? null
          : () async {
              if (await confirmDanger(
                context,
                title: 'Mettre « ${unit.name} » à la corbeille ?',
                message:
                    'L\'unité disparaît de l\'organisation et du bureau. '
                    'Vous pourrez la restaurer depuis la corbeille.',
                action: 'Mettre à la corbeille',
              )) {
                await c.trash(unit.id);
              }
            },
      children: <Widget>[
        AdminField(controller: _name, label: 'Nom'),
        AdminField(
          controller: _kind,
          label: 'Niveau (facultatif)',
          hint: 'Département, Pôle…',
        ),
        AdminDropdown<int?>(
          label: 'Rattachée à',
          value: _parent,
          items: <(int?, String)>[
            (null, 'Premier niveau'),
            for (final (u, depth) in c.unitTree)
              if (unit == null || !c.isSelfOrDescendant(u.id, unit.id))
                (u.id, '${'  ' * depth}${u.name}'),
          ],
          onChanged: (v) => setState(() => _parent = v),
        ),
        AdminField(
          controller: _color,
          label: 'Couleur (facultatif)',
          hint: '#4C8BF5',
        ),
        if (unit?.systemRole != null)
          const _Hint(
            'Unité présente dans toute entreprise : elle se renomme mais '
            'ne se supprime pas.',
          ),
        const _Label('Activités'),
        const _Hint(
          'L\'aménagement du bureau en déduit les salles dont l\'unité a '
          'besoin.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final tag in c.activityTags)
                _Toggle(
                  label: activityTagLabels[tag] ?? tag,
                  on: _tags.contains(tag),
                  onTap: () => setState(
                    () => _tags.contains(tag)
                        ? _tags.remove(tag)
                        : _tags.add(tag),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PositionEditor extends StatefulWidget {
  const _PositionEditor({required this.controller, this.position, super.key});

  final AdminController controller;
  final OrgPosition? position;

  @override
  State<_PositionEditor> createState() => _PositionEditorState();
}

class _PositionEditorState extends State<_PositionEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.position?.title,
  );
  late final TextEditingController _mission = TextEditingController(
    text: widget.position?.mission,
  );
  late final TextEditingController _duties = TextEditingController(
    text: widget.position?.responsibilities.join('\n'),
  );
  late int? _unit =
      widget.position?.unitId ?? widget.controller.units.firstOrNull?.id;
  late int? _reportsTo = widget.position?.reportsToId;
  late bool _head = widget.position?.isHead ?? false;
  late bool _active = widget.position?.status == 'active';

  @override
  void dispose() {
    _title.dispose();
    _mission.dispose();
    _duties.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final position = widget.position;
    final unit = _unit;
    return _EditorFrame(
      controller: c,
      title: position == null ? 'Nouveau poste' : position.title,
      onSave: unit == null
          ? null
          : () => c.savePosition(
              id: position?.id,
              title: _title.text,
              unitId: unit,
              reportsToId: _reportsTo,
              mission: _mission.text,
              responsibilities: <String>[
                for (final line in _duties.text.split('\n'))
                  if (line.trim().isNotEmpty) line.trim(),
              ],
              isHead: _head,
              status: _active ? 'active' : 'draft',
            ),
      onTrash: position == null
          ? null
          : () async {
              if (await confirmDanger(
                context,
                title: 'Mettre « ${position.title} » à la corbeille ?',
                message:
                    'Le poste disparaît de l\'organisation. Vous pourrez le '
                    'restaurer depuis la corbeille.',
                action: 'Mettre à la corbeille',
              )) {
                await c.trash(position.id);
              }
            },
      children: <Widget>[
        AdminField(controller: _title, label: 'Intitulé'),
        if (c.units.isEmpty)
          const _Hint('Créez d\'abord une unité dans « Organisation ».')
        else
          AdminDropdown<int?>(
            label: 'Unité',
            value: _unit,
            items: <(int?, String)>[
              for (final (u, depth) in c.unitTree)
                (u.id, '${'  ' * depth}${u.name}'),
            ],
            onChanged: (v) => setState(() => _unit = v),
          ),
        AdminDropdown<int?>(
          label: 'Rend compte à',
          value: _reportsTo,
          items: <(int?, String)>[
            (null, 'Au CEO'),
            for (final p in c.positions)
              if (position == null || !c.reportsToSelf(p.id, position.id))
                (p.id, p.title),
          ],
          onChanged: (v) => setState(() => _reportsTo = v),
        ),
        AdminField(controller: _mission, label: 'Mission', lines: 3),
        AdminField(
          controller: _duties,
          label: 'Responsabilités',
          hint: 'Une par ligne',
          lines: 4,
        ),
        _Switch(
          label: 'Responsable de l\'unité',
          value: _head,
          onChanged: (v) => setState(() => _head = v),
        ),
        _Switch(
          label: 'En service',
          detail: 'Un poste en brouillon peut encore être préparé.',
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

class _AgentEditor extends StatefulWidget {
  const _AgentEditor({required this.controller, this.agent, super.key});

  final AdminController controller;
  final OrgAgent? agent;

  @override
  State<_AgentEditor> createState() => _AgentEditorState();
}

class _AgentEditorState extends State<_AgentEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.agent?.name,
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.agent?.bio,
  );
  late int? _position = widget.agent?.positionId;
  late final List<AgentModelLink> _models = <AgentModelLink>[
    ...?widget.agent?.models,
  ];
  late bool _active = widget.agent?.active ?? false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _toggleModel(int id) => setState(() {
    final i = _models.indexWhere((m) => m.aiModelId == id);
    if (i >= 0) {
      _models.removeAt(i);
      if (_models.isNotEmpty && !_models.any((m) => m.isDefault)) {
        _models[0] = AgentModelLink(
          aiModelId: _models[0].aiModelId,
          purpose: _models[0].purpose,
          isDefault: true,
        );
      }
    } else {
      _models.add(AgentModelLink(aiModelId: id, isDefault: _models.isEmpty));
    }
  });

  void _makeDefault(int id) => setState(() {
    for (var i = 0; i < _models.length; i++) {
      _models[i] = AgentModelLink(
        aiModelId: _models[i].aiModelId,
        purpose: _models[i].purpose,
        isDefault: _models[i].aiModelId == id,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final agent = widget.agent;
    final all = c.allModels;
    return _EditorFrame(
      controller: c,
      title: agent == null ? 'Nouvel agent' : agent.name,
      onSave: () => c.saveAgent(
        id: agent?.id,
        name: _name.text,
        bio: _bio.text,
        positionId: _position,
        models: List<AgentModelLink>.of(_models),
        active: _active && _models.isNotEmpty,
      ),
      onTrash: agent == null
          ? null
          : () async {
              if (await confirmDanger(
                context,
                title: 'Mettre « ${agent.name} » à la corbeille ?',
                message:
                    'L\'agent quitte l\'équipe. Son identité et son parcours '
                    'sont gardés : vous pourrez le restaurer depuis la '
                    'corbeille.',
                action: 'Mettre à la corbeille',
              )) {
                await c.trash(agent.id);
              }
            },
      children: <Widget>[
        AdminField(controller: _name, label: 'Nom'),
        AdminField(controller: _bio, label: 'Présentation', lines: 3),
        AdminDropdown<int?>(
          label: 'Poste',
          value: _position,
          items: <(int?, String)>[
            (null, 'Sans poste'),
            for (final p in c.positions) (p.id, p.title),
          ],
          onChanged: (v) => setState(() => _position = v),
        ),
        if (agent != null && agent.positionId != _position)
          const _Hint(
            'Changer de poste clôt l\'affectation en cours ; l\'agent garde '
            'son historique.',
          ),
        const _Label('Modèles IA'),
        if (all.isEmpty)
          const _Hint('Ajoutez d\'abord un fournisseur dans « Modèles IA ».')
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: <Widget>[
                for (final (provider, model) in all)
                  _ModelRow(
                    title: model.displayName,
                    subtitle: provider.name,
                    on: _models.any((m) => m.aiModelId == model.id),
                    isDefault: _models.any(
                      (m) => m.aiModelId == model.id && m.isDefault,
                    ),
                    onToggle: () => _toggleModel(model.id),
                    onDefault: () => _makeDefault(model.id),
                  ),
              ],
            ),
          ),
        _Switch(
          label: 'En service',
          detail: _models.isEmpty
              ? 'Choisissez au moins un modèle pour le mettre en service.'
              : 'L\'agent peut recevoir des tâches et travailler.',
          value: _active && _models.isNotEmpty,
          onChanged: _models.isEmpty
              ? null
              : (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.title,
    required this.subtitle,
    required this.on,
    required this.isDefault,
    required this.onToggle,
    required this.onDefault,
  });

  final String title;
  final String subtitle;
  final bool on;
  final bool isDefault;
  final VoidCallback onToggle;
  final VoidCallback onDefault;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: on ? LdColors.borderStrong : LdColors.border),
    ),
    child: Row(
      children: <Widget>[
        Checkbox(
          value: on,
          onChanged: (_) => onToggle(),
          semanticLabel: 'Utiliser $title',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(color: LdColors.text, fontSize: 13),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: LdColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        if (on)
          isDefault
              ? const StatusChip(label: 'Par défaut')
              : AdminButton(label: 'Par défaut', small: true, onTap: onDefault),
      ],
    ),
  );
}

class _ProviderEditor extends StatefulWidget {
  const _ProviderEditor({required this.controller, this.provider, super.key});

  final AdminController controller;
  final AiProviderEntry? provider;

  @override
  State<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<_ProviderEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.provider?.name,
  );
  late final TextEditingController _baseUrl = TextEditingController(
    text: widget.provider?.baseUrl,
  );
  late final TextEditingController _identifier = TextEditingController();
  late final TextEditingController _label = TextEditingController();
  late String _driver =
      widget.provider?.driver ??
      widget.controller.drivers.firstOrNull?.$1 ??
      'anthropic';

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _identifier.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final provider = widget.provider;
    final drivers = <(String, String)>[
      ...c.drivers,
      if (!c.drivers.any((d) => d.$1 == _driver)) (_driver, _driver),
    ];
    return _EditorFrame(
      controller: c,
      title: provider == null ? 'Nouveau fournisseur' : provider.name,
      trashLabel: 'Retirer le fournisseur',
      onSave: () => c.saveProvider(
        id: provider?.id,
        name: _name.text,
        driver: _driver,
        baseUrl: _baseUrl.text,
      ),
      onTrash: provider == null
          ? null
          : () async {
              if (await confirmDanger(
                context,
                title: 'Retirer « ${provider.name} » ?',
                message:
                    'Ses modèles ne seront plus proposés aux agents. Un agent '
                    'en service qui n\'a que ces modèles empêche le retrait.',
                action: 'Retirer',
              )) {
                await c.trash(provider.id);
              }
            },
      extra: provider == null
          ? const <Widget>[]
          : <Widget>[
              const SizedBox(height: 26),
              if (c.keys != null)
                _ProviderImport(
                  key: ValueKey<String>('import-${provider.id}'),
                  controller: c,
                  provider: provider,
                ),
              const _Label('Modèles'),
              for (final m in provider.models)
                _ProviderModelRow(
                  key: ValueKey<int>(m.id),
                  controller: c,
                  model: m,
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AdminField(
                      controller: _identifier,
                      label: 'Identifiant',
                      hint: 'claude-opus-5-5',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminField(
                      controller: _label,
                      label: 'Nom affiché (facultatif)',
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminButton(
                  label: 'Ajouter le modèle',
                  icon: Icons.add,
                  onTap: c.busy
                      ? null
                      : () async {
                          if (_identifier.text.trim().isEmpty) {
                            return;
                          }
                          if (await c.addModel(
                            provider.id,
                            _identifier.text,
                            _label.text,
                          )) {
                            _identifier.clear();
                            _label.clear();
                          }
                        },
                ),
              ),
            ],
      children: <Widget>[
        AdminField(controller: _name, label: 'Nom'),
        AdminDropdown<String>(
          label: 'Type',
          value: _driver,
          items: drivers,
          onChanged: (v) => setState(() => _driver = v ?? _driver),
        ),
        AdminField(
          controller: _baseUrl,
          label: 'Adresse de l\'API (facultatif)',
          hint: 'https://… — seulement si elle diffère de celle du fournisseur',
        ),
        _Hint(
          provider == null
              ? 'Pas de clé ici : une fois le fournisseur enregistré, sa clé '
                    'se saisit plus bas et reste sur cet ordinateur.'
              : 'La clé se saisit plus bas et reste sur cet ordinateur.',
        ),
      ],
    );
  }
}

/// Clé du fournisseur (gardée sur cet ordinateur) et import des modèles
/// du compte (D-027).
class _ProviderImport extends StatefulWidget {
  const _ProviderImport({
    required this.controller,
    required this.provider,
    super.key,
  });

  final AdminController controller;
  final AiProviderEntry provider;

  @override
  State<_ProviderImport> createState() => _ProviderImportState();
}

class _ProviderImportState extends State<_ProviderImport> {
  final TextEditingController _key = TextEditingController();
  final Set<String> _chosen = <String>{};

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = widget.provider;
    final mask = c.keyMasks[p.driver];
    final supported = ModelCatalog.supports(p.driver, p.baseUrl);
    final remote = c.remoteFor == p.id ? c.remoteModels : null;
    final existing = <String>{for (final m in p.models) m.identifier};
    final addable = <RemoteModel>[
      for (final m in remote ?? const <RemoteModel>[])
        if (!existing.contains(m.identifier)) m,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(LdRadius.card),
        border: Border.all(color: LdColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Label('Clé et import des modèles'),
          _Hint(
            mask == null
                ? 'Aucune clé sur cet ordinateur. Elle sert à lire les '
                      'modèles de votre compte et n\'est jamais envoyée au '
                      'serveur LeadDesk.'
                : 'Clé enregistrée sur cet ordinateur ($mask). Elle n\'est '
                      'jamais envoyée au serveur LeadDesk.',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _key,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(color: LdColors.text, fontSize: 13.5),
                  decoration: _decoration(
                    mask == null ? 'Clé d\'API' : 'Remplacer la clé',
                    null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AdminButton(
                label: 'Enregistrer la clé',
                onTap: () async {
                  if (_key.text.trim().isEmpty) {
                    return;
                  }
                  await c.setProviderKey(p.driver, _key.text);
                  _key.clear();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AdminButton(
                label: c.fetchingRemote
                    ? 'Lecture du compte…'
                    : 'Importer les modèles',
                icon: Icons.download_outlined,
                primary: true,
                onTap: !supported || mask == null || c.fetchingRemote
                    ? null
                    : () {
                        _chosen.clear();
                        unawaited(c.fetchRemoteModels(p));
                      },
              ),
              if (mask != null)
                AdminButton(
                  label: 'Effacer la clé',
                  danger: true,
                  onTap: () async {
                    if (await confirmDanger(
                      context,
                      title: 'Effacer la clé de ${p.name} ?',
                      message:
                          'Elle est retirée de cet ordinateur. Les agents qui '
                          'utilisent ce fournisseur ne pourront plus travailler '
                          'ici tant qu\'une clé n\'est pas saisie.',
                      action: 'Effacer',
                    )) {
                      await c.setProviderKey(p.driver, '');
                    }
                  },
                ),
            ],
          ),
          if (!supported)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _Hint(
                'Indiquez l\'adresse de l\'API de ce fournisseur pour importer '
                'ses modèles.',
              ),
            ),
          if (remote != null && remote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${remote.length} modèles sur votre compte · '
                    '${addable.length} à ajouter',
                    style: const TextStyle(
                      color: LdColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                AdminButton(
                  label: _chosen.length == addable.length && addable.isNotEmpty
                      ? 'Tout décocher'
                      : 'Tout cocher',
                  small: true,
                  onTap: addable.isEmpty
                      ? null
                      : () => setState(() {
                          if (_chosen.length == addable.length) {
                            _chosen.clear();
                          } else {
                            _chosen.addAll(addable.map((m) => m.identifier));
                          }
                        }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final m in remote)
                    _RemoteRow(
                      model: m,
                      added: existing.contains(m.identifier),
                      chosen: _chosen.contains(m.identifier),
                      onToggle: () => setState(
                        () => _chosen.contains(m.identifier)
                            ? _chosen.remove(m.identifier)
                            : _chosen.add(m.identifier),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                AdminButton(
                  label: 'Ajouter la sélection (${_chosen.length})',
                  primary: true,
                  onTap: _chosen.isEmpty || c.busy
                      ? null
                      : () => c.importModels(p.id, <RemoteModel>[
                          for (final m in remote)
                            if (_chosen.contains(m.identifier)) m,
                        ]),
                ),
                AdminButton(label: 'Annuler', onTap: c.closeRemoteModels),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoteRow extends StatelessWidget {
  const _RemoteRow({
    required this.model,
    required this.added,
    required this.chosen,
    required this.onToggle,
  });

  final RemoteModel model;
  final bool added;
  final bool chosen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = model.label;
    return Row(
      children: <Widget>[
        Checkbox(
          value: added || chosen,
          onChanged: added ? null : (_) => onToggle(),
          semanticLabel: 'Importer ${model.identifier}',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label == null || label.isEmpty ? model.identifier : label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: added ? LdColors.textMuted : LdColors.text,
                  fontSize: 13,
                ),
              ),
              if (label != null && label.isNotEmpty)
                Text(
                  model.identifier,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LdColors.textFaint,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
        ),
        if (added) const _MutedChip('Déjà ajouté'),
      ],
    );
  }
}

class _ProviderModelRow extends StatelessWidget {
  const _ProviderModelRow({
    required this.controller,
    required this.model,
    super.key,
  });

  final AdminController controller;
  final AiModelEntry model;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LdColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  model.displayName,
                  style: const TextStyle(color: LdColors.text, fontSize: 13),
                ),
                if (model.label != null && model.label!.isNotEmpty)
                  Text(
                    model.identifier,
                    style: const TextStyle(
                      color: LdColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          LdIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Retirer ${model.displayName}',
            size: 30,
            iconSize: 16,
            onTap: c.busy
                ? null
                : () async {
                    if (await confirmDanger(
                      context,
                      title: 'Retirer « ${model.displayName} » ?',
                      message:
                          'Les agents qui l\'utilisent le perdent. Un agent en '
                          'service qui n\'a que ce modèle empêche le retrait.',
                      action: 'Retirer',
                    )) {
                      await c.removeModel(model.id);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// Champs.

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
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

InputDecoration _decoration(String label, String? hint) => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: const Color(0xFF262625),
  labelText: label,
  hintText: hint,
  hintStyle: const TextStyle(color: LdColors.textFaint, fontSize: 13),
  labelStyle: const TextStyle(color: LdColors.textMuted, fontSize: 13),
  contentPadding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: LdColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: LdColors.borderStrong),
  ),
);

class AdminField extends StatelessWidget {
  const AdminField({
    required this.controller,
    required this.label,
    this.hint,
    this.lines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      style: const TextStyle(color: LdColors.text, fontSize: 13.5),
      decoration: _decoration(label, hint),
    ),
  );
}

class AdminDropdown<T> extends StatelessWidget {
  const AdminDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final known = items.any((i) => i.$1 == value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: known ? value : null,
        isExpanded: true,
        dropdownColor: const Color(0xFF262625),
        // Le style du menu remplace celui du thème : on repart de sa police.
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: LdColors.text, fontSize: 13.5),
        decoration: _decoration(label, null),
        items: <DropdownMenuItem<T>>[
          for (final (v, text) in items)
            DropdownMenuItem<T>(
              value: v,
              child: Text(text, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(color: LdColors.text, fontSize: 13.5),
              ),
              if (detail case final d?)
                Text(
                  d,
                  style: const TextStyle(
                    color: LdColors.textFaint,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LdPressable(
    onTap: onTap,
    builder: (context, hovered) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: on
            ? LdColors.greenSoft
            : (hovered ? LdColors.hover : const Color(0xFF262625)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: on ? Colors.transparent : LdColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: on ? LdColors.green : LdColors.textMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Bouton du back-office : principal (blanc), secondaire, ou danger.
class AdminButton extends StatelessWidget {
  const AdminButton({
    required this.label,
    this.onTap,
    this.icon,
    this.primary = false,
    this.danger = false,
    this.small = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final bool danger;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    const red = Color(0xFFE5776B);
    final Color background;
    final Color foreground;
    if (!enabled) {
      background = const Color(0xFF262625);
      foreground = LdColors.textFaint;
    } else if (primary && danger) {
      background = const Color(0xFFB4483D);
      foreground = const Color(0xFFFFFFFF);
    } else if (primary) {
      background = const Color(0xFFFFFFFF);
      foreground = const Color(0xFF161514);
    } else {
      background = const Color(0xFF262625);
      foreground = danger ? red : LdColors.text;
    }
    return LdPressable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 14,
          vertical: small ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: hovered
              ? Color.lerp(background, const Color(0xFF808080), 0.12)
              : background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary && enabled ? Colors.transparent : LdColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final i?) ...<Widget>[
              Icon(i, size: 15, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: small ? 12 : 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
