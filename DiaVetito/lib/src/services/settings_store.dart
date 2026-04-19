import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:diatar_common/diatar_common.dart';

class SettingsStore {
  static const String _kPort = 'Port';
  static const String _kBoot = 'Boot';
  static const String _kB2C = 'B2C';
  static const String _kClipL = 'ClipL';
  static const String _kClipR = 'ClipR';
  static const String _kClipT = 'ClipT';
  static const String _kClipB = 'ClipB';
  static const String _kMirror = 'Mirror';
  static const String _kRotate = 'Rotate';
  static const String _kUser = 'Username';
  static const String _kChannel = 'Channel';
  static const String _kReceiverUseServerColors = 'ReceiverUseServerColors';
  static const String _kReceiverShowHighlight = 'ReceiverShowHighlight';
  static const String _kReceiverUseAkkord = 'ReceiverUseAkkord';
  static const String _kReceiverUseKotta = 'ReceiverUseKotta';
  static const String _kBkColor = 'BkColor';
  static const String _kTxtColor = 'TxtColor';
  static const String _kBlankColor = 'BlankColor';
  static const String _kHiColor = 'HiColor';
  static const String _kProjAutoSize = 'ProjAutoSize';
  static const String _kAppLanguage = 'AppLanguage';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings(
      port: prefs.getInt(_kPort) ?? 1024,
      boot: prefs.getBool(_kBoot) ?? false,
      borderToClip: prefs.getBool(_kB2C) ?? false,
      clipL: prefs.getDouble(_kClipL) ?? 0,
      clipR: prefs.getDouble(_kClipR) ?? 0,
      clipT: prefs.getDouble(_kClipT) ?? 0,
      clipB: prefs.getDouble(_kClipB) ?? 0,
      mirror: prefs.getBool(_kMirror) ?? false,
      rotateQuarterTurns: prefs.getInt(_kRotate) ?? 0,
      mqttUser: prefs.getString(_kUser) ?? '',
      mqttChannel: prefs.getString(_kChannel) ?? '1',
      receiverUseServerColors: prefs.getBool(_kReceiverUseServerColors) ?? true,
      receiverShowHighlight: prefs.getBool(_kReceiverShowHighlight) ?? true,
      receiverUseAkkord: prefs.getBool(_kReceiverUseAkkord) ?? true,
      receiverUseKotta: prefs.getBool(_kReceiverUseKotta) ?? true,
      bkColor: Color(prefs.getInt(_kBkColor) ?? 0xFF000000),
      txtColor: Color(prefs.getInt(_kTxtColor) ?? 0xFFFFFFFF),
      blankColor: Color(prefs.getInt(_kBlankColor) ?? 0xFF000000),
      hiColor: Color(prefs.getInt(_kHiColor) ?? 0xFF00FFFF),
      projAutoSize: prefs.getBool(_kProjAutoSize) ?? false,
      appLanguage: prefs.getString(_kAppLanguage) ?? '',
    );
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPort, settings.port);
    await prefs.setBool(_kBoot, settings.boot);
    await prefs.setBool(_kB2C, settings.borderToClip);
    await prefs.setDouble(_kClipL, settings.clipL);
    await prefs.setDouble(_kClipR, settings.clipR);
    await prefs.setDouble(_kClipT, settings.clipT);
    await prefs.setDouble(_kClipB, settings.clipB);
    await prefs.setBool(_kMirror, settings.mirror);
    await prefs.setInt(_kRotate, settings.rotateQuarterTurns);
    await prefs.setString(_kUser, settings.mqttUser);
    await prefs.setString(_kChannel, settings.mqttChannel);
    await prefs.setBool(_kReceiverUseServerColors, settings.receiverUseServerColors);
    await prefs.setBool(_kReceiverShowHighlight, settings.receiverShowHighlight);
    await prefs.setBool(_kReceiverUseAkkord, settings.receiverUseAkkord);
    await prefs.setBool(_kReceiverUseKotta, settings.receiverUseKotta);
    await prefs.setInt(_kBkColor, settings.bkColor.toARGB32());
    await prefs.setInt(_kTxtColor, settings.txtColor.toARGB32());
    await prefs.setInt(_kBlankColor, settings.blankColor.toARGB32());
    await prefs.setInt(_kHiColor, settings.hiColor.toARGB32());
    await prefs.setBool(_kProjAutoSize, settings.projAutoSize);
    await prefs.setString(_kAppLanguage, settings.appLanguage);
  }
}
