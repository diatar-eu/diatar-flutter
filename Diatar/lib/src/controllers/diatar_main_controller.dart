import 'dart:convert';
import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/mqtt_sender_service.dart';
import '../services/dtx_download_service.dart';
import '../services/dtx_order_store.dart';
import '../services/settings_store.dart';
import '../services/tcp_sender_service.dart';

enum DiatarHomeViewMode { szimpla, spontan, sorrend }

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

class CustomOrderEntry {
  const CustomOrderEntry({
    required this.fileName,
    required this.songIndex,
    required this.verseIndex,
    required this.label,
  });

  final String fileName;
  final int songIndex;
  final int verseIndex;
  final String label;

  CustomOrderEntry copyWith({
    String? fileName,
    int? songIndex,
    int? verseIndex,
    String? label,
  }) {
    return CustomOrderEntry(
      fileName: fileName ?? this.fileName,
      songIndex: songIndex ?? this.songIndex,
      verseIndex: verseIndex ?? this.verseIndex,
      label: label ?? this.label,
    );
  }
}

class DiatarMainController extends ChangeNotifier {
  final DtxParser _parser = const DtxParser();
  final SettingsStore _settingsStore = SettingsStore();
  final DtxDownloadService _downloadService = DtxDownloadService();
  final DtxOrderStore _orderStore = DtxOrderStore();
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
  bool showing = false;
  bool loading = false;
  AppSettings settings = const AppSettings();
  ProjectionGlobals globals = const ProjectionGlobals();
  bool senderRunning = false;
  bool senderConnected = false;
  bool mqttActive = false;
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

  Map<String, String> get statusParams => Map<String, String>.unmodifiable(_statusParams);

  void _setStatus(String code, [Map<String, String> params = const <String, String>{}]) {
    statusCode = code;
    _statusParams = Map<String, String>.from(params);
  }

