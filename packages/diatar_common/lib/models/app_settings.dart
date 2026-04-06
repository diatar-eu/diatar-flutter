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
      bkColor: bkColor ?? this.bkColor,
      txtColor: txtColor ?? this.txtColor,
      blankColor: blankColor ?? this.blankColor,
      hiColor: hiColor ?? this.hiColor,
    );
  }
}
