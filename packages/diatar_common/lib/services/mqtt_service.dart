import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_factory.dart';

import '../models/mqtt_user.dart';
import '../models/records.dart';

typedef MqttErrorCallback = void Function(String message);
typedef MqttStateCallback = void Function(RecStateRecord record);
typedef MqttTextCallback = void Function(RecTextRecord record);
typedef MqttImageCallback = void Function(RecImageRecord record);
typedef MqttUsersCallback = void Function(List<MqttUser> users);
typedef MqttConnectionCallback = void Function(bool connected);

class MqttService {
  MqttService({
    required this.onError,
    required this.onState,
    required this.onText,
    required this.onPic,
    required this.onBlank,
    required this.onUsers,
    this.onConnection,
  });

  final MqttErrorCallback onError;
  final MqttStateCallback onState;
  final MqttTextCallback onText;
  final MqttImageCallback onPic;
  final MqttImageCallback onBlank;
  final MqttUsersCallback onUsers;
  final MqttConnectionCallback? onConnection;

  static const String _host = 'mqtt.diatar.eu';
  static const String _webHost = 'wss://mqttws.diatar.eu';
  static const int _port = 1883;
  static const String _apiBase = 'https://mqtt.diatar.eu';

  MqttClient? _receiverClient;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _receiverSub;

  String _username = '';
  String _channel = '1';
  String _topicGroup = '';
  String _topicMask = '';
  String _topicState = '';
  String _topicBlank = '';
  String _topicDia = '';
  Uint8List? _lastStateBytes;

  List<MqttUser> _users = <MqttUser>[];

