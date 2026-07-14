import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String host, String clientId) {
  return MqttBrowserClient(host, clientId);
}