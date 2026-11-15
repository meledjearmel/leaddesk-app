import 'dart:ui';

/// Couleurs d'un personnage de prototype.
class AgentPalette {
  const AgentPalette({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.trousers,
  });

  final Color skin;
  final Color hair;
  final Color shirt;
  final Color trousers;
}

/// Taille d'une image de la planche (en pixels sources).
const int agentFrameWidth = 16;
const int agentFrameHeight = 24;

/// Image 0 : immobile. Images 1 à 4 : cycle de marche.
const int agentFrameCount = 5;

const List<Color> _skins = <Color>[
  Color(0xFFF2C9A1),
  Color(0xFFD9A066),
  Color(0xFFA9714B),
  Color(0xFF6B4A32),
];
const List<Color> _hairs = <Color>[
  Color(0xFF2B1D17),
  Color(0xFF5A3A22),
  Color(0xFFB5651D),
  Color(0xFFE0C068),
  Color(0xFF8A8FA3),
];
const List<Color> _shirts = <Color>[
  Color(0xFF7C6BD6),
  Color(0xFF4FB8A8),
  Color(0xFFF08A5D),
  Color(0xFF5B8DEF),
  Color(0xFFE56B8C),
  Color(0xFF6BBF59),
  Color(0xFFF2B84B),
];
const List<Color> _trousers = <Color>[
  Color(0xFF2F3A56),
  Color(0xFF4A4458),
  Color(0xFF3B5B6B),
];

/// Palette déterministe à partir d'un indice : deux agents voisins diffèrent.
AgentPalette paletteFor(int index) {
  return AgentPalette(
    skin: _skins[index % _skins.length],
    hair: _hairs[(index * 3 + 1) % _hairs.length],
    shirt: _shirts[(index * 5 + 2) % _shirts.length],
    trousers: _trousers[(index * 2) % _trousers.length],
  );
}

/// Dessine la planche d'un personnage : [agentFrameCount] images côte à côte.
///
/// Les graphismes sont générés par le code pour le prototype ; la production
/// utilisera des planches Aseprite en calques.
Future<Image> buildAgentSheet(AgentPalette palette) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  for (var frame = 0; frame < agentFrameCount; frame++) {
    canvas
      ..save()
      ..translate((frame * agentFrameWidth).toDouble(), 0);
    _drawAgentFrame(canvas, palette, frame);
    canvas.restore();
  }
  return recorder.endRecording().toImage(
    agentFrameWidth * agentFrameCount,
    agentFrameHeight,
  );
}

void _drawAgentFrame(Canvas canvas, AgentPalette palette, int frame) {
  final paint = Paint()..isAntiAlias = false;
  void px(int x, int y, int w, int h, Color color) {
    paint.color = color;
    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      paint,
    );
  }

  // Images 2 et 4 : le corps monte d'un pixel (rebond de la marche).
  final bob = (frame == 2 || frame == 4) ? -1 : 0;
  const outline = Color(0xFF2A2233);
  const shoe = Color(0xFF1F1A24);

  // Jambes.
  final leftForward = frame == 1;
  final rightForward = frame == 3;
  px(5, 16 + bob, 2, leftForward ? 5 : 6, palette.trousers);
  px(9, 16 + bob, 2, rightForward ? 5 : 6, palette.trousers);
  px(leftForward ? 4 : 5, leftForward ? 21 : 22, 3, 1, shoe);
  px(rightForward ? 10 : 9, rightForward ? 21 : 22, 3, 1, shoe);

  // Torse et bras.
  px(4, 9 + bob, 8, 7, palette.shirt);
  px(3, 10 + bob, 1, 5, palette.shirt);
  px(12, 10 + bob, 1, 5, palette.shirt);
  px(3, 15 + bob, 1, 1, palette.skin);
  px(12, 15 + bob, 1, 1, palette.skin);

  // Tête.
  px(5, 3 + bob, 6, 6, palette.skin);
  px(5, 2 + bob, 6, 2, palette.hair);
  px(4, 3 + bob, 1, 3, palette.hair);
  px(11, 3 + bob, 1, 3, palette.hair);
  px(6, 6 + bob, 1, 1, outline);
  px(9, 6 + bob, 1, 1, outline);
}
