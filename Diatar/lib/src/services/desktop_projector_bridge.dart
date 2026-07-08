import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';

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
    _enabled = _isDesktopPlatform();
    _lastSettings = settings;
    if (!_enabled) {
      return;
    }
    if (_windowController != null || _starting) {
      await updateSettings(settings);
      return;
    }

    _starting = true;
    try {
      _windowController = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode(<String, Object?>{
            'businessId': _businessId,
            'side': settings.desktopProjectorSide.clamp(0, 1),
          }),
        ),
      );
      await _windowController?.show();
      unawaited(_retryReplayPending());
    } finally {
      _starting = false;
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    _lastSettings = settings;
    if (!_enabled) {
      return;
    }
    await _invoke('settings', settings.toMap(), cache: () {});
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

  Future<void> dispose() async {
    _windowController = null;
    _starting = false;
    _enabled = false;
    _lastStateBytes = null;
    _lastTextBytes = null;
    _lastPicBytes = null;
    _lastBlankBytes = null;
    _hasState = false;
    _hasText = false;
    _hasPic = false;
    _hasBlank = false;
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
}
