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
  /// **'Diatár'**
  String get appTitle;

  /// No description provided for @viewTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Nézet'**
  String get viewTooltip;

  /// No description provided for @viewSimple.
  ///
  /// In hu, this message translates to:
  /// **'Szimpla'**
  String get viewSimple;

  /// No description provided for @viewSpontaneous.
  ///
  /// In hu, this message translates to:
  /// **'Spontán'**
  String get viewSpontaneous;

  /// No description provided for @viewOrder.
  ///
  /// In hu, this message translates to:
  /// **'Sorrend'**
  String get viewOrder;

  /// No description provided for @settingsTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Beállítások'**
  String get settingsTooltip;

  /// No description provided for @playlistsTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Énekrendek'**
  String get playlistsTooltip;

  /// No description provided for @playlistsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Énekrendek'**
  String get playlistsTitle;

  /// No description provided for @playlistsMessage.
  ///
  /// In hu, this message translates to:
  /// **'Ez a művelet később visszakaphatja a teljes dialógust.'**
  String get playlistsMessage;

  /// No description provided for @customOrderTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Saját sorrend'**
  String get customOrderTooltip;

  /// No description provided for @addSlideTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Dia hozzáadása'**
  String get addSlideTooltip;

  /// No description provided for @addTextSlide.
  ///
  /// In hu, this message translates to:
  /// **'Szöveges dia'**
  String get addTextSlide;

  /// No description provided for @addImageSlide.
  ///
  /// In hu, this message translates to:
  /// **'Képes dia'**
  String get addImageSlide;

  /// No description provided for @downloadBooksTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Énektárak letöltése'**
  String get downloadBooksTooltip;

  /// No description provided for @downloadTitle.
  ///
  /// In hu, this message translates to:
  /// **'Letöltés'**
  String get downloadTitle;

  /// No description provided for @downloadMessage.
  ///
  /// In hu, this message translates to:
  /// **'A letöltési párbeszéd később visszahelyezhető.'**
  String get downloadMessage;

  /// No description provided for @refreshTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Frissítés'**
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
  /// **'Vetítés BE'**
  String get projectionOn;

  /// No description provided for @projectionOff.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés KI'**
  String get projectionOff;

  /// No description provided for @previous.
  ///
  /// In hu, this message translates to:
  /// **'Előző'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In hu, this message translates to:
  /// **'Következő'**
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
  /// **'Pozíció: {current}/{total}'**
  String positionLabel(int current, int total);

  /// No description provided for @statusLabel.
  ///
  /// In hu, this message translates to:
  /// **'Státusz: {status}'**
  String statusLabel(Object status);

  /// No description provided for @statusStarting.
  ///
  /// In hu, this message translates to:
  /// **'Indítás...'**
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
  /// **'Nem sikerült portot nyitni ({port}): {error}'**
  String statusSenderOpenPortFailed(int port, Object error);

  /// No description provided for @statusSenderMqttConnectFailed.
  ///
  /// In hu, this message translates to:
  /// **'MQTT sender kapcsolódás sikertelen.'**
  String get statusSenderMqttConnectFailed;

  /// No description provided for @statusSenderMqttError.
  ///
  /// In hu, this message translates to:
  /// **'MQTT sender hiba: {error}'**
  String statusSenderMqttError(Object error);

  /// No description provided for @statusMqttSending.
  ///
  /// In hu, this message translates to:
  /// **'MQTT küldés: {user}/{channel}'**
  String statusMqttSending(Object user, Object channel);

  /// No description provided for @statusTcpSending.
  ///
  /// In hu, this message translates to:
  /// **'TCP küldés: {port}'**
  String statusTcpSending(int port);

  /// No description provided for @statusNoDtxFiles.
  ///
  /// In hu, this message translates to:
  /// **'Nincs .dtx fájl: {path}'**
  String statusNoDtxFiles(Object path);

  /// No description provided for @statusAllSongbooksDisabled.
  ///
  /// In hu, this message translates to:
  /// **'Minden énektár le van tiltva az énekrendben.'**
  String get statusAllSongbooksDisabled;

  /// No description provided for @statusSongbooksLoaded.
  ///
  /// In hu, this message translates to:
  /// **'{count} kötet betöltve'**
  String statusSongbooksLoaded(int count);

  /// No description provided for @statusLoadError.
  ///
  /// In hu, this message translates to:
  /// **'Betöltési hiba: {error}'**
  String statusLoadError(Object error);

  /// No description provided for @statusCustomOrderSelected.
  ///
  /// In hu, this message translates to:
  /// **'Saját sorrend: {label}'**
  String statusCustomOrderSelected(Object label);

  /// No description provided for @statusOrderSaved.
  ///
  /// In hu, this message translates to:
  /// **'Sorrend mentve: {path}'**
  String statusOrderSaved(Object path);

  /// No description provided for @statusDiaFileMissing.
  ///
  /// In hu, this message translates to:
  /// **'Nincs ilyen .DIA fájl: {path}'**
  String statusDiaFileMissing(Object path);

  /// No description provided for @statusOrderLoaded.
  ///
  /// In hu, this message translates to:
  /// **'Sorrend betöltve ({count} elem): {path}'**
  String statusOrderLoaded(int count, Object path);

  /// No description provided for @statusDownloadListLoading.
  ///
  /// In hu, this message translates to:
  /// **'Énektár lista letöltése...'**
  String get statusDownloadListLoading;

  /// No description provided for @statusDownloadProgress.
  ///
  /// In hu, this message translates to:
  /// **'Letöltés: {current}/{total} {name} {percent}%'**
  String statusDownloadProgress(
    int current,
    int total,
    Object name,
    int percent,
  );

  /// No description provided for @statusDownloadSummaryNone.
  ///
  /// In hu, this message translates to:
  /// **'Nincs új énektár frissítés.'**
  String get statusDownloadSummaryNone;

  /// No description provided for @statusDownloadSummary.
  ///
  /// In hu, this message translates to:
  /// **'{downloaded} fájl letöltve, {skipped} változatlan.'**
  String statusDownloadSummary(int downloaded, int skipped);

  /// No description provided for @statusDownloadError.
  ///
  /// In hu, this message translates to:
  /// **'Letöltési hiba: {error}'**
  String statusDownloadError(Object error);

  /// No description provided for @statusBookSelected.
  ///
  /// In hu, this message translates to:
  /// **'Kötet: {name}'**
  String statusBookSelected(Object name);

  /// No description provided for @statusSongPicked.
  ///
  /// In hu, this message translates to:
  /// **'Ének: {name}'**
  String statusSongPicked(Object name);

  /// No description provided for @statusVersePicked.
  ///
  /// In hu, this message translates to:
  /// **'Versszak: {name}'**
  String statusVersePicked(Object name);

  /// No description provided for @statusSongSelected.
  ///
  /// In hu, this message translates to:
  /// **'Ének: {title}'**
  String statusSongSelected(Object title);

  /// No description provided for @statusSongVerseSelected.
  ///
  /// In hu, this message translates to:
  /// **'Ének/versszak: {title}'**
  String statusSongVerseSelected(Object title);

  /// No description provided for @statusProjectionOn.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés: BE'**
  String get statusProjectionOn;

  /// No description provided for @statusProjectionOff.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés: KI'**
  String get statusProjectionOff;

  /// No description provided for @statusImagePathEmpty.
  ///
  /// In hu, this message translates to:
  /// **'A kép fájl útvonala üres.'**
  String get statusImagePathEmpty;

  /// No description provided for @statusCustomTextEmpty.
  ///
  /// In hu, this message translates to:
  /// **'Adj meg címet vagy legalább egy sort.'**
  String get statusCustomTextEmpty;

  /// No description provided for @statusCustomTextSent.
  ///
  /// In hu, this message translates to:
  /// **'Szöveges dia elküldve: {title}'**
  String statusCustomTextSent(Object title);

  /// No description provided for @statusCustomTextError.
  ///
  /// In hu, this message translates to:
  /// **'Szöveges dia küldési hiba: {error}'**
  String statusCustomTextError(Object error);

  /// No description provided for @statusImageNotFound.
  ///
  /// In hu, this message translates to:
  /// **'A kép fájl nem található: {path}'**
  String statusImageNotFound(Object path);

  /// No description provided for @statusImageSent.
  ///
  /// In hu, this message translates to:
  /// **'Kép elküldve: {name}'**
  String statusImageSent(Object name);

  /// No description provided for @statusImageSendError.
  ///
  /// In hu, this message translates to:
  /// **'Kép küldési hiba: {error}'**
  String statusImageSendError(Object error);

  /// No description provided for @statusBlankPathEmpty.
  ///
  /// In hu, this message translates to:
  /// **'A blank kép fájl útvonala üres.'**
  String get statusBlankPathEmpty;

  /// No description provided for @statusBlankNotFound.
  ///
  /// In hu, this message translates to:
  /// **'A blank kép fájl nem található: {path}'**
  String statusBlankNotFound(Object path);

  /// No description provided for @statusBlankSet.
  ///
  /// In hu, this message translates to:
  /// **'Blank kép beállítva: {name}'**
  String statusBlankSet(Object name);

  /// No description provided for @statusBlankSendError.
  ///
  /// In hu, this message translates to:
  /// **'Blank kép küldési hiba: {error}'**
  String statusBlankSendError(Object error);

  /// No description provided for @statusBlankCleared.
  ///
  /// In hu, this message translates to:
  /// **'Blank kép törölve.'**
  String get statusBlankCleared;

  /// No description provided for @statusBlankClearError.
  ///
  /// In hu, this message translates to:
  /// **'Blank kép törlési hiba: {error}'**
  String statusBlankClearError(Object error);

  /// No description provided for @statusShutdownCommandSent.
  ///
  /// In hu, this message translates to:
  /// **'Lezárás utasitas elküldve.'**
  String get statusShutdownCommandSent;

  /// No description provided for @statusStopCommandSent.
  ///
  /// In hu, this message translates to:
  /// **'Megállítás utasitas elküldve.'**
  String get statusStopCommandSent;

  /// No description provided for @statusCommandSendError.
  ///
  /// In hu, this message translates to:
  /// **'Utasítás küldési hiba: {error}'**
  String statusCommandSendError(Object error);

  /// No description provided for @sendStatusLabel.
  ///
  /// In hu, this message translates to:
  /// **'Küldés ({protocol}): {senderState}, kliens: {clientState}'**
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
  /// **'aktív'**
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
  /// **'várakozik'**
  String get clientStateWaiting;

  /// No description provided for @tcpPortLabel.
  ///
  /// In hu, this message translates to:
  /// **'TCP port: {port}'**
  String tcpPortLabel(int port);

  /// No description provided for @downloadProgress.
  ///
  /// In hu, this message translates to:
  /// **'Letöltés: {current}/{total} {name}'**
  String downloadProgress(int current, int total, Object name);

  /// No description provided for @noLoadedSlide.
  ///
  /// In hu, this message translates to:
  /// **'Nincs betöltött dia.'**
  String get noLoadedSlide;

  /// No description provided for @bookLabel.
  ///
  /// In hu, this message translates to:
  /// **'Kötet'**
  String get bookLabel;

  /// No description provided for @songLabel.
  ///
  /// In hu, this message translates to:
  /// **'Ének'**
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
  /// **'Diakereső'**
  String get searchLabel;

  /// No description provided for @searchHint.
  ///
  /// In hu, this message translates to:
  /// **'Kötet vagy enekcím'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In hu, this message translates to:
  /// **'Nincs találat.'**
  String get noResults;

  /// No description provided for @customOrderStatus.
  ///
  /// In hu, this message translates to:
  /// **'Saját sorrend: {state}'**
  String customOrderStatus(Object state);

  /// No description provided for @stateActive.
  ///
  /// In hu, this message translates to:
  /// **'Aktív'**
  String get stateActive;

  /// No description provided for @stateInactive.
  ///
  /// In hu, this message translates to:
  /// **'Inaktív'**
  String get stateInactive;

  /// No description provided for @nextShort.
  ///
  /// In hu, this message translates to:
  /// **'Kov.'**
  String get nextShort;

  /// No description provided for @previewTitle.
  ///
  /// In hu, this message translates to:
  /// **'Dia előnézet'**
  String get previewTitle;

  /// No description provided for @projectedImage.
  ///
  /// In hu, this message translates to:
  /// **'Vetített kép:'**
  String get projectedImage;

  /// No description provided for @settingsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Diatár beállítások'**
  String get settingsTitle;

  /// No description provided for @settingsTitleReceiver.
  ///
  /// In hu, this message translates to:
  /// **'Beállítások'**
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
  /// **'Küldő'**
  String get senderLabel;

  /// No description provided for @senderHelper.
  ///
  /// In hu, this message translates to:
  /// **'MQTT sender neve'**
  String get senderHelper;

  /// No description provided for @senderRefreshTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Küldő lista frissítés'**
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
  /// **'Felső'**
  String get clipTop;

  /// No description provided for @clipRight.
  ///
  /// In hu, this message translates to:
  /// **'Jobb'**
  String get clipRight;

  /// No description provided for @clipBottom.
  ///
  /// In hu, this message translates to:
  /// **'Alsó'**
  String get clipBottom;

  /// No description provided for @borderToClip.
  ///
  /// In hu, this message translates to:
  /// **'Margok a vezérlőtől (Border2Clip)'**
  String get borderToClip;

  /// No description provided for @mirror.
  ///
  /// In hu, this message translates to:
  /// **'Tükrözés'**
  String get mirror;

  /// No description provided for @autoBootIndicator.
  ///
  /// In hu, this message translates to:
  /// **'Automatikus indítás (jelző)'**
  String get autoBootIndicator;

  /// No description provided for @rotationLabel.
  ///
  /// In hu, this message translates to:
  /// **'Forgatás'**
  String get rotationLabel;

  /// No description provided for @tcpPortRange.
  ///
  /// In hu, this message translates to:
  /// **'TCP port (0..65535)'**
  String get tcpPortRange;

  /// No description provided for @mqttUserHint.
  ///
  /// In hu, this message translates to:
  /// **'MQTT user (üres = TCP mód)'**
  String get mqttUserHint;

  /// No description provided for @mqttPassword.
  ///
  /// In hu, this message translates to:
  /// **'MQTT jelszó'**
  String get mqttPassword;

  /// No description provided for @mqttChannel.
  ///
  /// In hu, this message translates to:
  /// **'MQTT csatorna'**
  String get mqttChannel;

  /// No description provided for @uiTheme.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználói felület témája'**
  String get uiTheme;

  /// No description provided for @themeDark.
  ///
  /// In hu, this message translates to:
  /// **'Sötét'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In hu, this message translates to:
  /// **'Világos'**
  String get themeLight;

  /// No description provided for @dtxFolderPath.
  ///
  /// In hu, this message translates to:
  /// **'DTX mappa'**
  String get dtxFolderPath;

  /// No description provided for @blankImagePath.
  ///
  /// In hu, this message translates to:
  /// **'Blank kép útvonal'**
  String get blankImagePath;

  /// No description provided for @diaExportFolderPath.
  ///
  /// In hu, this message translates to:
  /// **'DIA mentési mappa'**
  String get diaExportFolderPath;

  /// No description provided for @fileChoose.
  ///
  /// In hu, this message translates to:
  /// **'Fájl választása'**
  String get fileChoose;

  /// No description provided for @uiLanguage.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználói felület nyelve'**
  String get uiLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In hu, this message translates to:
  /// **'Rendszer alapértelmezett'**
  String get languageSystem;

  /// No description provided for @languageHungarian.
  ///
  /// In hu, this message translates to:
  /// **'Magyar'**
  String get languageHungarian;

  /// No description provided for @languageEnglish.
  ///
  /// In hu, this message translates to:
  /// **'Angol'**
  String get languageEnglish;

  /// No description provided for @projectionSettingsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Vetítési beállítások'**
  String get projectionSettingsTitle;

  /// No description provided for @fontSize.
  ///
  /// In hu, this message translates to:
  /// **'Betűméret'**
  String get fontSize;

  /// No description provided for @titleSize.
  ///
  /// In hu, this message translates to:
  /// **'Cím méret'**
  String get titleSize;

  /// No description provided for @leftMargin.
  ///
  /// In hu, this message translates to:
  /// **'Bal behúzás'**
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
  /// **'Sorköz'**
  String get lineSpacing;

  /// No description provided for @kottaScale.
  ///
  /// In hu, this message translates to:
  /// **'Kotta méret arány'**
  String get kottaScale;

  /// No description provided for @chordScale.
  ///
  /// In hu, this message translates to:
  /// **'Akkord méret arány'**
  String get chordScale;

  /// No description provided for @backgroundMode.
  ///
  /// In hu, this message translates to:
  /// **'Háttér kép mód'**
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
  /// **'Háttér átlátszóság'**
  String get backgroundOpacity;

  /// No description provided for @blankOpacity.
  ///
  /// In hu, this message translates to:
  /// **'Blank átlátszóság'**
  String get blankOpacity;

  /// No description provided for @autoSize.
  ///
  /// In hu, this message translates to:
  /// **'Automatikus méretezés'**
  String get autoSize;

  /// No description provided for @scrollableProjection.
  ///
  /// In hu, this message translates to:
  /// **'Görgethető vetítés'**
  String get scrollableProjection;

  /// No description provided for @scrollableProjectionHint.
  ///
  /// In hu, this message translates to:
  /// **'Ha ki van kapcsolva, a szöveg automatikusan a vetítési területhez igazodik.'**
  String get scrollableProjectionHint;

  /// No description provided for @showTitle.
  ///
  /// In hu, this message translates to:
  /// **'Cím mutatása'**
  String get showTitle;

  /// No description provided for @projectionLock.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés zárolása'**
  String get projectionLock;

  /// No description provided for @projectionUnlock.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés feloldása'**
  String get projectionUnlock;

  /// No description provided for @hCenter.
  ///
  /// In hu, this message translates to:
  /// **'Vízszintes középre igazítás'**
  String get hCenter;

  /// No description provided for @vCenter.
  ///
  /// In hu, this message translates to:
  /// **'Függőleges középre igazítás'**
  String get vCenter;

  /// No description provided for @showChords.
  ///
  /// In hu, this message translates to:
  /// **'Akkordok mutatása'**
  String get showChords;

  /// No description provided for @showKotta.
  ///
  /// In hu, this message translates to:
  /// **'Kotta mutatása'**
  String get showKotta;

  /// No description provided for @boldText.
  ///
  /// In hu, this message translates to:
  /// **'Félkövér szöveg'**
  String get boldText;

  /// No description provided for @colorsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Színek'**
  String get colorsTitle;

  /// No description provided for @backgroundColor.
  ///
  /// In hu, this message translates to:
  /// **'Háttér'**
  String get backgroundColor;

  /// No description provided for @textColor.
  ///
  /// In hu, this message translates to:
  /// **'Szöveg'**
  String get textColor;

  /// No description provided for @emptySlideColor.
  ///
  /// In hu, this message translates to:
  /// **'Üres dia'**
  String get emptySlideColor;

  /// No description provided for @highlightColor.
  ///
  /// In hu, this message translates to:
  /// **'Kiemelés'**
  String get highlightColor;

  /// No description provided for @backgroundColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Háttér színe'**
  String get backgroundColorTitle;

  /// No description provided for @textColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Szöveg színe'**
  String get textColorTitle;

  /// No description provided for @emptySlideColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Üres dia színe'**
  String get emptySlideColorTitle;

  /// No description provided for @highlightColorTitle.
  ///
  /// In hu, this message translates to:
  /// **'Kiemelés színe'**
  String get highlightColorTitle;

  /// No description provided for @cancel.
  ///
  /// In hu, this message translates to:
  /// **'Mégse'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In hu, this message translates to:
  /// **'Ment'**
  String get save;

  /// No description provided for @invalidPortRange.
  ///
  /// In hu, this message translates to:
  /// **'A port 0..65535 között legyen.'**
  String get invalidPortRange;

  /// No description provided for @hexColorHint.
  ///
  /// In hu, this message translates to:
  /// **'Hex szín (#AARRGGBB vagy #RRGGBB)'**
  String get hexColorHint;

  /// No description provided for @close.
  ///
  /// In hu, this message translates to:
  /// **'Bezárás'**
  String get close;

  /// No description provided for @imagesFileTypeLabel.
  ///
  /// In hu, this message translates to:
  /// **'képek'**
  String get imagesFileTypeLabel;

  /// No description provided for @diatarPlaylistFileTypeLabel.
  ///
  /// In hu, this message translates to:
  /// **'Diatár playlist'**
  String get diatarPlaylistFileTypeLabel;

  /// No description provided for @customOrderSuggestedFileName.
  ///
  /// In hu, this message translates to:
  /// **'sorrend.dia'**
  String get customOrderSuggestedFileName;

  /// No description provided for @customOrderEditTitle.
  ///
  /// In hu, this message translates to:
  /// **'Saját sorrend szerkesztése'**
  String get customOrderEditTitle;

  /// No description provided for @addSong.
  ///
  /// In hu, this message translates to:
  /// **'Ének hozzáadása'**
  String get addSong;

  /// No description provided for @searchSongHint.
  ///
  /// In hu, this message translates to:
  /// **'Kötet vagy énekcím'**
  String get searchSongHint;

  /// No description provided for @textSlideDialogTitle.
  ///
  /// In hu, this message translates to:
  /// **'Szöveges dia hozzáadása'**
  String get textSlideDialogTitle;

  /// No description provided for @textSlideTitleLabel.
  ///
  /// In hu, this message translates to:
  /// **'Cím'**
  String get textSlideTitleLabel;

  /// No description provided for @textSlideBodyLabel.
  ///
  /// In hu, this message translates to:
  /// **'Szöveg (soronként)'**
  String get textSlideBodyLabel;

  /// No description provided for @loadDia.
  ///
  /// In hu, this message translates to:
  /// **'Betöltés .DIA'**
  String get loadDia;

  /// No description provided for @saveDia.
  ///
  /// In hu, this message translates to:
  /// **'Mentés .DIA'**
  String get saveDia;

  /// No description provided for @savedPath.
  ///
  /// In hu, this message translates to:
  /// **'Mentve: {path}'**
  String savedPath(Object path);

  /// No description provided for @loadedCount.
  ///
  /// In hu, this message translates to:
  /// **'Betöltve: {count} elem'**
  String loadedCount(int count);

  /// No description provided for @customOrderEmpty.
  ///
  /// In hu, this message translates to:
  /// **'A sorrend üres.\nKeress énekeket a szerkesztéshez.'**
  String get customOrderEmpty;

  /// No description provided for @versePicker.
  ///
  /// In hu, this message translates to:
  /// **'Versszak'**
  String get versePicker;

  /// No description provided for @selectedVersesTitle.
  ///
  /// In hu, this message translates to:
  /// **'Kiválasztott versszakok'**
  String get selectedVersesTitle;

  /// No description provided for @selectedVersesSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'Többet is kijelölhetsz.'**
  String get selectedVersesSubtitle;

  /// No description provided for @apply.
  ///
  /// In hu, this message translates to:
  /// **'Alkalmaz'**
  String get apply;

  /// No description provided for @internetUserActionsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználói műveletek (API)'**
  String get internetUserActionsTitle;

  /// No description provided for @internetStatusOn.
  ///
  /// In hu, this message translates to:
  /// **'Be'**
  String get internetStatusOn;

  /// No description provided for @internetStatusOff.
  ///
  /// In hu, this message translates to:
  /// **'Ki'**
  String get internetStatusOff;

  /// No description provided for @valueNotSet.
  ///
  /// In hu, this message translates to:
  /// **'-'**
  String get valueNotSet;

  /// No description provided for @tcpNoTargets.
  ///
  /// In hu, this message translates to:
  /// **'Nincs célpont'**
  String get tcpNoTargets;

  /// No description provided for @tcpTargetsCount.
  ///
  /// In hu, this message translates to:
  /// **'{count} célpont'**
  String tcpTargetsCount(int count);

  /// No description provided for @settingsSearchLabel.
  ///
  /// In hu, this message translates to:
  /// **'Keresés a beállításokban'**
  String get settingsSearchLabel;

  /// No description provided for @settingsInternetTitle.
  ///
  /// In hu, this message translates to:
  /// **'Internet'**
  String get settingsInternetTitle;

  /// No description provided for @settingsInternetSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'Internetes közvetítés: {status}, felhasználó: {user}'**
  String settingsInternetSubtitle(Object status, Object user);

  /// No description provided for @settingsLocalNetworkTitle.
  ///
  /// In hu, this message translates to:
  /// **'Helyi hálózat (TCP/IP)'**
  String get settingsLocalNetworkTitle;

  /// No description provided for @settingsLocalNetworkSubtitle.
  ///
  /// In hu, this message translates to:
  /// **'TCP kliens célpontok: {summary}'**
  String settingsLocalNetworkSubtitle(Object summary);

  /// No description provided for @settingsColorSummary.
  ///
  /// In hu, this message translates to:
  /// **'Háttér: {background}, Szöveg: {text}'**
  String settingsColorSummary(Object background, Object text);

  /// No description provided for @settingsProjectionSummary.
  ///
  /// In hu, this message translates to:
  /// **'Betű: {font}px, Cím: {title}px'**
  String settingsProjectionSummary(Object font, Object title);

  /// No description provided for @settingsFilesTitle.
  ///
  /// In hu, this message translates to:
  /// **'Énektárak és fájlok'**
  String get settingsFilesTitle;

  /// No description provided for @settingsFilesSummary.
  ///
  /// In hu, this message translates to:
  /// **'DTX: {dtx}, Üres kép: {blank}'**
  String settingsFilesSummary(Object dtx, Object blank);

  /// No description provided for @settingsGeneralTitle.
  ///
  /// In hu, this message translates to:
  /// **'Általános'**
  String get settingsGeneralTitle;

  /// No description provided for @settingsGeneralSummary.
  ///
  /// In hu, this message translates to:
  /// **'Téma: {theme}, Nyelv: {language}'**
  String settingsGeneralSummary(Object theme, Object language);

  /// No description provided for @settingsHotkeysTitle.
  ///
  /// In hu, this message translates to:
  /// **'Gyorsbillentyűk'**
  String get settingsHotkeysTitle;

  /// No description provided for @settingsHotkeysSummary.
  ///
  /// In hu, this message translates to:
  /// **'Vezérlő műveletek és ének-hozzárendelés billentyűhöz'**
  String get settingsHotkeysSummary;

  /// No description provided for @settingsDesktopHotkeysTitle.
  ///
  /// In hu, this message translates to:
  /// **'Gyorsbillentyűk (asztali)'**
  String get settingsDesktopHotkeysTitle;

  /// No description provided for @settingsHotkeysActionsSectionTitle.
  ///
  /// In hu, this message translates to:
  /// **'Vezérlő műveletek'**
  String get settingsHotkeysActionsSectionTitle;

  /// No description provided for @settingsHotkeysSongsSectionTitle.
  ///
  /// In hu, this message translates to:
  /// **'Ének gyorsbillentyűhöz'**
  String get settingsHotkeysSongsSectionTitle;

  /// No description provided for @settingsHotkeysNoSongs.
  ///
  /// In hu, this message translates to:
  /// **'Nincs betöltött ének, ezért nem lehet hozzárendelni.'**
  String get settingsHotkeysNoSongs;

  /// No description provided for @settingsHotkeyActionHint.
  ///
  /// In hu, this message translates to:
  /// **'pl. Ctrl+Right vagy F8'**
  String get settingsHotkeyActionHint;

  /// No description provided for @settingsHotkeyFieldLabel.
  ///
  /// In hu, this message translates to:
  /// **'Gyorsbillentyű'**
  String get settingsHotkeyFieldLabel;

  /// No description provided for @settingsHotkeySongHint.
  ///
  /// In hu, this message translates to:
  /// **'pl. Ctrl+1 vagy F2'**
  String get settingsHotkeySongHint;

  /// No description provided for @settingsHotkeyAssign.
  ///
  /// In hu, this message translates to:
  /// **'Hozzárendelés'**
  String get settingsHotkeyAssign;

  /// No description provided for @settingsHotkeyDelete.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get settingsHotkeyDelete;

  /// No description provided for @settingsHotkeyActionPrevSong.
  ///
  /// In hu, this message translates to:
  /// **'Előző ének'**
  String get settingsHotkeyActionPrevSong;

  /// No description provided for @settingsHotkeyActionPrevVerse.
  ///
  /// In hu, this message translates to:
  /// **'Előző versszak'**
  String get settingsHotkeyActionPrevVerse;

  /// No description provided for @settingsHotkeyActionToggleProjection.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés ki/be'**
  String get settingsHotkeyActionToggleProjection;

  /// No description provided for @settingsHotkeyActionNextVerse.
  ///
  /// In hu, this message translates to:
  /// **'Következő versszak'**
  String get settingsHotkeyActionNextVerse;

  /// No description provided for @settingsHotkeyActionNextSong.
  ///
  /// In hu, this message translates to:
  /// **'Következő ének'**
  String get settingsHotkeyActionNextSong;

  /// No description provided for @settingsHotkeyActionHighlightPrev.
  ///
  /// In hu, this message translates to:
  /// **'Kiemelés előző szó'**
  String get settingsHotkeyActionHighlightPrev;

  /// No description provided for @settingsHotkeyActionHighlightNext.
  ///
  /// In hu, this message translates to:
  /// **'Kiemelés következő szó'**
  String get settingsHotkeyActionHighlightNext;

  /// No description provided for @settingsHotkeyConflict.
  ///
  /// In hu, this message translates to:
  /// **'Ütköző gyorsbillentyű: {hotkey}'**
  String settingsHotkeyConflict(Object hotkey);

  /// No description provided for @settingsNoResults.
  ///
  /// In hu, this message translates to:
  /// **'Nincs találat a keresésre.'**
  String get settingsNoResults;

  /// No description provided for @internetRelaySwitchTitle.
  ///
  /// In hu, this message translates to:
  /// **'Internetes közvetítés'**
  String get internetRelaySwitchTitle;

  /// No description provided for @passwordHideTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Elrejtés'**
  String get passwordHideTooltip;

  /// No description provided for @passwordShowTooltip.
  ///
  /// In hu, this message translates to:
  /// **'Megjelenítés'**
  String get passwordShowTooltip;

  /// No description provided for @tcpTargetsLabel.
  ///
  /// In hu, this message translates to:
  /// **'Célpontok (IP:port soronként)'**
  String get tcpTargetsLabel;

  /// No description provided for @tcpTargetsHint.
  ///
  /// In hu, this message translates to:
  /// **'192.168.1.50:1024\\n192.168.1.51:1024'**
  String get tcpTargetsHint;

  /// No description provided for @tcpTargetsHelp.
  ///
  /// In hu, this message translates to:
  /// **'A sender kliensként csatlakozik a fenti címekhez.'**
  String get tcpTargetsHelp;

  /// No description provided for @projectionMarginsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Margók'**
  String get projectionMarginsTitle;

  /// No description provided for @projectionMarginLeft.
  ///
  /// In hu, this message translates to:
  /// **'Bal margó'**
  String get projectionMarginLeft;

  /// No description provided for @projectionMarginRight.
  ///
  /// In hu, this message translates to:
  /// **'Jobb margó'**
  String get projectionMarginRight;

  /// No description provided for @projectionMarginTop.
  ///
  /// In hu, this message translates to:
  /// **'Felső margó'**
  String get projectionMarginTop;

  /// No description provided for @projectionMarginBottom.
  ///
  /// In hu, this message translates to:
  /// **'Alsó margó'**
  String get projectionMarginBottom;

  /// No description provided for @tcpInvalidTargetFormat.
  ///
  /// In hu, this message translates to:
  /// **'Hibás célpont formátum: {target}'**
  String tcpInvalidTargetFormat(Object target);

  /// No description provided for @userActionRegister.
  ///
  /// In hu, this message translates to:
  /// **'Regisztráció'**
  String get userActionRegister;

  /// No description provided for @userActionResendVerification.
  ///
  /// In hu, this message translates to:
  /// **'E-mail újraküldés'**
  String get userActionResendVerification;

  /// No description provided for @userActionDeleteUser.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználó törlése'**
  String get userActionDeleteUser;

  /// No description provided for @userActionChangePassword.
  ///
  /// In hu, this message translates to:
  /// **'Jelszóváltoztatás'**
  String get userActionChangePassword;

  /// No description provided for @userActionChangeEmail.
  ///
  /// In hu, this message translates to:
  /// **'E-mail-változtatás'**
  String get userActionChangeEmail;

  /// No description provided for @userActionChangeUsername.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználónév-változtatás'**
  String get userActionChangeUsername;

  /// No description provided for @userFieldUsername.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználónév'**
  String get userFieldUsername;

  /// No description provided for @userFieldPassword.
  ///
  /// In hu, this message translates to:
  /// **'Jelszó'**
  String get userFieldPassword;

  /// No description provided for @userFieldEmail.
  ///
  /// In hu, this message translates to:
  /// **'E-mail'**
  String get userFieldEmail;

  /// No description provided for @userFieldCurrentPassword.
  ///
  /// In hu, this message translates to:
  /// **'Jelenlegi jelszó'**
  String get userFieldCurrentPassword;

  /// No description provided for @userFieldNewPassword.
  ///
  /// In hu, this message translates to:
  /// **'Új jelszó'**
  String get userFieldNewPassword;

  /// No description provided for @userFieldNewEmail.
  ///
  /// In hu, this message translates to:
  /// **'Új e-mail'**
  String get userFieldNewEmail;

  /// No description provided for @userFieldCurrentUsername.
  ///
  /// In hu, this message translates to:
  /// **'Jelenlegi felhasználónév'**
  String get userFieldCurrentUsername;

  /// No description provided for @userFieldNewUsername.
  ///
  /// In hu, this message translates to:
  /// **'Új felhasználónév'**
  String get userFieldNewUsername;

  /// No description provided for @userActionRegisterSuccess.
  ///
  /// In hu, this message translates to:
  /// **'Sikeres regisztráció. Ellenőrizd az e-mail fiókot a megerősítéshez.'**
  String get userActionRegisterSuccess;

  /// No description provided for @userActionResendVerificationSuccess.
  ///
  /// In hu, this message translates to:
  /// **'Megerősítő e-mail újraküldve.'**
  String get userActionResendVerificationSuccess;

  /// No description provided for @userActionDeleteUserSuccess.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználó törölve.'**
  String get userActionDeleteUserSuccess;

  /// No description provided for @userActionChangePasswordSuccess.
  ///
  /// In hu, this message translates to:
  /// **'Jelszó sikeresen módosítva.'**
  String get userActionChangePasswordSuccess;

  /// No description provided for @userActionChangeEmailSuccess.
  ///
  /// In hu, this message translates to:
  /// **'E-mail-cím módosítási kérés elküldve.'**
  String get userActionChangeEmailSuccess;

  /// No description provided for @userActionChangeUsernameSuccess.
  ///
  /// In hu, this message translates to:
  /// **'Felhasználónév módosítva.'**
  String get userActionChangeUsernameSuccess;

  /// No description provided for @userDeleteConfirmTitle.
  ///
  /// In hu, this message translates to:
  /// **'Megerősítés'**
  String get userDeleteConfirmTitle;

  /// No description provided for @userDeleteConfirmMessage.
  ///
  /// In hu, this message translates to:
  /// **'Biztosan törölni szeretnéd ezt a felhasználót? Ez a művelet nem visszavonható.'**
  String get userDeleteConfirmMessage;

  /// No description provided for @userDeleteConfirmButton.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get userDeleteConfirmButton;

  /// No description provided for @userApiError.
  ///
  /// In hu, this message translates to:
  /// **'API hiba: {error}'**
  String userApiError(Object error);

  /// No description provided for @settingsHotkeyPressAnyKey.
  ///
  /// In hu, this message translates to:
  /// **'Nyomj meg bármelyik billentyű kombinációt...'**
  String get settingsHotkeyPressAnyKey;

  /// No description provided for @settingsHotkeyDialogTitle.
  ///
  /// In hu, this message translates to:
  /// **'Gyorsbillentyű rögzítése'**
  String get settingsHotkeyDialogTitle;

  /// No description provided for @settingsHotkeyConfirm.
  ///
  /// In hu, this message translates to:
  /// **'Megerősítés'**
  String get settingsHotkeyConfirm;

  /// No description provided for @settingsHotkeyClearCapture.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get settingsHotkeyClearCapture;

  /// No description provided for @settingsHotkeyClear.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get settingsHotkeyClear;

  /// No description provided for @settingsHotkeyCapture.
  ///
  /// In hu, this message translates to:
  /// **'Rögzítés'**
  String get settingsHotkeyCapture;
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
