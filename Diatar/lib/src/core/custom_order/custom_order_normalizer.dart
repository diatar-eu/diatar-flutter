import 'package:diatar_common/diatar_common.dart';

import '../../models/custom_order_entry.dart';
import 'entry_label_service.dart';
import 'entry_resolver.dart';

class CustomOrderNormalizer {
  const CustomOrderNormalizer({
    required this.resolver,
    required this.labelService,
  });

  final EntryResolver resolver;
  final EntryLabelService labelService;

  int safeVerseIndex(CustomOrderEntry entry, {int fallback = 0}) {
    return resolver.safeVerseIndex(entry, fallback: fallback);
  }

  CustomOrderEntry normalizeEntry(CustomOrderEntry entry, List<DtxBook> books) {
    if (!entry.isSongEntry) {
      return entry;
    }
    final DtxBook? book = resolver.bookForEntry(books, entry);
    if (book == null) {
      return entry;
    }
    if (book.songs.isEmpty) {
      return entry.copyWith(label: book.displayName);
    }

    final int safeSong = entry.songIndex.clamp(0, book.songs.length - 1);
    final DtxSong song = book.songs[safeSong];
    final int safeVerse = song.verses.isEmpty
        ? 0
        : safeVerseIndex(entry).clamp(0, song.verses.length - 1);

    return entry.copyWith(
      songIndex: safeSong,
      verseIndex: safeVerse,
      label: labelService.buildEntryLabel(
        books,
        entry.fileName,
        safeSong,
        safeVerse,
      ),
    );
  }
}
