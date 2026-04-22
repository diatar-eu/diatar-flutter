import 'dart:async';
import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';

typedef SenderErrorCallback =
    void Function(String code, Map<String, String> params);

class TcpSenderService {
  TcpSenderService({required this.onStatusChanged, required this.onError});

  ValueChanged<bool> onStatusChanged;
  SenderErrorCallback onError;

  final Map<String, Socket> _clients = <String, Socket>{};
  final Map<String, StreamSubscription<List<int>>> _subs =
      <String, StreamSubscription<List<int>>>{};
  final Map<String, DateTime> _lastConnectError = <String, DateTime>{};
  final Set<String> _targetKeys = <String>{};
  bool _running = false;
  int _session = 0;
  Timer? _idleTimer;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  Uint8List? _cachedState;
  Uint8List? _cachedText;
  Uint8List? _cachedBlank;
  Uint8List? _cachedPic;
  Uint8List? _cachedScrSize;
  bool _lastStatus = false;

  bool get running => _running;
  bool get hasClients => _clients.isNotEmpty;

  Future<void> start(List<String> targets) async {
    await stop();
    final List<_TcpTarget> parsedTargets = _parseTargets(targets);
    if (parsedTargets.isEmpty) {
      _emitStatus();
      return;
    }

    _running = true;
    _session++;
    final int session = _session;
    _targetKeys
      ..clear()
      ..addAll(parsedTargets.map((target) => target.key));
    _startIdleKeepAlive();
    _emitStatus();

    for (final _TcpTarget target in parsedTargets) {
      unawaited(_runTargetLoop(target, session));
    }
  }

  Future<void> restart(List<String> targets) async {
    await start(targets);
  }

  Future<void> stop() async {
    _running = false;
    _session++;
    _targetKeys.clear();
    _lastConnectError.clear();

    for (final StreamSubscription<List<int>> sub in _subs.values) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _subs.clear();

    for (final Socket socket in _clients.values) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _clients.clear();

    _idleTimer?.cancel();
    _idleTimer = null;
    _emitStatus(force: true);
  }

