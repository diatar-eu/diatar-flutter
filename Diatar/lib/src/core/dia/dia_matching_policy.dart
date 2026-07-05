import 'package:diatar_common/diatar_common.dart';

class DiaMatchingPolicy {
  const DiaMatchingPolicy();

  String normalize(String text) {
    const Map<String, String> repl = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ö': 'o',
      'ő': 'o',
      'ú': 'u',
      'ü': 'u',
      'ű': 'u',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ö': 'o',
      'Ő': 'o',
      'Ú': 'u',
      'Ü': 'u',
      'Ű': 'u',
    };
    final StringBuffer sb = StringBuffer();
    bool lastWasSpace = false;
    for (final int rune in text.runes) {
      final String ch = String.fromCharCode(rune);
      final String mapped = repl[ch] ?? ch;
      final bool isSep =
          mapped.trim().isEmpty ||
          mapped == '_' ||
          mapped == '-' ||
          mapped == '/';
      if (isSep) {
        if (!lastWasSpace) {
          sb.write(' ');
          lastWasSpace = true;
        }
        continue;
      }
      sb.write(mapped.toLowerCase());
      lastWasSpace = false;
    }
    return sb.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  int findBookIndex(List<DtxBook> books, String kotet) {
    final String needle = normalize(kotet);
    if (needle.isEmpty) {
      return -1;
    }
    return books.indexWhere((DtxBook b) {
      return normalize(b.title) == needle ||
          normalize(b.displayName) == needle ||
          normalize(b.fileName) == needle;
    });
  }

  int findSongIndex(DtxBook book, String enek) {
    final String needle = normalize(enek);
    if (needle.isEmpty) {
      return -1;
    }
    return book.songs.indexWhere(
      (DtxSong s) => !s.separator && normalize(s.title) == needle,
    );
  }

  int findVerseIndex(DtxSong song, String versszak) {
    final String needle = normalize(versszak);
    if (needle.isEmpty) {
      return 0;
    }
    final int parsed = song.verses.indexWhere(
      (DtxVerse v) => normalize(v.name) == needle,
    );
    return parsed >= 0 ? parsed : 0;
  }
}
