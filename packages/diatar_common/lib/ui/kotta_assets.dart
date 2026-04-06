import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class KottaAssets {
  KottaAssets._();

  static final Map<String, ui.Image> _images = <String, ui.Image>{};
  static Future<void>? _loading;

  static Future<void> ensureLoaded() {
    _loading ??= _loadAll();
    return _loading!;
  }

  static ui.Image? image(String name) => _images[name];

  static Future<void> _loadAll() async {
    const List<String> names = <String>[
      'be',
      'bebe',
      'ckulcs',
      'dkulcs',
      'feloldo',
      'fkulcs',
      'gkulcs',
      'hang0',
      'hang1',
      'hang2fej',
      'hang4fej',
      'hangbrevis1',
      'hangbrevis2',
      'kereszt',
      'kettoskereszt',
      'koronafel',
      'koronale',
      'marcato1',
      'marcato2',
      'mordent1',
      'mordent2',
      'pentola',
      'pont',
      'szunet1',
      'szunet16',
      'szunet2',
      'szunet4',
      'szunet8',
      'tenuto',
      'trilla1',
      'trilla2',
      'triola',
      'u22',
      'u24',
      'u32',
      'u34',
      'u38',
      'u44',
      'u54',
      'u64',
      'u68',
      'zaszlo16fel',
      'zaszlo16le',
      'zaszlo8fel',
      'zaszlo8le',
    ];

    for (final String n in names) {
      try {
        final ByteData data = await rootBundle.load('assets/kotta/$n.png');
        final Uint8List bytes = Uint8List.view(data.buffer);
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        _images[n] = frame.image;
      } catch (_) {
        // Missing/corrupt asset should not crash projection.
      }
    }
  }
}
