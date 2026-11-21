import 'dart:async';

import 'package:diatar_common/services/mqtt_service.dart';
import 'package:diatar_common/services/diagnostic_log.dart';
import 'package:diatar_common/services/mqtt_connection_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('diagnostics describe recovery without raw connection errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DiagnosticLog log = DiagnosticLog(
      metadataLoader: () async => const DiagnosticMetadata(
        version: '12.0.0',
        build: '158',
        os: 'ios',
        osVersion: '18.2',
      ),
    );
    await log.initialize(DiagnosticApp.receiver);
    await log.setEnabled(true);
    final List<_FakeMqttClient> clients = <_FakeMqttClient>[];
    final MqttConnectionSupervisor connection = MqttConnectionSupervisor(
      role: DiagnosticRole.mqttReceiver,
      diagnosticLog: log,
      createClient: () {
        final _FakeMqttClient client = _FakeMqttClient('unused', 'test');
        if (clients.isEmpty) {
          client.connectError = TimeoutException(
            'private-user private-password secret-topic projected-text',
          );
        }
        clients.add(client);
        return client;
      },
      onReady: (_) {},
      onConnection: (_) {},
      onConnectionFailed: () {},
      onError: (_) {},
    );
    await connection.start();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    clients.last.pongCallback!();
    clients.last.pongCallback!();
    final String text = log.exportText();
    expect(text, contains('"event":"mqttConnectFailed"'));
    expect(text, contains('"error":"timeout"'));
    expect(text, contains('"event":"mqttRetryScheduled"'));
    expect(text, contains('"event":"mqttSubscribed"'));
    expect(text, contains('"event":"mqttConnected"'));
    expect('"event":"mqttHeartbeat"'.allMatches(text), hasLength(1));
    for (final String privateValue in <String>[
      'private-user',
      'private-password',
      'secret-topic',
      'projected-text',
    ]) {
      expect(text, isNot(contains(privateValue)));
    }
    await connection.stop();
    await log.flush();
    log.dispose();
  });

  late MqttService receiver;
  late List<_FakeMqttClient> clients;
  late List<bool> connections;
  late List<String> errors;
  late List<String> receivedTopics;
  void Function(_FakeMqttClient client)? configureClient;

  setUp(() {
    clients = <_FakeMqttClient>[];
    connections = <bool>[];
    errors = <String>[];
    receivedTopics = <String>[];
    configureClient = null;
    receiver = MqttService(
      clientFactory: (host, clientId) {
        final _FakeMqttClient client = _FakeMqttClient(host, clientId);
        configureClient?.call(client);
        clients.add(client);
        return client;
      },
      onConnection: connections.add,
      onError: errors.add,
      onState: (_) {},
      onText: (_) => receivedTopics.add('dia'),
      onPic: (_) {},
      onBlank: (_) {},
      onUsers: (_) {},
    );
  });

  testWidgets('replaces a silent connection and restores its subscription', (
    tester,
  ) async {
    await receiver.openReceiver(username: 'test-user', channel: '2');
    final _FakeMqttClient oldClient = clients.single;
    expect(oldClient.topics, <String>['Diatar/test-user/2/#']);

    await tester.pump(const Duration(seconds: 59));
    expect(clients, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(clients, hasLength(2));
    expect(oldClient.disconnectCount, 1);
    expect(oldClient.messages.hasListener, isFalse);
    expect(clients.last.topics, oldClient.topics);
    expect(connections.last, isTrue);
    clients.last.messages.add(<MqttReceivedMessage<MqttMessage>>[
      MqttReceivedMessage<MqttMessage>(
        'Diatar/test-user/2/dia',
        MqttPublishMessage(),
      ),
    ]);
    await tester.pump();
    expect(receivedTopics, <String>['dia']);
    await receiver.dispose();
  });

  testWidgets('broker pongs keep an idle projection connected', (tester) async {
    await receiver.openReceiver(username: 'test-user', channel: '1');
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 15));
      clients.single.pongCallback!();
    }

    expect(clients, hasLength(1));
    expect(connections.last, isTrue);
    expect(errors, isEmpty);
    await receiver.dispose();
  });

  testWidgets('disconnect retries with a fresh client after five seconds', (
    tester,
  ) async {
    await receiver.openReceiver(username: 'test-user', channel: '1');
    clients.single.dropConnection();
    expect(connections.last, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(clients, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(clients, hasLength(2));
    expect(connections.last, isTrue);
    await receiver.dispose();
  });

  testWidgets('failed initial connections keep retrying and can recover', (
    tester,
  ) async {
    configureClient = (client) => client.connectError = StateError('offline');
    await receiver.openReceiver(username: 'test-user', channel: '1');
    expect(errors, hasLength(1));
    expect(connections.last, isFalse);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(errors, hasLength(2));
    configureClient = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(clients, hasLength(3));
    expect(connections.last, isTrue);
    await receiver.dispose();
  });

  testWidgets('rejected connections also retry', (tester) async {
    configureClient = (client) =>
        client.status.state = MqttConnectionState.disconnected;
    await receiver.openReceiver(username: 'test-user', channel: '1');
    expect(errors, hasLength(1));
    configureClient = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(clients, hasLength(2));
    expect(connections.last, isTrue);
    await receiver.dispose();
  });

  testWidgets('times out a hung connect and discards its late completion', (
    tester,
  ) async {
    final Completer<void> pending = Completer<void>();
    configureClient = (client) => client.pendingConnect = pending.future;
    final Future<void> opening = receiver.openReceiver(
      username: 'test-user',
      channel: '1',
    );
    await tester.pump();
    final _FakeMqttClient oldClient = clients.single;
    await tester.pump(const Duration(seconds: 30));
    await opening;
    expect(errors.single, contains('TimeoutException'));
    configureClient = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(clients, hasLength(2));

    final int notificationCount = connections.length;
    pending.complete();
    await tester.pump();
    oldClient.onDisconnected!();
    oldClient.pongCallback!();
    expect(oldClient.disconnectCount, 2);
    expect(oldClient.topics, isEmpty);
    expect(connections, hasLength(notificationCount));
    expect(connections.last, isTrue);
    await receiver.dispose();
  });

  testWidgets('changing settings ignores the previous pending open', (
    tester,
  ) async {
    final Completer<void> pending = Completer<void>();
    configureClient = (client) => client.pendingConnect = pending.future;
    final Future<void> oldOpen = receiver.openReceiver(
      username: 'old-user',
      channel: '1',
    );
    await tester.pump();
    final _FakeMqttClient oldClient = clients.single;
    configureClient = null;
    await receiver.openReceiver(username: 'new-user', channel: '3');
    pending.complete();
    await oldOpen;

    expect(oldClient.topics, isEmpty);
    expect(clients.last.topics, <String>['Diatar/new-user/3/#']);
    expect(connections.last, isTrue);
    await receiver.dispose();
  });

  testWidgets(
    'late connect errors after dispose still clean up the old client',
    (tester) async {
      final Completer<void> pending = Completer<void>();
      configureClient = (client) => client.pendingConnect = pending.future;
      final Future<void> opening = receiver.openReceiver(
        username: 'test-user',
        channel: '1',
      );
      await tester.pump();
      await receiver.dispose();
      pending.completeError(StateError('late socket failure'));
      await opening;

      expect(clients.single.disconnectCount, 2);
      expect(errors, isEmpty);
      expect(connections.last, isFalse);
      await tester.pump(const Duration(minutes: 2));
      expect(clients, hasLength(1));
    },
  );

  testWidgets('close and dispose cancel retries, including pending connects', (
    tester,
  ) async {
    await receiver.openReceiver(username: 'test-user', channel: '1');
    clients.single.dropConnection();
    await receiver.closeReceiver();
    await tester.pump(const Duration(minutes: 2));
    expect(clients, hasLength(1));

    final Completer<void> pending = Completer<void>();
    configureClient = (client) => client.pendingConnect = pending.future;
    final Future<void> opening = receiver.openReceiver(
      username: 'test-user',
      channel: '1',
    );
    await tester.pump();
    await receiver.dispose();
    pending.complete();
    await opening;
    await tester.pump(const Duration(minutes: 2));
    expect(clients, hasLength(2));
    expect(clients.last.topics, isEmpty);
    expect(connections.last, isFalse);
  });
}

class _FakeMqttClient extends MqttClient {
  _FakeMqttClient(super.server, super.clientIdentifier);

  final MqttClientConnectionStatus status = MqttClientConnectionStatus()
    ..state = MqttConnectionState.connected;
  final StreamController<List<MqttReceivedMessage<MqttMessage>>> messages =
      StreamController<List<MqttReceivedMessage<MqttMessage>>>(
        onCancel: () async {},
      );
  final List<String> topics = <String>[];
  Future<void>? pendingConnect;
  Object? connectError;
  int disconnectCount = 0;

  @override
  MqttClientConnectionStatus get connectionStatus => status;

  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>> get updates => messages.stream;

  @override
  Future<MqttClientConnectionStatus?> connect([
    String? username,
    String? password,
  ]) async {
    await pendingConnect;
    if (connectError case final Object error) {
      throw error;
    }
    return status;
  }

  @override
  Subscription? subscribe(String topic, MqttQos qosLevel) {
    topics.add(topic);
    return null;
  }

  void dropConnection() {
    status.state = MqttConnectionState.disconnected;
    onDisconnected?.call();
  }

  @override
  void disconnect() {
    disconnectCount++;
    status.state = MqttConnectionState.disconnected;
    unawaited(messages.close());
    onDisconnected?.call();
  }
}
