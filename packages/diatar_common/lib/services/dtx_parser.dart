import '../models/dtx_models.dart';

class DtxParser {
  const DtxParser();

  DtxBook parse({
    required String fileName,
    required String content,
    String? title,
  }) {
    final List<String> lines = content.replaceAll('\r\n', '\n').split('\n');

    String parsedTitle = title ?? fileName;
    String parsedNick = fileName;
    String parsedGroup = '';
    int parsedOrder = 0;

    final List<DtxSong> songs = <DtxSong>[];
    String? currentSongTitle;
    final List<DtxVerse> currentVerses = <DtxVerse>[];
    String currentVerseName = '';
    final List<String> currentVerseLines = <String>[];
    bool songHasBody = false;
    bool seenSongStart = false;

    void flushVerseIfNeeded() {
      if (currentSongTitle == null) {
        return;
      }
      if (currentVerseLines.isEmpty && currentVerses.isNotEmpty) {
        return;
      }
      if (currentVerseLines.isEmpty && currentVerses.isEmpty) {
        return;
      }
      currentVerses.add(
        DtxVerse(
          name: currentVerseName.isEmpty ? '---' : currentVerseName,
          lines: List<String>.from(currentVerseLines),
        ),
      );
      currentVerseLines.clear();
    }

    void flushSongIfNeeded() {
      if (currentSongTitle == null) {
        return;
      }
      flushVerseIfNeeded();
      if (currentVerses.isEmpty) {
        currentVerses.add(const DtxVerse(name: '---', lines: <String>['']));
      }
      songs.add(
        DtxSong(
          title: currentSongTitle,
          separator: !songHasBody,
          verses: List<DtxVerse>.from(currentVerses),
        ),
      );
      currentVerses.clear();
      currentVerseName = '';
      currentVerseLines.clear();
      songHasBody = false;
    }

    for (final String raw in lines) {
      if (raw.isEmpty) {
        continue;
      }

      if (!seenSongStart) {
        if (raw.startsWith('>')) {
          seenSongStart = true;
          flushSongIfNeeded();
          currentSongTitle = raw.substring(1).trim();
          currentVerseName = '';
          continue;
        }

        if (raw.startsWith('N')) {
          final String value = raw.substring(1).trim();
          if (value.isNotEmpty) {
            parsedTitle = value;
          }
          continue;
        }

        if (raw.startsWith('R')) {
          final String value = raw.substring(1).trim();
          if (value.isNotEmpty) {
            parsedNick = value;
          }
          continue;
        }

        if (raw.startsWith('C')) {
          parsedGroup = raw.substring(1).trim();
          continue;
        }

        if (raw.startsWith('S')) {
          parsedOrder = int.tryParse(raw.substring(1).trim()) ?? parsedOrder;
        }
        continue;
      }

      if (raw.startsWith('>')) {
        flushSongIfNeeded();
        currentSongTitle = raw.substring(1).trim();
        currentVerseName = '';
        continue;
      }

      if (currentSongTitle == null) {
        continue;
      }

      if (raw.startsWith('/')) {
        flushVerseIfNeeded();
        currentVerseName = raw.substring(1).trim();
        songHasBody = true;
        continue;
      }

      if (raw.startsWith(' ')) {
        currentVerseLines.add(_deFormat(raw.substring(1)));
        songHasBody = true;
      }
    }

    flushSongIfNeeded();

    return DtxBook(
      fileName: fileName,
      title: parsedTitle,
      nick: parsedNick,
      group: parsedGroup,
      order: parsedOrder,
      songs: songs,
    );
  }

  String _deFormat(String src) {
    final StringBuffer sb = StringBuffer();
    bool esc = false;
    int i = 0;
    while (i < src.length) {
      final String ch = src[i++];
      if (!esc) {
        if (ch == r'\') {
          esc = true;
        } else {
          sb.write(ch);
        }
        continue;
      }

      esc = false;
      switch (ch) {
        case '.':
        case ' ':
          sb.write(' ');
          break;
        case '-':
        case '_':
          sb.write('-');
          break;
        case 'G':
        case 'K':
        case '?':
          while (i < src.length && src[i++] != ';') {}
          break;
        case 'B':
        case 'b':
        case 'I':
        case 'i':
        case 'U':
        case 'u':
          // Style commands are intentionally ignored in plain text preview.
          break;
        default:
          sb.write(ch);
          break;
      }
    }
    return sb.toString();
  }
}
