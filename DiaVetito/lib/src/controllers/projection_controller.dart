import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/mqtt_service.dart';
import '../services/settings_store.dart';
import '../services/tcp_server_service.dart';

class ProjectionController extends ChangeNotifier {
  ProjectionController()
      : _server = TcpServerService(
          onState: _onStateStatic,
          onText: _onTextStatic,
          onPic: _onPicStatic,
          onBlank: _onBlankStatic,
          onAskSize: _onAskSizeStatic,
          onError: _onErrorStatic,
          onConnection: _onConnectionStatic,
        ),
        _mqtt = MqttService(
          onError: _onErrorStatic,
          onState: _onStateStatic,
          onText: _onTextStatic,
          onPic: _onPicStatic,
          onBlank: _onBlankStatic,
          onUsers: _onUsersStatic,
        ) {
    _instance = this;
  }

  static ProjectionController? _instance;

  static void _onStateStatic(RecStateRecord record) => _instance?._onState(record);
  static void _onTextStatic(RecTextRecord record) => _instance?._onText(record);
  static void _onPicStatic(RecImageRecord record) => _instance?._onPic(record);
  static void _onBlankStatic(RecImageRecord record) => _instance?._onBlank(record);
  static void _onAskSizeStatic() => _instance?._onAskSize();
  static void _onErrorStatic(String message) => _instance?._onError(message);
  static void _onConnectionStatic(bool connected) => _instance?._onConnection(connected);
  static void _onUsersStatic(List<MqttUser> users) => _instance?._onUsers(users);

  final SettingsStore _settingsStore = SettingsStore();
  final TcpServerService _server;
  final MqttService _mqtt;

  AppSettings settings = const AppSettings();
  ProjectionGlobals globals = const ProjectionGlobals().copyWith(projecting: true);
  ProjectionFrame? diaFrame = const LogoFrame(0);
  ProjectionFrame? blankFrame;
  List<MqttUser> mqttUsers = <MqttUser>[];
  List<String> senderSuggestions = <String>[];
  List<String> channelSuggestions = const <String>[];

  bool initialized = false;
  bool connected = false;
  bool mqttActive = false;
  String statusMessage = 'Inditas...';
  Size viewportSize = const Size(1920, 1080);

  Timer? _logoTimer;
  bool _disposed = false;

