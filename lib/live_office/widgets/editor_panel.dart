import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../office/office_plan.dart';
import '../../office/plan_editor.dart';
import '../../office/room_catalog.dart';
import '../live_office_controller.dart';
import 'common.dart';

/// Panneau du mode « Aménager » (D-016) : salle choisie, ajout depuis le
/// catalogue, règles en direct, Annuler / Enregistrer.
class EditorPanel extends StatefulWidget {
  const EditorPanel({required this.controller, super.key});

  static const double width = 348;

  final LiveOfficeController controller;

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  RoomCategory _category = RoomCategory.production;

  LiveOfficeController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final editor = _controller.editor!;
    final problems = editor.problems;
    final selected = editor.selected;
    return Container(
      width: EditorPanel.width,
      decoration: BoxDecoration(
        color: LdColors.surface,
        borderRadius: BorderRadius.circular(LdRadius.panel),
        border: Border.all(color: LdColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(editor: editor, onClose: _controller.cancelEditing),
          const Divider(height: 1, color: LdColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              children: <Widget>[
                const _Title('Salle choisie'),
                if (selected == null)
                  const Text(
                    'Cliquez sur une salle pour la modifier ; faites-la '
                    'glisser pour la déplacer.',
                    style: TextStyle(
                      color: LdColors.textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  )
                else
                  _SelectedRoom(editor: editor, room: selected),
                const SizedBox(height: 20),
                const _Title('Ajouter une salle'),
                _CategoryChips(
                  value: _category,
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 8),
                for (final type in RoomCatalog.all)
                  if (type.category == _category)
                    _CatalogRow(
                      type: type,
                      onAdd: () => editor.add(
                        type.id,
                        departmentId:
                            selected?.departmentId ??
                            (editor.departments.isEmpty
                                ? null
                                : editor.departments.first.id),
                      ),
                    ),
                const SizedBox(height: 20),
                const _Title('Règles'),
                if (problems.isEmpty)
                  const _Rule(
                    ok: true,
                    text: 'Le plan respecte toutes les règles.',
                  )
                else
                  for (final problem in problems)
                    _Rule(ok: false, text: problem),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: LdColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_controller.saveError case final error?) ...<Widget>[
                  _Rule(ok: false, text: error),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Button(
                        label: 'Annuler',
                        onTap: _controller.cancelEditing,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Button(
                        label: _controller.saving ? 'Envoi…' : 'Enregistrer',
                        primary: true,
                        enabled: editor.canSave && !_controller.saving,
                        onTap: _controller.saveEditing,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.editor, required this.onClose});

  final PlanEditor editor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x24F2B34C),
              borderRadius: BorderRadius.circular(LdRadius.control),
            ),
            child: const Icon(
              Icons.design_services_outlined,
              size: 19,
              color: LdColors.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Aménager le bureau',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LdColors.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  editor.dirty
                      ? 'Modifications non enregistrées'
                      : 'Aucune modification',
                  style: const TextStyle(
                    color: LdColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          LdIconButton(
            icon: Icons.undo,
            tooltip: 'Annuler la dernière modification',
            size: 32,
            iconSize: 17,
            onTap: editor.canUndo ? editor.undo : null,
          ),
          LdIconButton(
            icon: Icons.redo,
            tooltip: 'Rétablir',
            size: 32,
            iconSize: 17,
            onTap: editor.canRedo ? editor.redo : null,
          ),
          LdIconButton(
            icon: Icons.close,
            tooltip: 'Quitter sans enregistrer',
            size: 32,
            iconSize: 17,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

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

class _SelectedRoom extends StatelessWidget {
  const _SelectedRoom({required this.editor, required this.room});

  final PlanEditor editor;
  final PlacedRoom room;

  @override
  Widget build(BuildContext context) {
    final type = RoomCatalog.byId(room.typeId);
    final shared = type?.scope == RoomScope.shared;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LdColors.surfaceHigh,
        borderRadius: BorderRadius.circular(LdRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            room.label,
            style: const TextStyle(
              color: LdColors.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${room.cols} × ${room.rows} cases'
            '${room.seats > 0 ? ' · ${room.seats} ${room.seats > 1 ? 'postes' : 'poste'}' : ''}',
            style: const TextStyle(color: LdColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (shared)
            const Text(
              'Lieu commun : il n\'appartient à aucun département.',
              style: TextStyle(color: LdColors.textMuted, fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final department in editor.departments)
                  _Chip(
                    label: department.name,
                    color: Color(department.color),
                    active: department.id == room.departmentId,
                    onTap: () => editor.assign(room.id, department.id),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: <Widget>[
                    _Stepper(
                      label: 'Largeur',
                      onMinus: () => editor.resize(room.id, dCols: -1),
                      onPlus: () => editor.resize(room.id, dCols: 1),
                    ),
                    _Stepper(
                      label: 'Profondeur',
                      onMinus: () => editor.resize(room.id, dRows: -1),
                      onPlus: () => editor.resize(room.id, dRows: 1),
                    ),
                  ],
                ),
              ),
              LdIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Retirer la salle',
                size: 32,
                iconSize: 18,
                onTap: () => editor.remove(room.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: LdColors.textMuted, fontSize: 12.5),
        ),
        const SizedBox(width: 4),
        LdIconButton(
          icon: Icons.remove,
          tooltip: '$label −1',
          size: 26,
          iconSize: 15,
          onTap: onMinus,
        ),
        LdIconButton(
          icon: Icons.add,
          tooltip: '$label +1',
          size: 26,
          iconSize: 15,
          onTap: onPlus,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return LdPressable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0x24F2B34C)
              : hovered
              ? LdColors.hover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? LdColors.amber : LdColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (color case final dot?) ...<Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? LdColors.text : LdColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.value, required this.onChanged});

  final RoomCategory value;
  final ValueChanged<RoomCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final category in RoomCategory.values)
          _Chip(
            label: category.label,
            active: category == value,
            onTap: () => onChanged(category),
          ),
      ],
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.type, required this.onAdd});

  final RoomType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LdPressable(
      onTap: onAdd,
      tooltip: 'Ajouter : ${type.name}',
      builder: (context, hovered) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: hovered ? LdColors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(LdRadius.control),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    type.name,
                    style: const TextStyle(
                      color: LdColors.text,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    type.scope == RoomScope.shared
                        ? 'Lieu commun · ${type.minCols} × ${type.minRows}'
                        : 'Département · ${type.minCols} × ${type.minRows}',
                    style: const TextStyle(
                      color: LdColors.textFaint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add,
              size: 17,
              color: hovered ? LdColors.amber : LdColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.text});

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
            color: ok ? LdColors.green : const Color(0xFFF2617A),
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
