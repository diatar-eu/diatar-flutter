import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, exit;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:diatar_common/diatar_common.dart';
import 'package:diatar_common/utils/transposition_utils.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/path_helper.dart';
import '../utils/file_system_provider.dart';
import '../utils/browser_window_close.dart' as browser_window_close;

import '../core/books/book_sort_policy.dart';
import '../core/custom_order/custom_order_normalizer.dart';
import '../core/custom_order/custom_order_navigation_policy.dart';
import '../core/custom_order/custom_order_bootstrap_policy.dart';
import '../core/custom_order/custom_order_entry_mapper.dart';
import '../core/custom_order/entry_label_service.dart';
import '../core/custom_order/entry_match_policy.dart';
import '../core/custom_order/entry_resolver.dart';
import '../core/dia/dia_ini_parser.dart';
import '../core/dia/dia_matching_policy.dart';
import '../core/dia/dia_path_policy.dart';
import '../core/navigation/song_navigation_policy.dart';
import '../core/navigation/song_selection_policy.dart';
import '../core/settings/projection_globals_policy.dart';
import '../core/settings/transport_settings_policy.dart';
import '../models/custom_order_entry.dart';
import '../models/custom_order_set.dart';
import '../services/mqtt_sender_service.dart';
import '../services/desktop_projector_bridge.dart';
import '../services/dtx_download_service.dart';
import '../services/dtz_download_service.dart';
import '../services/dtx_library_service.dart';
import '../services/dtx_order_store.dart';
import '../services/dtz_library_service.dart';
import '../services/dtz_user_import_service.dart';
import '../services/sender_callback_coordinator.dart';
import '../services/sender_transport_coordinator.dart';
import '../services/song_search_service.dart';
import '../services/settings_store.dart';
import '../services/audio_service.dart';
import '../services/cast_service.dart';
import '../services/tcp_sender_service.dart';
import '../services/zsolozsma_decode_breviar.dart';
import '../services/zsolozsma_service.dart';
import '../services/napi_lelki_batyu_service.dart';
import '../services/szentiras_api_service.dart';
import '../utils/text_chunking.dart';

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

/// Egy diasor betöltésekor választható viselkedés:
/// felülírja az aktuálisan aktív diasort, vagy új, párhuzamos diasorként
/// töltődik be a már betöltöttek mellé.
enum CustomOrderImportMode { overwriteActive, addNew }

class DiatarMainController extends ChangeNotifier {
  final DtxParser _parser = const DtxParser();
  final DiaIniParser _diaIniParser = const DiaIniParser();
  final DiaMatchingPolicy _diaMatchingPolicy = const DiaMatchingPolicy();
  final DiaPathPolicy _diaPathPolicy = const DiaPathPolicy();
  final BookSortPolicy _bookSortPolicy = const BookSortPolicy();
  final SongNavigationPolicy _songNavigationPolicy =
      const SongNavigationPolicy();
  final SongSelectionPolicy _songSelectionPolicy = const SongSelectionPolicy();
  final CustomOrderNavigationPolicy _customOrderNavigationPolicy =
      const CustomOrderNavigationPolicy();
  final CustomOrderBootstrapPolicy _customOrderBootstrapPolicy =
      const CustomOrderBootstrapPolicy();
  final CustomOrderEntryMapper _customOrderEntryMapper =
      const CustomOrderEntryMapper();
  final ProjectionGlobalsPolicy _projectionGlobalsPolicy =
      const ProjectionGlobalsPolicy();
  final TransportSettingsPolicy _transportSettingsPolicy =
      const TransportSettingsPolicy();
  final SenderCallbackCoordinator _senderCallbackCoordinator =
      SenderCallbackCoordinator();
  final SenderTransportCoordinator _senderTransportCoordinator =
      const SenderTransportCoordinator();
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
  final DtzDownloadService _dtzDownloadService = DtzDownloadService();
  late final DtxLibraryService _dtxLibraryService = DtxLibraryService(
    parser: _parser,
  );
  final DtzLibraryService _dtzLibraryService = const DtzLibraryService();
  final DtzUserImportService _dtzUserImportService =
      const DtzUserImportService();
  final DtxOrderStore _orderStore = DtxOrderStore();
  final ZsolozsmaService _zsolozsmaService = ZsolozsmaService();
  final ZsolozsmaBreviarDecoder _zsolozsmaDecoder = ZsolozsmaBreviarDecoder();
  final NapiLelkiBatyuService _napiLelkiBatyuService = NapiLelkiBatyuService();
  final SongSearchService _searchService = SongSearchService();
  final AudioService _audioService = AudioService();
  final TcpSenderService _sender = TcpSenderService(
    onStatusChanged: (bool connected) {},
    onError: (String code, Map<String, String> params) {},
  );
  final MqttSenderService _mqttSender = MqttSenderService(
    onStatusChanged: (bool connected) {},
    onError: (String code, Map<String, String> params) {},
  );
  final DesktopProjectorBridge _desktopProjectorBridge =
      DesktopProjectorBridge.instance;
  CastService? _castService;

  List<DtxBook> books = <DtxBook>[];
  int bookIndex = 0;
  int songIndex = 0;
  int verseIndex = 0;
  int highPos = 0;
  int _renderedHighlightWordCount = -1;
  bool _highlightFullyRendered = false;
  bool showing = false;
  bool loading = false;
  bool pendingOnboarding = false;
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
  Set<String> _disabledDtzFiles = <String>{};
  bool _hasSavedDtzExclusions = false;
  List<CustomOrderEntry> _customOrder = <CustomOrderEntry>[];
  bool customOrderActive = false;
  int _customOrderCursor = -1;
  int _projectedCustomCursor = -1;
  String? _lastImportedCustomOrderBaseName;
  bool _diaVirtualBookSelected = false;
  Map<String, int> _lastSongPerBook = <String, int>{};
  Map<String, int> _lastVersePerBook = <String, int>{};
  bool _startupDownloadDialogHandled = false;
  bool _startupDownloadDialogRequested = false;
  String _zsolozsmaLastDiagnostics = '';
  String? _customOrderSourceType;
  static const String _disabledDtzPrefsKey = 'disabled_dtz_files';

  /// A párhuzamosan betöltött diasorok (saját diasorok) listája.
  List<CustomOrderSet> _customOrderSets = <CustomOrderSet>[];

  /// Az éppen aktív (navigált/vetített) diasor indexe a [_customOrderSets]
  /// listában, vagy -1 ha nincs betöltve egy sem.
  int _activeOrderSetIndex = -1;

  /// Egyedi azonosító-generálás új diasorokhez.
  int _customOrderSetIdCounter = 0;

  CustomOrderSet? get _activeOrderSet {
    if (_activeOrderSetIndex < 0 ||
        _activeOrderSetIndex >= _customOrderSets.length) {
      return null;
    }
    return _customOrderSets[_activeOrderSetIndex];
  }

  /// Az aktív diasor egyedi azonosítója, vagy null ha nincs betöltve.
  String? get activeCustomOrderSetId => _activeOrderSet?.id;

  String _nextCustomOrderSetId() {
    _customOrderSetIdCounter++;
    return 'set_${DateTime.now().microsecondsSinceEpoch}_$_customOrderSetIdCounter';
  }

  String? _normalizeLoadedCustomOrderBaseName(
    String? baseName,
    String? sourceType,
  ) {
    final String normalizedBase = (baseName ?? '').trim();
    if (normalizedBase.isEmpty) {
      return null;
    }
    final String normalizedSource = (sourceType ?? '').trim();
    if (normalizedSource.isNotEmpty) {
      return normalizedBase;
    }
    // Legacy migration: an unsaved manual custom order could keep an internal
    // *.bin working name. Treat it as unnamed until the user saves to DIA.
    if (normalizedBase.toLowerCase().endsWith('.bin')) {
      return null;
    }
    return _stripOSSuffix(normalizedBase);
  }

  /// Strips trailing OS-generated filename suffixes like " (1)", " (2)".
  String _stripOSSuffix(String name) {
    final RegExp pattern = RegExp(r'\s+\(\d+\)$');
    String result = name;
    while (pattern.hasMatch(result)) {
      result = result.replaceFirst(pattern, '');
    }
    return result;
  }

  /// Betölti a párhuzamosan tárolt diasoroket a perzisztenciából.
  /// Visszamenőleges kompatibilitás: ha még nincs elmentett diasor-készlet,
  /// de létezik a régi egyetlen saját sorrend, azt átvezeti egyetlen
  /// diasorként.
  Future<void> _loadCustomOrderSets() async {
    final ({List<StoredCustomOrderSet> sets, int activeIndex}) storedSets =
        await _orderStore.loadCustomOrderSets();
    if (storedSets.sets.isNotEmpty) {
      _customOrderSets = storedSets.sets.map((StoredCustomOrderSet s) {
        final String? normalizedBaseName = _normalizeLoadedCustomOrderBaseName(
          s.baseName,
          s.sourceType,
        );
        return CustomOrderSet(
          id: s.id,
          name: s.name,
          entries: s.entries.map(_customOrderEntryMapper.fromStored).toList(),
          enabled: s.enabled,
          baseName: normalizedBaseName,
          sourceType: s.sourceType,
        );
      }).toList();
      _activeOrderSetIndex = storedSets.activeIndex;
      final CustomOrderSet? active = _activeOrderSet;
      if (active != null) {
        _customOrder = List<CustomOrderEntry>.from(active.entries);
        _lastImportedCustomOrderBaseName = active.baseName;
        _customOrderSourceType = active.sourceType;
        customOrderActive = active.entries.isNotEmpty;
        _diaVirtualBookSelected = active.entries.isNotEmpty;
        _customOrderCursor = active.entries.isEmpty
            ? -1
            : active.cursor.clamp(0, active.entries.length - 1);
      } else {
        _customOrder = const <CustomOrderEntry>[];
        customOrderActive = false;
        _diaVirtualBookSelected = false;
      }
    } else {
      // Visszamenőleges kompatibilitás: régi egyéni sorrend átvezetése.
      final CustomOrderBootstrapState customOrderState =
          _customOrderBootstrapPolicy.fromStored(
            await _orderStore.loadCurrentCustomOrder(),
          );
      _customOrder = customOrderState.entries;
      customOrderActive = customOrderState.active;
      _lastImportedCustomOrderBaseName = _normalizeLoadedCustomOrderBaseName(
        customOrderState.baseName,
        customOrderState.sourceType,
      );
      _customOrderSourceType = customOrderState.sourceType;
      _diaVirtualBookSelected = customOrderState.diaVirtualBookSelected;
      if (_customOrder.isNotEmpty) {
        _customOrderSets = <CustomOrderSet>[
          CustomOrderSet(
            id: _nextCustomOrderSetId(),
            name: _lastImportedCustomOrderBaseName ?? 'Diasor',
            entries: List<CustomOrderEntry>.from(_customOrder),
            enabled: true,
            baseName: _lastImportedCustomOrderBaseName,
            sourceType: customOrderState.sourceType,
          ),
        ];
        _activeOrderSetIndex = 0;
        _customOrderCursor = _customOrder.isEmpty ? -1 : 0;
      }
    }
  }

