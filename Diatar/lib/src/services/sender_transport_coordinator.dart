import 'package:flutter/foundation.dart';

import '../core/settings/transport_settings_policy.dart';
import 'mqtt_sender_service.dart';
import 'tcp_sender_service.dart';

class SenderTransportCoordinator {
  const SenderTransportCoordinator();

  static const Duration _transportTimeout = Duration(seconds: 20);

  Future<void> apply({
    required MqttSenderService mqttSender,
    required TcpSenderService tcpSender,
    required TransportRuntimeState runtime,
    required String mqttPassword,
    required String mqttChannel,
    required int screenWidth,
    required int screenHeight,
  }) async {
    try {
      final Future<void> mqttFuture = runtime.mqttActive
          ? mqttSender
                .open(
                  username: runtime.mqttUser,
                  password: mqttPassword,
                  channel: mqttChannel,
                )
                .timeout(_transportTimeout)
          : () async {
              await mqttSender.clearRetainedMessages().timeout(_transportTimeout);
              await mqttSender.close().timeout(_transportTimeout);
            }();

      final Future<void> tcpFuture = (!kIsWeb && runtime.tcpConfigured)
          ? () async {
              await tcpSender.restart(runtime.tcpTargets).timeout(_transportTimeout);
              await tcpSender
                  .sendScreenSize(
                    width: screenWidth,
                    height: screenHeight,
                  )
                  .timeout(_transportTimeout);
            }()
          : tcpSender.stop().timeout(_transportTimeout);

      await Future.wait(<Future<void>>[mqttFuture, tcpFuture], eagerError: false);
    } catch (e) {
      // A két küldési csatorna független kell, hogy legyen: egyik hibája
      // ne akadályozza meg a másik elkészülését, és ne torzítsa a jelzőállapotot.
      debugPrint('[transport] apply timeout/error: $e');
    }
  }

  Future<void> sendScreenSize({
    required TcpSenderService tcpSender,
    required int screenWidth,
    required int screenHeight,
  }) {
    return tcpSender.sendScreenSize(
      width: screenWidth,
      height: screenHeight,
    );
  }
}