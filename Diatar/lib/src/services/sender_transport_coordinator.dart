import '../core/settings/transport_settings_policy.dart';
import 'mqtt_sender_service.dart';
import 'tcp_sender_service.dart';

class SenderTransportCoordinator {
  const SenderTransportCoordinator();

  Future<void> apply({
    required MqttSenderService mqttSender,
    required TcpSenderService tcpSender,
    required TransportRuntimeState runtime,
    required String mqttPassword,
    required String mqttChannel,
    required int screenWidth,
    required int screenHeight,
  }) async {
    if (runtime.mqttActive) {
      await mqttSender.open(
        username: runtime.mqttUser,
        password: mqttPassword,
        channel: mqttChannel,
      );
    } else {
      await mqttSender.clearRetainedMessages();
      await mqttSender.close();
    }

    if (runtime.tcpConfigured) {
      await tcpSender.restart(runtime.tcpTargets);
      await tcpSender.sendScreenSize(width: screenWidth, height: screenHeight);
    } else {
      await tcpSender.stop();
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