  /// A jelenleg aktív diasor munkapéldányának (_customOrder) és a hozzá
  /// tartozó metaadatoknak a visszaírása a diasor-készletbe.
  void _persistActiveSetToSets() {
    if (_activeOrderSetIndex < 0 ||
        _activeOrderSetIndex >= _customOrderSets.length) {
      return;
    }
    final int safeCursor = _customOrder.isEmpty
        ? -1
        : _customOrderCursor.clamp(0, _customOrder.length - 1);
    _customOrderSets[_activeOrderSetIndex] =
        _customOrderSets[_activeOrderSetIndex].copyWith(
          entries: List<CustomOrderEntry>.from(_customOrder),
          baseName: _lastImportedCustomOrderBaseName,
          sourceType: _customOrderSourceType,
          cursor: safeCursor,
        );
  }

  /// Az összes diasor perzisztens mentése (azonnali írás a tárolóba).
  Future<void> _persistAllSets() async {
    final List<StoredCustomOrderSet> stored = _customOrderSets
        .map(
          (CustomOrderSet s) => StoredCustomOrderSet(
            id: s.id,
            name: s.name,
            entries: s.entries
                .map(
                  (CustomOrderEntry e) => _customOrderEntryMapper.toStored(
                    e,
                    verseIndex: _safeVerseIndex(e),
                  ),
                )
                .toList(),
            enabled: s.enabled,
            baseName: s.baseName,
            sourceType: s.sourceType,
          ),
        )
        .toList();
    await _orderStore.saveCustomOrderSets(
      stored,
      activeIndex: _activeOrderSetIndex,
    );
  }

  /// Átvált a megadott indexű diasorra: először menti az aktuális munkapéldányt,
  /// majd betölti az új diasor bejegyzéseit és metaadatait a munkapéldányba.
  Future<void> _switchActiveSet(int index) async {
    if (index < 0 || index >= _customOrderSets.length) {
      return;
    }
    if (index == _activeOrderSetIndex && _activeOrderSetIndex >= 0) {
      return;
    }
    _persistActiveSetToSets();
    _activeOrderSetIndex = index;
    final CustomOrderSet set = _customOrderSets[index];
    _customOrder = List<CustomOrderEntry>.from(set.entries);
    _lastImportedCustomOrderBaseName = set.baseName;
    _customOrderSourceType = set.sourceType;
    customOrderActive = set.entries.isNotEmpty;
    _diaVirtualBookSelected = set.entries.isNotEmpty;
    _customOrderCursor = set.entries.isEmpty
        ? -1
        : set.cursor.clamp(0, set.entries.length - 1);
    _projectedCustomCursor = -1;
    await _persistAllSets();
    if (customOrderActive) {
      _selectByCustomOrderCursor(_customOrderCursor, sync: false);
      if (_customOrderCursor >= 0 &&
          _customOrderCursor < _customOrder.length &&
          !_customOrder[_customOrderCursor].isSongEntry) {
        await _projectCustomOrderEntry(
          _customOrder[_customOrderCursor],
          cursor: _customOrderCursor,
        );
      } else {
        await _syncCurrentDia();
      }
    } else {
      notifyListeners();
    }
  }

  /// A betöltött diasorok (saját diasorok) listája, csak olvashatóan.
  List<CustomOrderSet> get customOrderSets =>
      List<CustomOrderSet>.unmodifiable(_customOrderSets);

  /// Az éppen aktív diasor indexe a [customOrderSets] listában (-1 ha nincs).
  int get activeCustomOrderSetIndex => _activeOrderSetIndex;

  /// Kiválasztja az aktív diasort a megadott index alapján.
  Future<void> setActiveCustomOrderSet(int index) async {
    await _switchActiveSet(index);
  }

  /// Kiválasztja az aktív diasort a megadott egyedi azonosító alapján.
  Future<void> setActiveCustomOrderSetById(String id) async {
    final int index = _customOrderSets.indexWhere(
      (CustomOrderSet s) => s.id == id,
    );
    if (index < 0) {
      return;
    }
    await _switchActiveSet(index);
  }

  /// A következő engedélyezett diasorra vált (körkörösen).
  /// Ha nincs betöltött diasor, nem csinál semmit.
  Future<void> nextCustomOrderSet() async {
    if (_customOrderSets.isEmpty) {
      return;
    }
    final List<int> enabledIndexes = <int>[];
    for (int i = 0; i < _customOrderSets.length; i++) {
      if (_customOrderSets[i].enabled) {
        enabledIndexes.add(i);
      }
    }
    if (enabledIndexes.length <= 1) {
      return;
    }
    final int currentPos = enabledIndexes.indexOf(_activeOrderSetIndex);
    final int nextPos = currentPos < 0
        ? 0
        : (currentPos + 1) % enabledIndexes.length;
    await _switchActiveSet(enabledIndexes[nextPos]);
  }

  /// Az előző engedélyezett diasorra vált (körkörösen).
  /// Ha nincs betöltött diasor, nem csinál semmit.
  Future<void> prevCustomOrderSet() async {
    if (_customOrderSets.isEmpty) {
      return;
    }
    final List<int> enabledIndexes = <int>[];
    for (int i = 0; i < _customOrderSets.length; i++) {
      if (_customOrderSets[i].enabled) {
        enabledIndexes.add(i);
      }
    }
    if (enabledIndexes.length <= 1) {
      return;
    }
    final int currentPos = enabledIndexes.indexOf(_activeOrderSetIndex);
    final int prevPos = currentPos < 0
        ? 0
        : (currentPos - 1 + enabledIndexes.length) % enabledIndexes.length;
    await _switchActiveSet(enabledIndexes[prevPos]);
  }

  /// Be-/kikapcsolja a megadott diasort a betöltöttek közül.
  /// A kikapcsolt diasor nem lesz elérhető a nézetekben, de megmarad.
  /// Az utolsó engedélyezett diasor nem kapcsolható ki, és ha az aktív
  /// diasort kapcsoljuk ki, az aktív kiválasztás átvált egy másik
  /// engedélyezett diasorra.
  Future<void> toggleCustomOrderSetEnabled(int index) async {
    if (index < 0 || index >= _customOrderSets.length) {
      return;
    }
    final bool currentlyEnabled = _customOrderSets[index].enabled;
    if (currentlyEnabled) {
      final int enabledCount = _customOrderSets
          .where((CustomOrderSet s) => s.enabled)
          .length;
      if (enabledCount <= 1) {
        return;
      }
    }
    _customOrderSets[index] = _customOrderSets[index].copyWith(
      enabled: !currentlyEnabled,
    );
    if (currentlyEnabled && index == _activeOrderSetIndex) {
      final int nextActive = _customOrderSets.indexWhere(
        (CustomOrderSet s) => s.enabled,
      );
      if (nextActive >= 0) {
        await _switchActiveSet(nextActive);
        return;
      }
    }
    await _persistAllSets();
    notifyListeners();
  }

  /// Eltávolítja a megadott diasort a betöltöttek közül.
  Future<void> removeCustomOrderSet(int index) async {
    if (index < 0 || index >= _customOrderSets.length) {
      return;
    }
    final bool wasActive = index == _activeOrderSetIndex;
    _customOrderSets.removeAt(index);
    if (_customOrderSets.isEmpty) {
      _activeOrderSetIndex = -1;
      _customOrder = const <CustomOrderEntry>[];
      customOrderActive = false;
      _diaVirtualBookSelected = false;
      _customOrderCursor = -1;
      _projectedCustomCursor = -1;
      _lastImportedCustomOrderBaseName = null;
      _customOrderSourceType = null;
    } else {
      if (_activeOrderSetIndex > index) {
        _activeOrderSetIndex--;
      } else if (wasActive) {
        _activeOrderSetIndex = _activeOrderSetIndex.clamp(
          0,
          _customOrderSets.length - 1,
        );
        final CustomOrderSet set = _customOrderSets[_activeOrderSetIndex];
        _customOrder = List<CustomOrderEntry>.from(set.entries);
        _lastImportedCustomOrderBaseName = set.baseName;
        _customOrderSourceType = set.sourceType;
        customOrderActive = set.entries.isNotEmpty;
        _diaVirtualBookSelected = set.entries.isNotEmpty;
        _customOrderCursor = set.entries.isEmpty
            ? -1
            : set.cursor.clamp(0, set.entries.length - 1);
        _projectedCustomCursor = -1;
      }
    }
    await _persistAllSets();
    if (customOrderActive) {
      _selectByCustomOrderCursor(_customOrderCursor, sync: false);
      if (_customOrderCursor >= 0 &&
          _customOrderCursor < _customOrder.length &&
          !_customOrder[_customOrderCursor].isSongEntry) {
        await _projectCustomOrderEntry(
          _customOrder[_customOrderCursor],
          cursor: _customOrderCursor,
        );
      } else {
        await _syncCurrentDia();
      }
    } else {
      notifyListeners();
    }
  }

  /// Átnevezi a megadott diasort.
  Future<void> renameCustomOrderSet(int index, String name) async {
    if (index < 0 || index >= _customOrderSets.length) {
      return;
    }
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _customOrderSets[index] = _customOrderSets[index].copyWith(
      name: trimmed,
      baseName: trimmed,
    );
    if (index == _activeOrderSetIndex) {
      _lastImportedCustomOrderBaseName = trimmed;
    }
    await _persistAllSets();
    notifyListeners();
  }

