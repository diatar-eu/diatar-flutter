import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../controllers/diatar_main_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/custom_order_set.dart';
import '../utils/custom_entry_labels.dart';
import '../utils/escape_sequences.dart';
import '../utils/friendly_path.dart';
import '../services/song_search_service.dart';
import '../services/zsolozsma_service.dart';
import '../services/napi_lelki_batyu_service.dart';
import 'song_search_sheet.dart';

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
  static const MethodChannel _androidDiaSaveChannel = MethodChannel(
    'diatar.eu/dia_save',
  );

  late List<CustomOrderEntry> _entries;
  String? _selectedInsertBookFileName;
  int? _selectedInsertSongIndex;
  bool _groupReorder = true;

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

  String _normalizeSlashSpacing(String text) {
    return text.replaceAll(RegExp(r'\s*/\s*'), '/');
  }

  ({String prefix, String suffix})? _splitSlashLabel(String label) {
    final int slashIndex = label.indexOf('/');
    if (slashIndex <= 0 || slashIndex >= label.length - 1) {
      return null;
    }
    final String prefix = label.substring(0, slashIndex).trim();
    final String suffix = label.substring(slashIndex + 1).trim();
    if (prefix.isEmpty || suffix.isEmpty) {
      return null;
    }
    return (prefix: prefix, suffix: suffix);
  }

  /// Whether a non-song (custom text) entry continues the same logical item as
  /// the previous entry, i.e. they share the same label prefix before a '/'.
  ///
  /// This mirrors the grouping used by the dialista (slide list) view so that
  /// zsolozsma and napi lelki batyu verses are shown subdivided under one item
  /// instead of as separate songs.
  bool _isCustomTextContinuation(
    AppLocalizations l10n,
    int index,
    CustomOrderEntry entry,
  ) {
    if (index <= 0) {
      return false;
    }
    final CustomOrderEntry previous = _entries[index - 1];
    if (previous.isSeparator) {
      return false;
    }
    final String label = localizedCustomEntryLabel(l10n, entry);
    final ({String prefix, String suffix})? split = _splitSlashLabel(label);
    if (split == null) {
      return false;
    }
    final String previousLabel = localizedCustomEntryLabel(l10n, previous);
    final ({String prefix, String suffix})? previousSplit =
        _splitSlashLabel(previousLabel);
    if (previousSplit == null || previousSplit.prefix != split.prefix) {
      return false;
    }
    return true;
  }

  /// Builds the title for a continuation entry: the shared prefix is rendered
  /// transparent (so the verse suffix aligns under the parent item) and only
  /// the '/suffix' part is visible, matching the dialista view.
  Widget _buildContinuationTitle({
    required String prefix,
    required String suffix,
    required String firstLine,
  }) {
    final List<InlineSpan> spans = <InlineSpan>[
      TextSpan(text: prefix, style: const TextStyle(color: Colors.transparent)),
      TextSpan(text: '/$suffix'),
    ];
    if (firstLine.trim().isNotEmpty) {
      spans.add(
        TextSpan(
          text: ' ($firstLine)',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(height: 0.95),
    );
  }

  Widget _buildTitleWithFirstLine({
    required String title,
    required String firstLine,
  }) {
    final List<InlineSpan> spans = <InlineSpan>[TextSpan(text: title)];
    if (firstLine.trim().isNotEmpty) {
      spans.add(const TextSpan(text: ' '));
      spans.add(
        TextSpan(
          text: '($firstLine)',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(height: 0.95),
    );
  }

  DiatarMainController get controller => widget.controller;

  String _entrySignature(CustomOrderEntry entry) {
    return '${entry.fileName}|${entry.songIndex}|${entry.verseIndex}|${entry.customTextTitle ?? ''}|${entry.customTextBody ?? ''}|${entry.customImagePath ?? ''}|${entry.customType ?? ''}|${jsonEncode(entry.customData)}|${entry.label}';
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
    final String ungroupedLabel = context.l10n.ungroupedBookGroupLabel;
    String? lastGroup;
    for (final DtxBook book in books) {
      final String rawGroup = book.group.trim();
      final String displayGroup = rawGroup.isEmpty ? ungroupedLabel : rawGroup;
      if (displayGroup != lastGroup) {
        entries.add(_InsertBookDropdownEntry.header(displayGroup));
        lastGroup = displayGroup;
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
                      onPressed: () => _openSearchSheet(context),
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
                    IconButton(
                      tooltip: l10n.zsolozsmaTooltip,
                      onPressed: _openZsolozsmaDialog,
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                    IconButton(
                      tooltip: l10n.batyuTooltip,
                      onPressed: _openBatyuDialog,
                      icon: const Icon(Icons.auto_stories_outlined),
                    ),
                    IconButton(
                      tooltip: l10n.customOrderClearAllTooltip,
                      onPressed: _entries.isEmpty ? null : _confirmAndClearAll,
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        isDense: true,
                        initialValue: controller.activeCustomOrderSetId,
                        decoration: InputDecoration(
                          labelText: l10n.customOrderSetSelectorLabel,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: controller.customOrderSets
                            .map(
                              (CustomOrderSet set) => DropdownMenuItem<String>(
                                value: set.id,
                                child: Text(
                                  set.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: set.enabled
                                      ? null
                                      : const TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          unawaited(_switchEditingSet(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l10n.customOrderSetToggleEnabledTooltip,
                      icon: Icon(
                        _currentSetEnabled
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: controller.customOrderSets.length > 1
                          ? _toggleCurrentSetEnabled
                          : null,
                    ),
                    IconButton(
                      tooltip: l10n.customOrderSetRemove,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: controller.customOrderSets.length > 1
                          ? _confirmRemoveCurrentSet
                          : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: <Widget>[
                    Text(l10n.customOrderGroupReorder),
                    const SizedBox(width: 8),
                    Switch(
                      value: _groupReorder,
                      onChanged: (bool value) {
                        setState(() => _groupReorder = value);
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
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

    int lastInsertedIndex = 0;
    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insertAll(insertIndex, toInsert);
      lastInsertedIndex = insertIndex + toInsert.length - 1;
    });
    await _commitEntries();
    if (mounted) {
      controller.selectCustomOrderEntryForEditing(lastInsertedIndex);
    }
  }

  void _openSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SongSearchSheet(
        controller: controller,
        onSelected: (result) {
          _insertSearchResult(result);
        },
      ),
    );
  }

  Future<void> _insertSearchResult(SongSearchResult result) async {
    final CustomOrderEntry baseEntry = CustomOrderEntry(
      fileName: controller.books[result.bookIndex].fileName,
      songIndex: result.songIndex,
      verseIndex: 0,
      label: controller.buildEntryLabel(
        controller.books[result.bookIndex].fileName,
        result.songIndex,
        0,
      ),
    );
    final List<DtxVerse> verses = controller.versesForEntry(baseEntry);
    final List<CustomOrderEntry> toInsert = verses.isEmpty
        ? <CustomOrderEntry>[baseEntry]
        : List<CustomOrderEntry>.generate(
            verses.length,
            (int verseIx) => CustomOrderEntry(
              fileName: controller.books[result.bookIndex].fileName,
              songIndex: result.songIndex,
              verseIndex: verseIx,
              label: controller.buildEntryLabel(
                controller.books[result.bookIndex].fileName,
                result.songIndex,
                verseIx,
              ),
            ),
          );

    int insertedCount = 0;
    int insertedStartIndex = 0;
    setState(() {
      insertedStartIndex = _selectedInsertInsertionIndex();
      _entries.insertAll(insertedStartIndex, toInsert);
      insertedCount = toInsert.length;
    });
    await _commitEntries();
    if (mounted && insertedCount > 0) {
      controller.selectCustomOrderEntryForEditing(
        insertedStartIndex + insertedCount - 1,
      );
    }
  }


  Future<void> _pickAndSendImageSlide() async {
    final AppLocalizations l10n = context.l10n;
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
      label: formatCustomImageEntryLabel(l10n, fileName),
      customImagePath: file.path,
    );

    int lastInsertedIndex = 0;
    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insert(insertIndex, entry);
      lastInsertedIndex = insertIndex;
    });
    await _commitEntries();
    if (mounted) {
      controller.selectCustomOrderEntryForEditing(lastInsertedIndex);
    }
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
      label: formatCustomTextEntryLabel(context.l10n, effectiveTitle),
      customTextTitle: effectiveTitle,
      customTextBody: lines.join('\n'),
    );

    int lastInsertedIndex = 0;
    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insert(insertIndex, entry);
      lastInsertedIndex = insertIndex;
    });
    await _commitEntries();
    if (mounted) {
      controller.selectCustomOrderEntryForEditing(lastInsertedIndex);
    }
  }

  Future<void> _openZsolozsmaDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _ZsolozsmaDialog(controller: controller);
      },
    );
  }

  Future<void> _openBatyuDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _BatyuDialog(controller: controller);
      },
    );
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

    int lastInsertedIndex = 0;
    setState(() {
      final int insertIndex = _selectedInsertInsertionIndex();
      _entries.insert(insertIndex, entry);
      lastInsertedIndex = insertIndex;
    });
    await _commitEntries();
    if (mounted) {
      controller.selectCustomOrderEntryForEditing(lastInsertedIndex);
    }
  }

  Future<void> _confirmAndClearAll() async {
    if (_entries.isEmpty) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final dialogL10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(dialogL10n.customOrderClearAllConfirmTitle),
          content: Text(dialogL10n.customOrderClearAllConfirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogL10n.customOrderClearAllConfirmButton),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _entries = <CustomOrderEntry>[];
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
                              title: _buildTitleWithFirstLine(
                                title: verses[i].name,
                                firstLine: firstMeaningfulLine(
                                  verses[i].lines,
                                ),
                              ),
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
    await controller.applyCustomOrder(
      _entries,
      activate: true,
      syncProjection: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
    });
  }

  /// Az éppen aktív (szerkesztett) énekrend engedélyezve van-e.
  bool get _currentSetEnabled {
    final int index = controller.activeCustomOrderSetIndex;
    if (index < 0 || index >= controller.customOrderSets.length) {
      return true;
    }
    return controller.customOrderSets[index].enabled;
  }

  /// Elmenti az éppen szerkesztett énekrendet, majd átvált a megadott
  /// azonosítójú énekrendre, hogy azt lehessen szerkeszteni. Ha a cél
  /// énekrend le van tiltva, előbb engedélyezi, hogy szerkeszthető legyen.
  Future<void> _switchEditingSet(String id) async {
    await _commitEntries();
    if (!mounted) {
      return;
    }
    final int index = controller.customOrderSets.indexWhere(
      (CustomOrderSet s) => s.id == id,
    );
    if (index >= 0 && !controller.customOrderSets[index].enabled) {
      await controller.toggleCustomOrderSetEnabled(index);
      if (!mounted) {
        return;
      }
    }
    await controller.setActiveCustomOrderSetById(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
    });
  }

  /// Be-/kikapcsolja az éppen aktív énekrendet. A kikapcsolt énekrend nem
  /// jelenik meg a nézetekben, de megmarad (újra kiválasztható a listából).
  Future<void> _toggleCurrentSetEnabled() async {
    final int index = controller.activeCustomOrderSetIndex;
    if (index < 0) {
      return;
    }
    await controller.toggleCustomOrderSetEnabled(index);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
    });
  }

  /// Megerősítés után eltávolítja az éppen aktív énekrendet a betöltöttek közül.
  Future<void> _confirmRemoveCurrentSet() async {
    final int index = controller.activeCustomOrderSetIndex;
    if (index < 0) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.customOrderSetRemove),
          content: Text(l10n.customOrderSetRemoveConfirm),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.customOrderSetRemove),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await controller.removeCustomOrderSet(index);
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
        controller.suggestedCustomOrderBaseName ?? fallbackBaseName,
        fallback: 'sorrend',
      );
      final String defaultFileName = '$defaultBaseName.dia';
      final String configuredDir = controller.settings.diaExportPath.trim();
      final String? initialDir = configuredDir.isNotEmpty
          ? _existingDirectoryPathOrNull(configuredDir)
          : null;
      final bool hadUsableConfiguredDir = initialDir != null;

      try {
        final XFile? file = await openFile(
          acceptedTypeGroups: <XTypeGroup>[diaType],
          initialDirectory: initialDir,
        );
        if (file != null) {
          targetPath = file.path;
          if (!hadUsableConfiguredDir) {
            final String selectedDir = path.dirname(file.path).trim();
            final String? existingSelectedDir = _existingDirectoryPathOrNull(
              selectedDir,
            );
            if (existingSelectedDir != null) {
              await controller.applySettings(
                controller.settings.copyWith(diaExportPath: existingSelectedDir),
              );
            }
          }
        }
      } catch (e) {
        nativeSaveDialogAvailable = false;
      }

      if (!nativeSaveDialogAvailable) {
        if (!kIsWeb && Platform.isAndroid) {
          final String? savedPath = await _saveDiaWithAndroidSystemDialog(
            defaultFileName: defaultFileName,
          );
          if (savedPath == null || !mounted) {
            return;
          }
          await controller.markCustomOrderDiaExportSaved(savedPath);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.savedPath(formatFriendlyPathLabel(savedPath, l10n)),
              ),
            ),
          );
          return;
        }

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
        if (!hadUsableConfiguredDir) {
          await controller.applySettings(
            controller.settings.copyWith(diaExportPath: exportDir.path),
          );
        }
        targetPath =
            '${exportDir.path}/$fileBaseName.dia';
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
      await _showDiaSaveErrorDialog(e);
    }
  }

  Future<String?> _saveDiaWithAndroidSystemDialog({
    required String defaultFileName,
  }) async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'diatar_dia_export_',
    );
    try {
      final String tempPath =
          '${tempDir.path}/$defaultFileName';
      final String exportedTempPath = await controller.exportCustomOrderToDia(
        tempPath,
      );
      final Uint8List data = await File(exportedTempPath).readAsBytes();
      return _androidDiaSaveChannel.invokeMethod<String>(
        'saveDiaFile',
        <String, Object?>{'fileName': defaultFileName, 'bytes': data},
      );
    } finally {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {
        // Ignore temp cleanup failures.
      }
    }
  }

  Future<void> _showDiaSaveErrorDialog(Object error) async {
    if (!mounted) {
      return;
    }
    final l10n = context.l10n;
    final String details = _formatDiaSaveErrorDetails(error, l10n);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.customOrderSaveDiaErrorTitle),
          content: Text(details),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  String _formatDiaSaveErrorDetails(Object error, AppLocalizations l10n) {
    final String raw = '$error';
    final String lowered = raw.toLowerCase();
    final bool permissionLikeError =
        error is FileSystemException &&
        (error.osError?.errorCode == 13 ||
            lowered.contains('permission denied') ||
            lowered.contains('operation not permitted') ||
            lowered.contains('eacces') ||
            lowered.contains('eperm'));
    if (!kIsWeb && Platform.isAndroid && permissionLikeError) {
      return l10n.customOrderSaveDiaPermissionDenied;
    }
    return l10n.customOrderSaveDiaGenericError(raw);
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

  String? _existingDirectoryPathOrNull(String rawPath) {
    final String trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final Directory directory = Directory(trimmed);
    if (!directory.existsSync()) {
      return null;
    }
    return directory.path;
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

  Future<CustomOrderImportMode?> _askImportMode() async {
    final AppLocalizations l10n = context.l10n;
    return showDialog<CustomOrderImportMode>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.customOrderLoadModeTitle),
          content: Text(l10n.customOrderLoadModeMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(CustomOrderImportMode.overwriteActive),
              child: Text(l10n.customOrderLoadModeOverwrite),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(CustomOrderImportMode.addNew),
              child: Text(l10n.customOrderLoadModeAdd),
            ),
          ],
        );
      },
    );
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
    final CustomOrderImportMode? mode = await _askImportMode();
    if (mode == null) {
      return;
    }
    final int count = await controller.importCustomOrderFromDia(
      file.path,
      activate: true,
      mode: mode,
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
          if (_groupReorder) {
            final ({int start, int end}) group =
                _contiguousGroupRange(oldIndex);
            final int groupStart = group.start;
            final int groupEnd = group.end;
            // Dropping inside the same group is a no-op.
            if (newIndex > groupStart && newIndex <= groupEnd) {
              return;
            }
            final List<CustomOrderEntry> block = _entries.sublist(
              groupStart,
              groupEnd + 1,
            );
            _entries.removeRange(groupStart, groupEnd + 1);
            final int insertAt = newIndex > groupEnd
                ? newIndex - block.length
                : newIndex;
            _entries.insertAll(insertAt, block);
          } else {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final CustomOrderEntry entry = _entries.removeAt(oldIndex);
            _entries.insert(newIndex, entry);
          }
        });
        unawaited(_commitEntries());
      },
      itemBuilder: (BuildContext context, int index) {
        final CustomOrderEntry entry = _entries[index];
        final bool isSongEntry = controller.isSongOrderEntry(entry);
        final bool isContinuation = isSongEntry
            ? (index > 0 &&
                _entries[index - 1].fileName == entry.fileName &&
                _entries[index - 1].songIndex == entry.songIndex)
            : _isCustomTextContinuation(context.l10n, index, entry);
        final List<DtxVerse> verses = isSongEntry
            ? controller.versesForEntry(entry)
            : const <DtxVerse>[];
        final int verseIx = _safeEntryVerseIndex(entry);
        final String rawVerseLabel = verses.isEmpty
            ? '-'
            : verses[verseIx.clamp(0, verses.length - 1)].name;
        final String verseLabel = isSongEntry
            ? _normalizeSlashSpacing(rawVerseLabel)
            : rawVerseLabel;
        final String fullLabel = isSongEntry
            ? _normalizeSlashSpacing(entry.label)
            : localizedCustomEntryLabel(context.l10n, entry);
        final String firstLine = controller.firstTextLineForEntry(entry);
        final Widget titleWidget;
        if (isContinuation && isSongEntry) {
          titleWidget = _buildTitleWithFirstLine(
            title: verseLabel,
            firstLine: firstLine,
          );
        } else if (isContinuation) {
          final ({String prefix, String suffix}) split =
              _splitSlashLabel(fullLabel)!;
          titleWidget = _buildContinuationTitle(
            prefix: split.prefix,
            suffix: split.suffix,
            firstLine: firstLine,
          );
        } else {
          titleWidget = _buildTitleWithFirstLine(
            title: fullLabel,
            firstLine: firstLine,
          );
        }
        return ListTile(
          key: ValueKey<String>('${entry.fileName}_${entry.songIndex}_$index'),
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          minVerticalPadding: 0,
          minTileHeight: 30,
          selected: controller.isCustomOrderIndexCurrent(index),
          selectedTileColor: Colors.blue.withValues(alpha: 0.12),
          onTap: () => controller.selectCustomOrderEntryForEditing(index),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          contentPadding: EdgeInsets.only(
            left: isContinuation ? 70 : 16,
            right: 8,
          ),
          title: titleWidget,
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
    final List<int>? chosen = await _showVerseSelectionSheet(
      verses: verses,
      initialSelection: selectedSet,
      title: context.l10n.selectedVersesTitle,
      subtitle: context.l10n.selectedVersesSubtitle,
    );

    if (chosen == null || chosen.isEmpty) {
      return;
    }

    final List<int> normalized = chosen.toList()..sort();
    if (listEquals(normalized, originalSelection)) {
      return;
    }

    setState(() {
      final List<CustomOrderEntry> replacements = normalized
          .map(
            (int verseIx) => CustomOrderEntry(
              fileName: base.fileName,
              songIndex: base.songIndex,
              verseIndex: verseIx,
              label: controller.buildEntryLabel(
                base.fileName,
                base.songIndex,
                verseIx,
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

  /// Returns the inclusive range of entries that belong to the same logical
  /// item as the entry at [index]: a song with all its verses, or a zsolozsma /
  /// napi lelki batyu section with all its subdivided verses. Used so the whole
  /// group can be reordered as a single unit.
  ({int start, int end}) _contiguousGroupRange(int index) {
    final CustomOrderEntry center = _entries[index];
    if (controller.isSongOrderEntry(center)) {
      return _contiguousSongGroup(index);
    }
    if (center.isCustomText) {
      int start = index;
      while (start > 0 &&
          _entries[start - 1].isCustomText &&
          _isCustomTextContinuation(context.l10n, start, _entries[start])) {
        start--;
      }
      int end = index;
      while (end + 1 < _entries.length &&
          _entries[end + 1].isCustomText &&
          _isCustomTextContinuation(context.l10n, end + 1, _entries[end + 1])) {
        end++;
      }
      return (start: start, end: end);
    }
    return (start: index, end: index);
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

class _ZsolozsmaDialog extends StatefulWidget {
  const _ZsolozsmaDialog({required this.controller});

  final DiatarMainController controller;

  @override
  State<_ZsolozsmaDialog> createState() => _ZsolozsmaDialogState();
}

class _ZsolozsmaDialogState extends State<_ZsolozsmaDialog> {
  late DateTime _selectedDate;
  bool _loading = false;
  bool _syncing = false;
  String? _error;
  List<ZsolozsmaDayPart> _parts = const <ZsolozsmaDayPart>[];

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    unawaited(_load(syncArchives: true));
  }

  Future<void> _load({required bool syncArchives}) async {
    setState(() {
      _loading = true;
      _syncing = syncArchives;
      _error = null;
    });
    try {
      final List<ZsolozsmaDayPart> parts = await widget.controller
          .loadZsolozsmaDayParts(_selectedDate, syncArchives: syncArchives);
      if (!mounted) {
        return;
      }
      setState(() {
        _parts = parts;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parts = const <ZsolozsmaDayPart>[];
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _syncing = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _load(syncArchives: false);
  }

  String _dateLabel(DateTime date) {
    final String yy = date.year.toString().padLeft(4, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.zsolozsmaTitle),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('${l10n.zsolozsmaDateLabel}:'),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _pickDate,
                  child: Text(_dateLabel(_selectedDate)),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _loading ? null : () => _load(syncArchives: true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                  child: _syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!)
            else if (_parts.isEmpty)
              Text(l10n.zsolozsmaNoItems)
            else
              SizedBox(
                height: math.min(320, 72.0 * _parts.length),
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: _parts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ZsolozsmaDayPart part = _parts[index];
                    return ListTile(
                      dense: true,
                      title: Text(part.title),
                      onTap: () async {
                        final bool loaded = await widget.controller
                            .selectZsolozsmaPart(
                              _selectedDate,
                              part,
                              insertAtIndex:
                                  widget.controller.customOrderInsertionIndex,
                            );
                        if (loaded && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _BatyuDialog extends StatefulWidget {
  const _BatyuDialog({required this.controller});

  final DiatarMainController controller;

  @override
  State<_BatyuDialog> createState() => _BatyuDialogState();
}

class _BatyuDialogState extends State<_BatyuDialog> {
  late DateTime _selectedDate;
  bool _loading = false;
  String? _error;
  List<NapiLelkiBatyuCelebration> _celebrations =
      const <NapiLelkiBatyuCelebration>[];
  int _wordsPerSlide = 30;
  final TextEditingController _wordsPerSlideController =
      TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    unawaited(_load());
  }

  @override
  void dispose() {
    _wordsPerSlideController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<NapiLelkiBatyuCelebration> celebrations = await widget
          .controller
          .loadBatyuCelebrations(_selectedDate);
      if (!mounted) {
        return;
      }
      setState(() {
        _celebrations = celebrations;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _celebrations = const <NapiLelkiBatyuCelebration>[];
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _load();
  }

  String _dateLabel(DateTime date) {
    final String yy = date.year.toString().padLeft(4, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.batyuTitle),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('${l10n.batyuDateLabel}:'),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _pickDate,
                  child: Text(_dateLabel(_selectedDate)),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _loading ? null : _load,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.sync),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text('${l10n.batyuWordsPerSlide}:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: _wordsPerSlideController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (String value) {
                      final int? parsed = int.tryParse(value);
                      setState(() {
                        _wordsPerSlide = parsed == null || parsed < 1
                            ? 1
                            : parsed;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!)
            else if (_celebrations.isEmpty)
              Text(l10n.batyuNoItems)
            else
              SizedBox(
                height: math.min(320, 72.0 * _celebrations.length),
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: _celebrations.length,
                  itemBuilder: (BuildContext context, int index) {
                    final NapiLelkiBatyuCelebration celebration =
                        _celebrations[index];
                    return ListTile(
                      dense: true,
                      title: Text(celebration.title),
                      subtitle: celebration.subtitle?.trim().isNotEmpty == true
                          ? Text(celebration.subtitle!)
                          : null,
                      onTap: () async {
                        final bool loaded = await widget.controller
                            .importNapiLelkiBatyu(
                              _selectedDate,
                              celebration,
                              wordsPerSlide: _wordsPerSlide,
                              insertAtIndex:
                                  widget.controller.customOrderInsertionIndex,
                            );
                        if (loaded && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
