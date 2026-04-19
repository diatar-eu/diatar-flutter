import 'package:flutter/widgets.dart';

class AppSettings {
  const AppSettings({
    this.port = 1024,
    this.boot = false,
    this.borderToClip = false,
    this.clipL = 0,
    this.clipT = 0,
    this.clipR = 0,
    this.clipB = 0,
    this.mirror = false,
    this.rotateQuarterTurns = 0,
    this.mqttUser = '',
    this.mqttPassword = '',
    this.mqttChannel = '1',
    this.dtxPath = '',
    this.blankPicPath = '',
    this.projFontSize = 70,
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
    this.projBgMode = 0,
    this.projBackTrans = 0,
    this.projBlankTrans = 0,
    this.homeViewMode = 0,
    this.appThemeMode = 0,
    this.appLanguage = '',
    this.receiverUseServerColors = true,
    this.receiverShowHighlight = true,
    this.receiverUseAkkord = true,
    this.receiverUseKotta = true,
    Color? bkColor,
    Color? txtColor,
    Color? blankColor,
    Color? hiColor,
  })  : _bkColor = bkColor,
        _txtColor = txtColor,
        _blankColor = blankColor,
        _hiColor = hiColor;

  final int port;
  final bool boot;
  final bool borderToClip;
  final double clipL;
  final double clipT;
  final double clipR;
  final double clipB;
  final bool mirror;
  final int rotateQuarterTurns;
  final String mqttUser;
  final String mqttPassword;
  final String mqttChannel;
  final String dtxPath;
  final String blankPicPath;
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
  final int homeViewMode;
  final int appThemeMode;
  final String appLanguage;
  final bool receiverUseServerColors;
  final bool receiverShowHighlight;
  final bool receiverUseAkkord;
  final bool receiverUseKotta;
  final Color? _bkColor;
  final Color? _txtColor;
  final Color? _blankColor;
  final Color? _hiColor;

  Color get bkColor => _bkColor ?? const Color(0xFF000000);
  Color get txtColor => _txtColor ?? const Color(0xFFFFFFFF);
  Color get blankColor => _blankColor ?? const Color(0xFF000000);
  Color get hiColor => _hiColor ?? const Color(0xFF00FFFF);

  bool get tcpEnabled => mqttUser.trim().isEmpty && port > 0;

  EdgeInsets get clipInsets => EdgeInsets.fromLTRB(clipL, clipT, clipR, clipB);

  AppSettings copyWith({
    int? port,
    bool? boot,
    bool? borderToClip,
    double? clipL,
    double? clipT,
    double? clipR,
    double? clipB,
    bool? mirror,
    int? rotateQuarterTurns,
    String? mqttUser,
    String? mqttPassword,
    String? mqttChannel,
    String? dtxPath,
    String? blankPicPath,
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
    int? homeViewMode,
    int? appThemeMode,
    String? appLanguage,
    bool? receiverUseServerColors,
    bool? receiverShowHighlight,
    bool? receiverUseAkkord,
    bool? receiverUseKotta,
    Color? bkColor,
    Color? txtColor,
    Color? blankColor,
    Color? hiColor,
  }) {
    return AppSettings(
      port: port ?? this.port,
      boot: boot ?? this.boot,
      borderToClip: borderToClip ?? this.borderToClip,
      clipL: clipL ?? this.clipL,
      clipT: clipT ?? this.clipT,
      clipR: clipR ?? this.clipR,
      clipB: clipB ?? this.clipB,
      mirror: mirror ?? this.mirror,
      rotateQuarterTurns: rotateQuarterTurns ?? this.rotateQuarterTurns,
      mqttUser: mqttUser ?? this.mqttUser,
      mqttPassword: mqttPassword ?? this.mqttPassword,
      mqttChannel: mqttChannel ?? this.mqttChannel,
      dtxPath: dtxPath ?? this.dtxPath,
      blankPicPath: blankPicPath ?? this.blankPicPath,
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
      homeViewMode: homeViewMode ?? this.homeViewMode,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      appLanguage: appLanguage ?? this.appLanguage,
      receiverUseServerColors: receiverUseServerColors ?? this.receiverUseServerColors,
      receiverShowHighlight: receiverShowHighlight ?? this.receiverShowHighlight,
      receiverUseAkkord: receiverUseAkkord ?? this.receiverUseAkkord,
      receiverUseKotta: receiverUseKotta ?? this.receiverUseKotta,
      bkColor: bkColor ?? this.bkColor,
      txtColor: txtColor ?? this.txtColor,
      blankColor: blankColor ?? this.blankColor,
      hiColor: hiColor ?? this.hiColor,
    );
  }
}