  /// Létrehoz egy új, üres diasort a megadott névvel, hozzáadja a
  /// betöltöttekhez, és aktívvá teszi (az előző diasor szerkesztett
  /// állapota előbb elmentésre kerül).
  Future<void> createCustomOrderSet(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _persistActiveSetToSets();
    final CustomOrderSet newSet = CustomOrderSet(
      id: _nextCustomOrderSetId(),
      name: trimmed,
      entries: const <CustomOrderEntry>[],
      enabled: true,
    );
    _customOrderSets.add(newSet);
    _activeOrderSetIndex = _customOrderSets.length - 1;
    _customOrder = const <CustomOrderEntry>[];
    _lastImportedCustomOrderBaseName = trimmed;
    _customOrderSourceType = null;
    customOrderActive = false;
    _diaVirtualBookSelected = false;
    _customOrderCursor = -1;
    _projectedCustomCursor = -1;
    await _persistAllSets();
    notifyListeners();
  }

  /// A kereséshez eloallitott, izolátumban keresheto index.
  /// `reloadBooks` után épül fel (háttérfolyamatban).
  List<SongSearchSong> _searchIndex = const <SongSearchSong>[];
  List<SongSearchSong> get searchIndex => _searchIndex;

  /// A .dtz fajlokbol betoltott dia-id -> DtxVerse lekepezes.
  Map<String, DtxVerse> _dtzLibrary = <String, DtxVerse>{};

  /// Atmeneti, csak az adott munkamenetre ervenyes kapcsolo: a vezérlő ablak
  /// előnézetében a vetítési előnézet helyett a dia-id-hez tartozo fotot
  /// mutassa-e. A vetítőablakot (es a tobbi kimenetet) ez nem erinti.
  bool _showPhotoInControl = false;
  bool get showPhotoInControl => _showPhotoInControl;

  void toggleControlPhotoView() {
    _showPhotoInControl = !_showPhotoInControl;
    notifyListeners();
  }

  /// Toggle whether chords (akkord) are shown on projection outputs.
  Future<void> toggleChordsVisible() async {
    final AppSettings newSettings = settings.copyWith(
      projUseAkkord: !settings.projUseAkkord,
    );
    await applySettings(newSettings);
  }

  /// Toggle whether sheet music (kotta) is shown on projection outputs.
  Future<void> toggleSheetMusicVisible() async {
    final AppSettings newSettings = settings.copyWith(
      projUseKotta: !settings.projUseKotta,
    );
    await applySettings(newSettings);
  }

  /// Az aktualis versszak dia-id-jehez tartozo foto utvonala, vagy null ha
  /// nincs hozzarendelve foto.
  String? get currentPhotoPath {
    final String? diaId = currentVerse?.diaId;
    if (diaId == null || diaId.isEmpty) {
      return null;
    }
    final DtxVerse? verse = _dtzLibrary[diaId];
    return verse?.fotoFilePath;
  }

