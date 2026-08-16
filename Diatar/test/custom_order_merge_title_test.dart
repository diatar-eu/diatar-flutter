import 'dart:async';

import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/core/settings/transport_settings_policy.dart';
import 'package:diatar_app/src/services/mqtt_sender_service.dart';
import 'package:diatar_app/src/services/sender_transport_coordinator.dart';
import 'package:diatar_app/src/services/tcp_sender_service.dart';
import 'package:diatar_app/src/ui/home_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'create') {
        return <String, dynamic>{'playerId': 'mock-player'};
      }
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAll':
          return <String, dynamic>{};
        case 'setBool':
        case 'setDouble':
        case 'setInt':
        case 'setString':
        case 'setStringList':
        case 'remove':
          return true;
        default:
          return null;
      }
    },
  );

  group('merge title formatting', () {
    test('keeps shared book and song prefix once', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet: ének/vers1',
        'Kötet: ének/vers2',
      );

      expect(merged, 'Kötet: ének/vers1, vers2');
    });

    test('keeps shared book prefix and separates differing song/verse', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet: ének1/vers1',
        'Kötet: ének2/vers2',
      );

      expect(merged, 'Kötet: ének1/vers1, ének2/vers2');
    });

    test('falls back to comma-separated full labels when no shared prefix', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet1: ének1/Vers1',
        'kötet2: ének2/vers2',
      );

      expect(merged, 'Kötet1: ének1/Vers1, kötet2: ének2/vers2');
    });

    test('normalizes slash spacing before merge formatting', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet: ének / vers1',
        'Kötet: ének/vers2',
      );

      expect(merged, 'Kötet: ének/vers1, vers2');
    });
  });

  group('custom order naming', () {
    test('updates the active set display name after a save-as rename', () async {
      final DiatarMainController controller = DiatarMainController();

      await controller.createCustomOrderSet('Régi név');
      await controller.markCustomOrderDiaExportSaved('C:/Temp/Új név.dia');

      expect(controller.customOrderSets, hasLength(1));
      expect(controller.customOrderSets.first.name, 'Új név');
      expect(controller.customOrderSets.first.baseName, 'Új név');
      expect(controller.customOrderSets.first.displayName, 'Új név');
      expect(controller.suggestedCustomOrderBaseName, 'Új név');
    });
  });

  group('connection indicator precedence', () {
    test('TCP stays green when the connection is live even if the internet side is failing', () {
      expect(
        resolveTcpIndicatorState(
          tcpActive: true,
          tcpConnected: true,
          tcpHasError: true,
        ),
        TransportIndicatorState.connected,
      );
    });

    test('TCP remains yellow while it is still waiting for a TCP connection', () {
      expect(
        resolveTcpIndicatorState(
          tcpActive: true,
          tcpConnected: false,
          tcpHasError: false,
        ),
        TransportIndicatorState.connecting,
      );
    });

    test('Internet status is still independent from TCP', () {
      expect(
        resolveMqttIndicatorState(
          mqttActive: true,
          mqttConnected: false,
          mqttHasError: true,
        ),
        TransportIndicatorState.error,
      );
    });
  });

  group('transport startup independence', () {
    test('TCP startup is not blocked by a slow or failing MQTT connection', () async {
      final Completer<void> mqttOpenGate = Completer<void>();
      final _BlockingMqttSender mqtt = _BlockingMqttSender(mqttOpenGate);
      final _TrackingTcpSender tcp = _TrackingTcpSender();
      final SenderTransportCoordinator coordinator = const SenderTransportCoordinator();

      final Future<void> applyFuture = coordinator.apply(
        mqttSender: mqtt,
        tcpSender: tcp,
        runtime: const TransportRuntimeState(
          mqttUser: 'user',
          tcpTargets: <String>['127.0.0.1:1024'],
          mqttActive: true,
          tcpConfigured: true,
          mqttConnectAttemptAt: null,
          tcpConnectAttemptAt: null,
        ),
        mqttPassword: 'pw',
        mqttChannel: '1',
        screenWidth: 1920,
        screenHeight: 1080,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(tcp.restartCalled, isTrue,
          reason: 'TCP restart should be started independently of MQTT connection attempts.');

      mqttOpenGate.complete();
      await applyFuture;
    });
  });
}

class _BlockingMqttSender extends MqttSenderService {
  _BlockingMqttSender(this._openGate)
      : super(onStatusChanged: (_) {}, onError: (_, __) {});

  final Completer<void> _openGate;

  @override
  Future<void> open({
    required String username,
    required String password,
    required String channel,
  }) async {
    await _openGate.future;
  }

  @override
  Future<void> clearRetainedMessages() async {}

  @override
  Future<void> close() async {}
}

class _TrackingTcpSender extends TcpSenderService {
  _TrackingTcpSender()
      : super(onStatusChanged: (_) {}, onError: (_, __) {});

  bool restartCalled = false;

  @override
  Future<void> restart(List<String> targets) async {
    restartCalled = true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> sendScreenSize({
    required int width,
    required int height,
  }) async {}
}
