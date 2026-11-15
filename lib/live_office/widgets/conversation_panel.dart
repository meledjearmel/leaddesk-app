import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../live_office_controller.dart';
import '../models.dart';
import 'common.dart';

/// Panneau de droite : conversation ouverte entre des agents et le CEO.
class ConversationPanel extends StatefulWidget {
  const ConversationPanel({required this.controller, super.key});

  static const double width = 348;

  final LiveOfficeController controller;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  int _tab = 0;

  LiveOfficeController get _controller => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final before = _controller.entries.length;
    _controller.sendMessage(_input.text);
    if (_controller.entries.length == before) {
      return;
    }
    _input.clear();
    _focus.requestFocus();
    // Le nouveau message est tout en bas : on y défile une fois posé.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _controller.agentById('atlas');
    final quill = _controller.agentById('quill');
    return Container(
      width: ConversationPanel.width,
      decoration: BoxDecoration(
        color: LdColors.surface,
        borderRadius: BorderRadius.circular(LdRadius.panel),
        border: Border.all(color: LdColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(
            first: atlas,
            second: quill,
            onClose: _controller.toggleConversation,
          ),
          _Tabs(index: _tab, onChanged: (i) => setState(() => _tab = i)),
          Expanded(
            child: _tab == 0
                ? ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: <Widget>[
                      for (final entry in _controller.entries)
                        switch (entry) {
                          AgentMessage() => _AgentBubble(
                            agent: _controller.agentById(entry.agentId),
                            time: entry.time,
                            child: Text(entry.text, style: _bubbleText),
                          ),
                          UserMessage() => _UserBubble(entry: entry),
                          SystemNote() => _Note(entry: entry),
                        },
                      _AgentBubble(
                        agent: quill,
                        time: 'à l\'instant',
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: TypingDots(),
                        ),
                      ),
                    ],
                  )
                : const _SharedContext(),
          ),
          _Composer(input: _input, focus: _focus, onSend: _send),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LdPressable(
                onTap: _controller.toggleConversation,
                builder: (context, hovered) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.subdirectory_arrow_left,
                        size: 15,
                        color: hovered ? LdColors.text : LdColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Quitter',
                        style: TextStyle(
                          color: hovered ? LdColors.text : LdColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _bubbleText = TextStyle(
  color: LdColors.text,
  fontSize: 14,
  height: 1.4,
);

class _Header extends StatelessWidget {
  const _Header({
    required this.first,
    required this.second,
    required this.onClose,
  });

  final OfficeAgent first;
  final OfficeAgent second;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 58,
            height: 36,
            child: Stack(
              children: <Widget>[
                AgentAvatar(style: first.avatar),
                Positioned(
                  left: 22,
                  child: Container(
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: LdColors.surface, width: 2),
                    ),
                    child: AgentAvatar(style: second.avatar),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '${first.name}, ${second.name} et vous',
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
                    const StatusChip(label: 'Présent'),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Passation · Brief de lancement · 14:33',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: LdColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          LdIconButton(
            icon: Icons.close,
            tooltip: 'Fermer la conversation',
            size: 32,
            iconSize: 17,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Conversation', 'Contexte partagé'];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LdColors.border)),
      ),
      // Défile si les onglets ne tiennent pas (texte système agrandi).
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

class _AgentBubble extends StatelessWidget {
  const _AgentBubble({
    required this.agent,
    required this.time,
    required this.child,
  });

  final OfficeAgent agent;
  final String time;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 42, bottom: 5),
            child: Text(
              '${agent.name} · $time',
              style: const TextStyle(color: LdColors.textMuted, fontSize: 12),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              AgentAvatar(style: agent.avatar, size: 32),
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
                  child: child,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.entry});

  final UserMessage entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 42, bottom: 5),
            child: Text(
              'Vous · ${entry.time}',
              style: const TextStyle(color: LdColors.textMuted, fontSize: 12),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    entry.text,
                    style: _bubbleText.copyWith(color: const Color(0xFF161514)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF3A3937),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'CEO',
                  style: TextStyle(
                    color: Color(0xFFD9D5CE),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
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
  const _Note({required this.entry});

  final SystemNote entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(entry.icon, size: 14, color: LdColors.textFaint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              entry.text,
              style: const TextStyle(color: LdColors.textMuted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedContext extends StatelessWidget {
  const _SharedContext();

  @override
  Widget build(BuildContext context) {
    const files = <(IconData, String, String)>[
      (Icons.description_outlined, 'brief-lancement.md', 'Transmis par Atlas'),
      (Icons.code, 'diff-pull-request-214.patch', 'Transmis par Forge'),
      (Icons.table_chart_outlined, 'limites-api.csv', 'Transmis par Atlas'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Fichiers partagés dans cette conversation',
            style: TextStyle(color: LdColors.textMuted, fontSize: 12.5),
          ),
        ),
        for (final (icon, name, origin) in files)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF191919),
              borderRadius: BorderRadius.circular(LdRadius.control),
              border: Border.all(color: LdColors.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: LdColors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(
                          color: LdColors.text,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        origin,
                        style: const TextStyle(
                          color: LdColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.focus,
    required this.onSend,
  });

  final TextEditingController input;
  final FocusNode focus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: TextField(
        controller: input,
        focusNode: focus,
        onSubmitted: (_) => onSend(),
        textInputAction: TextInputAction.send,
        style: const TextStyle(color: LdColors.text, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF262625),
          hintText: 'Message à Atlas et Quill',
          hintStyle: const TextStyle(color: LdColors.textFaint, fontSize: 14),
          contentPadding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: LdIconButton(
              icon: Icons.arrow_upward,
              tooltip: 'Envoyer',
              size: 32,
              iconSize: 17,
              onTap: onSend,
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
    );
  }
}
