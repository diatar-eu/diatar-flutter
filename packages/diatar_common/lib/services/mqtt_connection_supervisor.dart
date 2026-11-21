import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'diagnostic_log.dart';

class MqttConnectionSupervisor {
  MqttConnectionSupervisor({
    required this.createClient,
    required this.onReady,
    required this.onConnection,
    required this.onConnectionFailed,
    required this.onError,
    required this.role,
    this.onMessages,
    DiagnosticLog? diagnosticLog,
  }) : _diagnostics = diagnosticLog ?? DiagnosticLog.instance;

  final MqttClient Function() createClient;
  final FutureOr<void> Function(MqttClient client) onReady;
  final ValueChanged<bool> onConnection;
  final VoidCallback onConnectionFailed;
  final ValueChanged<Object> onError;
  final DiagnosticRole role;
  final DiagnosticLog _diagnostics;
  final void Function(List<MqttReceivedMessage<MqttMessage>> messages)?
  onMessages;

  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _heartbeatTimeout = Duration(minutes: 1);

  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _sub;
  Timer? _timer;
  int _generation = 0;
  final Stopwatch _heartbeatAge = Stopwatch();
  final Stopwatch _heartbeatSample = Stopwatch();

  Future<void> start() async {
    _log(DiagnosticEvent.mqttStarting);
    final int generation = ++_generation;
    await _stopClient();
    if (generation == _generation) {
      await _connect(generation);
    }
  }

  Future<void> stop() async {
    _log(DiagnosticEvent.mqttStopped);
    ++_generation;
    await _stopClient();
  }

  bool _isCurrent(MqttClient client, int generation) =>
      generation == _generation && identical(client, _client);

  Future<void> _connect(int generation) async {
    final Stopwatch attempt = Stopwatch()..start();
    _heartbeatAge
      ..reset()
      ..start();
    _heartbeatSample.reset();
    _log(DiagnosticEvent.mqttConnecting);
    final MqttClient client = createClient();
    _client = client;
    client
      ..keepAlivePeriod = 15
      ..disconnectOnNoResponsePeriod = 30
      // Own retries so a broken reconnect loop cannot keep an old socket alive.
      ..autoReconnect = false
      ..pongCallback = () {
        if (_isCurrent(client, generation) &&
            client.connectionStatus?.state == MqttConnectionState.connected) {
          _heartbeatAge
            ..reset()
            ..start();
          if (!_diagnostics.enabled) {
            _heartbeatSample.reset();
          } else if (!_heartbeatSample.isRunning ||
              _heartbeatSample.elapsed >= const Duration(minutes: 5)) {
            _log(DiagnosticEvent.mqttHeartbeat);
            _heartbeatSample
              ..reset()
              ..start();
          }
          _scheduleRestart(generation, _heartbeatTimeout);
        }
      }
      ..onDisconnected = () {
        if (_isCurrent(client, generation)) {
          _log(
            DiagnosticEvent.mqttDisconnected,
            elapsedMs: _heartbeatAge.elapsedMilliseconds,
          );
          onConnection(false);
          _scheduleRestart(generation, _retryDelay);
        }
      };

    _scheduleRestart(generation, _heartbeatTimeout);
    try {
      final MqttClientConnectionStatus? status = await client
          .connect()
          .whenComplete(() {
            // A timed-out socket open may still complete after replacement.
            if (!_isCurrent(client, generation)) {
              _disconnectClient(client);
            }
          })
          .timeout(_connectTimeout);
      if (!_isCurrent(client, generation)) {
        return;
      }
      if (status?.state != MqttConnectionState.connected) {
        _log(
          DiagnosticEvent.mqttConnectRejected,
          code: status?.returnCode?.index,
          elapsedMs: attempt.elapsedMilliseconds,
        );
        onConnectionFailed();
        await _retry(generation);
        return;
      }
      _sub = client.updates?.listen(
        (messages) {
          if (_isCurrent(client, generation)) {
            onMessages?.call(messages);
          }
        },
        onError: (Object error) {
          if (_isCurrent(client, generation)) {
            _log(DiagnosticEvent.mqttStreamFailed, error: error);
            onError(error);
            unawaited(_retry(generation));
          }
        },
      );
      await onReady(client);
      if (_isCurrent(client, generation)) {
        if (role == DiagnosticRole.mqttReceiver) {
          _log(DiagnosticEvent.mqttSubscribed);
        }
        _log(
          DiagnosticEvent.mqttConnected,
          elapsedMs: attempt.elapsedMilliseconds,
        );
        _scheduleRestart(generation, _heartbeatTimeout);
        onConnection(true);
      }
    } catch (e) {
      if (_isCurrent(client, generation)) {
        _log(
          DiagnosticEvent.mqttConnectFailed,
          elapsedMs: attempt.elapsedMilliseconds,
          error: e,
        );
        onError(e);
        await _retry(generation);
      }
    }
  }

  void _scheduleRestart(int generation, Duration delay) {
    if (delay == _retryDelay) {
      _log(DiagnosticEvent.mqttRetryScheduled, delaySeconds: delay.inSeconds);
    }
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (generation == _generation) {
        _log(
          delay == _heartbeatTimeout
              ? DiagnosticEvent.mqttHeartbeatTimeout
              : DiagnosticEvent.mqttRestarting,
          elapsedMs: _heartbeatAge.elapsedMilliseconds,
        );
        debugPrint('MQTT: rebuilding connection after ${delay.inSeconds}s.');
        unawaited(_restart(generation));
      }
    });
  }

  Future<void> _restart(int generation) async {
    await _stopClient();
    if (generation == _generation) {
      await _connect(generation);
    }
  }

  Future<void> _retry(int generation) async {
    await _stopClient();
    if (generation == _generation) {
      _scheduleRestart(generation, _retryDelay);
    }
  }

  Future<void> _stopClient() async {
    _timer?.cancel();
    _timer = null;
    final MqttClient? client = _client;
    final StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? sub =
        _sub;
    _client = null;
    _sub = null;
    final Future<void>? cancelled = sub?.cancel();
    if (client != null) {
      _disconnectClient(client);
    }
    onConnection(false);
    await cancelled;
  }

  void _disconnectClient(MqttClient client) {
    try {
      client.disconnect();
    } catch (e) {
      _log(DiagnosticEvent.mqttCleanupFailed, error: e);
      debugPrint('MQTT cleanup failed: $e');
    }
  }

  void _log(
    DiagnosticEvent event, {
    int? code,
    int? elapsedMs,
    int? delaySeconds,
    Object? error,
  }) => _diagnostics.record(
    event,
    role: role,
    code: code,
    elapsedMs: elapsedMs,
    delaySeconds: delaySeconds,
    error: error,
  );
}
