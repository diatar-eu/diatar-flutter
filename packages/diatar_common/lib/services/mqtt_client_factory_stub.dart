import 'package:mqtt_client/mqtt_client.dart';

MqttClient createMqttClient(String host, String clientId) {
  throw UnsupportedError('Cannot create a client without dart:io or dart:html');
}
