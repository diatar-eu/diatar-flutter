import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/hotkeys/desktop_hotkey_dispatch.dart';

class DesktopProjectorBridge {
  DesktopProjectorBridge._();

  static final DesktopProjectorBridge instance = DesktopProjectorBridge._();

  static const String _channelName = 'diatar/desktop_projector';
  static const String _controlChannelName = 'diatar/desktop_projector_control';
  static const String _businessId = 'desktop_projector';
  static const Duration _windowOpTimeout = Duration(milliseconds: 1200);

  final WindowMethodChannel _channel = const WindowMethodChannel(
    _channelName,
    mode: ChannelMode.unidirectional,
  );
  final WindowMethodChannel _controlChannel = const WindowMethodChannel(
    _controlChannelName,
    mode: ChannelMode.unidirectional,
  );

  WindowController? _windowController;
  bool _starting = false;
  bool _enabled = false;
  bool _controlHidden = false;
  Future<void> _settingsTransition = Future<void>.value();
  Future<void>? _recovery;
  StreamSubscription<void>? _windowsChangedSubscription;
  AppSettings _lastSettings = const AppSettings();

  /// Akkor hívódik meg, ha a vezérlő ablakot külső esemény (pl. a vetítő
  /// ablakba való kattintás) hozza vissza. A controller ezen keresztül
  /// szinkronizálhatja a belső `controlWindowHidden` állapotát.
  VoidCallback? onControlWindowRestored;

  /// A vetítőablakból érkező, már feloldott gyorsbillentyű-parancsokat adja
  /// át a controllernek.
  void Function(DesktopHotkeyCommand command)? onDesktopHotkeyCommand;
  Uint8List? _lastStateBytes;
  Uint8List? _lastTextBytes;
  Uint8List? _lastRenderedTextBytes;
  Uint8List? _lastPicBytes;
  Uint8List? _lastBlankBytes;
  ProjectionGlobals _lastGlobals = const ProjectionGlobals();
  bool _hasState = false;
  bool _hasText = false;
  bool _hasRenderedText = false;
  bool _hasPic = false;
  bool _hasBlank = false;

  bool get isEnabled => _enabled;

  bool get _isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// A szoftveres OpenGL-es régi Linux gépeken a másodlagos Flutter-motor
  /// szövegrajzolása nem megbízható. Ezeknek előre renderelt képet küldünk;
  /// minden más platform a kisebb, natív szövegüzenetet használja.
  bool get _useRenderedText =>
      _isLinux && Platform.environment['DIATAR_DISABLE_IMPELLER'] == '1';

  Future<void> start(AppSettings settings) async {
    _enabled = _isDesktopPlatform() && settings.desktopProjectorEnabled;
    _lastSettings = settings;
    _listenToWindowChanges();
    if (!_enabled) {
      await _closeProjectorWindowsBestEffort();
      return;
    }
    await _controlChannel.setMethodCallHandler(_handleControlMethodCall);
    await _adoptExistingProjectorWindow();
    await _ensureProjectorWindow();
    await _invoke('settings', settings.toMap(), cache: () {});
  }

  /// Figyeli a natív ablaklista változásait, hogy a váratlanul eltűnt
  /// (pl. felhasználó által bezárt) vetítőablakot újra létrehozhassuk.
  void _listenToWindowChanges() {
    _windowsChangedSubscription ??= onWindowsChanged.listen((_) {
      unawaited(_handleWindowsChanged());
    });
  }

