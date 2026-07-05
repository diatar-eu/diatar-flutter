import 'package:diatar_common/diatar_common.dart';

import '../../models/custom_order_entry.dart';

class EntryResolver {
  const EntryResolver();

  DtxBook? bookForEntry(List<DtxBook> books, CustomOrderEntry entry) {
    final int idx = books.indexWhere((DtxBook b) => b.fileName == entry.fileName);
    if (idx < 0) {
      return null;
    }
    return books[idx];
  }

  DtxSong? songForEntry(List<DtxBook> books, CustomOrderEntry entry) {
    final DtxBook? book = bookForEntry(books, entry);
    if (book == null || book.songs.isEmpty) {
      return null;
    }
    final int safeSong = entry.songIndex.clamp(0, book.songs.length - 1);
    return book.songs[safeSong];
  }

  List<DtxVerse> versesForEntry(List<DtxBook> books, CustomOrderEntry entry) {
    return songForEntry(books, entry)?.verses ?? const <DtxVerse>[];
  }

  int safeVerseIndex(CustomOrderEntry entry, {int fallback = 0}) {
    try {
      final dynamic value = (entry as dynamic).verseIndex;
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    } catch (_) {}
    return fallback;
  }
}
