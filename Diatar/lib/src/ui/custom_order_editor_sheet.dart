import 'dart:async';
import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/diatar_main_controller.dart';
import '../l10n/l10n.dart';
import '../utils/friendly_path.dart';

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
  String? _selectedInsertBookFileName;
  int? _selectedInsertSongIndex;

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
    final List<CustomOrderEntry> source = List<CustomOrderEntry>.from(
      controller.customOrder,
    );
    if (_sameEntries(_entries, source)) {
      return;
    }
    _entries = source;
  }

  bool _bookHasSongs(DtxBook book) {
    return book.songs.any((DtxSong song) => !song.separator);
  }

  List<_SongOption> _songOptionsForBook(DtxBook book) {
    final List<_SongOption> options = <_SongOption>[];
    for (int i = 0; i < book.songs.length; i++) {
      final DtxSong song = book.songs[i];
      if (song.separator) {
        continue;
      }
      options.add(_SongOption(songIndex: i, songTitle: song.title));
    }
    return options;
  }

  List<_InsertBookDropdownEntry> _buildInsertBookDropdownEntries(
    List<DtxBook> books,
  ) {
    final List<_InsertBookDropdownEntry> entries = <_InsertBookDropdownEntry>[];
    String? lastGroup;
    for (final DtxBook book in books) {
      final String group = book.group.trim();
      if (group.isNotEmpty && group != lastGroup) {
        entries.add(_InsertBookDropdownEntry.header(group));
        lastGroup = group;
      }
      if (group.isEmpty) {
        lastGroup = null;
      }
      entries.add(
        _InsertBookDropdownEntry.book(
          fileName: book.fileName,
          title: book.title,
        ),
      );
    }
    return entries;
  }

  void _ensureInsertSelectionValid() {
    final List<DtxBook> books = controller.books
        .where(_bookHasSongs)
        .toList(growable: false);
    if (books.isEmpty) {
      _selectedInsertBookFileName = null;
      _selectedInsertSongIndex = null;
      return;
    }

    final DtxBook selectedBook = books.firstWhere(
      (DtxBook b) => b.fileName == _selectedInsertBookFileName,
      orElse: () => books.first,
    );
    if (_selectedInsertBookFileName != selectedBook.fileName) {
      _selectedInsertBookFileName = selectedBook.fileName;
    }

    final List<_SongOption> songOptions = _songOptionsForBook(selectedBook);
    if (songOptions.isEmpty) {
      _selectedInsertSongIndex = null;
      return;
    }

    final bool songStillValid = songOptions.any(
      (_SongOption option) => option.songIndex == _selectedInsertSongIndex,
    );
    if (!songStillValid) {
      _selectedInsertSongIndex = songOptions.first.songIndex;
    }
  }

  @override
  void initState() {
    super.initState();
    _entries = List<CustomOrderEntry>.from(controller.customOrder);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        _syncEntriesFromControllerIfNeeded();
        _ensureInsertSelectionValid();
        return Material(
          color: widget.embedded
              ? Colors.transparent
              : Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.customOrderEditTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.addSong,
                      onPressed: _openSearchDialog,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: l10n.customOrderInsertVersesAction,
                      onPressed: _openInsertVersesDialog,
                      icon: const Icon(Icons.playlist_add),
                    ),
                    IconButton(
                      tooltip: l10n.customOrderInsertSeparatorAction,
                      onPressed: _insertSeparator,
                      icon: const Icon(Icons.horizontal_rule),
                    ),
                    IconButton(
                      tooltip: l10n.addTextSlide,
                      onPressed: _openCustomTextSlideDialog,
                      icon: const Icon(Icons.text_fields),
                    ),
                    IconButton(
                      tooltip: l10n.addImageSlideTooltip,
                      onPressed: _pickAndSendImageSlide,
                      icon: const Icon(Icons.image),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildCurrentOrderList()),
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
                        icon: const Icon(Icons.close),
                        label: Text(l10n.close),
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

  Future<void> _openInsertVersesDialog() async {
    final List<DtxBook> books = controller.books
        .where(_bookHasSongs)
        .toList(growable: false);
    final List<_InsertBookDropdownEntry> bookEntries =
        _buildInsertBookDropdownEntries(books);
    if (books.isEmpty) {
      return;
    }

    String selectedBookFileName =
        _selectedInsertBookFileName ?? books.first.fileName;
    DtxBook selectedBook = books.firstWhere(
      (DtxBook b) => b.fileName == selectedBookFileName,
      orElse: () => books.first,
    );
    List<_SongOption> songs = _songOptionsForBook(selectedBook);
    int? selectedSongIndex =
        songs.any(
          (_SongOption option) => option.songIndex == _selectedInsertSongIndex,
        )
        ? _selectedInsertSongIndex
        : (songs.isEmpty ? null : songs.first.songIndex);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final NavigatorState dialogNavigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder:
              (
                BuildContext innerContext,
                void Function(void Function()) setDialogState,
              ) {
                selectedBook = books.firstWhere(
                  (DtxBook b) => b.fileName == selectedBookFileName,
                  orElse: () => books.first,
                );
                songs = _songOptionsForBook(selectedBook);
                if (!songs.any(
                  (_SongOption option) => option.songIndex == selectedSongIndex,
                )) {
                  selectedSongIndex = songs.isEmpty
                      ? null
                      : songs.first.songIndex;
                }

                return AlertDialog(
                  title: Text(l10n.customOrderInsertVersesAction),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedBook.fileName,
                          decoration: InputDecoration(
                            labelText: l10n.customOrderInsertBookLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: bookEntries.asMap().entries.map((
                            MapEntry<int, _InsertBookDropdownEntry> e,
                          ) {
                            final _InsertBookDropdownEntry entry = e.value;
                            if (entry.isHeader) {
                              return DropdownMenuItem<String>(
                                value: '__header_${e.key}',
                                enabled: false,
                                child: Text(
                                  '[${entry.group!}]',
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          dialogContext,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              );
                            }
                            return DropdownMenuItem<String>(
                              value: entry.fileName,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    entry.title!,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (BuildContext context) {
                            return bookEntries.map((
                              _InsertBookDropdownEntry entry,
                            ) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  entry.title ?? '[${entry.group!}]',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList();
                          },
                          onChanged: (String? value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedBookFileName = value;
                              final DtxBook selected = books.firstWhere(
                                (DtxBook b) => b.fileName == value,
                              );
                              final List<_SongOption> options =
                                  _songOptionsForBook(selected);
                              selectedSongIndex = options.isEmpty
                                  ? null
                                  : options.first.songIndex;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: selectedSongIndex,
                          decoration: InputDecoration(
                            labelText: l10n.customOrderInsertSongLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: songs
                              .map(
                                (_SongOption option) => DropdownMenuItem<int>(
                                  value: option.songIndex,
                                  child: Text(
                                    option.songTitle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (int? value) {
                            setDialogState(() => selectedSongIndex = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => dialogNavigator.pop(),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton.icon(
                      onPressed: selectedSongIndex == null
                          ? null
                          : () async {
                              dialogNavigator.pop();
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _selectedInsertBookFileName =
                                    selectedBookFileName;
                                _selectedInsertSongIndex = selectedSongIndex;
                              });
                              await _insertFromSelection(
                                selectedBookFileName,
                                selectedSongIndex!,
                              );
                            },
                      icon: const Icon(Icons.playlist_add),
                      label: Text(l10n.customOrderInsertVersesAction),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _insertFromSelection(
    String selectedBookFileName,
    int selectedSongIndex,
  ) async {
    final CustomOrderEntry baseEntry = CustomOrderEntry(
      fileName: selectedBookFileName,
      songIndex: selectedSongIndex,
      verseIndex: 0,
      label: controller.buildEntryLabel(
        selectedBookFileName,
        selectedSongIndex,
        0,
      ),
    );
    final List<DtxVerse> verses = controller.versesForEntry(baseEntry);

    List<CustomOrderEntry> toInsert;
    if (verses.isEmpty) {
      toInsert = <CustomOrderEntry>[baseEntry];
    } else if (verses.length == 1) {
      toInsert = <CustomOrderEntry>[
        CustomOrderEntry(
          fileName: selectedBookFileName,
          songIndex: selectedSongIndex,
          verseIndex: 0,
          label: controller.buildEntryLabel(
            selectedBookFileName,
            selectedSongIndex,
            0,
          ),
        ),
      ];
    } else {
      final Set<int> allSelected = Set<int>.from(
        List<int>.generate(verses.length, (int i) => i),
      );
      final List<int>? chosen = await _showVerseSelectionSheet(
        verses: verses,
        initialSelection: allSelected,
        title: context.l10n.customOrderInsertVersesTitle,
        subtitle: context.l10n.customOrderInsertVersesSubtitle,
      );
      if (chosen == null || chosen.isEmpty) {
        return;
      }
      toInsert = chosen
          .map(
            (int verseIx) => CustomOrderEntry(
              fileName: selectedBookFileName,
              songIndex: selectedSongIndex,
              verseIndex: verseIx,
              label: controller.buildEntryLabel(
                selectedBookFileName,
                selectedSongIndex,
                verseIx,
              ),
            ),
          )
          .toList();
    }

    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insertAll(insertIndex, toInsert);
    });
    await _commitEntries();
  }

  Future<void> _openSearchDialog() async {
    String query = '';

    final _SearchCandidate? selected = await showDialog<_SearchCandidate>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final NavigatorState dialogNavigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder:
              (
                BuildContext innerContext,
                void Function(void Function()) setDialogState,
              ) {
                final String filter = query.trim().toLowerCase();
                final List<_SearchCandidate> hits =
                    _collectSearchCandidates()
                        .where(
                          (_SearchCandidate candidate) =>
                              candidate.bookSearchText.toLowerCase().contains(
                                filter,
                              ) ||
                              candidate.songTitle.toLowerCase().contains(
                                filter,
                              ),
                        )
                        .toList()
                      ..sort((_SearchCandidate a, _SearchCandidate b) {
                        final int byBook = a.bookSortTitle
                            .toLowerCase()
                            .compareTo(b.bookSortTitle.toLowerCase());
                        if (byBook != 0) {
                          return byBook;
                        }
                        final int byGroup = a.bookGroup.toLowerCase().compareTo(
                          b.bookGroup.toLowerCase(),
                        );
                        return byGroup != 0
                            ? byGroup
                            : a.songTitle.toLowerCase().compareTo(
                                b.songTitle.toLowerCase(),
                              );
                      });

                return AlertDialog(
                  title: Text(l10n.addSong),
                  content: SizedBox(
                    width: 560,
                    height: 460,
                    child: Column(
                      children: <Widget>[
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: l10n.searchSongHint,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (String value) {
                            setDialogState(() => query = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: hits.isEmpty
                              ? Center(child: Text(l10n.noResults))
                              : ListView.builder(
                                  itemCount: hits.length,
                                  itemBuilder:
                                      (BuildContext listContext, int index) {
                                        final _SearchCandidate hit =
                                            hits[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(hit.songTitle),
                                          subtitle: Text(hit.bookDisplayTitle),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            onPressed: () {
                                              dialogNavigator.pop(hit);
                                            },
                                          ),
                                        );
                                      },
                                ),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => dialogNavigator.pop(),
                      child: Text(l10n.close),
                    ),
                  ],
                );
              },
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    await _insertSearchCandidate(selected);
  }

  List<_SearchCandidate> _collectSearchCandidates() {
    final List<_SearchCandidate> candidates = <_SearchCandidate>[];
    for (final DtxBook book in controller.books) {
      final String group = book.group.trim();
      final String fullTitle = book.title;
      final String displayTitle = group.isEmpty
          ? fullTitle
          : '[$group] $fullTitle';
      final String searchText = '${book.displayName} $fullTitle';
      for (int i = 0; i < book.songs.length; i++) {
        final DtxSong song = book.songs[i];
        if (song.separator) {
          continue;
        }
        candidates.add(
          _SearchCandidate(
            fileName: book.fileName,
            bookDisplayTitle: displayTitle,
            bookSortTitle: fullTitle,
            bookSearchText: searchText,
            bookGroup: group,
            songIndex: i,
            songTitle: song.title,
          ),
        );
      }
    }
    return candidates;
  }

  Future<void> _insertSearchCandidate(_SearchCandidate hit) async {
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
              label: controller.buildEntryLabel(
                hit.fileName,
                hit.songIndex,
                verseIx,
              ),
            ),
          );

    setState(() {
      _entries.addAll(toInsert);
    });
    await _commitEntries();
  }

  Future<void> _pickAndSendImageSlide() async {
    final XTypeGroup images = XTypeGroup(
      label: context.l10n.imagesFileTypeLabel,
      extensions: <String>['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[images],
    );
    if (file == null) {
      return;
    }

    final String fileName = file.name;
    final CustomOrderEntry entry = CustomOrderEntry(
      fileName: '__custom_image__',
      songIndex: -2,
      verseIndex: 0,
      label: '[Kep] $fileName',
      customImagePath: file.path,
    );

    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insert(insertIndex, entry);
    });
    await _commitEntries();
  }

  Future<void> _openCustomTextSlideDialog() async {
    final _TextSlideInput? input = await showDialog<_TextSlideInput>(
      context: context,
      builder: (BuildContext context) => const _CustomTextSlideDialog(),
    );
    if (input == null || !mounted) {
      return;
    }

    final String normalizedTitle = input.title.trim();
    final List<String> lines = input.body
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trimRight())
        .where((String line) => line.trim().isNotEmpty)
        .toList();
    if (normalizedTitle.isEmpty && lines.isEmpty) {
      return;
    }

    final String effectiveTitle = normalizedTitle.isEmpty
        ? 'Dia'
        : normalizedTitle;
    final CustomOrderEntry entry = CustomOrderEntry(
      fileName: '__custom_text__',
      songIndex: -1,
      verseIndex: 0,
      label: '[Szoveg] $effectiveTitle',
      customTextTitle: effectiveTitle,
      customTextBody: lines.join('\n'),
    );

    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insert(insertIndex, entry);
    });
    await _commitEntries();
  }

  Future<void> _insertSeparator() async {
    final l10n = context.l10n;
    String entered = l10n.customOrderSeparatorDefaultName;

    final String? enteredName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final dialogL10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(dialogL10n.customOrderInsertSeparatorAction),
          content: TextFormField(
            initialValue: entered,
            autofocus: true,
            decoration: InputDecoration(
              labelText: dialogL10n.customOrderSeparatorNameLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (String value) => entered = value,
            onFieldSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(dialogL10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(entered);
              },
              child: Text(dialogL10n.apply),
            ),
          ],
        );
      },
    );

    if (enteredName == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final String separatorName = enteredName.trim().isEmpty
        ? l10n.customOrderSeparatorDefaultName
        : enteredName.trim();
    final CustomOrderEntry entry = CustomOrderEntry(
      fileName: CustomOrderEntry.separatorFileName,
      songIndex: CustomOrderEntry.separatorSongIndex,
      verseIndex: 0,
      label: '--- $separatorName ---',
      customTextTitle: separatorName,
    );

    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insert(insertIndex, entry);
    });
    await _commitEntries();
  }

  int _selectedInsertInsertionIndex() {
    if (_entries.isEmpty) {
      return 0;
    }
    final int cursor = controller.customOrderCursor;
    if (cursor < 0 || cursor >= _entries.length) {
      return _entries.length;
    }
    return cursor + 1;
  }

  Future<List<int>?> _showVerseSelectionSheet({
    required List<DtxVerse> verses,
    required Set<int> initialSelection,
    required String title,
    required String subtitle,
  }) async {
    final Set<int> selectedSet = Set<int>.from(initialSelection);
    return showModalBottomSheet<List<int>>(
      context: context,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext sheetContext,
                void Function(void Function()) setModalState,
              ) {
                return SafeArea(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(subtitle),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: <Widget>[
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  selectedSet
                                    ..clear()
                                    ..addAll(
                                      List<int>.generate(
                                        verses.length,
                                        (int i) => i,
                                      ),
                                    );
                                });
                              },
                              icon: const Icon(Icons.done_all),
                              label: Text(
                                sheetContext.l10n.customOrderSelectAllVerses,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                setModalState(selectedSet.clear);
                              },
                              icon: const Icon(Icons.remove_done),
                              label: Text(
                                sheetContext
                                    .l10n
                                    .customOrderClearVerseSelection,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: verses.length,
                          itemBuilder: (BuildContext itemContext, int i) {
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
                                onPressed: () =>
                                    Navigator.of(modalContext).pop(null),
                                child: Text(sheetContext.l10n.cancel),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: selectedSet.isEmpty
                                    ? null
                                    : () {
                                        final List<int> out =
                                            selectedSet.toList()..sort();
                                        Navigator.of(modalContext).pop(out);
                                      },
                                child: Text(sheetContext.l10n.apply),
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
    final l10n = context.l10n;
    final XTypeGroup diaType = XTypeGroup(
      label: l10n.diatarPlaylistFileTypeLabel,
      extensions: <String>['dia'],
    );
    try {
      await _commitEntries();

      String? targetPath;
      bool nativeSaveDialogAvailable = true;
      final String fallbackBaseName = controller.customOrderLooksLikeZsolozsma
          ? l10n.zsolozsmaTooltip
          : l10n.customOrderSuggestedFileName;
      final String defaultBaseName = _normalizeDiaBaseName(
        controller.lastImportedCustomOrderBaseName ?? fallbackBaseName,
        fallback: 'sorrend',
      );
      final String defaultFileName = '$defaultBaseName.dia';
      final String configuredDir = controller.settings.diaExportPath.trim();
      final bool hadConfiguredDir = configuredDir.isNotEmpty;
      final String? initialDir =
          configuredDir.isNotEmpty && Directory(configuredDir).existsSync()
          ? configuredDir
          : null;

      try {
        final FileSaveLocation? target = await getSaveLocation(
          suggestedName: defaultFileName,
          acceptedTypeGroups: <XTypeGroup>[diaType],
          initialDirectory: initialDir,
        );
        targetPath = target?.path;
        if (!hadConfiguredDir &&
            targetPath != null &&
            targetPath.trim().isNotEmpty) {
          final String selectedDir = File(targetPath).parent.path.trim();
          if (selectedDir.isNotEmpty) {
            final Directory selectedDirectory = Directory(selectedDir);
            if (await selectedDirectory.exists()) {
              await controller.applySettings(
                controller.settings.copyWith(diaExportPath: selectedDir),
              );
            }
          }
        }
      } on UnimplementedError {
        nativeSaveDialogAvailable = false;
      }

      if (!nativeSaveDialogAvailable) {
        final _DiaSaveTarget? chosenTarget = await _askDiaSaveTarget(
          initialName: defaultBaseName,
          initialDirectory: initialDir ?? '',
        );
        if (chosenTarget == null) {
          return;
        }
        final String fileBaseName = _normalizeDiaBaseName(
          chosenTarget.fileName,
          fallback: defaultBaseName,
        );
        final String targetDir = chosenTarget.directoryPath.trim();
        if (targetDir.isEmpty) {
          return;
        }
        final Directory exportDir = Directory(targetDir);
        if (!await exportDir.exists()) {
          return;
        }
        if (!hadConfiguredDir) {
          await controller.applySettings(
            controller.settings.copyWith(diaExportPath: exportDir.path),
          );
        }
        targetPath =
            '${exportDir.path}${Platform.pathSeparator}$fileBaseName.dia';
      }

      if (targetPath == null || targetPath.trim().isEmpty) {
        return;
      }

      final String outPath = await controller.exportCustomOrderToDia(
        targetPath,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.savedPath(formatFriendlyPathLabel(outPath, l10n))),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.statusLoadError('$e'))));
    }
  }

  String _normalizeDiaBaseName(String raw, {required String fallback}) {
    final String trimmed = raw.trim();
    final String cleaned = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String base = cleaned.isEmpty ? fallback : cleaned;
    final String normalized = base.toLowerCase().endsWith('.dia')
        ? base.substring(0, base.length - 4)
        : base;
    return normalized.trim().isEmpty ? fallback : normalized;
  }

  Future<_DiaSaveTarget?> _askDiaSaveTarget({
    required String initialName,
    required String initialDirectory,
  }) async {
    final _DiaSaveTarget? result = await showDialog<_DiaSaveTarget>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _DiaSaveDialog(
          initialName: initialName,
          initialDirectory: initialDirectory,
        );
      },
    );
    return result;
  }

  Future<void> _importDia() async {
    final XTypeGroup diaType = XTypeGroup(
      label: context.l10n.diatarPlaylistFileTypeLabel,
      extensions: <String>['dia'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[diaType],
    );
    if (file == null) {
      return;
    }
    final int count = await controller.importCustomOrderFromDia(
      file.path,
      activate: true,
      sourceFileName: file.name,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.loadedCount(count))));
  }

  Widget _buildCurrentOrderList() {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          context.l10n.customOrderEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
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
          onTap: () => unawaited(
            controller.projectCustomOrderEntry(entry, preferredCursor: index),
          ),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isSongEntry && !isContinuation)
                IconButton(
                  tooltip: context.l10n.versePicker,
                  icon: const Icon(Icons.format_list_numbered),
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () => _pickVerse(index),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
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
    final List<CustomOrderEntry> groupEntries = _entries.sublist(
      group.start,
      group.end + 1,
    );
    final CustomOrderEntry base = groupEntries.first;
    final List<DtxVerse> verses = controller.versesForEntry(base);
    if (verses.isEmpty) {
      return;
    }
    if (verses.length == 1) {
      final CustomOrderEntry onlyVerseEntry = controller.normalizeEntry(
        base.copyWith(
          verseIndex: 0,
          label: controller.buildEntryLabel(base.fileName, base.songIndex, 0),
        ),
      );
      final String normalizedSignature = _entrySignature(onlyVerseEntry);
      final bool alreadySame = groupEntries.every(
        (CustomOrderEntry e) => _entrySignature(e) == normalizedSignature,
      );
      if (alreadySame) {
        return;
      }

      setState(() {
        _entries.removeRange(group.start, group.end + 1);
        _entries.insert(group.start, onlyVerseEntry);
      });
      await _commitEntries();
      return;
    }

    final Set<int> selectedSet = groupEntries
        .map((CustomOrderEntry e) => _safeEntryVerseIndex(e))
        .toSet();
    if (selectedSet.isEmpty) {
      selectedSet.add(0);
    }
    final List<int> originalSelection = selectedSet.toList()..sort();
    final List<int>? selectedMany = await _showVerseSelectionSheet(
      verses: verses,
      initialSelection: selectedSet,
      title: context.l10n.selectedVersesTitle,
      subtitle: context.l10n.selectedVersesSubtitle,
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
                label: controller.buildEntryLabel(
                  base.fileName,
                  base.songIndex,
                  v,
                ),
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
  const CustomOrderEditorSheet({super.key, required this.controller});

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
    required this.bookDisplayTitle,
    required this.bookSortTitle,
    required this.bookSearchText,
    required this.bookGroup,
    required this.songIndex,
    required this.songTitle,
  });

  final String fileName;
  final String bookDisplayTitle;
  final String bookSortTitle;
  final String bookSearchText;
  final String bookGroup;
  final int songIndex;
  final String songTitle;
}

class _SongOption {
  const _SongOption({required this.songIndex, required this.songTitle});

  final int songIndex;
  final String songTitle;
}

class _InsertBookDropdownEntry {
  const _InsertBookDropdownEntry.header(this.group)
    : fileName = null,
      title = null;

  const _InsertBookDropdownEntry.book({
    required this.fileName,
    required this.title,
  }) : group = null;

  final String? group;
  final String? fileName;
  final String? title;

  bool get isHeader => group != null;
}

class _DiaSaveTarget {
  const _DiaSaveTarget({required this.fileName, required this.directoryPath});

  final String fileName;
  final String directoryPath;
}

class _TextSlideInput {
  const _TextSlideInput({required this.title, required this.body});

  final String title;
  final String body;
}

class _CustomTextSlideDialog extends StatefulWidget {
  const _CustomTextSlideDialog();

  @override
  State<_CustomTextSlideDialog> createState() => _CustomTextSlideDialogState();
}

class _CustomTextSlideDialogState extends State<_CustomTextSlideDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.textSlideDialogTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.textSlideTitleLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(labelText: l10n.textSlideBodyLabel),
              minLines: 4,
              maxLines: 8,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _TextSlideInput(
                title: _titleController.text,
                body: _bodyController.text,
              ),
            );
          },
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}