  int _safeVerseIndex(CustomOrderEntry entry, {int fallback = 0}) {
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

  Future<void> init() async {
    settings = await _settingsStore.load();
    lastBlankPath = settings.blankPicPath;
    _disabledSongbooks = await _orderStore.loadDisabled();
    final ({List<StoredCustomOrderEntry> entries, bool active}) stored =
        await _orderStore.loadCurrentCustomOrder();
    _customOrder = stored.entries
        .map(
          (StoredCustomOrderEntry e) => CustomOrderEntry(
            fileName: e.fileName,
            songIndex: e.songIndex,
            verseIndex: e.verseIndex,
            label: e.label,
          ),
        )
        .toList();
    customOrderActive = stored.active && _customOrder.isNotEmpty;
    _customOrderCursor = customOrderActive ? 0 : -1;
    globals = globals.copyWith(
      bkColor: settings.bkColor,
      txtColor: settings.txtColor,
      blankColor: settings.blankColor,
      hiColor: settings.hiColor,
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
    await _syncCurrentDia();
  }

  DiatarHomeViewMode get viewMode {
    final int idx = settings.homeViewMode.clamp(0, DiatarHomeViewMode.values.length - 1);
    return DiatarHomeViewMode.values[idx];
  }

  Future<void> setViewMode(DiatarHomeViewMode mode) async {
    settings = settings.copyWith(homeViewMode: mode.index);
    await _settingsStore.save(settings);
    notifyListeners();
  }

  void _configureSender() {
    _sender.onStatusChanged = (bool connected) {
      senderConnected = connected;
      notifyListeners();
    };
    _sender.onError = (String code, Map<String, String> params) {
      switch (code) {
        case 'senderTcpError':
          _setStatus('statusSenderTcpError', <String, String>{'error': params['error'] ?? ''});
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
      notifyListeners();
    };
    _mqttSender.onStatusChanged = (bool connected) {
      senderConnected = connected;
      notifyListeners();
    };
    _mqttSender.onError = (String code, Map<String, String> params) {
      switch (code) {
        case 'senderMqttConnectFailed':
          _setStatus('statusSenderMqttConnectFailed');
          break;
        case 'senderMqttError':
          _setStatus('statusSenderMqttError', <String, String>{'error': params['error'] ?? ''});
          break;
        default:
          _setStatus('statusSenderError', <String, String>{'message': code});
          break;
      }
      notifyListeners();
    };
  }

  Future<void> applySettings(AppSettings newSettings) async {
    settings = newSettings;
    lastBlankPath = settings.blankPicPath;
    await _settingsStore.save(settings);
    globals = globals.copyWith(
      bkColor: settings.bkColor,
      txtColor: settings.txtColor,
      blankColor: settings.blankColor,
      hiColor: settings.hiColor,
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
    await _applyTransport();
    notifyListeners();
    await _syncCurrentDia();
  }

  Future<void> _applyTransport() async {
    final String user = settings.mqttUser.trim();
    mqttActive = user.isNotEmpty;
    if (mqttActive) {
      await _sender.stop();
      await _mqttSender.open(
        username: user,
        password: settings.mqttPassword,
        channel: settings.mqttChannel,
      );
      senderRunning = _mqttSender.running;
      _setStatus('statusMqttSending', <String, String>{
        'user': user,
        'channel': settings.mqttChannel,
      });
    } else {
      await _mqttSender.close();
      await _sender.restart(settings.port);
      await _sender.sendScreenSize(width: _screenWidth, height: _screenHeight);
      senderRunning = _sender.running;
      _setStatus('statusTcpSending', <String, String>{
        'port': '${settings.port}',
      });
    }
  }

  Future<void> updateScreenSize({required int width, required int height}) async {
    final int normalizedW = width < 1 ? 1 : width;
    final int normalizedH = height < 1 ? 1 : height;
    if (normalizedW == _screenWidth && normalizedH == _screenHeight) {
      return;
    }
    _screenWidth = normalizedW;
    _screenHeight = normalizedH;

    if (!mqttActive) {
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
        final Directory docs = await getApplicationDocumentsDirectory();
        _setStatus('statusNoDtxFiles', <String, String>{'path': '${docs.path}/diatar'});
      } else if (enabled.isEmpty) {
        books = const <DtxBook>[];
        _setStatus('statusAllSongbooksDisabled');
      } else {
        enabled.sort(_compareBooksLikeAndroid);
        books = enabled;
        _setStatus('statusSongbooksLoaded', <String, String>{'count': '${enabled.length}'});
      }

      bookIndex = 0;
      songIndex = 0;
      verseIndex = 0;
      highPos = 0;
      _customOrder = _customOrder.where((CustomOrderEntry e) {
        final int bIx = books.indexWhere((DtxBook b) => b.fileName == e.fileName);
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
        _customOrderCursor = _customOrderCursor.clamp(0, _customOrder.length - 1);
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
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dtxDir = Directory('${docs.path}/diatar');
    final List<DtxBook> loaded = <DtxBook>[];

    if (!await dtxDir.exists()) {
      return loaded;
    }

    final List<FileSystemEntity> children = dtxDir.listSync();
    children.sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));
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

  List<CustomOrderEntry> get customOrder => List<CustomOrderEntry>.unmodifiable(_customOrder);
  int get customOrderCursor => _customOrderCursor;

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
            ),
          )
          .toList(),
      active: customOrderActive,
    );
  }

  Future<List<String>> listCustomOrderPresetNames() async {
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore.loadCustomOrderPresets();
    final List<String> names = presets.keys.toList()..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<List<CustomOrderEntry>> readCustomOrderPreset(String name) async {
    final String key = name.trim();
    if (key.isEmpty) {
      return const <CustomOrderEntry>[];
    }
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore.loadCustomOrderPresets();
    final List<StoredCustomOrderEntry> entries = presets[key] ?? const <StoredCustomOrderEntry>[];
    return entries
        .map(
          (StoredCustomOrderEntry e) => CustomOrderEntry(
            fileName: e.fileName,
            songIndex: e.songIndex,
            verseIndex: e.verseIndex,
            label: e.label,
          ),
        )
        .toList();
  }

  Future<void> saveCustomOrderPreset(String name, List<CustomOrderEntry> entries) async {
    final String key = name.trim();
    if (key.isEmpty) {
      return;
    }
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore.loadCustomOrderPresets();
    presets[key] = entries
        .map(
          (CustomOrderEntry e) => StoredCustomOrderEntry(
            fileName: e.fileName,
            songIndex: e.songIndex,
            verseIndex: _safeVerseIndex(e),
            label: e.label,
          ),
        )
        .toList();
    await _orderStore.saveCustomOrderPresets(presets);
  }

  Future<void> deleteCustomOrderPreset(String name) async {
    final String key = name.trim();
    if (key.isEmpty) {
      return;
    }
    final Map<String, List<StoredCustomOrderEntry>> presets = await _orderStore.loadCustomOrderPresets();
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
    final int idx = books.indexWhere((DtxBook b) => b.fileName == entry.fileName);
    if (idx < 0) {
      return null;
    }
    return books[idx];
  }

  DtxSong? songForEntry(CustomOrderEntry entry) {
    final DtxBook? b = bookForEntry(entry);
    if (b == null || b.songs.isEmpty) {
      return null;
    }
    final int safeSong = entry.songIndex.clamp(0, b.songs.length - 1);
    return b.songs[safeSong];
  }

  List<DtxVerse> versesForEntry(CustomOrderEntry entry) {
    final DtxSong? s = songForEntry(entry);
    return s?.verses ?? const <DtxVerse>[];
  }

  String buildEntryLabel(String fileName, int songIndex, int verseIndex) {
    final int bIx = books.indexWhere((DtxBook b) => b.fileName == fileName);
    if (bIx < 0) {
      return fileName;
    }
    final DtxBook b = books[bIx];
    if (b.songs.isEmpty) {
      return b.displayName;
    }
    final int safeSong = songIndex.clamp(0, b.songs.length - 1);
    final DtxSong song = b.songs[safeSong];
    final String verseName = song.verses.isEmpty
        ? '-'
      : song.verses[verseIndex.clamp(0, song.verses.length - 1)].name;
    return '${b.displayName}: ${song.title} / $verseName';
  }

  String _normalizeDiaText(String text) {
    const Map<String, String> repl = <String, String>{
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ö': 'o', 'ő': 'o', 'ú': 'u', 'ü': 'u', 'ű': 'u',
      'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ö': 'o', 'Ő': 'o', 'Ú': 'u', 'Ü': 'u', 'Ű': 'u',
    };
    final StringBuffer sb = StringBuffer();
    bool lastWasSpace = false;
    for (final int rune in text.runes) {
      final String ch = String.fromCharCode(rune);
      final String mapped = repl[ch] ?? ch;
      final bool isSep = mapped.trim().isEmpty || mapped == '_' || mapped == '-' || mapped == '/';
      if (isSep) {
        if (!lastWasSpace) {
          sb.write(' ');
          lastWasSpace = true;
        }
        continue;
      }
      sb.write(mapped.toLowerCase());
      lastWasSpace = false;
    }
    return sb.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  int _findBookIndexForDia(String kotet) {
    final String needle = _normalizeDiaText(kotet);
    if (needle.isEmpty) {
      return -1;
    }
    return books.indexWhere((DtxBook b) {
      return _normalizeDiaText(b.title) == needle ||
          _normalizeDiaText(b.displayName) == needle ||
          _normalizeDiaText(b.fileName) == needle;
    });
  }

  int _findSongIndexForDia(DtxBook book, String enek) {
    final String needle = _normalizeDiaText(enek);
    if (needle.isEmpty) {
      return -1;
    }
    return book.songs.indexWhere((DtxSong s) => !s.separator && _normalizeDiaText(s.title) == needle);
  }

  int _findVerseIndexForDia(DtxSong song, String versszak) {
    final String needle = _normalizeDiaText(versszak);
    if (needle.isEmpty) {
      return 0;
    }
    final int parsed = song.verses.indexWhere((DtxVerse v) => _normalizeDiaText(v.name) == needle);
    return parsed >= 0 ? parsed : 0;
  }

  int _findCustomOrderIndexByEntry(CustomOrderEntry entry, {int preferredCursor = -1}) {
    bool matches(int idx) {
      if (idx < 0 || idx >= _customOrder.length) {
        return false;
      }
      final CustomOrderEntry candidate = _customOrder[idx];
      return candidate.fileName == entry.fileName &&
          candidate.songIndex == entry.songIndex &&
          _safeVerseIndex(candidate) == _safeVerseIndex(entry);
    }

    if (preferredCursor >= 0 && preferredCursor < _customOrder.length && matches(preferredCursor)) {
      return preferredCursor;
    }

    if (preferredCursor >= 0) {
      for (int i = preferredCursor + 1; i < _customOrder.length; i++) {
        if (matches(i)) {
          return i;
        }
      }
      for (int i = 0; i < preferredCursor && i < _customOrder.length; i++) {
        if (matches(i)) {
          return i;
        }
      }
      return -1;
    }

    for (int i = 0; i < _customOrder.length; i++) {
      if (matches(i)) {
        return i;
      }
    }
    return -1;
  }

  CustomOrderEntry normalizeEntry(CustomOrderEntry entry) {
    final int bIx = books.indexWhere((DtxBook b) => b.fileName == entry.fileName);
    if (bIx < 0) {
      return entry;
    }
    final DtxBook b = books[bIx];
    if (b.songs.isEmpty) {
      return entry.copyWith(label: b.displayName);
    }
    final int safeSong = entry.songIndex.clamp(0, b.songs.length - 1);
    final DtxSong song = b.songs[safeSong];
    final int safeVerse = song.verses.isEmpty
        ? 0
      : _safeVerseIndex(entry).clamp(0, song.verses.length - 1);
    return entry.copyWith(
      songIndex: safeSong,
      verseIndex: safeVerse,
      label: buildEntryLabel(entry.fileName, safeSong, safeVerse),
    );
  }

  Future<void> applyCustomOrder(List<CustomOrderEntry> entries, {required bool activate}) async {
    final int previousCursor = _customOrderCursor;
    final CustomOrderEntry? previousEntry = previousCursor >= 0 && previousCursor < _customOrder.length
        ? _customOrder[previousCursor]
        : null;

    _customOrder = entries.map(normalizeEntry).toList();
    customOrderActive = activate && _customOrder.isNotEmpty;
    if (customOrderActive) {
      final int preservedCursor = previousEntry == null
          ? -1
          : _findCustomOrderIndexByEntry(previousEntry, preferredCursor: previousCursor);
      if (preservedCursor >= 0) {
        _customOrderCursor = preservedCursor;
      } else if (_customOrder.isNotEmpty) {
        _customOrderCursor = previousCursor.clamp(0, _customOrder.length - 1);
      } else {
        _customOrderCursor = -1;
      }
      if (_customOrderCursor >= 0) {
        _selectByCustomOrderCursor(_customOrderCursor, sync: false);
      }
      await _persistCurrentCustomOrder();
      await _syncCurrentDia();
    } else {
      _customOrderCursor = -1;
      await _persistCurrentCustomOrder();
      notifyListeners();
    }
  }

  Future<void> projectCustomOrderEntry(CustomOrderEntry rawEntry, {int? preferredCursor}) async {
    final CustomOrderEntry entry = normalizeEntry(rawEntry);
    final int bookIx = books.indexWhere((DtxBook b) => b.fileName == entry.fileName);
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

    if (preferredCursor != null) {
      _customOrderCursor = preferredCursor.clamp(0, _customOrder.isEmpty ? 0 : _customOrder.length - 1);
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

    _setStatus('statusCustomOrderSelected', <String, String>{'label': entry.label});
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

    bool matches(int idx) {
      if (idx < 0 || idx >= _customOrder.length) {
        return false;
      }
      final CustomOrderEntry e = _customOrder[idx];
      return e.fileName == b.fileName && e.songIndex == songIndex && _safeVerseIndex(e) == verseIndex;
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
    final int bookIx = books.indexWhere((DtxBook b) => b.fileName == entry.fileName);
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
    _customOrderCursor = safe;
    _setStatus('statusCustomOrderSelected', <String, String>{'label': entry.label});
    notifyListeners();
    if (sync) {
      _syncCurrentDia();
    }
  }

  Future<List<DtxDownloadItem>> loadDownloadCandidates() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dtxDir = Directory('${docs.path}/diatar');
    return _downloadService.listUpdates(targetDir: dtxDir);
  }

  Future<String> exportCustomOrderToDia(String path) async {
    final String safePath = path.toLowerCase().endsWith('.dia') ? path : '$path.dia';
    final StringBuffer out = StringBuffer();
    out.writeln('[main]');
    out.writeln('diaszam=${_customOrder.length}');
    out.writeln('utf8=1');

    for (int i = 0; i < _customOrder.length; i++) {
      final CustomOrderEntry entry = normalizeEntry(_customOrder[i]);
      final DtxBook? book = bookForEntry(entry);
      final DtxSong? song = songForEntry(entry);
      final List<DtxVerse> verses = versesForEntry(entry);
      final int verse = _safeVerseIndex(entry);
      final String verseName = verses.isEmpty ? '' : verses[verse.clamp(0, verses.length - 1)].name;
      final String idValue = '${entry.fileName}|${entry.songIndex}|$verse';

      out.writeln();
      out.writeln('[${i + 1}]');
      out.writeln('id=$idValue');
      out.writeln('kotet=${book?.title ?? entry.fileName}');
      out.writeln('enek=${song?.title ?? entry.label}');
      out.writeln('versszak=$verseName');
    }

    final File f = File(safePath);
    await f.writeAsString(out.toString(), encoding: utf8);
    _setStatus('statusOrderSaved', <String, String>{'path': safePath});
    notifyListeners();
    return safePath;
  }

  Future<int> importCustomOrderFromDia(String path, {bool activate = true}) async {
    final File f = File(path);
    if (!await f.exists()) {
      _setStatus('statusDiaFileMissing', <String, String>{'path': path});
      notifyListeners();
      return 0;
    }

    final String content = await f.readAsString();
    final Map<String, Map<String, String>> sections = _parseDiaIni(content);
    final int declaredCount = int.tryParse(sections['main']?['diaszam'] ?? '') ?? 0;

    final List<CustomOrderEntry> imported = <CustomOrderEntry>[];
    final Iterable<String> keys = sections.keys.where((String k) => k != 'main');
    final List<String> sectionOrder = keys.toList()
      ..sort((String a, String b) => (int.tryParse(a) ?? 999999).compareTo(int.tryParse(b) ?? 999999));

    final int max = declaredCount > 0 ? declaredCount : sectionOrder.length;
    for (int i = 1; i <= max; i++) {
      final Map<String, String>? sec = sections['$i'];
      if (sec == null) {
        continue;
      }
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
    _setStatus('statusOrderLoaded', <String, String>{
      'count': '${imported.length}',
      'path': path,
    });
    notifyListeners();
    return imported.length;
  }

  Map<String, Map<String, String>> _parseDiaIni(String content) {
    final Map<String, Map<String, String>> sections = <String, Map<String, String>>{};
    String current = 'main';
    sections[current] = <String, String>{};

    for (final String rawLine in content.split(RegExp(r'\r?\n'))) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        current = line.substring(1, line.length - 1).trim().toLowerCase();
        sections.putIfAbsent(current, () => <String, String>{});
        continue;
      }
      final int eq = line.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      final String key = line.substring(0, eq).trim().toLowerCase();
      final String value = line.substring(eq + 1).trim();
      sections[current]![key] = value;
    }

    return sections;
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
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dtxDir = Directory('${docs.path}/diatar');
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
    final String lGroup = left.group.trim();
    final String rGroup = right.group.trim();
    final int groupCmp = lGroup.toLowerCase().compareTo(rGroup.toLowerCase());
    if (groupCmp != 0) {
      return groupCmp;
    }

    final int lOrder = left.order;
    final int rOrder = right.order;
    if (lOrder != 0) {
      if (rOrder != 0) {
        return lOrder.compareTo(rOrder);
      }
      return -1;
    }
    if (rOrder != 0) {
      return 1;
    }

    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  DtxBook? get currentBook => books.isEmpty ? null : books[bookIndex.clamp(0, books.length - 1)];

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
    bookIndex = value.clamp(0, books.length - 1);
    songIndex = 0;
    verseIndex = 0;
    highPos = 0;
    final DtxBook? selected = currentBook;
    _setStatus('statusBookSelected', <String, String>{'name': selected?.displayName ?? '-'});
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
    _setStatus('statusSongPicked', <String, String>{'name': currentSong?.title ?? '-'});
    _syncCustomCursorFromCurrentSong();
    notifyListeners();
    _syncCurrentDia();
  }

  void setVerseIndex(int value) {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return;
    }
    verseIndex = value.clamp(0, s.verses.length - 1);
    highPos = 0;
    _setStatus('statusVersePicked', <String, String>{'name': currentVerse?.name ?? '-'});
    notifyListeners();
    _syncCurrentDia();
  }

  void nextVerse() {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return;
    }

    if (customOrderActive && _customOrder.isNotEmpty) {
      final int exactIdx = _currentCustomOrderIndex();
      if (exactIdx >= 0) {
        if (exactIdx + 1 >= _customOrder.length) {
          return;
        }
        _selectByCustomOrderCursor(exactIdx + 1, sync: true);
        return;
      }

      // Ha sorrenden kivuli dian allunk, eloszor azon lepdelunk vegig,
      // es csak a vege utan ugrunk vissza a sorrend kovetkezo elemere.
      if (verseIndex + 1 < s.verses.length) {
        setVerseIndex(verseIndex + 1);
        return;
      }

      if (_customOrderCursor < 0) {
        _selectByCustomOrderCursor(0, sync: true);
        return;
      }
      if (_customOrderCursor + 1 < _customOrder.length) {
        _selectByCustomOrderCursor(_customOrderCursor + 1, sync: true);
      }
      return;
    }

    if (verseIndex + 1 < s.verses.length) {
      setVerseIndex(verseIndex + 1);
      return;
    }

    final int? nextSongIdx = _findSelectableSongIndex(songIndex + 1, forward: true);
    if (nextSongIdx == null) {
      return;
    }
    _selectSongAndVerse(nextSongIdx, 0, includeVerseInStatus: true);
  }

  int _currentCustomOrderIndex() {
    final DtxBook? b = currentBook;
    if (b == null || _customOrder.isEmpty) {
      return -1;
    }

    bool matches(int idx) {
      if (idx < 0 || idx >= _customOrder.length) {
        return false;
      }
      final CustomOrderEntry e = _customOrder[idx];
      return e.fileName == b.fileName && e.songIndex == songIndex && _safeVerseIndex(e) == verseIndex;
    }

    // Prefer current cursor when duplicates exist.
    if (matches(_customOrderCursor)) {
      return _customOrderCursor;
    }
    for (int i = _customOrderCursor + 1; i < _customOrder.length; i++) {
      if (matches(i)) {
        return i;
      }
    }
    for (int i = 0; i <= _customOrderCursor && i < _customOrder.length; i++) {
      if (matches(i)) {
        return i;
      }
    }
    return -1;
  }

  void prevVerse() {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
      return;
    }

    if (customOrderActive && _customOrder.isNotEmpty) {
      final int exactIdx = _currentCustomOrderIndex();
      if (exactIdx >= 0) {
        if (exactIdx <= 0) {
          return;
        }
        _selectByCustomOrderCursor(exactIdx - 1, sync: true);
        return;
      }

      // Ha sorrenden kivuli dian allunk, eloszor azon lepdelunk vissza,
      // es csak az eleje utan ugrunk vissza a sorrend elozo elemere.
      if (verseIndex > 0) {
        setVerseIndex(verseIndex - 1);
        return;
      }

      if (_customOrderCursor < 0) {
        _selectByCustomOrderCursor(0, sync: true);
        return;
      }
      if (_customOrderCursor > 0) {
        _selectByCustomOrderCursor(_customOrderCursor - 1, sync: true);
      }
      return;
    }

    if (verseIndex > 0) {
      setVerseIndex(verseIndex - 1);
      return;
    }

    final int? prevSongIdx = _findSelectableSongIndex(songIndex - 1, forward: false);
    if (prevSongIdx == null) {
      return;
    }
    final DtxSong targetSong = currentBook!.songs[prevSongIdx];
    final int targetVerse = targetSong.verses.isEmpty ? 0 : targetSong.verses.length - 1;
    _selectSongAndVerse(prevSongIdx, targetVerse, includeVerseInStatus: true);
  }

