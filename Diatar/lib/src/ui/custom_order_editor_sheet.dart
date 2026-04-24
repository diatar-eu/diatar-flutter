import 'dart:async';

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/diatar_main_controller.dart';
import '../l10n/l10n.dart';

class CustomOrderEditorPanel extends StatefulWidget {
  const CustomOrderEditorPanel({
    super.key,
    required this.controller,
    this.embedded = false,
    this.onClose,
  });

  final DiatarMainController controller;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<CustomOrderEditorPanel> createState() => _CustomOrderEditorPanelState();
}

class _CustomOrderEditorPanelState extends State<CustomOrderEditorPanel> {
  late List<CustomOrderEntry> _entries;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int _safeEntryVerseIndex(CustomOrderEntry entry, {int fallback = 0}) {
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

  DiatarMainController get controller => widget.controller;

  String _entrySignature(CustomOrderEntry entry) {
    return '${entry.fileName}|${entry.songIndex}|${entry.verseIndex}|${entry.customTextTitle ?? ''}|${entry.customTextBody ?? ''}|${entry.customImagePath ?? ''}|${entry.label}';
  }

  bool _sameEntries(List<CustomOrderEntry> left, List<CustomOrderEntry> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i++) {
      if (_entrySignature(left[i]) != _entrySignature(right[i])) {
        return false;
      }
    }
    return true;
  }

  void _syncEntriesFromControllerIfNeeded() {
    final List<CustomOrderEntry> source = List<CustomOrderEntry>.from(controller.customOrder);
    if (_sameEntries(_entries, source)) {
      return;
    }
    _entries = source;
  }

  @override
  void initState() {
    super.initState();
    _entries = List<CustomOrderEntry>.from(controller.customOrder);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        _syncEntriesFromControllerIfNeeded();
        return Material(
          color: widget.embedded ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.customOrderEditTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!widget.embedded) ...<Widget>[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: l10n.close,
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: l10n.addSong,
                    hintText: l10n.searchSongHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (String value) => setState(() => _searchQuery = value.trim()),
                ),
              ),
              Expanded(
                child: _searchQuery.isNotEmpty ? _buildSearchResults() : _buildCurrentOrderList(),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _importDia,
                      icon: const Icon(Icons.file_open),
                      label: Text(l10n.loadDia),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportDia,
                      icon: const Icon(Icons.save_alt),
                      label: Text(l10n.saveDia),
                    ),
                    if (!widget.embedded)
                      OutlinedButton.icon(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(l10n.cancel),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _commitEntries() async {
    await controller.applyCustomOrder(_entries, activate: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
    });
  }

