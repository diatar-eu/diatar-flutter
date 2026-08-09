import 'dart:io';
import 'dart:typed_data';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/tcp_sender_service.dart';

void main() {
  test('sendBlank transmits the full image payload over TCP', () async {
    final _TcpHarness harness = _TcpHarness();
    await harness.start();
    final TcpSenderService sender = _createSender();

    try {
      final Future<Socket> clientFuture = harness.nextClient();
      await sender.start(<String>[harness.target]);
      await clientFuture;

      final Uint8List imageBytes = Uint8List.fromList(
        List<int>.generate(4 * 1024 * 1024, (int i) => i & 0xFF),
      );
      await sender.sendBlank(imageBytes, ext: 'jpg');
      await sender.sendState(
        const ProjectionGlobals(),
        showing: true,
        wordToHighlight: 0,
      );

      await _waitFor(() => harness.parsedPackets.length >= 2);
      expect(harness.parsedPackets.length, 2);
      expect(harness.parsedPackets[0].type, RecTypes.blank);
      expect(
        harness.parsedPackets[0].body,
        encodeImageRecord(bytes: imageBytes, ext: 'jpg'),
      );
      expect(harness.parsedPackets[1].type, RecTypes.state);
    } finally {
      await sender.stop();
      await harness.dispose();
    }
  });

  test('start replays the cached blank to a newly connected receiver', () async {
    final _TcpHarness harness = _TcpHarness();
    await harness.start();
    final TcpSenderService sender = _createSender();

    try {
      final Future<Socket> clientFuture = harness.nextClient();
      await sender.start(<String>[harness.target]);
      final Socket client = await clientFuture;

      final Uint8List imageBytes = Uint8List.fromList(
        List<int>.generate(2 * 1024 * 1024, (int i) => i & 0xFF),
      );
      await sender.sendBlank(imageBytes, ext: 'png');
      await _waitFor(
        () => harness.parsedPackets
            .any((ProjectionPacket p) => p.type == RecTypes.blank),
      );

      // Drop the connection; the sender reconnects and replays its caches.
      final Future<Socket> reconnectedFuture = harness.nextClient();
      client.destroy();
      await reconnectedFuture;

      await _waitFor(() {
        final List<ProjectionPacket> replayed = harness.replayPackets();
        return replayed.any(
          (ProjectionPacket p) =>
              p.type == RecTypes.blank &&
              p.body.length == 8 + imageBytes.length,
        );
      });
    } finally {
      await sender.stop();
      await harness.dispose();
    }
  });
}

TcpSenderService _createSender() {
  return TcpSenderService(
    onStatusChanged: (_) {},
    onError: (String code, Map<String, String> params) {
      fail('unexpected sender error: $code $params');
    },
  );
}

class _TcpHarness {
  final List<Socket> _clients = <Socket>[];
  final List<Uint8List> _rawChunks = <Uint8List>[];
  final ProjectionPacketParser _parser = ProjectionPacketParser();
  final List<ProjectionPacket> _packets = <ProjectionPacket>[];
  ServerSocket? _server;

  late final String target;

  Future<void> start() async {
    final ServerSocket server = await ServerSocket.bind('127.0.0.1', 0);
    _server = server;
    target = '127.0.0.1:${server.port}';
    server.listen(_onClient);
  }

  void _onClient(Socket client) {
    _clients.add(client);
    client.listen((Uint8List data) {
      _rawChunks.add(data);
      _packets.addAll(_parser.addChunk(data));
    });
  }

  List<ProjectionPacket> get parsedPackets => _packets;

  /// Returns the next accepted client, parsed from all bytes received so far.
  List<ProjectionPacket> replayPackets() {
    final List<int> all = <int>[];
    for (final Uint8List chunk in _rawChunks) {
      all.addAll(chunk);
    }
    return ProjectionPacketParser().addChunk(all);
  }

  Future<Socket> nextClient() async {
    await _waitFor(() => _clients.isNotEmpty);
    return _clients.removeAt(0);
  }

  Future<void> dispose() async {
    for (final Socket client in _clients) {
      try {
        client.destroy();
      } catch (_) {}
    }
    await _server?.close();
  }
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