  void nextSong() {
    if (customOrderActive && _customOrder.isNotEmpty) {
      if (_customOrderCursor + 1 >= _customOrder.length) {
        return;
      }
      _selectByCustomOrderCursor(_customOrderCursor + 1, sync: true);
      return;
    }
    final int? nextSongIdx = _findSelectableSongIndex(songIndex + 1, forward: true);
    if (nextSongIdx == null) {
      return;
    }
    _selectSongAndVerse(nextSongIdx, 0, includeVerseInStatus: false);
  }

  void prevSong() {
    if (customOrderActive && _customOrder.isNotEmpty) {
      if (_customOrderCursor <= 0) {
        return;
      }
      _selectByCustomOrderCursor(_customOrderCursor - 1, sync: true);
      return;
    }
    final int? prevSongIdx = _findSelectableSongIndex(songIndex - 1, forward: false);
    if (prevSongIdx == null) {
      return;
    }
    _selectSongAndVerse(prevSongIdx, 0, includeVerseInStatus: false);
  }

  int? _findSelectableSongIndex(int start, {required bool forward}) {
    final List<DtxSong> songs = currentBook?.songs ?? const <DtxSong>[];
    if (songs.isEmpty) {
      return null;
    }
    int idx = start;
    while (idx >= 0 && idx < songs.length) {
      if (!songs[idx].separator) {
        return idx;
      }
      idx += forward ? 1 : -1;
    }
    return null;
  }

