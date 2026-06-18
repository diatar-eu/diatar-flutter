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

class _DtxManagerDialogResult {
  const _DtxManagerDialogResult({
    required this.downloadSelected,
    required this.excludedSelected,
  });

  final Set<String> downloadSelected;
  final Set<String> excludedSelected;
}

class _DtxManagerListEntry {
  const _DtxManagerListEntry.header(this.group) : item = null;

  const _DtxManagerListEntry.item(this.item) : group = null;

  final String? group;
  final DtxManageItem? item;

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

enum _ProjectionDisplayToggle { kotta, chords, backgroundImage }

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
        if (candidateSplit == null ||
            candidateSplit.prefix != firstSplit.prefix) {
          break;
        }
        verses.add(
          _DiaVerseEntry(customOrderIndex: j, label: candidateSplit.suffix),
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

enum _TransportIndicatorState { off, connecting, connected, error }

bool _isTransportErrorStatus(String code) {
  return _isMqttErrorStatus(code) || _isTcpErrorStatus(code);
}

String _statusParam(Map<String, String> params, String key) {
  return params[key] ?? '';
}

String _transportErrorMessage(
  BuildContext context,
  DiatarMainController controller,
) {
  final l10n = context.l10n;
  final String code = controller.statusCode;
  final Map<String, String> params = controller.statusParams;
  switch (code) {
    case 'statusSenderMqttConnectFailed':
      return l10n.statusSenderMqttConnectFailed;
    case 'statusSenderMqttError':
      return l10n.statusSenderMqttError(_statusParam(params, 'error'));
    case 'statusSenderTcpError':
      return l10n.statusSenderTcpError(_statusParam(params, 'error'));
    case 'statusSenderOpenPortFailed':
      return l10n.statusSenderOpenPortFailed(
        int.tryParse(_statusParam(params, 'port')) ?? 0,
        _statusParam(params, 'error'),
      );
    case 'statusSenderError':
      return l10n.statusSenderError(_statusParam(params, 'message'));
    default:
      return l10n.statusSenderError(code);
  }
}

String _transportStateLabel(
  BuildContext context,
  _TransportIndicatorState state,
) {
  final l10n = context.l10n;
  switch (state) {
    case _TransportIndicatorState.off:
      return l10n.internetStatusOff;
    case _TransportIndicatorState.connecting:
      return l10n.internetStatusConnecting;
    case _TransportIndicatorState.connected:
      return l10n.internetStatusOn;
    case _TransportIndicatorState.error:
      return l10n.internetStatusError;
  }
}

String _statusTooltip(
  BuildContext context, {
  required String title,
  required _TransportIndicatorState state,
}) {
  return context.l10n.connectionStatusTooltip(
    title,
    _transportStateLabel(context, state),
  );
}

bool _isMqttErrorStatus(String code) {
  return code == 'statusSenderMqttConnectFailed' ||
      code == 'statusSenderMqttError' ||
      code == 'statusSenderError';
}

bool _isTcpErrorStatus(String code) {
  return code == 'statusSenderTcpError' ||
      code == 'statusSenderOpenPortFailed' ||
      code == 'statusSenderError';
}

_TransportIndicatorState _mqttIndicatorState(DiatarMainController controller) {
  if (!controller.mqttActive) {
    return _TransportIndicatorState.off;
  }
  if (controller.mqttConnected) {
    return _TransportIndicatorState.connected;
  }
  if (controller.mqttHasError) {
    return _TransportIndicatorState.error;
  }
  return _TransportIndicatorState.connecting;
}

_TransportIndicatorState _localNetworkIndicatorState(
  DiatarMainController controller,
) {
  if (!controller.tcpActive) {
    return _TransportIndicatorState.off;
  }
  if (controller.tcpConnected) {
    return _TransportIndicatorState.connected;
  }
  if (controller.tcpHasError) {
    return _TransportIndicatorState.error;
  }
  return _TransportIndicatorState.connecting;
}

Color _statusColorFor(_TransportIndicatorState state, ThemeData theme) {
  switch (state) {
    case _TransportIndicatorState.off:
      return theme.disabledColor;
    case _TransportIndicatorState.connecting:
      return Colors.amber;
    case _TransportIndicatorState.connected:
      return Colors.green;
    case _TransportIndicatorState.error:
      return Colors.red;
  }
}

Widget _statusIcon({
  required IconData icon,
  required _TransportIndicatorState state,
  required ThemeData theme,
}) {
  final Color color = _statusColorFor(state, theme);
  final BorderSide border = switch (state) {
    _TransportIndicatorState.off => BorderSide.none,
    _TransportIndicatorState.connecting => BorderSide(
      color: Colors.amber.withValues(alpha: 0.85),
      width: 1.0,
    ),
    _TransportIndicatorState.connected => BorderSide(
      color: Colors.green.withValues(alpha: 0.85),
      width: 1.0,
    ),
    _TransportIndicatorState.error => BorderSide(
      color: Colors.red.withValues(alpha: 0.9),
      width: 1.4,
    ),
  };
  return Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.fromBorderSide(border),
    ),
    child: Icon(icon, size: 16, color: color),
  );
}

