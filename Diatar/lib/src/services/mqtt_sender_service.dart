import 'dart:async';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_buffers.dart';

class MqttSenderService {
  MqttSenderService({required this.onStatusChanged, required this.onError});

  ValueChanged<bool> onStatusChanged;
  ValueChanged<String> onError;

  static const String _host = 'mqtt.diatar.eu';
  static const int _port = 1883;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _sub;
  String _topicGroup = '';
  String _topicState = '';
  String _topicBlank = '';
  String _topicDia = '';

  Uint8List? _cachedState;
  Uint8List? _cachedText;
  Uint8List? _cachedBlank;

  bool get running => _client != null;

  Future<void> open({
    required String username,
    required String password,
    required String channel,
  }) async {
    await close();

    final String user = username.trim();
    final String pass = password;
    final String ch = channel.trim().isEmpty ? '1' : channel.trim();
    if (user.isEmpty) {
      onStatusChanged(false);
      return;
    }

    _topicGroup = 'Diatar/$user/$ch/';
    _topicState = '${_topicGroup}state';
    _topicBlank = '${_topicGroup}blank';
    _topicDia = '${_topicGroup}dia';

    final String clientId = 'sender-${DateTime.now().millisecondsSinceEpoch}';
    final MqttServerClient client = MqttServerClient(_host, clientId)
      ..port = _port
      ..logging(on: false)
      ..keepAlivePeriod = 15
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = false
      ..onDisconnected = () {
        onStatusChanged(false);
      }
      ..connectionMessage = MqttConnectMessage()
          .authenticateAs(user, pass)
          .withClientIdentifier(clientId)
          .withWillQos(MqttQos.atMostOnce);

    try {
      final MqttClientConnectionStatus? status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        onError('MQTT sender kapcsolodas sikertelen.');
        client.disconnect();
        onStatusChanged(false);
        return;
      }

      _client = client;
      _sub = client.updates?.listen((_) {});
      onStatusChanged(true);
      await _replayCache();
    } catch (e) {
      onError('MQTT sender hiba: $e');
      try {
        client.disconnect();
      } catch (_) {}
      onStatusChanged(false);
    }
  }

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    onStatusChanged(false);
  }

  Future<void> sendState(ProjectionGlobals globals, {required bool showing, required int wordToHighlight}) async {
    _cachedState = encodeStateRecord(globals, projecting: showing, wordToHighlight: wordToHighlight);
    await _publish(_topicState, _cachedState);
  }

  Future<void> sendText({required String title, required List<String> lines}) async {
    final Uint8List body = encodeTextRecord(title: title, lines: lines);
    _cachedText = Uint8List.fromList(<int>['T'.codeUnitAt(0), ...body]);
    await _publish(_topicDia, _cachedText);
  }

  Future<void> sendBlank(Uint8List bytes, {String ext = ''}) async {
    _cachedBlank = encodeImageRecord(bytes: bytes, ext: ext);
    await _publish(_topicBlank, _cachedBlank);
  }

  Future<void> sendPic(Uint8List bytes, {String ext = ''}) async {
    final Uint8List body = encodeImageRecord(bytes: bytes, ext: ext);
    await _publish(_topicDia, Uint8List.fromList(<int>['P'.codeUnitAt(0), ...body]));
  }

  Future<void> _replayCache() async {
    await _publish(_topicState, _cachedState);
    await _publish(_topicDia, _cachedText);
    await _publish(_topicBlank, _cachedBlank);
  }

  Future<void> _publish(String topic, Uint8List? payload) async {
    final MqttServerClient? client = _client;
    if (client == null || payload == null || topic.isEmpty) {
      return;
    }
    final Uint8Buffer buffer = Uint8Buffer()..addAll(payload);
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder()..addBuffer(buffer);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
}
