import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/mqtt_user.dart';
import '../models/records.dart';

typedef MqttErrorCallback = void Function(String message);
typedef MqttStateCallback = void Function(RecStateRecord record);
typedef MqttTextCallback = void Function(RecTextRecord record);
typedef MqttImageCallback = void Function(RecImageRecord record);
typedef MqttUsersCallback = void Function(List<MqttUser> users);

class MqttService {
  MqttService({
    required this.onError,
    required this.onState,
    required this.onText,
    required this.onPic,
    required this.onBlank,
    required this.onUsers,
  });

  final MqttErrorCallback onError;
  final MqttStateCallback onState;
  final MqttTextCallback onText;
  final MqttImageCallback onPic;
  final MqttImageCallback onBlank;
  final MqttUsersCallback onUsers;

  static const String _host = 'mqtt.diatar.eu';
  static const int _port = 1883;

  static const String _dynSecSuperUser = 'GMfnGLDMCLFLOLlmqm';
  static const String _dynSecSuperPsw = 'ekhnenjmQLAPLKMdmaCIBIcjhi';
  static const String _dynSecTopic = r'$CONTROL/dynamic-security/v1';
  static const String _dynSecTopicResp = r'$CONTROL/dynamic-security/v1/response';

  MqttServerClient? _receiverClient;
  MqttServerClient? _adminClient;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _receiverSub;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _adminSub;

  String _username = '';
  String _channel = '1';
  String _topicGroup = '';
  String _topicMask = '';
  String _topicState = '';
  String _topicBlank = '';
  String _topicDia = '';

  List<MqttUser> _users = <MqttUser>[];

  Future<void> openReceiver({required String username, required String channel}) async {
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

    final String clientId = 'receiver-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
    final MqttServerClient client = MqttServerClient(_host, clientId)
      ..port = _port
      ..logging(on: false)
      ..keepAlivePeriod = 15
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..onDisconnected = () {}
      ..connectionMessage = MqttConnectMessage()
          .authenticateAs('receiver', 'receiverpsw')
          .withClientIdentifier(clientId)
          .withWillQos(MqttQos.atMostOnce);

    try {
      final MqttClientConnectionStatus? status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        onError('MQTT receiver kapcsolodas sikertelen.');
        client.disconnect();
        return;
      }
      client.subscribe(_topicMask, MqttQos.atLeastOnce);
      _receiverSub = client.updates?.listen(_onReceiverMessages);
      _receiverClient = client;
    } catch (e) {
      onError('MQTT receiver hiba: $e');
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
  }

  Future<void> fillUserList() async {
    await _openAdmin();
    if (_adminClient == null) {
      return;
    }
    _users = <MqttUser>[];
    _publishAdmin('{"commands": [{"command": "listClients"}]}');
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
    await _closeAdmin();
  }

