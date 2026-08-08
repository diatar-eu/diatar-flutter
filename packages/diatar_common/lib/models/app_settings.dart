import 'package:flutter/widgets.dart';

class AppSettings {
  const AppSettings({
    this.port = 1024,
    this.tcpClientEnabled = true,
    this.tcpTargets = const <String>[],
    this.boot = false,
    this.remoteShutdownEnabled = false,
    this.borderToClip = false,
    this.clipL = 0,
    this.clipT = 0,
    this.clipR = 0,
    this.clipB = 0,
    this.mirror = false,
    this.rotateQuarterTurns = 0,
    this.mqttUser = '',
    this.mqttPassword = '',
    this.internetRelayEnabled = false,
    this.mqttChannel = '1',
    this.dtxPath = '',
    this.blankPicPath = '',
    this.diaExportPath = '',
    this.diaExportTreeUri = '',
    this.projFontSize = 255,
    this.projTitleSize = 12,
    this.projLeftIndent = 2,
    this.projBorderL = 0,
    this.projBorderT = 0,
    this.projBorderR = 0,
    this.projBorderB = 0,
    this.projSpacingStep = 0,
    this.projAutoSize = true,
    this.projHCenter = false,
    this.projVCenter = true,
    this.projUseAkkord = false,
    this.projUseKotta = true,
    this.projUseTitle = true,
    this.projKottaArany = 100,
    this.projAkkordArany = 100,
    this.projBoldText = false,
    this.projBgMode = 1,
    this.projBackTrans = 0,
    this.projBlankTrans = 0,
    this.projShowBackgroundImage = true,
    this.homeViewMode = 0,
    this.homeShowHighlightControls = false,
    this.homeLayoutMode = 0,
    this.presentationControlsVisible = false,
    this.appThemeMode = 0,
    this.appLanguage = '',
    this.projectionLocked = false,
    this.desktopProjectorEnabled = false,
    this.desktopProjectorMonitor = -1,
    this.desktopActionHotkeys = const <String, String>{},
    this.desktopSongHotkeys = const <String, String>{},
    this.desktopOrderSetHotkeys = const <String, String>{},
    this.receiverUseServerColors = true,
    this.receiverShowHighlight = true,
    this.receiverUseAkkord = true,
    this.receiverUseKotta = true,
    this.receiverKeepStartupLogo = true,
    this.useSound = false,
    this.castEnabled = false,
    this.castDeviceId = '',
    this.castPort = 1024,
    this.castAutoConnect = false,
    this.szentirasApiKey = '',
    Color? bkColor,
    Color? txtColor,
    Color? blankColor,
    Color? hiColor,
  }) : _bkColor = bkColor,
       _txtColor = txtColor,
       _blankColor = blankColor,
       _hiColor = hiColor;

  final int port;
  final bool tcpClientEnabled;
  final List<String> tcpTargets;
  final bool boot;
  final bool remoteShutdownEnabled;
  final bool borderToClip;
  final double clipL;
  final double clipT;
  final double clipR;
  final double clipB;
  final bool mirror;
  final int rotateQuarterTurns;
  final String mqttUser;
  final String mqttPassword;
  final bool internetRelayEnabled;
  final String mqttChannel;
  final String dtxPath;
  final String blankPicPath;
  final String diaExportPath;
  final String diaExportTreeUri;
  final int projFontSize;
  final int projTitleSize;
  final int projLeftIndent;
  final int projBorderL;
  final int projBorderT;
  final int projBorderR;
  final int projBorderB;
  final int projSpacingStep;
  final bool projAutoSize;
  final bool projHCenter;
  final bool projVCenter;
  final bool projUseAkkord;
  final bool projUseKotta;
  final bool projUseTitle;
  final int projKottaArany;
  final int projAkkordArany;
  final bool projBoldText;
  final int projBgMode;
  final int projBackTrans;
  final int projBlankTrans;
  final bool projShowBackgroundImage;
  final int homeViewMode;
  final bool homeShowHighlightControls;
  final int homeLayoutMode;
  final bool presentationControlsVisible;
  final int appThemeMode;
  final String appLanguage;
  final bool projectionLocked;
  final bool desktopProjectorEnabled;
  final int desktopProjectorMonitor;
  final Map<String, String> desktopActionHotkeys;
  final Map<String, String> desktopSongHotkeys;
  final Map<String, String> desktopOrderSetHotkeys;
  final bool receiverUseServerColors;
  final bool receiverShowHighlight;
  final bool receiverUseAkkord;
  final bool receiverUseKotta;
  final bool receiverKeepStartupLogo;
  final bool useSound;
  final bool castEnabled;
  final String castDeviceId;
  final int castPort;
  final bool castAutoConnect;
  final String szentirasApiKey;
  final Color? _bkColor;
  final Color? _txtColor;
  final Color? _blankColor;
  final Color? _hiColor;

