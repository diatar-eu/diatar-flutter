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
      if (runtime.mqttActive) {
        await mqttSender
            .open(
              username: runtime.mqttUser,
              password: mqttPassword,
              channel: mqttChannel,
            )
            .timeout(_transportTimeout);
      } else {
        await mqttSender
            .clearRetainedMessages()
            .timeout(_transportTimeout);
        await mqttSender.close().timeout(_transportTimeout);
      }

      if (!kIsWeb && runtime.tcpConfigured) {
        await tcpSender
            .restart(runtime.tcpTargets)
            .timeout(_transportTimeout);
        await tcpSender
            .sendScreenSize(width: screenWidth, height: screenHeight)
            .timeout(_transportTimeout);
      } else {
        await tcpSender.stop().timeout(_transportTimeout);
      }
    } catch (e) {
      // Egy elérhetetlen hálózati célpont soha nem akaszthatja meg az
      // alkalmazás indítását vagy a beállítások alkalmazását.
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