import 'dart:async';
import 'dart:io';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';

typedef StateCallback = FutureOr<void> Function(RecStateRecord record);
typedef TextCallback = FutureOr<void> Function(RecTextRecord record);
typedef ImageCallback = FutureOr<void> Function(RecImageRecord record);
typedef AskSizeCallback = FutureOr<void> Function();
typedef CameraCallback = FutureOr<void> Function(CameraSignal signal);
typedef ErrorCallback = void Function(String message);
typedef ConnectionCallback = void Function(bool connected);

class TcpServerService {
  TcpServerService({
    required this.onState,
    required this.onText,
    required this.onPic,
    required this.onBlank,
    required this.onAskSize,
    required this.onCamera,
    required this.onError,
    required this.onConnection,
  });

  final StateCallback onState;
  final TextCallback onText;
  final ImageCallback onPic;
  final ImageCallback onBlank;
  final AskSizeCallback onAskSize;
  final CameraCallback onCamera;
  final ErrorCallback onError;
  final ConnectionCallback onConnection;

  ServerSocket? _server;
  final Map<Socket, StreamSubscription<List<int>>> _clients = {};
  final ProjectionPacketParser _parser = ProjectionPacketParser();
  Future<void> _dispatchQueue = Future<void>.value();
  Future<void> _sendQueue = Future<void>.value();

  int _port = -1;

  bool get running => _server != null;

  Future<void> start(int port) async {
    await stop(emitConnection: false);
    _port = port;
    if (_port <= 0) {
      return;
    }
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(
        _onClient,
        onError: (Object e) {
          onError('tcpServerError:$e');
        },
      );
    } catch (e) {
      onError('tcpServerOpenPortFailed:$_port:$e');
    }
  }

  Future<void> restart(int port) async {
    await start(port);
  }

  Future<void> stop({bool emitConnection = true}) async {
    debugPrint('CAM srv stop called');
    for (final MapEntry<Socket, StreamSubscription<List<int>>> entry
        in _clients.entries.toList()) {
      await entry.value.cancel();
      await entry.key.close().catchError((_) {});
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    _parser.clear();
    if (emitConnection) {
      onConnection(false);
    }
  }

  Future<void> sendScreenSize({required int width, required int height}) async {
    final Uint8List body = encodeScreenSizeRecord(
      width: width,
      height: height,
      korusMode: false,
    );
    await _sendPacket(RecTypes.scrSize, body);
  }

  Future<void> sendCameraSignal(CameraSignal signal) async {
    await _sendPacket(RecTypes.camera, encodeCameraSignal(signal));
  }

  void _onClient(Socket socket) {
    debugPrint('CAM srv client connect ${socket.remoteAddress.address}');
    if (_clients.isEmpty) {
      onConnection(true);
    }
    _clients[socket] = socket.listen(
      _onData,
      onError: (Object e) {
        debugPrint('CAM srv client socket error: $e');
        onError('tcpServerClientError:$e');
        _removeClient(socket, 'socketError');
      },
      onDone: () {
        debugPrint('CAM srv client socket done');
        _removeClient(socket, 'clientClosed');
      },
      cancelOnError: true,
    );
  }

  void _removeClient(Socket socket, [String? reason]) {
    debugPrint('CAM srv disconnect reason=$reason clients=${_clients.length}');
    final StreamSubscription<List<int>>? sub = _clients.remove(socket);
    if (sub != null) {
      unawaited(sub.cancel().catchError((_) {}));
      unawaited(socket.close().catchError((_) {}));
    }
    if (_clients.isEmpty) {
      _parser.clear();
      onConnection(false);
    }
  }

  void _onData(List<int> data) {
    final List<ProjectionPacket> packets = _parser.addChunk(data);
    for (final ProjectionPacket packet in packets) {
      debugPrint('CAM srv rx type=${packet.type} len=${packet.body.length}');
      _dispatchQueue = _dispatchQueue.then(
        (_) => _dispatch(packet.type, packet.body),
      );
    }
  }

  Future<void> _dispatch(int type, Uint8List body) async {
    try {
      switch (type) {
        case RecTypes.state:
          await onState(RecStateRecord.fromBytes(body));
          break;
        case RecTypes.text:
          await onText(RecTextRecord.fromBytes(body));
          break;
        case RecTypes.pic:
          await onPic(RecImageRecord.fromBytes(body));
          break;
        case RecTypes.blank:
          await onBlank(RecImageRecord.fromBytes(body));
          break;
        case RecTypes.askSize:
          await onAskSize();
          break;
        case RecTypes.camera:
          onCamera(decodeCameraSignal(body));
          break;
        case RecTypes.idle:
          // No-op.
          break;
        default:
          break;
      }
    } catch (e) {
      onError('tcpServerPacketParseError:$e');
    }
  }

  Future<void> _sendPacket(int type, Uint8List body) async {
    final Future<void> previous = _sendQueue;
    final Completer<void> current = Completer<void>();
    _sendQueue = current.future;
    await previous;
    try {
      await _doSendPacket(type, body);
    } finally {
      current.complete();
    }
  }

  Future<void> _doSendPacket(int type, Uint8List body) async {
    if (_clients.isEmpty) {
      debugPrint('CAM srv tx type=$type no client');
      return;
    }
    final Uint8List packet = encodeProjectionPacket(type, body);
    debugPrint('CAM srv tx type=$type len=${body.length} clients=${_clients.length}');
    final List<Socket> dead = <Socket>[];
    for (final MapEntry<Socket, StreamSubscription<List<int>>> entry
        in _clients.entries.toList()) {
      final Socket socket = entry.key;
      try {
        socket.add(packet);
        await socket.flush();
      } catch (e) {
        debugPrint('CAM srv tx failed type=$type: $e');
        onError('tcpServerSendError:$e');
        dead.add(socket);
      }
    }
    for (final Socket socket in dead) {
      _removeClient(socket, 'sendError');
    }
  }
}