  /// A kovetkezo versszak dia-id-jehez tartozo foto utvonala (RAM-előtolteshez),
  String? get nextPhotoPath {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return null;
    }
    final int nextIdx = verseIndex + 1;
    if (nextIdx >= s.verses.length) {
      return null;
    }
    final String? diaId = s.verses[nextIdx].diaId;
    if (diaId == null || diaId.isEmpty) {
      return null;
    }
    final DtxVerse? verse = _dtzLibrary[diaId];
    return verse?.fotoFilePath;
  }

  /// True, ha a betöltött énekek bármelyik versszakához tartozik elérhető
  /// DTZ/ZIP-ből feloldott fotó, így a vezérlőben van értelme a
  /// "Fénykép / vetítés váltása" gombnak.
  bool get hasAnyLoadedVersePhoto {
    if (books.isEmpty || _dtzLibrary.isEmpty) {
      return false;
    }
    for (final DtxBook book in books) {
      for (final DtxSong song in book.songs) {
        for (final DtxVerse verse in song.verses) {
          final String? diaId = verse.diaId;
          if (diaId == null || diaId.isEmpty) {
            continue;
          }
          final String? photoPath = _dtzLibrary[diaId]?.fotoFilePath;
          if (photoPath != null && photoPath.isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

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
  String? get suggestedCustomOrderBaseName => lastImportedCustomOrderBaseName;

  bool get customOrderLooksLikeZsolozsma =>
      _customOrder.isNotEmpty &&
      _customOrder.every(
        (CustomOrderEntry entry) =>
            entry.isCustomText && entry.label.startsWith('[Zsolozsma]'),
      );
  bool get customOrderLooksLikeBatyu =>
      _customOrder.isNotEmpty &&
      _customOrder.every(
        (CustomOrderEntry entry) =>
            entry.isCustomText && entry.label.startsWith('[Batyu]'),
      );
  String get zsolozsmaLastDiagnostics => _zsolozsmaLastDiagnostics;
  bool get hasImportedCustomOrderDia => _customOrder.isNotEmpty;
  bool get diaVirtualBookSelected =>
      _diaVirtualBookSelected && hasImportedCustomOrderDia;
  bool get shouldAutoOpenDownloadDialog =>
      !_startupDownloadDialogHandled &&
      !loading &&
      (statusCode == 'statusNoDtxFiles' || _startupDownloadDialogRequested);
  bool get tcpActive => settings.tcpClientEnabled;
  bool get tcpConfigured => _transportSettingsPolicy.isTcpConfigured(settings);

  /// True, ha asztali környezeten a vetítőablak (külön ablak) elérhető.
  /// Ez a beállítás értékét tükrözi (a felhasználó kapcsolhatja ki).
  bool get desktopProjectorEnabled =>
      _isDesktopPlatform() && settings.desktopProjectorEnabled;

  bool _isDesktopPlatform() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _refreshSenderFlags() {
    senderRunning = _sender.running || _mqttSender.running;
    senderConnected = tcpConnected || mqttConnected;
  }

  void _playCurrentVerseSound() {
    if (!settings.useSound || !showing) {
      _audioService.stop();
      return;
    }
    _audioService.playSound(currentVerse?.soundFilePath);
  }

  void markStartupDownloadDialogHandled() {
    _startupDownloadDialogHandled = true;
    _startupDownloadDialogRequested = false;
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
    _transpositions = await _settingsStore.loadTranspositions();
    _lastSongPerBook = await _settingsStore.loadLastSongPerBook();
    _lastVersePerBook = await _settingsStore.loadLastVersePerBook();
    lastBlankPath = settings.blankPicPath;
    _disabledSongbooks = await _orderStore.loadDisabled();
    _disabledDtzFiles = await _loadDisabledDtzFiles();
    await _loadCustomOrderSets();
    globals = _projectionGlobalsPolicy.fromSettings(
      settings,
      projecting: showing,
      hasBackgroundImage: _hasConfiguredBackgroundImage,
    );

    // A köteteket még a (hálózatfüggő) transport beállítása előtt betöltjük,
    // így a könyvtár azonnal használható akkor is, ha az MQTT/TCP kapcsolat
    // lassú vagy elérhetetlen.
    await reloadBooks();

    await _desktopProjectorBridge.start(settings);
    _desktopProjectorBridge.onControlWindowRestored = () {
      if (_controlWindowHidden) {
        _controlWindowHidden = false;
        notifyListeners();
      }
    };
    _configureSender();
    await _applyTransport();
    if (settings.castEnabled && !kIsWeb) {
      _castService ??= CastService();
      await _castService!.initialize();
    }
    unawaited(_checkStartupDtxUpdates());
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
      await _syncCurrentDia(playSound: false);
    }
    final bool hasSeen = await _settingsStore.hasSeenOnboarding();
    if (!hasSeen) {
      pendingOnboarding = true;
      notifyListeners();
    }
  }

  Future<void> markOnboardingSeen() async {
    await _settingsStore.markOnboardingSeen();
    pendingOnboarding = false;
    notifyListeners();
  }

  Future<void> _tryAutoLoadTodayDia() async {
    final String basePath = settings.diaExportPath.trim();
    if (basePath.isEmpty) {
      return;
    }

    if (kIsWeb) return;

    final Directory dir = FileSystemProvider.instance.directory(basePath);
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
      final File candidate = FileSystemProvider.instance.file(
        '${dir.path}/$name.dia',
      );
      if (await candidate.exists()) {
        await importCustomOrderFromDia(candidate.path, activate: true);
        return;
      }
    }
  }

  Future<Set<String>> _loadDisabledDtzFiles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _hasSavedDtzExclusions = prefs.containsKey(_disabledDtzPrefsKey);
    return (prefs.getStringList(_disabledDtzPrefsKey) ?? const <String>[])
        .map((String name) => name.trim())
        .where((String name) => name.isNotEmpty)
        .toSet();
  }

  Future<void> _saveDisabledDtzFiles(Set<String> files) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> normalized =
        files
            .map((String name) => name.trim())
            .where((String name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    await prefs.setStringList(_disabledDtzPrefsKey, normalized);
    _hasSavedDtzExclusions = true;
  }

  Future<void> _checkStartupDtxUpdates() async {
    if (_startupDownloadDialogHandled || _startupDownloadDialogRequested) {
      return;
    }
    try {
      final List<DtxManageItem> items = await loadDtxManagerItems();
      final bool hasInstalledUpdate = items.any(
        (DtxManageItem managed) =>
            managed.item.isOfficial &&
            managed.item.isInstalled &&
            managed.item.updateAvailable,
      );
      if (!hasInstalledUpdate ||
          _startupDownloadDialogHandled ||
          _startupDownloadDialogRequested) {
        return;
      }
      _startupDownloadDialogRequested = true;
      notifyListeners();
    } catch (_) {
      // Offline or remote list failure should not block startup.
    }
  }

  void _configureSender() {
    _sender.onStatusChanged = _senderCallbackCoordinator
        .buildStatusChangedHandler(
          setConnected: (bool connected) => tcpConnected = connected,
          clearError: () {
            if (_sender.allTargetsConnected) {
              tcpHasError = false;
            }
          },
          syncAfterConnect: _syncBackgroundImageAfterConnect,
          refreshFlags: _refreshSenderFlags,
          notify: notifyListeners,
          onConnected: () {
            _setStatus('statusTcpSending', <String, String>{
              'port': _transportSettingsPolicy.tcpTargetsStatusLabel(settings),
            });
            unawaited(_syncCurrentDia(playSound: false));
          },
        );
    _sender.onError = _senderCallbackCoordinator.buildTcpErrorHandler(
      isActive: () => tcpActive,
      isConnected: () => tcpConnected && _sender.allTargetsConnected,
      markHasError: () => tcpHasError = true,
      setStatus: _setStatus,
      refreshFlags: _refreshSenderFlags,
      notify: notifyListeners,
    );
    _mqttSender.onStatusChanged = _senderCallbackCoordinator
        .buildStatusChangedHandler(
          setConnected: (bool connected) => mqttConnected = connected,
          clearError: () => mqttHasError = false,
          syncAfterConnect: _syncBackgroundImageAfterConnect,
          refreshFlags: _refreshSenderFlags,
          notify: notifyListeners,
          onConnected: () {
            _setStatus('statusMqttSending', <String, String>{
              'user': _transportSettingsPolicy.normalizedMqttUser(settings),
              'channel': settings.mqttChannel,
            });
            unawaited(_syncCurrentDia(playSound: false));
          },
        );
    _mqttSender.onError = _senderCallbackCoordinator.buildMqttErrorHandler(
      isActive: () => mqttActive,
      isConnected: () => mqttConnected,
      markHasError: () => mqttHasError = true,
      setStatus: _setStatus,
      refreshFlags: _refreshSenderFlags,
      notify: notifyListeners,
    );
  }

  Future<void> applySettings(AppSettings newSettings) async {
    final AppSettings previousSettings = settings;
    final bool transportChanged = _transportSettingsPolicy
        .transportSettingsChanged(previousSettings, newSettings);
    settings = newSettings;
    lastBlankPath = settings.blankPicPath;
    await _settingsStore.save(settings);
    try {
      await _desktopProjectorBridge
          .updateSettings(settings)
          .timeout(const Duration(milliseconds: 2500));
    } on TimeoutException {
      _setStatus('statusCommandSendError', <String, String>{
        'error': 'Desktop projector update timeout',
      });
    } catch (error) {
      _setStatus('statusCommandSendError', <String, String>{'error': '$error'});
    }
    globals = _projectionGlobalsPolicy.fromSettings(
      settings,
      projecting: showing,
      hasBackgroundImage: _hasConfiguredBackgroundImage,
    );
    if (transportChanged) {
      await _applyTransport();
    } else {
      _refreshSenderFlags();
    }
    notifyListeners();
    await _syncCurrentDia(playSound: false);
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

  Future<void> setHomeLayoutMode(int mode) async {
    if (settings.homeLayoutMode == mode) {
      return;
    }
    settings = settings.copyWith(homeLayoutMode: mode);
    await _settingsStore.save(settings);
    notifyListeners();
  }

  Future<void> setPresentationControlsVisible(bool visible) async {
    if (settings.presentationControlsVisible == visible) {
      return;
    }
    settings = settings.copyWith(presentationControlsVisible: visible);
    await _settingsStore.save(settings);
    notifyListeners();
  }

  Future<void> saveSzentirasApiKey(String key) async {
    final String trimmed = key.trim();
    if (settings.szentirasApiKey == trimmed) return;
    settings = settings.copyWith(szentirasApiKey: trimmed);
    await _settingsStore.save(settings);
    notifyListeners();
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
    return _dtxLibraryService.resolveDirectory();
  }

  Future<Directory> _resolveZsolozsmaDirectory() async {
    final String docsPath = await PathHelper.getDocumentsDirectoryPath();
    return FileSystemProvider.instance.directory('$docsPath/zsolozsma');
  }

  // ---------------------------------------------------------------------------
  // User DTZ import
  // ---------------------------------------------------------------------------

  /// Reads [files] (DTZ + ZIP) into memory and returns a validation analysis
  /// without touching the file system.
  /// Returns true when [bytes] begin with the ZIP magic signature (PK).
  static bool _bytesLookLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 && // P
        bytes[1] == 0x4B && // K
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  /// Resolves a display name for an imported DTZ/ZIP [file].
  ///
  /// On Android the content resolver sometimes strips the extension from
  /// [XFile.name], so we fall back to extracting the last path segment from
  /// [XFile.path] (which always preserves the original name on Android).
  static String _resolveDtzImportName(XFile file, int index) {
    final String direct = file.name.trim();
    if (direct.isNotEmpty) {
      final String lower = direct.toLowerCase();
      if (lower.endsWith('.dtz') || lower.endsWith('.zip')) {
        return direct;
      }
    }
    // Fall back to path-based extraction (same strategy as DtxImportPolicy).
    final Uri? parsed = Uri.tryParse(file.path);
    if (parsed != null && parsed.pathSegments.isNotEmpty) {
      final String last = Uri.decodeComponent(parsed.pathSegments.last).trim();
      if (last.isNotEmpty) return last;
    }
    final String normalized = file.path.replaceAll('\\', '/').trim();
    if (normalized.isNotEmpty) {
      final List<String> segments = normalized.split('/');
      final String last = segments.isNotEmpty ? segments.last.trim() : '';
      if (last.isNotEmpty) return last;
    }
    return direct.isNotEmpty ? direct : 'file_${index + 1}';
  }

  /// Reads [files] and categorises them into DTZ and ZIP buckets.
  /// ZIP detection is content-based (magic bytes) so that files without a
  /// recognisable extension (common on Android content URIs) are handled
  /// correctly.
  Future<(Map<String, List<int>> dtz, Map<String, List<int>> zip)>
  _categoriseDtzFiles(List<XFile> files) async {
    final Map<String, List<int>> dtzFiles = <String, List<int>>{};
    final Map<String, List<int>> zipFiles = <String, List<int>>{};
    for (int i = 0; i < files.length; i++) {
      final XFile file = files[i];
      final List<int> bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      final String name = _resolveDtzImportName(file, i);
      // Use magic bytes as primary classifier; fall back to extension.
      if (_bytesLookLikeZip(bytes) || name.toLowerCase().endsWith('.zip')) {
        zipFiles[name] = bytes;
      } else {
        // Treat everything else as a candidate DTZ (text format).
        // Normalise the name: strip legacy .bin suffix and ensure .dtz extension.
        String dtzName = name;
        if (dtzName.toLowerCase().endsWith('.bin.dtz')) {
          dtzName = '${dtzName.substring(0, dtzName.length - 8)}.dtz';
        } else if (dtzName.toLowerCase().endsWith('.bin')) {
          dtzName = '${dtzName.substring(0, dtzName.length - 4)}.dtz';
        } else if (!dtzName.toLowerCase().endsWith('.dtz')) {
          dtzName = '$dtzName.dtz';
        }
        dtzFiles[dtzName] = bytes;
      }
    }
    return (dtzFiles, zipFiles);
  }

  Future<DtzUserImportAnalysis> analyzeDtzUserImport(List<XFile> files) async {
    final (Map<String, List<int>> dtzFiles, Map<String, List<int>> zipFiles) =
        await _categoriseDtzFiles(files);
    return _dtzUserImportService.analyze(
      dtzFiles: dtzFiles,
      zipFiles: zipFiles,
      availableDiaIds: _availableDiaIds(),
    );
  }

  /// dia-IDs of all loaded DTX books (from the '#' lines). These are the IDs
  /// the DTZ import validation considers known, since a photo is only
  /// displayable when a loaded song verse references it.
  Set<String> _availableDiaIds() {
    final Set<String> ids = <String>{};
    for (final DtxBook book in books) {
      for (final DtxSong song in book.songs) {
        for (final DtxVerse verse in song.verses) {
          final String? diaId = verse.diaId;
          if (diaId != null && diaId.isNotEmpty) {
            ids.add(diaId);
          }
        }
      }
    }
    return ids;
  }

  /// Commits previously analysed packages to the DTZ directory.
  Future<DtzUserImportCommitResult> commitDtzUserImport({
    required List<DtzImportPackageAnalysis> toImport,
    required List<XFile> files,
  }) async {
    final (Map<String, List<int>> dtzFiles, Map<String, List<int>> zipFiles) =
        await _categoriseDtzFiles(files);
    final Directory dtzDir = await _dtzDownloadService.resolveDirectory();
    final DtzUserImportCommitResult result = await _dtzUserImportService.commit(
      toImport: toImport,
      dtzFiles: dtzFiles,
      zipFiles: zipFiles,
      targetDir: dtzDir,
    );
    if (result.importedDtzCount > 0) {
      await reloadBooks();
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // User DTX import
  // ---------------------------------------------------------------------------

  /// Copies the given [files] (picked via file picker) into the internal DTX
  /// directory, then reloads books.
  Future<DtxImportResult> importDtxFiles(List<XFile> files) async {
    final DtxLibraryImportResult result = await _dtxLibraryService.importFiles(
      files,
    );
    if (result.importedCount > 0) {
      _disabledSongbooks.removeAll(result.importedFileNames);
      await _orderStore.saveDisabled(_disabledSongbooks);
      await reloadBooks();
    }
    return DtxImportResult(
      importedCount: result.importedCount,
      failures: result.failures,
    );
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

  Future<bool> selectZsolozsmaPart(
    DateTime date,
    ZsolozsmaDayPart part, {
    int? insertAtIndex,
  }) async {
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

    final List<CustomOrderEntry> combined = _insertEntriesIntoOrder(
      entries,
      insertAtIndex,
    );
    await applyCustomOrder(combined, activate: true);
    _logZsolozsmaDebug('applyCustomOrder complete entries=${entries.length}');
    final String zsolozsmaLabel = '${_formatDateIso(day)} ${part.title.trim()}'
        .trim();
    _lastImportedCustomOrderBaseName = zsolozsmaLabel;
    await _persistCurrentCustomOrder();
    _persistActiveSetToSets();
    await _persistAllSets();
    _diaVirtualBookSelected = combined.isNotEmpty;
    final int selectIndex = insertAtIndex == null
        ? 0
        : insertAtIndex.clamp(0, combined.length - 1);
    if (combined.isNotEmpty) {
      _selectByCustomOrderCursor(selectIndex, sync: true);
      _logZsolozsmaDebug('selected custom order entry at $selectIndex');
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

  /// Loads the celebrations (ünnepek) of a given day from the Napi Lelki Batyu
  /// service. Returns an empty list if the data is not available.
  Future<List<NapiLelkiBatyuCelebration>> loadBatyuCelebrations(
    DateTime date,
  ) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    try {
      final Map<String, dynamic> dayJson = await _napiLelkiBatyuService
          .fetchDayJson(day);
      final List<NapiLelkiBatyuCelebration> celebrations =
          _napiLelkiBatyuService.parseCelebrations(dayJson);
      final String dateLabel = _formatDateIso(day);
      if (celebrations.isEmpty) {
        _setStatus('statusBatyuDayEmpty', <String, String>{'date': dateLabel});
      } else {
        _setStatus('statusBatyuDayLoaded', <String, String>{
          'date': dateLabel,
          'count': '${celebrations.length}',
        });
      }
      notifyListeners();
      return celebrations;
    } catch (e) {
      _setStatus('statusBatyuDayError', <String, String>{'error': '$e'});
      notifyListeners();
      rethrow;
    }
  }

  /// Imports a Napi Lelki Batyu celebration as a virtual custom-order book.
  ///
  /// [wordsPerSlide] controls how many words are kept on a single imported
  /// slide before the text is split into the next slide.
  Future<bool> importNapiLelkiBatyu(
    DateTime date,
    NapiLelkiBatyuCelebration celebration, {
    int wordsPerSlide = 30,
    int? insertAtIndex,
  }) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final List<CustomOrderEntry> entries = _napiLelkiBatyuService.buildEntries(
      celebration,
      wordsPerSlide: wordsPerSlide,
    );

    if (entries.isEmpty) {
      _setStatus('statusBatyuPartLoadError', <String, String>{
        'title': celebration.title,
      });
      notifyListeners();
      return false;
    }

    final List<CustomOrderEntry> combined = _insertEntriesIntoOrder(
      entries,
      insertAtIndex,
    );
    await applyCustomOrder(combined, activate: true);
    final String batyuLabel =
        '${_formatDateIso(day)} ${celebration.title.trim()}'.trim();
    _lastImportedCustomOrderBaseName = batyuLabel;
    await _persistCurrentCustomOrder();
    _persistActiveSetToSets();
    await _persistAllSets();
    _diaVirtualBookSelected = combined.isNotEmpty;
    final int selectIndex = insertAtIndex == null
        ? 0
        : insertAtIndex.clamp(0, combined.length - 1);
    if (combined.isNotEmpty) {
      _selectByCustomOrderCursor(selectIndex, sync: true);
    }

    _setStatus('statusBatyuPartLoaded', <String, String>{
      'date': _formatDateIso(day),
      'title': celebration.title,
      'count': '${entries.length}',
    });
    notifyListeners();
    return true;
  }

  /// Returns the index at which a newly inserted block should be placed:
  /// right after the current cursor, or at the end when the cursor is invalid.
  int get customOrderInsertionIndex {
    if (_customOrder.isEmpty) {
      return 0;
    }
    final int cursor = _customOrderCursor;
    if (cursor < 0 || cursor >= _customOrder.length) {
      return _customOrder.length;
    }
    return cursor + 1;
  }

  List<CustomOrderEntry> _insertEntriesIntoOrder(
    List<CustomOrderEntry> entries,
    int? insertAtIndex,
  ) {
    if (insertAtIndex == null) {
      return entries;
    }
    final int index = insertAtIndex.clamp(0, _customOrder.length);
    final List<CustomOrderEntry> combined = List<CustomOrderEntry>.from(
      _customOrder,
    );
    combined.insertAll(index, entries);
    return combined;
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
    final TransportRuntimeState runtime = _transportSettingsPolicy.runtimeState(
      settings,
    );
    _senderCallbackCoordinator.invalidatePendingErrors();
    mqttActive = runtime.mqttActive;
    mqttConnectAttemptAt = runtime.mqttConnectAttemptAt;
    mqttConnected = false;
    mqttHasError = false;
    tcpConnectAttemptAt = runtime.tcpConnectAttemptAt;
    tcpConnected = false;
    tcpHasError = false;

    await _senderTransportCoordinator.apply(
      mqttSender: _mqttSender,
      tcpSender: _sender,
      runtime: runtime,
      mqttPassword: settings.mqttPassword,
      mqttChannel: settings.mqttChannel,
      screenWidth: _screenWidth,
      screenHeight: _screenHeight,
    );

    if (runtime.mqttActive) {
      if (mqttConnected) {
        _setStatus('statusMqttSending', <String, String>{
          'user': runtime.mqttUser,
          'channel': settings.mqttChannel,
        });
      }
    }

    if (runtime.tcpConfigured) {
      if (tcpConnected) {
        _setStatus('statusTcpSending', <String, String>{
          'port': _transportSettingsPolicy.tcpTargetsStatusLabel(settings),
        });
      }
    }
    _refreshSenderFlags();
  }

  bool get _projectionOutputLocked => settings.projectionLocked;

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
      await _senderTransportCoordinator.sendScreenSize(
        tcpSender: _sender,
        screenWidth: _screenWidth,
        screenHeight: _screenHeight,
      );
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
      await _loadDtzPhotos();
      await _persistCurrentCustomOrder();
      _persistActiveSetToSets();
      await _persistAllSets();

      // Keresési index építése háttérfolyamatban (nem fagyasztja az UI-t).
      _searchIndex = await compute(buildSearchIndex, books);
    } catch (e) {
      _setStatus('statusLoadError', <String, String>{'error': '$e'});
      books = const <DtxBook>[];
      _searchIndex = const <SongSearchSong>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Betolti a .dtz fajlokbol a dia-id -> foto utvonal lekepezeseket.
  Future<void> _loadDtzPhotos() async {
    try {
      _dtzLibrary = await _dtzLibraryService.loadLibrary();
    } catch (_) {
      _dtzLibrary = <String, DtxVerse>{};
    }
  }

  Future<List<DtxBook>> _loadBooksFromDisk() async {
    return _dtxLibraryService.loadBooks();
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

  /// Returns true when the entry at [index] is a merge leader
  /// (its [CustomOrderEntry.mergeWithNext] flag is set).
  bool isCustomOrderEntryMergeLeaderAt(int index) {
    if (index < 0 || index >= _customOrder.length) return false;
    return _customOrder[index].mergeWithNext;
  }

  /// Returns true when the entry at [index] immediately follows a merge leader.
  bool isCustomOrderEntryMergeFollowerAt(int index) {
    if (index <= 0 || index >= _customOrder.length) return false;
    return _customOrder[index - 1].mergeWithNext;
  }

  static String _normalizeMergeLabelSlashSpacing(String text) {
    return text.replaceAll(RegExp(r'\s*/\s*'), '/').trim();
  }

  static bool _isMergeLabelBoundaryChar(String ch) {
    return ch == ' ' ||
        ch == ':' ||
        ch == '/' ||
        ch == ',' ||
        ch == '-' ||
        ch == '(' ||
        ch == ')' ||
        ch == '[' ||
        ch == ']' ||
        ch == '{' ||
        ch == '}';
  }

  static String _semanticSharedMergeLabelPrefix(String left, String right) {
    final int limit = math.min(left.length, right.length);
    int rawShared = 0;
    while (rawShared < limit && left[rawShared] == right[rawShared]) {
      rawShared++;
    }
    if (rawShared == 0) {
      return '';
    }
    int boundary = 0;
    for (int i = 0; i < rawShared; i++) {
      if (_isMergeLabelBoundaryChar(left[i])) {
        boundary = i + 1;
      }
    }
    if (boundary <= 0) {
      return '';
    }
    return left.substring(0, boundary);
  }

  @visibleForTesting
  static String formatMergedProjectionLabel(
    String leaderLabel,
    String followerLabel,
  ) {
    final String left = _normalizeMergeLabelSlashSpacing(leaderLabel);
    final String right = _normalizeMergeLabelSlashSpacing(followerLabel);
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    if (left == right) return left;

    final String sharedPrefix = _semanticSharedMergeLabelPrefix(left, right);
    if (sharedPrefix.isEmpty) {
      return '$left, $right';
    }

    final String leftSuffix = left.substring(sharedPrefix.length).trimLeft();
    final String rightSuffix = right.substring(sharedPrefix.length).trimLeft();
    if (leftSuffix.isEmpty || rightSuffix.isEmpty) {
      return '$left, $right';
    }
    return '$sharedPrefix$leftSuffix, $rightSuffix';
  }

  /// Returns the combined display label for the merge-pair starting at [index].
  String customOrderProjectionTitleAt(int index) {
    if (!isCustomOrderEntryMergeLeaderAt(index)) {
      return _customOrder[index].label;
    }
    final String leader = _customOrder[index].label;
    if (index + 1 < _customOrder.length) {
      final String follower = _customOrder[index + 1].label;
      return formatMergedProjectionLabel(leader, follower);
    }
    return leader;
  }

  /// The combined title for the currently projected custom-order entry, or
  /// null when there is no active merge-leader at the cursor.
  String? get currentCustomOrderProjectionTitle {
    final int cursor = selectedCustomOrderCursor;
    if (!isCustomOrderEntryMergeLeaderAt(cursor)) return null;
    return customOrderProjectionTitleAt(cursor);
  }

  /// Maps a raw list index to the effective selection-cursor index.
  /// For a follower entry this returns the leader's index.
  int normalizeCustomOrderIndex(int index) {
    return isCustomOrderEntryMergeFollowerAt(index) ? index - 1 : index;
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
    final DtxBook? oldBook = currentBook;
    if (oldBook != null) {
      _lastSongPerBook[oldBook.fileName] = songIndex;
      _lastVersePerBook[oldBook.fileName] = verseIndex;
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

    // Ha beállított diasor van aktív, a kötetek nézetben is maradjon
    // kiválasztva (ne ugorjon vissza egy kötetre), így a diasor
    // váltása minden nézetben nyomon követhető.
    if (_activeOrderSetIndex >= 0 && _customOrder.isNotEmpty) {
      _diaVirtualBookSelected = true;
      _projectedCustomCursor = -1;
      notifyListeners();
      unawaited(_syncCurrentDia());
      return;
    }

    _diaVirtualBookSelected = false;
    _projectedCustomCursor = -1;

    final DtxBook? book = currentBook;
    if (book != null) {
      final int? savedSong = _lastSongPerBook[book.fileName];
      if (savedSong != null && savedSong < book.songs.length) {
        songIndex = savedSong;
        verseIndex =
            _lastVersePerBook[book.fileName]?.clamp(
              0,
              book.songs[savedSong].verses.length - 1,
            ) ??
            0;
      }
    }

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
            (CustomOrderEntry e) => _customOrderEntryMapper.toStored(
              e,
              verseIndex: _safeVerseIndex(e),
            ),
          )
          .toList(),
      active: customOrderActive,
      baseName: _customOrder.isEmpty ? null : _lastImportedCustomOrderBaseName,
      sourceType: _customOrder.isEmpty ? null : _customOrderSourceType,
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
    return entries.map(_customOrderEntryMapper.fromStored).toList();
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
          (CustomOrderEntry e) => _customOrderEntryMapper.toStored(
            e,
            verseIndex: _safeVerseIndex(e),
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
      _persistActiveSetToSets();
      await _persistAllSets();
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
      _persistActiveSetToSets();
      await _persistAllSets();
      notifyListeners();
    }
  }

  Future<void> syncProjectionToCurrentDia() async {
    _projectedCustomCursor = -1;
    if (customOrderActive &&
        _customOrderCursor >= 0 &&
        _customOrderCursor < _customOrder.length) {
      _selectByCustomOrderCursor(_customOrderCursor, sync: true);
      return;
    }
    await _syncCurrentDia();
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

  Future<List<DtzManageItem>> loadDtzManagerItems() async {
    final Directory dtzDir = await _dtzDownloadService.resolveDirectory();
    final Map<String, String> dtxTitles = <String, String>{};
    for (final DtxBook book in books) {
      final String base = book.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      dtxTitles[base] = book.title;
    }
    try {
      final Map<String, String> remoteTitles = await _downloadService
          .loadRemoteTitleMap();
      for (final MapEntry<String, String> entry in remoteTitles.entries) {
        dtxTitles.putIfAbsent(entry.key, () => entry.value);
      }
    } catch (_) {
      // If remote title lookup fails, keep local titles/fallbacks.
    }
    final List<DtzDownloadItem> all = await _dtzDownloadService.listAll(
      targetDir: dtzDir,
      dtxTitles: dtxTitles,
    );
    return all
        .map(
          (DtzDownloadItem item) => DtzManageItem(
            item: item,
            excluded: _hasSavedDtzExclusions
                ? _disabledDtzFiles.contains(item.fileName)
                : true,
          ),
        )
        .toList();
  }

  Future<int> deleteDtzFiles(Set<String> fileNames) async {
    final Directory dtzDir = await _dtzDownloadService.resolveDirectory();
    final int deleted = await _dtzDownloadService.deleteLocalFiles(
      targetDir: dtzDir,
      fileNames: fileNames,
    );
    if (deleted > 0) {
      await reloadBooks();
      await _loadDtzPhotos();
    }
    return deleted;
  }

  Future<void> applyDtzManagerSelection({
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
      final Set<String> effectiveExcluded = excludedSelected
          .map((String name) => name.trim())
          .where((String name) => name.isNotEmpty)
          .toSet();

      // A mellőzés-módosítást mindenekelőtt mentjük, így az
      // hálózati/letöltési hiba esetén is érvényesül.
      _disabledDtzFiles = effectiveExcluded;
      await _saveDisabledDtzFiles(_disabledDtzFiles);

      try {
        final Directory dtzDir = await _dtzDownloadService.resolveDirectory();
        final int deleted = await _dtzDownloadService.deleteLocalFiles(
          targetDir: dtzDir,
          fileNames: effectiveExcluded,
        );
        if (deleted > 0) {
          await reloadBooks();
        }
        await _loadDtzPhotos();
        final List<DtzDownloadItem> all = await _dtzDownloadService.listAll(
          targetDir: dtzDir,
        );
        final Map<String, DtzDownloadItem> byFile = <String, DtzDownloadItem>{
          for (final DtzDownloadItem item in all) item.fileName: item,
        };

        final Set<String> effectiveDownload = downloadSelected
            .map((String n) => n.trim())
            .where((String n) => n.isNotEmpty)
            .where((String n) {
              final DtzDownloadItem? item = byFile[n];
              return item != null && item.isOfficial && item.updateAvailable;
            })
            .toSet();

        if (_disabledDtzFiles.intersection(effectiveDownload).isNotEmpty) {
          _disabledDtzFiles.removeAll(effectiveDownload);
          await _saveDisabledDtzFiles(_disabledDtzFiles);
          await _loadDtzPhotos();
        }

        downloadTotalFiles = effectiveDownload.length;

        final List<DtzDownloadItem> selected = effectiveDownload
            .map((String n) => byFile[n]!)
            .toList();

        if (selected.isEmpty) {
          _setStatus('statusDownloadSummaryNone');
        } else {
          final DtzDownloadSummary summary = await _dtzDownloadService
              .downloadUpdates(
                targetDir: dtzDir,
                selected: selected,
                onProgress: (DtzDownloadProgress progress) {
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
          _setStatus('statusDownloadSummary', <String, String>{
            'downloaded': '${summary.downloaded}',
            'skipped': '${summary.skipped}',
          });
        }
      } catch (e) {
        _setStatus('statusDownloadError', <String, String>{'error': '$e'});
      }
    } catch (e) {
      _setStatus('statusDownloadError', <String, String>{'error': '$e'});
    } finally {
      downloadInProgress = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<String> exportCustomOrderToDia(
    String path, {
    bool recordSave = true,
  }) async {
    final String safePath = path.toLowerCase().endsWith('.dia')
        ? path
        : '$path.dia';
    final File diaFile = FileSystemProvider.instance.file(safePath);
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
    if (recordSave) {
      await markCustomOrderDiaExportSaved(safePath);
    }
    return safePath;
  }

  Future<void> markCustomOrderDiaExportSaved(
    String path, {
    String? explicitName,
  }) async {
    String? cleanName;
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      // Androidon a rendszer mentési ablakából a valódi fájlnevet kapjuk
      // (DISPLAY_NAME), azt használjuk a diasor nevéhez — a desktop
      // viselkedéssel azonosan, az OS-utótagok (pl. " (1)") levágásával.
      cleanName = _stripOSSuffix(_stripFileExtension(explicitName.trim()));
    } else if (!path.trim().toLowerCase().startsWith('content://')) {
      // Android SAF URIs (content://...) nem hordoznak megbízható fájlnevet,
      // pl. a letöltések tárháza msf:<id> formátumot ad vissza. Ilyenkor nem
      // nevezhetjük át a diasort a mentési útvonal alapján.
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
      cleanName = _stripOSSuffix(savedName);
    }
    if (cleanName != null) {
      final String normalizedName = cleanName.trim();
      _lastImportedCustomOrderBaseName = normalizedName.isEmpty
          ? null
          : normalizedName;
      if (_activeOrderSetIndex >= 0 &&
          _activeOrderSetIndex < _customOrderSets.length) {
        _customOrderSets[_activeOrderSetIndex] =
            _customOrderSets[_activeOrderSetIndex].copyWith(
              name: normalizedName,
              baseName: normalizedName,
              sourceType: null,
            );
      }
    }
    _customOrderSourceType = null;
    await _persistCurrentCustomOrder();
    await _persistAllSets();
    _setStatus('statusOrderSaved', <String, String>{'path': path});
    notifyListeners();
  }

  Future<int> importCustomOrderFromDia(
    String path, {
    bool activate = true,
    String? sourceFileName,
    CustomOrderImportMode mode = CustomOrderImportMode.addNew,
  }) async {
    final File f = FileSystemProvider.instance.file(path);
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

    final String importedName = _stripFileExtension(
      (sourceFileName ?? _fileNameFromPath(path)).trim(),
    );
    final String? baseName = importedName.trim().isEmpty ? null : importedName;

    if (mode == CustomOrderImportMode.overwriteActive &&
        _activeOrderSetIndex >= 0) {
      // Felülírjuk az éppen aktív diasort a betöltöttel.
      await applyCustomOrder(imported, activate: activate);
      _lastImportedCustomOrderBaseName = baseName;
      _customOrderSourceType = null;
      _customOrderSets[_activeOrderSetIndex] =
          _customOrderSets[_activeOrderSetIndex].copyWith(
            name: baseName ?? _customOrderSets[_activeOrderSetIndex].name,
            baseName: baseName,
            sourceType: null,
            cursor: _customOrder.isEmpty
                ? -1
                : _customOrderCursor.clamp(0, _customOrder.length - 1),
          );
      await _persistCurrentCustomOrder();
      await _persistAllSets();
    } else {
      // Új, párhuzamos diasorként töltjük be a már betöltöttek mellé.
      // Előbb elmentjük az eddigi aktív diasor kurzorát, mielőtt
      // átváltunk az újonnan betöltöttre.
      _persistActiveSetToSets();
      final CustomOrderSet newSet = CustomOrderSet(
        id: _nextCustomOrderSetId(),
        name: baseName ?? 'Diasor',
        entries: imported.map(normalizeEntry).toList(),
        enabled: true,
        baseName: baseName,
        sourceType: null,
      );
      _customOrderSets.add(newSet);
      _activeOrderSetIndex = _customOrderSets.length - 1;
      _customOrder = List<CustomOrderEntry>.from(newSet.entries);
      _lastImportedCustomOrderBaseName = baseName;
      _customOrderSourceType = null;
      customOrderActive = activate && imported.isNotEmpty;
      _diaVirtualBookSelected = imported.isNotEmpty;
      _customOrderCursor = imported.isEmpty ? -1 : 0;
      _projectedCustomCursor = -1;
      await _persistCurrentCustomOrder();
      await _persistAllSets();
      if (customOrderActive) {
        _selectByCustomOrderCursor(_customOrderCursor, sync: false);
        await _syncCurrentDia();
      }
    }

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

  Future<int> deleteDtxFiles(Set<String> fileNames) async {
    final Directory dtxDir = await _resolveDtxDirectory();
    final int deleted = await _downloadService.deleteLocalFiles(
      targetDir: dtxDir,
      fileNames: fileNames,
    );
    if (deleted > 0) {
      await reloadBooks();
    }
    return deleted;
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
      final Set<String> effectiveExcluded = excludedSelected
          .map((String name) => name.trim())
          .where((String name) => name.isNotEmpty)
          .toSet();

      // A mellőzés-módosítást mindenekelőtt mentjük, így az
      // hálózati/letöltési hiba esetén is érvényesül.
      _disabledSongbooks = effectiveExcluded;
      await _orderStore.saveDisabled(_disabledSongbooks);

      try {
        final Directory dtxDir = await _resolveDtxDirectory();
        await _downloadService.deleteLocalFiles(
          targetDir: dtxDir,
          fileNames: effectiveExcluded,
        );
        await reloadBooks();
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

        if (_disabledSongbooks.intersection(effectiveDownload).isNotEmpty) {
          _disabledSongbooks.removeAll(effectiveDownload);
          await _orderStore.saveDisabled(_disabledSongbooks);
          await reloadBooks();
        }

        downloadTotalFiles = effectiveDownload.length;

        final List<DtxDownloadItem> selectedForDownload = effectiveDownload
            .map((String name) => byFile[name]!)
            .toList();

        if (selectedForDownload.isEmpty) {
          _setStatus('statusDownloadSummaryNone');
        } else {
          final DtxDownloadSummary summary = await _downloadService
              .downloadUpdates(
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
          await reloadBooks();
          _setStatus('statusDownloadSummary', <String, String>{
            'downloaded': '${summary.downloaded}',
            'skipped': '${summary.skipped}',
          });
        }
      } catch (e) {
        _setStatus('statusDownloadError', <String, String>{'error': '$e'});
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

  /// A dalokhoz tartozo transzpozicio eltolasok (felhasznaloi beallitas).
  /// Kulcs: "konyvFajlneve|enekIndex".
  Map<String, int> _transpositions = <String, int>{};

  String get _currentSongKey {
    final DtxBook? b = currentBook;
    if (b == null) return '';
    return '${b.fileName}|$songIndex';
  }

  /// Az aktualis enek transzpozicio eltolasa (felhasznaloi beallitas,
  /// vagy a dal alapértelmezett transzpozicioja).
  int get currentTransposition =>
      _transpositions[_currentSongKey] ?? currentSong?.transposition ?? 0;

  List<String> get displayLines {
    final DtxVerse? v = currentVerse;
    if (v == null || v.lines.isEmpty) {
      return const <String>[''];
    }
    final int offset = currentTransposition;
    if (offset == 0) return v.lines;
    return v.lines
        .map((line) => TranspositionUtils.transposeLine(line, offset))
        .toList();
  }

  List<String> get projectionDisplayLines {
    if (!customOrderActive) return displayLines;

    if (_customOrderCursor >= 0 && _customOrderCursor < _customOrder.length) {
      final CustomOrderEntry entry = _customOrder[_customOrderCursor];
      if (entry.isSongEntry &&
          entry.mergeWithNext &&
          _customOrderCursor + 1 < _customOrder.length) {
        final CustomOrderEntry next = _customOrder[_customOrderCursor + 1];
        if (next.isSongEntry &&
            next.fileName == entry.fileName &&
            next.songIndex == entry.songIndex) {
          final DtxSong? s = currentSong;
          if (s != null &&
              next.verseIndex >= 0 &&
              next.verseIndex < s.verses.length) {
            final List<String> currentLines = displayLines;
            final int offset = currentTransposition;
            final List<String> nextLines = offset == 0
                ? s.verses[next.verseIndex].lines
                : s.verses[next.verseIndex].lines
                      .map(
                        (String line) =>
                            TranspositionUtils.transposeLine(line, offset),
                      )
                      .toList();
            if (nextLines.isNotEmpty) {
              return <String>[...currentLines, '', ...nextLines];
            }
          }
        }
      }
    }
    return displayLines;
  }

  /// Beallitja az aktualis enek transzpozicio eltolasat es ujrajelzi a vetítést.
  Future<void> setTransposition(int semitones) async {
    final String key = _currentSongKey;
    if (key.isEmpty) return;
    _transpositions[key] = semitones;
    await _settingsStore.saveTranspositions(_transpositions);
    notifyListeners();
    await _syncCurrentDia(playSound: false);
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

    if (customOrderActive) {
      _persistActiveSetToSets();
      customOrderActive = false;
      _activeOrderSetIndex = -1;
    }

    final DtxBook? oldBook = currentBook;
    if (oldBook != null) {
      _lastSongPerBook[oldBook.fileName] = songIndex;
      _lastVersePerBook[oldBook.fileName] = verseIndex;
    }

    _diaVirtualBookSelected = false;
    bookIndex = value.clamp(0, books.length - 1);

    final DtxBook? newBook = currentBook;
    final int? lastSong = newBook != null
        ? _lastSongPerBook[newBook.fileName]
        : null;
    if (lastSong != null &&
        newBook != null &&
        lastSong < newBook.songs.length) {
      songIndex = lastSong;
      verseIndex =
          _lastVersePerBook[newBook.fileName]?.clamp(
            0,
            newBook.songs[lastSong].verses.length - 1,
          ) ??
          0;
    } else {
      songIndex = 0;
      verseIndex = 0;
    }

    highPos = 0;
    _resetHighlightRenderState();
    _projectedCustomCursor = -1;
    _setStatus('statusBookSelected', <String, String>{
      'name': newBook?.displayName ?? '-',
    });
    notifyListeners();
    _syncCurrentDia();
    unawaited(_settingsStore.saveLastSongPerBook(_lastSongPerBook));
    unawaited(_settingsStore.saveLastVersePerBook(_lastVersePerBook));
    unawaited(_persistAllSets());
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

    goToSong(bookIdx, targetSong, 0);
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

  /// Egy adott ének/versszak közvetlen megjelenítése a vezérlőben és a
  /// vetítésben, egyetlen szinkronizálással (a keresőből való ugráshoz).
  void goToSong(
    int targetBookIndex,
    int targetSongIndex,
    int targetVerseIndex,
  ) {
    if (books.isEmpty) {
      return;
    }
    final int bIx = targetBookIndex.clamp(0, books.length - 1);
    final DtxBook b = books[bIx];
    if (b.songs.isEmpty) {
      return;
    }
    final int sIx = targetSongIndex.clamp(0, b.songs.length - 1);
    final DtxSong s = b.songs[sIx];
    final int vIx = s.verses.isEmpty
        ? 0
        : targetVerseIndex.clamp(0, s.verses.length - 1);

    _diaVirtualBookSelected = false;
    bookIndex = bIx;
    songIndex = sIx;
    verseIndex = vIx;
    highPos = 0;
    _resetHighlightRenderState();
    _projectedCustomCursor = -1;
    _setStatus('statusSongSelected', <String, String>{'title': s.title});
    _syncCustomCursorFromCurrentSong();
    notifyListeners();
    _syncCurrentDia();
  }

  /// Keresés az összes betöltött énektárban: énekszám, cím és dalbeli sor
  /// alapján is. A keresés külön izolátumban fut, így nem fagyasztja az UI-t.
  Future<List<SongSearchResult>> searchSongs(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty || _searchIndex.isEmpty) {
      return const <SongSearchResult>[];
    }
    return _searchService.search(index: _searchIndex, query: trimmed);
  }

  void nextVerse() {
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

      final DtxSong? s = currentSong;
      if (s != null && verseIndex + 1 < s.verses.length) {
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

    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
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

    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
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
    final DtxBook? b = currentBook;
    if (b == null) {
      return;
    }
    final DtxSong prevSong = b.songs[prevSongIdx];
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
    _setStatus(selection.statusCode, <String, String>{
      'title': selectedSong.title,
    });
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

  /// Elrejti a vezérlő (fő) ablakot, ha a vetítő ablakkal azonos
  /// monitoron vagyunk, hogy a vetítés látszódjon.
  Future<void> hideControlWindow() async {
    await _desktopProjectorBridge.hideControlWindow();
    _controlWindowHidden = true;
    notifyListeners();
  }

  /// Visszaállítja a vezérlő (fő) ablakot a vetítésbe való kattintás után.
  Future<void> showControlWindow() async {
    await _desktopProjectorBridge.showControlWindow();
    _controlWindowHidden = false;
    notifyListeners();
  }

  /// Igaz, ha a vezérlő ablak el van rejtve (átlátszósága 0).
  bool _controlWindowHidden = false;
  bool get controlWindowHidden => _controlWindowHidden;

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
    await _desktopProjectorBridge.sendState(
      globals,
      showing: showing,
      wordToHighlight: highPos,
    );
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
    await _desktopProjectorBridge.sendState(
      globals,
      showing: showing,
      wordToHighlight: highPos,
    );
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

  Future<void> _syncCurrentDia({bool playSound = true}) async {
    if (_projectedCustomCursor >= 0 &&
        _projectedCustomCursor < _customOrder.length) {
      final CustomOrderEntry entry = _customOrder[_projectedCustomCursor];
      if (!entry.isSongEntry) {
        await _projectCustomOrderEntry(entry, cursor: _projectedCustomCursor);
        return;
      }
    }
    _projectedCustomCursor = -1;
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    if (_projectionOutputLocked) {
      notifyListeners();
      return;
    }
    await _desktopProjectorBridge.sendState(
      globals,
      showing: showing,
      wordToHighlight: highPos,
    );
    final DtxSong? song = currentSong;
    final DtxBook? book = currentBook;
    final DtxVerse? verse = currentVerse;
    final List<String> lines = projectionDisplayLines;

    final String bookNick = book?.displayName ?? '';
    final String songTitle = song?.title ?? '';
    final String verseTitle = (verse?.name ?? '').trim();
    final bool hideVerseInTitle = verseTitle.isEmpty;
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
    await _desktopProjectorBridge.sendText(title: title, lines: lines);
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
    await _desktopProjectorBridge.sendIdle();
    _refreshSenderFlags();
    unawaited(_castCurrentSlide(title: title, lines: lines));
    notifyListeners();
    if (playSound) {
      _playCurrentVerseSound();
    }
  }

  /// Előkészíti és elküldi az aktuális vetítési állapotot a Cast eszközre.
  Future<void> _castCurrentSlide({
    required String title,
    required List<String> lines,
  }) async {
    if (!settings.castEnabled) {
      return;
    }

    // Instead of sending text data, we render the current frame to an image
    // and send it to Cast. This ensures the receiver displays exactly what is projected.
    await renderCurrentFrameToImage();
  }

  /// Renders the current projection frame to an image and sends it to the Cast device.
  /// This method captures the current projection state using ProjectorPainter and converts
  /// it to a PNG image that can be sent via Cast.
  Future<void> renderCurrentFrameToImage() async {
    if (!settings.castEnabled) return;

    try {
      // Get the current projection state
      final ProjectionFrame? frame = _buildCurrentFrame();
      if (frame == null) return;

      // Create a picture recorder to capture the rendering
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Get screen dimensions from settings or use defaults
      final double width = _screenWidth.toDouble();
      final double height = _screenHeight.toDouble();
      final Size size = Size(width, height);

      // Create and paint the projector painter
      final ProjectorPainter painter = ProjectorPainter(
        frame: frame,
        globals: globals,
        settings: settings,
        logoTitle: '',
        logoSubtitle: '',
      );

      painter.paint(canvas, size);

      // End recording and get the picture
      final ui.Picture picture = recorder.endRecording();

      // Convert picture to image
      final ui.Image image = await picture.toImage(width.ceil(), height.ceil());

      // Convert image to PNG bytes
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Send the image via Cast service
      await _castService?.sendCastImage(pngBytes, 'image/png');
    } catch (e) {
      debugPrint('Error rendering frame to image for Cast: $e');
    }
  }

  /// Builds the current projection frame based on the controller's state.
  /// This method determines which type of frame to render (text, image, etc.)
  /// and returns the appropriate ProjectionFrame instance.
  ProjectionFrame? _buildCurrentFrame() {
    // Default to showing nothing
    if (!showing) {
      return const LogoFrame(0);
    }

    // Handle custom order entries that are images or text
    if (customOrderActive &&
        _projectedCustomCursor >= 0 &&
        _projectedCustomCursor < _customOrder.length) {
      final CustomOrderEntry entry = _customOrder[_projectedCustomCursor];
      if (entry.isCustomImage) {
        // For custom images, we would need to load the image as an ImageFrame
        // For now, we'll fall back to text rendering or handle it elsewhere
        return null;
      } else if (entry.isCustomText) {
        final bool isMergeLeader = isCustomOrderEntryMergeLeaderAt(
          _projectedCustomCursor,
        );
        final String title = isMergeLeader
            ? customOrderProjectionTitleAt(_projectedCustomCursor)
            : (entry.customTextTitle ?? '').trim().isEmpty
            ? 'Dia'
            : (entry.customTextTitle ?? '').trim();
        final List<String> lines = () {
          final String body =
              isMergeLeader && _projectedCustomCursor + 1 < _customOrder.length
              ? '${entry.customTextBody ?? ''}\n${_customOrder[_projectedCustomCursor + 1].customTextBody ?? ''}'
              : (entry.customTextBody ?? '');
          return body
              .split(RegExp(r'\r?\n'))
              .map((String line) => line.trimRight())
              .where((String line) => line.trim().isNotEmpty)
              .toList();
        }();
        final RecTextRecord record = RecTextRecord(
          scholaLine: '',
          title: title,
          lines: lines,
        );
        return TextFrame(record: record);
      }
    }

    // Default to showing the current verse/projection
    final DtxBook? book = currentBook;
    final DtxSong? song = currentSong;
    final DtxVerse? verse = currentVerse;

    if (book == null || song == null || verse == null) {
      return const LogoFrame(0);
    }

    // Create a TextFrame with the current book, song, and verse information
    final String title =
        '${book.displayName}: ${song.title}/${verse.name ?? ''}'.trim();
    final List<String> lines = displayLines;
    final RecTextRecord record = RecTextRecord(
      scholaLine: '',
      title: title,
      lines: lines,
    );
    return TextFrame(record: record);
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
      final bool isMergeLeader = isCustomOrderEntryMergeLeaderAt(cursor);
      final String title = isMergeLeader
          ? customOrderProjectionTitleAt(cursor)
          : (entry.customTextTitle ?? '').trim().isEmpty
          ? 'Dia'
          : (entry.customTextTitle ?? '').trim();
      final List<String> lines = () {
        final String body = isMergeLeader && cursor + 1 < _customOrder.length
            ? '${entry.customTextBody ?? ''}\n${_customOrder[cursor + 1].customTextBody ?? ''}'
            : (entry.customTextBody ?? '');
        return body
            .split(RegExp(r'\r?\n'))
            .map((String line) => line.trimRight())
            .where((String line) => line.trim().isNotEmpty)
            .toList();
      }();
      final List<String> payloadLines = lines.isEmpty
          ? const <String>['']
          : lines;
      globals = globals.copyWith(projecting: showing, wordToHighlight: 0);
      if (_projectionOutputLocked) {
        _setStatus('statusCustomTextSent', <String, String>{'title': title});
        notifyListeners();
        return;
      }
      await _desktopProjectorBridge.sendState(
        globals,
        showing: showing,
        wordToHighlight: 0,
      );
      await _desktopProjectorBridge.sendText(title: title, lines: payloadLines);
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
      await _desktopProjectorBridge.sendIdle();
      _refreshSenderFlags();
      _setStatus('statusCustomTextSent', <String, String>{'title': title});
      notifyListeners();
      return;
    }

    if (entry.isCustomImage) {
      await sendPicFromPath(entry.customImagePath ?? '');
    }
    if (settings.castEnabled && !kIsWeb) {
      _castService ??= CastService();
      await _castService!.initialize();
    }
    if (settings.castEnabled) {
      await _castCurrentImage(entry.customImagePath ?? '');
    }
  }

  Future<void> _castCurrentImage(String path) async {
    if (!settings.castEnabled) return;
    final String normalized = path.trim();
    if (normalized.isEmpty) return;

    try {
      final File file = FileSystemProvider.instance.file(normalized);
      if (await file.exists()) {
        final Uint8List bytes = await file.readAsBytes();
        final String ext = _fileExtension(normalized);
        await _castService?.sendCastData(<String, dynamic>{
          'type': 'image',
          'path': normalized,
          'ext': ext,
          'bytes': base64Encode(bytes),
        });
      }
    } catch (e) {
      debugPrint('Cast image error: $e');
    }
  }

  Future<void> _castCurrentBlank(String path) async {
    if (!settings.castEnabled) return;
    final String normalized = path.trim();
    if (normalized.isEmpty) return;

    try {
      final File file = FileSystemProvider.instance.file(normalized);
      if (await file.exists()) {
        final Uint8List bytes = await file.readAsBytes();
        final String ext = _fileExtension(normalized);
        await _castService?.sendCastData(<String, dynamic>{
          'type': 'blank',
          'path': normalized,
          'ext': ext,
          'bytes': base64Encode(bytes),
        });
      }
    } catch (e) {
      debugPrint('Cast blank error: $e');
    }
  }

  Future<void> _appendCustomOrderEntry(CustomOrderEntry entry) async {
    _customOrder = <CustomOrderEntry>[..._customOrder, entry];
    customOrderActive = _customOrder.isNotEmpty;
    _customOrderCursor = _customOrder.length - 1;
    await _persistCurrentCustomOrder();
    _persistActiveSetToSets();
    await _persistAllSets();
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

    final File file = FileSystemProvider.instance.file(normalized);
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

  Future<void> importSzentirasVerses({
    required String translationName,
    required List<SzentirasVerse> verses,
    int maxWords = 30,
  }) async {
    if (verses.isEmpty) {
      _setStatus('statusCustomTextEmpty');
      notifyListeners();
      return;
    }
    final String refLabel = verses.first.reference;
    final List<String> allLines = <String>[];
    for (int i = 0; i < verses.length; i++) {
      final SzentirasVerse v = verses[i];
      if (i > 0) {
        allLines.add('');
      }
      allLines.addAll(
        v.text
            .trim()
            .split(RegExp(r'\r?\n'))
            .where((String line) => line.trim().isNotEmpty),
      );
    }
    final List<List<String>> chunks = chunkLinesByBoundary(allLines, maxWords);
    final List<CustomOrderEntry> newEntries = <CustomOrderEntry>[];
    for (int j = 0; j < chunks.length; j++) {
      final String chunkTitle = chunks.length > 1
          ? '$refLabel/${j + 1}'
          : refLabel;
      newEntries.add(
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: j,
          label: '[Szentírás] $chunkTitle',
          customTextTitle: chunkTitle,
          customTextBody: tokensToText(chunks[j]),
          customType: 'text',
        ),
      );
    }
    final List<CustomOrderEntry> combined = _insertEntriesIntoOrder(
      newEntries,
      _customOrder.length,
    );
    await applyCustomOrder(combined, activate: true, syncProjection: false);
    _diaVirtualBookSelected = combined.isNotEmpty;
    if (combined.isNotEmpty) {
      final int target = combined.length - newEntries.length;
      _selectByCustomOrderCursor(
        target.clamp(0, combined.length - 1),
        sync: true,
      );
    }
    _setStatus('statusCustomTextSent', <String, String>{'title': refLabel});
    notifyListeners();
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
      await _desktopProjectorBridge.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
      await _desktopProjectorBridge.sendText(
        title: effectiveTitle,
        lines: nonEmptyLines,
      );
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
      await _desktopProjectorBridge.sendIdle();
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
      final File file = FileSystemProvider.instance.file(normalized);
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
      await _desktopProjectorBridge.sendPic(bytes, ext: ext);
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
      unawaited(_castCurrentImage(normalized));
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
      final File file = FileSystemProvider.instance.file(normalized);
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
      await _desktopProjectorBridge.sendBlank(bytes, ext: ext);
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
      unawaited(_castCurrentBlank(normalized));
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
      await _desktopProjectorBridge.sendBlank(Uint8List(0), ext: '');
      await _desktopProjectorBridge.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
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
    try {
      await _mqttSender.clearRetainedMessages();
    } catch (_) {
      // A törlés hibája sosem blokkolhatja a kilépést.
    }
    await _sender.stop();
    await _mqttSender.close();
    await _desktopProjectorBridge.dispose();
    if (kIsWeb) {
      await browser_window_close.tryCloseBrowserWindow();
      return;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      exit(0);
    } else {
      await SystemNavigator.pop();
    }
  }

  /// Best-effort retained törlés (pl. web-es fülbezárásnál), ami sosem dob.
  Future<void> clearRetainedBestEffort() async {
    try {
      await _mqttSender.clearRetainedMessages();
    } catch (_) {}
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
