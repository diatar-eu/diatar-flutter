import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../controllers/diatar_main_controller.dart';
import '../l10n/l10n.dart';
import '../services/dtx_download_service.dart';
import '../services/zsolozsma_service.dart';
import '../utils/friendly_path.dart';
import 'settings_sheet.dart';
import 'custom_order_editor_sheet.dart';

class _BookDropdownEntry {
  const _BookDropdownEntry.header(this.group) : bookIndex = null, title = null;

  const _BookDropdownEntry.book({required this.bookIndex, required this.title})
    : group = null;

  final String? group;
  final int? bookIndex;
  final String? title;

  bool get isHeader => group != null;
}

class _DownloadListEntry {
  const _DownloadListEntry.header(this.group) : item = null;

  const _DownloadListEntry.item(this.item) : group = null;

  final String? group;
  final DtxDownloadItem? item;

  bool get isHeader => group != null;
}

class _DiaVerseEntry {
  const _DiaVerseEntry({required this.customOrderIndex, required this.label});

  final int customOrderIndex;
  final String label;
}

class _DiaSongGroup {
  const _DiaSongGroup({required this.label, required this.verses});

  final String label;
  final List<_DiaVerseEntry> verses;
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

const int _diaVirtualBookValue = -1000000;

String _basename(String path) {
  final String normalized = path.replaceAll('\\', '/');
  final List<String> parts = normalized
      .split('/')
      .where((String part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? normalized : parts.last;
}

String _cleanSeparatorLabel(CustomOrderEntry entry) {
  final String explicit = (entry.customTextTitle ?? '').trim();
  if (explicit.isNotEmpty) {
    return '-- $explicit --';
  }
  final String compact = entry.label
      .trim()
      .replaceAll(RegExp(r'^-+\s*'), '')
      .replaceAll(RegExp(r'\s*-+$'), '')
      .trim();
  return compact.isEmpty ? '--' : '-- $compact --';
}

String _songVerseToken(DtxVerse verse) {
  final String raw = verse.name.trim();
  if (raw.isEmpty || raw == '---') {
    return '';
  }
  final RegExpMatch? match = RegExp(r'^(\d+)').firstMatch(raw);
  if (match != null) {
    return match.group(1)!;
  }
  return raw;
}

String _entryShortLabel(
  DiatarMainController controller,
  CustomOrderEntry entry,
) {
  if (entry.isSeparator) {
    return _cleanSeparatorLabel(entry);
  }
  if (entry.isCustomImage) {
    return _basename(entry.customImagePath ?? entry.label);
  }
  if (entry.isCustomText) {
    final String title = (entry.customTextTitle ?? '').trim();
    return title.isEmpty ? entry.label : title;
  }
  final DtxSong? song = controller.songForEntry(entry);
  final List<DtxVerse> verses = controller.versesForEntry(entry);
  if (song == null || verses.isEmpty) {
    return entry.label;
  }
  final int safeVerse = entry.verseIndex.clamp(0, verses.length - 1);
  final String token = _songVerseToken(verses[safeVerse]);
  if (token.isNotEmpty) {
    return token;
  }
  final String fallback = verses[safeVerse].name.trim();
  return fallback.isEmpty ? '${safeVerse + 1}' : fallback;
}

List<_DiaSongGroup> _buildDiaSongGroups(DiatarMainController controller) {
  final List<CustomOrderEntry> custom = controller.customOrder;
  final List<_DiaSongGroup> groups = <_DiaSongGroup>[];
  int i = 0;

  while (i < custom.length) {
    final CustomOrderEntry first = custom[i];
    if (!first.isSongEntry) {
      final String firstLabel = _entryShortLabel(controller, first);
      final ({String prefix, String suffix})? firstSplit = _splitSlashLabel(
        firstLabel,
      );
      if (firstSplit == null) {
        groups.add(
          _DiaSongGroup(
            label: firstLabel,
            verses: <_DiaVerseEntry>[
              _DiaVerseEntry(customOrderIndex: i, label: firstLabel),
            ],
          ),
        );
        i++;
        continue;
      }

      final List<_DiaVerseEntry> verses = <_DiaVerseEntry>[];
      int j = i;
      while (j < custom.length) {
        final CustomOrderEntry candidate = custom[j];
        if (candidate.isSongEntry) {
          break;
        }
        final String candidateLabel = _entryShortLabel(controller, candidate);
        final ({String prefix, String suffix})? candidateSplit =
            _splitSlashLabel(candidateLabel);
        if (candidateSplit == null || candidateSplit.prefix != firstSplit.prefix) {
          break;
        }
        verses.add(
          _DiaVerseEntry(
            customOrderIndex: j,
            label: candidateSplit.suffix,
          ),
        );
        j++;
      }

      final String compactSuffix = verses
          .map((_DiaVerseEntry verse) => verse.label)
          .where((String label) => label.trim().isNotEmpty)
          .join(', ');
      final String groupLabel = compactSuffix.isEmpty
          ? firstLabel
          : '${firstSplit.prefix}/$compactSuffix';
      groups.add(_DiaSongGroup(label: groupLabel, verses: verses));
      i = j;
      continue;
    }

    final List<_DiaVerseEntry> verses = <_DiaVerseEntry>[];
    final DtxSong? song = controller.songForEntry(first);
    final DtxBook? book = controller.bookForEntry(first);
    int j = i;
    int lastVerse = first.verseIndex;

    while (j < custom.length) {
      final CustomOrderEntry candidate = custom[j];
      if (!candidate.isSongEntry ||
          candidate.fileName != first.fileName ||
          candidate.songIndex != first.songIndex) {
        break;
      }
      if (j != i && candidate.verseIndex != lastVerse + 1) {
        break;
      }
      verses.add(
        _DiaVerseEntry(
          customOrderIndex: j,
          label: _entryShortLabel(controller, candidate),
        ),
      );
      lastVerse = candidate.verseIndex;
      j++;
    }

    final String bookName = book?.displayName ?? first.fileName;
    final String songTitle = song?.title ?? first.label;
    final List<String> tokens = verses
        .map((_DiaVerseEntry v) => v.label.trim())
        .where((String v) => v.isNotEmpty)
        .toList();
    final String suffix = tokens.isEmpty
        ? songTitle
        : '$songTitle/${tokens.join(', ')}';
    groups.add(_DiaSongGroup(label: '$bookName: $suffix', verses: verses));
    i = j;
  }

  return groups;
}

int _selectedDiaSongGroupIndex(
  List<_DiaSongGroup> groups,
  int selectedCustomOrderCursor,
) {
  final int idx = groups.indexWhere(
    (_DiaSongGroup g) => g.verses.any(
      (_DiaVerseEntry v) => v.customOrderIndex == selectedCustomOrderCursor,
    ),
  );
  return idx >= 0 ? idx : 0;
}

List<_BookDropdownEntry> _buildBookDropdownEntries(List<DtxBook> books) {
  final List<_BookDropdownEntry> entries = <_BookDropdownEntry>[];
  String? lastGroup;
  for (int index = 0; index < books.length; index++) {
    final DtxBook book = books[index];
    final String group = book.group.trim();
    if (group.isNotEmpty && group != lastGroup) {
      entries.add(_BookDropdownEntry.header(group));
      lastGroup = group;
    }
    if (group.isEmpty) {
      lastGroup = null;
    }
    entries.add(_BookDropdownEntry.book(bookIndex: index, title: book.title));
  }
  return entries;
}

List<_DownloadListEntry> _buildDownloadListEntries(List<DtxDownloadItem> items) {
  final List<_DownloadListEntry> entries = <_DownloadListEntry>[];
  String? lastGroup;
  for (final DtxDownloadItem item in items) {
    final String group = item.group.trim();
    if (group.isNotEmpty && group != lastGroup) {
      entries.add(_DownloadListEntry.header(group));
      lastGroup = group;
    }
    if (group.isEmpty) {
      lastGroup = null;
    }
    entries.add(_DownloadListEntry.item(item));
  }
  return entries;
}

class DiatarHomePage extends StatelessWidget {
  const DiatarHomePage({super.key, required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.settingsTooltip,
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: l10n.customOrderTooltip,
            onPressed: () => _openCustomOrderEditor(context),
            icon: const Icon(Icons.queue_music),
          ),
          IconButton(
            tooltip: l10n.zsolozsmaTooltip,
            onPressed: () => _openZsolozsmaDialog(context),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: l10n.downloadBooksTooltip,
            onPressed: () => _openDownloadDialog(context),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            tooltip: l10n.refreshTooltip,
            onPressed: controller.reloadBooks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          if (controller.shouldAutoOpenDownloadDialog) {
            controller.markStartupDownloadDialogHandled();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              unawaited(_openDownloadDialog(context));
            });
          }

          final MediaQueryData mq = MediaQuery.of(context);
          final int screenW = (mq.size.width * mq.devicePixelRatio).round();
          final int screenH = (mq.size.height * mq.devicePixelRatio).round();
          unawaited(
            controller.updateScreenSize(width: screenW, height: screenH),
          );

          return _buildSimpleView(context);
        },
      ),
    );
  }

  Widget _buildSimpleView(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool isLandscape = mq.orientation == Orientation.landscape;

    if (isLandscape) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double minPreviewWidth = 320.0;
          const double minControlsWidth = 300.0;
          const double preferredControlsWidth = 460.0;
          // 9 circle buttons (with lock toggle) + 8 gaps + side paddings.
          const double controlsRowMinWidthForButtons = 538.0;

          final double maxControlsWidth = math.max(
            minControlsWidth,
            constraints.maxWidth - minPreviewWidth - 1,
          );

          double controlsWidth = (constraints.maxWidth * 0.38).clamp(
            minControlsWidth,
            preferredControlsWidth,
          );

          if (maxControlsWidth >= controlsRowMinWidthForButtons &&
              controlsWidth < controlsRowMinWidthForButtons) {
            controlsWidth = controlsRowMinWidthForButtons;
          }

          controlsWidth = controlsWidth.clamp(
            minControlsWidth,
            maxControlsWidth,
          );

          return Row(
            children: <Widget>[
              SizedBox(
                width: controlsWidth,
                child: Column(
                  children: <Widget>[
                    if (controller.loading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: _buildSimpleControls(context),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildSimplePreviewPane(context)),
            ],
          );
        },
      );
    }

    return Column(
      children: <Widget>[
        if (controller.loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildSimpleControls(context),
        ),
        const Divider(height: 1),
        Expanded(child: _buildSimplePreviewPane(context)),
      ],
    );
  }

  Widget _buildSimpleControls(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: <Widget>[
        _BookDropdown(controller: controller),
        const SizedBox(height: 8),
        _SongDropdown(controller: controller),
        const SizedBox(height: 8),
        _VerseDropdown(controller: controller),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _actionIconButton(
                context,
                icon: Icons.keyboard_double_arrow_left,
                tooltip: l10n.songPrev,
                onPressed: controller.prevSong,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                icon: Icons.chevron_left,
                tooltip: l10n.previous,
                onPressed: controller.prevVerse,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                icon: controller.showing ? Icons.cast_connected : Icons.cast,
                tooltip: controller.showing
                    ? l10n.projectionOff
                    : l10n.projectionOn,
                onPressed: controller.toggleShowing,
                backgroundColor: controller.showing
                    ? const Color(0xFFD32F2F).withValues(alpha: 0.15)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                foregroundColor: controller.showing
                    ? const Color(0xFFD32F2F)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                icon: controller.settings.projectionLocked
                    ? Icons.lock
                    : Icons.lock_open,
                tooltip: controller.settings.projectionLocked
                    ? l10n.projectionUnlock
                    : l10n.projectionLock,
                onPressed: () => unawaited(controller.toggleProjectionLock()),
                backgroundColor: controller.settings.projectionLocked
                    ? const Color(0xFFF9A825).withValues(alpha: 0.15)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                foregroundColor: controller.settings.projectionLocked
                    ? const Color(0xFFF9A825)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                icon: Icons.chevron_right,
                tooltip: l10n.next,
                onPressed: controller.nextVerse,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                icon: Icons.keyboard_double_arrow_right,
                tooltip: l10n.songNext,
                onPressed: controller.nextSong,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                child: const Text(
                  '\u2796',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                tooltip: l10n.highlightPrev,
                onPressed: controller.highlightPrev,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                context,
                child: const Text(
                  '\u2795',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                tooltip: l10n.highlightNext,
                onPressed: controller.highlightNext,
              ),
            ],
          ),
        ),
        if (controller.downloadInProgress) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: controller.downloadCurrentFraction),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.downloadProgress(
                controller.downloadCurrentFile,
                controller.downloadTotalFiles,
                controller.downloadCurrentName,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSimplePreviewPane(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      color: controller.globals.bkColor,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget preview = _buildActivePreview(
            context,
            panelTitle: l10n.previewTitle,
          );
          final bool scrollableProjection = !controller.settings.projAutoSize;
          if (scrollableProjection) {
            return SingleChildScrollView(child: preview);
          }
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: preview,
          );
        },
      ),
    );
  }

  Widget _buildActivePreview(
    BuildContext context, {
    required String panelTitle,
  }) {
    final CustomOrderEntry? projectedCustom =
        controller.projectedCustomOrderEntry;
    if (projectedCustom != null && projectedCustom.isCustomText) {
      final String title =
          (projectedCustom.customTextTitle ?? '').trim().isEmpty
          ? projectedCustom.label
          : (projectedCustom.customTextTitle ?? '').trim();
      final List<String> lines = (projectedCustom.customTextBody ?? '')
          .split(RegExp(r'\r?\n'))
          .map((String line) => line.trimRight())
          .where((String line) => line.trim().isNotEmpty)
          .toList();
      return _CustomTextPreview(
        controller: controller,
        title: title,
        lines: lines,
      );
    }
    if (projectedCustom != null && projectedCustom.isCustomImage) {
      return _CustomImagePreview(
        controller: controller,
        imagePath: projectedCustom.customImagePath ?? '',
      );
    }

    final DtxSong? song = controller.currentSong;
    final DtxVerse? verse = controller.currentVerse;
    if (song == null || verse == null) {
      return Text(
        context.l10n.noLoadedSlide,
        style: TextStyle(color: controller.globals.txtColor),
      );
    }
    return _VersePreview(
      controller: controller,
      song: song,
      verse: verse,
      panelTitle: panelTitle,
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DiatarSettingsSheet(
          initialSettings: controller.settings,
          availableSongsLoader: () {
            final List<SongHotkeyOption> songOptions = <SongHotkeyOption>[];
            for (final DtxBook book in controller.books) {
              for (int songIdx = 0; songIdx < book.songs.length; songIdx++) {
                final DtxSong song = book.songs[songIdx];
                if (song.separator) {
                  continue;
                }
                songOptions.add(
                  SongHotkeyOption(
                    id: '${book.fileName}::$songIdx',
                    label: '${book.displayName} / ${song.title}',
                  ),
                );
              }
            }
            return songOptions;
          },
          onApply: (AppSettings settings) => controller.applySettings(settings),
          onExitRequested: controller.requestExit,
        );
      },
    );
  }

  Future<void> _openCustomOrderEditor(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return CustomOrderEditorSheet(controller: controller);
      },
    );
  }

  Future<void> _openDownloadDialog(BuildContext context) async {
    final List<DtxDownloadItem>? selected =
        await showDialog<List<DtxDownloadItem>>(
          context: context,
          builder: (BuildContext context) =>
              _DownloadSongbooksDialog(controller: controller),
        );
    if (selected == null || selected.isEmpty) {
      return;
    }
    unawaited(controller.downloadSongBooks(selected: selected));
  }

  Future<void> _openZsolozsmaDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _ZsolozsmaDialog(controller: controller);
      },
    );
  }
}

