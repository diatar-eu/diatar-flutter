// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DiaVetito';

  @override
  String get settingsTitleReceiver => 'Settings';

  @override
  String get modeIp => 'IP';

  @override
  String get modeInternet => 'Internet';

  @override
  String get tcpPortRange => 'TCP port (0..65535)';

  @override
  String get senderLabel => 'Sender';

  @override
  String get senderHelper => 'MQTT sender name';

  @override
  String get senderRefreshTooltip => 'Refresh sender list';

  @override
  String get channelLabel => 'Channel';

  @override
  String get clipLeft => 'Left';

  @override
  String get clipTop => 'Top';

  @override
  String get clipRight => 'Right';

  @override
  String get clipBottom => 'Bottom';

  @override
  String get borderToClip => 'Margins from controller (Border2Clip)';

  @override
  String get mirror => 'Mirror';

  @override
  String get autoBootIndicator => 'Auto start (indicator)';

  @override
  String get rotationLabel => 'Rotation';

  @override
  String get projectionFilteringTitle => 'Projection filters';

  @override
  String get receiverUseServerColors => 'Server colors';

  @override
  String get receiverUseServerColorsHint =>
      'If disabled, local colors are used.';

  @override
  String get receiverShowHighlight => 'Show highlight';

  @override
  String get showChords => 'Show chords';

  @override
  String get showKotta => 'Show notation';

  @override
  String get scrollableProjection => 'Scrollable projection';

  @override
  String get scrollableProjectionHint =>
      'If turned off, text is auto-sized to fit the projection area.';

  @override
  String get localColorsTitle => 'Local colors';

  @override
  String get backgroundColorLabel => 'Background color';

  @override
  String get textColorLabel => 'Text color';

  @override
  String get blankColorLabel => 'Blank color';

  @override
  String get highlightColorLabel => 'Highlight color';

  @override
  String get change => 'Change';

  @override
  String get colorPickerTitle => 'Color picker';

  @override
  String get exit => 'Exit';

  @override
  String get shutdown => 'Shutdown';

  @override
  String get reboot => 'Reboot';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get invalidPortRange => 'Port must be between 0 and 65535.';

  @override
  String get statusStarting => 'Starting...';

  @override
  String get statusExitRequested => 'Exiting...';

  @override
  String get statusShutdownUnsupported =>
      'System shutdown is not supported in Flutter.';

  @override
  String get statusRebootUnsupported =>
      'System reboot is not supported in Flutter.';

  @override
  String get statusStopRequested => 'Stop requested (epStop).';

  @override
  String get statusShutdownRequestedUnsupported =>
      'Shutdown requested (epShutdown), unsupported in Flutter.';

  @override
  String statusReceiverError(Object message) {
    return '$message';
  }

  @override
  String get statusMqttOff => 'MQTT disabled';

  @override
  String statusMqttReceiving(Object user, Object channel) {
    return 'MQTT receiving: $user/$channel';
  }

  @override
  String statusConnected(int port) {
    return 'Connected ($port)';
  }

  @override
  String statusWaitingForClient(int port) {
    return 'Waiting for client ($port)';
  }

  @override
  String get statusTcpOff => 'TCP disabled';

  @override
  String statusTcpListening(int port) {
    return 'TCP listening: $port';
  }

  @override
  String statusTcpServerError(Object error) {
    return 'TCP error: $error';
  }

  @override
  String statusTcpServerOpenPortFailed(int port, Object error) {
    return 'Failed to open port ($port): $error';
  }

  @override
  String statusTcpServerClientError(Object error) {
    return 'Client error: $error';
  }

  @override
  String statusTcpServerPacketParseError(Object error) {
    return 'Packet parse error: $error';
  }

  @override
  String statusTcpServerSendError(Object error) {
    return 'Send error: $error';
  }
}