  Future<void> _handleWindowsChanged() async {
    if (!_enabled) {
      return;
    }
    final WindowController? current = _windowController;
    if (current == null) {
      return;
    }
    // Rövid késleltetés, hogy az ablaklista stabilizálódjon (a frissen
    // létrehozott ablak csak a motor indulása után jelenik meg).
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_enabled || !identical(_windowController, current)) {
      return;
    }
    try {
      final List<WindowController> all = await WindowController.getAll();
      final bool alive = all.any(
        (WindowController controller) => controller.windowId == current.windowId,
      );
      if (alive) {
        return;
      }
      _windowController = null;
      _scheduleProjectorRecovery();
    } catch (_) {
      // nem kritikus
    }
  }

  Future<dynamic> _handleControlMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'showControl':
        await _restoreControlWindow();
        return null;
      case 'focusControl':
        await focusControlWindow();
        return null;
      case 'ready':
        // A vetítő motor befejezte az indulást és regisztrálta az
        // adatcsatornát: most küldjük el a függőben lévő állapotot.
        if (_windowController == null) {
          await _adoptExistingProjectorWindow();
        }
        await _replayPending();
        return null;
      case 'hotkey':
        final DesktopHotkeyCommand? command = DesktopHotkeyCommand.fromMap(
          call.arguments,
        );
        if (command != null) {
          onDesktopHotkeyCommand?.call(command);
        }
        return null;
      default:
        throw MissingPluginException(
          'Unknown desktop projector control method: ${call.method}',
        );
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settingsTransition = _settingsTransition.then(
      (_) => _updateSettingsCore(settings),
      onError: (_) => _updateSettingsCore(settings),
    );
    return _settingsTransition;
  }

  Future<void> _updateSettingsCore(AppSettings settings) async {
    final bool newEnabled =
        _isDesktopPlatform() && settings.desktopProjectorEnabled;
    _lastSettings = settings;

    // Ha nem változott az engedélyezett állapot, csak továbbítjuk a
    // beállításokat (pl. monitorváltás) a meglévő vetítőablaknak.
    if (newEnabled == _enabled) {
      if (!_enabled) {
        await _closeProjectorWindowsBestEffort();
        return;
      }
      await _adoptExistingProjectorWindow();
      await _invoke('settings', settings.toMap(), cache: () {});
      await _invoke('relocate', <String, Object?>{
        'monitor': settings.desktopProjectorMonitor,
        'mainMonitor': await _currentDisplayIndex(),
      }, cache: () {});
      final Uint8List? lastTextBytes = _lastTextBytes;
      if (_hasText && lastTextBytes != null) {
        await _sendTextToProjector(lastTextBytes);
      }
      return;
    }

    // Állapotváltás: be/ki kapcsolás azonnali hatálya.
    if (newEnabled) {
      _enabled = true;
      await _adoptExistingProjectorWindow();
      await _ensureProjectorWindow();
      await _invoke('settings', settings.toMap(), cache: () {});
      unawaited(_retryReplayPending());
    } else {
      // Az `_enabled` jelzőt azonnal lekapcsoljuk, hogy bármely közben futó
      // küldés/ikonművelet ne tudja visszanyitni a vetítőablakot.
      _enabled = false;
      // Kikapcsoláskor előbb visszaállítjuk a vezérlő ablakot (ha épp
      // el volt rejtve), majd elrejtjük a vetítőablakot.
      await _restoreControlWindow();
      await _closeWindow();
      await _closeProjectorWindowsBestEffort();
    }
  }

  /// A vetítőablakot elrejti (nem zárja be).
  ///
  /// Minden platformon ugyanezt tesszük: a gyerekablak bezárása a
  /// desktop_multi_window + window_manager kombinációban Linuxon crash-t
  /// okoz ("The implicit view cannot be removed"), és a motor megszűnésével
  /// a natív csatorna-regisztráció is árva maradhat. Az elrejtés egységes,
  /// veszteségmentes életciklust ad, és a meglévő ablak újra megjeleníthető.
  Future<void> _closeWindow() async {
    try {
      await _windowController?.hide().timeout(_windowOpTimeout);
    } catch (_) {
      // nem kritikus
    }
    _windowController = null;
    _starting = false;
    _lastStateBytes = null;
    _lastTextBytes = null;
    _lastRenderedTextBytes = null;
    _lastPicBytes = null;
    _lastBlankBytes = null;
    _hasState = false;
    _hasText = false;
    _hasRenderedText = false;
    _hasPic = false;
    _hasBlank = false;
  }

  Future<void> sendState(
    ProjectionGlobals globals, {
    required bool showing,
    required int wordToHighlight,
  }) async {
    if (!_enabled) {
      return;
    }
    _lastGlobals = globals.copyWith(
      projecting: showing,
      wordToHighlight: wordToHighlight,
    );
    final Uint8List body = encodeStateRecord(
      globals,
      projecting: showing,
      wordToHighlight: wordToHighlight,
    );
    _lastStateBytes = body;
    _hasState = true;
    await _invoke('state', body, cache: () {});
    final Uint8List? lastTextBytes = _lastTextBytes;
    if (_useRenderedText && _hasText && lastTextBytes != null) {
      await _renderAndSendText(lastTextBytes);
    }
  }

  Future<void> sendText({
    required String title,
    required List<String> lines,
  }) async {
    if (!_enabled) {
      return;
    }
    final Uint8List body = encodeTextRecord(title: title, lines: lines);
    _lastTextBytes = body;
    _hasText = true;
    _lastRenderedTextBytes = null;
    _hasRenderedText = false;
    await _sendTextToProjector(body);
  }

  Future<void> sendPic(Uint8List bytes, {String ext = ''}) async {
    if (!_enabled) {
      return;
    }
    final Uint8List body = encodeImageRecord(bytes: bytes, ext: ext);
    _lastPicBytes = body;
    _hasPic = true;
    await _invoke('pic', body, cache: () {});
  }

  Future<void> sendBlank(Uint8List bytes, {String ext = ''}) async {
    if (!_enabled) {
      return;
    }
    final Uint8List body = encodeImageRecord(bytes: bytes, ext: ext);
    _lastBlankBytes = body;
    _hasBlank = true;
    await _invoke('blank', body, cache: () {});
  }

  Future<void> sendIdle() async {
    if (!_enabled) {
      return;
    }
    await _invoke('idle', null, cache: () {});
  }

  /// Elrejti a vezérlő (fő) ablakot, hogy a vetítés látszódjon.
  ///
  /// A **minimalizálást** használjuk, nem az elrejtést és nem az
  /// átlátszóságot. A minimalizált ablak kikerül a képernyőről (a dia nem villan
  /// át rajta), de a rendszer megőrzi a tálca-, a panel- és az
  /// Alt+TAB-bejegyzését, így a felhasználó bármikor visszahozhatja. Az
  /// elrejtés (`windowManager.hide()`) ezt elrontja: Windowson az ablak
  /// eltűnik a tálcáról és az Alt+TAB-ból, Linuxon a panelről, és mivel a
  /// rejtett vezérlőfelületen nincs programsáv, visszahozni is csak a
  /// vetítésre való kattintással lehet — ami pont akkor nem elérhető, ha az
  /// eleve nem működik.
  ///
  /// A vetítőablak a vezérlőablak előtt veszi át a fókuszt, így a
  /// gyorsbillentyűket megkapja és továbbítja a vezérlőablaknak.
  ///
  /// `true`, ha az ablak valóban eltűnt; `false` esetén a hívó ne ürítse ki
  /// a vezérlőfelületet.
  Future<bool> hideControlWindow() async {
    if (!_enabled) {
      return false;
    }
    try {
      // Előbb a vetítőablaknak adjuk a fókuszt, és csak utána lépünk félre:
      // a Windows az aktív ablak minimalizálásakor egy másik ablakra adja át
      // a fókuszt, így fordított sorrendben a fókusz a minimalizálás után
      // rögtön elsodródna, és a gyorsbillentyűk nem kapnák meg.
      await _focusProjectorWindow();
      await windowManager.minimize();
    } catch (_) {
      // Ha nem sikerült elrejteni, maradjon a vezérlőfelület a helyén.
      _controlHidden = false;
      return false;
    }
    _controlHidden = true;
    return true;
  }

  /// Visszaállítja a vezérlő (fő) ablakot a vetítésbe való kattintás után.
  Future<bool> showControlWindow() async {
    if (!_enabled) {
      return false;
    }
    return _restoreControlWindow();
  }

  /// A vetítőablakot fókuszba hozza, hogy az átvegye a billentyűzetet a
  /// elrejtett vezérlőablaktól.
  Future<void> _focusProjectorWindow() async {
    try {
      await _channel.invokeMethod('focus', null).timeout(_windowOpTimeout);
    } catch (_) {
      // nem kritikus; a következő hotkey-ig a fókusz a régi maradhat
    }
  }

  /// A felhasználó a rendszeren keresztül hozta vissza a vezérlő ablakot
  /// (tálcáról, Alt+TAB-bal, a panel ikonjáról): ezt nem a bridge kérte, így
  /// a rejtett jelzőt és a vezérlőfelületet itt kell visszaállítani.
  ///
  /// Csak akkor fogadjuk el, ha az ablak már nem minimalizált, hogy a
  /// minimalizáláshoz tartozó fókuszváltás (amit magunk indítunk) ne oldja fel
  /// a rejtett állapotot. Ha nem tudunk róla döntést, akkor fogadjuk el a
  /// visszahozást: inkább egy látható vezérlőfelület, mint egy elakadt állapot.
  Future<void> handleExternalRestore() async {
    if (!_controlHidden) {
      return;
    }
    try {
      if (await windowManager.isMinimized()) {
        return;
      }
    } catch (_) {
      // nem kritikus
    }
    _controlHidden = false;
    try {
      onControlWindowRestored?.call();
    } catch (_) {
      // nem kritikus
    }
  }

  /// A vezérlő ablak eredeti (látható, fókuszált) állapotának
  /// visszaállítása. Nem függ az `_enabled` állapottól, így kikapcsoláskor is
  /// meghívható.
  Future<bool> _restoreControlWindow() async {
    _controlHidden = false;
    bool shown = true;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      shown = false;
    }
    if (!shown) {
      return false;
    }
    // Jelezzük a controllernek, hogy a vezérlő ablak újra látható
    // (pl. a vetítőbe kattintás miatt), hogy a UI visszaálljon.
    try {
      onControlWindowRestored?.call();
    } catch (_) {
      // nem kritikus
    }
    return true;
  }

  /// A vezérlőablakot fókuszba hozza a vetítő fölé. Ha a vezérlőablak
  /// szándékosan el van rejtve, nem hozzuk vissza.
  Future<void> focusControlWindow() async {
    if (!_enabled || _controlHidden) {
      return;
    }
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // nem kritikus
    }
  }

  /// Újra a felszínre hozza a vezérlőablakot (pl. a macOS mentési panel
  /// bezárása után), ha az a vetítőablak mögé került vagy elvesztette a
  /// fókuszt. Nem módosítja a rejtett/átlátszó állapotot.
  Future<void> reassertControlWindow() async {
    if (!_isDesktopPlatform() || _controlHidden) {
      return;
    }
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // nem kritikus
    }
  }

  /// Natív rendszer-párbeszédablak (mentés/megnyitás/mappa) előkészítése.
  ///
  /// A vezérlő (fő) ablakot hozza előre, hogy a párbeszédablak megbízhatóan
  /// megjelenhessen. A macOS-os fájlpárbeszédablakok a `runModal` alapú natív
  /// útvonalon mennek (lásd: `macos_file_panels`), így a vetítőablak
  /// jelenléte nem zavarja őket.
  Future<void> prepareForNativeDialog() async {
    if (!_isDesktopPlatform() || _controlHidden) {
      return;
    }
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // nem kritikus
    }
  }

  /// A natív rendszer-párbeszédablak bezárása után visszaállítja a
  /// vezérlőablak állapotát.
  Future<void> releaseFromNativeDialog() async {
    if (!_isDesktopPlatform()) {
      return;
    }
    await reassertControlWindow();
  }

  /// Natív rendszer-párbeszédablakot (mentés/megnyitás/mappa választó)
  /// futtat az előkészítő/visszaállító lépésekkel körülvéve. Weben és
  /// mobilon nem csinál semmit.
  Future<T> runWithNativeDialog<T>(Future<T> Function() action) async {
    await prepareForNativeDialog();
    try {
      return await action();
    } finally {
      await releaseFromNativeDialog();
    }
  }

  Future<void> dispose() async {
    await _windowsChangedSubscription?.cancel();
    _windowsChangedSubscription = null;
    await _closeWindow();
    await _controlChannel.setMethodCallHandler(null);
    _enabled = false;
  }

  Future<void> _retryReplayPending() async {
    for (int attempt = 0; attempt < 8; attempt++) {
      if (_windowController == null) {
        return;
      }
      final bool sentAnything = await _replayPending();
      if (sentAnything) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<bool> _replayPending() async {
    bool sent = false;
    if (!_enabled || _windowController == null) {
      return false;
    }
    try {
      await _channel.invokeMethod('settings', _lastSettings.toMap());
      sent = true;
      if (_hasState && _lastStateBytes != null) {
        await _channel.invokeMethod('state', _lastStateBytes);
      }
      if (_hasText && _lastTextBytes != null) {
        if (_useRenderedText &&
            _hasRenderedText &&
            _lastRenderedTextBytes != null) {
          await _channel.invokeMethod('rendered_text', _lastRenderedTextBytes);
        } else {
          await _channel.invokeMethod('text', _lastTextBytes);
        }
      }
      if (_hasBlank && _lastBlankBytes != null) {
        await _channel.invokeMethod('blank', _lastBlankBytes);
      }
      if (_hasPic && _lastPicBytes != null) {
        await _channel.invokeMethod('pic', _lastPicBytes);
      }
    } catch (_) {
      sent = false;
    }
    return sent;
  }

  Future<T?> _invoke<T>(
    String method,
    dynamic arguments, {
    required VoidCallback cache,
  }) async {
    if (_windowController == null) {
      cache();
      return null;
    }

    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on WindowChannelException catch (error) {
      cache();
      // Az „a csatorna még nincs regisztrálva” átmeneti állapot: a vetítő
      // `ready` üzenetére újraküldjük a függőben lévő állapotot, és nem
      // dobjuk el a controllerünket (ez korábban duplikált ablakokat okozott).
      if (!_isTransientChannelError(error)) {
        _windowController = null;
        _scheduleProjectorRecovery();
      }
      return null;
    } catch (_) {
      cache();
      _windowController = null;
      _scheduleProjectorRecovery();
      return null;
    }
  }

  bool _isTransientChannelError(WindowChannelException error) {
    return error.code == 'CHANNEL_UNREGISTERED' ||
        error.code == 'CHANNEL_NOT_FOUND' ||
        error.code == 'NO_HANDLER';
  }

  Future<void> _sendTextToProjector(Uint8List textBytes) async {
    if (!_useRenderedText) {
      await _invoke('text', textBytes, cache: () {});
      return;
    }
    await _renderAndSendText(textBytes);
  }

  Future<void> _renderAndSendText(Uint8List textBytes) async {
    final ui.Size size = await _projectorDisplaySize();
    if (size.isEmpty) {
      await _invoke('text', textBytes, cache: () {});
      return;
    }

    final RecTextRecord record = RecTextRecord.fromBytes(textBytes);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    ProjectorPainter(
      frame: TextFrame(record: record),
      globals: _lastGlobals,
      settings: _lastSettings,
    ).paint(canvas, size);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    picture.dispose();
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (byteData == null) {
      await _invoke('text', textBytes, cache: () {});
      return;
    }

    final Uint8List imageBytes = Uint8List.fromList(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
    _lastRenderedTextBytes = encodeImageRecord(bytes: imageBytes, ext: 'png');
    _hasRenderedText = true;
    final bool? decoded = await _invoke<bool>(
      'rendered_text',
      _lastRenderedTextBytes,
      cache: () {},
    );
    if (decoded != true) {
      _hasRenderedText = false;
      _lastRenderedTextBytes = null;
      await _invoke('text', textBytes, cache: () {});
    }
  }

  Future<ui.Size> _projectorDisplaySize() async {
    final List<Display> displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      return ui.Size.zero;
    }
    final List<Display> sorted = List<Display>.from(displays)
      ..sort((Display a, Display b) {
        final double ax = a.visiblePosition?.dx ?? 0;
        final double bx = b.visiblePosition?.dx ?? 0;
        return ax.compareTo(bx);
      });
    final int requested = _lastSettings.desktopProjectorMonitor;
    final int index = requested >= 0 && requested < sorted.length
        ? requested
        : sorted.length - 1;
    return sorted[index].size;
  }

  Future<void> _recoverProjectorWindow() async {
    // Rövid késleltetés, hogy az ablaklista stabilizálódjon.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!_enabled) {
      return;
    }
    await _adoptExistingProjectorWindow();
    if (_windowController != null) {
      await _invoke('settings', _lastSettings.toMap(), cache: () {});
      await _replayPending();
      return;
    }
    await _ensureProjectorWindow();
    await _invoke('settings', _lastSettings.toMap(), cache: () {});
  }

  /// A helyreállítást sorosítja, hogy egy hiba se indítson több párhuzamos
  /// újranyitást (korábban ez duplikált vetítőablakokat eredményezett).
  void _scheduleProjectorRecovery() {
    if (!_enabled || _recovery != null) {
      return;
    }
    _recovery = _recoverProjectorWindow().whenComplete(() {
      _recovery = null;
    });
  }

  Future<void> _ensureProjectorWindow() async {
    if (!_enabled || _windowController != null || _starting) {
      return;
    }
    _starting = true;
    try {
      final int mainMonitor = await _currentDisplayIndex();
      _windowController = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode(<String, Object?>{
            'businessId': _businessId,
            'monitor': _lastSettings.desktopProjectorMonitor,
            'mainMonitor': mainMonitor,
          }),
        ),
      );
      if (_windowController == null) {
        return;
      }
      await _windowController?.show();
      unawaited(_retryReplayPending());
    } finally {
      _starting = false;
    }
  }

  Future<void> _adoptExistingProjectorWindow() async {
    try {
      final List<WindowController> all = await WindowController.getAll();
      final List<WindowController> projectors = all
          .where(
            (WindowController controller) =>
                _isProjectorWindowArgs(controller.arguments),
          )
          .toList();
      if (projectors.isEmpty) {
        return;
      }
      final WindowController adopted = projectors.last;
      _windowController = adopted;
      await adopted.show().timeout(_windowOpTimeout);
      for (int i = 0; i < projectors.length - 1; i++) {
        unawaited(_closeWindowControllerBestEffort(projectors[i]));
      }
    } catch (_) {
      // nem kritikus
    }
  }

  Future<void> _closeProjectorWindowsBestEffort() async {
    try {
      final List<WindowController> all = await WindowController.getAll();
      for (final WindowController controller in all) {
        if (!_isProjectorWindowArgs(controller.arguments)) {
          continue;
        }
        await _closeWindowControllerBestEffort(controller);
      }
    } catch (_) {
      // nem kritikus
    }
  }

  Future<void> _closeWindowControllerBestEffort(
    WindowController controller,
  ) async {
    // Egységesen elrejtjük: a bezárás Linuxon crash-t okoz, és a motor
    // megszűnésével a natív csatorna-regisztráció árva maradhat.
    try {
      await controller.hide().timeout(_windowOpTimeout);
    } catch (_) {
      // nem kritikus
    }
  }

  bool _isProjectorWindowArgs(String raw) {
    try {
      if (raw.trim().isEmpty) {
        return false;
      }
      final Object decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return false;
      }
      final Map<dynamic, dynamic> map = decoded;
      return map['businessId'] == _businessId;
    } catch (_) {
      return false;
    }
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Visszaadja a főablakot tartalmazó kijelző indexét (balról jobbra
  /// rendezve), vagy -1-et, ha nem állapítható meg.
  Future<int> _currentDisplayIndex() async {
    try {
      final ui.Rect bounds = await windowManager.getBounds();
      final double centerX = bounds.left + bounds.width / 2;
      final double centerY = bounds.top + bounds.height / 2;
      final List<Display> displays = await screenRetriever.getAllDisplays();
      final List<Display> sorted = List<Display>.from(displays)
        ..sort((Display a, Display b) {
          final double ax = a.visiblePosition?.dx ?? 0;
          final double bx = b.visiblePosition?.dx ?? 0;
          return ax.compareTo(bx);
        });
      for (int i = 0; i < sorted.length; i++) {
        final Display d = sorted[i];
        final ui.Offset pos = d.visiblePosition ?? ui.Offset.zero;
        final ui.Size size = d.size;
        if (centerX >= pos.dx &&
            centerX < pos.dx + size.width &&
            centerY >= pos.dy &&
            centerY < pos.dy + size.height) {
          return i;
        }
      }
    } catch (_) {
      // nem kritikus
    }
    return -1;
  }
}
