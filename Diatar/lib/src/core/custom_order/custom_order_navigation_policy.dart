import '../../models/custom_order_entry.dart';

class CustomOrderNavigationPolicy {
  const CustomOrderNavigationPolicy();

  int? findNextProjectableIndex(List<CustomOrderEntry> source, int start) {
    int idx = start;
    while (idx >= 0 && idx < source.length) {
      if (!source[idx].isSeparator) {
        return idx;
      }
      idx++;
    }
    return null;
  }

  int? findPrevProjectableIndex(List<CustomOrderEntry> source, int start) {
    int idx = start;
    while (idx >= 0 && idx < source.length) {
      if (!source[idx].isSeparator) {
        return idx;
      }
      idx--;
    }
    return null;
  }

  String? nonSongSlashGroupPrefix(CustomOrderEntry entry) {
    if (entry.isSongEntry || entry.isSeparator) {
      return null;
    }
    final String source = (entry.customTextTitle ?? entry.label).trim();
    if (source.isEmpty) {
      return null;
    }
    final int slashIndex = source.indexOf('/');
    if (slashIndex <= 0 || slashIndex >= source.length - 1) {
      return null;
    }
    final String prefix = source.substring(0, slashIndex).trim();
    final String suffix = source.substring(slashIndex + 1).trim();
    if (prefix.isEmpty || suffix.isEmpty) {
      return null;
    }
    return prefix.toLowerCase();
  }

  bool isDiaSongGroupContinuation(
    List<CustomOrderEntry> source,
    int previousIndex,
    int currentIndex, {
    required int Function(CustomOrderEntry entry) safeVerseIndex,
  }) {
    if (previousIndex < 0 ||
        currentIndex < 0 ||
        previousIndex >= source.length ||
        currentIndex >= source.length) {
      return false;
    }
    final CustomOrderEntry previous = source[previousIndex];
    final CustomOrderEntry current = source[currentIndex];
    if (previous.isSongEntry && current.isSongEntry) {
      return previous.fileName == current.fileName &&
          previous.songIndex == current.songIndex &&
          safeVerseIndex(current) == safeVerseIndex(previous) + 1;
    }

    final String? previousPrefix = nonSongSlashGroupPrefix(previous);
    if (previousPrefix == null) {
      return false;
    }
    final String? currentPrefix = nonSongSlashGroupPrefix(current);
    if (currentPrefix == null) {
      return false;
    }
    return previousPrefix == currentPrefix;
  }

  int currentDiaGroupStartIndex(
    List<CustomOrderEntry> source,
    int currentIndex, {
    required int Function(CustomOrderEntry entry) safeVerseIndex,
  }) {
    int current = currentIndex;
    while (
        current > 0 &&
        isDiaSongGroupContinuation(source, current - 1, current,
            safeVerseIndex: safeVerseIndex)) {
      current--;
    }
    return current;
  }

  int? findNextDiaSongGroupStart(
    List<CustomOrderEntry> source,
    int currentGroupStart, {
    required int Function(CustomOrderEntry entry) safeVerseIndex,
  }) {
    if (source.isEmpty) {
      return null;
    }
    int next = currentGroupStart + 1;
    while (
        next < source.length &&
        isDiaSongGroupContinuation(source, next - 1, next,
            safeVerseIndex: safeVerseIndex)) {
      next++;
    }
    if (next >= source.length) {
      return null;
    }
    return next;
  }

  int? findPrevDiaSongGroupStart(
    List<CustomOrderEntry> source,
    int currentGroupStart, {
    required int Function(CustomOrderEntry entry) safeVerseIndex,
  }) {
    if (source.isEmpty) {
      return null;
    }
    int start = currentGroupStart - 1;
    if (start < 0) {
      return null;
    }
    while (
        start > 0 &&
        isDiaSongGroupContinuation(source, start - 1, start,
            safeVerseIndex: safeVerseIndex)) {
      start--;
    }
    return start;
  }
}