  Future<void> _runTargetLoop(_TcpTarget target, int session) async {
    while (_running &&
        session == _session &&
        _targetKeys.contains(target.key)) {
      Socket? socket;
      StreamSubscription<List<int>>? sub;
      try {
        socket = await Socket.connect(
          target.host,
          target.port,
          timeout: const Duration(seconds: 3),
        );

        _clients[target.key] = socket;
        _emitStatus();
        await _replayCache(socket);

        final ProjectionPacketParser parser = ProjectionPacketParser();
        final Completer<void> done = Completer<void>();
        sub = socket.listen(
          (List<int> chunk) {
            final List<ProjectionPacket> packets = parser.addChunk(
              Uint8List.fromList(chunk),
            );
            for (final ProjectionPacket packet in packets) {
              if (packet.type == RecTypes.askSize && _cachedScrSize != null) {
                unawaited(
                  _sendToSocket(socket!, RecTypes.scrSize, _cachedScrSize),
                );
              }
            }
          },
          onError: (Object e) {
            _reportConnectOrClientError(target, e);
            if (!done.isCompleted) {
              done.complete();
            }
          },
          onDone: () {
            if (!done.isCompleted) {
              done.complete();
            }
          },
          cancelOnError: true,
        );
        _subs[target.key] = sub;
        await done.future;
      } catch (e) {
        _reportConnectOrClientError(target, e);
      } finally {
        if (sub != null) {
          try {
            await sub.cancel();
          } catch (_) {}
        }
        _subs.remove(target.key);

        final Socket? old = _clients.remove(target.key);
        try {
          old?.destroy();
        } catch (_) {}
        _emitStatus();
      }

      if (_running && session == _session && _targetKeys.contains(target.key)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  void _reportConnectOrClientError(_TcpTarget target, Object error) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastConnectError[target.key];
    if (last != null && now.difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _lastConnectError[target.key] = now;
    onError('senderTcpError', <String, String>{
      'error': '${target.host}:${target.port} - $error',
    });
  }

  Future<void> sendState(
    ProjectionGlobals globals, {
    required bool showing,
    required int wordToHighlight,
  }) async {
    _cachedState = encodeStateRecord(
      globals,
      projecting: showing,
      wordToHighlight: wordToHighlight,
    );
    await _sendPacket(RecTypes.state, _cachedState!);
  }

  Future<void> sendText({
    required String title,
    required List<String> lines,
    required int wordToHighlight,
  }) async {
    _cachedText = encodeTextRecord(title: title, lines: lines);
    await _sendPacket(RecTypes.text, _cachedText!);
  }

  Future<void> sendBlank(Uint8List bytes, {String ext = ''}) async {
    _cachedBlank = encodeImageRecord(bytes: bytes, ext: ext);
    await _sendPacket(RecTypes.blank, _cachedBlank!);
  }

  Future<void> sendPic(Uint8List bytes, {String ext = ''}) async {
    _cachedPic = encodeImageRecord(bytes: bytes, ext: ext);
    await _sendPacket(RecTypes.pic, _cachedPic!);
  }

  Future<void> sendIdle() async {
    await _sendPacket(RecTypes.idle, Uint8List(0));
  }

  Future<void> sendScreenSize({required int width, required int height}) async {
    _cachedScrSize = encodeScreenSizeRecord(
      width: width,
      height: height,
      korusMode: false,
    );
    await _sendPacket(RecTypes.scrSize, _cachedScrSize!);
  }

  Future<void> _replayCache(Socket socket) async {
    await _sendToSocket(socket, RecTypes.scrSize, _cachedScrSize);
    await _sendToSocket(socket, RecTypes.state, _cachedState);
    await _sendToSocket(socket, RecTypes.text, _cachedText);
    await _sendToSocket(socket, RecTypes.blank, _cachedBlank);
    await _sendToSocket(socket, RecTypes.pic, _cachedPic);
  }

  Future<void> _sendPacket(int type, Uint8List body) async {
    if (_clients.isEmpty) {
      return;
    }
    final Uint8List packet = encodeProjectionPacket(type, body);
    final List<String> dead = <String>[];
    for (final MapEntry<String, Socket> entry in _clients.entries) {
      final String key = entry.key;
      final Socket socket = entry.value;
      try {
        socket.add(packet);
        await socket.flush();
        _lastSentAt = DateTime.now();
      } catch (_) {
        dead.add(key);
      }
    }
    for (final String key in dead) {
      final Socket? deadSocket = _clients.remove(key);
      try {
        deadSocket?.destroy();
      } catch (_) {}
    }
    _emitStatus();
  }

  Future<void> _sendToSocket(Socket socket, int type, Uint8List? body) async {
    if (body == null) {
      return;
    }
    try {
      socket.add(encodeProjectionPacket(type, body));
      await socket.flush();
      _lastSentAt = DateTime.now();
    } catch (_) {}
  }

  void _startIdleKeepAlive() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!running || _clients.isEmpty) {
        return;
      }
      final Duration sinceLastSend = DateTime.now().difference(_lastSentAt);
      if (sinceLastSend >= const Duration(seconds: 5)) {
        unawaited(sendIdle());
      }
    });
  }

  void _emitStatus({bool force = false}) {
    final bool connected = _clients.isNotEmpty;
    if (force || connected != _lastStatus) {
      _lastStatus = connected;
      onStatusChanged(connected);
    }
  }

  List<_TcpTarget> _parseTargets(List<String> rawTargets) {
    final List<_TcpTarget> out = <_TcpTarget>[];
    final Set<String> seen = <String>{};
    for (final String raw in rawTargets) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int split = trimmed.lastIndexOf(':');
      if (split <= 0 || split >= trimmed.length - 1) {
        continue;
      }
      final String host = trimmed.substring(0, split).trim();
      final int? port = int.tryParse(trimmed.substring(split + 1).trim());
      if (host.isEmpty || port == null || port < 0 || port > 65535) {
        continue;
      }
      final _TcpTarget target = _TcpTarget(host: host, port: port);
      if (seen.add(target.key)) {
        out.add(target);
      }
    }
    return out;
  }
}

class _TcpTarget {
  const _TcpTarget({required this.host, required this.port});

  final String host;
  final int port;

  String get key => '$host:$port';
}
