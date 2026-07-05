import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/books/book_sort_policy.dart';
import '../core/custom_order/custom_order_normalizer.dart';
import '../core/custom_order/custom_order_navigation_policy.dart';
import '../core/custom_order/entry_label_service.dart';
import '../core/custom_order/entry_match_policy.dart';
import '../core/custom_order/entry_resolver.dart';
import '../core/dia/dia_ini_parser.dart';
import '../core/dia/dia_matching_policy.dart';
import '../core/dia/dia_path_policy.dart';
import '../core/navigation/song_navigation_policy.dart';
import '../core/navigation/song_selection_policy.dart';
import '../models/custom_order_entry.dart';
import '../services/mqtt_sender_service.dart';
import '../services/dtx_download_service.dart';
import '../services/dtx_order_store.dart';
import '../services/settings_store.dart';
import '../services/tcp_sender_service.dart';
import '../services/zsolozsma_decode_breviar.dart';
import '../services/zsolozsma_service.dart';

export '../models/custom_order_entry.dart';

class SongbookOrderItem {
  const SongbookOrderItem({
    required this.fileName,
    required this.title,
    required this.group,
    required this.enabled,
  });

  final String fileName;
  final String title;
  final String group;
  final bool enabled;
}

class CustomOrderCandidate {
  const CustomOrderCandidate({
    required this.fileName,
    required this.bookTitle,
    required this.songIndex,
    required this.songTitle,
  });

  final String fileName;
  final String bookTitle;
  final int songIndex;
  final String songTitle;

  String get label => '$bookTitle: $songTitle';
}

class DtxImportResult {
  const DtxImportResult({required this.importedCount, required this.failures});

  final int importedCount;
  final List<String> failures;

  int get failedCount => failures.length;

  bool get hasFailures => failures.isNotEmpty;

  String shortFailureSummary({int maxItems = 3}) {
    final List<String> items = failures.take(maxItems).toList();
    if (items.isEmpty) {
      return '';
    }
    if (failures.length > maxItems) {
      final int rest = failures.length - maxItems;
      return '${items.join('; ')} (+$rest more)';
    }
    return items.join('; ');
  }
}

class DtxManageItem {
  const DtxManageItem({required this.item, required this.excluded});

  final DtxDownloadItem item;
  final bool excluded;
}

class DiatarMainController extends ChangeNotifier {
  final DtxParser _parser = const DtxParser();
  final DiaIniParser _diaIniParser = const DiaIniParser();
  final DiaMatchingPolicy _diaMatchingPolicy = const DiaMatchingPolicy();
  final DiaPathPolicy _diaPathPolicy = const DiaPathPolicy();
  final BookSortPolicy _bookSortPolicy = const BookSortPolicy();
    final SongNavigationPolicy _songNavigationPolicy =
      const SongNavigationPolicy();
    final SongSelectionPolicy _songSelectionPolicy =
      const SongSelectionPolicy();
  final CustomOrderNavigationPolicy _customOrderNavigationPolicy =
      const CustomOrderNavigationPolicy();
  final EntryResolver _entryResolver = const EntryResolver();
  late final EntryMatchPolicy _entryMatchPolicy = EntryMatchPolicy(
    resolver: _entryResolver,
  );
  late final EntryLabelService _entryLabelService = EntryLabelService(
    resolver: _entryResolver,
  );
  late final CustomOrderNormalizer _customOrderNormalizer =
      CustomOrderNormalizer(
        resolver: _entryResolver,
        labelService: _entryLabelService,
      );
  final SettingsStore _settingsStore = SettingsStore();
  final DtxDownloadService _downloadService = DtxDownloadService();
  final DtxOrderStore _orderStore = DtxOrderStore();
  final ZsolozsmaService _zsolozsmaService = ZsolozsmaService();
  final ZsolozsmaBreviarDecoder _zsolozsmaDecoder = ZsolozsmaBreviarDecoder();
  final TcpSenderService _sender = TcpSenderService(
    onStatusChanged: (bool connected) {},
    onError: (String code, Map<String, String> params) {},
  );
  final MqttSenderService _mqttSender = MqttSenderService(
    onStatusChanged: (bool connected) {},
    onError: (String code, Map<String, String> params) {},
  );

  List<DtxBook> books = <DtxBook>[];
  int bookIndex = 0;
  int songIndex = 0;
  int verseIndex = 0;
  int highPos = 0;
  int _renderedHighlightWordCount = -1;
  bool _highlightFullyRendered = false;
  bool showing = false;
  bool loading = false;
  AppSettings settings = const AppSettings();
  ProjectionGlobals globals = const ProjectionGlobals();
  bool senderRunning = false;
  bool senderConnected = false;
  bool mqttActive = false;
  bool mqttConnected = false;
  bool tcpConnected = false;
  bool mqttHasError = false;
  bool tcpHasError = false;
  DateTime? mqttConnectAttemptAt;
  DateTime? tcpConnectAttemptAt;
  int _mqttErrorSeq = 0;
  int _tcpErrorSeq = 0;
  String statusCode = 'statusStarting';
  Map<String, String> _statusParams = <String, String>{};
  String lastPicPath = '';
  String lastBlankPath = '';
  bool downloadInProgress = false;
  int downloadCurrentFile = 0;
  int downloadTotalFiles = 0;
  String downloadCurrentName = '';
  double downloadCurrentFraction = 0;
  int _screenWidth = 1920;
  int _screenHeight = 1080;
  Set<String> _disabledSongbooks = <String>{};
  List<CustomOrderEntry> _customOrder = <CustomOrderEntry>[];
  bool customOrderActive = false;
  int _customOrderCursor = -1;
  int _projectedCustomCursor = -1;
  String? _lastImportedCustomOrderBaseName;
  bool _diaVirtualBookSelected = false;
  bool _startupDownloadDialogHandled = false;
  String _zsolozsmaLastDiagnostics = '';
  static const String _customOrderSourceZsolozsmaUnsaved = 'zsolozsma-unsaved';
  String? _customOrderSourceType;
  String? _zsolozsmaVirtualBookLabel;

  Map<String, String> get statusParams =>
      Map<String, String>.unmodifiable(_statusParams);

  void _resetHighlightRenderState() {
    _renderedHighlightWordCount = -1;
    _highlightFullyRendered = false;
  }

  void updateHighlightRenderState({
    required int maxWordIndex,
    required bool isFullyHighlighted,
  }) {
    final int normalizedMax = math.max(0, maxWordIndex);
    _renderedHighlightWordCount = normalizedMax;
    _highlightFullyRendered = isFullyHighlighted && normalizedMax > 0;
    if (highPos > normalizedMax) {
      highPos = normalizedMax;
      notifyListeners();
      unawaited(_syncHighlightOnly());
    }
  }

  String? get lastImportedCustomOrderBaseName =>
      _lastImportedCustomOrderBaseName;
  bool get customOrderIsUnsavedZsolozsma =>
      _customOrder.isNotEmpty &&
      _customOrderSourceType == _customOrderSourceZsolozsmaUnsaved;
  String? get zsolozsmaVirtualBookLabel =>
      customOrderIsUnsavedZsolozsma ? _zsolozsmaVirtualBookLabel : null;
  String? get suggestedCustomOrderBaseName {
    final String? zsolozsmaLabel = zsolozsmaVirtualBookLabel?.trim();
    if (zsolozsmaLabel != null && zsolozsmaLabel.isNotEmpty) {
      return zsolozsmaLabel;
    }
    return lastImportedCustomOrderBaseName;
  }

  bool get customOrderLooksLikeZsolozsma =>
      _customOrder.isNotEmpty &&
      _customOrder.every(
        (CustomOrderEntry entry) =>
            entry.isCustomText && entry.label.startsWith('[Zsolozsma]'),
      );
  String get zsolozsmaLastDiagnostics => _zsolozsmaLastDiagnostics;
  bool get hasImportedCustomOrderDia => _customOrder.isNotEmpty;
  bool get diaVirtualBookSelected =>
      _diaVirtualBookSelected && hasImportedCustomOrderDia;
  bool get shouldAutoOpenDownloadDialog =>
      !_startupDownloadDialogHandled &&
      !loading &&
      statusCode == 'statusNoDtxFiles';
  bool get tcpActive => settings.tcpClientEnabled;
  bool get tcpConfigured =>
      tcpActive &&
      settings.tcpTargets
          .map((String target) => target.trim())
          .any((String target) => target.isNotEmpty);

  void _refreshSenderFlags() {
    senderRunning = _sender.running || _mqttSender.running;
    senderConnected = tcpConnected || mqttConnected;
  }

  void markStartupDownloadDialogHandled() {
    _startupDownloadDialogHandled = true;
  }

  void _setStatus(
    String code, [
    Map<String, String> params = const <String, String>{},
  ]) {
    statusCode = code;
    _statusParams = Map<String, String>.from(params);
  }

  int _safeVerseIndex(CustomOrderEntry entry, {int fallback = 0}) {
    return _customOrderNormalizer.safeVerseIndex(entry, fallback: fallback);
  }

  bool get _hasConfiguredBackgroundImage =>
      settings.blankPicPath.trim().isNotEmpty;

  Future<void> init() async {
    settings = await _settingsStore.load();
    lastBlankPath = settings.blankPicPath;
    _disabledSongbooks = await _orderStore.loadDisabled();
    final ({
      List<StoredCustomOrderEntry> entries,
      bool active,
      String? baseName,
      String? sourceType,
      String? zsolozsmaLabel,
    })
    stored = await _orderStore.loadCurrentCustomOrder();
    _customOrder = stored.entries
        .map(
          (StoredCustomOrderEntry e) => CustomOrderEntry(
            fileName: e.fileName,
            songIndex: e.songIndex,
            verseIndex: e.verseIndex,
            label: e.label,
            customTextTitle: e.customTextTitle,
            customTextBody: e.customTextBody,
            customImagePath: e.customImagePath,
            customType: e.customType,
            customData: e.customData,
            storageExtras: e.additionalFields,
          ),
        )
        .toList();
    customOrderActive = stored.active && _customOrder.isNotEmpty;
    _lastImportedCustomOrderBaseName = _customOrder.isEmpty
        ? null
        : stored.baseName;
    _customOrderSourceType = _customOrder.isEmpty ? null : stored.sourceType;
    _zsolozsmaVirtualBookLabel = _customOrder.isEmpty
        ? null
        : stored.zsolozsmaLabel;
    _customOrderCursor = customOrderActive ? 0 : -1;
    _diaVirtualBookSelected = _customOrder.isNotEmpty;
    globals = globals.copyWith(
      bkColor: settings.bkColor,
      txtColor: settings.txtColor,
      blankColor: settings.blankColor,
      hiColor: settings.hiColor,
      isBlankPic: _hasConfiguredBackgroundImage,
      showBlankPic:
          _hasConfiguredBackgroundImage && settings.projShowBackgroundImage,
      projecting: showing,
      fontSize: settings.projFontSize,
      titleSize: settings.projTitleSize,
      leftIndent: settings.projLeftIndent,
      borderL: settings.projBorderL,
      borderT: settings.projBorderT,
      borderR: settings.projBorderR,
      borderB: settings.projBorderB,
      spacing100: 100 + settings.projSpacingStep * 10,
      autoResize: settings.projAutoSize,
      hCenter: settings.projHCenter,
      vCenter: settings.projVCenter,
      useAkkord: settings.projUseAkkord,
      useKotta: settings.projUseKotta,
      hideTitle: !settings.projUseTitle,
      kottaArany: settings.projKottaArany,
      akkordArany: settings.projAkkordArany,
      bgMode: settings.projBgMode,
      backTrans: settings.projBackTrans,
      blankTrans: settings.projBlankTrans,
      boldText: settings.projBoldText,
    );
    _configureSender();
    await _applyTransport();
    await reloadBooks();
    await _tryAutoLoadTodayDia();
    if (customOrderActive &&
        _customOrderCursor >= 0 &&
        _customOrderCursor < _customOrder.length &&
        !_customOrder[_customOrderCursor].isSongEntry) {
      await _projectCustomOrderEntry(
        _customOrder[_customOrderCursor],
        cursor: _customOrderCursor,
      );
    } else {
      await _syncCurrentDia();
    }
  }

