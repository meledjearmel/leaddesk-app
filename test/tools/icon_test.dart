// Génère l'icône de l'application depuis LeadDeskMarkPainter (D-018).
// Inactif par défaut.
//
// Usage (PowerShell) :
//   $env:LD_ICON_DIR = 'C:\chemin\vers\un\dossier'
//   flutter test test/tools/icon_test.dart
// Produit app_icon.ico (16 à 256 px) et leaddesk_1024.png, à copier dans
// windows/runner/resources/ et assets/branding/.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/app/logo.dart';

Future<Uint8List> _render(int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const LeadDeskMarkPainter().paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Fichier ICO dont chaque image est un PNG (Windows Vista et suivants).
Uint8List buildIco(List<(int, Uint8List)> images) {
  final header = ByteData(6 + 16 * images.length)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, images.length, Endian.little);
  var offset = header.lengthInBytes;
  for (final (i, (size, png)) in images.indexed) {
    final entry = 6 + 16 * i;
    header
      ..setUint8(entry, size >= 256 ? 0 : size)
      ..setUint8(entry + 1, size >= 256 ? 0 : size)
      ..setUint8(entry + 2, 0)
      ..setUint8(entry + 3, 0)
      ..setUint16(entry + 4, 1, Endian.little)
      ..setUint16(entry + 6, 32, Endian.little)
      ..setUint32(entry + 8, png.length, Endian.little)
      ..setUint32(entry + 12, offset, Endian.little);
    offset += png.length;
  }
  return Uint8List.fromList(<int>[
    ...header.buffer.asUint8List(),
    for (final (_, png) in images) ...png,
  ]);
}

void main() {
  final dir = Platform.environment['LD_ICON_DIR'];

  test('l\'en-tête ICO décrit chaque image', () {
    final ico = buildIco(<(int, Uint8List)>[
      (16, Uint8List(10)),
      (256, Uint8List(20)),
    ]);
    final data = ByteData.sublistView(ico);
    expect(data.getUint16(4, Endian.little), 2);
    expect(data.getUint8(6), 16);
    expect(data.getUint8(22), 0);
    expect(data.getUint32(6 + 12, Endian.little), 38);
    expect(ico.length, 38 + 30);
  });

  testWidgets(
    'génère l\'icône de l\'application',
    skip: dir == null || dir.isEmpty,
    (tester) async {
      await tester.runAsync(() async {
        final images = <(int, Uint8List)>[
          for (final size in const <int>[16, 24, 32, 48, 64, 128, 256])
            (size, await _render(size)),
        ];
        File('$dir/app_icon.ico')
          ..createSync(recursive: true)
          ..writeAsBytesSync(buildIco(images));
        File('$dir/leaddesk_1024.png').writeAsBytesSync(await _render(1024));
        for (final (size, png) in images) {
          File('$dir/icon_$size.png').writeAsBytesSync(png);
        }
      });
    },
  );
}
