import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class DesktopProjectorBridge {
  DesktopProjectorBridge._();

  static final DesktopProjectorBridge instance = DesktopProjectorBridge._();

  static const String _channelName = 'diatar/desktop_projector';
  static const String _businessId = 'desktop_projector';
  static const String _windowCloseMethod = 'window_close';
  static const Duration _windowOpTimeout = Duration(milliseconds: 1200);
  static const double _hiddenOpacityWindows = 0.01;

  final WindowMethodChannel _channel = const WindowMethodChannel(
    _channelName,
    mode: ChannelMode.unidirectional,
  );

  WindowController? _windowController;
  bool _starting = false;
  bool _enabled = false;
  bool _controlWindowHidden = false;
  Future<void> _settingsTransition = Future<void>.value();
  AppSettings _lastSettings = const AppSettings();

  /// Akkor hívódik meg, ha a vezérlő ablakot külső esemény (pl. a vetítő
  /// ablakba való kattintás) hozza vissza. A controller ezen keresztül
  /// szinkronizálhatja a belső `controlWindowHidden` állapotát.
  VoidCallback? onControlWindowRestored;
  Uint8List? _lastStateBytes;
  Uint8List? _lastTextBytes;
  Uint8List? _lastPicBytes;
  Uint8List? _lastBlankBytes;
  bool _hasState = false;
  bool _hasText = false;
  bool _hasPic = false;
  bool _hasBlank = false;

  bool get isEnabled => _enabled;

  /// Linuxon a desktop_multi_window 0.3.0 + window_manager 0.5.2
  /// gyerekablak-bezárása crash-t okoz (lásd: _closeWindow), ezért
  /// Linuxon eltérő (rejtő) viselkedést használunk.
  bool get _isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  Future<void> start(AppSettings settings) async {
    _enabled = _isDesktopPlatform() && settings.desktopProjectorEnabled;
    _lastSettings = settings;
    if (!_enabled) {
      await _closeProjectorWindowsBestEffort();
      return;
    }
    await _adoptExistingProjectorWindow();
    await _ensureProjectorWindow();
    await _invoke('settings', settings.toMap(), cache: () {});
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
      await _invoke(
        'relocate',
        <String, Object?>{
          'monitor': settings.desktopProjectorMonitor,
          'mainMonitor': await _currentDisplayIndex(),
        },
        cache: () {},
      );
      return;
    }

    // Állapotváltás: be/ki kapcsolás azonnali hatálya.
    if (newEnabled) {
      _enabled = true;
      await _adoptExistingProjectorWindow();
      await _ensureProjectorWindow();
      await _invoke('settings', settings.toMap(), cache: () {});
    } else {
      // Az `_enabled` jelzőt azonnal lekapcsoljuk, hogy bármely közben futó
      // küldés/ikonművelet ne tudja visszanyitni a vetítőablakot.
      _enabled = false;
      // Kikapcsoláskor előbb visszaállítjuk a vezérlő ablakot (ha épp
      // el volt rejtve), majd bezárjuk a vetítőablakot.
      await _restoreControlWindow();
      await _closeWindow();
      await _closeProjectorWindowsBestEffort();
    }
  }

  Future<void> _closeWindow() async {
    try {
      if (_isLinux) {
        // A Linux-i desktop_multi_window 0.3.0 + window_manager 0.5.2
        // kombinációban a gyerekablak bezárása (windowManager.close)
        // crash-t okoz ("The implicit view cannot be removed", lásd
        // MixinNetwork/flutter-plugins#488). Ezért Linuxon csak
        // elrejtjük az ablakot, a motort nem állítjuk le; újra
        // bekapcsoláskor a meglévő ablakot visszahozzuk.
        await _windowController?.hide().timeout(_windowOpTimeout);
      } else {
        // A vetítőablakot a saját maga zárja be (windowManager.close),
        // mivel a WindowControllernek nincs close metódusa. Így a
        // WindowListener.onWindowClose is megfelelően lefut.
        await _channel.invokeMethod('close', null).timeout(_windowOpTimeout);
      }
    } catch (_) {
      // nem kritikus
    }
    _windowController = null;
    _starting = false;
    _lastStateBytes = null;
    _lastTextBytes = null;
    _lastPicBytes = null;
    _lastBlankBytes = null;
    _hasState = false;
    _hasText = false;
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
    final Uint8List body = encodeStateRecord(
      globals,
      projecting: showing,
      wordToHighlight: wordToHighlight,
    );
    _lastStateBytes = body;
    _hasState = true;
    await _invoke('state', body, cache: () {});
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
    await _invoke('text', body, cache: () {});
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

  /// Elrejti a vezérlő (fő) ablakot, ha a vetítő ablakkal azonos
  /// monitoron vagyunk, hogy a vetítés látszódjon.
  ///
  /// Ablakmozgatás/átméretezés nélkül átlátszóvá tesszük, és átadjuk az
  /// egéreseményeket a vetítőablaknak. Win10 alatt ez stabilabb, mert elkerüli
  /// a DPI/surface deszinkront, ami torz visszarajzolást okozhat.
  Future<void> hideControlWindow() async {
    if (!_enabled) {
      return;
    }
    try {
      await windowManager.setIgnoreMouseEvents(true, forward: true);
      await windowManager.setOpacity(
        Platform.isWindows ? _hiddenOpacityWindows : 0.0,
      );
    } catch (_) {
      // nem kritikus
    }
    _controlWindowHidden = true;
  }

  /// Visszaállítja a vezérlő (fő) ablakot a vetítésbe való kattintás után.
  Future<void> showControlWindow() async {
    if (!_enabled) {
      return;
    }
    await _restoreControlWindow();
  }

  /// A vezérlő ablak eredeti (látható, egérrel kezelhető, nem teljes
  /// képernyős) állapotának visszaállítása. Nem függ az `_enabled`
  /// állapottól, így kikapcsoláskor is meghívható.
  Future<void> _restoreControlWindow() async {
    try {
      await windowManager.setIgnoreMouseEvents(false);
      await windowManager.setOpacity(1.0);
      await windowManager.show();
      await windowManager.focus();
      _controlWindowHidden = false;
    } catch (_) {
      // nem kritikus
    }
    // Jelezzük a controllernek, hogy a vezérlő ablak újra látható
    // (pl. a vetítőbe kattintás miatt), hogy a UI visszaálljon.
    try {
      onControlWindowRestored?.call();
    } catch (_) {
      // nem kritikus
    }
  }

  /// A vezérlőablakot fókuszba hozza a vetítő fölé úgy, hogy közben
  /// a rejtett állapotot nem módosítja.
  Future<void> focusControlWindow() async {
    if (!_enabled || _controlWindowHidden) {
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
    if (!_isDesktopPlatform()) {
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
    if (!_isDesktopPlatform()) {
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
    await _closeWindow();
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
        await _channel.invokeMethod('text', _lastTextBytes);
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

  Future<void> _invoke(
    String method,
    dynamic arguments, {
    required VoidCallback cache,
  }) async {
    if (_windowController == null) {
      cache();
      return;
    }
    try {
      await _channel.invokeMethod(method, arguments);
    } catch (_) {
      cache();
      // Ha a csatorna már nem elérhető, a tárolt controller valószínűleg
      // egy lezárt (árva) vetítőablakra mutat. Eldobjuk és újranyitjuk.
      _windowController = null;
      if (_enabled) {
        unawaited(_recoverProjectorWindow());
      }
    }
  }

  Future<void> _recoverProjectorWindow() async {
    await _adoptExistingProjectorWindow();
    await _ensureProjectorWindow();
    await _invoke('settings', _lastSettings.toMap(), cache: () {});
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
    if (_isLinux) {
      // Linuxon nem zárjuk be a vetítőablakot, mert az crash-t okoz
      // (lásd: _closeWindow); csak elrejtjük.
      try {
        await controller.hide().timeout(_windowOpTimeout);
      } catch (_) {
        // nem kritikus
      }
      return;
    }
    try {
      await controller
          .invokeMethod(_windowCloseMethod)
          .timeout(_windowOpTimeout);
      return;
    } catch (_) {
      // Ha a per-window close nincs bekötve, próbáljuk a legacy close-t.
    }
    try {
      await controller.invokeMethod('close').timeout(_windowOpTimeout);
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
        final ui.Size size = d.visibleSize ?? d.size;
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