  void _onReceiverMessages(List<MqttReceivedMessage<MqttMessage>> event) {
    for (final MqttReceivedMessage<MqttMessage> e in event) {
      final MqttPublishMessage msg = e.payload as MqttPublishMessage;
      final String topic = e.topic;
      if (topic == _topicState) {
        final List<int> bytes = msg.payload.message;
        if (bytes.isNotEmpty) {
          onState(RecStateRecord.fromBytes(Uint8List.fromList(bytes)));
        }
      } else if (topic == _topicBlank) {
        onBlank(RecImageRecord.fromBytes(Uint8List.fromList(msg.payload.message)));
      } else if (topic == _topicDia) {
        final List<int> b = msg.payload.message;
        if (b.isEmpty) {
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

  Future<void> _openAdmin() async {
    await _closeAdmin();
    final String clientId = 'admin-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
    final MqttServerClient client = MqttServerClient(_host, clientId)
      ..port = _port
      ..logging(on: false)
      ..keepAlivePeriod = 15
      ..autoReconnect = false
      ..connectionMessage = MqttConnectMessage()
          .authenticateAs(_decodePsw(_dynSecSuperUser), _decodePsw(_dynSecSuperPsw))
          .withClientIdentifier(clientId)
          .withWillQos(MqttQos.atMostOnce);
    try {
      final MqttClientConnectionStatus? status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        onError('MQTT admin kapcsolodas sikertelen.');
        try {
          client.disconnect();
        } catch (_) {}
        return;
      }
      client.subscribe(_dynSecTopicResp, MqttQos.atLeastOnce);
      _adminSub = client.updates?.listen(_onAdminMessages);
      _adminClient = client;
    } catch (e) {
      onError('MQTT admin hiba: $e');
      try {
        client.disconnect();
      } catch (_) {}
    }
  }

  Future<void> _closeAdmin() async {
    await _adminSub?.cancel();
    _adminSub = null;
    try {
      _adminClient?.disconnect();
    } catch (_) {}
    _adminClient = null;
  }

  void _publishAdmin(String jsonPayload) {
    final MqttServerClient? client = _adminClient;
    if (client == null) {
      return;
    }
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder()..addString(jsonPayload);
    client.publishMessage(_dynSecTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _onAdminMessages(List<MqttReceivedMessage<MqttMessage>> event) {
    for (final MqttReceivedMessage<MqttMessage> e in event) {
      final MqttPublishMessage msg = e.payload as MqttPublishMessage;
      final String txt = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      _messageReceived(txt);
    }
  }

  void _messageReceived(String txt) {
    try {
      final dynamic all = jsonDecode(txt);
      final List<dynamic> responses = (all['responses'] as List<dynamic>? ?? <dynamic>[]);
      bool isCont = false;
      for (final dynamic resp in responses) {
        isCont = _processResponse(resp as Map<String, dynamic>, isCont) || isCont;
      }
      if (!isCont) {
        onUsers(List<MqttUser>.unmodifiable(_users));
        _closeAdmin();
      }
    } catch (e) {
      onError('MQTT admin valasz hiba: $e');
      _closeAdmin();
    }
  }

  bool _processResponse(Map<String, dynamic> resp, bool isCont) {
    if (resp['error'] != null) {
      onError('Adminisztracios hiba: ${resp['error']}');
      return false;
    }
    final String cmd = (resp['command']?.toString() ?? '').toUpperCase();
    if (cmd == 'LISTCLIENTS') {
      return _processListClients(resp, isCont);
    }
    if (cmd == 'GETCLIENT') {
      return _processGetClient(resp, isCont);
    }
    return false;
  }

  bool _processListClients(Map<String, dynamic> resp, bool isCont) {
    final List<dynamic> clients = ((resp['data'] as Map<String, dynamic>?)?['clients'] as List<dynamic>?) ?? <dynamic>[];
    _users = clients.map((dynamic c) => MqttUser(username: c.toString())).toList();
    return isCont || _sendUserDetails();
  }

  bool _processGetClient(Map<String, dynamic> resp, bool isCont) {
    final Map<String, dynamic>? client = (resp['data'] as Map<String, dynamic>?)?['client'] as Map<String, dynamic>?;
    if (client == null) {
      return isCont || _sendUserDetails();
    }
    final String uname = client['username']?.toString() ?? '';
    if (uname.isEmpty) {
      return isCont || _sendUserDetails();
    }
    MqttUser? user;
    for (final MqttUser u in _users) {
      if (u.username == uname) {
        user = u;
        break;
      }
    }
    user ??= MqttUser(username: uname);
    if (!_users.contains(user)) {
      _users.add(user);
    }

    user.email = client['textname']?.toString() ?? '';
    _fillChannels(user, client['textdescription']?.toString() ?? '');
    final List<dynamic> roles = client['roles'] as List<dynamic>? ?? <dynamic>[];
    user.sendersGroup = roles.any((dynamic r) => ((r as Map<String, dynamic>)['rolename']?.toString() ?? '').startsWith('s-'));
    return isCont || _sendUserDetails();
  }

  bool _sendUserDetails() {
    final List<String> cmds = <String>[];
    for (final MqttUser u in _users) {
      if (u.sentForDetails) {
        continue;
      }
      u.sentForDetails = true;
      cmds.add('{"command": "getClient", "username": "${u.username}"}');
      if (cmds.length >= 5) {
        break;
      }
    }
    if (cmds.isEmpty) {
      return false;
    }
    _publishAdmin('{"commands": [${cmds.join(', ')}]}');
    return true;
  }

  void _fillChannels(MqttUser user, String txt) {
    user.channels.fillRange(0, user.channels.length, '');
    int idx = 0;
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < txt.length; i++) {
      final String ch = txt[i];
      if (ch == '|') {
        if (i + 1 < txt.length && txt[i + 1] == '|') {
          sb.write('|');
          i++;
          continue;
        }
        if (idx < user.channels.length) {
          user.channels[idx] = sb.toString().trim();
          idx++;
        }
        sb.clear();
        continue;
      }
      sb.write(ch);
    }
    if (idx < user.channels.length && sb.isNotEmpty) {
      user.channels[idx] = sb.toString().trim();
    }
  }

  String _decodePsw(String secret) {
    if (secret.isEmpty) {
      return secret;
    }
    final List<int> input = utf8.encode(secret);
    final List<int> out = <int>[];
    int i = 0;
    while (i < input.length) {
      int b1 = input[i++];
      if (b1 == 'A'.codeUnitAt(0) || b1 == 'a'.codeUnitAt(0)) {
        continue;
      }
      if (i >= input.length) {
        break;
      }
      final int b2 = input[i++];
      final int c1 = b1 >= 'c'.codeUnitAt(0) ? b1 - 'c'.codeUnitAt(0) : b1 - 'B'.codeUnitAt(0);
      final int c2 = b2 >= 'c'.codeUnitAt(0) ? b2 - 'c'.codeUnitAt(0) - 4 : b2 - 'B'.codeUnitAt(0) - 4;
      out.add((c1 & 15) + ((c2 & 15) << 4));
    }
    return utf8.decode(out, allowMalformed: true);
  }

  String _unaccent(String txt) {
    const Map<String, String> repl = <String, String>{
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ö': 'o', 'ő': 'o', 'ú': 'u', 'ü': 'u', 'ű': 'u',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ö': 'O', 'Ő': 'O', 'Ú': 'U', 'Ü': 'U', 'Ű': 'U',
    };
    final StringBuffer sb = StringBuffer();
    for (final int r in txt.runes) {
      final String ch = String.fromCharCode(r);
      sb.write(repl[ch] ?? ch);
    }
    return sb.toString().toUpperCase();
  }
}