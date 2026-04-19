// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'DiaVetítő';

  @override
  String get settingsTitleReceiver => 'Beállítások';

  @override
  String get modeIp => 'IP';

  @override
  String get modeInternet => 'Internet';

  @override
  String get tcpPortRange => 'TCP port (0..65535)';

  @override
  String get senderLabel => 'Küldő';

  @override
  String get senderHelper => 'MQTT sender neve';

  @override
  String get senderRefreshTooltip => 'Küldő lista frissítés';

  @override
  String get channelLabel => 'Csatorna';

  @override
  String get clipLeft => 'Bal';

  @override
  String get clipTop => 'Felső';

  @override
  String get clipRight => 'Jobb';

  @override
  String get clipBottom => 'Alsó';

  @override
  String get borderToClip => 'Margok a vezérlőtől (Border2Clip)';

  @override
  String get mirror => 'Tükrözés';

  @override
  String get autoBootIndicator => 'Automatikus indítás (jelző)';

  @override
  String get rotationLabel => 'Forgatás';

  @override
  String get uiLanguage => 'Felhasználói felület nyelve';

  @override
  String get languageSystem => 'Rendszer alapértelmezett';

  @override
  String get languageHungarian => 'Magyar';

  @override
  String get languageEnglish => 'Angol';

  @override
  String get projectionFilteringTitle => 'Vetítés szűrése';

  @override
  String get receiverUseServerColors => 'Szerver színei';

  @override
  String get receiverUseServerColorsHint =>
      'Ha ki van kapcsolva, a helyi színek lesznek használva.';

  @override
  String get receiverShowHighlight => 'Kiemelés megjelenítése';

  @override
  String get showChords => 'Akkordok mutatása';

  @override
  String get showKotta => 'Kotta mutatása';

  @override
  String get scrollableProjection => 'Görgethető vetítés';

  @override
  String get scrollableProjectionHint =>
      'Ha ki van kapcsolva, a szöveg automatikusan a vetítési területhez igazodik.';

  @override
  String get localColorsTitle => 'Helyi színek';

  @override
  String get backgroundColorLabel => 'Háttérszín';

  @override
  String get textColorLabel => 'Szövegszín';

  @override
  String get blankColorLabel => 'Blank szín';

  @override
  String get highlightColorLabel => 'Kiemelés szín';

  @override
  String get change => 'Vált';

  @override
  String get colorPickerTitle => 'Színválasztó';

  @override
  String get exit => 'Kilépés';

  @override
  String get shutdown => 'Leállítás';

  @override
  String get reboot => 'Újraindítás';

  @override
  String get cancel => 'Mégse';

  @override
  String get save => 'Ment';

  @override
  String get ok => 'OK';

  @override
  String get invalidPortRange => 'A port 0..65535 között legyen.';

  @override
  String get statusStarting => 'Indítás...';

  @override
  String get statusExitRequested => 'Kilépés...';

  @override
  String get statusShutdownUnsupported =>
      'Rendszerleállítás Flutteren nem támogatott.';

  @override
  String get statusRebootUnsupported =>
      'Rendszer újraindítás Flutteren nem támogatott.';

  @override
  String get statusStopRequested => 'Leállítás kérve (epStop).';

  @override
  String get statusShutdownRequestedUnsupported =>
      'Rendszerleállítás kérve (epShutdown), Flutterben nem támogatott.';

  @override
  String statusReceiverError(Object message) {
    return '$message';
  }

  @override
  String get statusMqttOff => 'MQTT kikapcsolva';

  @override
  String statusMqttReceiving(Object user, Object channel) {
    return 'MQTT fogadás: $user/$channel';
  }

  @override
  String statusConnected(int port) {
    return 'Kapcsolódva ($port)';
  }

  @override
  String statusWaitingForClient(int port) {
    return 'Várakozás kliensre ($port)';
  }

  @override
  String get statusTcpOff => 'TCP kikapcsolva';

  @override
  String statusTcpListening(int port) {
    return 'TCP figyelés: $port';
  }

  @override
  String statusTcpServerError(Object error) {
    return 'TCP hiba: $error';
  }

  @override
  String statusTcpServerOpenPortFailed(int port, Object error) {
    return 'Nem sikerült portot nyitni ($port): $error';
  }

  @override
  String statusTcpServerClientError(Object error) {
    return 'Kliens hiba: $error';
  }

  @override
  String statusTcpServerPacketParseError(Object error) {
    return 'Csomag feldolgozási hiba: $error';
  }

  @override
  String statusTcpServerSendError(Object error) {
    return 'Küldési hiba: $error';
  }
}
