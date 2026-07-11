import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:diatar_common/diatar_common.dart';

/// A .dtz fajlokat kezeli: a bennuk levo dia-id -> foto utvonal lekepezeset
/// epiti fel. A formatum:
///   - 'b' sor: a fotok alapkonyvtara (base directory)
///   - 'f' sor: a dia-id, majd szokoz, majd a foto relatív utvonala
///   - 'Z'/'z' sor: a dia-id, majd szokoz, majd a hangfajl relatív utvonala
///   - 'F'/'f' sor: a dia-id, majd szokoz, majd a fotófajl relatív utvonala
///   - 'i' sor: a dia-id, majd szokoz, majd a forwardMS (ms) ertek
class DtzLibraryService {
  const DtzLibraryService();

  Future<Directory> resolveDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/diatar/DTZs');
  }

  /// Beolvassa az osszes .dtz fajlt a DTXs konyvtarbol, es egyesiti a bennuk
  /// levo dia-id -> DtxVerse lekepezeseket egy tombben.
  Future<Map<String, DtxVerse>> loadLibrary() async {
    final Directory dtzDir = await resolveDirectory();
    final Map<String, DtxVerse> entries = <String, DtxVerse>{};

    if (!await dtzDir.exists()) {
      return entries;
    }

    final List<FileSystemEntity> children = dtzDir.listSync();
    children.sort(
      (FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path),
    );

    for (final FileSystemEntity child in children) {
      if (child is! File || !child.path.toLowerCase().endsWith('.dtz')) {
        continue;
      }
      try {
        final String content = await child.readAsString();
        _parseFile(content, entries);
      } catch (_) {
        // Hibas dtz fajlokat atugrunk, hogy az app hasznalhato maradjon.
      }
    }

    return entries;
  }

  void _parseFile(String content, Map<String, DtxVerse> entries) async {
    final List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
    final Directory docs = await getApplicationDocumentsDirectory();

    String baseDir = '${docs.path}/diatar/DTZs';

    for (final String raw in lines) {
      if (raw.isEmpty) {
        continue;
      }

      final String prefix = raw[0];
      final String rest = raw.substring(1).trim();

      if (prefix == 'b' || prefix == 'B') {
        baseDir = '${docs.path}/diatar/DTZs/${rest.replaceAll('\\', '/')}';
        continue;
      }

      // A tobbi sor: <diaId> <ertek> formatumu
      final int spaceIndex = rest.indexOf(' ');
      if (spaceIndex <= 0) {
        continue;
      }
      final String diaId = rest.substring(0, spaceIndex).trim();
      final String value =
          rest.substring(spaceIndex + 1).trim().replaceAll('\\', '/');
      if (diaId.isEmpty) {
        continue;
      }

      // Meglévő vagy új bejegyzés lekérése
      DtxVerse verse = entries[diaId] ??
          DtxVerse(name: diaId, lines: const <String>[]);

      switch (prefix) {
        case 'f':
        case 'F':
          // Foto utvonal (dia-id szinten)
          final String fullPath = baseDir.isEmpty
              ? value
              : '${baseDir.endsWith('/') ? baseDir : '$baseDir/'}$value';
          verse = DtxVerse(
            name: verse.name,
            lines: verse.lines,
            diaId: diaId,
            soundFilePath: verse.soundFilePath,
            fotoFilePath: fullPath,
            forwardMS: verse.forwardMS,
          );
          break;
        case 'Z':
        case 'z':
          // Hangfajl utvonala
          final String fullPath = baseDir.isEmpty
              ? value
              : '${baseDir.endsWith('/') ? baseDir : '$baseDir/'}$value';
          verse = DtxVerse(
            name: verse.name,
            lines: verse.lines,
            diaId: diaId,
            soundFilePath: fullPath,
            fotoFilePath: verse.fotoFilePath,
            forwardMS: verse.forwardMS,
          );
          break;
        case 'i':
        case 'I':
          // ForwardMS (ms)
          final int forwardMS = int.tryParse(value) ?? 0;
          verse = DtxVerse(
            name: verse.name,
            lines: verse.lines,
            diaId: diaId,
            soundFilePath: verse.soundFilePath,
            fotoFilePath: verse.fotoFilePath,
            forwardMS: forwardMS,
          );
          break;
        default:
          continue;
      }

      entries[diaId] = verse;
    }
  }
}