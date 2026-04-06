import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/mqtt_sender_service.dart';
import '../services/dtx_download_service.dart';
import '../services/settings_store.dart';
import '../services/tcp_sender_service.dart';

class DiatarMainController extends ChangeNotifier {
  final DtxParser _parser = const DtxParser();
  final SettingsStore _settingsStore = SettingsStore();
  final DtxDownloadService _downloadService = DtxDownloadService();
  final TcpSenderService _sender = TcpSenderService(
    onStatusChanged: (bool connected) {},
    onError: (String message) {},
  );
  final MqttSenderService _mqttSender = MqttSenderService(
    onStatusChanged: (bool connected) {},
    onError: (String message) {},
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
  String status = 'Inditas...';
  String lastPicPath = '';
  String lastBlankPath = '';
  bool downloadInProgress = false;
  int downloadCurrentFile = 0;
  int downloadTotalFiles = 0;
  String downloadCurrentName = '';
  double downloadCurrentFraction = 0;
  int _screenWidth = 1920;
  int _screenHeight = 1080;

  Future<void> init() async {
    settings = await _settingsStore.load();
    globals = globals.copyWith(
      projecting: showing,
      fontSize: 70,
      titleSize: 12,
    );
    _configureSender();
    await _applyTransport();
    await reloadBooks();
    await _syncCurrentDia();
  }

  void _configureSender() {
    _sender.onStatusChanged = (bool connected) {
      senderConnected = connected;
      notifyListeners();
    };
    _sender.onError = (String message) {
      status = message;
      notifyListeners();
    };
    _mqttSender.onStatusChanged = (bool connected) {
      senderConnected = connected;
      notifyListeners();
    };
    _mqttSender.onError = (String message) {
      status = message;
      notifyListeners();
    };
  }

  Future<void> applySettings(AppSettings newSettings) async {
    settings = newSettings;
    await _settingsStore.save(settings);
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
      status = 'MQTT kuldes: $user/${settings.mqttChannel}';
    } else {
      await _mqttSender.close();
      await _sender.restart(settings.port);
      await _sender.sendScreenSize(width: _screenWidth, height: _screenHeight);
      senderRunning = _sender.running;
      status = 'TCP kuldes: ${settings.port}';
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
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dtxDir = Directory('${docs.path}/diatar');
      final List<DtxBook> loaded = <DtxBook>[];

      if (await dtxDir.exists()) {
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
      }

      if (loaded.isEmpty) {
        loaded.add(
          const DtxBook(
            fileName: 'demo.dtx',
            title: 'Minta kotet (nincs dtx fajl)',
            nick: 'Minta',
            songs: <DtxSong>[
              DtxSong(
                title: 'Minta enek',
                verses: <DtxVerse>[
                  DtxVerse(name: '1', lines: <String>['Tegy egy .dtx fajlt a dokumentum konyvtar diatar mappajaba.']),
                  DtxVerse(name: '2', lines: <String>['Utana frissits, es valos eneklistat kapsz.']),
                ],
              ),
            ],
          ),
        );
        status = 'Nincs .dtx fajl: ${dtxDir.path}';
      } else {
        loaded.sort(_compareBooksLikeAndroid);
        status = '${loaded.length} kotet betoltve';
      }

      books = loaded;
      bookIndex = 0;
      songIndex = 0;
      verseIndex = 0;
      highPos = 0;
    } catch (e) {
      status = 'Betoltesi hiba: $e';
      books = const <DtxBook>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<DtxDownloadItem>> loadDownloadCandidates() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dtxDir = Directory('${docs.path}/diatar');
    return _downloadService.listUpdates(targetDir: dtxDir);
  }

  Future<void> downloadSongBooks({List<DtxDownloadItem>? selected}) async {
    loading = true;
    downloadInProgress = true;
    downloadCurrentFile = 0;
    downloadTotalFiles = selected?.length ?? 0;
    downloadCurrentName = '';
    downloadCurrentFraction = 0;
    status = 'Enektar lista letoltese...';
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
          status =
              'Letoltes: ${progress.currentFile}/${progress.totalFiles} ${progress.fileName} '
              '${(progress.fraction * 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );
      await reloadBooks();
      status = summary.message;
    } catch (e) {
      status = 'Letoltesi hiba: $e';
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
    status = 'Kotet: ${selected?.displayName ?? '-'}';
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
    status = 'Enek: ${currentSong?.title ?? '-'}';
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
    status = 'Versszak: ${currentVerse?.name ?? '-'}';
    notifyListeners();
    _syncCurrentDia();
  }

  void nextVerse() {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
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
    _selectSongAndVerse(nextSongIdx, 0, statusPrefix: 'Enek/versszak');
  }

  void prevVerse() {
    final DtxSong? s = currentSong;
    if (s == null || s.verses.isEmpty) {
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
    _selectSongAndVerse(prevSongIdx, targetVerse, statusPrefix: 'Enek/versszak');
  }

  void nextSong() {
    final int? nextSongIdx = _findSelectableSongIndex(songIndex + 1, forward: true);
    if (nextSongIdx == null) {
      return;
    }
    _selectSongAndVerse(nextSongIdx, 0, statusPrefix: 'Enek');
  }

  void prevSong() {
    final int? prevSongIdx = _findSelectableSongIndex(songIndex - 1, forward: false);
    if (prevSongIdx == null) {
      return;
    }
    _selectSongAndVerse(prevSongIdx, 0, statusPrefix: 'Enek');
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

  void _selectSongAndVerse(int targetSong, int targetVerse, {required String statusPrefix}) {
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
    status = '$statusPrefix: ${songModel.title}';
    notifyListeners();
    _syncCurrentDia();
  }

  void toggleShowing() {
    showing = !showing;
    status = showing ? 'Vetites: BE' : 'Vetites: KI';
    notifyListeners();
    _syncCurrentDia();
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
      status = 'A kep fajl utvonala ures.';
      notifyListeners();
      return;
    }

    try {
      final File file = File(normalized);
      if (!await file.exists()) {
        status = 'A kep fajl nem talalhato: $normalized';
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
      status = 'Kep elkuldve: ${file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : normalized}';
      notifyListeners();
    } catch (e) {
      status = 'Kep kuldesi hiba: $e';
      notifyListeners();
    }
  }

  Future<void> sendBlankFromPath(String path) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      status = 'A blank kep fajl utvonala ures.';
      notifyListeners();
      return;
    }

    try {
      final File file = File(normalized);
      if (!await file.exists()) {
        status = 'A blank kep fajl nem talalhato: $normalized';
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
      status = 'Blank kep beallitva: ${file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : normalized}';
      notifyListeners();
    } catch (e) {
      status = 'Blank kep kuldesi hiba: $e';
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
      status = 'Blank kep torolve.';
      notifyListeners();
    } catch (e) {
      status = 'Blank kep torlesi hiba: $e';
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

      status = wantShutdown
          ? 'Lezaras utasitas elkuldve.'
          : 'Megallitas utasitas elkuldve.';
      notifyListeners();
    } catch (e) {
      status = 'Utasitas kuldesi hiba: $e';
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
