import 'dart:ui';

import 'layers.dart';

/// Calques dessinés par le code pour le prototype. Créations originales.
LayerLibrary buildPrototypeLibrary() {
  return LayerLibrary(<LayerOption>[
    _body('skin-light', 'Claire', const Color(0xFFF2C9A1)),
    _body('skin-tan', 'Hâlée', const Color(0xFFD9A066)),
    _body('skin-brown', 'Brune', const Color(0xFFA9714B)),
    _body('skin-deep', 'Foncée', const Color(0xFF6B4A32)),
    _outfit(
      'shirt-violet',
      'Chemise violette',
      const Color(0xFF7C6BD6),
      const Color(0xFF2F3A56),
    ),
    _outfit(
      'shirt-teal',
      'Pull turquoise',
      const Color(0xFF4FB8A8),
      const Color(0xFF4A4458),
    ),
    _outfit(
      'shirt-coral',
      'Sweat corail',
      const Color(0xFFF08A5D),
      const Color(0xFF3B5B6B),
    ),
    _outfit(
      'suit-navy',
      'Costume marine',
      const Color(0xFF2F3A56),
      const Color(0xFF1F2740),
      tie: const Color(0xFFE56B8C),
    ),
    _face('eyes-dark', 'Yeux sombres', const Color(0xFF2A2233)),
    _face('eyes-blue', 'Yeux bleus', const Color(0xFF3F6FD1)),
    _hairShort('hair-short-black', 'Courts noirs', const Color(0xFF2B1D17)),
    _hairShort('hair-short-blond', 'Courts blonds', const Color(0xFFE0C068)),
    _hairLong('hair-long-auburn', 'Longs auburn', const Color(0xFFB5651D)),
    _hairLong('hair-long-grey', 'Longs gris', const Color(0xFF8A8FA3)),
    _hairBun('hair-bun-brown', 'Chignon brun', const Color(0xFF5A3A22)),
    LayerOption(
      kind: LayerKind.accessory,
      id: 'none',
      label: 'Aucun',
      paint: (canvas, frame) {},
    ),
    _glasses('glasses', 'Lunettes'),
    _headset('headset', 'Casque audio'),
    _badge('badge', 'Badge'),
  ]);
}

/// Les images 2 et 4 du cycle de marche montent d'un pixel.
int _bob(int frame) => (frame == 2 || frame == 4) ? -1 : 0;

final Paint _paint = Paint()..isAntiAlias = false;

void _px(Canvas canvas, int x, int y, int w, int h, Color color) {
  _paint.color = color;
  canvas.drawRect(
    Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    _paint,
  );
}

LayerOption _body(String id, String label, Color skin) {
  return LayerOption(
    kind: LayerKind.body,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      // Tête, cou, mains et jambes (recouvertes ensuite par la tenue).
      _px(canvas, 5, 3 + bob, 6, 6, skin);
      _px(canvas, 7, 9 + bob, 2, 1, skin);
      _px(canvas, 3, 15 + bob, 1, 1, skin);
      _px(canvas, 12, 15 + bob, 1, 1, skin);
      _px(canvas, 5, 16 + bob, 2, 6, skin);
      _px(canvas, 9, 16 + bob, 2, 6, skin);
    },
  );
}

LayerOption _outfit(
  String id,
  String label,
  Color top,
  Color trousers, {
  Color? tie,
}) {
  return LayerOption(
    kind: LayerKind.outfit,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      const shoe = Color(0xFF1F1A24);
      final leftForward = frame == 1;
      final rightForward = frame == 3;
      _px(canvas, 5, 16 + bob, 2, leftForward ? 5 : 6, trousers);
      _px(canvas, 9, 16 + bob, 2, rightForward ? 5 : 6, trousers);
      _px(canvas, leftForward ? 4 : 5, leftForward ? 21 : 22, 3, 1, shoe);
      _px(canvas, rightForward ? 10 : 9, rightForward ? 21 : 22, 3, 1, shoe);
      _px(canvas, 4, 10 + bob, 8, 6, top);
      _px(canvas, 3, 10 + bob, 1, 5, top);
      _px(canvas, 12, 10 + bob, 1, 5, top);
      if (tie != null) {
        _px(canvas, 7, 10 + bob, 2, 1, const Color(0xFFFFFFFF));
        _px(canvas, 7, 11 + bob, 1, 3, tie);
      }
    },
  );
}

LayerOption _face(String id, String label, Color eyes) {
  return LayerOption(
    kind: LayerKind.face,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      _px(canvas, 6, 6 + bob, 1, 1, eyes);
      _px(canvas, 9, 6 + bob, 1, 1, eyes);
      _px(canvas, 7, 8 + bob, 2, 1, const Color(0x55A04040));
    },
  );
}

LayerOption _hairShort(String id, String label, Color hair) {
  return LayerOption(
    kind: LayerKind.hair,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      _px(canvas, 5, 2 + bob, 6, 2, hair);
      _px(canvas, 4, 3 + bob, 1, 2, hair);
      _px(canvas, 11, 3 + bob, 1, 2, hair);
    },
  );
}

LayerOption _hairLong(String id, String label, Color hair) {
  return LayerOption(
    kind: LayerKind.hair,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      _px(canvas, 5, 2 + bob, 6, 2, hair);
      _px(canvas, 4, 3 + bob, 1, 8, hair);
      _px(canvas, 11, 3 + bob, 1, 8, hair);
      _px(canvas, 5, 4 + bob, 1, 1, hair);
    },
  );
}

LayerOption _hairBun(String id, String label, Color hair) {
  return LayerOption(
    kind: LayerKind.hair,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      _px(canvas, 7, bob, 2, 2, hair);
      _px(canvas, 5, 2 + bob, 6, 2, hair);
      _px(canvas, 4, 3 + bob, 1, 3, hair);
      _px(canvas, 11, 3 + bob, 1, 3, hair);
    },
  );
}

LayerOption _glasses(String id, String label) {
  return LayerOption(
    kind: LayerKind.accessory,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      const frameColor = Color(0xFF1F1A24);
      _px(canvas, 5, 5 + bob, 3, 1, frameColor);
      _px(canvas, 8, 5 + bob, 3, 1, frameColor);
      _px(canvas, 5, 7 + bob, 3, 1, frameColor);
      _px(canvas, 8, 7 + bob, 3, 1, frameColor);
      _px(canvas, 5, 6 + bob, 1, 1, frameColor);
      _px(canvas, 7, 6 + bob, 2, 1, frameColor);
      _px(canvas, 10, 6 + bob, 1, 1, frameColor);
    },
  );
}

LayerOption _headset(String id, String label) {
  return LayerOption(
    kind: LayerKind.accessory,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      const band = Color(0xFF3A3F52);
      _px(canvas, 5, 1 + bob, 6, 1, band);
      _px(canvas, 4, 2 + bob, 1, 3, band);
      _px(canvas, 11, 2 + bob, 1, 3, band);
      _px(canvas, 3, 5 + bob, 2, 3, const Color(0xFFF2B84B));
      _px(canvas, 11, 5 + bob, 2, 3, const Color(0xFFF2B84B));
    },
  );
}

LayerOption _badge(String id, String label) {
  return LayerOption(
    kind: LayerKind.accessory,
    id: id,
    label: label,
    paint: (canvas, frame) {
      final bob = _bob(frame);
      _px(canvas, 9, 12 + bob, 2, 2, const Color(0xFFFFFFFF));
      _px(canvas, 9, 12 + bob, 2, 1, const Color(0xFFF2B84B));
    },
  );
}
