import 'dart:async';
import 'dart:convert';
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

  final WindowMethodChannel _channel = const WindowMethodChannel(
    _channelName,
    mode: ChannelMode.unidirectional,
  );

  WindowController? _windowController;
  bool _starting = false;
  bool _enabled = false;
  AppSettings _lastSettings = const AppSettings();
  ui.Rect? _savedControlBounds;

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

  Future<void> start(AppSettings settings) async {
    _enabled = _isDesktopPlatform() && settings.desktopProjectorEnabled;
    _lastSettings = settings;
    if (!_enabled) {
      return;
    }
    // Csak egyszer hozzuk létre a vetítőablakot. Ha már létezik (vagy épp
    // készül), akkor csak frissítjük a beállításokat, hogy ne nyíljon meg
    // második vetítőablak.
    if (_windowController != null || _starting) {
      await updateSettings(settings);
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
            'monitor': settings.desktopProjectorMonitor,
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

  Future<void> updateSettings(AppSettings settings) async {
    final bool newEnabled =
        _isDesktopPlatform() && settings.desktopProjectorEnabled;
    _lastSettings = settings;

    // Ha nem változott az engedélyezett állapot, csak továbbítjuk a
    // beállításokat (pl. monitorváltás) a meglévő vetítőablaknak.
    if (newEnabled == _enabled) {
      if (!_enabled) {
        return;
      }
      await _invoke('settings', settings.toMap(), cache: () {});
      return;
    }

    // Állapotváltás: be/ki kapcsolás azonnali hatálya.
    if (newEnabled) {
      _enabled = true;
      if (_windowController != null || _starting) {
        await _invoke('settings', settings.toMap(), cache: () {});
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
              'monitor': settings.desktopProjectorMonitor,
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
    } else {
      // Kikapcsoláskor előbb visszaállítjuk a vezérlő ablakot (ha épp
      // el volt rejtve), majd bezárjuk a vetítőablakot.
      await _restoreControlWindow();
      await _closeWindow();
      _enabled = false;
    }
  }

  Future<void> _closeWindow() async {
    try {
      // A vetítőablakot a saját maga zárja be (windowManager.close),
      // mivel a WindowControllernek nincs close metódusa. Így a
      // WindowListener.onWindowClose is megfelelően lefut.
      await _channel.invokeMethod('close', null);
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

  Future<void> sendText({required String title, required List<String> lines}) async {
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
  /// Ablak teljes elrejtése helyett átlátszóvá (opacity 0) tesszük, miközben
  /// megőrizzük a fókuszt. Így a Flutter Focus-rétegen keresztül a
  /// gyorsbillentyűk továbbra is működnek. A vezérlő ablakot teljes
  /// képernyőre (a kijelző teljes területére) helyezzük, hogy az átlátszó
  /// `cursor: none` réteg az egész vetítőfelületet lefedje – így a kurzor
  /// akkor is el van rejtve, ha a vezérlő eredeti helyén kívülre húzzuk az
  /// egeret. A `setIgnoreMouseEvents(true, forward: true)` gondoskodik róla,
  /// hogy az átlátszó ablak ne kapja el az egérmutatót, hanem továbbadja az
  /// alatta lévő vetítőablaknak (visszahozáshoz a vetítésbe kattintva).
  Future<void> hideControlWindow() async {
    if (!_enabled) {
      return;
    }
    try {
      _savedControlBounds = await windowManager.getBounds();
      final List<Display> displays = await screenRetriever.getAllDisplays();
      final List<Display> sorted = List<Display>.from(displays)
        ..sort((Display a, Display b) {
          final double ax = a.visiblePosition?.dx ?? 0;
          final double bx = b.visiblePosition?.dx ?? 0;
          return ax.compareTo(bx);
        });
      final int mainIndex = await _currentDisplayIndex();
      final int index =
          (mainIndex >= 0 && mainIndex < sorted.length) ? mainIndex : 0;
      final Display d = sorted[index];
      final ui.Offset pos = d.visiblePosition ?? ui.Offset.zero;
      final ui.Size size = d.visibleSize ?? d.size;
      await windowManager.setFullScreen(true);
      await windowManager.setBounds(
        ui.Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
      );
      await windowManager.setIgnoreMouseEvents(true, forward: true);
      await windowManager.setOpacity(0.0);
    } catch (_) {
      // nem kritikus
    }
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
      await windowManager.setOpacity(1.0);
      await windowManager.setIgnoreMouseEvents(false);
      if (_savedControlBounds != null) {
        await windowManager.setBounds(_savedControlBounds!);
      }
      await windowManager.setFullScreen(false);
      await windowManager.focus();
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
      unawaited(_retryReplayPending());
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
