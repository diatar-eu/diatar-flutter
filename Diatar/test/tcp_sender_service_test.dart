import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:diatar_app/src/services/tcp_sender_service.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends a complete large image packet through a RawSocket', () async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final Completer<void> connected = Completer<void>();
    final Completer<ProjectionPacket> received = Completer<ProjectionPacket>();
    final ProjectionPacketParser parser = ProjectionPacketParser();
    final TcpSenderService sender = TcpSenderService(
      onStatusChanged: (bool isConnected) {
        if (isConnected && !connected.isCompleted) {
          connected.complete();
        }
      },
      onError: (_, __) {},
    );

    server.listen((Socket client) {
      client.listen((List<int> chunk) {
        for (final ProjectionPacket packet in parser.addChunk(chunk)) {
          if (packet.type == RecTypes.pic && !received.isCompleted) {
            received.complete(packet);
          }
        }
      });
    });

    addTearDown(() async {
      await sender.stop();
      await server.close();
    });

    sender.start(<String>['127.0.0.1:${server.port}']);
    await connected.future.timeout(const Duration(seconds: 3));

    final Uint8List imageBytes = Uint8List.fromList(
      List<int>.generate(4 * 1024 * 1024, (int index) => index % 251),
    );
    expect(
      RecImageRecord.fromBytes(
        encodeImageRecord(bytes: imageBytes, ext: 'png'),
      ).imageBytes,
      imageBytes,
    );
    await sender.sendPic(imageBytes, ext: 'png');

    final ProjectionPacket packet = await received.future.timeout(
      const Duration(seconds: 10),
    );
    final RecImageRecord image = RecImageRecord.fromBytes(packet.body);
    expect(image.ext, 'png');
    expect(image.imageBytes, imageBytes);
  });
}