class _DownloadSongbooksDialog extends StatefulWidget {
  const _DownloadSongbooksDialog({required this.controller});

  final DiatarMainController controller;

  @override
  State<_DownloadSongbooksDialog> createState() =>
      _DownloadSongbooksDialogState();
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
                        final bool loaded = await widget.controller.selectZsolozsmaPart(
                          _selectedDate,
                          part,
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

class _DownloadSongbooksDialogState extends State<_DownloadSongbooksDialog> {
  late Future<List<DtxDownloadItem>> _candidatesFuture;
  final Set<String> _selectedFiles = <String>{};
  bool _selectionInitialized = false;

  @override
  void initState() {
    super.initState();
    _candidatesFuture = widget.controller.loadDownloadCandidates();
  }

  void _reload() {
    setState(() {
      _selectionInitialized = false;
      _selectedFiles.clear();
      _candidatesFuture = widget.controller.loadDownloadCandidates();
    });
  }

  List<DtxDownloadItem> _effectiveSelected(List<DtxDownloadItem> items) {
    if (!_selectionInitialized) {
      // Default behavior: before first interaction every candidate is selected.
      return items;
    }
    return items
        .where((DtxDownloadItem item) => _selectedFiles.contains(item.fileName))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(l10n.downloadTitle)),
          IconButton(
            tooltip: l10n.refreshTooltip,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<DtxDownloadItem>>(
          future: _candidatesFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<DtxDownloadItem>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(l10n.statusDownloadListLoading),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text(l10n.statusDownloadError('${snapshot.error}'));
                }

                final List<DtxDownloadItem> items =
                    snapshot.data ?? const <DtxDownloadItem>[];
                if (!_selectionInitialized) {
                  _selectedFiles
                    ..clear()
                    ..addAll(
                      items.map((DtxDownloadItem item) => item.fileName),
                    );
                  _selectionInitialized = true;
                }

                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.statusDownloadSummaryNone),
                  );
                }

