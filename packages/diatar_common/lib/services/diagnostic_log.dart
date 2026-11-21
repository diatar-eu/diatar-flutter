import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'diagnostic_log_store.dart';
import 'diagnostic_platform.dart';

enum DiagnosticApp { sender, receiver }

enum DiagnosticRole { mqttSender, mqttReceiver }

enum DiagnosticEvent {
  sessionStarted,
  loggingDisabled,
  appResumed,
  appInactive,
  appHidden,
  appPaused,
  appDetached,
  mqttStarting,
  mqttConnecting,
  mqttConnected,
  mqttDisconnected,
  mqttConnectRejected,
  mqttConnectFailed,
  mqttStreamFailed,
  mqttHeartbeat,
  mqttHeartbeatTimeout,
  mqttRetryScheduled,
  mqttRestarting,
  mqttStopped,
  mqttCleanupFailed,
  mqttSubscribed,
  mqttPublishFailed,
}

class DiagnosticMetadata {
  const DiagnosticMetadata({
    required this.version,
    required this.build,
    required this.os,
    required this.osVersion,
  });

  final String version;
  final String build;
  final String os;
  final String osVersion;
}

class DiagnosticLog extends ChangeNotifier {
  DiagnosticLog({
    DiagnosticLogStore? store,
    Future<DiagnosticMetadata> Function()? metadataLoader,
  }) : _store = store ?? PreferencesDiagnosticLogStore(),
       _metadataLoader = metadataLoader ?? _loadMetadata;

  static final DiagnosticLog instance = DiagnosticLog();
  // Reserve space for the export header as well as the bounded log segments.
  static const int segmentBytes = 31 * 1024;
  static const int maxBytes = 1024 * 1024;

  final DiagnosticLogStore _store;
  final Future<DiagnosticMetadata> Function() _metadataLoader;
  final Stopwatch _uptime = Stopwatch()..start();
  final List<_LogSegment> _segments = <_LogSegment>[];
  final Map<int, String> _dirty = <int, String>{};
  Future<void> _pending = Future<void>.value();
  Future<bool>? _initializing;
  AppLifecycleListener? _lifecycle;
  Timer? _flushTimer;
  DiagnosticApp? _app;
  DiagnosticMetadata? _metadata;
  int _nextSequence = 0;
  bool _enabled = false;
  bool _initialized = false;
  bool _failed = false;
  bool _disposed = false;

  bool get enabled => _enabled;
  bool get initialized => _initialized;
  bool get hasEntries => _segments.isNotEmpty;
  bool get failed => _failed;

  Future<bool> initialize(DiagnosticApp app) {
    if (_initialized) {
      return Future<bool>.value(true);
    }
    return _initializing ??= _initialize(app).whenComplete(() {
      _initializing = null;
    });
  }

  Future<bool> _initialize(DiagnosticApp app) async {
    _app = app;
    _segments.clear();
    try {
      try {
        _metadata = await _metadataLoader().timeout(const Duration(seconds: 5));
      } catch (error) {
        debugPrint('Diagnostic application version metadata unavailable.');
      }
      final DiagnosticLogSnapshot snapshot = await _store.load();
      for (final MapEntry<int, String> entry in snapshot.segments.entries) {
        final Object? decoded = jsonDecode(entry.value);
        if (decoded is! Map<String, dynamic> ||
            decoded['sequence'] is! int ||
            decoded['text'] is! String) {
          throw const FormatException('Invalid diagnostic segment');
        }
        final int sequence = decoded['sequence'] as int;
        final String text = decoded['text'] as String;
        if (sequence < 0 ||
            sequence % DiagnosticLogStore.segmentCount != entry.key ||
            utf8.encode(text).length > segmentBytes) {
          throw const FormatException('Invalid diagnostic segment bounds');
        }
        _segments.add(_LogSegment(sequence, text));
      }
      _segments.sort((a, b) => a.sequence.compareTo(b.sequence));
      _nextSequence = _segments.isEmpty ? 0 : _segments.last.sequence + 1;
      _enabled = snapshot.enabled;
      _initialized = true;
      _failed = false;
      if (_enabled) {
        record(DiagnosticEvent.sessionStarted);
      }
      _notify();
      return true;
    } catch (error) {
      _reportFailure();
      return false;
    }
  }

