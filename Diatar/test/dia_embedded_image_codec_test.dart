import 'dart:typed_data';

import 'package:diatar_app/src/core/dia/dia_embedded_image_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DiaEmbeddedImageCodec codec = DiaEmbeddedImageCodec();

  test('encodes images as a chunked ZIP archive and decodes them', () {
    final Uint8List imageBytes = Uint8List.fromList(
      List<int>.generate(4000, (int index) => index % 251),
    );
    final Map<String, String> section = codec.encode(<String, Uint8List>{
      'images/test.png': imageBytes,
      'C:/temporary/second.jpg': Uint8List.fromList(<int>[1, 2, 3]),
    });

    expect(int.parse(section['size']!), greaterThan(0));
    expect(
      section.entries
          .where(
            (MapEntry<String, String> entry) => entry.key.startsWith('data'),
          )
          .every(
            (MapEntry<String, String> entry) =>
                entry.key.length + 1 + entry.value.length <=
                DiaEmbeddedImageCodec.maxDataLineBytes,
          ),
      isTrue,
    );

    final Map<String, Uint8List> decoded = codec.decode(section);
    expect(decoded['images/test.png'], imageBytes);
    expect(decoded['C:/temporary/second.jpg'], <int>[1, 2, 3]);
  });

  test('rejects a mismatched embedded archive size', () {
    final Map<String, String> section = codec.encode(<String, Uint8List>{
      'image.png': Uint8List.fromList(<int>[1, 2, 3]),
    });
    section['size'] = '1';

    expect(() => codec.decode(section), throwsFormatException);
  });
}