class _DiaSaveDialog extends StatefulWidget {
  const _DiaSaveDialog({
    required this.initialName,
    required this.initialDirectory,
  });

  final String initialName;
  final String initialDirectory;

  @override
  State<_DiaSaveDialog> createState() => _DiaSaveDialogState();
}

class _DiaSaveDialogState extends State<_DiaSaveDialog> {
  late final TextEditingController _fileNameController;
  late String _directoryPath;

  bool _isValidExistingDirectory(String rawPath) {
    final String path = rawPath.trim();
    if (path.isEmpty) {
      return false;
    }
    try {
      return Directory(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(text: widget.initialName);
    _directoryPath = widget.initialDirectory.trim();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  _DiaSaveTarget? _buildTargetOrNull() {
    final String fileName = _fileNameController.text.trim();
    final String directoryPath = _directoryPath.trim();
    if (fileName.isEmpty || !_isValidExistingDirectory(directoryPath)) {
      return null;
    }
    return _DiaSaveTarget(fileName: fileName, directoryPath: directoryPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String friendlyDirectory = _directoryPath.trim().isEmpty
        ? l10n.valueNotSet
        : formatFriendlyPathLabel(_directoryPath.trim(), l10n);
    final bool canSave =
        _fileNameController.text.trim().isNotEmpty &&
        _isValidExistingDirectory(_directoryPath);

    return AlertDialog(
      title: Text(l10n.saveDia),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _fileNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.customOrderDiaFileNameLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                final _DiaSaveTarget? target = _buildTargetOrNull();
                if (target != null) {
                  Navigator.of(context).pop(target);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>(
                      'friendly_dir_${_directoryPath.trim()}',
                    ),
                    initialValue: friendlyDirectory,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.diaExportFolderPath,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.copyPathTooltip,
                  onPressed: _directoryPath.trim().isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _directoryPath.trim()),
                          );
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.pathCopied)),
                          );
                        },
                  icon: const Icon(Icons.content_copy),
                ),
                IconButton(
                  tooltip: l10n.fileChoose,
                  onPressed: () async {
                    final String? folderPath = await getDirectoryPath();
                    if (folderPath == null || !mounted) {
                      return;
                    }
                    setState(() {
                      _directoryPath = folderPath;
                    });
                  },
                  icon: const Icon(Icons.folder_open),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: !canSave
              ? null
              : () {
                  final _DiaSaveTarget? target = _buildTargetOrNull();
                  if (target != null) {
                    Navigator.of(context).pop(target);
                  }
                },
          child: Text(l10n.saveDia),
        ),
      ],
    );
  }
}
