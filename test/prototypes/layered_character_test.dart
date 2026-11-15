import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../prototypes/layered_character/layers.dart';
import '../../prototypes/layered_character/prototype_layers.dart';

/// Octets RGBA du rectangle `(x, y, w, h)` de la première image de la planche.
Future<List<int>> _region(Image sheet, int x, int y, int w, int h) async {
  final ByteData? data = await sheet.toByteData();
  final bytes = <int>[];
  for (var row = y; row < y + h; row++) {
    for (var col = x; col < x + w; col++) {
      final offset = (row * sheet.width + col) * 4;
      bytes.addAll(<int>[
        data!.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
        data.getUint8(offset + 3),
      ]);
    }
  }
  return bytes;
}

void main() {
  final library = buildPrototypeLibrary();

  test('chaque calque propose au moins deux variantes', () {
    for (final kind in LayerKind.values) {
      expect(library.optionsFor(kind).length, greaterThanOrEqualTo(2));
    }
  });

  test('l apparence par défaut choisit une variante par calque', () {
    final appearance = library.defaultAppearance();
    for (final kind in LayerKind.values) {
      expect(library.find(kind, appearance.optionId(kind)), isNotNull);
    }
  });

  test('withLayer ne modifie que le calque demandé', () {
    final base = library.defaultAppearance();
    final changed = base.withLayer(LayerKind.hair, 'hair-long-auburn');

    expect(changed.optionId(LayerKind.hair), 'hair-long-auburn');
    for (final kind in LayerKind.values.where((k) => k != LayerKind.hair)) {
      expect(changed.optionId(kind), base.optionId(kind));
    }
    expect(base.optionId(LayerKind.hair), isNot('hair-long-auburn'));
    expect(changed, isNot(base));
    expect(
      base.withLayer(LayerKind.hair, base.optionId(LayerKind.hair)!),
      base,
    );
  });

  test('next boucle sur les variantes d un calque', () {
    final options = library.optionsFor(LayerKind.face);
    expect(library.next(LayerKind.face, options.first.id).id, options[1].id);
    expect(library.next(LayerKind.face, options.last.id).id, options.first.id);
  });

  testWidgets('la planche composée garde la grille des calques', (
    tester,
  ) async {
    final composer = CharacterComposer(library);
    final sheet = await tester.runAsync(
      () => composer.compose(library.defaultAppearance()),
    );
    expect(sheet!.width, layerFrameWidth * layerFrameCount);
    expect(sheet.height, layerFrameHeight);
    expect(composer.cachedLayerCount, LayerKind.values.length);
  });

  testWidgets('changer les cheveux ne touche pas le reste du personnage', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final composer = CharacterComposer(library);
      final base = library.defaultAppearance();
      final before = await composer.compose(base);
      final after = await composer.compose(
        base.withLayer(LayerKind.hair, 'hair-long-auburn'),
      );

      // Haut de la tête : les cheveux ont changé.
      expect(
        await _region(after, 4, 2, 8, 3),
        isNot(await _region(before, 4, 2, 8, 3)),
      );
      // Jambes et chaussures : rien n'a bougé.
      expect(
        await _region(after, 4, 16, 9, 8),
        await _region(before, 4, 16, 9, 8),
      );
      // Seule la planche du nouveau calque a été dessinée en plus.
      expect(composer.cachedLayerCount, LayerKind.values.length + 1);
    });
  });
}
