import 'package:diatar_common/diatar_common.dart';

class SongSelectionResult {
  const SongSelectionResult({
    required this.songIndex,
    required this.verseIndex,
    required this.statusCode,
  });

  final int songIndex;
  final int verseIndex;
  final String statusCode;
}

class SongSelectionPolicy {
  const SongSelectionPolicy();

  SongSelectionResult? selectSongAndVerse({
    required List<DtxSong> songs,
    required int targetSong,
    required int targetVerse,
    required bool includeVerseInStatus,
  }) {
    if (songs.isEmpty) {
      return null;
    }

    final int song = targetSong.clamp(0, songs.length - 1);
    final DtxSong songModel = songs[song];
    final int verse = songModel.verses.isEmpty
        ? 0
        : targetVerse.clamp(0, songModel.verses.length - 1);

    final String statusCode = includeVerseInStatus
        ? 'statusSongVerseSelected'
        : 'statusSongSelected';

    return SongSelectionResult(
      songIndex: song,
      verseIndex: verse,
      statusCode: statusCode,
    );
  }
}
