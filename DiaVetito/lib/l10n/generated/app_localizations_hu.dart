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
  String get logoTitle => 'Diatár Vetítő';

  @override
  String splashVersionSubtitle(Object version, Object buildNumber) {
    return 'Verzió v$version ($buildNumber)';
  }

  @override
  String get settingsTitleReceiver => 'Beállítások';

  @override
  String settingsVersionLabel(Object version, Object buildNumber) {
    return 'Verzió $version ($buildNumber)';
  }

  @override
  String get settingsSearchLabel => 'Keresés a beállításokban';

  @override
  String get settingsNoResults => 'Nincs találat a keresésre.';

  @override
  String get settingsInternetTitle => 'Internet';

  @override
  String settingsInternetSubtitle(Object internet, Object sender) {
    return 'Internetes közvetítés: $internet, Felhasználó: $sender';
  }

  @override
  String get settingsLocalNetworkTitle => 'Helyi hálózat (TCP/IP)';

  @override
  String settingsLocalNetworkSubtitle(Object port) {
    return 'TCP port: $port';
  }

  @override
  String get projectionImageTitle => 'Vetítési kép';

  @override
  String projectionImageSummary(Object rotation, Object mirror) {
    return 'Forgatás: $rotation, Tükrözés: $mirror';
  }

  @override
  String get projectionColorSourceServer => 'Szerver színek';

  @override
  String get projectionColorSourceLocal => 'Helyi színek';

  @override
  String projectionFilterSummary(Object source, Object scrollable) {
    return 'Színforrás: $source, Görgethető: $scrollable';
  }

  @override
  String localColorsSummary(Object background, Object text) {
    return 'Háttér: $background, Szöveg: $text';
  }

  @override
  String get settingsGeneralTitle => 'Általános';

  @override
  String settingsGeneralSubtitle(Object language, Object autostart) {
    return 'Nyelv: $language, Autostart: $autostart';
  }

  @override
  String get systemActionsTitle => 'Rendszer műveletek';

  @override
  String get systemActionsSummary => 'Kilépés, leállítás, újraindítás';

  @override
  String get internetBroadcastTitle => 'Internetes közvetítés';

  @override
  String get valueOn => 'Be';

  @override
  String get valueOff => 'Ki';

  @override
  String get settingsSearchKeywordsInternet =>
      'internet mqtt sender channel kozvetites felhasznalo';

  @override
  String get settingsSearchKeywordsLan => 'helyi halozat tcp ip port';

  @override
  String get settingsSearchKeywordsProjectionImage =>
      'vetitesi kep forgatas tukrozes clip margok';

  @override
  String get settingsSearchKeywordsProjectionFilter =>
      'vetitesi szures akkord kotta highlight scroll';

  @override
  String get settingsSearchKeywordsColors => 'szinek hatter szoveg blank';

  @override
  String get settingsSearchKeywordsGeneral => 'altalanos nyelv autostart boot';

  @override
  String get settingsSearchKeywordsSystem =>
      'rendszer kilepes leallas ujrainditas';

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