  Future<void> _tryAutoLoadTodayDia() async {
    final String basePath = settings.diaExportPath.trim();
    if (basePath.isEmpty) {
      return;
    }

    final Directory dir = Directory(basePath);
    if (!await dir.exists()) {
      return;
    }

    final DateTime now = DateTime.now();
    final int year4 = now.year;
    final int year2 = now.year % 100;
    final int month = now.month;
    final int day = now.day;

    final String yyyy = year4.toString().padLeft(4, '0');
    final String yy = year2.toString().padLeft(2, '0');
    final String mm = month.toString().padLeft(2, '0');
    final String dd = day.toString().padLeft(2, '0');
    final String m = month.toString();
    final String d = day.toString();

    final List<String> baseNames = <String>[
      '$yyyy-$mm-$dd',
      '$yy-$mm-$dd',
      '$yyyy-$m-$d',
      '$yy-$m-$d',
      '$yyyy.$mm.$dd',
      '$yy.$mm.$dd',
      '$yyyy.$m.$d',
      '$yy.$m.$d',
    ];

    for (final String name in baseNames) {
      final File candidate = File('${dir.path}/$name.dia');
      if (await candidate.exists()) {
        await importCustomOrderFromDia(candidate.path, activate: true);
        return;
      }
    }
  }

