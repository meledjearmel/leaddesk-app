import 'dart:ui';

/// Calques d'un personnage, dans l'ordre d'empilement (du fond vers le dessus).
enum LayerKind {
  body('Silhouette'),
  outfit('Tenue'),
  face('Visage'),
  hair('Cheveux'),
  accessory('Accessoire');

  const LayerKind(this.label);

  final String label;
}

/// Taille d'une image de planche et nombre d'images (0 : immobile, 1-4 : marche).
const int layerFrameWidth = 16;
const int layerFrameHeight = 24;
const int layerFrameCount = 5;

typedef LayerPainter = void Function(Canvas canvas, int frame);

/// Une variante d'un calque (par exemple « cheveux courts bruns »).
class LayerOption {
  const LayerOption({
    required this.kind,
    required this.id,
    required this.label,
    required this.paint,
  });

  final LayerKind kind;
  final String id;
  final String label;

  /// Dessine une image de la planche, fond transparent. Dans le prototype les
  /// calques sont dessinés par le code ; en production ce seront des PNG
  /// exportés d'Aseprite, avec la même grille d'images.
  final LayerPainter paint;
}

/// Apparence d'un personnage : une variante choisie par calque.
class CharacterAppearance {
  const CharacterAppearance(this.layers);

  final Map<LayerKind, String> layers;

  String? optionId(LayerKind kind) => layers[kind];

  CharacterAppearance withLayer(LayerKind kind, String optionId) {
    return CharacterAppearance(<LayerKind, String>{...layers, kind: optionId});
  }

  @override
  bool operator ==(Object other) {
    if (other is! CharacterAppearance || other.layers.length != layers.length) {
      return false;
    }
    for (final entry in layers.entries) {
      if (other.layers[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    layers.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Catalogue des variantes disponibles par calque.
class LayerLibrary {
  LayerLibrary(Iterable<LayerOption> options) {
    for (final option in options) {
      _byKind.putIfAbsent(option.kind, () => <LayerOption>[]).add(option);
    }
  }

  final Map<LayerKind, List<LayerOption>> _byKind =
      <LayerKind, List<LayerOption>>{};

  List<LayerOption> optionsFor(LayerKind kind) =>
      _byKind[kind] ?? const <LayerOption>[];

  LayerOption? find(LayerKind kind, String? id) {
    for (final option in optionsFor(kind)) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  /// Variante suivante du calque (boucle sur la liste).
  LayerOption next(LayerKind kind, String? currentId) {
    final options = optionsFor(kind);
    final index = options.indexWhere((option) => option.id == currentId);
    return options[(index + 1) % options.length];
  }

  /// Première variante de chaque calque.
  CharacterAppearance defaultAppearance() {
    return CharacterAppearance(<LayerKind, String>{
      for (final kind in LayerKind.values)
        if (optionsFor(kind).isNotEmpty) kind: optionsFor(kind).first.id,
    });
  }
}

/// Compose la planche d'un personnage en empilant les planches de ses calques.
///
/// Chaque planche de calque est rendue une seule fois puis gardée en cache ;
/// changer un calque ne redessine donc que la composition finale.
class CharacterComposer {
  CharacterComposer(this.library);

  final LayerLibrary library;
  final Map<String, Image> _layerSheets = <String, Image>{};

  int get cachedLayerCount => _layerSheets.length;

  Future<Image> _layerSheet(LayerOption option) async {
    final key = '${option.kind.name}/${option.id}';
    final cached = _layerSheets[key];
    if (cached != null) {
      return cached;
    }
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (var frame = 0; frame < layerFrameCount; frame++) {
      canvas
        ..save()
        ..translate((frame * layerFrameWidth).toDouble(), 0);
      option.paint(canvas, frame);
      canvas.restore();
    }
    final image = await recorder.endRecording().toImage(
      layerFrameWidth * layerFrameCount,
      layerFrameHeight,
    );
    return _layerSheets[key] = image;
  }

  Future<Image> compose(CharacterAppearance appearance) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.none;
    for (final kind in LayerKind.values) {
      final option = library.find(kind, appearance.optionId(kind));
      if (option == null) {
        continue;
      }
      canvas.drawImage(await _layerSheet(option), Offset.zero, paint);
    }
    return recorder.endRecording().toImage(
      layerFrameWidth * layerFrameCount,
      layerFrameHeight,
    );
  }
}
