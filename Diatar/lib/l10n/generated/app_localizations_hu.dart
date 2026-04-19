// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Diatár';

  @override
  String get viewTooltip => 'Nézet';

  @override
  String get viewSimple => 'Szimpla';

  @override
  String get viewSpontaneous => 'Spontán';

  @override
  String get viewOrder => 'Sorrend';

  @override
  String get settingsTooltip => 'Beállítások';

  @override
  String get playlistsTooltip => 'Énekrendek';

  @override
  String get playlistsTitle => 'Énekrendek';

  @override
  String get playlistsMessage =>
      'Ez a művelet később visszakaphatja a teljes dialógust.';

  @override
  String get customOrderTooltip => 'Saját sorrend';

  @override
  String get addSlideTooltip => 'Dia hozzáadása';

  @override
  String get addTextSlide => 'Szöveges dia';

  @override
  String get addImageSlide => 'Képes dia';

  @override
  String get downloadBooksTooltip => 'Énektárak letöltése';

  @override
  String get downloadTitle => 'Letöltés';

  @override
  String get downloadMessage =>
      'A letöltési párbeszéd később visszahelyezhető.';

  @override
  String get refreshTooltip => 'Frissítés';

  @override
  String get ok => 'Rendben';

  @override
  String get songPrev => 'Ének -';

  @override
  String get songNext => 'Ének +';

  @override
  String get projectionOn => 'Vetítés BE';

  @override
  String get projectionOff => 'Vetítés KI';

  @override
  String get previous => 'Előző';

  @override
  String get next => 'Következő';

  @override
  String get highlightPrev => 'Highlight -';

  @override
  String get highlightNext => 'Highlight +';

  @override
  String positionLabel(int current, int total) {
    return 'Pozíció: $current/$total';
  }

  @override
  String statusLabel(Object status) {
    return 'Státusz: $status';
  }

  @override
  String get statusStarting => 'Indítás...';

  @override
  String statusSenderError(Object message) {
    return '$message';
  }

  @override
  String statusSenderTcpError(Object error) {
    return 'TCP hiba: $error';
  }

  @override
  String statusSenderOpenPortFailed(int port, Object error) {
    return 'Nem sikerült portot nyitni ($port): $error';
  }

  @override
  String get statusSenderMqttConnectFailed =>
      'MQTT sender kapcsolódás sikertelen.';

  @override
  String statusSenderMqttError(Object error) {
    return 'MQTT sender hiba: $error';
  }

  @override
  String statusMqttSending(Object user, Object channel) {
    return 'MQTT küldés: $user/$channel';
  }

  @override
  String statusTcpSending(int port) {
    return 'TCP küldés: $port';
  }

  @override
  String statusNoDtxFiles(Object path) {
    return 'Nincs .dtx fájl: $path';
  }

  @override
  String get statusAllSongbooksDisabled =>
      'Minden énektár le van tiltva az énekrendben.';

  @override
  String statusSongbooksLoaded(int count) {
    return '$count kötet betöltve';
  }

  @override
  String statusLoadError(Object error) {
    return 'Betöltési hiba: $error';
  }

  @override
  String statusCustomOrderSelected(Object label) {
    return 'Saját sorrend: $label';
  }

  @override
  String statusOrderSaved(Object path) {
    return 'Sorrend mentve: $path';
  }

  @override
  String statusDiaFileMissing(Object path) {
    return 'Nincs ilyen .DIA fájl: $path';
  }

  @override
  String statusOrderLoaded(int count, Object path) {
    return 'Sorrend betöltve ($count elem): $path';
  }

  @override
  String get statusDownloadListLoading => 'Énektár lista letöltése...';

  @override
  String statusDownloadProgress(
    int current,
    int total,
    Object name,
    int percent,
  ) {
    return 'Letöltés: $current/$total $name $percent%';
  }

  @override
  String get statusDownloadSummaryNone => 'Nincs új énektár frissítés.';

  @override
  String statusDownloadSummary(int downloaded, int skipped) {
    return '$downloaded fájl letöltve, $skipped változatlan.';
  }

  @override
  String statusDownloadError(Object error) {
    return 'Letöltési hiba: $error';
  }

  @override
  String statusBookSelected(Object name) {
    return 'Kötet: $name';
  }

  @override
  String statusSongPicked(Object name) {
    return 'Ének: $name';
  }

  @override
  String statusVersePicked(Object name) {
    return 'Versszak: $name';
  }

  @override
  String statusSongSelected(Object title) {
    return 'Ének: $title';
  }

  @override
  String statusSongVerseSelected(Object title) {
    return 'Ének/versszak: $title';
  }

  @override
  String get statusProjectionOn => 'Vetítés: BE';

  @override
  String get statusProjectionOff => 'Vetítés: KI';

  @override
  String get statusImagePathEmpty => 'A kép fájl útvonala üres.';

  @override
  String get statusCustomTextEmpty => 'Adj meg címet vagy legalább egy sort.';

  @override
  String statusCustomTextSent(Object title) {
    return 'Szöveges dia elküldve: $title';
  }

  @override
  String statusCustomTextError(Object error) {
    return 'Szöveges dia küldési hiba: $error';
  }

  @override
  String statusImageNotFound(Object path) {
    return 'A kép fájl nem található: $path';
  }

  @override
  String statusImageSent(Object name) {
    return 'Kép elküldve: $name';
  }

  @override
  String statusImageSendError(Object error) {
    return 'Kép küldési hiba: $error';
  }

  @override
  String get statusBlankPathEmpty => 'A blank kép fájl útvonala üres.';

  @override
  String statusBlankNotFound(Object path) {
    return 'A blank kép fájl nem található: $path';
  }

  @override
  String statusBlankSet(Object name) {
    return 'Blank kép beállítva: $name';
  }

  @override
  String statusBlankSendError(Object error) {
    return 'Blank kép küldési hiba: $error';
  }

  @override
  String get statusBlankCleared => 'Blank kép törölve.';

  @override
  String statusBlankClearError(Object error) {
    return 'Blank kép törlési hiba: $error';
  }

  @override
  String get statusShutdownCommandSent => 'Lezárás utasitas elküldve.';

  @override
  String get statusStopCommandSent => 'Megállítás utasitas elküldve.';

  @override
  String statusCommandSendError(Object error) {
    return 'Utasítás küldési hiba: $error';
  }

  @override
  String sendStatusLabel(
    Object protocol,
    Object senderState,
    Object clientState,
  ) {
    return 'Küldés ($protocol): $senderState, kliens: $clientState';
  }

  @override
  String get protocolMqtt => 'MQTT';

  @override
  String get protocolTcp => 'TCP';

  @override
  String get senderStateActive => 'aktív';

  @override
  String get senderStateOff => 'kikapcsolva';

  @override
  String get clientStateConnected => 'csatlakozva';

  @override
  String get clientStateWaiting => 'várakozik';

  @override
  String tcpPortLabel(int port) {
    return 'TCP port: $port';
  }

  @override
  String downloadProgress(int current, int total, Object name) {
    return 'Letöltés: $current/$total $name';
  }

  @override
  String get noLoadedSlide => 'Nincs betöltött dia.';

  @override
  String get bookLabel => 'Kötet';

  @override
  String get songLabel => 'Ének';

  @override
  String get verseLabel => 'Versszak';

  @override
  String versePanelTitle(Object title, Object verse) {
    return '$title: $verse';
  }

  @override
  String get searchLabel => 'Diakereső';

  @override
  String get searchHint => 'Kötet vagy enekcím';

  @override
  String get noResults => 'Nincs találat.';

  @override
  String customOrderStatus(Object state) {
    return 'Saját sorrend: $state';
  }

  @override
  String get stateActive => 'Aktív';

  @override
  String get stateInactive => 'Inaktív';

  @override
  String get nextShort => 'Kov.';

  @override
  String get previewTitle => 'Dia előnézet';

  @override
  String get projectedImage => 'Vetített kép:';

  @override
  String get settingsTitle => 'Diatár beállítások';

  @override
  String get settingsTitleReceiver => 'Beállítások';

  @override
  String get modeIp => 'IP';

  @override
  String get modeInternet => 'Internet';

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
  String get tcpPortRange => 'TCP port (0..65535)';

  @override
  String get mqttUserHint => 'MQTT user (üres = TCP mód)';

  @override
  String get mqttPassword => 'MQTT jelszó';

  @override
  String get mqttChannel => 'MQTT csatorna';

  @override
  String get uiTheme => 'Felhasználói felület témája';

  @override
  String get themeDark => 'Sötét';

  @override
  String get themeLight => 'Világos';

  @override
  String get dtxFolderPath => 'DTX mappa';

  @override
  String get blankImagePath => 'Blank kép útvonal';

  @override
  String get fileChoose => 'Fájl választása';

  @override
  String get uiLanguage => 'Felhasználói felület nyelve';

  @override
  String get languageSystem => 'Rendszer alapértelmezett';

  @override
  String get languageHungarian => 'Magyar';

  @override
  String get languageEnglish => 'Angol';

  @override
  String get projectionSettingsTitle => 'Vetítési beállítások';

  @override
  String get fontSize => 'Betűméret';

  @override
  String get titleSize => 'Cím méret';

  @override
  String get leftMargin => 'Bal behúzás';

  @override
  String get borderLeft => 'Border L';

  @override
  String get borderTop => 'Border T';

  @override
  String get borderRight => 'Border R';

  @override
  String get borderBottom => 'Border B';

  @override
  String get lineSpacing => 'Sorköz';

  @override
  String get kottaScale => 'Kotta méret arány';

  @override
  String get chordScale => 'Akkord méret arány';

  @override
  String get backgroundMode => 'Háttér kép mód';

  @override
  String get bgModeCenter => 'Center';

  @override
  String get bgModeZoom => 'Zoom';

  @override
  String get bgModeFull => 'Full';

  @override
  String get bgModeCascade => 'Cascade';

  @override
  String get bgModeMirror => 'Mirror';

  @override
  String get backgroundOpacity => 'Háttér átlátszóság';

  @override
  String get blankOpacity => 'Blank átlátszóság';

  @override
  String get autoSize => 'Automatikus méretezés';

  @override
  String get scrollableProjection => 'Görgethető vetítés';

  @override
  String get scrollableProjectionHint =>
      'Ha ki van kapcsolva, a szöveg automatikusan a vetítési területhez igazodik.';

  @override
  String get showTitle => 'Cím mutatása';

  @override
  String get hCenter => 'Vízszintes középre igazítás';

  @override
  String get vCenter => 'Függőleges középre igazítás';

  @override
  String get showChords => 'Akkordok mutatása';

  @override
  String get showKotta => 'Kotta mutatása';

  @override
  String get boldText => 'Félkövér szöveg';

  @override
  String get colorsTitle => 'Színek';

  @override
  String get backgroundColor => 'Háttér';

  @override
  String get textColor => 'Szöveg';

  @override
  String get emptySlideColor => 'Üres dia';

  @override
  String get highlightColor => 'Kiemelés';

  @override
  String get backgroundColorTitle => 'Háttér színe';

  @override
  String get textColorTitle => 'Szöveg színe';

  @override
  String get emptySlideColorTitle => 'Üres dia színe';

  @override
  String get highlightColorTitle => 'Kiemelés színe';

  @override
  String get cancel => 'Mégse';

  @override
  String get save => 'Ment';

  @override
  String get invalidPortRange => 'A port 0..65535 között legyen.';

  @override
  String get hexColorHint => 'Hex szín (#AARRGGBB vagy #RRGGBB)';

  @override
  String get close => 'Bezárás';

  @override
  String get imagesFileTypeLabel => 'képek';

  @override
  String get diatarPlaylistFileTypeLabel => 'Diatár playlist';

  @override
  String get customOrderSuggestedFileName => 'sorrend.dia';

  @override
  String get customOrderEditTitle => 'Saját sorrend szerkesztése';

  @override
  String get addSong => 'Ének hozzáadása';

  @override
  String get searchSongHint => 'Kötet vagy énekcím';

  @override
  String get textSlideDialogTitle => 'Szöveges dia hozzáadása';

  @override
  String get textSlideTitleLabel => 'Cím';

  @override
  String get textSlideBodyLabel => 'Szöveg (soronként)';

  @override
  String get loadDia => 'Betöltés .DIA';

  @override
  String get saveDia => 'Mentés .DIA';

  @override
  String savedPath(Object path) {
    return 'Mentve: $path';
  }

  @override
  String loadedCount(int count) {
    return 'Betöltve: $count elem';
  }

  @override
  String get customOrderEmpty =>
      'A sorrend üres.\nKeress énekeket a szerkesztéshez.';

  @override
  String get versePicker => 'Versszak';

  @override
  String get selectedVersesTitle => 'Kiválasztott versszakok';

  @override
  String get selectedVersesSubtitle => 'Többet is kijelölhetsz.';

  @override
  String get apply => 'Alkalmaz';
}
