import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:diatar_app/src/services/tcp_server_service.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'processes a slide sent after an image only after image processing',
    () async {
      final ServerSocket reservedPort = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final int port = reservedPort.port;
      await reservedPort.close();

      final Completer<void> imageStarted = Completer<void>();
      final Completer<void> allowImageCompletion = Completer<void>();
      final Completer<void> textReceived = Completer<void>();
      final List<String> processed = <String>[];
      final TcpServerService server = TcpServerService(
        onState: (_) {},
        onText: (RecTextRecord record) {
          processed.add('text:${record.title}');
          if (!textReceived.isCompleted) {
            textReceived.complete();
          }
        },
        onPic: (_) async {
          processed.add('image');
          if (!imageStarted.isCompleted) {
            imageStarted.complete();
          }
          await allowImageCompletion.future;
        },
        onBlank: (_) {},
        onAskSize: () {},
        onError: fail,
        onConnection: (_) {},
      );

      await server.start(port);
      final Socket client = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
      );
      addTearDown(() async {
        await client.close();
        await server.stop();
      });

      final Uint8List imagePacket = encodeProjectionPacket(
        RecTypes.pic,
        encodeImageRecord(bytes: Uint8List.fromList(<int>[1]), ext: 'png'),
      );
      final Uint8List textPacket = encodeProjectionPacket(
        RecTypes.text,
        encodeTextRecord(title: 'Current slide', lines: <String>['Text']),
      );
      client.add(Uint8List.fromList(<int>[...imagePacket, ...textPacket]));
      await client.flush();

      await imageStarted.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processed, <String>['image']);

      allowImageCompletion.complete();
      await textReceived.future.timeout(const Duration(seconds: 3));
      expect(processed, <String>['image', 'text:Current slide']);
    },
  );
}