  void _configureSender() {
    _sender.onStatusChanged = (bool connected) {
      tcpConnected = connected;
      if (connected) {
        tcpHasError = false;
        unawaited(_syncBackgroundImageAfterConnect());
      }
      _refreshSenderFlags();
      notifyListeners();
    };
    _sender.onError = (String code, Map<String, String> params) {
      _tcpErrorSeq++;
      final int token = _tcpErrorSeq;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (token != _tcpErrorSeq || !tcpActive || tcpConnected) {
          return;
        }
        tcpHasError = true;
        switch (code) {
          case 'senderTcpError':
            _setStatus('statusSenderTcpError', <String, String>{
              'error': params['error'] ?? '',
            });
            break;
          case 'senderOpenPortFailed':
            _setStatus('statusSenderOpenPortFailed', <String, String>{
              'port': params['port'] ?? '0',
              'error': params['error'] ?? '',
            });
            break;
          default:
            _setStatus('statusSenderError', <String, String>{'message': code});
            break;
        }
        _refreshSenderFlags();
        notifyListeners();
      });
    };
    _mqttSender.onStatusChanged = (bool connected) {
      mqttConnected = connected;
      if (connected) {
        mqttHasError = false;
        unawaited(_syncBackgroundImageAfterConnect());
      }
      _refreshSenderFlags();
      notifyListeners();
    };
    _mqttSender.onError = (String code, Map<String, String> params) {
      _mqttErrorSeq++;
      final int token = _mqttErrorSeq;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (token != _mqttErrorSeq || !mqttActive || mqttConnected) {
          return;
        }
        mqttHasError = true;
        switch (code) {
          case 'senderMqttConnectFailed':
            _setStatus('statusSenderMqttConnectFailed');
            break;
          case 'senderMqttError':
            _setStatus('statusSenderMqttError', <String, String>{
              'error': params['error'] ?? '',
            });
            break;
          default:
            _setStatus('statusSenderError', <String, String>{'message': code});
            break;
        }
        _refreshSenderFlags();
        notifyListeners();
      });
    };
  }

  Future<void> applySettings(AppSettings newSettings) async {
    final AppSettings previousSettings = settings;
    final bool transportChanged = _transportSettingsChanged(
      previousSettings,
      newSettings,
    );
    settings = newSettings;
    lastBlankPath = settings.blankPicPath;
    await _settingsStore.save(settings);
    globals = globals.copyWith(
      bkColor: settings.bkColor,
      txtColor: settings.txtColor,
      blankColor: settings.blankColor,
      hiColor: settings.hiColor,
      isBlankPic: _hasConfiguredBackgroundImage,
      showBlankPic:
          _hasConfiguredBackgroundImage && settings.projShowBackgroundImage,
      fontSize: settings.projFontSize,
      titleSize: settings.projTitleSize,
      leftIndent: settings.projLeftIndent,
      borderL: settings.projBorderL,
      borderT: settings.projBorderT,
      borderR: settings.projBorderR,
      borderB: settings.projBorderB,
      spacing100: 100 + settings.projSpacingStep * 10,
      autoResize: settings.projAutoSize,
      hCenter: settings.projHCenter,
      vCenter: settings.projVCenter,
      useAkkord: settings.projUseAkkord,
      useKotta: settings.projUseKotta,
      hideTitle: !settings.projUseTitle,
      kottaArany: settings.projKottaArany,
      akkordArany: settings.projAkkordArany,
      bgMode: settings.projBgMode,
      backTrans: settings.projBackTrans,
      blankTrans: settings.projBlankTrans,
      boldText: settings.projBoldText,
    );
    if (transportChanged) {
      await _applyTransport();
    } else {
      _refreshSenderFlags();
    }
    notifyListeners();
    await _syncCurrentDia();
    await _syncBackgroundImageAfterConnect();
  }

  Future<void> setHomeViewMode(int mode) async {
    if (settings.homeViewMode == mode) {
      return;
    }
    settings = settings.copyWith(homeViewMode: mode);
    await _settingsStore.save(settings);
    notifyListeners();
  }

  bool _transportSettingsChanged(AppSettings previous, AppSettings next) {
    final bool mqttChanged = _mqttSettingsChanged(previous, next);
    final bool tcpChanged = _tcpSettingsChanged(previous, next);
    return mqttChanged || tcpChanged;
  }

  bool _mqttSettingsChanged(AppSettings previous, AppSettings next) {
    if (previous.internetRelayEnabled != next.internetRelayEnabled) {
      return true;
    }
    if (!previous.internetRelayEnabled && !next.internetRelayEnabled) {
      return false;
    }
    return previous.mqttUser.trim() != next.mqttUser.trim() ||
        previous.mqttPassword != next.mqttPassword ||
        previous.mqttChannel.trim() != next.mqttChannel.trim();
  }

  bool _tcpSettingsChanged(AppSettings previous, AppSettings next) {
    if (previous.tcpClientEnabled != next.tcpClientEnabled) {
      return true;
    }
    if (!previous.tcpClientEnabled && !next.tcpClientEnabled) {
      return false;
    }
    return !listEquals(
      _normalizedTcpTargets(previous),
      _normalizedTcpTargets(next),
    );
  }

  List<String> _normalizedTcpTargets(AppSettings value) {
    return value.tcpTargets
        .map((String target) => target.trim())
        .where((String target) => target.isNotEmpty)
        .toList();
  }

  Future<void> _sendProjectionState() async {
    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
    if (tcpConfigured) {
      await _sender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
    _refreshSenderFlags();
  }

  Future<void> _syncBackgroundImageAfterConnect() async {
    final String path = settings.blankPicPath.trim();
    final bool enabled = settings.projShowBackgroundImage;

    globals = globals.copyWith(
      isBlankPic: path.isNotEmpty,
      showBlankPic: path.isNotEmpty && enabled,
    );

    if (_projectionOutputLocked) {
      return;
    }

    if (path.isEmpty || !enabled) {
      await _sendProjectionState();
      notifyListeners();
      return;
    }

    await sendBlankFromPath(
      path,
      showBackgroundImage: enabled,
      persistPath: false,
      updateStatus: false,
    );
    notifyListeners();
  }

  Future<Directory> _resolveDtxDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/diatar/DTXs');
  }

  Future<Directory> _resolveZsolozsmaDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/zsolozsma');
  }

  String _displayNameForImportedFile(XFile xf, int index) {
    final String directName = xf.name.trim();
    if (directName.isNotEmpty) {
      return directName;
    }

    final Uri? parsed = Uri.tryParse(xf.path);
    if (parsed != null && parsed.pathSegments.isNotEmpty) {
      final String last = Uri.decodeComponent(parsed.pathSegments.last).trim();
      if (last.isNotEmpty) {
        return last;
      }
    }

    final String normalized = xf.path.replaceAll('\\', '/').trim();
    if (normalized.isNotEmpty) {
      final List<String> segments = normalized.split('/');
      final String last = segments.isNotEmpty ? segments.last.trim() : '';
      if (last.isNotEmpty) {
        return last;
      }
    }

    return 'imported_${index + 1}.dtx';
  }

  String _safeImportFileName(String value, int index) {
    String name = value.trim();
    if (name.isEmpty) {
      name = 'imported_${index + 1}.dtx';
    }
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!name.toLowerCase().endsWith('.dtx')) {
      name = '$name.dtx';
    }
    return name;
  }

  /// Copies the given [files] (picked via file picker) into the internal DTX
  /// directory, then reloads books.
  Future<DtxImportResult> importDtxFiles(List<XFile> files) async {
    final Directory dtxDir = await _resolveDtxDirectory();
    await dtxDir.create(recursive: true);
    final List<String> failures = <String>[];
    final Set<String> importedFileNames = <String>{};
    int count = 0;
    for (int i = 0; i < files.length; i++) {
      final XFile xf = files[i];
      final String originalName = _displayNameForImportedFile(xf, i);
      final String targetName = _safeImportFileName(originalName, i);
      try {
        final List<int> bytes = await xf.readAsBytes();
        final String content = utf8.decode(bytes, allowMalformed: true);
        _parser.parse(fileName: targetName, content: content);
        await File('${dtxDir.path}/$targetName').writeAsBytes(bytes);
        importedFileNames.add(targetName);
        count++;
      } catch (e) {
        failures.add('$originalName: $e');
      }
    }
    if (count > 0) {
      _disabledSongbooks.removeAll(importedFileNames);
      await _orderStore.saveDisabled(_disabledSongbooks);
      await reloadBooks();
    }
    return DtxImportResult(importedCount: count, failures: failures);
  }

  Future<ZsolozsmaSyncResult> syncZsolozsmaArchives({int? centerYear}) async {
    final int year = centerYear ?? DateTime.now().year;
    final Directory dir = await _resolveZsolozsmaDirectory();
    final ZsolozsmaSyncResult result = await _zsolozsmaService
        .ensureYearArchives(storageDir: dir, centerYear: year);
    if (result.failedCount > 0) {
      _setStatus('statusZsolozsmaSyncError', <String, String>{
        'error': result.failedByYear.values.first,
      });
    } else {
      _setStatus('statusZsolozsmaSyncOk', <String, String>{
        'downloaded': '${result.downloadedYears.length}',
        'failed': '${result.failedCount}',
      });
    }
    notifyListeners();
    return result;
  }

  Future<List<ZsolozsmaDayPart>> loadZsolozsmaDayParts(
    DateTime date, {
    bool syncArchives = false,
  }) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final Directory dir = await _resolveZsolozsmaDirectory();
    if (syncArchives) {
      await syncZsolozsmaArchives(centerYear: day.year);
    }

    try {
      final ZsolozsmaDayPartsLoadResult loadResult = await _zsolozsmaService
          .listDayPartsWithDiagnostics(storageDir: dir, date: day);
      final List<ZsolozsmaDayPart> parts = loadResult.parts;
      _zsolozsmaLastDiagnostics = loadResult.diagnostics;
      final String dateLabel = _formatDateIso(day);
      if (parts.isEmpty) {
        _setStatus('statusZsolozsmaDayEmpty', <String, String>{
          'date': dateLabel,
        });
      } else {
        _setStatus('statusZsolozsmaDayLoaded', <String, String>{
          'date': dateLabel,
          'count': '${parts.length}',
        });
      }
      notifyListeners();
      return parts;
    } catch (e) {
      _zsolozsmaLastDiagnostics =
          'date=${_formatDateIso(day)}\nerror=$e\nstorageDir=${dir.path}';
      _setStatus('statusZsolozsmaDayError', <String, String>{'error': '$e'});
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> selectZsolozsmaPart(DateTime date, ZsolozsmaDayPart part) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final Directory dir = await _resolveZsolozsmaDirectory();
    _logZsolozsmaDebug(
      'select part start date=${_formatDateIso(day)} title=${part.title} href=${part.href}',
    );
    final ZsolozsmaDayPartHtmlResult loadResult = await _zsolozsmaService
        .loadDayPartHtml(storageDir: dir, date: day, part: part);
    _zsolozsmaLastDiagnostics = loadResult.diagnostics;
    _logZsolozsmaDebug('part load diagnostics:\n${loadResult.diagnostics}');

    final String? html = loadResult.html;
    if (html == null || html.trim().isEmpty) {
      _logZsolozsmaDebug('part load returned empty html for ${part.title}');
      _setStatus('statusZsolozsmaPartLoadError', <String, String>{
        'title': part.title,
      });
      notifyListeners();
      return false;
    }

    _logZsolozsmaDebug('loaded html length=${html.length}');

    final List<ZsolozsmaSlide> slides = _zsolozsmaDecoder.decode(html);
    _logZsolozsmaDebug(
      'decoded slides=${slides.length} titles=${slides.take(5).map((ZsolozsmaSlide slide) => slide.title).join(' | ')}',
    );
    final List<CustomOrderEntry> entries = slides
        .map(
          (ZsolozsmaSlide slide) => CustomOrderEntry(
            fileName: '__custom_text__',
            songIndex: -1,
            verseIndex: 0,
            label: '[Zsolozsma] ${slide.title}',
            customTextTitle: slide.title,
            customTextBody: slide.lines.join('\n'),
            customType: 'text',
          ),
        )
        .toList();

    if (entries.isEmpty) {
      _logZsolozsmaDebug('decoded entries are empty for ${part.title}');
      _setStatus('statusZsolozsmaPartLoadError', <String, String>{
        'title': part.title,
      });
      notifyListeners();
      return false;
    }

    await applyCustomOrder(entries, activate: true);
    _logZsolozsmaDebug('applyCustomOrder complete entries=${entries.length}');
    final String zsolozsmaLabel = '${_formatDateIso(day)} ${part.title.trim()}'
        .trim();
    _customOrderSourceType = _customOrderSourceZsolozsmaUnsaved;
    _zsolozsmaVirtualBookLabel = zsolozsmaLabel;
    _lastImportedCustomOrderBaseName = zsolozsmaLabel;
    await _persistCurrentCustomOrder();
    _diaVirtualBookSelected = entries.isNotEmpty;
    if (entries.isNotEmpty) {
      _selectByCustomOrderCursor(0, sync: true);
      _logZsolozsmaDebug('selected first custom order entry');
    }

    _setStatus('statusZsolozsmaPartLoaded', <String, String>{
      'date': _formatDateIso(day),
      'title': part.title,
      'count': '${entries.length}',
    });
    _logZsolozsmaDebug(
      'part loaded successfully title=${part.title} count=${entries.length}',
    );
    notifyListeners();
    return true;
  }

  void _logZsolozsmaDebug(String message) {
    debugPrint('[Zsolozsma] $message');
  }

  String _formatDateIso(DateTime date) {
    final String yy = date.year.toString().padLeft(4, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }

  Future<void> _applyTransport() async {
    final String user = settings.mqttUser.trim();
    _mqttErrorSeq++;
    _tcpErrorSeq++;
    mqttActive = settings.internetRelayEnabled && user.isNotEmpty;
    if (mqttActive) {
      mqttConnected = false;
      mqttHasError = false;
      mqttConnectAttemptAt = DateTime.now();
      await _mqttSender.open(
        username: user,
        password: settings.mqttPassword,
        channel: settings.mqttChannel,
      );
      if (mqttConnected) {
        _setStatus('statusMqttSending', <String, String>{
          'user': user,
          'channel': settings.mqttChannel,
        });
      }
    } else {
      mqttConnectAttemptAt = null;
      mqttConnected = false;
      mqttHasError = false;
      await _mqttSender.clearRetainedMessages();
      await _mqttSender.close();
    }

    if (tcpConfigured) {
      tcpConnected = false;
      tcpHasError = false;
      tcpConnectAttemptAt = DateTime.now();
      await _sender.restart(settings.tcpTargets);
      await _sender.sendScreenSize(width: _screenWidth, height: _screenHeight);
      if (tcpConnected) {
        _setStatus('statusTcpSending', <String, String>{
          'port': _tcpTargetsStatusLabel(settings),
        });
      }
    } else {
      tcpConnectAttemptAt = null;
      tcpConnected = false;
      tcpHasError = false;
      await _sender.stop();
    }
    _refreshSenderFlags();
  }

  bool get _projectionOutputLocked => settings.projectionLocked;

  String _tcpTargetsStatusLabel(AppSettings value) {
    if (!value.tcpClientEnabled || value.tcpTargets.isEmpty) {
      return '-';
    }
    final List<String> targets = value.tcpTargets
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    if (targets.isEmpty) {
      return '-';
    }
    if (targets.length == 1) {
      return targets.first;
    }
    return '${targets.first} (+${targets.length - 1})';
  }

  Future<void> updateScreenSize({
    required int width,
    required int height,
  }) async {
    final int normalizedW = width < 1 ? 1 : width;
    final int normalizedH = height < 1 ? 1 : height;
    if (normalizedW == _screenWidth && normalizedH == _screenHeight) {
      return;
    }
    _screenWidth = normalizedW;
    _screenHeight = normalizedH;

    if (tcpConfigured && !_projectionOutputLocked) {
      await _sender.sendScreenSize(width: _screenWidth, height: _screenHeight);
    }
  }

  Future<void> reloadBooks() async {
    loading = true;
    notifyListeners();

    try {
      final List<DtxBook> loaded = await _loadBooksFromDisk();
      final List<DtxBook> enabled = loaded
          .where((DtxBook b) => !_disabledSongbooks.contains(b.fileName))
          .toList();

      if (loaded.isEmpty) {
        books = const <DtxBook>[];
        final Directory dtxDir = await _resolveDtxDirectory();
        _setStatus('statusNoDtxFiles', <String, String>{'path': dtxDir.path});
      } else if (enabled.isEmpty) {
        books = const <DtxBook>[];
        _setStatus('statusAllSongbooksDisabled');
      } else {
        enabled.sort(_compareBooksLikeAndroid);
        books = enabled;
        _setStatus('statusSongbooksLoaded', <String, String>{
          'count': '${enabled.length}',
        });
      }

      bookIndex = 0;
      songIndex = 0;
      verseIndex = 0;
      highPos = 0;
      _resetHighlightRenderState();
      _customOrder = _customOrder.where((CustomOrderEntry e) {
        if (!e.isSongEntry) {
          return true;
        }
        final int bIx = books.indexWhere(
          (DtxBook b) => b.fileName == e.fileName,
        );
        if (bIx < 0) {
          return false;
        }
        if (e.songIndex < 0 || e.songIndex >= books[bIx].songs.length) {
          return false;
        }
        final DtxSong s = books[bIx].songs[e.songIndex];
        if (s.verses.isEmpty) {
          return _safeVerseIndex(e) == 0;
        }
        final int verse = _safeVerseIndex(e);
        return verse >= 0 && verse < s.verses.length;
      }).toList();
      if (_customOrder.isEmpty) {
        customOrderActive = false;
        _customOrderCursor = -1;
      } else {
        _customOrderCursor = _customOrderCursor.clamp(
          0,
          _customOrder.length - 1,
        );
        if (customOrderActive) {
          _selectByCustomOrderCursor(_customOrderCursor, sync: false);
        }
      }
      await _persistCurrentCustomOrder();
    } catch (e) {
      _setStatus('statusLoadError', <String, String>{'error': '$e'});
      books = const <DtxBook>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<DtxBook>> _loadBooksFromDisk() async {
    final Directory dtxDir = await _resolveDtxDirectory();
    final List<DtxBook> loaded = <DtxBook>[];

    if (!await dtxDir.exists()) {
      return loaded;
    }

    final List<FileSystemEntity> children = dtxDir.listSync();
    children.sort(
      (FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path),
    );
    for (final FileSystemEntity child in children) {
      if (child is! File || !child.path.toLowerCase().endsWith('.dtx')) {
        continue;
      }
      try {
        final String content = await child.readAsString();
        loaded.add(
          _parser.parse(
            fileName: child.uri.pathSegments.isNotEmpty
                ? child.uri.pathSegments.last
                : child.path,
            content: content,
          ),
        );
      } catch (_) {
        // Invalid dtx files are skipped to keep the app usable.
      }
    }
    return loaded;
  }

  Future<List<SongbookOrderItem>> loadSongbookOrderItems() async {
    final List<DtxBook> allBooks = await _loadBooksFromDisk();
    allBooks.sort(_compareBooksLikeAndroid);
    return allBooks
        .map(
          (DtxBook b) => SongbookOrderItem(
            fileName: b.fileName,
            title: b.displayName,
            group: b.group,
            enabled: !_disabledSongbooks.contains(b.fileName),
          ),
        )
        .toList();
  }

  Future<void> applySongbookOrder(Map<String, bool> enabledByFile) async {
    final Set<String> disabled = <String>{};
    enabledByFile.forEach((String fileName, bool enabled) {
      if (!enabled) {
        disabled.add(fileName);
      }
    });
    _disabledSongbooks = disabled;
    await _orderStore.saveDisabled(_disabledSongbooks);
    await reloadBooks();
  }

  List<CustomOrderEntry> get customOrder =>
      List<CustomOrderEntry>.unmodifiable(_customOrder);
  int get customOrderCursor => _customOrderCursor;
  int get selectedCustomOrderCursor {
    if (_projectedCustomCursor >= 0 &&
        _projectedCustomCursor < _customOrder.length) {
      return _projectedCustomCursor;
    }
    if (_customOrderCursor >= 0 && _customOrderCursor < _customOrder.length) {
      return _customOrderCursor;
    }
    return _customOrder.isEmpty ? -1 : 0;
  }

  CustomOrderEntry? get projectedCustomOrderEntry {
    if (_projectedCustomCursor < 0 ||
        _projectedCustomCursor >= _customOrder.length) {
      return null;
    }
    return _customOrder[_projectedCustomCursor];
  }

  bool isCustomOrderIndexCurrent(int index) {
    if (index < 0 || index >= _customOrder.length) {
      return false;
    }
    return customOrderActive && _customOrderCursor == index;
  }

  void projectCustomOrderAt(int index) {
    if (index < 0 || index >= _customOrder.length) {
      return;
    }
    _selectByCustomOrderCursor(index, sync: true);
  }

  void selectCustomOrderEntryAt(int index) {
    if (index < 0 || index >= _customOrder.length) {
      return;
    }
    customOrderActive = _customOrder.isNotEmpty;
    _diaVirtualBookSelected = _customOrder.isNotEmpty;
    _selectByCustomOrderCursor(index, sync: true);
  }

  void selectCustomOrderEntryForEditing(int index) {
    if (index < 0 || index >= _customOrder.length) {
      return;
    }
    customOrderActive = _customOrder.isNotEmpty;
    _diaVirtualBookSelected = _customOrder.isNotEmpty;
    _customOrderCursor = index;
    _setStatus('statusCustomOrderSelected', <String, String>{
      'label': _customOrder[index].label,
    });
    notifyListeners();
  }

  void selectDiaVirtualBook() {
    if (_customOrder.isEmpty) {
      return;
    }
    _diaVirtualBookSelected = true;
    customOrderActive = true;
    int target = _customOrderCursor;
    if (target < 0 ||
        target >= _customOrder.length ||
        _customOrder[target].isSeparator) {
      target = _findNextProjectableCustomOrderIndex(0) ?? 0;
    }
    _selectByCustomOrderCursor(target, sync: true);
  }

  void selectBookControlMode() {
    customOrderActive = _customOrder.isNotEmpty;

    final CustomOrderEntry? projected = projectedCustomOrderEntry;
    final bool keepProjectedCustom =
        projected != null && !projected.isSongEntry;
    if (keepProjectedCustom) {
      _diaVirtualBookSelected = _customOrder.isNotEmpty;
      notifyListeners();
      return;
    }

    _diaVirtualBookSelected = false;
    _projectedCustomCursor = -1;
    notifyListeners();
    unawaited(_syncCurrentDia());
  }

  bool isEntryCurrentlyProjected(CustomOrderEntry entry) {
    final DtxBook? b = currentBook;
    if (b == null) {
      return false;
    }
    return b.fileName == entry.fileName &&
        songIndex == entry.songIndex &&
        verseIndex == _safeVerseIndex(entry);
  }

  Future<void> _persistCurrentCustomOrder() async {
    await _orderStore.saveCurrentCustomOrder(
      _customOrder
          .map(
            (CustomOrderEntry e) => StoredCustomOrderEntry(
              fileName: e.fileName,
              songIndex: e.songIndex,
              verseIndex: _safeVerseIndex(e),
              label: e.label,
              customTextTitle: e.customTextTitle,
              customTextBody: e.customTextBody,
              customImagePath: e.customImagePath,
              customType: e.customType,
              customData: e.customData,
              additionalFields: e.storageExtras,
            ),
          )
          .toList(),
      active: customOrderActive,
      baseName: _customOrder.isEmpty ? null : _lastImportedCustomOrderBaseName,
      sourceType: _customOrder.isEmpty ? null : _customOrderSourceType,
      zsolozsmaLabel: _customOrder.isEmpty ? null : _zsolozsmaVirtualBookLabel,
    );
  }

  Future<List<String>> listCustomOrderPresetNames() async {
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore
        .loadCustomOrderPresets();
    final List<String> names = presets.keys.toList()
      ..sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
    return names;
  }

  Future<List<CustomOrderEntry>> readCustomOrderPreset(String name) async {
    final String key = name.trim();
    if (key.isEmpty) {
      return const <CustomOrderEntry>[];
    }
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore
        .loadCustomOrderPresets();
    final List<StoredCustomOrderEntry> entries =
        presets[key] ?? const <StoredCustomOrderEntry>[];
    return entries
        .map(
          (StoredCustomOrderEntry e) => CustomOrderEntry(
            fileName: e.fileName,
            songIndex: e.songIndex,
            verseIndex: e.verseIndex,
            label: e.label,
            customTextTitle: e.customTextTitle,
            customTextBody: e.customTextBody,
            customImagePath: e.customImagePath,
            customType: e.customType,
            customData: e.customData,
            storageExtras: e.additionalFields,
          ),
        )
        .toList();
  }

  Future<void> saveCustomOrderPreset(
    String name,
    List<CustomOrderEntry> entries,
  ) async {
    final String key = name.trim();
    if (key.isEmpty) {
      return;
    }
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore
        .loadCustomOrderPresets();
    presets[key] = entries
        .map(
          (CustomOrderEntry e) => StoredCustomOrderEntry(
            fileName: e.fileName,
            songIndex: e.songIndex,
            verseIndex: _safeVerseIndex(e),
            label: e.label,
            customTextTitle: e.customTextTitle,
            customTextBody: e.customTextBody,
            customImagePath: e.customImagePath,
            customType: e.customType,
            customData: e.customData,
            additionalFields: e.storageExtras,
          ),
        )
        .toList();
    await _orderStore.saveCustomOrderPresets(presets);
  }

  bool isSongOrderEntry(CustomOrderEntry entry) => entry.isSongEntry;
  bool isCustomTextOrderEntry(CustomOrderEntry entry) => entry.isCustomText;
  bool isCustomImageOrderEntry(CustomOrderEntry entry) => entry.isCustomImage;

  Future<void> deleteCustomOrderPreset(String name) async {
    final String key = name.trim();
    if (key.isEmpty) {
      return;
    }
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore
        .loadCustomOrderPresets();
    presets.remove(key);
    await _orderStore.saveCustomOrderPresets(presets);
  }

  List<CustomOrderCandidate> loadCustomOrderCandidates() {
    final List<CustomOrderCandidate> out = <CustomOrderCandidate>[];
    for (final DtxBook book in books) {
      for (int i = 0; i < book.songs.length; i++) {
        final DtxSong song = book.songs[i];
        if (song.separator) {
          continue;
        }
        out.add(
          CustomOrderCandidate(
            fileName: book.fileName,
            bookTitle: book.displayName,
            songIndex: i,
            songTitle: song.title,
          ),
        );
      }
    }
    return out;
  }

  DtxBook? bookForEntry(CustomOrderEntry entry) {
    return _entryLabelService.bookForEntry(books, entry);
  }

  DtxSong? songForEntry(CustomOrderEntry entry) {
    return _entryLabelService.songForEntry(books, entry);
  }

  List<DtxVerse> versesForEntry(CustomOrderEntry entry) {
    return _entryLabelService.versesForEntry(books, entry);
  }

  String firstTextLineForEntry(CustomOrderEntry entry) {
    return _entryLabelService.firstTextLineForEntry(books, entry);
  }

  String buildEntryLabel(String fileName, int songIndex, int verseIndex) {
    return _entryLabelService.buildEntryLabel(
      books,
      fileName,
      songIndex,
      verseIndex,
    );
  }

  String _normalizeDiaText(String text) {
    return _diaMatchingPolicy.normalize(text);
  }

  int _findBookIndexForDia(String kotet) {
    return _diaMatchingPolicy.findBookIndex(books, kotet);
  }

  int _findSongIndexForDia(DtxBook book, String enek) {
    return _diaMatchingPolicy.findSongIndex(book, enek);
  }

  int _findVerseIndexForDia(DtxSong song, String versszak) {
    return _diaMatchingPolicy.findVerseIndex(song, versszak);
  }

  int _findCustomOrderIndexByEntry(
    CustomOrderEntry entry, {
    int preferredCursor = -1,
  }) {
    return _entryMatchPolicy.findEntryIndex(
      _customOrder,
      entry,
      preferredCursor: preferredCursor,
    );
  }

  CustomOrderEntry normalizeEntry(CustomOrderEntry entry) {
    return _customOrderNormalizer.normalizeEntry(entry, books);
  }

  Future<void> applyCustomOrder(
    List<CustomOrderEntry> entries, {
    required bool activate,
    bool syncProjection = true,
  }) async {
    final int previousCursor = _customOrderCursor;
    final CustomOrderEntry? previousEntry =
        previousCursor >= 0 && previousCursor < _customOrder.length
        ? _customOrder[previousCursor]
        : null;

    _customOrder = entries.map(normalizeEntry).toList();
    if (_customOrder.isEmpty) {
      _diaVirtualBookSelected = false;
      _lastImportedCustomOrderBaseName = null;
      _customOrderSourceType = null;
      _zsolozsmaVirtualBookLabel = null;
    }
    customOrderActive = activate && _customOrder.isNotEmpty;
    if (customOrderActive) {
      final int preservedCursor = previousEntry == null
          ? -1
          : _findCustomOrderIndexByEntry(
              previousEntry,
              preferredCursor: previousCursor,
            );
      if (preservedCursor >= 0) {
        _customOrderCursor = preservedCursor;
      } else if (_customOrder.isNotEmpty) {
        _customOrderCursor = previousCursor.clamp(0, _customOrder.length - 1);
      } else {
        _customOrderCursor = -1;
      }
      if (syncProjection && _customOrderCursor >= 0) {
        _selectByCustomOrderCursor(_customOrderCursor, sync: false);
      }
      await _persistCurrentCustomOrder();
      if (syncProjection &&
          _customOrderCursor >= 0 &&
          _customOrderCursor < _customOrder.length &&
          !_customOrder[_customOrderCursor].isSongEntry) {
        await _projectCustomOrderEntry(
          _customOrder[_customOrderCursor],
          cursor: _customOrderCursor,
        );
      } else if (syncProjection) {
        await _syncCurrentDia();
      } else {
        notifyListeners();
      }
    } else {
      _customOrderCursor = -1;
      _projectedCustomCursor = -1;
      await _persistCurrentCustomOrder();
      notifyListeners();
    }
  }

  Future<void> syncProjectionToCurrentDia() {
    return _syncCurrentDia();
  }

  Future<void> projectCustomOrderEntry(
    CustomOrderEntry rawEntry, {
    int? preferredCursor,
  }) async {
    final CustomOrderEntry entry = normalizeEntry(rawEntry);
    if (!entry.isSongEntry) {
      int targetCursor = preferredCursor ?? _customOrder.indexOf(entry);
      if (targetCursor < 0) {
        targetCursor = _customOrderCursor;
      }
      targetCursor = targetCursor.clamp(
        0,
        _customOrder.isEmpty ? 0 : _customOrder.length - 1,
      );
      _customOrderCursor = targetCursor;
      _setStatus('statusCustomOrderSelected', <String, String>{
        'label': entry.label,
      });
      notifyListeners();
      await _projectCustomOrderEntry(entry, cursor: targetCursor);
      return;
    }
    final int bookIx = books.indexWhere(
      (DtxBook b) => b.fileName == entry.fileName,
    );
    if (bookIx < 0) {
      return;
    }
    final DtxBook b = books[bookIx];
    final int maxSong = b.songs.isEmpty ? 0 : b.songs.length - 1;

    bookIndex = bookIx;
    songIndex = entry.songIndex.clamp(0, maxSong);
    final DtxSong? s = currentSong;
    verseIndex = (s == null || s.verses.isEmpty)
        ? 0
        : _safeVerseIndex(entry).clamp(0, s.verses.length - 1);
    highPos = 0;
    _resetHighlightRenderState();

    if (preferredCursor != null) {
      _customOrderCursor = preferredCursor.clamp(
        0,
        _customOrder.isEmpty ? 0 : _customOrder.length - 1,
      );
    } else {
      final int idx = _customOrder.indexWhere(
        (CustomOrderEntry e) =>
            e.fileName == entry.fileName &&
            e.songIndex == entry.songIndex &&
            _safeVerseIndex(e) == _safeVerseIndex(entry),
      );
      if (idx >= 0) {
        _customOrderCursor = idx;
      }
    }

    _setStatus('statusCustomOrderSelected', <String, String>{
      'label': entry.label,
    });
    _projectedCustomCursor = -1;
    notifyListeners();
    await _syncCurrentDia();
  }

  void _syncCustomCursorFromCurrentSong() {
    if (!customOrderActive || _customOrder.isEmpty) {
      return;
    }
    final DtxBook? b = currentBook;
    if (b == null) {
      return;
    }

    _projectedCustomCursor = -1;

    bool matches(int idx) {
      if (idx < 0 || idx >= _customOrder.length) {
        return false;
      }
      final CustomOrderEntry e = _customOrder[idx];
      return e.fileName == b.fileName &&
          e.songIndex == songIndex &&
          _safeVerseIndex(e) == verseIndex;
    }

    // Keep current position stable for duplicate entries.
    if (matches(_customOrderCursor)) {
      return;
    }

    // Prefer the next matching occurrence after current cursor.
    for (int i = _customOrderCursor + 1; i < _customOrder.length; i++) {
      if (matches(i)) {
        _customOrderCursor = i;
        return;
      }
    }
    // Then search before current cursor.
    for (int i = 0; i <= _customOrderCursor && i < _customOrder.length; i++) {
      if (matches(i)) {
        _customOrderCursor = i;
        return;
      }
    }
  }

  void _selectByCustomOrderCursor(int cursor, {required bool sync}) {
    if (_customOrder.isEmpty) {
      return;
    }
    final int safe = cursor.clamp(0, _customOrder.length - 1);
    final CustomOrderEntry entry = _customOrder[safe];

    if (entry.isSeparator && sync) {
      final int? next = _findNextProjectableCustomOrderIndex(safe + 1);
      if (next != null) {
        _selectByCustomOrderCursor(next, sync: true);
        return;
      }
      final int? prev = _findPrevProjectableCustomOrderIndex(safe - 1);
      if (prev != null) {
        _selectByCustomOrderCursor(prev, sync: true);
        return;
      }
    }

    if (!entry.isSongEntry) {
      _customOrderCursor = safe;
      highPos = 0;
      _resetHighlightRenderState();
      _setStatus('statusCustomOrderSelected', <String, String>{
        'label': entry.label,
      });
      notifyListeners();
      if (sync) {
        unawaited(_projectCustomOrderEntry(entry, cursor: safe));
      }
      return;
    }
    final int bookIx = books.indexWhere(
      (DtxBook b) => b.fileName == entry.fileName,
    );
    if (bookIx < 0) {
      return;
    }
    final DtxBook b = books[bookIx];
    final int maxSong = b.songs.isEmpty ? 0 : b.songs.length - 1;

    bookIndex = bookIx;
    songIndex = entry.songIndex.clamp(0, maxSong);
    final DtxSong? s = currentSong;
    verseIndex = (s == null || s.verses.isEmpty)
        ? 0
        : _safeVerseIndex(entry).clamp(0, s.verses.length - 1);
    highPos = 0;
    _resetHighlightRenderState();
    _customOrderCursor = safe;
    _projectedCustomCursor = -1;
    _setStatus('statusCustomOrderSelected', <String, String>{
      'label': entry.label,
    });
    notifyListeners();
    if (sync) {
      _syncCurrentDia();
    }
  }

  Future<List<DtxDownloadItem>> loadDownloadCandidates() async {
    final Directory dtxDir = await _resolveDtxDirectory();
    return _downloadService.listUpdates(targetDir: dtxDir);
  }

  Future<List<DtxManageItem>> loadDtxManagerItems() async {
    final Directory dtxDir = await _resolveDtxDirectory();
    final List<DtxDownloadItem> all = await _downloadService.listAll(
      targetDir: dtxDir,
    );
    return all
        .map(
          (DtxDownloadItem item) => DtxManageItem(
            item: item,
            excluded: _disabledSongbooks.contains(item.fileName),
          ),
        )
        .toList();
  }

  Future<String> exportCustomOrderToDia(String path) async {
    final String safePath = path.toLowerCase().endsWith('.dia')
        ? path
        : '$path.dia';
    final File diaFile = File(safePath);
    final Directory diaDir = diaFile.parent;
    if (!await diaDir.exists()) {
      await diaDir.create(recursive: true);
    }
    final List<CustomOrderEntry> exportable = _customOrder
        .map(normalizeEntry)
        .toList();
    final StringBuffer out = StringBuffer();
    out.writeln('[main]');
    out.writeln('diaszam=${exportable.length}');
    out.writeln('utf8=1');

    for (int i = 0; i < exportable.length; i++) {
      final CustomOrderEntry entry = exportable[i];
      out.writeln();
      out.writeln('[${i + 1}]');

      if (entry.isSeparator) {
        final String separatorName =
            (entry.customTextTitle ?? '').trim().isEmpty
            ? entry.label.trim()
            : (entry.customTextTitle ?? '').trim();
        out.writeln('separator=$separatorName');
        continue;
      }

      if (entry.isCustomImage) {
        final String rel = _relativeDiaImagePath(
          entry.customImagePath ?? '',
          diaDir,
        );
        out.writeln('kep=$rel');
        continue;
      }

      if (entry.isCustomText) {
        final String caption = (entry.customTextTitle ?? '').trim().isEmpty
            ? 'Dia'
            : (entry.customTextTitle ?? '').trim();
        final List<String> lines = (entry.customTextBody ?? '')
            .split(RegExp(r'\r?\n'))
            .map((String line) => line.trimRight())
            .where((String line) => line.trim().isNotEmpty)
            .toList();
        out.writeln('caption=$caption');
        out.writeln('lines=${lines.length}');
        for (int li = 0; li < lines.length; li++) {
          out.writeln('line$li=${lines[li]}');
        }
        continue;
      }

      final DtxBook? book = bookForEntry(entry);
      final DtxSong? song = songForEntry(entry);
      final List<DtxVerse> verses = versesForEntry(entry);
      final int verse = _safeVerseIndex(entry);
      final String verseName = verses.isEmpty
          ? ''
          : verses[verse.clamp(0, verses.length - 1)].name;
      final String idValue = '${entry.fileName}|${entry.songIndex}|$verse';

      out.writeln('id=$idValue');
      out.writeln('kotet=${book?.title ?? entry.fileName}');
      out.writeln('enek=${song?.title ?? entry.label}');
      out.writeln('versszak=$verseName');
    }

    await diaFile.writeAsString(out.toString(), encoding: utf8);
    await markCustomOrderDiaExportSaved(safePath);
    return safePath;
  }

  Future<void> markCustomOrderDiaExportSaved(String path) async {
    // URI-decode to handle Android content URIs like
    // content://...document/primary%3ADocuments%2Fsorrend.dia
    // where %2F is an encoded '/' within the document-ID segment.
    String decodedPath;
    try {
      decodedPath = Uri.decodeComponent(path);
    } catch (_) {
      decodedPath = path;
    }
    final String savedName = _stripFileExtension(
      _fileNameFromPath(decodedPath),
    );
    _lastImportedCustomOrderBaseName = savedName.trim().isEmpty
        ? null
        : savedName;
    _customOrderSourceType = null;
    _zsolozsmaVirtualBookLabel = null;
    await _persistCurrentCustomOrder();
    _setStatus('statusOrderSaved', <String, String>{'path': path});
    notifyListeners();
  }

  Future<int> importCustomOrderFromDia(
    String path, {
    bool activate = true,
    String? sourceFileName,
  }) async {
    final File f = File(path);
    if (!await f.exists()) {
      _setStatus('statusDiaFileMissing', <String, String>{'path': path});
      notifyListeners();
      return 0;
    }

    final String content = await f.readAsString();
    final Map<String, Map<String, String>> sections = _parseDiaIni(content);
    final int declaredCount =
        int.tryParse(sections['main']?['diaszam'] ?? '') ?? 0;

    // Build ID-based lookup map for faster identification
    final Map<String, ({DtxBook book, int songIndex, int verseIndex})> idMap =
        <String, ({DtxBook book, int songIndex, int verseIndex})>{};
    for (final DtxBook book in books) {
      for (int si = 0; si < book.songs.length; si++) {
        final DtxSong song = book.songs[si];
        for (int vi = 0; vi < song.verses.length; vi++) {
          final String id = '${book.fileName}|$si|$vi';
          idMap[id] = (book: book, songIndex: si, verseIndex: vi);
        }
      }
    }

    final List<CustomOrderEntry> imported = <CustomOrderEntry>[];
    final Iterable<String> keys = sections.keys.where(
      (String k) => k != 'main',
    );
    final List<String> sectionOrder = keys.toList()
      ..sort(
        (String a, String b) =>
            (int.tryParse(a) ?? 999999).compareTo(int.tryParse(b) ?? 999999),
      );

    final int max = declaredCount > 0 ? declaredCount : sectionOrder.length;
    for (int i = 1; i <= max; i++) {
      final Map<String, String>? sec = sections['$i'];
      if (sec == null) {
        continue;
      }

      final String separatorName = (sec['separator'] ?? '').trim();
      if (separatorName.isNotEmpty) {
        imported.add(
          CustomOrderEntry(
            fileName: CustomOrderEntry.separatorFileName,
            songIndex: CustomOrderEntry.separatorSongIndex,
            verseIndex: 0,
            label: '--- $separatorName ---',
            customTextTitle: separatorName,
          ),
        );
        continue;
      }

      final String kep = (sec['kep'] ?? '').trim();
      if (kep.isNotEmpty) {
        final String resolved = _resolveDiaImagePath(path, kep);
        imported.add(
          CustomOrderEntry(
            fileName: '__custom_image__',
            songIndex: -2,
            verseIndex: 0,
            label: '[Kep] ${_fileNameFromPath(kep)}',
            customImagePath: resolved,
            customType: 'image',
          ),
        );
        continue;
      }

      final String caption = (sec['caption'] ?? '').trim();
      final int declaredLines = int.tryParse((sec['lines'] ?? '').trim()) ?? -1;
      final List<String> textLines = _collectDiaLines(sec, declaredLines);
      if (caption.isNotEmpty || textLines.isNotEmpty) {
        final String effectiveTitle = caption.isEmpty ? 'Dia' : caption;
        imported.add(
          CustomOrderEntry(
            fileName: '__custom_text__',
            songIndex: -1,
            verseIndex: 0,
            label: '[Szoveg] $effectiveTitle',
            customTextTitle: effectiveTitle,
            customTextBody: textLines.join('\n'),
            customType: 'text',
          ),
        );
        continue;
      }

      // Try ID-based identification first (most reliable)
      final String idField = (sec['id'] ?? '').trim();
      if (idField.isNotEmpty && idMap.containsKey(idField)) {
        final (:DtxBook book, :int songIndex, :int verseIndex) =
            idMap[idField]!;
        imported.add(
          CustomOrderEntry(
            fileName: book.fileName,
            songIndex: songIndex,
            verseIndex: verseIndex,
            label: buildEntryLabel(book.fileName, songIndex, verseIndex),
          ),
        );
        continue;
      }

      // Fallback: name-based identification
      final String kotet = (sec['kotet'] ?? '').trim();
      final String enek = (sec['enek'] ?? '').trim();
      final String versszak = (sec['versszak'] ?? '').trim();

      final int bIx = _findBookIndexForDia(kotet);
      if (bIx < 0) {
        continue;
      }

      final DtxBook b = books[bIx];
      final int sIx = _findSongIndexForDia(b, enek);
      if (sIx < 0) {
        continue;
      }

      final DtxSong s = b.songs[sIx];
      final int vIx = _findVerseIndexForDia(s, versszak);

      imported.add(
        CustomOrderEntry(
          fileName: b.fileName,
          songIndex: sIx,
          verseIndex: vIx,
          label: buildEntryLabel(b.fileName, sIx, vIx),
        ),
      );
    }

    await applyCustomOrder(imported, activate: activate);
    final String importedName = _stripFileExtension(
      (sourceFileName ?? _fileNameFromPath(path)).trim(),
    );
    _lastImportedCustomOrderBaseName = importedName.trim().isEmpty
        ? null
        : importedName;
    _customOrderSourceType = null;
    _zsolozsmaVirtualBookLabel = null;
    await _persistCurrentCustomOrder();
    _diaVirtualBookSelected = _customOrder.isNotEmpty;
    _setStatus('statusOrderLoaded', <String, String>{
      'count': '${imported.length}',
      'path': path,
    });
    notifyListeners();
    return imported.length;
  }

  String _relativeDiaImagePath(String rawPath, Directory diaDir) {
    return _diaPathPolicy.relativeDiaImagePath(rawPath, diaDir);
  }

  String _resolveDiaImagePath(String diaPath, String relOrAbs) {
    return _diaPathPolicy.resolveDiaImagePath(diaPath, relOrAbs);
  }

  String _fileNameFromPath(String rawPath) {
    return _diaPathPolicy.fileNameFromPath(rawPath);
  }

  String _stripFileExtension(String fileName) {
    return _diaPathPolicy.stripFileExtension(fileName);
  }

  List<String> _collectDiaLines(Map<String, String> sec, int declaredLines) {
    return _diaIniParser.collectLines(sec, declaredLines);
  }

  Map<String, Map<String, String>> _parseDiaIni(String content) {
    return _diaIniParser.parse(content);
  }

  Future<void> applyDtxManagerSelection({
    required Set<String> downloadSelected,
    required Set<String> excludedSelected,
  }) async {
    loading = true;
    downloadInProgress = true;
    downloadCurrentFile = 0;
    downloadTotalFiles = 0;
    downloadCurrentName = '';
    downloadCurrentFraction = 0;
    _setStatus('statusDownloadListLoading');
    notifyListeners();

    try {
      final Directory dtxDir = await _resolveDtxDirectory();
      final List<DtxDownloadItem> all = await _downloadService.listAll(
        targetDir: dtxDir,
      );
      final Map<String, DtxDownloadItem> byFile = <String, DtxDownloadItem>{
        for (final DtxDownloadItem item in all) item.fileName: item,
      };

      final Set<String> effectiveDownload = downloadSelected
          .map((String name) => name.trim())
          .where((String name) => name.isNotEmpty)
          .where((String name) {
            final DtxDownloadItem? item = byFile[name];
            return item != null && item.isOfficial && item.updateAvailable;
          })
          .toSet();

      downloadTotalFiles = effectiveDownload.length;

      final Set<String> effectiveExcluded = excludedSelected
          .map((String name) => name.trim())
          .where((String name) => name.isNotEmpty)
          .toSet();

      final Set<String> filesToDelete = effectiveExcluded.where((String name) {
        final DtxDownloadItem? item = byFile[name];
        return item != null && item.isInstalled;
      }).toSet();

      final List<DtxDownloadItem> selectedForDownload = effectiveDownload
          .map((String name) => byFile[name]!)
          .toList();

      final int deletedCount = await _downloadService.deleteLocalFiles(
        targetDir: dtxDir,
        fileNames: filesToDelete,
      );

      DtxDownloadSummary summary = const DtxDownloadSummary(
        downloaded: 0,
        skipped: 0,
      );
      if (selectedForDownload.isNotEmpty) {
        summary = await _downloadService.downloadUpdates(
          targetDir: dtxDir,
          selected: selectedForDownload,
          onProgress: (DtxDownloadProgress progress) {
            downloadCurrentFile = progress.currentFile;
            downloadTotalFiles = progress.totalFiles;
            downloadCurrentName = progress.fileName;
            downloadCurrentFraction = progress.fraction;
            _setStatus('statusDownloadProgress', <String, String>{
              'current': '${progress.currentFile}',
              'total': '${progress.totalFiles}',
              'name': progress.fileName,
              'percent': (progress.fraction * 100).toStringAsFixed(0),
            });
            notifyListeners();
          },
        );
      }

      effectiveExcluded.removeAll(effectiveDownload);
      _disabledSongbooks = effectiveExcluded;
      await _orderStore.saveDisabled(_disabledSongbooks);

      await reloadBooks();
      if (summary.downloaded == 0 && deletedCount == 0) {
        _setStatus('statusDownloadSummaryNone');
      } else {
        _setStatus('statusDownloadSummary', <String, String>{
          'downloaded': '${summary.downloaded}',
          'skipped': '${summary.skipped}',
        });
      }
    } catch (e) {
      _setStatus('statusDownloadError', <String, String>{'error': '$e'});
    } finally {
      downloadInProgress = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> downloadSongBooks({List<DtxDownloadItem>? selected}) async {
    loading = true;
    downloadInProgress = true;
    downloadCurrentFile = 0;
    downloadTotalFiles = selected?.length ?? 0;
    downloadCurrentName = '';
    downloadCurrentFraction = 0;
    _setStatus('statusDownloadListLoading');
    notifyListeners();

    try {
      final Directory dtxDir = await _resolveDtxDirectory();
      final DtxDownloadSummary summary = await _downloadService.downloadUpdates(
        targetDir: dtxDir,
        selected: selected,
        onProgress: (DtxDownloadProgress progress) {
          downloadCurrentFile = progress.currentFile;
          downloadTotalFiles = progress.totalFiles;
          downloadCurrentName = progress.fileName;
          downloadCurrentFraction = progress.fraction;
          _setStatus('statusDownloadProgress', <String, String>{
            'current': '${progress.currentFile}',
            'total': '${progress.totalFiles}',
            'name': progress.fileName,
            'percent': (progress.fraction * 100).toStringAsFixed(0),
          });
          notifyListeners();
        },
      );
      await reloadBooks();
      if (summary.downloaded == 0) {
        _setStatus('statusDownloadSummaryNone');
      } else {
        _setStatus('statusDownloadSummary', <String, String>{
          'downloaded': '${summary.downloaded}',
          'skipped': '${summary.skipped}',
        });
      }
    } catch (e) {
      _setStatus('statusDownloadError', <String, String>{'error': '$e'});
    } finally {
      downloadInProgress = false;
      loading = false;
      notifyListeners();
    }
  }

  int _compareBooksLikeAndroid(DtxBook left, DtxBook right) {
    return _bookSortPolicy.compare(left, right);
  }

  int _preferredBookGroupPriority(String group) {
    return _bookSortPolicy.preferredGroupPriority(group);
  }

  DtxBook? get currentBook =>
      books.isEmpty ? null : books[bookIndex.clamp(0, books.length - 1)];

  DtxSong? get currentSong {
    final DtxBook? b = currentBook;
    if (b == null || b.songs.isEmpty) {
      return null;
    }
    return b.songs[songIndex.clamp(0, b.songs.length - 1)];
  }

  DtxVerse? get currentVerse {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return null;
    }
    return s.verses[verseIndex.clamp(0, s.verses.length - 1)];
  }

  List<String> get displayLines {
    final DtxVerse? v = currentVerse;
    if (v == null || v.lines.isEmpty) {
      return const <String>[''];
    }
    return v.lines;
  }

  int get wordCount {
    int count = 0;
    for (final String line in displayLines) {
      count += line
          .split(RegExp(r'\s+'))
          .where((String w) => w.trim().isNotEmpty)
          .length;
    }
    return count;
  }

  void setBookIndex(int value) {
    if (books.isEmpty) {
      return;
    }
    _diaVirtualBookSelected = false;
    bookIndex = value.clamp(0, books.length - 1);
    songIndex = 0;
    verseIndex = 0;
    highPos = 0;
    _resetHighlightRenderState();
    _projectedCustomCursor = -1;
    final DtxBook? selected = currentBook;
    _setStatus('statusBookSelected', <String, String>{
      'name': selected?.displayName ?? '-',
    });
    _syncCustomCursorFromCurrentSong();
    notifyListeners();
    _syncCurrentDia();
  }

  void setSongIndex(int value) {
    final DtxSong? s = currentSong;
    final int max = (currentBook?.songs.length ?? 1) - 1;
    if (s == null || max < 0) {
      return;
    }
    songIndex = value.clamp(0, max);
    verseIndex = 0;
    highPos = 0;
    _resetHighlightRenderState();
    _projectedCustomCursor = -1;
    _setStatus('statusSongPicked', <String, String>{
      'name': currentSong?.title ?? '-',
    });
    _syncCustomCursorFromCurrentSong();
    notifyListeners();
    _syncCurrentDia();
  }

  void activateSongHotkeyBinding(String bindingId) {
    final List<String> parts = bindingId.split('::');
    if (parts.length != 2) {
      return;
    }
    final String fileName = parts[0].trim();
    final int? targetSong = int.tryParse(parts[1].trim());
    if (fileName.isEmpty || targetSong == null || targetSong < 0) {
      return;
    }

    final int bookIdx = books.indexWhere((DtxBook b) => b.fileName == fileName);
    if (bookIdx < 0) {
      return;
    }

    final DtxBook book = books[bookIdx];
    if (book.songs.isEmpty || targetSong >= book.songs.length) {
      return;
    }
    if (book.songs[targetSong].separator) {
      return;
    }

    setBookIndex(bookIdx);
    setSongIndex(targetSong);
  }

  void setVerseIndex(int value) {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return;
    }
    verseIndex = value.clamp(0, s.verses.length - 1);
    highPos = 0;
    _resetHighlightRenderState();
    _projectedCustomCursor = -1;
    _setStatus('statusVersePicked', <String, String>{
      'name': currentVerse?.name ?? '-',
    });
    notifyListeners();
    _syncCurrentDia();
  }

  void nextVerse() {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return;
    }

    if (diaVirtualBookSelected) {
      final int exactIdx = _currentCustomOrderIndex();
      if (exactIdx >= 0) {
        final int? nextIdx = _findNextProjectableCustomOrderIndex(exactIdx + 1);
        if (nextIdx == null) {
          return;
        }
        _selectByCustomOrderCursor(nextIdx, sync: true);
        return;
      }

      // Ha sorrenden kivuli dian allunk, eloszor azon lepdelunk vegig,
      // es csak a vege utan ugrunk vissza a sorrend kovetkezo elemere.
      if (verseIndex + 1 < s.verses.length) {
        setVerseIndex(verseIndex + 1);
        return;
      }

      if (_customOrderCursor < 0) {
        final int? firstIdx = _findNextProjectableCustomOrderIndex(0);
        if (firstIdx != null) {
          _selectByCustomOrderCursor(firstIdx, sync: true);
        }
        return;
      }
      if (_customOrderCursor + 1 < _customOrder.length) {
        final int? nextIdx = _findNextProjectableCustomOrderIndex(
          _customOrderCursor + 1,
        );
        if (nextIdx != null) {
          _selectByCustomOrderCursor(nextIdx, sync: true);
        }
      }
      return;
    }

    if (verseIndex + 1 < s.verses.length) {
      setVerseIndex(verseIndex + 1);
      return;
    }

    final int? nextSongIdx = _findSelectableSongIndex(
      songIndex + 1,
      forward: true,
    );
    if (nextSongIdx == null) {
      return;
    }
    _selectSongAndVerse(nextSongIdx, 0, includeVerseInStatus: true);
  }

  int _currentCustomOrderIndex() {
    return _entryMatchPolicy.findCurrentIndex(
      source: _customOrder,
      projectedCursor: _projectedCustomCursor,
      currentCursor: _customOrderCursor,
      currentBookFileName: currentBook?.fileName,
      currentSongIndex: songIndex,
      currentVerseIndex: verseIndex,
    );
  }

  void prevVerse() {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return;
    }

    if (diaVirtualBookSelected) {
      final int exactIdx = _currentCustomOrderIndex();
      if (exactIdx >= 0) {
        final int? prevIdx = _findPrevProjectableCustomOrderIndex(exactIdx - 1);
        if (prevIdx == null) {
          return;
        }
        _selectByCustomOrderCursor(prevIdx, sync: true);
        return;
      }

      if (_customOrderCursor < 0) {
        final int? firstIdx = _findNextProjectableCustomOrderIndex(0);
        if (firstIdx != null) {
          _selectByCustomOrderCursor(firstIdx, sync: true);
        }
        return;
      }
      if (_customOrderCursor > 0) {
        final int? prevIdx = _findPrevProjectableCustomOrderIndex(
          _customOrderCursor - 1,
        );
        if (prevIdx != null) {
          _selectByCustomOrderCursor(prevIdx, sync: true);
        }
      }
      return;
    }

    if (verseIndex > 0) {
      _selectSongAndVerse(
        songIndex,
        verseIndex - 1,
        includeVerseInStatus: true,
      );
      return;
    }

    final int? prevSongIdx = _findSelectableSongIndex(
      songIndex - 1,
      forward: false,
    );
    if (prevSongIdx == null) {
      return;
    }
    final DtxBook? b = currentBook;
    if (b == null) {
      return;
    }
    final DtxSong prevSong = b.songs[prevSongIdx];
    final int prevSongLastVerse = prevSong.verses.isEmpty
        ? 0
        : prevSong.verses.length - 1;
    _selectSongAndVerse(
      prevSongIdx,
      prevSongLastVerse,
      includeVerseInStatus: true,
    );
  }

  void nextSong() {
    if (diaVirtualBookSelected) {
      final int? nextIdx = _findNextDiaSongGroupStart();
      if (nextIdx == null) {
        return;
      }
      _selectByCustomOrderCursor(nextIdx, sync: true);
      return;
    }
    final int? nextSongIdx = _findSelectableSongIndex(
      songIndex + 1,
      forward: true,
    );
    if (nextSongIdx == null) {
      return;
    }
    _selectSongAndVerse(nextSongIdx, 0, includeVerseInStatus: false);
  }

  void prevSong() {
    if (diaVirtualBookSelected) {
      final int currentGroupStart = _currentDiaGroupStartIndex();
      final int currentIndex = _currentCustomOrderIndex();
      final bool onGroupStart = currentIndex == currentGroupStart;

      if (!onGroupStart) {
        _selectByCustomOrderCursor(currentGroupStart, sync: true);
        return;
      }

      final int? prevIdx = _findPrevDiaSongGroupStart();
      if (prevIdx == null) {
        return;
      }
      _selectByCustomOrderCursor(prevIdx, sync: true);
      return;
    }

    final DtxSong? s = currentSong;
    if (s != null && s.verses.isNotEmpty && verseIndex > 0) {
      _selectSongAndVerse(songIndex, 0, includeVerseInStatus: false);
      return;
    }

    final int? prevSongIdx = _findSelectableSongIndex(
      songIndex - 1,
      forward: false,
    );
    if (prevSongIdx == null) {
      return;
    }
    _selectSongAndVerse(prevSongIdx, 0, includeVerseInStatus: false);
  }

  int? _findSelectableSongIndex(int start, {required bool forward}) {
    return _songNavigationPolicy.findSelectableSongIndex(
      currentBook?.songs ?? const <DtxSong>[],
      start,
      forward: forward,
    );
  }

  int? _findNextProjectableCustomOrderIndex(int start) {
    return _customOrderNavigationPolicy.findNextProjectableIndex(
      _customOrder,
      start,
    );
  }

  int? _findPrevProjectableCustomOrderIndex(int start) {
    return _customOrderNavigationPolicy.findPrevProjectableIndex(
      _customOrder,
      start,
    );
  }

  int _currentDiaGroupStartIndex() {
    int current = _currentCustomOrderIndex();
    if (current < 0 || current >= _customOrder.length) {
      current = _customOrderCursor.clamp(0, _customOrder.length - 1);
    }
    return _customOrderNavigationPolicy.currentDiaGroupStartIndex(
      _customOrder,
      current,
      safeVerseIndex: _safeVerseIndex,
    );
  }

  int? _findNextDiaSongGroupStart() {
    return _customOrderNavigationPolicy.findNextDiaSongGroupStart(
      _customOrder,
      _currentDiaGroupStartIndex(),
      safeVerseIndex: _safeVerseIndex,
    );
  }

  int? _findPrevDiaSongGroupStart() {
    return _customOrderNavigationPolicy.findPrevDiaSongGroupStart(
      _customOrder,
      _currentDiaGroupStartIndex(),
      safeVerseIndex: _safeVerseIndex,
    );
  }

  void _selectSongAndVerse(
    int targetSong,
    int targetVerse, {
    required bool includeVerseInStatus,
  }) {
    final DtxBook? b = currentBook;
    if (b == null || b.songs.isEmpty) {
      return;
    }
    final SongSelectionResult? selection = _songSelectionPolicy
        .selectSongAndVerse(
          songs: b.songs,
          targetSong: targetSong,
          targetVerse: targetVerse,
          includeVerseInStatus: includeVerseInStatus,
        );
    if (selection == null) {
      return;
    }

    songIndex = selection.songIndex;
    verseIndex = selection.verseIndex;
    highPos = 0;
    _resetHighlightRenderState();
    _projectedCustomCursor = -1;
    final DtxSong selectedSong = b.songs[selection.songIndex];
    _setStatus(selection.statusCode, <String, String>{'title': selectedSong.title});
    _syncCustomCursorFromCurrentSong();
    notifyListeners();
    _syncCurrentDia();
  }

  void toggleShowing() {
    showing = !showing;
    _setStatus(showing ? 'statusProjectionOn' : 'statusProjectionOff');
    notifyListeners();
    _syncProjectionOnly();
  }

  Future<void> toggleProjectionLock() async {
    final bool wasLocked = settings.projectionLocked;
    settings = settings.copyWith(projectionLocked: !wasLocked);
    await _settingsStore.save(settings);
    notifyListeners();
    if (wasLocked && !settings.projectionLocked) {
      await _syncCurrentDia();
    }
  }

  Future<void> _syncProjectionOnly() async {
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    if (_projectionOutputLocked) {
      return;
    }
    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
    if (tcpConfigured) {
      await _sender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
    _refreshSenderFlags();
  }

  void highlightNext() {
    final int maxByRenderer = _renderedHighlightWordCount;
    final int max = maxByRenderer >= 0 ? maxByRenderer : wordCount;
    if (_highlightFullyRendered && maxByRenderer >= 0 && highPos >= max) {
      return;
    }
    highPos = (highPos + 1).clamp(0, max);
    notifyListeners();
    _syncHighlightOnly();
  }

  void highlightPrev() {
    final int maxByRenderer = _renderedHighlightWordCount;
    final int max = maxByRenderer >= 0 ? maxByRenderer : wordCount;
    highPos = (highPos - 1).clamp(0, max);
    _highlightFullyRendered = false;
    notifyListeners();
    _syncHighlightOnly();
  }

  Future<void> _syncHighlightOnly() async {
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    if (_projectionOutputLocked) {
      return;
    }
    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
    if (tcpConfigured) {
      await _sender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
    _refreshSenderFlags();
  }

  Future<void> _syncCurrentDia() async {
    _projectedCustomCursor = -1;
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    if (_projectionOutputLocked) {
      notifyListeners();
      return;
    }
    final DtxSong? song = currentSong;
    final DtxBook? book = currentBook;
    final DtxVerse? verse = currentVerse;
    final List<String> lines = displayLines;

    final String bookNick = book?.displayName ?? '';
    final String songTitle = song?.title ?? '';
    final String verseTitle = (verse?.name ?? '').trim();
    final bool hasOnlyDefaultVerse =
        (song?.verses.length ?? 0) == 1 && verseTitle == '---';
    final bool hideVerseInTitle = verseTitle.isEmpty || hasOnlyDefaultVerse;
    final String title = bookNick.isEmpty
        ? songTitle
        : hideVerseInTitle
        ? '$bookNick: $songTitle'
        : '$bookNick: $songTitle/$verseTitle';

    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
      await _mqttSender.sendText(title: title, lines: lines);
    }
    if (tcpConfigured) {
      await _sender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
      await _sender.sendText(
        title: title,
        lines: lines,
        wordToHighlight: highPos,
      );
      await _sender.sendIdle();
    }
    _refreshSenderFlags();
    notifyListeners();
  }

  Future<void> _projectCustomOrderEntry(
    CustomOrderEntry entry, {
    required int cursor,
  }) async {
    _projectedCustomCursor = cursor;

    if (entry.isSeparator) {
      _setStatus('statusCustomOrderSelected', <String, String>{
        'label': entry.label,
      });
      notifyListeners();
      return;
    }

    if (entry.isCustomText) {
      highPos = 0;
      _resetHighlightRenderState();
      final String title = (entry.customTextTitle ?? '').trim().isEmpty
          ? 'Dia'
          : (entry.customTextTitle ?? '').trim();
      final List<String> lines = (entry.customTextBody ?? '')
          .split(RegExp(r'\r?\n'))
          .map((String line) => line.trimRight())
          .where((String line) => line.trim().isNotEmpty)
          .toList();
      final List<String> payloadLines = lines.isEmpty
          ? const <String>['']
          : lines;
      globals = globals.copyWith(projecting: showing, wordToHighlight: 0);
      if (_projectionOutputLocked) {
        _setStatus('statusCustomTextSent', <String, String>{'title': title});
        notifyListeners();
        return;
      }
      if (mqttActive) {
        await _mqttSender.sendState(
          globals,
          showing: showing,
          wordToHighlight: 0,
        );
        await _mqttSender.sendText(title: title, lines: payloadLines);
      }
      if (tcpConfigured) {
        await _sender.sendState(globals, showing: showing, wordToHighlight: 0);
        await _sender.sendText(
          title: title,
          lines: payloadLines,
          wordToHighlight: 0,
        );
        await _sender.sendIdle();
      }
      _refreshSenderFlags();
      _setStatus('statusCustomTextSent', <String, String>{'title': title});
      notifyListeners();
      return;
    }

    if (entry.isCustomImage) {
      await sendPicFromPath(entry.customImagePath ?? '');
    }
  }

  Future<void> _appendCustomOrderEntry(CustomOrderEntry entry) async {
    _customOrder = <CustomOrderEntry>[..._customOrder, entry];
    customOrderActive = _customOrder.isNotEmpty;
    _customOrderCursor = _customOrder.length - 1;
    await _persistCurrentCustomOrder();
    notifyListeners();
  }

  Future<void> addCustomTextSlideToOrder({
    required String title,
    required String body,
  }) async {
    final String normalizedTitle = title.trim();
    final List<String> lines = body
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trimRight())
        .where((String line) => line.trim().isNotEmpty)
        .toList();

    if (normalizedTitle.isEmpty && lines.isEmpty) {
      _setStatus('statusCustomTextEmpty');
      notifyListeners();
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
      customType: 'text',
    );

    await _appendCustomOrderEntry(entry);
    await _projectCustomOrderEntry(entry, cursor: _customOrderCursor);
  }

  Future<void> addCustomImageSlideToOrder(String path) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      _setStatus('statusImagePathEmpty');
      notifyListeners();
      return;
    }

    final File file = File(normalized);
    if (!await file.exists()) {
      _setStatus('statusImageNotFound', <String, String>{'path': normalized});
      notifyListeners();
      return;
    }

    final String fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : normalized;
    final CustomOrderEntry entry = CustomOrderEntry(
      fileName: '__custom_image__',
      songIndex: -2,
      verseIndex: 0,
      label: '[Kep] $fileName',
      customImagePath: normalized,
      customType: 'image',
    );

    await _appendCustomOrderEntry(entry);
    await _projectCustomOrderEntry(entry, cursor: _customOrderCursor);
  }

  Future<void> sendCustomTextSlide({
    required String title,
    required String body,
  }) async {
    final String normalizedTitle = title.trim();
    final List<String> lines = body
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trimRight())
        .toList();
    final List<String> nonEmptyLines = lines
        .where((String line) => line.trim().isNotEmpty)
        .toList();

    if (normalizedTitle.isEmpty && nonEmptyLines.isEmpty) {
      _setStatus('statusCustomTextEmpty');
      notifyListeners();
      return;
    }

    final String effectiveTitle = normalizedTitle.isEmpty
        ? 'Dia'
        : normalizedTitle;

    try {
      globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
      if (_projectionOutputLocked) {
        _setStatus('statusCustomTextSent', <String, String>{
          'title': effectiveTitle,
        });
        notifyListeners();
        return;
      }
      if (mqttActive) {
        await _mqttSender.sendState(
          globals,
          showing: showing,
          wordToHighlight: highPos,
        );
        await _mqttSender.sendText(title: effectiveTitle, lines: nonEmptyLines);
      }
      if (tcpConfigured) {
        await _sender.sendState(
          globals,
          showing: showing,
          wordToHighlight: highPos,
        );
        await _sender.sendText(
          title: effectiveTitle,
          lines: nonEmptyLines,
          wordToHighlight: highPos,
        );
        await _sender.sendIdle();
      }
      _refreshSenderFlags();
      _setStatus('statusCustomTextSent', <String, String>{
        'title': effectiveTitle,
      });
      notifyListeners();
    } catch (e) {
      _setStatus('statusCustomTextError', <String, String>{'error': '$e'});
      notifyListeners();
    }
  }

  Future<void> sendPicFromPath(String path) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      _setStatus('statusImagePathEmpty');
      notifyListeners();
      return;
    }

    try {
      final File file = File(normalized);
      if (!await file.exists()) {
        _setStatus('statusImageNotFound', <String, String>{'path': normalized});
        notifyListeners();
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final String ext = _fileExtension(normalized);
      if (_projectionOutputLocked) {
        lastPicPath = normalized;
        _setStatus('statusImageSent', <String, String>{
          'name': file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : normalized,
        });
        notifyListeners();
        return;
      }
      if (mqttActive) {
        await _mqttSender.sendPic(bytes, ext: ext);
      }
      if (tcpConfigured) {
        await _sender.sendPic(bytes, ext: ext);
      }
      _refreshSenderFlags();
      lastPicPath = normalized;
      _setStatus('statusImageSent', <String, String>{
        'name': file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : normalized,
      });
      notifyListeners();
    } catch (e) {
      _setStatus('statusImageSendError', <String, String>{'error': '$e'});
      notifyListeners();
    }
  }

  Future<void> sendBlankFromPath(
    String path, {
    bool showBackgroundImage = true,
    bool persistPath = true,
    bool updateStatus = true,
  }) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      globals = globals.copyWith(isBlankPic: false, showBlankPic: false);
      if (updateStatus) {
        _setStatus('statusBlankPathEmpty');
        notifyListeners();
      }
      return;
    }

    try {
      final File file = File(normalized);
      if (!await file.exists()) {
        globals = globals.copyWith(isBlankPic: false, showBlankPic: false);
        if (updateStatus) {
          _setStatus('statusBlankNotFound', <String, String>{
            'path': normalized,
          });
          notifyListeners();
        }
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final String ext = _fileExtension(normalized);
      globals = globals.copyWith(
        isBlankPic: true,
        showBlankPic: showBackgroundImage,
      );
      if (_projectionOutputLocked) {
        lastBlankPath = normalized;
        if (persistPath) {
          settings = settings.copyWith(blankPicPath: normalized);
          await _settingsStore.save(settings);
        }
        if (updateStatus) {
          _setStatus('statusBlankSet', <String, String>{
            'name': file.uri.pathSegments.isNotEmpty
                ? file.uri.pathSegments.last
                : normalized,
          });
          notifyListeners();
        }
        return;
      }
      if (mqttActive) {
        await _mqttSender.sendBlank(bytes, ext: ext);
      }
      if (tcpConfigured) {
        await _sender.sendBlank(bytes, ext: ext);
      }
      await _sendProjectionState();
      lastBlankPath = normalized;
      if (persistPath) {
        settings = settings.copyWith(blankPicPath: normalized);
        await _settingsStore.save(settings);
      }
      if (updateStatus) {
        _setStatus('statusBlankSet', <String, String>{
          'name': file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : normalized,
        });
        notifyListeners();
      }
    } catch (e) {
      if (updateStatus) {
        _setStatus('statusBlankSendError', <String, String>{'error': '$e'});
        notifyListeners();
      }
    }
  }

  Future<void> setBackgroundImageVisible(bool visible) async {
    settings = settings.copyWith(projShowBackgroundImage: visible);
    await _settingsStore.save(settings);

    final String path = settings.blankPicPath.trim();
    final bool hasPath = path.isNotEmpty;
    globals = globals.copyWith(
      isBlankPic: hasPath,
      showBlankPic: hasPath && visible,
    );

    if (_projectionOutputLocked) {
      notifyListeners();
      return;
    }

    if (!hasPath || !visible) {
      await _sendProjectionState();
      notifyListeners();
      return;
    }

    await sendBlankFromPath(
      path,
      showBackgroundImage: true,
      persistPath: false,
      updateStatus: false,
    );
    notifyListeners();
  }

  Future<void> toggleBackgroundImageVisible() async {
    await setBackgroundImageVisible(!settings.projShowBackgroundImage);
  }

  Future<void> clearBlankImage() async {
    try {
      globals = globals.copyWith(isBlankPic: false, showBlankPic: false);
      if (_projectionOutputLocked) {
        _setStatus('statusBlankCleared');
        notifyListeners();
        return;
      }
      if (mqttActive) {
        await _mqttSender.sendBlank(Uint8List(0), ext: '');
        await _mqttSender.sendState(
          globals,
          showing: showing,
          wordToHighlight: highPos,
        );
      }
      if (tcpConfigured) {
        await _sender.sendBlank(Uint8List(0), ext: '');
        await _sender.sendState(
          globals,
          showing: showing,
          wordToHighlight: highPos,
        );
      }
      _refreshSenderFlags();
      _setStatus('statusBlankCleared');
      notifyListeners();
    } catch (e) {
      _setStatus('statusBlankClearError', <String, String>{'error': '$e'});
      notifyListeners();
    }
  }

  Future<void> sendStop({bool wantShutdown = false}) async {
    try {
      final int endProgCode = wantShutdown
          ? RecStateEndProgram.shutdown
          : RecStateEndProgram.stop;

      globals = globals.copyWith(endProgram: endProgCode);

      if (mqttActive) {
        await _mqttSender.sendState(
          globals,
          showing: showing,
          wordToHighlight: highPos,
        );
      }
      if (tcpConfigured) {
        await _sender.sendState(
          globals,
          showing: showing,
          wordToHighlight: highPos,
        );
      }
      _refreshSenderFlags();

      // End-program commands are one-shot signals in Android too.
      globals = globals.copyWith(endProgram: 0);

      _setStatus(
        wantShutdown ? 'statusShutdownCommandSent' : 'statusStopCommandSent',
      );
      notifyListeners();
    } catch (e) {
      _setStatus('statusCommandSendError', <String, String>{'error': '$e'});
      notifyListeners();
    }
  }

  Future<void> requestExit() async {
    await _mqttSender.clearRetainedMessages();
    await _sender.stop();
    await _mqttSender.close();
    await SystemNavigator.pop();
  }

  String _fileExtension(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) {
      return '';
    }
    return path.substring(dot + 1).toLowerCase();
  }

  @override
  void dispose() {
    _sender.stop();
    _mqttSender.close();
    super.dispose();
  }
}
