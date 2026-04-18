// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Diatar';

  @override
  String get viewTooltip => 'Nezet';

  @override
  String get viewSimple => 'Szimpla';

  @override
  String get viewSpontaneous => 'Spontan';

  @override
  String get viewOrder => 'Sorrend';

  @override
  String get settingsTooltip => 'Beallitasok';

  @override
  String get playlistsTooltip => 'Enekrendek';

  @override
  String get playlistsTitle => 'Enekrendek';

  @override
  String get playlistsMessage =>
      'Ez a muvelet kesobb visszakaphatja a teljes dialogust.';

  @override
  String get customOrderTooltip => 'Sajat sorrend';

  @override
  String get addSlideTooltip => 'Dia hozzaadasa';

  @override
  String get addTextSlide => 'Szoveges dia';

  @override
  String get addImageSlide => 'Kepes dia';

  @override
  String get downloadBooksTooltip => 'Enektarak letoltese';

  @override
  String get downloadTitle => 'Letoltes';

  @override
  String get downloadMessage =>
      'A letoltesi parbeszed kesobb visszahelyezheto.';

  @override
  String get refreshTooltip => 'Frissites';

  @override
  String get ok => 'Rendben';

  @override
  String get songPrev => 'Ének -';

  @override
  String get songNext => 'Ének +';

  @override
  String get projectionOn => 'Vetites BE';

  @override
  String get projectionOff => 'Vetites KI';

  @override
  String get previous => 'Elozo';

  @override
  String get next => 'Kovetkezo';

  @override
  String get highlightPrev => 'Highlight -';

  @override
  String get highlightNext => 'Highlight +';

  @override
  String positionLabel(int current, int total) {
    return 'Pozicio: $current/$total';
  }

  @override
  String statusLabel(Object status) {
    return 'Statusz: $status';
  }

  @override
  String get statusStarting => 'Inditas...';

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
    return 'Nem sikerult portot nyitni ($port): $error';
  }

  @override
  String get statusSenderMqttConnectFailed =>
      'MQTT sender kapcsolodas sikertelen.';

  @override
  String statusSenderMqttError(Object error) {
    return 'MQTT sender hiba: $error';
  }

  @override
  String statusMqttSending(Object user, Object channel) {
    return 'MQTT kuldes: $user/$channel';
  }

  @override
  String statusTcpSending(int port) {
    return 'TCP kuldes: $port';
  }

  @override
  String statusNoDtxFiles(Object path) {
    return 'Nincs .dtx fajl: $path';
  }

  @override
  String get statusAllSongbooksDisabled =>
      'Minden enektar le van tiltva az enekrendben.';

  @override
  String statusSongbooksLoaded(int count) {
    return '$count kotet betoltve';
  }

  @override
  String statusLoadError(Object error) {
    return 'Betoltesi hiba: $error';
  }

  @override
  String statusCustomOrderSelected(Object label) {
    return 'Sajat sorrend: $label';
  }

  @override
  String statusOrderSaved(Object path) {
    return 'Sorrend mentve: $path';
  }

  @override
  String statusDiaFileMissing(Object path) {
    return 'Nincs ilyen .DIA fajl: $path';
  }

  @override
  String statusOrderLoaded(int count, Object path) {
    return 'Sorrend betoltve ($count elem): $path';
  }

  @override
  String get statusDownloadListLoading => 'Enektar lista letoltese...';

  @override
  String statusDownloadProgress(
    int current,
    int total,
    Object name,
    int percent,
  ) {
    return 'Letoltes: $current/$total $name $percent%';
  }

  @override
  String get statusDownloadSummaryNone => 'Nincs uj enektar frissites.';

  @override
  String statusDownloadSummary(int downloaded, int skipped) {
    return '$downloaded fajl letoltve, $skipped valtozatlan.';
  }

  @override
  String statusDownloadError(Object error) {
    return 'Letoltesi hiba: $error';
  }

  @override
  String statusBookSelected(Object name) {
    return 'Kotet: $name';
  }

  @override
  String statusSongPicked(Object name) {
    return 'Enek: $name';
  }

  @override
  String statusVersePicked(Object name) {
    return 'Versszak: $name';
  }

  @override
  String statusSongSelected(Object title) {
    return 'Enek: $title';
  }

  @override
  String statusSongVerseSelected(Object title) {
    return 'Enek/versszak: $title';
  }

  @override
  String get statusProjectionOn => 'Vetites: BE';

  @override
  String get statusProjectionOff => 'Vetites: KI';

  @override
  String get statusImagePathEmpty => 'A kep fajl utvonala ures.';

  @override
  String get statusCustomTextEmpty => 'Adj meg cimet vagy legalabb egy sort.';

  @override
  String statusCustomTextSent(Object title) {
    return 'Szoveges dia elkuldve: $title';
  }

  @override
  String statusCustomTextError(Object error) {
    return 'Szoveges dia kuldesi hiba: $error';
  }

  @override
  String statusImageNotFound(Object path) {
    return 'A kep fajl nem talalhato: $path';
  }

  @override
  String statusImageSent(Object name) {
    return 'Kep elkuldve: $name';
  }

  @override
  String statusImageSendError(Object error) {
    return 'Kep kuldesi hiba: $error';
  }

  @override
  String get statusBlankPathEmpty => 'A blank kep fajl utvonala ures.';

  @override
  String statusBlankNotFound(Object path) {
    return 'A blank kep fajl nem talalhato: $path';
  }

  @override
  String statusBlankSet(Object name) {
    return 'Blank kep beallitva: $name';
  }

  @override
  String statusBlankSendError(Object error) {
    return 'Blank kep kuldesi hiba: $error';
  }

  @override
  String get statusBlankCleared => 'Blank kep torolve.';

  @override
  String statusBlankClearError(Object error) {
    return 'Blank kep torlesi hiba: $error';
  }

  @override
  String get statusShutdownCommandSent => 'Lezaras utasitas elkuldve.';

  @override
  String get statusStopCommandSent => 'Megallitas utasitas elkuldve.';

  @override
  String statusCommandSendError(Object error) {
    return 'Utasitas kuldesi hiba: $error';
  }

  @override
  String sendStatusLabel(
    Object protocol,
    Object senderState,
    Object clientState,
  ) {
    return 'Kuldes ($protocol): $senderState, kliens: $clientState';
  }

  @override
  String get protocolMqtt => 'MQTT';

  @override
  String get protocolTcp => 'TCP';

  @override
  String get senderStateActive => 'aktiv';

  @override
  String get senderStateOff => 'kikapcsolva';

  @override
  String get clientStateConnected => 'csatlakozva';

  @override
  String get clientStateWaiting => 'varakozik';

  @override
  String tcpPortLabel(int port) {
    return 'TCP port: $port';
  }

  @override
  String downloadProgress(int current, int total, Object name) {
    return 'Letoltes: $current/$total $name';
  }

  @override
  String get noLoadedSlide => 'Nincs betoltott dia.';

  @override
  String get bookLabel => 'Kötet';

  @override
  String get songLabel => 'Enek';

  @override
  String get verseLabel => 'Versszak';

  @override
  String versePanelTitle(Object title, Object verse) {
    return '$title: $verse';
  }

  @override
  String get searchLabel => 'Diakereso';

  @override
  String get searchHint => 'Kötet vagy enekcim';

  @override
  String get noResults => 'Nincs talalat.';

  @override
  String customOrderStatus(Object state) {
    return 'Sajat sorrend: $state';
  }

  @override
  String get stateActive => 'Aktiv';

  @override
  String get stateInactive => 'Inaktiv';

  @override
  String get nextShort => 'Kov.';

  @override
  String get previewTitle => 'Dia elonezet';

  @override
  String get projectedImage => 'Vetitett kep:';

  @override
  String get settingsTitle => 'Diatar beallitasok';

  @override
  String get settingsTitleReceiver => 'Beallitasok';

  @override
  String get modeIp => 'IP';

  @override
  String get modeInternet => 'Internet';

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
  String get tcpPortRange => 'TCP port (0..65535)';

  @override
  String get mqttUserHint => 'MQTT user (ures = TCP mod)';

  @override
  String get mqttPassword => 'MQTT jelszo';

  @override
  String get mqttChannel => 'MQTT csatorna';

  @override
  String get dtxFolderPath => 'DTX mappa';

  @override
  String get blankImagePath => 'Blank kep utvonal';

  @override
  String get fileChoose => 'Fajl valasztasa';

  @override
  String get projectionSettingsTitle => 'Vetitesi beallitasok';

  @override
  String get fontSize => 'Betumeret';

  @override
  String get titleSize => 'Cim meret';

  @override
  String get leftMargin => 'Bal margo';

  @override
  String get borderLeft => 'Border L';

  @override
  String get borderTop => 'Border T';

  @override
  String get borderRight => 'Border R';

  @override
  String get borderBottom => 'Border B';

  @override
  String get lineSpacing => 'Sorkoz';

  @override
  String get kottaScale => 'Kotta meret arany';

  @override
  String get chordScale => 'Akkord meret arany';

  @override
  String get backgroundMode => 'Hatters kep mod';

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
  String get backgroundOpacity => 'Hatter atszosag';

  @override
  String get blankOpacity => 'Blank atszosag';

  @override
  String get autoSize => 'Automatikus meretezes';

  @override
  String get scrollableProjection => 'Gorgetheto vetites';

  @override
  String get scrollableProjectionHint =>
      'Ha ki van kapcsolva, a szoveg automatikusan a vetitesi terulethez igazodik.';

  @override
  String get showTitle => 'Cim mutatasa';

  @override
  String get hCenter => 'Vizszintes kozepre igazitas';

  @override
  String get vCenter => 'Fuggoleges kozepre igazitas';

  @override
  String get showChords => 'Akkordok mutatasa';

  @override
  String get showKotta => 'Kotta mutatasa';

  @override
  String get boldText => 'Felkover szoveg';

  @override
  String get colorsTitle => 'Szinek';

  @override
  String get backgroundColor => 'Hatter';

  @override
  String get textColor => 'Szoveg';

  @override
  String get emptySlideColor => 'Ures dia';

  @override
  String get highlightColor => 'Kiemeles';

  @override
  String get backgroundColorTitle => 'Hatter szine';

  @override
  String get textColorTitle => 'Szoveg szine';

  @override
  String get emptySlideColorTitle => 'Ures dia szine';

  @override
  String get highlightColorTitle => 'Kiemeles szine';

  @override
  String get cancel => 'Megse';

  @override
  String get save => 'Ment';

  @override
  String get invalidPortRange => 'A port 0..65535 kozott legyen.';

  @override
  String get hexColorHint => 'Hex szin (#AARRGGBB vagy #RRGGBB)';

  @override
  String get close => 'Bezaras';

  @override
  String get imagesFileTypeLabel => 'kepek';

  @override
  String get diatarPlaylistFileTypeLabel => 'Diatar playlist';

  @override
  String get customOrderSuggestedFileName => 'sorrend.dia';

  @override
  String get customOrderEditTitle => 'Sajat sorrend szerkesztese';

  @override
  String get addSong => 'Enek hozzaadasa';

  @override
  String get searchSongHint => 'Kötet vagy enekcim';

  @override
  String get textSlideDialogTitle => 'Szoveges dia hozzaadasa';

  @override
  String get textSlideTitleLabel => 'Cim';

  @override
  String get textSlideBodyLabel => 'Szoveg (soronként)';

  @override
  String get loadDia => 'Betoltes .DIA';

  @override
  String get saveDia => 'Mentes .DIA';

  @override
  String savedPath(Object path) {
    return 'Mentve: $path';
  }

  @override
  String loadedCount(int count) {
    return 'Betoltve: $count elem';
  }

  @override
  String get customOrderEmpty =>
      'A sorrend ures.\nKeress enekeket a szerkeszteshez.';

  @override
  String get versePicker => 'Versszak';

  @override
  String get selectedVersesTitle => 'Kivalasztott versszakok';

  @override
  String get selectedVersesSubtitle => 'Tobbet is kijelolhetsz.';

  @override
  String get apply => 'Alkalmaz';
}
