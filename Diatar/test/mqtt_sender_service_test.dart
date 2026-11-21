import 'dart:typed_data';

import 'package:diatar_app/src/services/mqtt_sender_service.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/typed_buffers.dart';

void main() {
  group('MqttSenderService.close', () {
    test('clears retained MQTT messages before disconnecting', () async {
      final _TrackingMqttSender sender = _TrackingMqttSender();

      await sender.close();

      expect(sender.clearRetainedMessagesCalled, isTrue);
    });

    test(
      'can keep retained messages while reopening the same topic group',
      () async {
        final _TrackingMqttSender sender = _TrackingMqttSender();

        await sender.close(clearRetained: false);

        expect(sender.clearRetainedMessagesCalled, isFalse);
      },
    );
  });

  for (final bool imageSlide in <bool>[false, true]) {
    testWidgets('reconnect replays the latest ${imageSlide ? 'image' : 'text'} '
        'slide, state and background', (tester) async {
      final List<_FakeMqttClient> clients = <_FakeMqttClient>[];
      final List<bool> statuses = <bool>[];
      final List<String> errors = <String>[];
      final MqttSenderService sender = MqttSenderService(
        clientFactory: (host, clientId) {
          final _FakeMqttClient client = _FakeMqttClient(host, clientId);
          clients.add(client);
          return client;
        },
        onStatusChanged: statuses.add,
        onError: (code, _) => errors.add(code),
      );
      await sender.open(
        username: 'test-user',
        password: 'test-password',
        channel: '2',
      );
      await sender.sendState(
        const ProjectionGlobals(),
        showing: true,
        wordToHighlight: 0,
      );
      await sender.sendBlank(Uint8List.fromList(<int>[1, 2]), ext: 'png');
      await sender.sendText(title: 'title', lines: <String>['first']);
      if (imageSlide) {
        await sender.sendPic(Uint8List.fromList(<int>[3, 4]), ext: 'png');
      }

      final _FakeMqttClient oldClient = clients.single;
      final Map<String, List<int>> expected = Map<String, List<int>>.from(
        oldClient.payloads,
      );
      oldClient.dropConnection();
      expect(statuses.last, isFalse);
      if (!imageSlide) {
        await sender.sendText(title: 'title', lines: <String>['latest']);
        expected['Diatar/test-user/2/dia'] = <int>[
          'T'.codeUnitAt(0),
          ...encodeTextRecord(title: 'title', lines: <String>['latest']),
        ];
      }
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(clients, hasLength(2));
      expect(clients.last.payloads, expected);
      expect(statuses.last, isTrue);
      expect(errors, isEmpty);

      await sender.close(clearRetained: false);
      await tester.pump(const Duration(minutes: 2));
      expect(clients, hasLength(2));
      expect(statuses.last, isFalse);
    });
  }
}

class _TrackingMqttSender extends MqttSenderService {
  _TrackingMqttSender() : super(onStatusChanged: (_) {}, onError: (_, __) {});

  bool clearRetainedMessagesCalled = false;

  @override
  Future<void> clearRetainedMessages() async {
    clearRetainedMessagesCalled = true;
  }
}

class _FakeMqttClient extends MqttClient {
  _FakeMqttClient(super.server, super.clientIdentifier);

  final MqttClientConnectionStatus status = MqttClientConnectionStatus()
    ..state = MqttConnectionState.connected;
  final Map<String, List<int>> payloads = <String, List<int>>{};

  @override
  MqttClientConnectionStatus get connectionStatus => status;

  @override
  Future<MqttClientConnectionStatus?> connect([
    String? username,
    String? password,
  ]) async => status;

  @override
  int publishMessage(
    String topic,
    MqttQos qualityOfService,
    Uint8Buffer data, {
    bool retain = false,
  }) {
    expectSync(status.state, MqttConnectionState.connected);
    expectSync(retain, isTrue);
    payloads[topic] = data.toList();
    return payloads.length;
  }

  void dropConnection() {
    status.state = MqttConnectionState.disconnected;
    onDisconnected?.call();
  }

  @override
  void disconnect() {
    status.state = MqttConnectionState.disconnected;
    onDisconnected?.call();
  }
}
