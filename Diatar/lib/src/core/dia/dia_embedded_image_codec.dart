import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class DiaEmbeddedImageSourceMissingException implements Exception {
  const DiaEmbeddedImageSourceMissingException(this.path);

  final String path;
}

class DiaEmbeddedImageCodec {
  const DiaEmbeddedImageCodec();

  static const int maxDataLineBytes = 1000;

  Map<String, String> encode(Map<String, Uint8List> images) {
    final Archive archive = Archive();
    for (final MapEntry<String, Uint8List> image in images.entries) {
      archive.addFile(ArchiveFile.bytes(image.key, image.value));
    }
    final List<int> zipBytes = ZipEncoder().encode(archive);
    final String data = base64Encode(zipBytes);
    final Map<String, String> section = <String, String>{
      'size': '${zipBytes.length}',
    };
    for (int offset = 0, index = 1; offset < data.length; index++) {
      final int capacity = maxDataLineBytes - 'data$index='.length;
      final int end = (offset + capacity).clamp(0, data.length);
      section['data$index'] = data.substring(offset, end);
      offset = end;
    }
    return section;
  }

  Map<String, Uint8List> decode(Map<String, String>? section) {
    if (section == null || section.isEmpty) {
      return const <String, Uint8List>{};
    }
    final int? expectedSize = int.tryParse(section['size'] ?? '');
    if (expectedSize == null || expectedSize < 0) {
      throw const FormatException('Invalid embedded DIA image archive size.');
    }

    final List<MapEntry<int, String>> chunks =
        section.entries
            .map((MapEntry<String, String> entry) {
              final Match? match = RegExp(r'^data(\d+)$').firstMatch(entry.key);
              final int? index = match == null
                  ? null
                  : int.tryParse(match.group(1)!);
              return index == null
                  ? null
                  : MapEntry<int, String>(index, entry.value);
            })
            .whereType<MapEntry<int, String>>()
            .toList()
          ..sort(
            (MapEntry<int, String> left, MapEntry<int, String> right) =>
                left.key.compareTo(right.key),
          );
    if (chunks.isEmpty ||
        chunks.first.key != 1 ||
        chunks.asMap().entries.any(
          (MapEntry<int, MapEntry<int, String>> entry) =>
              entry.value.key != entry.key + 1,
        )) {
      throw const FormatException('Invalid embedded DIA image archive data.');
    }

    final Uint8List zipBytes;
    try {
      zipBytes = Uint8List.fromList(
        base64Decode(
          chunks.map((MapEntry<int, String> chunk) => chunk.value).join(),
        ),
      );
    } on FormatException {
      throw const FormatException(
        'Invalid embedded DIA image archive encoding.',
      );
    }
    if (zipBytes.length != expectedSize) {
      throw const FormatException('Embedded DIA image archive size mismatch.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    } catch (_) {
      throw const FormatException('Invalid embedded DIA image archive.');
    }
    final Map<String, Uint8List> images = <String, Uint8List>{};
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile || file.name.isEmpty || images.containsKey(file.name)) {
        continue;
      }
      final Object content = file.content;
      if (content is List<int>) {
        images[file.name] = Uint8List.fromList(content);
      }
    }
    return images;
  }
}