  void observeAppLifecycle() {
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (AppLifecycleState state) {
        record(switch (state) {
          AppLifecycleState.resumed => DiagnosticEvent.appResumed,
          AppLifecycleState.inactive => DiagnosticEvent.appInactive,
          AppLifecycleState.hidden => DiagnosticEvent.appHidden,
          AppLifecycleState.paused => DiagnosticEvent.appPaused,
          AppLifecycleState.detached => DiagnosticEvent.appDetached,
        });
        if (state != AppLifecycleState.resumed) {
          unawaited(flush());
        }
      },
    );
  }

  Future<bool> setEnabled(bool value) async {
    if (!_initialized || _disposed) {
      _reportFailure();
      return false;
    }
    if (!value) {
      record(DiagnosticEvent.loggingDisabled);
    }
    _enabled = value;
    if (value) {
      record(DiagnosticEvent.sessionStarted);
    }
    _notify();
    final bool saved = await _persist(() => _store.setEnabled(value));
    final bool flushed = await flush();
    return saved && flushed;
  }

  // Only fixed event names and numeric values are accepted. Never pass MQTT
  // payloads, topics, exception messages, credentials or user-entered text.
  void record(
    DiagnosticEvent event, {
    DiagnosticRole? role,
    int? code,
    int? elapsedMs,
    int? delaySeconds,
    Object? error,
  }) {
    if (!_enabled || !_initialized || _disposed) {
      return;
    }
    final bool hadEntries = hasEntries;
    final String line =
        '${jsonEncode(<String, Object>{'time': DateTime.now().toUtc().toIso8601String(), 'uptimeMs': _uptime.elapsedMilliseconds, 'event': event.name, if (role != null) 'role': role.name, if (code != null) 'code': code, if (elapsedMs != null) 'elapsedMs': elapsedMs, if (delaySeconds != null) 'delaySeconds': delaySeconds, if (error != null) 'error': _errorCategory(error), if (event == DiagnosticEvent.sessionStarted) ..._environment()})}\n';
    final int bytes = utf8.encode(line).length;
    if (_segments.isEmpty || _segments.last.bytes + bytes > segmentBytes) {
      _segments.add(_LogSegment(_nextSequence++, ''));
      if (_segments.length > DiagnosticLogStore.segmentCount) {
        _segments.removeAt(0);
      }
    }
    final _LogSegment segment = _segments.last;
    segment.text += line;
    segment.bytes += bytes;
    _dirty[segment.index] = segment.encoded;
    if (!hadEntries) {
      _notify();
    }
    _flushTimer ??= Timer(const Duration(seconds: 5), () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  String exportText() =>
      '${jsonEncode(<String, Object>{'format': 1, ..._environment()})}\n'
      '${_segments.map((segment) => segment.text).join()}';

  Future<bool> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final Map<int, String> writes = Map<int, String>.of(_dirty);
    _dirty.clear();
    if (writes.isEmpty) {
      await _pending;
      return !_failed;
    }
    final bool success = await _persist(() async {
      for (final MapEntry<int, String> entry in writes.entries) {
        await _store.writeSegment(entry.key, entry.value);
      }
    });
    if (!success) {
      for (final _LogSegment segment in _segments) {
        _dirty.putIfAbsent(segment.index, () => segment.encoded);
      }
    }
    return success;
  }

  Future<bool> clear() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _dirty.clear();
    _segments.clear();
    _nextSequence = 0;
    _notify();
    final bool success = await _persist(_store.clear);
    final DiagnosticApp? app = _app;
    if (success && !_initialized && app != null) {
      return initialize(app);
    }
    return success;
  }

  Future<bool> _persist(Future<void> Function() write) {
    final Future<bool> result = _pending.then((_) async {
      try {
        await write();
        if (_failed) {
          _failed = false;
          _notify();
        }
        return true;
      } catch (error) {
        _reportFailure();
        return false;
      }
    });
    _pending = result.then<void>((_) {});
    return result;
  }

  Map<String, Object> _environment() {
    final DiagnosticMetadata? metadata = _metadata;
    return <String, Object>{
      'app': _app?.name ?? 'unavailable',
      'metadataAvailable': metadata != null,
      'version': _version(metadata?.version),
      'build': RegExp(r'^\d{1,20}$').hasMatch(metadata?.build ?? '')
          ? metadata!.build
          : 'unavailable',
      'os':
          const <String>{
            'web',
            'android',
            'ios',
            'tvos',
            'macos',
            'windows',
            'linux',
          }.contains(metadata?.os)
          ? metadata!.os
          : 'unavailable',
      'osVersion': _version(metadata?.osVersion),
    };
  }

  String _version(String? value) =>
      RegExp(
        r'^\d+(?:\.\d+){1,4}(?:[-+][A-Za-z0-9.-]{1,30})?$',
      ).hasMatch(value ?? '')
      ? value!
      : 'unavailable';

  String _errorCategory(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    FormatException() => 'format',
    PlatformException() => 'platform',
    _ => switch (error.runtimeType.toString()) {
      'SocketException' => 'socket',
      'HandshakeException' || 'TlsException' => 'tls',
      'NoConnectionException' || 'ConnectionException' => 'mqtt',
      _ => 'other',
    },
  };

  void _reportFailure() {
    _failed = true;
    debugPrint('Diagnostic log storage or initialization failed.');
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  static Future<DiagnosticMetadata> _loadMetadata() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return DiagnosticMetadata(
      version: info.version,
      build: info.buildNumber,
      os: diagnosticOperatingSystem,
      osVersion: diagnosticSystemVersion,
    );
  }
}

class _LogSegment {
  _LogSegment(this.sequence, this.text) : bytes = utf8.encode(text).length;

  final int sequence;
  String text;
  int bytes;

  int get index => sequence % DiagnosticLogStore.segmentCount;
  String get encoded =>
      jsonEncode(<String, Object>{'sequence': sequence, 'text': text});
}
