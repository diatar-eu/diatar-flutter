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
  /// **'DiaVetítő'**
  String get appTitle;

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

  /// No description provided for @tcpPortRange.
  ///
  /// In hu, this message translates to:
  /// **'TCP port (0..65535)'**
  String get tcpPortRange;

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

  /// No description provided for @projectionFilteringTitle.
  ///
  /// In hu, this message translates to:
  /// **'Vetítés szűrése'**
  String get projectionFilteringTitle;

  /// No description provided for @receiverUseServerColors.
  ///
  /// In hu, this message translates to:
  /// **'Szerver színei'**
  String get receiverUseServerColors;

  /// No description provided for @receiverUseServerColorsHint.
  ///
  /// In hu, this message translates to:
  /// **'Ha ki van kapcsolva, a helyi színek lesznek használva.'**
  String get receiverUseServerColorsHint;

  /// No description provided for @receiverShowHighlight.
  ///
  /// In hu, this message translates to:
  /// **'Kiemelés megjelenítése'**
  String get receiverShowHighlight;

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

  /// No description provided for @localColorsTitle.
  ///
  /// In hu, this message translates to:
  /// **'Helyi színek'**
  String get localColorsTitle;

  /// No description provided for @backgroundColorLabel.
  ///
  /// In hu, this message translates to:
  /// **'Háttérszín'**
  String get backgroundColorLabel;

  /// No description provided for @textColorLabel.
  ///
  /// In hu, this message translates to:
  /// **'Szövegszín'**
  String get textColorLabel;

  /// No description provided for @blankColorLabel.
  ///
  /// In hu, this message translates to:
  /// **'Blank szín'**
  String get blankColorLabel;

  /// No description provided for @highlightColorLabel.
  ///
  /// In hu, this message translates to:
  /// **'Kiemelés szín'**
  String get highlightColorLabel;

  /// No description provided for @change.
  ///
  /// In hu, this message translates to:
  /// **'Vált'**
  String get change;

  /// No description provided for @colorPickerTitle.
  ///
  /// In hu, this message translates to:
  /// **'Színválasztó'**
  String get colorPickerTitle;

  /// No description provided for @exit.
  ///
  /// In hu, this message translates to:
  /// **'Kilépés'**
  String get exit;

  /// No description provided for @shutdown.
  ///
  /// In hu, this message translates to:
  /// **'Leállítás'**
  String get shutdown;

  /// No description provided for @reboot.
  ///
  /// In hu, this message translates to:
  /// **'Újraindítás'**
  String get reboot;

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

  /// No description provided for @ok.
  ///
  /// In hu, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @invalidPortRange.
  ///
  /// In hu, this message translates to:
  /// **'A port 0..65535 között legyen.'**
  String get invalidPortRange;

  /// No description provided for @statusStarting.
  ///
  /// In hu, this message translates to:
  /// **'Indítás...'**
  String get statusStarting;

  /// No description provided for @statusExitRequested.
  ///
  /// In hu, this message translates to:
  /// **'Kilépés...'**
  String get statusExitRequested;

  /// No description provided for @statusShutdownUnsupported.
  ///
  /// In hu, this message translates to:
  /// **'Rendszerleállítás Flutteren nem támogatott.'**
  String get statusShutdownUnsupported;

  /// No description provided for @statusRebootUnsupported.
  ///
  /// In hu, this message translates to:
  /// **'Rendszer újraindítás Flutteren nem támogatott.'**
  String get statusRebootUnsupported;

  /// No description provided for @statusStopRequested.
  ///
  /// In hu, this message translates to:
  /// **'Leállítás kérve (epStop).'**
  String get statusStopRequested;

  /// No description provided for @statusShutdownRequestedUnsupported.
  ///
  /// In hu, this message translates to:
  /// **'Rendszerleállítás kérve (epShutdown), Flutterben nem támogatott.'**
  String get statusShutdownRequestedUnsupported;

  /// No description provided for @statusReceiverError.
  ///
  /// In hu, this message translates to:
  /// **'{message}'**
  String statusReceiverError(Object message);

  /// No description provided for @statusMqttOff.
  ///
  /// In hu, this message translates to:
  /// **'MQTT kikapcsolva'**
  String get statusMqttOff;

  /// No description provided for @statusMqttReceiving.
  ///
  /// In hu, this message translates to:
  /// **'MQTT fogadás: {user}/{channel}'**
  String statusMqttReceiving(Object user, Object channel);

  /// No description provided for @statusConnected.
  ///
  /// In hu, this message translates to:
  /// **'Kapcsolódva ({port})'**
  String statusConnected(int port);

  /// No description provided for @statusWaitingForClient.
  ///
  /// In hu, this message translates to:
  /// **'Várakozás kliensre ({port})'**
  String statusWaitingForClient(int port);

  /// No description provided for @statusTcpOff.
  ///
  /// In hu, this message translates to:
  /// **'TCP kikapcsolva'**
  String get statusTcpOff;

  /// No description provided for @statusTcpListening.
  ///
  /// In hu, this message translates to:
  /// **'TCP figyelés: {port}'**
  String statusTcpListening(int port);

  /// No description provided for @statusTcpServerError.
  ///
  /// In hu, this message translates to:
  /// **'TCP hiba: {error}'**
  String statusTcpServerError(Object error);

  /// No description provided for @statusTcpServerOpenPortFailed.
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerült portot nyitni ({port}): {error}'**
  String statusTcpServerOpenPortFailed(int port, Object error);

  /// No description provided for @statusTcpServerClientError.
  ///
  /// In hu, this message translates to:
  /// **'Kliens hiba: {error}'**
  String statusTcpServerClientError(Object error);

  /// No description provided for @statusTcpServerPacketParseError.
  ///
  /// In hu, this message translates to:
  /// **'Csomag feldolgozási hiba: {error}'**
  String statusTcpServerPacketParseError(Object error);

  /// No description provided for @statusTcpServerSendError.
  ///
  /// In hu, this message translates to:
  /// **'Küldési hiba: {error}'**
  String statusTcpServerSendError(Object error);
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
