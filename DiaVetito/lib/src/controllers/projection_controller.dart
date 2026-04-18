import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
  String statusCode = 'statusStarting';
  Map<String, Object> statusParams = const <String, Object>{};
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
    final ProjectionGlobals colored = settings.receiverUseServerColors
        ? source
        : source.copyWith(
            bkColor: settings.bkColor,
            txtColor: settings.txtColor,
            blankColor: settings.blankColor,
            hiColor: settings.hiColor,
          );

    return colored.copyWith(
      wordToHighlight: settings.receiverShowHighlight ? colored.wordToHighlight : 0,
      useAkkord: settings.receiverUseAkkord && source.useAkkord,
      useKotta: settings.receiverUseKotta && source.useKotta,
      autoResize: settings.projAutoSize,
    );
  }

  Future<void> requestExit() async {
    if (_disposed) {
      return;
    }
    _setStatus('statusExitRequested');
    await SystemNavigator.pop();
  }

  void requestShutdown() {
    if (_disposed) {
      return;
    }
    _setStatus('statusShutdownUnsupported');
  }

  void requestReboot() {
    if (_disposed) {
      return;
    }
    _setStatus('statusRebootUnsupported');
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
      _setStatus('statusStopRequested', notify: false);
      await SystemNavigator.pop();
      return;
    }
    if (ep == RecStateEndProgram.shutdown || ep == RecStateEndProgram.shutdown + RecStateEndProgram.skipSerialOff) {
      _setStatus('statusShutdownRequestedUnsupported', notify: false);
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
    if (message.startsWith('tcpServerOpenPortFailed:')) {
      const String prefix = 'tcpServerOpenPortFailed:';
      final String payload = message.substring(prefix.length);
      final int separator = payload.indexOf(':');
      if (separator > 0) {
        final int? port = int.tryParse(payload.substring(0, separator));
        final String error = payload.substring(separator + 1);
        _setStatus(
          'statusTcpServerOpenPortFailed',
          params: <String, Object>{
            'port': port ?? settings.port,
            'error': error,
          },
        );
        return;
      }
    }

    if (message.startsWith('tcpServerError:')) {
      _setStatus('statusTcpServerError', params: <String, Object>{'error': message.substring('tcpServerError:'.length)});
      return;
    }
    if (message.startsWith('tcpServerClientError:')) {
      _setStatus('statusTcpServerClientError', params: <String, Object>{'error': message.substring('tcpServerClientError:'.length)});
      return;
    }
    if (message.startsWith('tcpServerPacketParseError:')) {
      _setStatus('statusTcpServerPacketParseError', params: <String, Object>{'error': message.substring('tcpServerPacketParseError:'.length)});
      return;
    }
    if (message.startsWith('tcpServerSendError:')) {
      _setStatus('statusTcpServerSendError', params: <String, Object>{'error': message.substring('tcpServerSendError:'.length)});
      return;
    }

    _setStatus('statusReceiverError', params: <String, Object>{'message': message});
  }

  void _onConnection(bool isConnected) {
    if (_disposed) {
      return;
    }
    connected = isConnected;
    if (mqttActive) {
      _setStatus(
        settings.mqttUser.trim().isEmpty ? 'statusMqttOff' : 'statusMqttReceiving',
        notify: false,
        params: settings.mqttUser.trim().isEmpty
            ? const <String, Object>{}
            : <String, Object>{
                'user': settings.mqttUser,
                'channel': settings.mqttChannel,
              },
      );
    } else {
      if (isConnected) {
        _setStatus('statusConnected', notify: false, params: <String, Object>{'port': settings.port});
      } else if (settings.tcpEnabled) {
        _setStatus('statusWaitingForClient', notify: false, params: <String, Object>{'port': settings.port});
      } else {
        _setStatus('statusTcpOff', notify: false);
      }
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
      _setStatus('statusTcpListening', notify: false, params: <String, Object>{'port': settings.port});
    } else {
      mqttActive = true;
      await _server.stop();
      await _mqtt.openReceiver(username: user, channel: settings.mqttChannel);
      _setStatus(
        'statusMqttReceiving',
        notify: false,
        params: <String, Object>{
          'user': user,
          'channel': settings.mqttChannel,
        },
      );
    }
  }

  void _setStatus(String code, {Map<String, Object> params = const <String, Object>{}, bool notify = true}) {
    statusCode = code;
    statusParams = params;
    if (notify && !_disposed) {
      notifyListeners();
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
