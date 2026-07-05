import '../../models/custom_order_entry.dart';
import 'entry_resolver.dart';

class EntryMatchPolicy {
  const EntryMatchPolicy({required this.resolver});

  final EntryResolver resolver;

  int findCurrentIndex({
    required List<CustomOrderEntry> source,
    required int projectedCursor,
    required int currentCursor,
    required String? currentBookFileName,
    required int currentSongIndex,
    required int currentVerseIndex,
  }) {
    if (projectedCursor >= 0 && projectedCursor < source.length) {
      return projectedCursor;
    }

    if (currentBookFileName == null || source.isEmpty) {
      return -1;
    }

    bool matches(int idx) {
      if (idx < 0 || idx >= source.length) {
        return false;
      }
      final CustomOrderEntry entry = source[idx];
      return entry.fileName == currentBookFileName &&
          entry.songIndex == currentSongIndex &&
          resolver.safeVerseIndex(entry) == currentVerseIndex;
    }

    if (matches(currentCursor)) {
      return currentCursor;
    }
    for (int i = currentCursor + 1; i < source.length; i++) {
      if (matches(i)) {
        return i;
      }
    }
    for (int i = 0; i <= currentCursor && i < source.length; i++) {
      if (matches(i)) {
        return i;
      }
    }
    return -1;
  }

  int findEntryIndex(
    List<CustomOrderEntry> source,
    CustomOrderEntry entry, {
    int preferredCursor = -1,
  }) {
    bool matches(int idx) {
      if (idx < 0 || idx >= source.length) {
        return false;
      }
      final CustomOrderEntry candidate = source[idx];
      if (!entry.isSongEntry || !candidate.isSongEntry) {
        return candidate.fileName == entry.fileName &&
            candidate.songIndex == entry.songIndex &&
            candidate.label == entry.label &&
            candidate.customTextTitle == entry.customTextTitle &&
            candidate.customTextBody == entry.customTextBody &&
            candidate.customImagePath == entry.customImagePath &&
            candidate.customType == entry.customType &&
            _mapEquals(candidate.customData, entry.customData);
      }
      return candidate.fileName == entry.fileName &&
          candidate.songIndex == entry.songIndex &&
          resolver.safeVerseIndex(candidate) == resolver.safeVerseIndex(entry);
    }

    if (preferredCursor >= 0 &&
        preferredCursor < source.length &&
        matches(preferredCursor)) {
      return preferredCursor;
    }

    if (preferredCursor >= 0) {
      for (int i = preferredCursor + 1; i < source.length; i++) {
        if (matches(i)) {
          return i;
        }
      }
      for (int i = 0; i < preferredCursor && i < source.length; i++) {
        if (matches(i)) {
          return i;
        }
      }
      return -1;
    }

    for (int i = 0; i < source.length; i++) {
      if (matches(i)) {
        return i;
      }
    }
    return -1;
  }

  bool _mapEquals(Map<String, dynamic> left, Map<String, dynamic> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final MapEntry<String, dynamic> entry in left.entries) {
      if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
