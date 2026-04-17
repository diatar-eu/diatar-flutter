import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:diatar_common/diatar_common.dart';

typedef StateCallback = void Function(RecStateRecord record);
typedef TextCallback = void Function(RecTextRecord record);
typedef ImageCallback = void Function(RecImageRecord record);
typedef AskSizeCallback = void Function();
typedef ErrorCallback = void Function(String message);
typedef ConnectionCallback = void Function(bool connected);

class TcpServerService {
  TcpServerService({
    required this.onState,
    required this.onText,
    required this.onPic,
    required this.onBlank,
    required this.onAskSize,
    required this.onError,
    required this.onConnection,
  });

  final StateCallback onState;
  final TextCallback onText;
  final ImageCallback onPic;
  final ImageCallback onBlank;
  final AskSizeCallback onAskSize;
  final ErrorCallback onError;
  final ConnectionCallback onConnection;

  ServerSocket? _server;
  Socket? _client;
  StreamSubscription<List<int>>? _clientSub;
  final ProjectionPacketParser _parser = ProjectionPacketParser();

  int _port = -1;

  bool get running => _server != null;

  Future<void> start(int port) async {
    await stop(emitConnection: false);
    _port = port;
    if (_port <= 0) {
      return;
    }
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port, shared: true);
      _server!.listen(_onClient, onError: (Object e) {
        onError('tcpServerError:$e');
      });
    } catch (e) {
      onError('tcpServerOpenPortFailed:$_port:$e');
    }
  }

  Future<void> restart(int port) async {
    await start(port);
  }

  Future<void> stop({bool emitConnection = true}) async {
    await _clientSub?.cancel();
    _clientSub = null;
    await _client?.close();
    _client = null;
    await _server?.close();
    _server = null;
    _parser.clear();
    if (emitConnection) {
      onConnection(false);
    }
  }

  Future<void> sendScreenSize({required int width, required int height}) async {
    final Uint8List body = encodeScreenSizeRecord(width: width, height: height, korusMode: false);
    await _sendPacket(RecTypes.scrSize, body);
  }

  void _onClient(Socket socket) {
    _clientSub?.cancel();
    _client?.destroy();
    _client = socket;
    onConnection(true);
    _clientSub = socket.listen(
      _onData,
      onError: (Object e) {
        onError('tcpServerClientError:$e');
        _disconnectClient();
      },
      onDone: _disconnectClient,
      cancelOnError: true,
    );
  }

  void _disconnectClient() {
    _clientSub?.cancel();
    _clientSub = null;
    _client?.destroy();
    _client = null;
    _parser.clear();
    onConnection(false);
  }

  void _onData(List<int> data) {
    final List<ProjectionPacket> packets = _parser.addChunk(data);
    for (final ProjectionPacket packet in packets) {
      _dispatch(packet.type, packet.body);
    }
  }

  void _dispatch(int type, Uint8List body) {
    try {
      switch (type) {
        case RecTypes.state:
          onState(RecStateRecord.fromBytes(body));
          break;
        case RecTypes.text:
          onText(RecTextRecord.fromBytes(body));
          break;
        case RecTypes.pic:
          onPic(RecImageRecord.fromBytes(body));
          break;
        case RecTypes.blank:
          onBlank(RecImageRecord.fromBytes(body));
          break;
        case RecTypes.askSize:
          onAskSize();
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
    final Socket? client = _client;
    if (client == null) {
      return;
    }
    final Uint8List packet = encodeProjectionPacket(type, body);
    try {
      client.add(packet);
      await client.flush();
    } catch (e) {
      onError('tcpServerSendError:$e');
      _disconnectClient();
    }
  }
}