List<_BookDropdownEntry> _buildBookDropdownEntries(
  List<DtxBook> books,
  String ungroupedLabel,
) {
  final List<_BookDropdownEntry> entries = <_BookDropdownEntry>[];
  String? lastGroup;
  for (int index = 0; index < books.length; index++) {
    final DtxBook book = books[index];
    final String rawGroup = book.group.trim();
    final String displayGroup = rawGroup.isEmpty ? ungroupedLabel : rawGroup;
    if (displayGroup != lastGroup) {
      entries.add(_BookDropdownEntry.header(displayGroup));
      lastGroup = displayGroup;
    }
    entries.add(_BookDropdownEntry.book(bookIndex: index, title: book.title));
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
          // 10 circle buttons (including display options) + 9 gaps + side paddings.
          const double controlsRowMinWidthForButtons = 596.0;

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
        _TransportErrorSnackListener(controller: controller),
        _BookDropdown(controller: controller),
        const SizedBox(height: 4),
        _SongDropdown(controller: controller),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(child: _VerseDropdown(controller: controller)),
            const SizedBox(width: 30),
          ],
        ),
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
              Builder(
                builder: (BuildContext menuContext) {
                  final bool nothingShown =
                      !controller.settings.projUseKotta &&
                      !controller.settings.projUseAkkord;
                  final Color displayButtonColor = nothingShown
                      ? const Color(0xFFF9A825)
                      : Theme.of(menuContext).colorScheme.onSurfaceVariant;
                  return _actionIconButton(
                    menuContext,
                    child: Text(
                      '\u266B',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        decoration: nothingShown
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationThickness: 2.0,
                      ),
                    ),
                    tooltip:
                      '${l10n.showKotta} / ${l10n.showChords} / ${l10n.showBackgroundImage}',
                    onPressed: () =>
                        unawaited(_showProjectionDisplayMenu(menuContext)),
                    backgroundColor: displayButtonColor.withValues(alpha: 0.15),
                    foregroundColor: displayButtonColor,
                  );
                },
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
              if (controller.settings.homeShowHighlightControls) ...<Widget>[
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

  Future<void> _showProjectionDisplayMenu(BuildContext buttonContext) async {
    final RenderObject? buttonObject = buttonContext.findRenderObject();
    if (buttonObject is! RenderBox) {
      return;
    }
    final OverlayState overlay = Overlay.of(buttonContext);
    final RenderObject? overlayObject = overlay.context.findRenderObject();
    if (overlayObject is! RenderBox) {
      return;
    }

    final Offset topLeft = buttonObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    final Offset bottomRight = buttonObject.localToGlobal(
      buttonObject.size.bottomRight(Offset.zero),
      ancestor: overlayObject,
    );

    final _ProjectionDisplayToggle? selected =
        await showMenu<_ProjectionDisplayToggle>(
          context: buttonContext,
          position: RelativeRect.fromRect(
            Rect.fromPoints(topLeft, bottomRight),
            Offset.zero & overlayObject.size,
          ),
          items: <PopupMenuEntry<_ProjectionDisplayToggle>>[
            CheckedPopupMenuItem<_ProjectionDisplayToggle>(
              value: _ProjectionDisplayToggle.kotta,
              checked: controller.settings.projUseKotta,
              child: Text(buttonContext.l10n.showKotta),
            ),
            CheckedPopupMenuItem<_ProjectionDisplayToggle>(
              value: _ProjectionDisplayToggle.chords,
              checked: controller.settings.projUseAkkord,
              child: Text(buttonContext.l10n.showChords),
            ),
            CheckedPopupMenuItem<_ProjectionDisplayToggle>(
              value: _ProjectionDisplayToggle.backgroundImage,
              checked: controller.settings.projShowBackgroundImage,
              child: Text(buttonContext.l10n.showBackgroundImage),
            ),
          ],
        );

    if (selected == null) {
      return;
    }

    switch (selected) {
      case _ProjectionDisplayToggle.kotta:
        await controller.applySettings(
          controller.settings.copyWith(
            projUseKotta: !controller.settings.projUseKotta,
          ),
        );
      case _ProjectionDisplayToggle.chords:
        await controller.applySettings(
          controller.settings.copyWith(
            projUseAkkord: !controller.settings.projUseAkkord,
          ),
        );
      case _ProjectionDisplayToggle.backgroundImage:
        await controller.toggleBackgroundImageVisible();
    }
  }

  Widget _buildSimplePreviewPane(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color previewBorderColor = controller.globals.projecting
        ? Colors.red.shade700
        : theme.dividerColor.withValues(alpha: 0.65);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: controller.globals.bkColor,
        border: Border.all(color: previewBorderColor, width: 1.5),
      ),
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
    ).whenComplete(controller.syncProjectionToCurrentDia);
  }

  Future<void> _openDownloadDialog(BuildContext context) async {
    final _DtxManagerDialogResult? selected =
        await showDialog<_DtxManagerDialogResult>(
          context: context,
          builder: (BuildContext context) =>
              _DownloadSongbooksDialog(controller: controller),
        );
    if (selected == null) {
      return;
    }
    unawaited(
      controller.applyDtxManagerSelection(
        downloadSelected: selected.downloadSelected,
        excludedSelected: selected.excludedSelected,
      ),
    );
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

class _TransportErrorSnackListener extends StatefulWidget {
  const _TransportErrorSnackListener({required this.controller});

  final DiatarMainController controller;

  @override
  State<_TransportErrorSnackListener> createState() =>
      _TransportErrorSnackListenerState();
}

class _TransportErrorSnackListenerState
    extends State<_TransportErrorSnackListener> {
  String _lastErrorSignature = '';

  @override
  Widget build(BuildContext context) {
    final DiatarMainController controller = widget.controller;
    final String code = controller.statusCode;
    final bool isError = _isTransportErrorStatus(code);
    final String signature =
        '$code|${controller.statusParams.entries.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join(';')}';

    if (!isError) {
      _lastErrorSignature = '';
      return const SizedBox.shrink();
    }

    if (signature != _lastErrorSignature) {
      _lastErrorSignature = signature;
      final String message = _transportErrorMessage(context, controller);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }
        messenger.showSnackBar(SnackBar(content: Text(message)));
      });
    }

    return const SizedBox.shrink();
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
                        final bool loaded = await widget.controller
                            .selectZsolozsmaPart(_selectedDate, part);
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
  late Future<List<DtxManageItem>> _itemsFuture;
  final Set<String> _downloadSelected = <String>{};
  final Set<String> _excludedFiles = <String>{};
  bool _selectionInitialized = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.controller.loadDtxManagerItems();
  }

  void _reload() {
    setState(() {
      _selectionInitialized = false;
      _downloadSelected.clear();
      _excludedFiles.clear();
      _itemsFuture = widget.controller.loadDtxManagerItems();
    });
  }

  String _displayGroup(DtxManageItem managed, BuildContext context) {
    final l10n = context.l10n;
    if (managed.item.isUserProvided) {
      return l10n.downloadUserImportedGroup;
    }
    final String rawGroup = managed.item.group.trim();
    return rawGroup.isEmpty ? l10n.ungroupedBookGroupLabel : rawGroup;
  }

  bool? _groupDownloadValue(List<DtxManageItem> items) {
    final List<DtxManageItem> eligible = items
        .where(
          (DtxManageItem item) =>
              item.item.isOfficial && item.item.updateAvailable,
        )
        .toList();
    if (eligible.isEmpty) {
      return false;
    }
    final int selectedCount = eligible
        .where(
          (DtxManageItem item) =>
              _downloadSelected.contains(item.item.fileName),
        )
        .length;
    if (selectedCount == 0) {
      return false;
    }
    if (selectedCount == eligible.length) {
      return true;
    }
    return null;
  }

  bool? _groupExcludedValue(List<DtxManageItem> items) {
    if (items.isEmpty) {
      return false;
    }
    final int selectedCount = items
        .where(
          (DtxManageItem item) => _excludedFiles.contains(item.item.fileName),
        )
        .length;
    if (selectedCount == 0) {
      return false;
    }
    if (selectedCount == items.length) {
      return true;
    }
    return null;
  }

  String _subtitleFor(DtxDownloadItem item, BuildContext context) {
    final l10n = context.l10n;
    if (item.isUserProvided) {
      return l10n.downloadManagerUserImportedTag;
    }
    if (item.updateAvailable) {
      return l10n.downloadManagerUpdateAvailable;
    }
    return l10n.downloadManagerUpToDate;
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
        width: 700,
        child: FutureBuilder<List<DtxManageItem>>(
          future: _itemsFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<DtxManageItem>> snapshot,
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

                final List<DtxManageItem> items =
                    snapshot.data ?? const <DtxManageItem>[];
                if (!_selectionInitialized) {
                  _downloadSelected
                    ..clear()
                    ..addAll(
                      items
                          .where(
                            (DtxManageItem managed) =>
                                managed.item.isOfficial &&
                                managed.item.updateAvailable &&
                                !managed.excluded,
                          )
                          .map(
                            (DtxManageItem managed) => managed.item.fileName,
                          ),
                    );
                  _excludedFiles
                    ..clear()
                    ..addAll(
                      items
                          .where((DtxManageItem managed) => managed.excluded)
                          .map(
                            (DtxManageItem managed) => managed.item.fileName,
                          ),
                    );
                  _selectionInitialized = true;
                }

                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.statusDownloadSummaryNone),
                  );
                }

                final Map<String, List<DtxManageItem>> grouped =
                    <String, List<DtxManageItem>>{};
                for (final DtxManageItem managed in items) {
                  final String group = _displayGroup(managed, context);
                  grouped
                      .putIfAbsent(group, () => <DtxManageItem>[])
                      .add(managed);
                }

                final List<_DtxManagerListEntry> entries =
                    <_DtxManagerListEntry>[];
                for (final MapEntry<String, List<DtxManageItem>> entry
                    in grouped.entries) {
                  entries.add(_DtxManagerListEntry.header(entry.key));
                  for (final DtxManageItem managed in entry.value) {
                    entries.add(_DtxManagerListEntry.item(managed));
                  }
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.downloadManagerNameColumn,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            SizedBox(
                              width: 92,
                              child: Text(
                                l10n.downloadManagerUpdateColumn,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            SizedBox(
                              width: 92,
                              child: Text(
                                l10n.downloadManagerExcludedColumn,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          itemBuilder: (BuildContext context, int index) {
                            final _DtxManagerListEntry entry = entries[index];
                            if (entry.isHeader) {
                              final List<DtxManageItem> groupItems =
                                  grouped[entry.group!] ??
                                  const <DtxManageItem>[];
                              final bool hasDownloadEligible = groupItems.any(
                                (DtxManageItem item) =>
                                    item.item.isOfficial &&
                                    item.item.updateAvailable,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 2,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        '[${entry.group!}]',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 92,
                                      child: Center(
                                        child: Checkbox(
                                          tristate: true,
                                          value: _groupDownloadValue(
                                            groupItems,
                                          ),
                                          onChanged: hasDownloadEligible
                                              ? (bool? checked) {
                                                  setState(() {
                                                    for (final DtxManageItem
                                                        item
                                                        in groupItems) {
                                                      if (!item
                                                              .item
                                                              .isOfficial ||
                                                          !item
                                                              .item
                                                              .updateAvailable) {
                                                        continue;
                                                      }
                                                      if (checked == true) {
                                                        _downloadSelected.add(
                                                          item.item.fileName,
                                                        );
                                                        _excludedFiles.remove(
                                                          item.item.fileName,
                                                        );
                                                      } else {
                                                        _downloadSelected
                                                            .remove(
                                                              item
                                                                  .item
                                                                  .fileName,
                                                            );
                                                      }
                                                    }
                                                  });
                                                }
                                              : null,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 92,
                                      child: Center(
                                        child: Checkbox(
                                          tristate: true,
                                          value: _groupExcludedValue(
                                            groupItems,
                                          ),
                                          onChanged: (bool? checked) {
                                            setState(() {
                                              for (final DtxManageItem item
                                                  in groupItems) {
                                                if (checked == true) {
                                                  _excludedFiles.add(
                                                    item.item.fileName,
                                                  );
                                                  _downloadSelected.remove(
                                                    item.item.fileName,
                                                  );
                                                } else {
                                                  _excludedFiles.remove(
                                                    item.item.fileName,
                                                  );
                                                }
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final DtxManageItem managed = entry.item!;
                            final DtxDownloadItem item = managed.item;
                            final bool canUpdate =
                                item.isOfficial && item.updateAvailable;
                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(item.longName),
                                      subtitle: Text(
                                        _subtitleFor(item, context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 92,
                                    child: Center(
                                      child: canUpdate
                                          ? Checkbox(
                                              value: _downloadSelected.contains(
                                                item.fileName,
                                              ),
                                              onChanged: (bool? checked) {
                                                setState(() {
                                                  if (checked ?? false) {
                                                    _downloadSelected.add(
                                                      item.fileName,
                                                    );
                                                    _excludedFiles.remove(
                                                      item.fileName,
                                                    );
                                                  } else {
                                                    _downloadSelected.remove(
                                                      item.fileName,
                                                    );
                                                  }
                                                });
                                              },
                                            )
                                          : const Icon(Icons.remove, size: 16),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 92,
                                    child: Center(
                                      child: Checkbox(
                                        value: _excludedFiles.contains(
                                          item.fileName,
                                        ),
                                        onChanged: (bool? checked) {
                                          setState(() {
                                            if (checked ?? false) {
                                              _excludedFiles.add(item.fileName);
                                              _downloadSelected.remove(
                                                item.fileName,
                                              );
                                            } else {
                                              _excludedFiles.remove(
                                                item.fileName,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
        FilledButton(
          onPressed: widget.controller.downloadInProgress
              ? null
              : () => Navigator.of(context).pop(
                  _DtxManagerDialogResult(
                    downloadSelected: Set<String>.from(_downloadSelected),
                    excludedSelected: Set<String>.from(_excludedFiles),
                  ),
                ),
          child: Text(l10n.apply),
        ),
      ],
    );
  }

  Future<void> _importDtxFiles(BuildContext context) async {
    const XTypeGroup dtxType = XTypeGroup(
      label: 'DTX',
      extensions: <String>['dtx'],
    );
    final List<XFile> files = Platform.isAndroid
        ? await openFiles()
        : await openFiles(acceptedTypeGroups: <XTypeGroup>[dtxType]);
    if (files.isEmpty || !context.mounted) {
      return;
    }
    try {
      final DtxImportResult result = await widget.controller.importDtxFiles(
        files,
      );
      if (!context.mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      if (result.importedCount > 0 && !result.hasFailures) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.importDtxFilesSuccess(result.importedCount),
            ),
          ),
        );
        _reload();
        return;
      }

      if (result.importedCount > 0 && result.hasFailures) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.importDtxFilesPartial(
                result.importedCount,
                result.failedCount,
                result.shortFailureSummary(),
              ),
            ),
          ),
        );
        _reload();
        return;
      }

      final String reason = result.shortFailureSummary();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.importDtxFilesErrorDetailed(reason)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final String details = e.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            details.isEmpty
                ? context.l10n.importDtxFilesError
                : context.l10n.importDtxFilesErrorDetailed(details),
          ),
        ),
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
      context.l10n.ungroupedBookGroupLabel,
    );
    final int initial = controller.diaVirtualBookSelected
        ? _diaVirtualBookValue
        : controller.bookIndex;
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: initial,
            decoration: InputDecoration(
              labelText: context.l10n.bookLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
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
              ...entries.asMap().entries.map((
                MapEntry<int, _BookDropdownEntry> e,
              ) {
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
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _statusTooltip(
            context,
            title: context.l10n.settingsInternetTitle,
            state: _mqttIndicatorState(controller),
          ),
          child: _statusIcon(
            icon: Icons.public,
            state: _mqttIndicatorState(controller),
            theme: theme,
          ),
        ),
      ],
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
      final ThemeData theme = Theme.of(context);
      return Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedGroup.clamp(0, groups.length - 1),
              decoration: InputDecoration(
                labelText: context.l10n.songLabel,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              isExpanded: true,
              items: groups.asMap().entries.map((
                MapEntry<int, _DiaSongGroup> e,
              ) {
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
                controller.selectCustomOrderEntryAt(
                  verses.first.customOrderIndex,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _statusTooltip(
              context,
              title: context.l10n.settingsLocalNetworkTitle,
              state: _localNetworkIndicatorState(controller),
            ),
            child: _statusIcon(
              icon: Icons.lan,
              state: _localNetworkIndicatorState(controller),
              theme: theme,
            ),
          ),
        ],
      );
    }

    final DtxBook? b = controller.currentBook;
    final List<DtxSong> songs = b?.songs ?? const <DtxSong>[];
    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: controller.songIndex.clamp(0, songs.length - 1),
            decoration: InputDecoration(
              labelText: context.l10n.songLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
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
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
            onChanged: (int? value) {
              if (value != null) {
                controller.setSongIndex(value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _statusTooltip(
            context,
            title: context.l10n.settingsLocalNetworkTitle,
            state: _localNetworkIndicatorState(controller),
          ),
          child: _statusIcon(
            icon: Icons.lan,
            state: _localNetworkIndicatorState(controller),
            theme: theme,
          ),
        ),
      ],
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
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final bool showTitle = controller.settings.projUseTitle;
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
        final double titleHeight = showTitle ? titlePainter.height + 10 : 0;
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

        return _SwipePagingPreview(
          controller: controller,
          child: constraints.maxHeight.isFinite
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showTitle) ...<Widget>[
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
                    ],
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
                    if (showTitle) ...<Widget>[
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
                    ],
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
    final bool showTitle = controller.settings.projUseTitle;
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
        final double titleHeight = showTitle ? titlePainter.height + 10 : 0;
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

        return _SwipePagingPreview(
          controller: controller,
          child: constraints.maxHeight.isFinite
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showTitle) ...<Widget>[
                      Text(
                        fullTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 10),
                    ],
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
                    if (showTitle) ...<Widget>[
                      Text(
                        fullTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 10),
                    ],
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

    final Widget content = !exists
        ? Align(
            alignment: Alignment.topLeft,
            child: Text(context.l10n.statusImageNotFound(friendlyPath)),
          )
        : SizedBox.expand(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(f, fit: BoxFit.contain),
            ),
          );

    return _SwipePagingPreview(controller: controller, child: content);
  }
}

class _SwipePagingPreview extends StatefulWidget {
  const _SwipePagingPreview({required this.controller, required this.child});

  final DiatarMainController controller;
  final Widget child;

  @override
  State<_SwipePagingPreview> createState() => _SwipePagingPreviewState();
}

class _SwipePagingPreviewState extends State<_SwipePagingPreview> {
  double _dragDx = 0;

  bool _isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
  }

  void _resetDrag() {
    if (_dragDx == 0) {
      return;
    }
    _dragDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TargetPlatform platform = Theme.of(context).platform;
        final bool desktopLike = _isDesktopPlatform(platform);
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final double maxDrag = width * (desktopLike ? 0.30 : 0.40);
        final double distanceThreshold = width * (desktopLike ? 0.20 : 0.14);
        final double swipeVelocityThreshold = desktopLike ? 420.0 : 220.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.controller.toggleShowing,
          onHorizontalDragStart: (_) => _dragDx = 0,
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            _dragDx = (_dragDx + details.delta.dx)
                .clamp(-maxDrag, maxDrag)
                .toDouble();
          },
          onHorizontalDragCancel: _resetDrag,
          onHorizontalDragEnd: (DragEndDetails details) {
            final double velocityDx = details.velocity.pixelsPerSecond.dx;

            final bool goPrev =
                velocityDx > swipeVelocityThreshold ||
                _dragDx > distanceThreshold;
            final bool goNext =
                velocityDx < -swipeVelocityThreshold ||
                _dragDx < -distanceThreshold;

            _resetDrag();

            if (goPrev) {
              widget.controller.prevVerse();
            } else if (goNext) {
              widget.controller.nextVerse();
            }
          },
          child: widget.child,
        );
      },
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
        padding: const EdgeInsets.all(7),
        minimumSize: const Size(44, 44),
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
      child: child ?? Icon(icon!, size: 22),
    ),
  );
}