                final List<_DownloadListEntry> entries =
                    _buildDownloadListEntries(items);

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      final _DownloadListEntry entry = entries[index];
                      if (entry.isHeader) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text(
                            '[${entry.group!}]',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        );
                      }

                      final DtxDownloadItem item = entry.item!;
                      return Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selectedFiles.contains(item.fileName),
                          title: Text(item.longName),
                          subtitle: Text(item.timestamp),
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked ?? false) {
                                _selectedFiles.add(item.fileName);
                              } else {
                                _selectedFiles.remove(item.fileName);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                );
              },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        OutlinedButton(
          onPressed: () => _importDtxFiles(context),
          child: Text(l10n.importDtxFilesButton),
        ),
        FutureBuilder<List<DtxDownloadItem>>(
          future: _candidatesFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<DtxDownloadItem>> snapshot,
              ) {
                final List<DtxDownloadItem> items =
                    snapshot.data ?? const <DtxDownloadItem>[];
                final List<DtxDownloadItem> selected = _effectiveSelected(
                  items,
                );
                return FilledButton(
                  onPressed:
                      selected.isEmpty || widget.controller.downloadInProgress
                      ? null
                      : () => Navigator.of(context).pop(selected),
                  child: Text(l10n.apply),
                );
              },
        ),
      ],
    );
  }

  Future<void> _importDtxFiles(BuildContext context) async {
    const XTypeGroup dtxType = XTypeGroup(
      label: 'DTX',
      extensions: <String>['dtx'],
    );
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[dtxType],
    );
    if (files.isEmpty || !context.mounted) {
      return;
    }
    try {
      final int count = await widget.controller.importDtxFiles(files);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.importDtxFilesSuccess(count))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.importDtxFilesError)),
      );
    }
  }
}

