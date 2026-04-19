import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diatar_common/diatar_common.dart';

class SettingsStore {
  static const String _kPort = 'Port';
  static const String _kUser = 'Username';
  static const String _kPassword = 'Password';
  static const String _kChannel = 'Channel';
  static const String _kDtxPath = 'DtxPath';
  static const String _kBlankPicPath = 'BlankPicPath';
  static const String _kBkColor = 'BkColor';
  static const String _kTxColor = 'TxColor';
  static const String _kBlankColor = 'BlankColor';
  static const String _kHiColor = 'HiColor';
  static const String _kProjFontSize = 'ProjFontSize';
  static const String _kProjTitleSize = 'ProjTitleSize';
  static const String _kProjLeftIndent = 'ProjLeftIndent';
  static const String _kProjBorderL = 'ProjBorderL';
  static const String _kProjBorderT = 'ProjBorderT';
  static const String _kProjBorderR = 'ProjBorderR';
  static const String _kProjBorderB = 'ProjBorderB';
  static const String _kProjSpacingStep = 'ProjSpacingStep';
  static const String _kProjAutoSize = 'ProjAutoSize';
  static const String _kProjHCenter = 'ProjHCenter';
  static const String _kProjVCenter = 'ProjVCenter';
  static const String _kProjUseAkkord = 'ProjUseAkkord';
  static const String _kProjUseKotta = 'ProjUseKotta';
  static const String _kProjUseTitle = 'ProjUseTitle';
  static const String _kProjKottaArany = 'ProjKottaArany';
  static const String _kProjAkkordArany = 'ProjAkkordArany';
  static const String _kProjBoldText = 'ProjBoldText';
  static const String _kProjBgMode = 'ProjBgMode';
  static const String _kProjBackTrans = 'ProjBackTrans';
  static const String _kProjBlankTrans = 'ProjBlankTrans';
  static const String _kHomeViewMode = 'HomeViewMode';
  static const String _kAppThemeMode = 'AppThemeMode';
  static const String _kAppLanguage = 'AppLanguage';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings(
      port: prefs.getInt(_kPort) ?? 1024,
      boot: false,
      borderToClip: false,
      clipL: 0,
      clipR: 0,
      clipT: 0,
      clipB: 0,
      mirror: false,
      rotateQuarterTurns: 0,
      mqttUser: prefs.getString(_kUser) ?? '',
      mqttPassword: prefs.getString(_kPassword) ?? '',
      mqttChannel: prefs.getString(_kChannel) ?? '1',
      dtxPath: prefs.getString(_kDtxPath) ?? '',
      blankPicPath: prefs.getString(_kBlankPicPath) ?? '',
      projFontSize: prefs.getInt(_kProjFontSize) ?? 70,
      projTitleSize: prefs.getInt(_kProjTitleSize) ?? 12,
      projLeftIndent: prefs.getInt(_kProjLeftIndent) ?? 2,
      projBorderL: prefs.getInt(_kProjBorderL) ?? 0,
      projBorderT: prefs.getInt(_kProjBorderT) ?? 0,
      projBorderR: prefs.getInt(_kProjBorderR) ?? 0,
      projBorderB: prefs.getInt(_kProjBorderB) ?? 0,
      projSpacingStep: prefs.getInt(_kProjSpacingStep) ?? 0,
      projAutoSize: prefs.getBool(_kProjAutoSize) ?? true,
      projHCenter: prefs.getBool(_kProjHCenter) ?? false,
      projVCenter: prefs.getBool(_kProjVCenter) ?? true,
      projUseAkkord: prefs.getBool(_kProjUseAkkord) ?? false,
      projUseKotta: prefs.getBool(_kProjUseKotta) ?? true,
      projUseTitle: prefs.getBool(_kProjUseTitle) ?? true,
      projKottaArany: prefs.getInt(_kProjKottaArany) ?? 100,
      projAkkordArany: prefs.getInt(_kProjAkkordArany) ?? 100,
      projBoldText: prefs.getBool(_kProjBoldText) ?? false,
      projBgMode: prefs.getInt(_kProjBgMode) ?? 0,
      projBackTrans: prefs.getInt(_kProjBackTrans) ?? 0,
      projBlankTrans: prefs.getInt(_kProjBlankTrans) ?? 0,
      homeViewMode: prefs.getInt(_kHomeViewMode) ?? 0,
      appThemeMode: prefs.getInt(_kAppThemeMode) ?? 0,
      appLanguage: prefs.getString(_kAppLanguage) ?? '',
      bkColor: Color(prefs.getInt(_kBkColor) ?? 0xFF000000),
      txtColor: Color(prefs.getInt(_kTxColor) ?? 0xFFFFFFFF),
      blankColor: Color(prefs.getInt(_kBlankColor) ?? 0xFF000000),
      hiColor: Color(prefs.getInt(_kHiColor) ?? 0xFF00FFFF),
    );
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPort, settings.port);
    await prefs.setString(_kUser, settings.mqttUser);
    await prefs.setString(_kPassword, settings.mqttPassword);
    await prefs.setString(_kChannel, settings.mqttChannel);
    await prefs.setString(_kDtxPath, settings.dtxPath);
    await prefs.setString(_kBlankPicPath, settings.blankPicPath);
    await prefs.setInt(_kProjFontSize, settings.projFontSize);
    await prefs.setInt(_kProjTitleSize, settings.projTitleSize);
    await prefs.setInt(_kProjLeftIndent, settings.projLeftIndent);
    await prefs.setInt(_kProjBorderL, settings.projBorderL);
    await prefs.setInt(_kProjBorderT, settings.projBorderT);
    await prefs.setInt(_kProjBorderR, settings.projBorderR);
    await prefs.setInt(_kProjBorderB, settings.projBorderB);
    await prefs.setInt(_kProjSpacingStep, settings.projSpacingStep);
    await prefs.setBool(_kProjAutoSize, settings.projAutoSize);
    await prefs.setBool(_kProjHCenter, settings.projHCenter);
    await prefs.setBool(_kProjVCenter, settings.projVCenter);
    await prefs.setBool(_kProjUseAkkord, settings.projUseAkkord);
    await prefs.setBool(_kProjUseKotta, settings.projUseKotta);
    await prefs.setBool(_kProjUseTitle, settings.projUseTitle);
    await prefs.setInt(_kProjKottaArany, settings.projKottaArany);
    await prefs.setInt(_kProjAkkordArany, settings.projAkkordArany);
    await prefs.setBool(_kProjBoldText, settings.projBoldText);
    await prefs.setInt(_kProjBgMode, settings.projBgMode);
    await prefs.setInt(_kProjBackTrans, settings.projBackTrans);
    await prefs.setInt(_kProjBlankTrans, settings.projBlankTrans);
    await prefs.setInt(_kHomeViewMode, settings.homeViewMode);
    await prefs.setInt(_kAppThemeMode, settings.appThemeMode);
    await prefs.setString(_kAppLanguage, settings.appLanguage);
    await prefs.setInt(_kBkColor, settings.bkColor.toARGB32());
    await prefs.setInt(_kTxColor, settings.txtColor.toARGB32());
    await prefs.setInt(_kBlankColor, settings.blankColor.toARGB32());
    await prefs.setInt(_kHiColor, settings.hiColor.toARGB32());
  }
}
