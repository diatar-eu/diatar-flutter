import 'dart:async';
import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
                      tooltip: l10n.addImageSlideTooltip,
                      onPressed: _pickAndSendImageSlide,
                      icon: const Icon(Icons.image),
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
                          items: books
                              .map(
                                (DtxBook book) => DropdownMenuItem<String>(
                                  value: book.fileName,
                                  child: Text(
                                    book.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton.icon(
                      onPressed: selectedSongIndex == null
                          ? null
                          : () async {
                              Navigator.of(dialogContext).pop();
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
    final TextEditingController searchController = TextEditingController();
    String query = '';

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
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
                              candidate.bookTitle.toLowerCase().contains(
                                filter,
                              ) ||
                              candidate.songTitle.toLowerCase().contains(
                                filter,
                              ),
                        )
                        .toList()
                      ..sort((_SearchCandidate a, _SearchCandidate b) {
                        final int byBook = a.bookTitle.toLowerCase().compareTo(
                          b.bookTitle.toLowerCase(),
                        );
                        return byBook != 0
                            ? byBook
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
                          controller: searchController,
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
                                          subtitle: Text(hit.bookTitle),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            onPressed: () async {
                                              Navigator.of(dialogContext).pop();
                                              await _insertSearchCandidate(hit);
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(l10n.close),
                    ),
                  ],
                );
              },
        );
      },
    );

    searchController.dispose();
  }

  List<_SearchCandidate> _collectSearchCandidates() {
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
    if (controller.customOrderCursor < 0) {
      return _entries.length;
    }
    return controller.customOrderCursor.clamp(0, _entries.length);
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
      final String defaultBaseName = _normalizeDiaBaseName(
        controller.lastImportedCustomOrderBaseName ??
            l10n.customOrderSuggestedFileName,
        fallback: 'sorrend',
      );
      final String defaultFileName = '$defaultBaseName.dia';
      final String configuredDir = controller.settings.diaExportPath.trim();
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
      } on UnimplementedError {
        nativeSaveDialogAvailable = false;
      }

      if (!nativeSaveDialogAvailable) {
        final String baseDir = await _resolveDiaExportDirectory();
        final String? chosenName = await _askDiaFileName(defaultBaseName);
        if (chosenName == null) {
          return;
        }
        final String fileBaseName = _normalizeDiaBaseName(
          chosenName,
          fallback: defaultBaseName,
        );
        targetPath = '$baseDir${Platform.pathSeparator}$fileBaseName.dia';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.savedPath(outPath))));
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

  Future<String?> _askDiaFileName(String initialName) async {
    String enteredName = initialName;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.saveDia),
          content: TextFormField(
            initialValue: initialName,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'sorrend'),
            onChanged: (String value) => enteredName = value,
            onFieldSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(enteredName),
              child: Text(l10n.saveDia),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<String> _resolveDiaExportDirectory() async {
    final String configured = controller.settings.diaExportPath.trim();
    if (configured.isNotEmpty) {
      final Directory dir = Directory(configured);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    }

    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory exportDir = Directory(
      '${docs.path}${Platform.pathSeparator}dia',
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
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
    required this.bookTitle,
    required this.songIndex,
    required this.songTitle,
  });

  final String fileName;
  final String bookTitle;
  final int songIndex;
  final String songTitle;
}

class _SongOption {
  const _SongOption({required this.songIndex, required this.songTitle});

  final int songIndex;
  final String songTitle;
}