  Color get bkColor => _bkColor ?? const Color(0xFF000000);
  Color get txtColor => _txtColor ?? const Color(0xFFFFFFFF);
  Color get blankColor => _blankColor ?? const Color(0xFF000000);
  Color get hiColor => _hiColor ?? const Color(0xFF00FFFF);

  bool get tcpEnabled =>
      !internetRelayEnabled && tcpClientEnabled && tcpTargets.isNotEmpty;

  EdgeInsets get clipInsets => EdgeInsets.fromLTRB(clipL, clipT, clipR, clipB);

  AppSettings copyWith({
    int? port,
    bool? tcpClientEnabled,
    List<String>? tcpTargets,
    bool? boot,
    bool? remoteShutdownEnabled,
    bool? borderToClip,
    double? clipL,
    double? clipT,
    double? clipR,
    double? clipB,
    bool? mirror,
    int? rotateQuarterTurns,
    String? mqttUser,
    String? mqttPassword,
    bool? internetRelayEnabled,
    String? mqttChannel,
    String? dtxPath,
    String? blankPicPath,
    String? diaExportPath,
    String? diaExportTreeUri,
    int? projFontSize,
    int? projTitleSize,
    int? projLeftIndent,
    int? projBorderL,
    int? projBorderT,
    int? projBorderR,
    int? projBorderB,
    int? projSpacingStep,
    bool? projAutoSize,
    bool? projHCenter,
    bool? projVCenter,
    bool? projUseAkkord,
    bool? projUseKotta,
    bool? projUseTitle,
    int? projKottaArany,
    int? projAkkordArany,
    bool? projBoldText,
    int? projBgMode,
    int? projBackTrans,
    int? projBlankTrans,
    bool? projShowBackgroundImage,
    int? homeViewMode,
    bool? homeShowHighlightControls,
    int? homeLayoutMode,
    bool? presentationControlsVisible,
    int? appThemeMode,
    String? appLanguage,
    bool? projectionLocked,
    bool? desktopProjectorEnabled,
    int? desktopProjectorMonitor,
    Map<String, String>? desktopActionHotkeys,
    Map<String, String>? desktopSongHotkeys,
    Map<String, String>? desktopOrderSetHotkeys,
    bool? receiverUseServerColors,
    bool? receiverShowHighlight,
    bool? receiverUseAkkord,
    bool? receiverUseKotta,
    bool? receiverKeepStartupLogo,
    bool? useSound,
    bool? castEnabled,
    String? castDeviceId,
    int? castPort,
    bool? castAutoConnect,
    String? szentirasApiKey,
    Color? bkColor,
    Color? txtColor,
    Color? blankColor,
    Color? hiColor,
  }) {
    return AppSettings(
      port: port ?? this.port,
      tcpClientEnabled: tcpClientEnabled ?? this.tcpClientEnabled,
      tcpTargets: tcpTargets ?? this.tcpTargets,
      boot: boot ?? this.boot,
      remoteShutdownEnabled:
          remoteShutdownEnabled ?? this.remoteShutdownEnabled,
      borderToClip: borderToClip ?? this.borderToClip,
      clipL: clipL ?? this.clipL,
      clipT: clipT ?? this.clipT,
      clipR: clipR ?? this.clipR,
      clipB: clipB ?? this.clipB,
      mirror: mirror ?? this.mirror,
      rotateQuarterTurns: rotateQuarterTurns ?? this.rotateQuarterTurns,
      mqttUser: mqttUser ?? this.mqttUser,
      mqttPassword: mqttPassword ?? this.mqttPassword,
      internetRelayEnabled: internetRelayEnabled ?? this.internetRelayEnabled,
      mqttChannel: mqttChannel ?? this.mqttChannel,
      dtxPath: dtxPath ?? this.dtxPath,
      blankPicPath: blankPicPath ?? this.blankPicPath,
      diaExportPath: diaExportPath ?? this.diaExportPath,
      diaExportTreeUri: diaExportTreeUri ?? this.diaExportTreeUri,
      projFontSize: projFontSize ?? this.projFontSize,
      projTitleSize: projTitleSize ?? this.projTitleSize,
      projLeftIndent: projLeftIndent ?? this.projLeftIndent,
      projBorderL: projBorderL ?? this.projBorderL,
      projBorderT: projBorderT ?? this.projBorderT,
      projBorderR: projBorderR ?? this.projBorderR,
      projBorderB: projBorderB ?? this.projBorderB,
      projSpacingStep: projSpacingStep ?? this.projSpacingStep,
      projAutoSize: projAutoSize ?? this.projAutoSize,
      projHCenter: projHCenter ?? this.projHCenter,
      projVCenter: projVCenter ?? this.projVCenter,
      projUseAkkord: projUseAkkord ?? this.projUseAkkord,
      projUseKotta: projUseKotta ?? this.projUseKotta,
      projUseTitle: projUseTitle ?? this.projUseTitle,
      projKottaArany: projKottaArany ?? this.projKottaArany,
      projAkkordArany: projAkkordArany ?? this.projAkkordArany,
      projBoldText: projBoldText ?? this.projBoldText,
      projBgMode: projBgMode ?? this.projBgMode,
      projBackTrans: projBackTrans ?? this.projBackTrans,
      projBlankTrans: projBlankTrans ?? this.projBlankTrans,
      projShowBackgroundImage:
          projShowBackgroundImage ?? this.projShowBackgroundImage,
      homeViewMode: homeViewMode ?? this.homeViewMode,
      homeShowHighlightControls:
          homeShowHighlightControls ?? this.homeShowHighlightControls,
      homeLayoutMode: homeLayoutMode ?? this.homeLayoutMode,
      presentationControlsVisible:
          presentationControlsVisible ?? this.presentationControlsVisible,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      appLanguage: appLanguage ?? this.appLanguage,
      projectionLocked: projectionLocked ?? this.projectionLocked,
      desktopProjectorEnabled:
          desktopProjectorEnabled ?? this.desktopProjectorEnabled,
        desktopProjectorMonitor:
            desktopProjectorMonitor ?? this.desktopProjectorMonitor,
      desktopActionHotkeys: desktopActionHotkeys ?? this.desktopActionHotkeys,
      desktopSongHotkeys: desktopSongHotkeys ?? this.desktopSongHotkeys,
      desktopOrderSetHotkeys:
          desktopOrderSetHotkeys ?? this.desktopOrderSetHotkeys,
      receiverUseServerColors:
          receiverUseServerColors ?? this.receiverUseServerColors,
      receiverShowHighlight:
          receiverShowHighlight ?? this.receiverShowHighlight,
      receiverUseAkkord: receiverUseAkkord ?? this.receiverUseAkkord,
      receiverUseKotta: receiverUseKotta ?? this.receiverUseKotta,
       receiverKeepStartupLogo:
           receiverKeepStartupLogo ?? this.receiverKeepStartupLogo,
       useSound: useSound ?? this.useSound,
       castEnabled: castEnabled ?? this.castEnabled,
       castDeviceId: castDeviceId ?? this.castDeviceId,
       castPort: castPort ?? this.castPort,
       castAutoConnect: castAutoConnect ?? this.castAutoConnect,
       szentirasApiKey: szentirasApiKey ?? this.szentirasApiKey,
       bkColor: bkColor ?? this.bkColor,
      txtColor: txtColor ?? this.txtColor,
      blankColor: blankColor ?? this.blankColor,
      hiColor: hiColor ?? this.hiColor,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'clipL': clipL,
      'clipT': clipT,
      'clipR': clipR,
      'clipB': clipB,
      'mirror': mirror,
      'rotateQuarterTurns': rotateQuarterTurns,
      'projFontSize': projFontSize,
      'projTitleSize': projTitleSize,
      'projLeftIndent': projLeftIndent,
      'projBorderL': projBorderL,
      'projBorderT': projBorderT,
      'projBorderR': projBorderR,
      'projBorderB': projBorderB,
      'projSpacingStep': projSpacingStep,
      'projAutoSize': projAutoSize,
      'projHCenter': projHCenter,
      'projVCenter': projVCenter,
      'projUseAkkord': projUseAkkord,
      'projUseKotta': projUseKotta,
      'projUseTitle': projUseTitle,
      'projKottaArany': projKottaArany,
      'projAkkordArany': projAkkordArany,
      'projBoldText': projBoldText,
      'projBgMode': projBgMode,
      'projBackTrans': projBackTrans,
      'projBlankTrans': projBlankTrans,
      'projShowBackgroundImage': projShowBackgroundImage,
      'diaExportTreeUri': diaExportTreeUri,
      'desktopProjectorEnabled': desktopProjectorEnabled,
      'desktopProjectorMonitor': desktopProjectorMonitor,
      'bkColor': bkColor.toARGB32(),
      'txtColor': txtColor.toARGB32(),
      'blankColor': blankColor.toARGB32(),
      'hiColor': hiColor.toARGB32(),
      'receiverUseServerColors': receiverUseServerColors,
      'receiverShowHighlight': receiverShowHighlight,
      'receiverUseAkkord': receiverUseAkkord,
      'receiverUseKotta': receiverUseKotta,
       'receiverKeepStartupLogo': receiverKeepStartupLogo,
       'useSound': useSound,
       'castEnabled': castEnabled,
       'castDeviceId': castDeviceId,
       'castPort': castPort,
       'castAutoConnect': castAutoConnect,
       'szentirasApiKey': szentirasApiKey,
     };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    int intValue(String key, int fallback) {
      final Object? raw = map[key];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return fallback;
    }

    bool boolValue(String key, bool fallback) {
      final Object? raw = map[key];
      if (raw is bool) {
        return raw;
      }
      return fallback;
    }

    Color colorValue(String key, Color fallback) {
      final Object? raw = map[key];
      if (raw is int) {
        return Color(raw);
      }
      if (raw is num) {
        return Color(raw.toInt());
      }
      return fallback;
    }

    return AppSettings(
      clipL: (map['clipL'] as num?)?.toDouble() ?? 0,
      clipT: (map['clipT'] as num?)?.toDouble() ?? 0,
      clipR: (map['clipR'] as num?)?.toDouble() ?? 0,
      clipB: (map['clipB'] as num?)?.toDouble() ?? 0,
      mirror: boolValue('mirror', false),
      rotateQuarterTurns: intValue('rotateQuarterTurns', 0),
      projFontSize: intValue('projFontSize', 70),
      projTitleSize: intValue('projTitleSize', 12),
      projLeftIndent: intValue('projLeftIndent', 2),
      projBorderL: intValue('projBorderL', 0),
      projBorderT: intValue('projBorderT', 0),
      projBorderR: intValue('projBorderR', 0),
      projBorderB: intValue('projBorderB', 0),
      projSpacingStep: intValue('projSpacingStep', 0),
      projAutoSize: boolValue('projAutoSize', true),
      projHCenter: boolValue('projHCenter', false),
      projVCenter: boolValue('projVCenter', true),
      projUseAkkord: boolValue('projUseAkkord', false),
      projUseKotta: boolValue('projUseKotta', true),
      projUseTitle: boolValue('projUseTitle', true),
      projKottaArany: intValue('projKottaArany', 100),
      projAkkordArany: intValue('projAkkordArany', 100),
      projBoldText: boolValue('projBoldText', false),
      projBgMode: intValue('projBgMode', 0),
      projBackTrans: intValue('projBackTrans', 0),
      projBlankTrans: intValue('projBlankTrans', 0),
      projShowBackgroundImage: boolValue('projShowBackgroundImage', true),
      diaExportTreeUri: map['diaExportTreeUri'] as String? ?? '',
      desktopProjectorEnabled: boolValue('desktopProjectorEnabled', false),
      desktopProjectorMonitor: intValue('desktopProjectorMonitor', -1),
      bkColor: colorValue('bkColor', const Color(0xFF000000)),
      txtColor: colorValue('txtColor', const Color(0xFFFFFFFF)),
      blankColor: colorValue('blankColor', const Color(0xFF000000)),
      hiColor: colorValue('hiColor', const Color(0xFF00FFFF)),
      receiverUseServerColors: boolValue('receiverUseServerColors', true),
      receiverShowHighlight: boolValue('receiverShowHighlight', true),
      receiverUseAkkord: boolValue('receiverUseAkkord', true),
      receiverUseKotta: boolValue('receiverUseKotta', true),
       receiverKeepStartupLogo: boolValue('receiverKeepStartupLogo', true),
       useSound: boolValue('useSound', false),
       castEnabled: boolValue('castEnabled', false),
       castDeviceId: map['castDeviceId'] as String? ?? '',
       castPort: intValue('castPort', 1024),
       castAutoConnect: boolValue('castAutoConnect', false),
       szentirasApiKey: map['szentirasApiKey'] as String? ?? '',
     );
  }
}
