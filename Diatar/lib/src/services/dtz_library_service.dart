import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A .dtz fajlokat kezeli: a bennuk levo dia-id -> foto utvonal lekepezeset
/// epiti fel. A formatum:
///   - 'b' sor: a fotok alapkonyvtara (base directory)
///   - 'f' sor: a dia-id, majd szokoz, majd a foto relatív utvonala
class DtzLibraryService {
  const DtzLibraryService();

  Future<Directory> resolveDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/diatar/DTXs');
  }

  /// Beolvassa az osszes .dtz fajlt a DTXs konyvtarbol, es egyesiti a bennuk
  /// levo dia-id -> foto utvonal lekepezeseket egy tombben.
  Future<Map<String, String>> loadPhotos() async {
    final Directory dtxDir = await resolveDirectory();
    final Map<String, String> photos = <String, String>{};

    if (!await dtxDir.exists()) {
      return photos;
    }

    final List<FileSystemEntity> children = dtxDir.listSync();
    children.sort(
      (FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path),
    );

    for (final FileSystemEntity child in children) {
      if (child is! File || !child.path.toLowerCase().endsWith('.dtz')) {
        continue;
      }
      try {
        final String content = await child.readAsString();
        _parseFile(content, photos);
      } catch (_) {
        // Hibas dtz fajlokat atugrunk, hogy az app hasznalhato maradjon.
      }
    }

    return photos;
  }

  void _parseFile(String content, Map<String, String> photos) {
    final List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
    String baseDir = '';

    for (final String raw in lines) {
      if (raw.isEmpty) {
        continue;
      }

      if (raw.startsWith('b')) {
        baseDir = raw.substring(1).trim();
        continue;
      }

      if (raw.startsWith('f')) {
        // 'f' utan kozvetlenul a dia-id, majd space, majd az utvonal.
        final String rest = raw.substring(1);
        final int spaceIndex = rest.indexOf(' ');
        if (spaceIndex <= 0) {
          continue;
        }
        final String diaId = rest.substring(0, spaceIndex).trim();
        final String relPath = rest.substring(spaceIndex + 1).trim();
        if (diaId.isEmpty || relPath.isEmpty) {
          continue;
        }
        final String fullPath = baseDir.isEmpty
            ? relPath
            : '${baseDir.endsWith('/') || baseDir.endsWith(r'\') ? baseDir : '$baseDir/'}$relPath';
        photos[diaId] = fullPath;
      }
    }
  }
}