class _BookDropdown extends StatelessWidget {
  const _BookDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.books.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final bool hasDia = controller.hasImportedCustomOrderDia;
    final String fallbackDiaName = controller.customOrderLooksLikeZsolozsma
      ? context.l10n.zsolozsmaTooltip
      : context.l10n.customOrderUnnamedFileName;
    final String diaName =
      controller.lastImportedCustomOrderBaseName ?? fallbackDiaName;
    final List<_BookDropdownEntry> entries = _buildBookDropdownEntries(
      controller.books,
    );
    final int initial = controller.diaVirtualBookSelected
        ? _diaVirtualBookValue
        : controller.bookIndex;
    return DropdownButtonFormField<int>(
      initialValue: initial,
      decoration: InputDecoration(
        labelText: context.l10n.bookLabel,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: <DropdownMenuItem<int>>[
        if (hasDia)
          DropdownMenuItem<int>(
            value: _diaVirtualBookValue,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                context.l10n.diaBookLabel(diaName),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ...entries.asMap().entries.map((MapEntry<int, _BookDropdownEntry> e) {
          final _BookDropdownEntry entry = e.value;
          if (entry.isHeader) {
            return DropdownMenuItem<int>(
              value: -(e.key + 1),
              enabled: false,
              child: Text(
                '[${entry.group!}]',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return DropdownMenuItem<int>(
            value: entry.bookIndex,
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
        }),
      ],
      selectedItemBuilder: (BuildContext context) {
        return <Widget>[
          if (hasDia)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.diaBookLabel(diaName),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ...entries.map((_BookDropdownEntry entry) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.title ?? '[${entry.group!}]',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }),
        ];
      },
      onChanged: (int? value) {
        if (value == _diaVirtualBookValue) {
          controller.selectDiaVirtualBook();
          return;
        }
        if (value != null && value >= 0) {
          controller.setBookIndex(value);
        }
      },
    );
  }
}

class _SongDropdown extends StatelessWidget {
  const _SongDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.diaVirtualBookSelected) {
      final List<_DiaSongGroup> groups = _buildDiaSongGroups(controller);
      if (groups.isEmpty) {
        return const SizedBox.shrink();
      }
      final int selectedCursor = controller.selectedCustomOrderCursor;
      final int selectedGroup = _selectedDiaSongGroupIndex(
        groups,
        selectedCursor,
      );
      return DropdownButtonFormField<int>(
        initialValue: selectedGroup.clamp(0, groups.length - 1),
        decoration: InputDecoration(
          labelText: context.l10n.songLabel,
          border: const OutlineInputBorder(),
        ),
        isExpanded: true,
        items: groups.asMap().entries.map((MapEntry<int, _DiaSongGroup> e) {
          return DropdownMenuItem<int>(
            value: e.key,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                e.value.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        }).toList(),
        onChanged: (int? value) {
          if (value == null || value < 0 || value >= groups.length) {
            return;
          }
          final List<_DiaVerseEntry> verses = groups[value].verses;
          if (verses.isEmpty) {
            return;
          }
          controller.selectCustomOrderEntryAt(verses.first.customOrderIndex);
        },
      );
    }

    final DtxBook? b = controller.currentBook;
    final List<DtxSong> songs = b?.songs ?? const <DtxSong>[];
    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      initialValue: controller.songIndex.clamp(0, songs.length - 1),
      decoration: InputDecoration(
        labelText: context.l10n.songLabel,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: songs.asMap().entries.map((MapEntry<int, DtxSong> e) {
        final String title = e.value.separator
            ? '-- ${e.value.title} --'
            : e.value.title;
        return DropdownMenuItem<int>(
          value: e.key,
          child: SizedBox(
            width: double.infinity,
            child: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        );
      }).toList(),
      onChanged: (int? value) {
        if (value != null) {
          controller.setSongIndex(value);
        }
      },
    );
  }
}

class _VerseDropdown extends StatelessWidget {
  const _VerseDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.diaVirtualBookSelected) {
      final List<_DiaSongGroup> groups = _buildDiaSongGroups(controller);
      if (groups.isEmpty) {
        return const SizedBox.shrink();
      }
      final int selectedCursor = controller.selectedCustomOrderCursor;
      final int selectedGroup = _selectedDiaSongGroupIndex(
        groups,
        selectedCursor,
      );
      final List<_DiaVerseEntry> verses = groups[selectedGroup].verses;
      if (verses.isEmpty) {
        return const SizedBox.shrink();
      }
      final int selectedVerse = verses.indexWhere(
        (_DiaVerseEntry v) => v.customOrderIndex == selectedCursor,
      );
      final int initialValue = (selectedVerse >= 0 ? selectedVerse : 0).clamp(
        0,
        verses.length - 1,
      );
      return DropdownButtonFormField<int>(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: context.l10n.verseLabel,
          border: const OutlineInputBorder(),
        ),
        isExpanded: true,
        items: verses.asMap().entries.map((MapEntry<int, _DiaVerseEntry> e) {
          return DropdownMenuItem<int>(
            value: e.key,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                e.value.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        }).toList(),
        onChanged: (int? value) {
          if (value == null || value < 0 || value >= verses.length) {
            return;
          }
          controller.selectCustomOrderEntryAt(verses[value].customOrderIndex);
        },
      );
    }

    final DtxSong? s = controller.currentSong;
    final List<DtxVerse> verses = s?.verses ?? const <DtxVerse>[];
    if (verses.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      initialValue: controller.verseIndex.clamp(0, verses.length - 1),
      decoration: InputDecoration(
        labelText: context.l10n.verseLabel,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: verses.asMap().entries.map((MapEntry<int, DtxVerse> e) {
        return DropdownMenuItem<int>(
          value: e.key,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              e.value.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );
      }).toList(),
      onChanged: (int? value) {
        if (value != null) {
          controller.setVerseIndex(value);
        }
      },
    );
  }
}

class _VersePreview extends StatelessWidget {
  const _VersePreview({
    required this.controller,
    required this.song,
    required this.verse,
    required this.panelTitle,
  });

  final DiatarMainController controller;
  final DtxSong song;
  final DtxVerse verse;
  final String panelTitle;

  @override
  Widget build(BuildContext context) {
    final RecTextRecord previewRecord = RecTextRecord(
      scholaLine: '',
      title: '',
      lines: verse.lines,
    );
    final ProjectionFrame frame = TextFrame(record: previewRecord);
    final ProjectionGlobals globals = controller.globals.copyWith(
      projecting: true,
      wordToHighlight: controller.highPos,
    );
    final ProjectorPainter painter = ProjectorPainter(
      frame: frame,
      globals: globals,
      settings: controller.settings,
      logoTitle: context.l10n.appTitle,
    );
    final String verseTitle = _buildVerseTitle(controller, song, verse);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800;
        final double viewportHeightForMeasure = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      MediaQuery.of(context).padding.vertical -
                      220)
                  .clamp(240, double.infinity);

        final TextPainter titlePainter = TextPainter(
          text: TextSpan(
            text: verseTitle,
            style: TextStyle(
              color: controller.globals.txtColor.withValues(alpha: 0.75),
            ),
          ),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width);
        final double titleHeight = titlePainter.height + 10;
        final double fallbackCanvasHeight = math.max(
          120,
          viewportHeightForMeasure - titleHeight,
        );
        final double requiredCanvasHeight = painter.measureRequiredHeight(
          Size(width, fallbackCanvasHeight),
        );
        final double scrollCanvasHeight = math.max(
          fallbackCanvasHeight,
          requiredCanvasHeight,
        );

        return GestureDetector(
          onHorizontalDragEnd: (DragEndDetails details) {
            // Swipe threshold for velocity
            const double swipeThreshold = 300.0;
            if (details.velocity.pixelsPerSecond.dx.abs() > swipeThreshold) {
              if (details.velocity.pixelsPerSecond.dx > 0) {
                // Swipe right - previous verse
                controller.prevVerse();
              } else {
                // Swipe left - next verse
                controller.nextVerse();
              }
            }
          },
          child: constraints.maxHeight.isFinite
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      verseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: controller.globals.txtColor.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SizedBox(
                        width: width,
                        child: ClipRect(child: CustomPaint(painter: painter)),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      verseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: controller.globals.txtColor.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: width,
                      height: scrollCanvasHeight,
                      child: ClipRect(
                        child: CustomPaint(
                          size: Size(width, scrollCanvasHeight),
                          painter: painter,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  String _buildVerseTitle(
    DiatarMainController controller,
    DtxSong song,
    DtxVerse verse,
  ) {
    final DtxBook? book = controller.currentBook;
    if (book == null) return verse.name;

    final String bookShortName = book.nick.trim().isNotEmpty
        ? book.nick
        : book.title;
    final String songTitle = song.title.trim().isNotEmpty
        ? song.title.trim()
        : (controller.songIndex + 1).toString();
    final String verseName = verse.name.trim();
    final bool hideVersePart =
        verseName.isEmpty || ((song.verses.length == 1) && verseName == '---');
    final String versePart = hideVersePart ? '' : '/$verseName';

    return '$bookShortName: $songTitle$versePart';
  }
}

class _CustomTextPreview extends StatelessWidget {
  const _CustomTextPreview({
    required this.controller,
    required this.title,
    required this.lines,
  });

  final DiatarMainController controller;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final RecTextRecord previewRecord = RecTextRecord(
      scholaLine: '',
      title: '',
      lines: lines.isEmpty ? const <String>[''] : lines,
    );
    final ProjectionFrame frame = TextFrame(record: previewRecord);
    final ProjectionGlobals globals = controller.globals.copyWith(
      projecting: true,
      wordToHighlight: 0,
    );
    final ProjectorPainter painter = ProjectorPainter(
      frame: frame,
      globals: globals,
      settings: controller.settings,
      logoTitle: context.l10n.appTitle,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800;
        final String fullTitle = context.l10n.diaBookLabel(title);
        final TextStyle titleStyle = TextStyle(
          color: controller.globals.txtColor.withValues(alpha: 0.75),
        );
        final TextPainter titlePainter = TextPainter(
          text: TextSpan(text: fullTitle, style: titleStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width);
        final double titleHeight = titlePainter.height + 10;
        final double viewportHeightForMeasure = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      MediaQuery.of(context).padding.vertical -
                      220)
                  .clamp(240, double.infinity);
        final double fallbackCanvasHeight = math.max(
          120,
          viewportHeightForMeasure - titleHeight,
        );
        final double requiredCanvasHeight = painter.measureRequiredHeight(
          Size(width, fallbackCanvasHeight),
        );
        final double scrollCanvasHeight = math.max(
          fallbackCanvasHeight,
          requiredCanvasHeight,
        );

        return GestureDetector(
          onHorizontalDragEnd: (DragEndDetails details) {
            const double swipeThreshold = 300.0;
            if (details.velocity.pixelsPerSecond.dx.abs() > swipeThreshold) {
              if (details.velocity.pixelsPerSecond.dx > 0) {
                controller.prevVerse();
              } else {
                controller.nextVerse();
              }
            }
          },
          child: constraints.maxHeight.isFinite
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fullTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SizedBox(
                        width: width,
                        child: ClipRect(child: CustomPaint(painter: painter)),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fullTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: width,
                      height: scrollCanvasHeight,
                      child: ClipRect(
                        child: CustomPaint(
                          size: Size(width, scrollCanvasHeight),
                          painter: painter,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CustomImagePreview extends StatelessWidget {
  const _CustomImagePreview({
    required this.controller,
    required this.imagePath,
  });

  final DiatarMainController controller;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final String normalized = imagePath.trim();
    final String friendlyPath = normalized.isEmpty
        ? ''
        : formatFriendlyPathLabel(normalized, context.l10n);
    final File f = File(normalized);
    final bool exists = normalized.isNotEmpty && f.existsSync();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (DragEndDetails details) {
        const double swipeThreshold = 300.0;
        if (details.velocity.pixelsPerSecond.dx.abs() > swipeThreshold) {
          if (details.velocity.pixelsPerSecond.dx > 0) {
            controller.prevVerse();
          } else {
            controller.nextVerse();
          }
        }
      },
      child: !exists
          ? Align(
              alignment: Alignment.topLeft,
              child: Text(context.l10n.statusImageNotFound(friendlyPath)),
            )
          : SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(f, fit: BoxFit.contain),
              ),
            ),
    );
  }
}

Widget _actionIconButton(
  BuildContext context, {
  IconData? icon,
  Widget? child,
  required String tooltip,
  required VoidCallback onPressed,
  Color? backgroundColor,
  Color? foregroundColor,
  bool selected = false,
}) {
  assert(icon != null || child != null, 'Either icon or child must be set.');
  final ColorScheme colors = Theme.of(context).colorScheme;
  return Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(50, 50),
        side: BorderSide(
          color:
              foregroundColor ?? (selected ? colors.onPrimary : colors.outline),
          width: 2.0,
        ),
        backgroundColor:
            backgroundColor ??
            (selected ? colors.primary.withValues(alpha: 0.14) : null),
        foregroundColor:
            foregroundColor ?? (selected ? colors.onPrimary : null),
      ),
      child: child ?? Icon(icon!, size: 26),
    ),
  );
}
