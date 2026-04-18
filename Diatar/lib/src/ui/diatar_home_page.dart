import 'dart:async';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';

import '../controllers/diatar_main_controller.dart';
import '../l10n/l10n.dart';
import '../services/dtx_download_service.dart';
import 'diatar_settings_sheet.dart';
import 'custom_order_editor_sheet.dart';

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
          PopupMenuButton<DiatarHomeViewMode>(
            tooltip: l10n.viewTooltip,
            initialValue: controller.viewMode,
            onSelected: (DiatarHomeViewMode mode) =>
                unawaited(controller.setViewMode(mode)),
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<DiatarHomeViewMode>>[
                  PopupMenuItem<DiatarHomeViewMode>(
                    value: DiatarHomeViewMode.szimpla,
                    child: Text(l10n.viewSimple),
                  ),
                  PopupMenuItem<DiatarHomeViewMode>(
                    value: DiatarHomeViewMode.spontan,
                    child: Text(l10n.viewSpontaneous),
                  ),
                  PopupMenuItem<DiatarHomeViewMode>(
                    value: DiatarHomeViewMode.sorrend,
                    child: Text(l10n.viewOrder),
                  ),
                ],
            icon: const Icon(Icons.view_carousel_outlined),
          ),
          IconButton(
            tooltip: l10n.settingsTooltip,
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: l10n.playlistsTooltip,
            onPressed: () => _showPlaceholder(
              context,
              l10n.playlistsTitle,
              l10n.playlistsMessage,
            ),
            icon: const Icon(Icons.playlist_play),
          ),
          IconButton(
            tooltip: l10n.customOrderTooltip,
            onPressed: () => _openCustomOrderEditor(context),
            icon: const Icon(Icons.queue_music),
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
          final MediaQueryData mq = MediaQuery.of(context);
          final int screenW = (mq.size.width * mq.devicePixelRatio).round();
          final int screenH = (mq.size.height * mq.devicePixelRatio).round();
          unawaited(
            controller.updateScreenSize(width: screenW, height: screenH),
          );

          return switch (controller.viewMode) {
            DiatarHomeViewMode.szimpla => _buildSimpleView(context),
            DiatarHomeViewMode.spontan => _buildSpontanView(context),
            DiatarHomeViewMode.sorrend => _buildOrderView(context),
          };
        },
      ),
    );
  }

  Widget _buildSimpleView(BuildContext context) {
    final l10n = context.l10n;
    final DtxBook? book = controller.currentBook;
    final DtxSong? song = controller.currentSong;
    final DtxVerse? verse = controller.currentVerse;

    return Column(
      children: <Widget>[
        if (controller.loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
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
                      icon: Icons.skip_previous,
                      tooltip: l10n.previous,
                      onPressed: controller.prevVerse,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: controller.showing
                          ? Icons.cast_connected
                          : Icons.cast,
                      tooltip: controller.showing
                          ? l10n.projectionOff
                          : l10n.projectionOn,
                      onPressed: controller.toggleShowing,
                      backgroundColor: controller.showing
                          ? const Color(0xFFD32F2F).withOpacity(0.15)
                          : Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.08),
                      foregroundColor: controller.showing
                          ? const Color(0xFFD32F2F)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.skip_next,
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
                      icon: Icons.light_mode_outlined,
                      tooltip: l10n.highlightPrev,
                      onPressed: controller.highlightPrev,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.light_mode,
                      tooltip: l10n.highlightNext,
                      onPressed: controller.highlightNext,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.positionLabel(controller.highPos, controller.wordCount),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.statusLabel(_localizedStatus(context)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.sendStatusLabel(
                    controller.mqttActive
                        ? l10n.protocolMqtt
                        : l10n.protocolTcp,
                    controller.senderRunning
                        ? l10n.senderStateActive
                        : l10n.senderStateOff,
                    controller.senderConnected
                        ? l10n.clientStateConnected
                        : l10n.clientStateWaiting,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.tcpPortLabel(controller.settings.port)),
              ),
              if (controller.downloadInProgress) ...<Widget>[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: controller.downloadCurrentFraction,
                ),
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
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: controller.globals.bkColor,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: book == null || song == null || verse == null
                  ? Text(
                      l10n.noLoadedSlide,
                      style: TextStyle(color: controller.globals.txtColor),
                    )
                  : _VersePreview(
                      controller: controller,
                      song: song,
                      verse: verse,
                      panelTitle: l10n.previewTitle,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpontanView(BuildContext context) {
    return _SongSearchDashboard(
      controller: controller,
      onQuickOpenCustomOrder: () => _openCustomOrderEditor(context),
    );
  }

  Widget _buildOrderView(BuildContext context) {
    return _OrderDashboard(controller: controller);
  }

  String _localizedStatus(BuildContext context) {
    final l10n = context.l10n;
    final Map<String, String> p = controller.statusParams;
    switch (controller.statusCode) {
      case 'statusStarting':
        return l10n.statusStarting;
      case 'statusSenderError':
        return l10n.statusSenderError(p['message'] ?? '');
      case 'statusSenderTcpError':
        return l10n.statusSenderTcpError(p['error'] ?? '');
      case 'statusSenderOpenPortFailed':
        return l10n.statusSenderOpenPortFailed(
          int.tryParse(p['port'] ?? '') ?? 0,
          p['error'] ?? '',
        );
      case 'statusSenderMqttConnectFailed':
        return l10n.statusSenderMqttConnectFailed;
      case 'statusSenderMqttError':
        return l10n.statusSenderMqttError(p['error'] ?? '');
      case 'statusMqttSending':
        return l10n.statusMqttSending(p['user'] ?? '', p['channel'] ?? '');
      case 'statusTcpSending':
        return l10n.statusTcpSending(int.tryParse(p['port'] ?? '') ?? 0);
      case 'statusNoDtxFiles':
        return l10n.statusNoDtxFiles(p['path'] ?? '');
      case 'statusAllSongbooksDisabled':
        return l10n.statusAllSongbooksDisabled;
      case 'statusSongbooksLoaded':
        return l10n.statusSongbooksLoaded(int.tryParse(p['count'] ?? '') ?? 0);
      case 'statusLoadError':
        return l10n.statusLoadError(p['error'] ?? '');
      case 'statusCustomOrderSelected':
        return l10n.statusCustomOrderSelected(p['label'] ?? '');
      case 'statusOrderSaved':
        return l10n.statusOrderSaved(p['path'] ?? '');
      case 'statusDiaFileMissing':
        return l10n.statusDiaFileMissing(p['path'] ?? '');
      case 'statusOrderLoaded':
        return l10n.statusOrderLoaded(
          int.tryParse(p['count'] ?? '') ?? 0,
          p['path'] ?? '',
        );
      case 'statusDownloadListLoading':
        return l10n.statusDownloadListLoading;
      case 'statusDownloadProgress':
        return l10n.statusDownloadProgress(
          int.tryParse(p['current'] ?? '') ?? 0,
          int.tryParse(p['total'] ?? '') ?? 0,
          p['name'] ?? '',
          int.tryParse(p['percent'] ?? '') ?? 0,
        );
      case 'statusDownloadSummaryNone':
        return l10n.statusDownloadSummaryNone;
      case 'statusDownloadSummary':
        return l10n.statusDownloadSummary(
          int.tryParse(p['downloaded'] ?? '') ?? 0,
          int.tryParse(p['skipped'] ?? '') ?? 0,
        );
      case 'statusDownloadError':
        return l10n.statusDownloadError(p['error'] ?? '');
      case 'statusBookSelected':
        return l10n.statusBookSelected(p['name'] ?? '-');
      case 'statusSongPicked':
        return l10n.statusSongPicked(p['name'] ?? '-');
      case 'statusVersePicked':
        return l10n.statusVersePicked(p['name'] ?? '-');
      case 'statusSongSelected':
        return l10n.statusSongSelected(p['title'] ?? '');
      case 'statusSongVerseSelected':
        return l10n.statusSongVerseSelected(p['title'] ?? '');
      case 'statusProjectionOn':
        return l10n.statusProjectionOn;
      case 'statusProjectionOff':
        return l10n.statusProjectionOff;
      case 'statusImagePathEmpty':
        return l10n.statusImagePathEmpty;
      case 'statusImageNotFound':
        return l10n.statusImageNotFound(p['path'] ?? '');
      case 'statusImageSent':
        return l10n.statusImageSent(p['name'] ?? '');
      case 'statusImageSendError':
        return l10n.statusImageSendError(p['error'] ?? '');
      case 'statusBlankPathEmpty':
        return l10n.statusBlankPathEmpty;
      case 'statusBlankNotFound':
        return l10n.statusBlankNotFound(p['path'] ?? '');
      case 'statusBlankSet':
        return l10n.statusBlankSet(p['name'] ?? '');
      case 'statusBlankSendError':
        return l10n.statusBlankSendError(p['error'] ?? '');
      case 'statusBlankCleared':
        return l10n.statusBlankCleared;
      case 'statusBlankClearError':
        return l10n.statusBlankClearError(p['error'] ?? '');
      case 'statusShutdownCommandSent':
        return l10n.statusShutdownCommandSent;
      case 'statusStopCommandSent':
        return l10n.statusStopCommandSent;
      case 'statusCommandSendError':
        return l10n.statusCommandSendError(p['error'] ?? '');
      default:
        return controller.statusCode;
    }
  }

  Future<void> _openSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DiatarSettingsSheet(
          initialSettings: controller.settings,
          onApply: (AppSettings settings) => controller.applySettings(settings),
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

  Future<void> _showPlaceholder(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ok),
            ),
          ],
        );
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

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final DtxDownloadItem item = items[index];
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedFiles.contains(item.fileName),
                        title: Text(item.fileName),
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
        FutureBuilder<List<DtxDownloadItem>>(
          future: _candidatesFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<DtxDownloadItem>> snapshot,
              ) {
                final List<DtxDownloadItem> items =
                    snapshot.data ?? const <DtxDownloadItem>[];
                final List<DtxDownloadItem> selected = items
                    .where(
                      (DtxDownloadItem item) =>
                          _selectedFiles.contains(item.fileName),
                    )
                    .toList();
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
}

class _BookDropdown extends StatelessWidget {
  const _BookDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.books.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      value: controller.bookIndex,
      decoration: InputDecoration(
        labelText: context.l10n.bookLabel,
        border: const OutlineInputBorder(),
      ),
      items: controller.books.asMap().entries.map((MapEntry<int, DtxBook> e) {
        final DtxBook book = e.value;
        final String groupPrefix = book.group.trim().isEmpty
            ? ''
            : '[${book.group}] ';
        return DropdownMenuItem<int>(
          value: e.key,
          child: Text('$groupPrefix${book.displayName}'),
        );
      }).toList(),
      onChanged: (int? value) {
        if (value != null) {
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
    final DtxBook? b = controller.currentBook;
    final List<DtxSong> songs = b?.songs ?? const <DtxSong>[];
    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      value: controller.songIndex.clamp(0, songs.length - 1),
      decoration: InputDecoration(
        labelText: context.l10n.songLabel,
        border: const OutlineInputBorder(),
      ),
      items: songs.asMap().entries.map((MapEntry<int, DtxSong> e) {
        final String title = e.value.separator
            ? '-- ${e.value.title} --'
            : e.value.title;
        return DropdownMenuItem<int>(value: e.key, child: Text(title));
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
    final DtxSong? s = controller.currentSong;
    final List<DtxVerse> verses = s?.verses ?? const <DtxVerse>[];
    if (verses.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      value: controller.verseIndex.clamp(0, verses.length - 1),
      decoration: InputDecoration(
        labelText: context.l10n.verseLabel,
        border: const OutlineInputBorder(),
      ),
      items: verses.asMap().entries.map((MapEntry<int, DtxVerse> e) {
        return DropdownMenuItem<int>(value: e.key, child: Text(e.value.name));
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
      title: song.title,
      lines: verse.lines,
    );
    final ProjectionFrame frame = TextFrame(record: previewRecord);
    final ProjectionGlobals globals = controller.globals.copyWith(
      projecting: true,
      wordToHighlight: controller.highPos,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800;
        final double canvasHeight = _estimateCanvasHeight(
          globals: globals,
          frame: previewRecord,
          viewportWidth: width,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.versePanelTitle(panelTitle, verse.name),
              style: TextStyle(
                color: controller.globals.txtColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: width,
              height: canvasHeight,
              child: CustomPaint(
                size: Size(width, canvasHeight),
                painter: ProjectorPainter(
                  frame: frame,
                  globals: globals,
                  settings: controller.settings,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _estimateCanvasHeight({
    required ProjectionGlobals globals,
    required RecTextRecord frame,
    required double viewportWidth,
  }) {
    final bool hasTitle = !globals.hideTitle && frame.title.isNotEmpty;
    final int logicalLines = frame.lines.length + (hasTitle ? 1 : 0);
    if (logicalLines <= 0) {
      return 280;
    }

    final double fontSize = globals.fontSize.toDouble();
    final double titleSize = (globals.titleSize.toDouble() * 2.5).clamp(
      8.0,
      72.0,
    );
    final double lineSpacing = globals.spacing100 / 100.0;

    final TextPainter normalProbe = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: globals.boldText ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: viewportWidth);
    final TextPainter titleProbe = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: viewportWidth);

    double estimated = 8;
    if (hasTitle) {
      estimated += titleProbe.height * lineSpacing;
    }
    estimated += normalProbe.height * lineSpacing * frame.lines.length;

    if (globals.useKotta) {
      estimated +=
          frame.lines.length * (fontSize * (globals.kottaArany / 100.0) * 1.35);
    }

    return estimated * 1.25;
  }
}

class _SongSearchDashboard extends StatefulWidget {
  const _SongSearchDashboard({
    required this.controller,
    required this.onQuickOpenCustomOrder,
  });

  final DiatarMainController controller;
  final VoidCallback onQuickOpenCustomOrder;

  @override
  State<_SongSearchDashboard> createState() => _SongSearchDashboardState();
}

class _SongSearchDashboardState extends State<_SongSearchDashboard> {
  String _query = '';

  DiatarMainController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<_SearchHit> allHits = <_SearchHit>[];
    for (final DtxBook book in controller.books) {
      for (int i = 0; i < book.songs.length; i++) {
        final DtxSong song = book.songs[i];
        if (song.separator) {
          continue;
        }
        allHits.add(_SearchHit(book: book, songIndex: i, song: song));
      }
    }

    final String filter = _query.toLowerCase();
    final List<_SearchHit> hits =
        allHits.where((_SearchHit hit) {
          if (filter.isEmpty) {
            return true;
          }
          return hit.book.displayName.toLowerCase().contains(filter) ||
              hit.song.title.toLowerCase().contains(filter);
        }).toList()..sort((_SearchHit a, _SearchHit b) {
          final int byBook = a.book.displayName.toLowerCase().compareTo(
            b.book.displayName.toLowerCase(),
          );
          if (byBook != 0) {
            return byBook;
          }
          return a.song.title.toLowerCase().compareTo(
            b.song.title.toLowerCase(),
          );
        });

    final DtxSong? currentSong = controller.currentSong;
    final DtxVerse? currentVerse = controller.currentVerse;

    return Column(
      children: <Widget>[
        if (controller.loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              labelText: l10n.searchLabel,
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (String value) => setState(() => _query = value.trim()),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth > 1200;
              final Widget searchList = _buildSearchList(hits);
              final Widget detailPane = _buildDetailPane(
                currentSong: currentSong,
                currentVerse: currentVerse,
              );
              final Widget orderStrip = _buildCustomOrderStrip();

              if (wide) {
                // OpenLP-szerű: sorrend felül, keresés balra, előnézet jobbra
                return Row(
                  children: <Widget>[
                    Expanded(flex: 1, child: searchList),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: <Widget>[
                          SizedBox(height: 60, child: orderStrip),
                          const Divider(height: 1),
                          Expanded(child: detailPane),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                children: <Widget>[
                  SizedBox(height: 60, child: orderStrip),
                  const Divider(height: 1),
                  SizedBox(height: 300, child: searchList),
                  const Divider(height: 1),
                  detailPane,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchList(List<_SearchHit> hits) {
    if (hits.isEmpty) {
      return Center(child: Text(context.l10n.noResults));
    }

    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (BuildContext context, int index) {
        final _SearchHit hit = hits[index];
        final bool selected =
            controller.currentBook?.fileName == hit.book.fileName &&
            controller.songIndex == hit.songIndex;
        return ListTile(
          dense: true,
          selected: selected,
          title: Text(hit.song.title),
          subtitle: Text(hit.book.displayName, overflow: TextOverflow.ellipsis),
          trailing: Text(
            '${hit.song.verses.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            final int bookIndex = controller.books.indexWhere(
              (DtxBook b) => b.fileName == hit.book.fileName,
            );
            if (bookIndex >= 0) {
              controller.setBookIndex(bookIndex);
              controller.setSongIndex(hit.songIndex);
              controller.setVerseIndex(0);
            }
          },
        );
      },
    );
  }

  Widget _buildCustomOrderStrip() {
    final List<CustomOrderEntry> entries = controller.customOrder;
    final bool hasEntries = entries.isNotEmpty;

    if (!hasEntries) {
      return Center(
        child: Text(
          context.l10n.customOrderStatus(
            controller.customOrderActive
                ? context.l10n.stateActive
                : context.l10n.stateInactive,
          ),
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final CustomOrderEntry entry = entries[index];
        final bool selected = controller.isCustomOrderIndexCurrent(index);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: ActionChip(
            label: Text(
              '${index + 1}. ${entry.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: selected
                ? Colors.blue.withValues(alpha: 0.2)
                : null,
            side: selected
                ? const BorderSide(color: Colors.blue)
                : BorderSide.none,
            onPressed: () => controller.projectCustomOrderAt(index),
          ),
        );
      },
    );
  }

  Widget _buildDetailPane({
    required DtxSong? currentSong,
    required DtxVerse? currentVerse,
  }) {
    if (currentSong == null || currentVerse == null) {
      return Center(child: Text(context.l10n.noLoadedSlide));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    currentSong.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: controller.prevVerse,
                      icon: const Icon(Icons.skip_previous, size: 18),
                      label: Text(context.l10n.previous),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: controller.nextVerse,
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: Text(context.l10n.nextShort),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: currentSong.verses.asMap().entries.map((
                MapEntry<int, DtxVerse> e,
              ) {
                final bool selected = e.key == controller.verseIndex;
                return ChoiceChip(
                  label: Text(
                    e.value.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: selected,
                  onSelected: (_) => controller.setVerseIndex(e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _VersePreview(
              controller: controller,
              song: currentSong,
              verse: currentVerse,
              panelTitle: context.l10n.previewTitle,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.projectedImage,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              color: controller.globals.bkColor,
              child: _buildProjectedImagePreview(currentSong, currentVerse),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectedImagePreview(DtxSong song, DtxVerse verse) {
    final RecTextRecord projRecord = RecTextRecord(
      scholaLine: '',
      title: song.title,
      lines: verse.lines,
    );
    final ProjectionFrame frame = TextFrame(record: projRecord);
    final ProjectionGlobals globals = controller.globals.copyWith(
      projecting: true,
      wordToHighlight: controller.highPos,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: ProjectorPainter(
            frame: frame,
            globals: globals,
            settings: controller.settings,
          ),
        );
      },
    );
  }
}

class _OrderDashboard extends StatelessWidget {
  const _OrderDashboard({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    final DtxBook? book = controller.currentBook;
    final DtxSong? song = controller.currentSong;
    final DtxVerse? verse = controller.currentVerse;

    return Column(
      children: <Widget>[
        if (controller.loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            spacing: 8,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact = constraints.maxWidth < 900;
                  if (compact) {
                    return Column(
                      spacing: 8,
                      children: <Widget>[
                        _BookDropdown(controller: controller),
                        _SongDropdown(controller: controller),
                        _VerseDropdown(controller: controller),
                      ],
                    );
                  }
                  return Row(
                    spacing: 8,
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: _BookDropdown(controller: controller),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SongDropdown(controller: controller),
                      ),
                      Expanded(
                        flex: 1,
                        child: _VerseDropdown(controller: controller),
                      ),
                    ],
                  );
                },
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _actionIconButton(
                      context,
                      icon: Icons.keyboard_double_arrow_left,
                      tooltip: context.l10n.songPrev,
                      onPressed: controller.prevSong,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.skip_previous,
                      tooltip: context.l10n.previous,
                      onPressed: controller.prevVerse,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: controller.showing
                          ? Icons.cast_connected
                          : Icons.cast,
                      tooltip: controller.showing
                          ? context.l10n.projectionOff
                          : context.l10n.projectionOn,
                      onPressed: controller.toggleShowing,
                      backgroundColor: controller.showing
                          ? const Color(0xFFD32F2F).withOpacity(0.15)
                          : Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.08),
                      foregroundColor: controller.showing
                          ? const Color(0xFFD32F2F)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.skip_next,
                      tooltip: context.l10n.next,
                      onPressed: controller.nextVerse,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.keyboard_double_arrow_right,
                      tooltip: context.l10n.songNext,
                      onPressed: controller.nextSong,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.light_mode_outlined,
                      tooltip: context.l10n.highlightPrev,
                      onPressed: controller.highlightPrev,
                    ),
                    const SizedBox(width: 8),
                    _actionIconButton(
                      context,
                      icon: Icons.light_mode,
                      tooltip: context.l10n.highlightNext,
                      onPressed: controller.highlightNext,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth > 1200;
              final Widget preview =
                  book == null || song == null || verse == null
                  ? Center(child: Text(context.l10n.noLoadedSlide))
                  : _VersePreview(
                      controller: controller,
                      song: song,
                      verse: verse,
                      panelTitle: context.l10n.previewTitle,
                    );
              final Widget orderPanel = Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CustomOrderEditorPanel(
                    controller: controller,
                    embedded: true,
                  ),
                ),
              );

              if (wide) {
                // Asztali DiaTár-szerű: nagy előnézet balra, sorrend jobbra
                return Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: controller.globals.bkColor,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: preview,
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: orderPanel,
                      ),
                    ),
                  ],
                );
              }

              // Mobil/szűk: versz előnézet fölül, sorrend alul, kötött magasságokkal
              return Column(
                children: <Widget>[
                  SizedBox(
                    height: 300,
                    child: Container(
                      color: controller.globals.bkColor,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: preview,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: orderPanel,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _actionIconButton(
  BuildContext context, {
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
  Color? backgroundColor,
  Color? foregroundColor,
  bool selected = false,
}) {
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
            (selected ? colors.primary.withOpacity(0.14) : null),
        foregroundColor:
            foregroundColor ?? (selected ? colors.onPrimary : null),
      ),
      child: Icon(icon, size: 26),
    ),
  );
}

class _SearchHit {
  const _SearchHit({
    required this.book,
    required this.songIndex,
    required this.song,
  });

  final DtxBook book;
  final int songIndex;
  final DtxSong song;
}
