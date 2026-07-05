import 'package:diatar_common/diatar_common.dart';

class SongNavigationPolicy {
  const SongNavigationPolicy();

  int? findSelectableSongIndex(
    List<DtxSong> songs,
    int start, {
    required bool forward,
  }) {
    if (songs.isEmpty) {
      return null;
    }
    int idx = start;
    while (idx >= 0 && idx < songs.length) {
      if (!songs[idx].separator) {
        return idx;
      }
      idx += forward ? 1 : -1;
    }
    return null;
  }
}