  Future<void> _exportDia() async {
    final XTypeGroup diaType = XTypeGroup(
      label: context.l10n.diatarPlaylistFileTypeLabel,
      extensions: <String>['dia'],
    );
    final String initialDir = controller.settings.diaExportPath.trim();
    final FileSaveLocation? target = await getSaveLocation(
      suggestedName: context.l10n.customOrderSuggestedFileName,
      acceptedTypeGroups: <XTypeGroup>[diaType],
      initialDirectory: initialDir.isEmpty ? null : initialDir,
    );
    if (target == null) {
      return;
    }
    await _commitEntries();
    final String outPath = await controller.exportCustomOrderToDia(target.path);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.savedPath(outPath))),
    );
  }

  Future<void> _importDia() async {
    final XTypeGroup diaType = XTypeGroup(
      label: context.l10n.diatarPlaylistFileTypeLabel,
      extensions: <String>['dia'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[diaType]);
    if (file == null) {
      return;
    }
    final int count = await controller.importCustomOrderFromDia(file.path, activate: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
      _searchQuery = '';
    });
    _searchController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.loadedCount(count))),
    );
  }

  Widget _buildSearchResults() {
    final List<_SearchCandidate> candidates = <_SearchCandidate>[];
    for (final DtxBook book in controller.books) {
      for (int i = 0; i < book.songs.length; i++) {
        final DtxSong song = book.songs[i];
        if (song.separator) {
          continue;
        }
        candidates.add(
          _SearchCandidate(
            fileName: book.fileName,
            bookTitle: book.displayName,
            songIndex: i,
            songTitle: song.title,
          ),
        );
      }
    }

    final String filter = _searchQuery.toLowerCase();
    final List<_SearchCandidate> hits = candidates.where((_SearchCandidate c) {
      return c.bookTitle.toLowerCase().contains(filter) || c.songTitle.toLowerCase().contains(filter);
    }).toList()
      ..sort((_SearchCandidate a, _SearchCandidate b) {
        final int byBook = a.bookTitle.toLowerCase().compareTo(b.bookTitle.toLowerCase());
        return byBook != 0 ? byBook : a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase());
      });

    if (hits.isEmpty) {
      return Center(child: Text(context.l10n.noResults));
    }

    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (BuildContext context, int index) {
        final _SearchCandidate hit = hits[index];

        return ListTile(
          dense: true,
          title: Text(hit.songTitle),
          subtitle: Text(hit.bookTitle),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final CustomOrderEntry baseEntry = CustomOrderEntry(
                fileName: hit.fileName,
                songIndex: hit.songIndex,
                verseIndex: 0,
                label: controller.buildEntryLabel(hit.fileName, hit.songIndex, 0),
              );
              final List<DtxVerse> verses = controller.versesForEntry(baseEntry);
              final List<CustomOrderEntry> toInsert = verses.isEmpty
                  ? <CustomOrderEntry>[baseEntry]
                  : List<CustomOrderEntry>.generate(
                      verses.length,
                      (int verseIx) => CustomOrderEntry(
                        fileName: hit.fileName,
                        songIndex: hit.songIndex,
                        verseIndex: verseIx,
                        label: controller.buildEntryLabel(hit.fileName, hit.songIndex, verseIx),
                      ),
                    );
              setState(() {
                _entries.addAll(toInsert);
                _searchQuery = '';
              });
              _searchController.clear();
              unawaited(_commitEntries());
            },
          ),
        );
      },
    );
  }

  Widget _buildCurrentOrderList() {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          context.l10n.customOrderEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: _entries.length,
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final CustomOrderEntry entry = _entries.removeAt(oldIndex);
          _entries.insert(newIndex, entry);
        });
        unawaited(_commitEntries());
      },
      itemBuilder: (BuildContext context, int index) {
        final CustomOrderEntry entry = _entries[index];
        final bool isSongEntry = controller.isSongOrderEntry(entry);
        final bool isContinuation =
          isSongEntry &&
            index > 0 &&
            _entries[index - 1].fileName == entry.fileName &&
            _entries[index - 1].songIndex == entry.songIndex;
        final List<DtxVerse> verses = isSongEntry
          ? controller.versesForEntry(entry)
          : const <DtxVerse>[];
        final int verseIx = _safeEntryVerseIndex(entry);
        final String verseLabel = verses.isEmpty
            ? '-'
            : verses[verseIx.clamp(0, verses.length - 1)].name;
        final String titleText = isContinuation ? verseLabel : entry.label;
        return ListTile(
          key: ValueKey<String>('${entry.fileName}_${entry.songIndex}_$index'),
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          minVerticalPadding: 0,
          minTileHeight: 30,
          selected: controller.isCustomOrderIndexCurrent(index),
          selectedTileColor: Colors.blue.withValues(alpha: 0.12),
          onTap: () => unawaited(controller.projectCustomOrderEntry(entry, preferredCursor: index)),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          contentPadding: EdgeInsets.only(
            left: isContinuation ? 70 : 16,
            right: 8,
          ),
          title: Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 0.95),
          ),
          trailing: isContinuation
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isSongEntry)
                      IconButton(
                        tooltip: context.l10n.versePicker,
                        icon: const Icon(Icons.format_list_numbered),
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _pickVerse(index),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        setState(() => _entries.removeAt(index));
                        unawaited(_commitEntries());
                      },
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _pickVerse(int index) async {
    final ({int start, int end}) group = _contiguousSongGroup(index);
    final List<CustomOrderEntry> groupEntries = _entries.sublist(group.start, group.end + 1);
    final CustomOrderEntry base = groupEntries.first;
    final List<DtxVerse> verses = controller.versesForEntry(base);
    if (verses.isEmpty) {
      return;
    }

    final Set<int> selectedSet = groupEntries.map(_safeEntryVerseIndex).toSet();
    if (selectedSet.isEmpty) {
      selectedSet.add(0);
    }
    final List<int> originalSelection = selectedSet.toList()..sort();
    final List<int>? selectedMany = await showModalBottomSheet<List<int>>(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, void Function(void Function()) setModalState) {
                return SafeArea(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        title: Text(context.l10n.selectedVersesTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(context.l10n.selectedVersesSubtitle),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: verses.length,
                          itemBuilder: (BuildContext context, int i) {
                            final bool selected = selectedSet.contains(i);
                            return CheckboxListTile(
                              value: selected,
                              title: Text(verses[i].name),
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedSet.add(i);
                                  } else {
                                    selectedSet.remove(i);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(null),
                                child: Text(context.l10n.cancel),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: selectedSet.isEmpty
                                    ? null
                                    : () {
                                        final List<int> out = selectedSet.toList()..sort();
                                        Navigator.of(context).pop(out);
                                      },
                                child: Text(context.l10n.apply),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

    if (selectedMany == null || selectedMany.isEmpty) {
      return;
    }

    final List<int> normalized = selectedMany.toList()..sort();
    if (listEquals(normalized, originalSelection)) {
      return;
    }

    setState(() {
      final List<CustomOrderEntry> replacements = normalized
          .map(
            (int v) => controller.normalizeEntry(
              base.copyWith(
                verseIndex: v,
                label: controller.buildEntryLabel(base.fileName, base.songIndex, v),
              ),
            ),
          )
          .toList();
      _entries.removeRange(group.start, group.end + 1);
      _entries.insertAll(group.start, replacements);
    });

    // Commit immediately so multi-verse selections are not lost if user
    // continues navigating without pressing the bottom save button yet.
    await _commitEntries();
  }

  ({int start, int end}) _contiguousSongGroup(int index) {
    final CustomOrderEntry center = _entries[index];
    if (!controller.isSongOrderEntry(center)) {
      return (start: index, end: index);
    }
    bool sameSong(CustomOrderEntry e) =>
        controller.isSongOrderEntry(e) &&
        e.fileName == center.fileName &&
        e.songIndex == center.songIndex;

    int start = index;
    while (start > 0 && sameSong(_entries[start - 1])) {
      start--;
    }
    int end = index;
    while (end + 1 < _entries.length && sameSong(_entries[end + 1])) {
      end++;
    }
    return (start: start, end: end);
  }
}

class CustomOrderEditorSheet extends StatelessWidget {
  const CustomOrderEditorSheet({
    super.key,
    required this.controller,
  });

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController _) {
        return CustomOrderEditorPanel(
          controller: controller,
          embedded: false,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

class _SearchCandidate {
  const _SearchCandidate({
    required this.fileName,
    required this.bookTitle,
    required this.songIndex,
    required this.songTitle,
  });

  final String fileName;
  final String bookTitle;
  final int songIndex;
  final String songTitle;
}
