// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Diatar';

  @override
  String get viewTooltip => 'View';

  @override
  String get viewSimple => 'Simple';

  @override
  String get viewSpontaneous => 'Spontaneous';

  @override
  String get viewOrder => 'Order';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get playlistsTooltip => 'Playlists';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsMessage =>
      'This action can get back the full dialog later.';

  @override
  String get customOrderTooltip => 'Custom order';

  @override
  String get downloadBooksTooltip => 'Download songbooks';

  @override
  String get downloadTitle => 'Download';

  @override
  String get downloadMessage => 'The download dialog can be restored later.';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get ok => 'OK';

  @override
  String get songPrev => 'Song -';

  @override
  String get songNext => 'Song +';

  @override
  String get projectionOn => 'Projection ON';

  @override
  String get projectionOff => 'Projection OFF';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get highlightPrev => 'Highlight -';

  @override
  String get highlightNext => 'Highlight +';

  @override
  String positionLabel(int current, int total) {
    return 'Position: $current/$total';
  }

  @override
  String statusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get statusStarting => 'Starting...';

  @override
  String statusSenderError(Object message) {
    return '$message';
  }

  @override
  String statusSenderTcpError(Object error) {
    return 'TCP error: $error';
  }

  @override
  String statusSenderOpenPortFailed(int port, Object error) {
    return 'Failed to open port ($port): $error';
  }

  @override
  String get statusSenderMqttConnectFailed => 'MQTT sender connection failed.';

  @override
  String statusSenderMqttError(Object error) {
    return 'MQTT sender error: $error';
  }

  @override
  String statusMqttSending(Object user, Object channel) {
    return 'MQTT send: $user/$channel';
  }

  @override
  String statusTcpSending(int port) {
    return 'TCP send: $port';
  }

  @override
  String statusNoDtxFiles(Object path) {
    return 'No .dtx files: $path';
  }

  @override
  String get statusAllSongbooksDisabled =>
      'All songbooks are disabled in order settings.';

  @override
  String statusSongbooksLoaded(int count) {
    return '$count songbooks loaded';
  }

  @override
  String statusLoadError(Object error) {
    return 'Load error: $error';
  }

  @override
  String statusCustomOrderSelected(Object label) {
    return 'Custom order: $label';
  }

  @override
  String statusOrderSaved(Object path) {
    return 'Order saved: $path';
  }

  @override
  String statusDiaFileMissing(Object path) {
    return 'No such .DIA file: $path';
  }

  @override
  String statusOrderLoaded(int count, Object path) {
    return 'Order loaded ($count items): $path';
  }

  @override
  String get statusDownloadListLoading => 'Loading songbook update list...';

  @override
  String statusDownloadProgress(
    int current,
    int total,
    Object name,
    int percent,
  ) {
    return 'Download: $current/$total $name $percent%';
  }

  @override
  String get statusDownloadSummaryNone => 'No new songbook updates.';

  @override
  String statusDownloadSummary(int downloaded, int skipped) {
    return '$downloaded files downloaded, $skipped unchanged.';
  }

  @override
  String statusDownloadError(Object error) {
    return 'Download error: $error';
  }

  @override
  String statusBookSelected(Object name) {
    return 'Book: $name';
  }

  @override
  String statusSongPicked(Object name) {
    return 'Song: $name';
  }

  @override
  String statusVersePicked(Object name) {
    return 'Verse: $name';
  }

  @override
  String statusSongSelected(Object title) {
    return 'Song: $title';
  }

  @override
  String statusSongVerseSelected(Object title) {
    return 'Song/verse: $title';
  }

  @override
  String get statusProjectionOn => 'Projection: ON';

  @override
  String get statusProjectionOff => 'Projection: OFF';

  @override
  String get statusImagePathEmpty => 'Image file path is empty.';

  @override
  String statusImageNotFound(Object path) {
    return 'Image file not found: $path';
  }

  @override
  String statusImageSent(Object name) {
    return 'Image sent: $name';
  }

  @override
  String statusImageSendError(Object error) {
    return 'Image send error: $error';
  }

  @override
  String get statusBlankPathEmpty => 'Blank image file path is empty.';

  @override
  String statusBlankNotFound(Object path) {
    return 'Blank image file not found: $path';
  }

  @override
  String statusBlankSet(Object name) {
    return 'Blank image set: $name';
  }

  @override
  String statusBlankSendError(Object error) {
    return 'Blank image send error: $error';
  }

  @override
  String get statusBlankCleared => 'Blank image cleared.';

  @override
  String statusBlankClearError(Object error) {
    return 'Blank image clear error: $error';
  }

  @override
  String get statusShutdownCommandSent => 'Shutdown command sent.';

  @override
  String get statusStopCommandSent => 'Stop command sent.';

  @override
  String statusCommandSendError(Object error) {
    return 'Command send error: $error';
  }

  @override
  String sendStatusLabel(
    Object protocol,
    Object senderState,
    Object clientState,
  ) {
    return 'Sender ($protocol): $senderState, client: $clientState';
  }

  @override
  String get protocolMqtt => 'MQTT';

  @override
  String get protocolTcp => 'TCP';

  @override
  String get senderStateActive => 'active';

  @override
  String get senderStateOff => 'off';

  @override
  String get clientStateConnected => 'connected';

  @override
  String get clientStateWaiting => 'waiting';

  @override
  String tcpPortLabel(int port) {
    return 'TCP port: $port';
  }

  @override
  String downloadProgress(int current, int total, Object name) {
    return 'Download: $current/$total $name';
  }

  @override
  String get noLoadedSlide => 'No slide loaded.';

  @override
  String get bookLabel => 'Book';

  @override
  String get songLabel => 'Song';

  @override
  String get verseLabel => 'Verse';

  @override
  String versePanelTitle(Object title, Object verse) {
    return '$title: $verse';
  }

  @override
  String get searchLabel => 'Slide search';

  @override
  String get searchHint => 'Book or song title';

  @override
  String get noResults => 'No results.';

  @override
  String customOrderStatus(Object state) {
    return 'Custom order: $state';
  }

  @override
  String get stateActive => 'Active';

  @override
  String get stateInactive => 'Inactive';

  @override
  String get nextShort => 'Next';

  @override
  String get previewTitle => 'Slide preview';

  @override
  String get projectedImage => 'Projected image:';

  @override
  String get settingsTitle => 'Diatar settings';

  @override
  String get settingsTitleReceiver => 'Settings';

  @override
  String get modeIp => 'IP';

  @override
  String get modeInternet => 'Internet';

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
  String get tcpPortRange => 'TCP port (0..65535)';

  @override
  String get mqttUserHint => 'MQTT user (empty = TCP mode)';

  @override
  String get mqttPassword => 'MQTT password';

  @override
  String get mqttChannel => 'MQTT channel';

  @override
  String get dtxFolderPath => 'DTX folder';

  @override
  String get blankImagePath => 'Blank image path';

  @override
  String get fileChoose => 'Choose file';

  @override
  String get projectionSettingsTitle => 'Projection settings';

  @override
  String get fontSize => 'Font size';

  @override
  String get titleSize => 'Title size';

  @override
  String get leftMargin => 'Left margin';

  @override
  String get borderLeft => 'Border L';

  @override
  String get borderTop => 'Border T';

  @override
  String get borderRight => 'Border R';

  @override
  String get borderBottom => 'Border B';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get kottaScale => 'Music notation scale';

  @override
  String get chordScale => 'Chord scale';

  @override
  String get backgroundMode => 'Background image mode';

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
  String get backgroundOpacity => 'Background opacity';

  @override
  String get blankOpacity => 'Blank opacity';

  @override
  String get autoSize => 'Auto sizing';

  @override
  String get showTitle => 'Show title';

  @override
  String get hCenter => 'Horizontal center align';

  @override
  String get vCenter => 'Vertical center align';

  @override
  String get showChords => 'Show chords';

  @override
  String get showKotta => 'Show notation';

  @override
  String get boldText => 'Bold text';

  @override
  String get colorsTitle => 'Colors';

  @override
  String get backgroundColor => 'Background';

  @override
  String get textColor => 'Text';

  @override
  String get emptySlideColor => 'Empty slide';

  @override
  String get highlightColor => 'Highlight';

  @override
  String get backgroundColorTitle => 'Background color';

  @override
  String get textColorTitle => 'Text color';

  @override
  String get emptySlideColorTitle => 'Empty slide color';

  @override
  String get highlightColorTitle => 'Highlight color';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get invalidPortRange => 'Port must be between 0 and 65535.';

  @override
  String get hexColorHint => 'Hex color (#AARRGGBB or #RRGGBB)';

  @override
  String get close => 'Close';

  @override
  String get imagesFileTypeLabel => 'images';

  @override
  String get diatarPlaylistFileTypeLabel => 'Diatar playlist';

  @override
  String get customOrderSuggestedFileName => 'order.dia';

  @override
  String get customOrderEditTitle => 'Edit custom order';

  @override
  String get addSong => 'Add song';

  @override
  String get searchSongHint => 'Book or song title';

  @override
  String get loadDia => 'Load .DIA';

  @override
  String get saveDia => 'Save .DIA';

  @override
  String savedPath(Object path) {
    return 'Saved: $path';
  }

  @override
  String loadedCount(int count) {
    return 'Loaded: $count items';
  }

  @override
  String get customOrderEmpty =>
      'The order is empty.\nSearch songs to edit it.';

  @override
  String get versePicker => 'Verse';

  @override
  String get selectedVersesTitle => 'Selected verses';

  @override
  String get selectedVersesSubtitle => 'You can select multiple.';

  @override
  String get apply => 'Apply';
}
