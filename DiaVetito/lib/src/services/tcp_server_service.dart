import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/records.dart';

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
  final List<int> _buffer = <int>[];

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
        onError('TCP hiba: $e');
      });
    } catch (e) {
      onError('Nem sikerult portot nyitni ($_port): $e');
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
    _buffer.clear();
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
        onError('Kliens hiba: $e');
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
    _buffer.clear();
    onConnection(false);
  }

  void _onData(List<int> data) {
    _buffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      final int ix = _findMagicIndex(_buffer);
      if (ix < 0) {
        // Keep only the tail so split magic can still be matched after next read.
        if (_buffer.length > 3) {
          _buffer.removeRange(0, _buffer.length - 3);
        }
        return;
      }
      if (ix > 0) {
        _buffer.removeRange(0, ix);
      }
      if (_buffer.length < 12) {
        return;
      }
      final int type = _buffer[4];
      final int size = _readIntLE(_buffer, 8);
      if (size < 0 || size > 100 * 1024 * 1024) {
        _buffer.removeAt(0);
        continue;
      }
      final int total = 12 + size;
      if (_buffer.length < total) {
        return;
      }
      final Uint8List body = Uint8List.fromList(_buffer.sublist(12, total));
      _buffer.removeRange(0, total);
      _dispatch(type, body);
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
      onError('Csomag feldolgozasi hiba: $e');
    }
  }

  Future<void> _sendPacket(int type, Uint8List body) async {
    final Socket? client = _client;
    if (client == null) {
      return;
    }
    final Uint8List header = Uint8List(12);
    header[0] = 0xDA;
    header[1] = 0x69;
    header[2] = 0x70;
    header[3] = 0x4A;
    header[4] = type;
    final ByteData bd = header.buffer.asByteData();
    bd.setInt32(8, body.length, Endian.little);
    try {
      client.add(header);
      if (body.isNotEmpty) {
        client.add(body);
      }
      await client.flush();
    } catch (e) {
      onError('Kuldesi hiba: $e');
      _disconnectClient();
    }
  }

  int _findMagicIndex(List<int> data) {
    for (int i = 0; i <= data.length - 4; i++) {
      if (data[i] == 0xDA && data[i + 1] == 0x69 && data[i + 2] == 0x70 && data[i + 3] == 0x4A) {
        return i;
      }
    }
    return -1;
  }

  int _readIntLE(List<int> data, int ofs) {
    return (data[ofs]) |
        (data[ofs + 1] << 8) |
        (data[ofs + 2] << 16) |
        (data[ofs + 3] << 24);
  }
}
