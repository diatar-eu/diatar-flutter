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
  String get settingsTooltip => 'Settings';

  @override
  String get playlistsTooltip => 'Playlists';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get customOrderTooltip => 'Slide list';

  @override
  String get zsolozsmaTooltip => 'Liturgy of the Hours';

  @override
  String get zsolozsmaTitle => 'Select Liturgy of the Hours';

  @override
  String get zsolozsmaDateLabel => 'Date';

  @override
  String get zsolozsmaPickDate => 'Pick date';

  @override
  String get zsolozsmaSyncButton => 'Sync yearly ZIPs';

  @override
  String get zsolozsmaNoItems => 'No dayparts are available for this date.';

  @override
  String get zsolozsmaDiagnosticsLabel => 'Diagnostics';

  @override
  String get zsolozsmaSelectionHint =>
      'Selection currently loads and picks an item only. Slide splitting comes in the next step.';

  @override
  String get batyuTooltip => 'Daily readings (in Hungarian)';

  @override
  String get batyuTitle => 'Import Daily readings (in Hungarian)';

  @override
  String get batyuDateLabel => 'Date';

  @override
  String get batyuWordsPerSlide => 'Words per slide';

  @override
  String get batyuNoItems => 'No readings are available for this date.';

  @override
  String batyuBookLabel(Object name) {
    return 'Daily reading ($name)';
  }

  @override
  String get addSlideTooltip => 'Add slide';

  @override
  String get addTextSlide => 'Text slide';

  @override
  String get addImageSlide => 'Image slide';

  @override
  String get addImageSlideTooltip => 'Add image';

  @override
  String get downloadBooksTooltip => 'Download songbooks';

  @override
  String get downloadDtz => 'Download DTZ';

  @override
  String get downloadDtzTitle => 'Download DTX scores (DTZ)';

  @override
  String get downloadDtzHint =>
      'Select the DTZ files to download and the related images (zip).';

  @override
  String get downloadDtzWithImages => 'Images (zip) too';

  @override
  String downloadDtzCount(int count) {
    return '$count selected';
  }

  @override
  String get downloadDtzNoItems => 'No downloadable DTZ files.';

  @override
  String get downloadTabDtx => 'Volumes';

  @override
  String get downloadTabDtz => 'Scores';

  @override
  String get downloadTitle => 'Download';

  @override
  String get downloadManagerNameColumn => 'Volumes';

  @override
  String get downloadManagerUpdateColumn => 'Update';

  @override
  String get downloadManagerExcludedColumn => 'Excluded';

  @override
  String get downloadManagerUserImportedTag => 'User imported';

  @override
  String get downloadManagerUpdateAvailable => 'Update available';

  @override
  String get downloadManagerUpToDate => 'Up to date';

  @override
  String get downloadUserImportedGroup => 'User';

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
  String get hideControlWindow => 'Hide control window';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get highlightPrev => 'Word highlight ←';

  @override
  String get highlightNext => 'Word highlight →';

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
  String statusZsolozsmaSyncOk(int downloaded, int failed) {
    return 'Zsolozsma ZIP sync: $downloaded downloaded, $failed failed.';
  }

  @override
  String statusZsolozsmaSyncError(Object error) {
    return 'Zsolozsma ZIP sync error: $error';
  }

  @override
  String statusZsolozsmaDayLoaded(int count, Object date) {
    return 'Zsolozsma list loaded ($count) - $date';
  }

  @override
  String statusZsolozsmaDayEmpty(Object date) {
    return 'No zsolozsma list for this date: $date';
  }

  @override
  String statusZsolozsmaDayError(Object error) {
    return 'Zsolozsma list error: $error';
  }

  @override
  String statusZsolozsmaPartSelected(Object date, Object title) {
    return 'Zsolozsma selected ($date): $title';
  }

  @override
  String statusZsolozsmaPartLoaded(int count, Object date, Object title) {
    return 'Zsolozsma loaded ($count slides) - $date: $title';
  }

  @override
  String statusZsolozsmaPartLoadError(Object title) {
    return 'Failed to load selected zsolozsma part: $title';
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
  String get statusCustomTextEmpty => 'Provide a title or at least one line.';

  @override
  String statusCustomTextSent(Object title) {
    return 'Text slide sent: $title';
  }

  @override
  String statusCustomTextError(Object error) {
    return 'Text slide send error: $error';
  }

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
  String get statusBlankPathEmpty => 'Background image file path is empty.';

  @override
  String statusBlankNotFound(Object path) {
    return 'Background image file not found: $path';
  }

  @override
  String statusBlankSet(Object name) {
    return 'Background image set: $name';
  }

  @override
  String statusBlankSendError(Object error) {
    return 'Background image send error: $error';
  }

  @override
  String get statusBlankCleared => 'Background image cleared.';

  @override
  String statusBlankClearError(Object error) {
    return 'Background image clear error: $error';
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
  String get homeControlModeTooltip => 'Screen mode';

  @override
  String get homeControlModeBooks => 'Books';

  @override
  String get homeControlModeDialist => 'Slide list';

  @override
  String get homeControlModePresentation => 'Presentation';

  @override
  String dialistNamedLabel(Object name) {
    return 'Slide list: $name';
  }

  @override
  String get bookLabel => 'Book';

  @override
  String get ungroupedBookGroupLabel => '(unclassified)';

  @override
  String diaBookLabel(Object name) {
    return 'DIA: $name';
  }

  @override
  String zsolozsmaBookLabel(Object name) {
    return 'Liturgy: $name';
  }

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
  String get searchHint => 'Book, song title or lyric';

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
  String customTextEntryLabel(Object name) {
    return 'Slide: $name';
  }

  @override
  String customImageEntryLabel(Object name) {
    return 'Image: $name';
  }

  @override
  String get projectedImage => 'Projected image:';

  @override
  String get settingsTitle => 'Diatar settings';

  @override
  String get settingsTitleReceiver => 'Settings';

  @override
  String settingsVersionLabel(Object version, Object buildNumber) {
    return 'Version $version ($buildNumber)';
  }

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
  String get internetRelayQrButton => 'QR code';

  @override
  String get internetRelayQrTitle => 'DiaVetito QR code';

  @override
  String get internetRelayQrHint =>
      'Scan this QR code to quickly open the web DiaVetito receiver.';

  @override
  String get internetRelayLinkLabel => 'Open link';

  @override
  String get internetRelayCopyLink => 'Copy link';

  @override
  String get internetRelayLinkCopied => 'Link copied to clipboard';

  @override
  String get internetRelaySaveQrImage => 'Save QR as PNG';

  @override
  String internetRelayQrSaved(Object fileName) {
    return 'QR image saved: $fileName';
  }

  @override
  String internetRelayQrSaveFailed(Object error) {
    return 'Failed to save QR image: $error';
  }

  @override
  String get uiTheme => 'User interface theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get blankImagePath => 'Background image path';

  @override
  String get diaExportFolderPath => 'DIA export folder';

  @override
  String get fileChoose => 'Choose file';

  @override
  String get openDtxFolder => 'Open Diatár files';

  @override
  String get openDtxFolderTooltip =>
      'Open the folder containing the Diatár files';

  @override
  String get copyPathTooltip => 'Copy original path';

  @override
  String get pathCopied => 'Original path copied';

  @override
  String get pathLabelInternalStorage => 'Internal storage';

  @override
  String get pathSegmentDocuments => 'Documents';

  @override
  String get pathSegmentDownloads => 'Downloads';

  @override
  String get pathSegmentCamera => 'Camera';

  @override
  String get pathSegmentPictures => 'Pictures';

  @override
  String get pathSegmentMusic => 'Music';

  @override
  String get pathSegmentMovies => 'Movies';

  @override
  String get uiLanguage => 'User interface language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageHungarian => 'Hungarian';

  @override
  String get languageEnglish => 'English';

  @override
  String get projectionSettingsTitle => 'Projection settings';

  @override
  String get fontSize => 'Font size';

  @override
  String get titleSize => 'Title size';

  @override
  String get leftMargin => 'Indentation';

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
  String get blankOpacity => 'Background image opacity';

  @override
  String get autoSize => 'Auto sizing';

  @override
  String get scrollableProjection => 'Scrollable projection';

  @override
  String get scrollableProjectionHint =>
      'If turned off, text is auto-sized to fit the projection area.';

  @override
  String get showTitle => 'Show title';

  @override
  String get projectionLock => 'Lock projection';

  @override
  String get projectionUnlock => 'Unlock projection';

  @override
  String get hCenter => 'Horizontal center align';

  @override
  String get vCenter => 'Vertical center align';

  @override
  String get showChords => 'Show chords';

  @override
  String get showKotta => 'Show notation';

  @override
  String get showBackgroundImage => 'Show background image';

  @override
  String get wordHighlight => 'Word highlight';

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
  String get customOrderEditTitle => 'Slide list';

  @override
  String get customOrderGroupReorder => 'Group reordering';

  @override
  String get addSong => 'Add song';

  @override
  String get searchSongHint => 'Book, song title or lyric';

  @override
  String get customOrderInsertBookLabel => 'Book';

  @override
  String get customOrderInsertSongLabel => 'Song';

  @override
  String get customOrderInsertVersesAction => 'Insert verses';

  @override
  String get customOrderInsertSeparatorAction => 'Insert separator';

  @override
  String get customOrderClearAllTooltip => 'Clear all';

  @override
  String get customOrderClearAllConfirmTitle => 'Confirmation';

  @override
  String get customOrderClearAllConfirmMessage =>
      'Are you sure you want to delete the entire custom slide order?';

  @override
  String get customOrderClearAllConfirmButton => 'Clear all';

  @override
  String get customOrderSeparatorNameLabel => 'Separator name';

  @override
  String get customOrderSeparatorDefaultName => 'separator';

  @override
  String get customOrderInsertVersesTitle => 'Verses to insert';

  @override
  String get customOrderInsertVersesSubtitle =>
      'Select which verses should be added to the order.';

  @override
  String get textSlideDialogTitle => 'Add text slide';

  @override
  String get textSlideTitleLabel => 'Title';

  @override
  String get textSlideBodyLabel => 'Text (one line per row)';

  @override
  String get loadDia => 'Load';

  @override
  String get saveDia => 'Save';

  @override
  String get customOrderSaveDiaErrorTitle => 'Save failed';

  @override
  String get customOrderSaveDiaPermissionDenied =>
      'The selected folder exists, but Android denied write access. On newer Android versions, direct file write to shared folders (for example /Internal storage/Diatar) may be blocked by scoped storage, even if the folder can be selected. Please choose a location offered by the system save dialog or an app-specific folder.';

  @override
  String customOrderSaveDiaGenericError(Object error) {
    return 'Could not save DIA file. Details: $error';
  }

  @override
  String get customOrderDiaFileNameLabel => 'File name';

  @override
  String get customOrderUnnamedFileName => 'Unnamed';

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
  String get customOrderSelectAllVerses => 'Select all';

  @override
  String get customOrderClearVerseSelection => 'Clear';

  @override
  String get customOrderSetsSection => 'Custom orders';

  @override
  String get customOrderSetSelectorLabel => 'Active custom order';

  @override
  String get customOrderSetActive => 'Active';

  @override
  String get customOrderSetEmpty => 'Empty custom order';

  @override
  String customOrderSetEntryCount(int count) {
    return '$count items';
  }

  @override
  String get customOrderSetRename => 'Rename';

  @override
  String get customOrderSetRemove => 'Remove';

  @override
  String get customOrderSetRenameTitle => 'Rename custom order';

  @override
  String get customOrderSetRemoveConfirm => 'Remove this custom order?';

  @override
  String get customOrderSetToggleEnabledTooltip =>
      'Enable or disable the custom order (a disabled one is hidden from the views)';

  @override
  String get customOrderSetCreate => 'New custom order';

  @override
  String get customOrderSetCreateTitle => 'Create new custom order';

  @override
  String get customOrderSetCreateNameLabel => 'Custom order name';

  @override
  String get customOrderLoadModeTitle => 'Load custom order';

  @override
  String get customOrderLoadModeOverwrite => 'Overwrite the current one';

  @override
  String get customOrderLoadModeAdd => 'Load alongside (parallel)';

  @override
  String get customOrderLoadModeMessage =>
      'How should the selected custom order be loaded?';

  @override
  String get volumeListTitle => 'Volume list';

  @override
  String get apply => 'Apply';

  @override
  String get internetUserActionsTitle => 'User actions (API)';

  @override
  String get internetStatusOn => 'On';

  @override
  String get internetStatusOff => 'Off';

  @override
  String get internetStatusConnecting => 'Connecting';

  @override
  String get internetStatusError => 'Error';

  @override
  String connectionStatusTooltip(Object name, Object status) {
    return '$name: $status';
  }

  @override
  String get valueNotSet => '-';

  @override
  String get tcpNoTargets => 'No targets';

  @override
  String tcpTargetsCount(int count) {
    return '$count targets';
  }

  @override
  String get settingsSearchLabel => 'Search in settings';

  @override
  String get settingsInternetTitle => 'Internet';

  @override
  String settingsInternetSubtitle(Object status, Object user) {
    return 'Internet relay: $status, user: $user';
  }

  @override
  String get settingsLocalNetworkTitle => 'Local network (TCP/IP)';

  @override
  String settingsLocalNetworkSubtitle(Object status, Object summary) {
    return 'TCP client: $status, targets: $summary';
  }

  @override
  String settingsColorSummary(Object background, Object text) {
    return 'Background: $background, Text: $text';
  }

  @override
  String settingsProjectionSummary(Object font, Object title) {
    return 'Font: ${font}px, Title: ${title}px';
  }

  @override
  String get settingsFilesTitle => 'Songbooks and files';

  @override
  String settingsFilesSummary(Object blank) {
    return 'Background image: $blank';
  }

  @override
  String get importDtxFilesButton => 'Import from file';

  @override
  String get importDtzFilesButton => 'Import scores';

  @override
  String get importDtzPreviewTitle => 'Import scores';

  @override
  String get importDtzDtzSection => 'DTZ file';

  @override
  String get importDtzZipSection => 'ZIP files (images, sounds)';

  @override
  String get importDtzNoDtzSelected => 'No DTZ file selected';

  @override
  String get importDtzSelectDtz => 'Select DTZ';

  @override
  String get importDtzAddZip => 'Add ZIP files';

  @override
  String get importDtzValidateButton => 'Validate';

  @override
  String get importDtzPreviewNoDtz =>
      'No .dtz file selected. Please select at least one DTZ file!';

  @override
  String importDtzPreviewOrphanZips(int count) {
    return '$count ZIP file(s) cannot be paired with a DTZ.';
  }

  @override
  String importDtzStatusOk(int matched) {
    return 'Importable – $matched media file(s) OK';
  }

  @override
  String get importDtzStatusNoRefs => 'Importable – no media files referenced';

  @override
  String importDtzStatusWarning(int missing, int total) {
    return 'Importable (with warning) – $missing/$total media file(s) missing';
  }

  @override
  String importDtzStatusError(int missing, int total) {
    return 'Not importable – $missing/$total media file(s) missing';
  }

  @override
  String get importDtzStatusParseError => 'Not importable – invalid DTZ file';

  @override
  String importDtzStatusMissingDiaIds(Object reason) {
    return 'Not importable – unknown dia-IDs in DTZ: $reason';
  }

  @override
  String get importDtzImportButton => 'Import';

  @override
  String importDtzSuccess(int dtz, int files) {
    return '$dtz DTZ file(s) imported, $files media file(s) extracted';
  }

  @override
  String importDtzSuccessNoMedia(int dtz) {
    return '$dtz DTZ file(s) imported';
  }

  @override
  String importDtzError(Object reason) {
    return 'Error importing score(s): $reason';
  }

  @override
  String importDtxFilesSuccess(int count) {
    return '$count .dtx file(s) imported';
  }

  @override
  String get importDtxFilesError => 'Error importing .dtx file(s)';

  @override
  String importDtxFilesErrorDetailed(Object reason) {
    return 'Error importing .dtx file(s): $reason';
  }

  @override
  String importDtxFilesPartial(int count, int failed, Object reason) {
    return '$count .dtx file(s) imported, $failed failed: $reason';
  }

  @override
  String get settingsGeneralTitle => 'General';

  @override
  String settingsGeneralSummary(Object theme, Object language) {
    return 'Theme: $theme, Language: $language';
  }

  @override
  String get systemActionsTitle => 'System actions';

  @override
  String get systemActionsSummary =>
      'Exit, refresh, remote program stop, remote machine stop';

  @override
  String get systemActionsBack => 'Back';

  @override
  String get localExit => 'Exit';

  @override
  String get remoteProgramStop => 'Remote program stop';

  @override
  String get remoteMachineStop => 'Remote machine stop';

  @override
  String get settingsHotkeysTitle => 'Hotkeys';

  @override
  String get settingsHotkeysSummary =>
      'Controller actions and song assignment to keys';

  @override
  String get settingsDesktopHotkeysTitle => 'Hotkeys (desktop)';

  @override
  String get settingsHotkeysActionsSectionTitle => 'Controller actions';

  @override
  String get settingsHotkeysSongsSectionTitle => 'Song to hotkey';

  @override
  String get settingsHotkeysNoSongs =>
      'No songs loaded, so assignment is not available.';

  @override
  String get settingsHotkeyActionHint => 'e.g. Ctrl+Right or F8';

  @override
  String get settingsHotkeyFieldLabel => 'Hotkey';

  @override
  String get settingsHotkeySongHint => 'e.g. Ctrl+1 or F2';

  @override
  String get settingsHotkeyAssign => 'Assign';

  @override
  String get settingsHotkeyDelete => 'Delete';

  @override
  String get settingsHotkeyActionPrevSong => 'Previous song';

  @override
  String get settingsHotkeyActionPrevVerse => 'Previous verse';

  @override
  String get settingsHotkeyActionToggleProjection => 'Toggle projection';

  @override
  String get settingsHotkeyActionNextVerse => 'Next verse';

  @override
  String get settingsHotkeyActionNextSong => 'Next song';

  @override
  String get settingsHotkeyActionPrevOrderSet => 'Previous custom order';

  @override
  String get settingsHotkeyActionNextOrderSet => 'Next custom order';

  @override
  String get settingsHotkeyActionHighlightPrev => 'Highlight previous word';

  @override
  String get settingsHotkeyActionHighlightNext => 'Highlight next word';

  @override
  String get settingsHotkeyActionTogglePhoto => 'Toggle photo';

  @override
  String get settingsHotkeyActionToggleChords => 'Toggle chords';

  @override
  String get settingsHotkeyActionToggleBackground => 'Toggle background';

  @override
  String get settingsHotkeyActionToggleSheetMusic => 'Toggle sheet music';

  @override
  String get settingsDesktopOrderSetHotkeysTitle => 'Order set hotkeys';

  @override
  String get settingsOrderSetLabel => 'Order set';

  @override
  String get settingsHotkeysNoOrderSets =>
      'No order sets loaded, so assignment is not available.';

  @override
  String get settingsHotkeysOrderSetExistingTitle => 'Existing bindings';

  @override
  String get settingsOrderSetPickerTitle => 'Select order set';

  @override
  String settingsHotkeyConflict(Object hotkey) {
    return 'Conflicting hotkey: $hotkey';
  }

  @override
  String get settingsNoResults => 'No results for the search.';

  @override
  String get internetRelaySwitchTitle => 'Internet relay';

  @override
  String get localNetworkRelaySwitchTitle => 'Local network (TCP/IP)';

  @override
  String get passwordHideTooltip => 'Hide';

  @override
  String get passwordShowTooltip => 'Show';

  @override
  String get tcpTargetsLabel => 'Targets (IP:port per line)';

  @override
  String get tcpTargetsHint => '192.168.1.50:1024\n192.168.1.51:1024';

  @override
  String get tcpTargetsHelp =>
      'The sender connects as a client to the addresses above.';

  @override
  String get projectionMarginsTitle => 'Margins';

  @override
  String get projectionMarginLeft => 'Left margin';

  @override
  String get projectionMarginRight => 'Right margin';

  @override
  String get projectionMarginTop => 'Top margin';

  @override
  String get projectionMarginBottom => 'Bottom margin';

  @override
  String get projectorMonitor => 'Projector display';

  @override
  String get projectorEnabled => 'Use projector window';

  @override
  String get projectorEnabledHint =>
      'Projects in a separate window on desktop. When off, the app acts only as a controller without a projector window.';

  @override
  String get projectorMonitorAuto => 'Automatic (last display)';

  @override
  String projectorMonitorIndex(int index, Object size) {
    return 'Display $index ($size)';
  }

  @override
  String projectorMonitorIndexShort(int index) {
    return 'Display $index';
  }

  @override
  String tcpInvalidTargetFormat(Object target) {
    return 'Invalid target format: $target';
  }

  @override
  String get userActionRegister => 'Register';

  @override
  String get userActionResendVerification => 'Resend e-mail';

  @override
  String get userActionForgotPassword => 'Forgot password';

  @override
  String get userActionDeleteUser => 'Delete user';

  @override
  String get userActionChangePassword => 'Change password';

  @override
  String get userActionChangeEmail => 'Change e-mail';

  @override
  String get userActionChangeUsername => 'Change username';

  @override
  String get userFieldUsername => 'Username';

  @override
  String get userFieldPassword => 'Password';

  @override
  String get userFieldEmail => 'E-mail';

  @override
  String get userFieldCurrentPassword => 'Current password';

  @override
  String get userFieldNewPassword => 'New password';

  @override
  String get userFieldNewEmail => 'New e-mail';

  @override
  String get userFieldCurrentUsername => 'Current username';

  @override
  String get userFieldNewUsername => 'New username';

  @override
  String get userActionRegisterSuccess =>
      'Registration successful. Please check your e-mail inbox to complete verification.';

  @override
  String get userActionResendVerificationSuccess =>
      'Verification e-mail resent. Please check your e-mails.';

  @override
  String get userActionForgotPasswordSuccess =>
      'If the account exists, a password reset e-mail has been sent.';

  @override
  String get userActionValidationRequiredFields =>
      'Username and e-mail are required.';

  @override
  String get userActionValidationRequiredPasswordFields =>
      'Username, current password and new password are required.';

  @override
  String get userActionValidationRequiredChangeEmailFields =>
      'Username, current password and new e-mail are required.';

  @override
  String get userActionValidationRequiredChangeUsernameFields =>
      'Current username, password and new username are required.';

  @override
  String get userActionValidationInvalidEmail => 'Invalid e-mail address.';

  @override
  String get userActionDeleteUserSuccess => 'User deleted.';

  @override
  String get userActionChangePasswordSuccess =>
      'Password changed successfully.';

  @override
  String get userActionChangeEmailSuccess =>
      'E-mail change request sent. Please check your e-mail inbox to complete verification.';

  @override
  String get userActionChangeUsernameSuccess => 'Username changed.';

  @override
  String get userDeleteConfirmTitle => 'Confirmation';

  @override
  String get userDeleteConfirmMessage =>
      'Are you sure you want to delete this user? This action cannot be undone.';

  @override
  String get userDeleteConfirmButton => 'Delete';

  @override
  String userApiError(Object error) {
    return 'API error: $error';
  }

  @override
  String get userApiUnauthorized =>
      'Authentication failed. Check the username and password.';

  @override
  String get userApiUnknownError => 'Unexpected API error.';

  @override
  String get settingsHotkeyPressAnyKey => 'Press any key combination...';

  @override
  String get settingsHotkeyDialogTitle => 'Capture Hotkey';

  @override
  String get settingsHotkeyConfirm => 'Confirm';

  @override
  String get settingsHotkeyClearCapture => 'Clear';

  @override
  String get settingsHotkeyClear => 'Clear';

  @override
  String get settingsHotkeyCapture => 'Capture';

  @override
  String get settingsSearchKeywordsSystem =>
      'system exit stop shutdown epstop epshutdown';

  @override
  String get controlPhotoView => 'Toggle photo / projection';

  @override
  String get controlPhotoViewPhoto => 'Photo view';

  @override
  String get controlPhotoViewPreview => 'Projection preview';

  @override
  String get useSound => 'Use sound';

  @override
  String get castSettingsTitle => 'Google Cast settings';

  @override
  String get castSettingsSummary => 'Configure Cast devices';

  @override
  String get castEnabledTitle => 'Use Cast';

  @override
  String get castDeviceIdLabel => 'Cast device ID';

  @override
  String get castPortLabel => 'Cast port';

  @override
  String get castAutoConnectTitle => 'Auto-connect';

  @override
  String get castSelectDeviceTitle => 'Select Cast Device';

  @override
  String get castNoDevicesFound => 'No Cast devices found';

  @override
  String get castConnecting => 'Connecting...';

  @override
  String get transposeDown => 'Transpose down';

  @override
  String get transposeUp => 'Transpose up';

  @override
  String get transposeReset => 'Reset transpose';

  @override
  String get diatarDataTransferTitle => 'Backup';

  @override
  String get diatarDataTransferDescription =>
      'Export the complete internal diatar folder to a ZIP file or restore it from a ZIP file.';

  @override
  String get diatarExportButton => 'Export';

  @override
  String get diatarImportButton => 'Import';

  @override
  String get diatarZipFileTypeLabel => 'Diatar backup';

  @override
  String diatarExportSuccess(Object fileName) {
    return 'Export completed: $fileName';
  }

  @override
  String diatarImportSuccess(int imported, int skipped) {
    return '$imported files imported, $skipped files skipped.';
  }

  @override
  String get diatarImportConflictTitle => 'Existing files';

  @override
  String diatarImportConflictMessage(int count) {
    return '$count files to import already exist. Should they be overwritten or skipped throughout this import?';
  }

  @override
  String get diatarImportOverwriteAll => 'Overwrite';

  @override
  String get diatarImportSkipAll => 'Skip';

  @override
  String get diatarExportSourceMissing =>
      'The internal diatar folder was not found.';

  @override
  String get diatarImportInvalidArchive =>
      'The selected file is not a valid Diatar backup.';

  @override
  String diatarTransferError(Object error) {
    return 'The operation failed: $error';
  }

  @override
  String get szentirasTooltip => 'Bible';

  @override
  String get szentirasTitle => 'Insert Bible verse';

  @override
  String get szentirasReferenceLabel => 'Reference';

  @override
  String get szentirasReferenceHint => 'e.g. 1Cor13,10-13';

  @override
  String get szentirasTranslationLabel => 'Translation';

  @override
  String get szentirasTranslationDefault => 'Default';

  @override
  String get szentirasFetchButton => 'Fetch';

  @override
  String get szentirasImportButton => 'Import';

  @override
  String szentirasInsertAll(int count) {
    return 'Insert all ($count verses)';
  }

  @override
  String get szentirasLoading => 'Loading…';

  @override
  String szentirasError(Object error) {
    return 'Error: $error';
  }

  @override
  String get szentirasNoVerses => 'No verses found.';

  @override
  String get settingsSzentirasApiKeyLabel => 'szentiras.eu API key';

  @override
  String get settingsSzentirasApiKeyHint => 'Key from szentiras.eu';

  @override
  String get szentirasApiKeyPrompt =>
      'Enter your szentiras.eu API key to use the Bible feature.';

  @override
  String get statusSzentirasApiKeyMissing => 'szentiras.eu API key is not set.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Diatar!';

  @override
  String get onboardingWelcomeBody =>
      'A church slide projector app.\n\nChoose a songbook, build a custom order, then send it to the projector.';

  @override
  String get onboardingPage2Title => 'Main Screen';

  @override
  String get onboardingPage2Body =>
      'Choose from three modes:\n\n• Books: browse songbooks, select song and verse\n• Slide list: build a custom slide order\n• Presentation: full-screen preview for projecting';

  @override
  String get onboardingPage3Title => 'Building a Slide List';

  @override
  String get onboardingPage3Body =>
      '1. Find songs in the Books mode\n2. Open the Slide List editor\n3. Add verses, text slides, separators\n4. Save as .dia file for later use';

  @override
  String get onboardingPage4Title => 'Special Features';

  @override
  String get onboardingPage4Body =>
      '• Liturgy of the Hours (Zsolozsma): daily liturgy slides\n• Daily Readings (Batyu): import daily readings\n• Bible Verses (Szentiras): insert scripture\n• Search: full-text search across songbooks\n• Hotkeys: keyboard shortcuts for desktop';

  @override
  String get onboardingGotIt => 'Got it, let\'s go!';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Done';

  @override
  String get settingsInternetDescription =>
      'Internet relay via MQTT. Create a user, then share the QR code with the remote DiaVetito receiver.';

  @override
  String get settingsLocalNetworkDescription =>
      'TCP/IP connection over your local network. Enter the projector\'s IP address and port.';

  @override
  String get castSettingsDescription =>
      'Send slides to a Google Cast device (Chromecast).';

  @override
  String get colorsDescription =>
      'Customize projection colors: background, text, empty slide, and highlight.';

  @override
  String get projectionSettingsDescription =>
      'Font size, margins, background image, alignment, and other projection parameters.';

  @override
  String get settingsFilesDescription =>
      'Import songbooks, DTZ scores, create and restore backups.';

  @override
  String get settingsGeneralDescription =>
      'Switch app theme (dark/light) and user interface language.';

  @override
  String get systemActionsDescription =>
      'Exit the app, reload songbooks, or stop/shutdown the remote projector.';

  @override
  String get settingsHotkeysDescription =>
      'Keyboard shortcuts for quick control on desktop.';

  @override
  String get settingsOnboardingButton => 'Getting started';
}
