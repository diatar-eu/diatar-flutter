import 'dart:async';
import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';

typedef SenderErrorCallback = void Function(String code, Map<String, String> params);

class TcpSenderService {
  TcpSenderService({required this.onStatusChanged, required this.onError});

  ValueChanged<bool> onStatusChanged;
  SenderErrorCallback onError;

  ServerSocket? _server;
  final Set<Socket> _clients = <Socket>{};
  int _port = -1;
  Timer? _idleTimer;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  Uint8List? _cachedState;
  Uint8List? _cachedText;
  Uint8List? _cachedBlank;
  Uint8List? _cachedPic;
  Uint8List? _cachedScrSize;

  bool get running => _server != null;
  bool get hasClients => _clients.isNotEmpty;

  Future<void> start(int port) async {
    await stop();
    _port = port;
    if (_port <= 0) {
      onStatusChanged(false);
      return;
    }

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port, shared: true);
      _server!.listen(
        _onClient,
        onError: (Object e) => onError('senderTcpError', <String, String>{'error': '$e'}),
        onDone: () => onStatusChanged(_clients.isNotEmpty),
      );
      _startIdleKeepAlive();
      onStatusChanged(false);
    } catch (e) {
      onError('senderOpenPortFailed', <String, String>{
        'port': '$_port',
        'error': '$e',
      });
      onStatusChanged(false);
    }
  }

  Future<void> restart(int port) async {
    await start(port);
  }

  Future<void> stop() async {
    for (final Socket socket in _clients) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _clients.clear();
    _idleTimer?.cancel();
    _idleTimer = null;
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    onStatusChanged(false);
  }

  void _onClient(Socket socket) {
    _clients.add(socket);
    onStatusChanged(true);
    unawaited(_replayCache(socket));
    final ProjectionPacketParser parser = ProjectionPacketParser();
    socket.listen(
      (List<int> chunk) {
        final List<ProjectionPacket> packets = parser.addChunk(Uint8List.fromList(chunk));
        for (final ProjectionPacket packet in packets) {
          if (packet.type == RecTypes.askSize && _cachedScrSize != null) {
            unawaited(_sendToSocket(socket, RecTypes.scrSize, _cachedScrSize));
          }
        }
      },
      onError: (_) {
        _clients.remove(socket);
        onStatusChanged(_clients.isNotEmpty);
      },
    );
    socket.done.whenComplete(() {
      _clients.remove(socket);
      onStatusChanged(_clients.isNotEmpty);
    });
  }

  Future<void> sendState(ProjectionGlobals globals, {required bool showing, required int wordToHighlight}) async {
    _cachedState = encodeStateRecord(
      globals,
      projecting: showing,
      wordToHighlight: wordToHighlight,
    );
    await _sendPacket(
      RecTypes.state,
      _cachedState!,
    );
  }

  Future<void> sendText({required String title, required List<String> lines, required int wordToHighlight}) async {
    _cachedText = encodeTextRecord(title: title, lines: lines);
    await _sendPacket(
      RecTypes.text,
      _cachedText!,
    );
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
    _cachedScrSize = encodeScreenSizeRecord(width: width, height: height, korusMode: false);
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
    final List<Socket> dead = <Socket>[];
    for (final Socket socket in _clients) {
      try {
        socket.add(packet);
        await socket.flush();
        _lastSentAt = DateTime.now();
      } catch (_) {
        dead.add(socket);
      }
    }
    for (final Socket socket in dead) {
      _clients.remove(socket);
    }
    onStatusChanged(_clients.isNotEmpty);
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
}
