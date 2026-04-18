import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In hu, this message translates to:
  /// **'Diatar'**
  String get appTitle;

  /// No description provided for @viewTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Nezet'**
  String get viewTooltip;

  /// No description provided for @viewSimple.
  ///
  /// In hu, this message translates to:
  /// **'Szimpla'**
  String get viewSimple;

  /// No description provided for @viewSpontaneous.
  ///
  /// In hu, this message translates to:
  /// **'Spontan'**
  String get viewSpontaneous;

  /// No description provided for @viewOrder.
  ///
  /// In hu, this message translates to:
  /// **'Sorrend'**
  String get viewOrder;

  /// No description provided for @settingsTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Beallitasok'**
  String get settingsTooltip;

  /// No description provided for @playlistsTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Enekrendek'**
  String get playlistsTooltip;

  /// No description provided for @playlistsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Enekrendek'**
  String get playlistsTitle;

  /// No description provided for @playlistsMessage.
  ///
  /// In hu, this message translates to:
  /// **'Ez a muvelet kesobb visszakaphatja a teljes dialogust.'**
  String get playlistsMessage;

  /// No description provided for @customOrderTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Sajat sorrend'**
  String get customOrderTooltip;

  /// No description provided for @addSlideTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Dia hozzaadasa'**
  String get addSlideTooltip;

  /// No description provided for @addTextSlide.
  ///
  /// In hu, this message translates to:
  /// **'Szoveges dia'**
  String get addTextSlide;

  /// No description provided for @addImageSlide.
  ///
  /// In hu, this message translates to:
  /// **'Kepes dia'**
  String get addImageSlide;

  /// No description provided for @downloadBooksTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Enektarak letoltese'**
  String get downloadBooksTooltip;

  /// No description provided for @downloadTitle.
  ///
  /// In hu, this message translates to:
  /// **'Letoltes'**
  String get downloadTitle;

  /// No description provided for @downloadMessage.
  ///
  /// In hu, this message translates to:
  /// **'A letoltesi parbeszed kesobb visszahelyezheto.'**
  String get downloadMessage;

  /// No description provided for @refreshTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Frissites'**
  String get refreshTooltip;

  /// No description provided for @ok.
  ///
  /// In hu, this message translates to:
  /// **'Rendben'**
  String get ok;

  /// No description provided for @songPrev.
  ///
  /// In hu, this message translates to:
  /// **'Ének -'**
  String get songPrev;

  /// No description provided for @songNext.
  ///
  /// In hu, this message translates to:
  /// **'Ének +'**
  String get songNext;

  /// No description provided for @projectionOn.
  ///
  /// In hu, this message translates to:
  /// **'Vetites BE'**
  String get projectionOn;

  /// No description provided for @projectionOff.
  ///
  /// In hu, this message translates to:
  /// **'Vetites KI'**
  String get projectionOff;

  /// No description provided for @previous.
  ///
  /// In hu, this message translates to:
  /// **'Elozo'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In hu, this message translates to:
  /// **'Kovetkezo'**
  String get next;

  /// No description provided for @highlightPrev.
  ///
  /// In hu, this message translates to:
  /// **'Highlight -'**
  String get highlightPrev;

  /// No description provided for @highlightNext.
  ///
  /// In hu, this message translates to:
  /// **'Highlight +'**
  String get highlightNext;

  /// No description provided for @positionLabel.
  ///
  /// In hu, this message translates to:
  /// **'Pozicio: {current}/{total}'**
  String positionLabel(int current, int total);

  /// No description provided for @statusLabel.
  ///
  /// In hu, this message translates to:
  /// **'Statusz: {status}'**
  String statusLabel(Object status);

  /// No description provided for @statusStarting.
  ///
  /// In hu, this message translates to:
  /// **'Inditas...'**
  String get statusStarting;

  /// No description provided for @statusSenderError.
  ///
  /// In hu, this message translates to:
  /// **'{message}'**
  String statusSenderError(Object message);

  /// No description provided for @statusSenderTcpError.
  ///
  /// In hu, this message translates to:
  /// **'TCP hiba: {error}'**
  String statusSenderTcpError(Object error);

  /// No description provided for @statusSenderOpenPortFailed.
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerult portot nyitni ({port}): {error}'**
  String statusSenderOpenPortFailed(int port, Object error);

  /// No description provided for @statusSenderMqttConnectFailed.
  ///
  /// In hu, this message translates to:
  /// **'MQTT sender kapcsolodas sikertelen.'**
  String get statusSenderMqttConnectFailed;

  /// No description provided for @statusSenderMqttError.
  ///
  /// In hu, this message translates to:
  /// **'MQTT sender hiba: {error}'**
  String statusSenderMqttError(Object error);

  /// No description provided for @statusMqttSending.
  ///
  /// In hu, this message translates to:
  /// **'MQTT kuldes: {user}/{channel}'**
  String statusMqttSending(Object user, Object channel);

  /// No description provided for @statusTcpSending.
  ///
  /// In hu, this message translates to:
  /// **'TCP kuldes: {port}'**
  String statusTcpSending(int port);

  /// No description provided for @statusNoDtxFiles.
  ///
  /// In hu, this message translates to:
  /// **'Nincs .dtx fajl: {path}'**
  String statusNoDtxFiles(Object path);

  /// No description provided for @statusAllSongbooksDisabled.
  ///
  /// In hu, this message translates to:
  /// **'Minden enektar le van tiltva az enekrendben.'**
  String get statusAllSongbooksDisabled;

  /// No description provided for @statusSongbooksLoaded.
  ///
  /// In hu, this message translates to:
  /// **'{count} kotet betoltve'**
  String statusSongbooksLoaded(int count);

  /// No description provided for @statusLoadError.
  ///
  /// In hu, this message translates to:
  /// **'Betoltesi hiba: {error}'**
  String statusLoadError(Object error);

  /// No description provided for @statusCustomOrderSelected.
  ///
  /// In hu, this message translates to:
  /// **'Sajat sorrend: {label}'**
  String statusCustomOrderSelected(Object label);

  /// No description provided for @statusOrderSaved.
  ///
  /// In hu, this message translates to:
  /// **'Sorrend mentve: {path}'**
  String statusOrderSaved(Object path);

  /// No description provided for @statusDiaFileMissing.
  ///
  /// In hu, this message translates to:
  /// **'Nincs ilyen .DIA fajl: {path}'**
  String statusDiaFileMissing(Object path);

  /// No description provided for @statusOrderLoaded.
  ///
  /// In hu, this message translates to:
  /// **'Sorrend betoltve ({count} elem): {path}'**
  String statusOrderLoaded(int count, Object path);

  /// No description provided for @statusDownloadListLoading.
  ///
  /// In hu, this message translates to:
  /// **'Enektar lista letoltese...'**
  String get statusDownloadListLoading;

  /// No description provided for @statusDownloadProgress.
  ///
  /// In hu, this message translates to:
  /// **'Letoltes: {current}/{total} {name} {percent}%'**
  String statusDownloadProgress(
    int current,
    int total,
    Object name,
    int percent,
  );

  /// No description provided for @statusDownloadSummaryNone.
  ///
  /// In hu, this message translates to:
  /// **'Nincs uj enektar frissites.'**
  String get statusDownloadSummaryNone;

  /// No description provided for @statusDownloadSummary.
  ///
  /// In hu, this message translates to:
  /// **'{downloaded} fajl letoltve, {skipped} valtozatlan.'**
  String statusDownloadSummary(int downloaded, int skipped);

  /// No description provided for @statusDownloadError.
  ///
  /// In hu, this message translates to:
  /// **'Letoltesi hiba: {error}'**
  String statusDownloadError(Object error);

  /// No description provided for @statusBookSelected.
  ///
  /// In hu, this message translates to:
  /// **'Kotet: {name}'**
  String statusBookSelected(Object name);

  /// No description provided for @statusSongPicked.
  ///
  /// In hu, this message translates to:
  /// **'Enek: {name}'**
  String statusSongPicked(Object name);

  /// No description provided for @statusVersePicked.
  ///
  /// In hu, this message translates to:
  /// **'Versszak: {name}'**
  String statusVersePicked(Object name);

  /// No description provided for @statusSongSelected.
  ///
  /// In hu, this message translates to:
  /// **'Enek: {title}'**
  String statusSongSelected(Object title);

  /// No description provided for @statusSongVerseSelected.
  ///
  /// In hu, this message translates to:
  /// **'Enek/versszak: {title}'**
  String statusSongVerseSelected(Object title);

  /// No description provided for @statusProjectionOn.
  ///
  /// In hu, this message translates to:
  /// **'Vetites: BE'**
  String get statusProjectionOn;

  /// No description provided for @statusProjectionOff.
  ///
  /// In hu, this message translates to:
  /// **'Vetites: KI'**
  String get statusProjectionOff;

  /// No description provided for @statusImagePathEmpty.
  ///
  /// In hu, this message translates to:
  /// **'A kep fajl utvonala ures.'**
  String get statusImagePathEmpty;

  /// No description provided for @statusCustomTextEmpty.
  ///
  /// In hu, this message translates to:
  /// **'Adj meg cimet vagy legalabb egy sort.'**
  String get statusCustomTextEmpty;

  /// No description provided for @statusCustomTextSent.
  ///
  /// In hu, this message translates to:
  /// **'Szoveges dia elkuldve: {title}'**
  String statusCustomTextSent(Object title);

  /// No description provided for @statusCustomTextError.
  ///
  /// In hu, this message translates to:
  /// **'Szoveges dia kuldesi hiba: {error}'**
  String statusCustomTextError(Object error);

  /// No description provided for @statusImageNotFound.
  ///
  /// In hu, this message translates to:
  /// **'A kep fajl nem talalhato: {path}'**
  String statusImageNotFound(Object path);

  /// No description provided for @statusImageSent.
  ///
  /// In hu, this message translates to:
  /// **'Kep elkuldve: {name}'**
  String statusImageSent(Object name);

  /// No description provided for @statusImageSendError.
  ///
  /// In hu, this message translates to:
  /// **'Kep kuldesi hiba: {error}'**
  String statusImageSendError(Object error);

  /// No description provided for @statusBlankPathEmpty.
  ///
  /// In hu, this message translates to:
  /// **'A blank kep fajl utvonala ures.'**
  String get statusBlankPathEmpty;

  /// No description provided for @statusBlankNotFound.
  ///
  /// In hu, this message translates to:
  /// **'A blank kep fajl nem talalhato: {path}'**
  String statusBlankNotFound(Object path);

  /// No description provided for @statusBlankSet.
  ///
  /// In hu, this message translates to:
  /// **'Blank kep beallitva: {name}'**
  String statusBlankSet(Object name);

  /// No description provided for @statusBlankSendError.
  ///
  /// In hu, this message translates to:
  /// **'Blank kep kuldesi hiba: {error}'**
  String statusBlankSendError(Object error);

  /// No description provided for @statusBlankCleared.
  ///
  /// In hu, this message translates to:
  /// **'Blank kep torolve.'**
  String get statusBlankCleared;

  /// No description provided for @statusBlankClearError.
  ///
  /// In hu, this message translates to:
  /// **'Blank kep torlesi hiba: {error}'**
  String statusBlankClearError(Object error);

  /// No description provided for @statusShutdownCommandSent.
  ///
  /// In hu, this message translates to:
  /// **'Lezaras utasitas elkuldve.'**
  String get statusShutdownCommandSent;

  /// No description provided for @statusStopCommandSent.
  ///
  /// In hu, this message translates to:
  /// **'Megallitas utasitas elkuldve.'**
  String get statusStopCommandSent;

  /// No description provided for @statusCommandSendError.
  ///
  /// In hu, this message translates to:
  /// **'Utasitas kuldesi hiba: {error}'**
  String statusCommandSendError(Object error);

  /// No description provided for @sendStatusLabel.
  ///
  /// In hu, this message translates to:
  /// **'Kuldes ({protocol}): {senderState}, kliens: {clientState}'**
  String sendStatusLabel(
    Object protocol,
    Object senderState,
    Object clientState,
  );

  /// No description provided for @protocolMqtt.
  ///
  /// In hu, this message translates to:
  /// **'MQTT'**
  String get protocolMqtt;

  /// No description provided for @protocolTcp.
  ///
  /// In hu, this message translates to:
  /// **'TCP'**
  String get protocolTcp;

  /// No description provided for @senderStateActive.
  ///
  /// In hu, this message translates to:
  /// **'aktiv'**
  String get senderStateActive;

  /// No description provided for @senderStateOff.
  ///
  /// In hu, this message translates to:
  /// **'kikapcsolva'**
  String get senderStateOff;

  /// No description provided for @clientStateConnected.
  ///
  /// In hu, this message translates to:
  /// **'csatlakozva'**
  String get clientStateConnected;

  /// No description provided for @clientStateWaiting.
  ///
  /// In hu, this message translates to:
  /// **'varakozik'**
  String get clientStateWaiting;

  /// No description provided for @tcpPortLabel.
  ///
  /// In hu, this message translates to:
  /// **'TCP port: {port}'**
  String tcpPortLabel(int port);

  /// No description provided for @downloadProgress.
  ///
  /// In hu, this message translates to:
  /// **'Letoltes: {current}/{total} {name}'**
  String downloadProgress(int current, int total, Object name);

  /// No description provided for @noLoadedSlide.
  ///
  /// In hu, this message translates to:
  /// **'Nincs betoltott dia.'**
  String get noLoadedSlide;

  /// No description provided for @bookLabel.
  ///
  /// In hu, this message translates to:
  /// **'Kötet'**
  String get bookLabel;

  /// No description provided for @songLabel.
  ///
  /// In hu, this message translates to:
  /// **'Enek'**
  String get songLabel;

  /// No description provided for @verseLabel.
  ///
  /// In hu, this message translates to:
  /// **'Versszak'**
  String get verseLabel;

  /// No description provided for @versePanelTitle.
  ///
  /// In hu, this message translates to:
  /// **'{title}: {verse}'**
  String versePanelTitle(Object title, Object verse);

  /// No description provided for @searchLabel.
  ///
  /// In hu, this message translates to:
  /// **'Diakereso'**
  String get searchLabel;

  /// No description provided for @searchHint.
  ///
  /// In hu, this message translates to:
  /// **'Kötet vagy enekcim'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In hu, this message translates to:
  /// **'Nincs talalat.'**
  String get noResults;

  /// No description provided for @customOrderStatus.
  ///
  /// In hu, this message translates to:
  /// **'Sajat sorrend: {state}'**
  String customOrderStatus(Object state);

  /// No description provided for @stateActive.
  ///
  /// In hu, this message translates to:
  /// **'Aktiv'**
  String get stateActive;

  /// No description provided for @stateInactive.
  ///
  /// In hu, this message translates to:
  /// **'Inaktiv'**
  String get stateInactive;

  /// No description provided for @nextShort.
  ///
  /// In hu, this message translates to:
  /// **'Kov.'**
  String get nextShort;

  /// No description provided for @previewTitle.
  ///
  /// In hu, this message translates to:
  /// **'Dia elonezet'**
  String get previewTitle;

  /// No description provided for @projectedImage.
  ///
  /// In hu, this message translates to:
  /// **'Vetitett kep:'**
  String get projectedImage;

  /// No description provided for @settingsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Diatar beallitasok'**
  String get settingsTitle;

  /// No description provided for @settingsTitleReceiver.
  ///
  /// In hu, this message translates to:
  /// **'Beallitasok'**
  String get settingsTitleReceiver;

  /// No description provided for @modeIp.
  ///
  /// In hu, this message translates to:
  /// **'IP'**
  String get modeIp;

  /// No description provided for @modeInternet.
  ///
  /// In hu, this message translates to:
  /// **'Internet'**
  String get modeInternet;

  /// No description provided for @senderLabel.
  ///
  /// In hu, this message translates to:
  /// **'Kuldo'**
  String get senderLabel;

  /// No description provided for @senderHelper.
  ///
  /// In hu, this message translates to:
  /// **'MQTT sender neve'**
  String get senderHelper;

  /// No description provided for @senderRefreshTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Kuldo lista frissites'**
  String get senderRefreshTooltip;

  /// No description provided for @channelLabel.
  ///
  /// In hu, this message translates to:
  /// **'Csatorna'**
  String get channelLabel;

  /// No description provided for @clipLeft.
  ///
  /// In hu, this message translates to:
  /// **'Bal'**
  String get clipLeft;

  /// No description provided for @clipTop.
  ///
  /// In hu, this message translates to:
  /// **'Felso'**
  String get clipTop;

  /// No description provided for @clipRight.
  ///
  /// In hu, this message translates to:
  /// **'Jobb'**
  String get clipRight;

  /// No description provided for @clipBottom.
  ///
  /// In hu, this message translates to:
  /// **'Also'**
  String get clipBottom;

  /// No description provided for @borderToClip.
  ///
  /// In hu, this message translates to:
  /// **'Margok a vezerlotol (Border2Clip)'**
  String get borderToClip;

  /// No description provided for @mirror.
  ///
  /// In hu, this message translates to:
  /// **'Tukrozes'**
  String get mirror;

  /// No description provided for @autoBootIndicator.
  ///
  /// In hu, this message translates to:
  /// **'Automatikus inditas (jelzo)'**
  String get autoBootIndicator;

  /// No description provided for @rotationLabel.
  ///
  /// In hu, this message translates to:
  /// **'Forgatas'**
  String get rotationLabel;

  /// No description provided for @tcpPortRange.
  ///
  /// In hu, this message translates to:
  /// **'TCP port (0..65535)'**
  String get tcpPortRange;

  /// No description provided for @mqttUserHint.
  ///
  /// In hu, this message translates to:
  /// **'MQTT user (ures = TCP mod)'**
  String get mqttUserHint;

  /// No description provided for @mqttPassword.
  ///
  /// In hu, this message translates to:
  /// **'MQTT jelszo'**
  String get mqttPassword;

  /// No description provided for @mqttChannel.
  ///
  /// In hu, this message translates to:
  /// **'MQTT csatorna'**
  String get mqttChannel;

  /// No description provided for @dtxFolderPath.
  ///
  /// In hu, this message translates to:
  /// **'DTX mappa'**
  String get dtxFolderPath;

  /// No description provided for @blankImagePath.
  ///
  /// In hu, this message translates to:
  /// **'Blank kep utvonal'**
  String get blankImagePath;

  /// No description provided for @fileChoose.
  ///
  /// In hu, this message translates to:
  /// **'Fajl valasztasa'**
  String get fileChoose;

  /// No description provided for @projectionSettingsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Vetitesi beallitasok'**
  String get projectionSettingsTitle;

  /// No description provided for @fontSize.
  ///
  /// In hu, this message translates to:
  /// **'Betumeret'**
  String get fontSize;

  /// No description provided for @titleSize.
  ///
  /// In hu, this message translates to:
  /// **'Cim meret'**
  String get titleSize;

  /// No description provided for @leftMargin.
  ///
  /// In hu, this message translates to:
  /// **'Bal margo'**
  String get leftMargin;

  /// No description provided for @borderLeft.
  ///
  /// In hu, this message translates to:
  /// **'Border L'**
  String get borderLeft;

  /// No description provided for @borderTop.
  ///
  /// In hu, this message translates to:
  /// **'Border T'**
  String get borderTop;

  /// No description provided for @borderRight.
  ///
  /// In hu, this message translates to:
  /// **'Border R'**
  String get borderRight;

  /// No description provided for @borderBottom.
  ///
  /// In hu, this message translates to:
  /// **'Border B'**
  String get borderBottom;

  /// No description provided for @lineSpacing.
  ///
  /// In hu, this message translates to:
  /// **'Sorkoz'**
  String get lineSpacing;

  /// No description provided for @kottaScale.
  ///
  /// In hu, this message translates to:
  /// **'Kotta meret arany'**
  String get kottaScale;

  /// No description provided for @chordScale.
  ///
  /// In hu, this message translates to:
  /// **'Akkord meret arany'**
  String get chordScale;

  /// No description provided for @backgroundMode.
  ///
  /// In hu, this message translates to:
  /// **'Hatters kep mod'**
  String get backgroundMode;

  /// No description provided for @bgModeCenter.
  ///
  /// In hu, this message translates to:
  /// **'Center'**
  String get bgModeCenter;

  /// No description provided for @bgModeZoom.
  ///
  /// In hu, this message translates to:
  /// **'Zoom'**
  String get bgModeZoom;

  /// No description provided for @bgModeFull.
  ///
  /// In hu, this message translates to:
  /// **'Full'**
  String get bgModeFull;

  /// No description provided for @bgModeCascade.
  ///
  /// In hu, this message translates to:
  /// **'Cascade'**
  String get bgModeCascade;

  /// No description provided for @bgModeMirror.
  ///
  /// In hu, this message translates to:
  /// **'Mirror'**
  String get bgModeMirror;

  /// No description provided for @backgroundOpacity.
  ///
  /// In hu, this message translates to:
  /// **'Hatter atszosag'**
  String get backgroundOpacity;

  /// No description provided for @blankOpacity.
  ///
  /// In hu, this message translates to:
  /// **'Blank atszosag'**
  String get blankOpacity;

  /// No description provided for @autoSize.
  ///
  /// In hu, this message translates to:
  /// **'Automatikus meretezes'**
  String get autoSize;

  /// No description provided for @showTitle.
  ///
  /// In hu, this message translates to:
  /// **'Cim mutatasa'**
  String get showTitle;

  /// No description provided for @hCenter.
  ///
  /// In hu, this message translates to:
  /// **'Vizszintes kozepre igazitas'**
  String get hCenter;

  /// No description provided for @vCenter.
  ///
  /// In hu, this message translates to:
  /// **'Fuggoleges kozepre igazitas'**
  String get vCenter;

  /// No description provided for @showChords.
  ///
  /// In hu, this message translates to:
  /// **'Akkordok mutatasa'**
  String get showChords;

  /// No description provided for @showKotta.
  ///
  /// In hu, this message translates to:
  /// **'Kotta mutatasa'**
  String get showKotta;

  /// No description provided for @boldText.
  ///
  /// In hu, this message translates to:
  /// **'Felkover szoveg'**
  String get boldText;

  /// No description provided for @colorsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Szinek'**
  String get colorsTitle;

  /// No description provided for @backgroundColor.
  ///
  /// In hu, this message translates to:
  /// **'Hatter'**
  String get backgroundColor;

  /// No description provided for @textColor.
  ///
  /// In hu, this message translates to:
  /// **'Szoveg'**
  String get textColor;

  /// No description provided for @emptySlideColor.
  ///
  /// In hu, this message translates to:
  /// **'Ures dia'**
  String get emptySlideColor;

  /// No description provided for @highlightColor.
  ///
  /// In hu, this message translates to:
  /// **'Kiemeles'**
  String get highlightColor;

  /// No description provided for @backgroundColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Hatter szine'**
  String get backgroundColorTitle;

  /// No description provided for @textColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Szoveg szine'**
  String get textColorTitle;

  /// No description provided for @emptySlideColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Ures dia szine'**
  String get emptySlideColorTitle;

  /// No description provided for @highlightColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Kiemeles szine'**
  String get highlightColorTitle;

  /// No description provided for @cancel.
  ///
  /// In hu, this message translates to:
  /// **'Megse'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In hu, this message translates to:
  /// **'Ment'**
  String get save;

  /// No description provided for @invalidPortRange.
  ///
  /// In hu, this message translates to:
  /// **'A port 0..65535 kozott legyen.'**
  String get invalidPortRange;

  /// No description provided for @hexColorHint.
  ///
  /// In hu, this message translates to:
  /// **'Hex szin (#AARRGGBB vagy #RRGGBB)'**
  String get hexColorHint;

  /// No description provided for @close.
  ///
  /// In hu, this message translates to:
  /// **'Bezaras'**
  String get close;

  /// No description provided for @imagesFileTypeLabel.
  ///
  /// In hu, this message translates to:
  /// **'kepek'**
  String get imagesFileTypeLabel;

  /// No description provided for @diatarPlaylistFileTypeLabel.
  ///
  /// In hu, this message translates to:
  /// **'Diatar playlist'**
  String get diatarPlaylistFileTypeLabel;

  /// No description provided for @customOrderSuggestedFileName.
  ///
  /// In hu, this message translates to:
  /// **'sorrend.dia'**
  String get customOrderSuggestedFileName;

  /// No description provided for @customOrderEditTitle.
  ///
  /// In hu, this message translates to:
  /// **'Sajat sorrend szerkesztese'**
  String get customOrderEditTitle;

  /// No description provided for @addSong.
  ///
  /// In hu, this message translates to:
  /// **'Enek hozzaadasa'**
  String get addSong;

  /// No description provided for @searchSongHint.
  ///
  /// In hu, this message translates to:
  /// **'Kötet vagy enekcim'**
  String get searchSongHint;

  /// No description provided for @textSlideDialogTitle.
  ///
  /// In hu, this message translates to:
  /// **'Szoveges dia hozzaadasa'**
  String get textSlideDialogTitle;

  /// No description provided for @textSlideTitleLabel.
  ///
  /// In hu, this message translates to:
  /// **'Cim'**
  String get textSlideTitleLabel;

  /// No description provided for @textSlideBodyLabel.
  ///
  /// In hu, this message translates to:
  /// **'Szoveg (soronként)'**
  String get textSlideBodyLabel;

  /// No description provided for @loadDia.
  ///
  /// In hu, this message translates to:
  /// **'Betoltes .DIA'**
  String get loadDia;

  /// No description provided for @saveDia.
  ///
  /// In hu, this message translates to:
  /// **'Mentes .DIA'**
  String get saveDia;

  /// No description provided for @savedPath.
  ///
  /// In hu, this message translates to:
  /// **'Mentve: {path}'**
  String savedPath(Object path);

  /// No description provided for @loadedCount.
  ///
  /// In hu, this message translates to:
  /// **'Betoltve: {count} elem'**
  String loadedCount(int count);

  /// No description provided for @customOrderEmpty.
  ///
  /// In hu, this message translates to:
  /// **'A sorrend ures.\nKeress enekeket a szerkeszteshez.'**
  String get customOrderEmpty;

  /// No description provided for @versePicker.
  ///
  /// In hu, this message translates to:
  /// **'Versszak'**
  String get versePicker;

  /// No description provided for @selectedVersesTitle.
  ///
  /// In hu, this message translates to:
  /// **'Kivalasztott versszakok'**
  String get selectedVersesTitle;

  /// No description provided for @selectedVersesSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'Tobbet is kijelolhetsz.'**
  String get selectedVersesSubtitle;

  /// No description provided for @apply.
  ///
  /// In hu, this message translates to:
  /// **'Alkalmaz'**
  String get apply;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