  Future<void> init() async {
    if (_disposed) {
      return;
    }
    settings = await _settingsStore.load();
    globals = _applyReceiverDisplayFilters(globals);
    await _applyTransport();
    await refreshMqttUsers();
    _startLogo();
    initialized = true;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> applySettings(AppSettings newSettings) async {
    if (_disposed) {
      return;
    }
    settings = newSettings;
    await _settingsStore.save(settings);
    globals = _applyReceiverDisplayFilters(globals);
    _updateChannelSuggestionsFor(settings.mqttUser);
    await _applyTransport();
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> refreshMqttUsers() async {
    if (_disposed) {
      return;
    }
    await _mqtt.fillUserList();
  }

  void updateSenderFilter(String mask) {
    senderSuggestions = _mqtt.usersLike(mask).map((MqttUser u) => u.username).toList();
    notifyListeners();
  }

  void chooseSender(String sender) {
    _updateChannelSuggestionsFor(sender);
    notifyListeners();
  }

  ProjectionGlobals _applyReceiverDisplayFilters(ProjectionGlobals source) {
    return source.copyWith(
      useAkkord: settings.receiverUseAkkord && source.useAkkord,
      useKotta: settings.receiverUseKotta && source.useKotta,
    );
  }

  Future<void> requestExit() async {
    if (_disposed) {
      return;
    }
    statusMessage = 'Kilepes...';
    notifyListeners();
    await SystemNavigator.pop();
  }

  void requestShutdown() {
    if (_disposed) {
      return;
    }
    statusMessage = 'Rendszerleallitas Flutteren nem tamogatott.';
    notifyListeners();
  }

  void requestReboot() {
    if (_disposed) {
      return;
    }
    statusMessage = 'Rendszer ujrainditas Flutteren nem tamogatott.';
    notifyListeners();
  }

  void _updateChannelSuggestionsFor(String sender) {
    final MqttUser? u = _mqtt.getUser(sender);
    if (u == null) {
      channelSuggestions = const <String>[];
      return;
    }
    channelSuggestions = u.channels.where((String c) => c.trim().isNotEmpty).toList();
  }

  void updateViewport(Size size) {
    if (size == Size.zero) {
      return;
    }
    viewportSize = size;
  }

  Future<void> _onState(RecStateRecord record) async {
    if (_disposed) {
      return;
    }
    globals = _applyReceiverDisplayFilters(globals.fromState(record));
    final int ep = record.endProgram;
    if (ep == RecStateEndProgram.stop || ep == RecStateEndProgram.stop + RecStateEndProgram.skipSerialOff) {
      statusMessage = 'Leallitas kerve (epStop).';
      await SystemNavigator.pop();
      return;
    }
    if (ep == RecStateEndProgram.shutdown || ep == RecStateEndProgram.shutdown + RecStateEndProgram.skipSerialOff) {
      statusMessage = 'Rendszerleallitas kerve (epShutdown), Flutterben nem tamogatott.';
    }
    if (settings.borderToClip) {
      settings = settings.copyWith(
        clipL: math.max(0, globals.borderL).toDouble(),
        clipT: math.max(0, globals.borderT).toDouble(),
        clipR: math.max(0, globals.borderR).toDouble(),
        clipB: math.max(0, globals.borderB).toDouble(),
      );
      await _settingsStore.save(settings);
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _onText(RecTextRecord record) {
    if (_disposed) {
      return;
    }
    diaFrame = TextFrame(record: record);
    notifyListeners();
  }

  Future<void> _onPic(RecImageRecord record) async {
    if (_disposed) {
      return;
    }
    final ui.Image? image = await _decodeImage(record.imageBytes);
    if (image == null) {
      return;
    }
    diaFrame = ImageFrame(image: image, bgMode: 1);
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _onBlank(RecImageRecord record) async {
    if (_disposed) {
      return;
    }
    final ui.Image? image = await _decodeImage(record.imageBytes);
    if (image == null) {
      return;
    }
    blankFrame = ImageFrame(image: image, bgMode: globals.bgMode);
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _onAskSize() async {
    if (_disposed) {
      return;
    }
    await _server.sendScreenSize(
      width: viewportSize.width.round(),
      height: viewportSize.height.round(),
    );
  }

  void _onError(String message) {
    if (_disposed) {
      return;
    }
    statusMessage = message;
    notifyListeners();
  }

  void _onConnection(bool isConnected) {
    if (_disposed) {
      return;
    }
    connected = isConnected;
    if (mqttActive) {
      statusMessage = settings.mqttUser.trim().isEmpty
          ? 'MQTT kikapcsolva'
          : 'MQTT fogadas: ${settings.mqttUser}/${settings.mqttChannel}';
    } else {
      statusMessage = isConnected
          ? 'Kapcsolodva (${settings.port})'
          : (settings.tcpEnabled ? 'Varakozas kliensre (${settings.port})' : 'TCP kikapcsolva');
    }
    notifyListeners();
  }

  void _onUsers(List<MqttUser> users) {
    if (_disposed) {
      return;
    }
    mqttUsers = users;
    senderSuggestions = _mqtt.usersLike(settings.mqttUser).map((MqttUser u) => u.username).toList();
    _updateChannelSuggestionsFor(settings.mqttUser);
    notifyListeners();
  }

  ProjectionFrame? get activeFrame {
    if (globals.projecting) {
      return diaFrame;
    }
    if (blankFrame != null) {
      return blankFrame;
    }
    if (diaFrame is ImageFrame) {
      return diaFrame;
    }
    return null;
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return null;
    }
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyTransport() async {
    final String user = settings.mqttUser.trim();
    if (user.isEmpty) {
      mqttActive = false;
      await _mqtt.closeReceiver();
      await _server.restart(settings.port);
      statusMessage = 'TCP figyeles: ${settings.port}';
    } else {
      mqttActive = true;
      await _server.stop();
      await _mqtt.openReceiver(username: user, channel: settings.mqttChannel);
      statusMessage = 'MQTT fogadas: $user/${settings.mqttChannel}';
    }
  }

  void _startLogo() {
    _logoTimer?.cancel();
    int phase = 0;
    _logoTimer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (diaFrame is! LogoFrame) {
        t.cancel();
        return;
      }
      if (phase > 80) {
        diaFrame = null;
        globals = globals.copyWith(projecting: false);
        t.cancel();
      } else {
        diaFrame = LogoFrame(phase);
      }
      phase++;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _instance = null;
    _logoTimer?.cancel();
    _server.stop(emitConnection: false);
    _mqtt.dispose();
    super.dispose();
  }
}