  Future<void> openReceiver({
    required String username,
    required String channel,
  }) async {
    await closeReceiver();
    _username = username.trim();
    _channel = channel.trim().isEmpty ? '1' : channel.trim();
    if (_username.isEmpty) {
      return;
    }

    _topicGroup = 'Diatar/$_username/$_channel/';
    _topicMask = '$_topicGroup#';
    _topicState = '${_topicGroup}state';
    _topicBlank = '${_topicGroup}blank';
    _topicDia = '${_topicGroup}dia';

    final String clientId =
        'receiver-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
    final bool isWeb = kIsWeb;
    final String host = isWeb ? _webHost : _host;
    final MqttClient client = createMqttClient(host, clientId)
      ..port = isWeb ? 443 : _port
      ..logging(on: false)
      ..keepAlivePeriod = 15
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..onConnected = () {
        onConnection?.call(true);
      }
      ..onDisconnected = () {
        onConnection?.call(false);
      }
      ..connectionMessage = MqttConnectMessage()
          .authenticateAs('receiver', 'receiverpsw')
          .withClientIdentifier(clientId)
          .withWillQos(MqttQos.atMostOnce);

    try {
      final MqttClientConnectionStatus? status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        onError('MQTT receiver kapcsolodas sikertelen.');
        onConnection?.call(false);
        client.disconnect();
        return;
      }
      client.subscribe(_topicMask, MqttQos.atLeastOnce);
      _receiverSub = client.updates?.listen(_onReceiverMessages);
      _receiverClient = client;
    } catch (e) {
      onError('MQTT receiver hiba: $e');
      onConnection?.call(false);
      try {
        client.disconnect();
      } catch (_) {}
    }
  }

  Future<void> closeReceiver() async {
    await _receiverSub?.cancel();
    _receiverSub = null;
    try {
      _receiverClient?.disconnect();
    } catch (_) {}
    _receiverClient = null;
    _lastStateBytes = null;
    onConnection?.call(false);
  }

  Future<void> fillUserList() async {
    await _fillUserList();
  }

  List<MqttUser> usersLike(String mask) {
    final String q = _unaccent(mask.trim());
    if (q.isEmpty) {
      return <MqttUser>[];
    }
    return _users.where((MqttUser u) {
      if (!u.sendersGroup) {
        return false;
      }
      final String name = _unaccent(u.username);
      return q.length == 1 ? name.startsWith(q) : name.contains(q);
    }).toList();
  }

  MqttUser? getUser(String uname) {
    final String q = _unaccent(uname.trim());
    for (final MqttUser u in _users) {
      if (!u.sendersGroup) {
        continue;
      }
      if (_unaccent(u.username) == q) {
        return u;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await closeReceiver();
  }

  Future<void> _fillUserList() async {
    final Uri uri = Uri.parse('$_apiBase/api/v1/users/list');
    try {
      final http.Response response = await http
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        onError(
          'Felhasznalolista lekerdezesi hiba: HTTP ${response.statusCode}.',
        );
        return;
      }

      final dynamic decoded = jsonDecode(response.body);
      final List<String> usernames = _extractUsernames(decoded);
      _users = usernames
          .where((String u) => u.trim().isNotEmpty)
          .toSet()
          .map((String u) => MqttUser(username: u.trim(), sendersGroup: true))
          .toList();
      onUsers(List<MqttUser>.unmodifiable(_users));
    } catch (e) {
      onError('Felhasznalolista lekerdezesi hiba: $e');
    }
  }

  List<String> _extractUsernames(dynamic payload) {
    final List<dynamic> rawList = <dynamic>[];
    if (payload is List<dynamic>) {
      rawList.addAll(payload);
    } else if (payload is Map<String, dynamic>) {
      final dynamic users =
          payload['users'] ??
          payload['data'] ??
          payload['items'] ??
          payload['result'];
      if (users is List<dynamic>) {
        rawList.addAll(users);
      }
    }

    final List<String> result = <String>[];
    for (final dynamic item in rawList) {
      if (item is String) {
        result.add(item);
      } else if (item is Map<String, dynamic>) {
        final dynamic uname =
            item['username'] ?? item['userName'] ?? item['name'];
        if (uname is String) {
          result.add(uname);
        }
      }
    }
    return result;
  }

  void _onReceiverMessages(List<MqttReceivedMessage<MqttMessage>> event) {
    for (final MqttReceivedMessage<MqttMessage> e in event) {
      final MqttPublishMessage msg = e.payload as MqttPublishMessage;
      final String topic = e.topic;
      if (topic == _topicState) {
        final List<int> bytes = msg.payload.message;
        if (bytes.isNotEmpty) {
          final Uint8List current = Uint8List.fromList(bytes);
          _lastStateBytes = current;
          onState(RecStateRecord.fromBytes(current));
        } else {
          onState(_projectionOffStateFromLastState());
        }
      } else if (topic == _topicBlank) {
        onBlank(
          RecImageRecord.fromBytes(Uint8List.fromList(msg.payload.message)),
        );
      } else if (topic == _topicDia) {
        final List<int> b = msg.payload.message;
        if (b.isEmpty) {
          onText(RecTextRecord.fromBytes(Uint8List(0)));
          continue;
        }
        if (b.first == 'P'.codeUnitAt(0)) {
          onPic(RecImageRecord.fromBytes(Uint8List.fromList(b.sublist(1))));
        } else if (b.first == 'T'.codeUnitAt(0)) {
          onText(RecTextRecord.fromBytes(Uint8List.fromList(b.sublist(1))));
        }
      }
    }
  }

  RecStateRecord _projectionOffStateFromLastState() {
    // RecStateRecord reads up to offset 348, so keep at least that many bytes.
    final Uint8List source = _lastStateBytes ?? Uint8List(349);
    final Uint8List bytes = Uint8List.fromList(source);
    if (bytes.length < 349) {
      final Uint8List padded = Uint8List(349);
      padded.setRange(0, bytes.length, bytes);
      padded[310] = 0;
      padded[318] = 0;
      padded[319] = 0;
      padded[320] = 0;
      padded[321] = 0;
      return RecStateRecord.fromBytes(padded);
    }
    bytes[310] = 0;
    bytes[318] = 0;
    bytes[319] = 0;
    bytes[320] = 0;
    bytes[321] = 0;
    return RecStateRecord.fromBytes(bytes);
  }

  String _unaccent(String txt) {
    const Map<String, String> repl = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ö': 'o',
      'ő': 'o',
      'ú': 'u',
      'ü': 'u',
      'ű': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ö': 'O',
      'Ő': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ű': 'U',
    };
    final StringBuffer sb = StringBuffer();
    for (final int r in txt.runes) {
      final String ch = String.fromCharCode(r);
      sb.write(repl[ch] ?? ch);
    }
    return sb.toString().toUpperCase();
  }
}