  void _selectSongAndVerse(int targetSong, int targetVerse, {required bool includeVerseInStatus}) {
    final DtxBook? b = currentBook;
    if (b == null || b.songs.isEmpty) {
      return;
    }
    final int song = targetSong.clamp(0, b.songs.length - 1);
    final DtxSong songModel = b.songs[song];
    final int verse = songModel.verses.isEmpty
        ? 0
        : targetVerse.clamp(0, songModel.verses.length - 1);

    songIndex = song;
    verseIndex = verse;
    highPos = 0;
    final String code = includeVerseInStatus ? 'statusSongVerseSelected' : 'statusSongSelected';
    _setStatus(code, <String, String>{'title': songModel.title});
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

  Future<void> _syncProjectionOnly() async {
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    } else {
      await _sender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
  }

  void highlightNext() {
    final int max = wordCount;
    highPos = (highPos + 1).clamp(0, max);
    notifyListeners();
    _syncHighlightOnly();
  }

  void highlightPrev() {
    highPos = (highPos - 1).clamp(0, wordCount);
    notifyListeners();
    _syncHighlightOnly();
  }

  Future<void> _syncHighlightOnly() async {
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    } else {
      await _sender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
    }
  }

  Future<void> _syncCurrentDia() async {
    globals = globals.copyWith(projecting: showing, wordToHighlight: highPos);
    final DtxSong? song = currentSong;
    final DtxBook? book = currentBook;
    final DtxVerse? verse = currentVerse;
    final List<String> lines = displayLines;

    final String bookNick = book?.displayName ?? '';
    final String songTitle = song?.title ?? '';
    final String verseTitle = verse?.name ?? '';
    final bool hasOnlyDefaultVerse = (song?.verses.length ?? 0) == 1 && verseTitle == '---';
    final String title = bookNick.isEmpty
        ? songTitle
        : hasOnlyDefaultVerse
            ? '$bookNick: $songTitle'
            : '$bookNick: $songTitle/$verseTitle';

    if (mqttActive) {
      await _mqttSender.sendState(
        globals,
        showing: showing,
        wordToHighlight: highPos,
      );
      await _mqttSender.sendText(title: title, lines: lines);
      senderRunning = _mqttSender.running;
    } else {
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
      senderRunning = _sender.running;
    }
    notifyListeners();
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
      if (mqttActive) {
        await _mqttSender.sendPic(bytes, ext: ext);
      } else {
        await _sender.sendPic(bytes, ext: ext);
      }
      lastPicPath = normalized;
      _setStatus('statusImageSent', <String, String>{
        'name': file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : normalized,
      });
      notifyListeners();
    } catch (e) {
      _setStatus('statusImageSendError', <String, String>{'error': '$e'});
      notifyListeners();
    }
  }

  Future<void> sendBlankFromPath(String path) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      _setStatus('statusBlankPathEmpty');
      notifyListeners();
      return;
    }

    try {
      final File file = File(normalized);
      if (!await file.exists()) {
        _setStatus('statusBlankNotFound', <String, String>{'path': normalized});
        notifyListeners();
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final String ext = _fileExtension(normalized);
      globals = globals.copyWith(isBlankPic: true, showBlankPic: true);
      if (mqttActive) {
        await _mqttSender.sendBlank(bytes, ext: ext);
        await _mqttSender.sendState(globals, showing: showing, wordToHighlight: highPos);
      } else {
        await _sender.sendBlank(bytes, ext: ext);
        await _sender.sendState(globals, showing: showing, wordToHighlight: highPos);
      }
      lastBlankPath = normalized;
      settings = settings.copyWith(blankPicPath: normalized);
      await _settingsStore.save(settings);
      _setStatus('statusBlankSet', <String, String>{
        'name': file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : normalized,
      });
      notifyListeners();
    } catch (e) {
      _setStatus('statusBlankSendError', <String, String>{'error': '$e'});
      notifyListeners();
    }
  }

  Future<void> clearBlankImage() async {
    try {
      globals = globals.copyWith(isBlankPic: false, showBlankPic: false);
      if (mqttActive) {
        await _mqttSender.sendBlank(Uint8List(0), ext: '');
        await _mqttSender.sendState(globals, showing: showing, wordToHighlight: highPos);
      } else {
        await _sender.sendBlank(Uint8List(0), ext: '');
        await _sender.sendState(globals, showing: showing, wordToHighlight: highPos);
      }
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
        await _mqttSender.sendState(globals, showing: showing, wordToHighlight: highPos);
      } else {
        await _sender.sendState(globals, showing: showing, wordToHighlight: highPos);
      }

      // End-program commands are one-shot signals in Android too.
      globals = globals.copyWith(endProgram: 0);

      _setStatus(wantShutdown ? 'statusShutdownCommandSent' : 'statusStopCommandSent');
      notifyListeners();
    } catch (e) {
      _setStatus('statusCommandSendError', <String, String>{'error': '$e'});
      notifyListeners();
    }
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
