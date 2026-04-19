// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'DiaVetito';

  @override
  String get settingsTitleReceiver => 'Beallitasok';

  @override
  String get modeIp => 'IP';

  @override
  String get modeInternet => 'Internet';

  @override
  String get tcpPortRange => 'TCP port (0..65535)';

  @override
  String get senderLabel => 'Kuldo';

  @override
  String get senderHelper => 'MQTT sender neve';

  @override
  String get senderRefreshTooltip => 'Kuldo lista frissites';

  @override
  String get channelLabel => 'Csatorna';

  @override
  String get clipLeft => 'Bal';

  @override
  String get clipTop => 'Felso';

  @override
  String get clipRight => 'Jobb';

  @override
  String get clipBottom => 'Also';

  @override
  String get borderToClip => 'Margok a vezerlotol (Border2Clip)';

  @override
  String get mirror => 'Tukrozes';

  @override
  String get autoBootIndicator => 'Automatikus inditas (jelzo)';

  @override
  String get rotationLabel => 'Forgatas';

  @override
  String get uiLanguage => 'Felhasznaloi felulet nyelve';

  @override
  String get languageSystem => 'Rendszer alapertelmezett';

  @override
  String get languageHungarian => 'Magyar';

  @override
  String get languageEnglish => 'Angol';

  @override
  String get projectionFilteringTitle => 'Vetites szurese';

  @override
  String get receiverUseServerColors => 'Szerver szinei';

  @override
  String get receiverUseServerColorsHint =>
      'Ha ki van kapcsolva, a helyi szinek lesznek hasznalva.';

  @override
  String get receiverShowHighlight => 'Kiemeles megjelenitese';

  @override
  String get showChords => 'Akkordok mutatasa';

  @override
  String get showKotta => 'Kotta mutatasa';

  @override
  String get scrollableProjection => 'Gorgetheto vetites';

  @override
  String get scrollableProjectionHint =>
      'Ha ki van kapcsolva, a szoveg automatikusan a vetitesi terulethez igazodik.';

  @override
  String get localColorsTitle => 'Helyi szinek';

  @override
  String get backgroundColorLabel => 'Hatterszin';

  @override
  String get textColorLabel => 'Szovegszin';

  @override
  String get blankColorLabel => 'Blank szin';

  @override
  String get highlightColorLabel => 'Kiemeles szin';

  @override
  String get change => 'Valt';

  @override
  String get colorPickerTitle => 'Szinvalaszto';

  @override
  String get exit => 'Kilepes';

  @override
  String get shutdown => 'Leallitas';

  @override
  String get reboot => 'Ujrainditas';

  @override
  String get cancel => 'Megse';

  @override
  String get save => 'Ment';

  @override
  String get ok => 'OK';

  @override
  String get invalidPortRange => 'A port 0..65535 kozott legyen.';

  @override
  String get statusStarting => 'Inditas...';

  @override
  String get statusExitRequested => 'Kilepes...';

  @override
  String get statusShutdownUnsupported =>
      'Rendszerleallitas Flutteren nem tamogatott.';

  @override
  String get statusRebootUnsupported =>
      'Rendszer ujrainditas Flutteren nem tamogatott.';

  @override
  String get statusStopRequested => 'Leallitas kerve (epStop).';

  @override
  String get statusShutdownRequestedUnsupported =>
      'Rendszerleallitas kerve (epShutdown), Flutterben nem tamogatott.';

  @override
  String statusReceiverError(Object message) {
    return '$message';
  }

  @override
  String get statusMqttOff => 'MQTT kikapcsolva';

  @override
  String statusMqttReceiving(Object user, Object channel) {
    return 'MQTT fogadas: $user/$channel';
  }

  @override
  String statusConnected(int port) {
    return 'Kapcsolodva ($port)';
  }

  @override
  String statusWaitingForClient(int port) {
    return 'Varakozas kliensre ($port)';
  }

  @override
  String get statusTcpOff => 'TCP kikapcsolva';

  @override
  String statusTcpListening(int port) {
    return 'TCP figyeles: $port';
  }

  @override
  String statusTcpServerError(Object error) {
    return 'TCP hiba: $error';
  }

  @override
  String statusTcpServerOpenPortFailed(int port, Object error) {
    return 'Nem sikerult portot nyitni ($port): $error';
  }

  @override
  String statusTcpServerClientError(Object error) {
    return 'Kliens hiba: $error';
  }

  @override
  String statusTcpServerPacketParseError(Object error) {
    return 'Csomag feldolgozasi hiba: $error';
  }

  @override
  String statusTcpServerSendError(Object error) {
    return 'Kuldesi hiba: $error';
  }
}
