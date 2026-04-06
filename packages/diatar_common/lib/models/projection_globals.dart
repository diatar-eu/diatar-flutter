import 'dart:typed_data';
import 'dart:ui';

import 'records.dart';

class ProjectionGlobals {
  const ProjectionGlobals({
    this.bkColor = const Color(0xFF000000),
    this.txtColor = const Color(0xFFFFFFFF),
    this.blankColor = const Color(0xFF000000),
    this.hiColor = const Color(0xFF00FFFF),
    this.fontSize = 20,
    this.titleSize = 10,
    this.leftIndent = 2,
    this.spacing100 = 100,
    this.hKey = 0,
    this.wordToHighlight = 0,
    this.borderL = 0,
    this.borderT = 0,
    this.borderR = 0,
    this.borderB = 0,
    this.fontName = '',
    this.isBlankPic = false,
    this.autoResize = true,
    this.projecting = false,
    this.showBlankPic = false,
    this.hCenter = false,
    this.vCenter = false,
    this.scholaMode = false,
    this.useAkkord = false,
    this.useKotta = false,
    this.useTransitions = false,
    this.endProgram = 0,
    this.hideTitle = false,
    this.inverzKotta = false,
    this.bgMode = 0,
    this.kottaArany = 100,
    this.akkordArany = 100,
    this.borderToClip = false,
    this.boldText = false,
  });

  final Color bkColor;
  final Color txtColor;
  final Color blankColor;
  final Color hiColor;
  final int fontSize;
  final int titleSize;
  final int leftIndent;
  final int spacing100;
  final int hKey;
  final int wordToHighlight;
  final int borderL;
  final int borderT;
  final int borderR;
  final int borderB;
  final String fontName;
  final bool isBlankPic;
  final bool autoResize;
  final bool projecting;
  final bool showBlankPic;
  final bool hCenter;
  final bool vCenter;
  final bool scholaMode;
  final bool useAkkord;
  final bool useKotta;
  final bool useTransitions;
  final int endProgram;
  final bool hideTitle;
  final bool inverzKotta;
  final int bgMode;
  final int kottaArany;
  final int akkordArany;
  final bool borderToClip;
  final bool boldText;

  ProjectionGlobals copyWith({
    Color? bkColor,
    Color? txtColor,
    Color? blankColor,
    Color? hiColor,
    int? fontSize,
    int? titleSize,
    int? leftIndent,
    int? spacing100,
    int? hKey,
    int? wordToHighlight,
    int? borderL,
    int? borderT,
    int? borderR,
    int? borderB,
    String? fontName,
    bool? isBlankPic,
    bool? autoResize,
    bool? projecting,
    bool? showBlankPic,
    bool? hCenter,
    bool? vCenter,
    bool? scholaMode,
    bool? useAkkord,
    bool? useKotta,
    bool? useTransitions,
    int? endProgram,
    bool? hideTitle,
    bool? inverzKotta,
    int? bgMode,
    int? kottaArany,
    int? akkordArany,
    bool? borderToClip,
    bool? boldText,
  }) {
    return ProjectionGlobals(
      bkColor: bkColor ?? this.bkColor,
      txtColor: txtColor ?? this.txtColor,
      blankColor: blankColor ?? this.blankColor,
      hiColor: hiColor ?? this.hiColor,
      fontSize: fontSize ?? this.fontSize,
      titleSize: titleSize ?? this.titleSize,
      leftIndent: leftIndent ?? this.leftIndent,
      spacing100: spacing100 ?? this.spacing100,
      hKey: hKey ?? this.hKey,
      wordToHighlight: wordToHighlight ?? this.wordToHighlight,
      borderL: borderL ?? this.borderL,
      borderT: borderT ?? this.borderT,
      borderR: borderR ?? this.borderR,
      borderB: borderB ?? this.borderB,
      fontName: fontName ?? this.fontName,
      isBlankPic: isBlankPic ?? this.isBlankPic,
      autoResize: autoResize ?? this.autoResize,
      projecting: projecting ?? this.projecting,
      showBlankPic: showBlankPic ?? this.showBlankPic,
      hCenter: hCenter ?? this.hCenter,
      vCenter: vCenter ?? this.vCenter,
      scholaMode: scholaMode ?? this.scholaMode,
      useAkkord: useAkkord ?? this.useAkkord,
      useKotta: useKotta ?? this.useKotta,
      useTransitions: useTransitions ?? this.useTransitions,
      endProgram: endProgram ?? this.endProgram,
      hideTitle: hideTitle ?? this.hideTitle,
      inverzKotta: inverzKotta ?? this.inverzKotta,
      bgMode: bgMode ?? this.bgMode,
      kottaArany: kottaArany ?? this.kottaArany,
      akkordArany: akkordArany ?? this.akkordArany,
      borderToClip: borderToClip ?? this.borderToClip,
      boldText: boldText ?? this.boldText,
    );
  }

  ProjectionGlobals fromState(RecStateRecord r) {
    return copyWith(
      bkColor: r.bkColor,
      txtColor: r.txtColor,
      blankColor: r.blankColor,
      hiColor: r.hiColor,
      fontSize: r.fontSize,
      titleSize: r.titleSize,
      leftIndent: r.leftIndent,
      spacing100: r.spacing100,
      hKey: r.hKey,
      wordToHighlight: r.wordToHighlight,
      borderL: r.borderL,
      borderT: r.borderT,
      borderR: r.borderR,
      borderB: r.borderB,
      fontName: r.fontName,
      isBlankPic: r.isBlankPic,
      autoResize: r.autoResize,
      projecting: r.projecting,
      showBlankPic: r.showBlankPic,
      hCenter: r.hCenter,
      vCenter: r.vCenter,
      scholaMode: r.scholaMode,
      useAkkord: r.useAkkord,
      useKotta: r.useKotta,
      useTransitions: r.useTransitions,
      endProgram: r.endProgram,
      hideTitle: r.hideTitle,
      inverzKotta: r.inverzKotta,
      bgMode: r.bgMode,
      kottaArany: r.kottaArany,
      akkordArany: r.akkordArany,
      boldText: r.boldText,
    );
  }
}

Uint8List encodeStateRecord(
  ProjectionGlobals globals, {
  required bool projecting,
  required int wordToHighlight,
  int? endProgram,
}) {
  final Uint8List body = Uint8List(349);

  void writeColor(int ofs, Color color) {
    body[ofs] = (color.r * 255.0).round() & 0xFF;
    body[ofs + 1] = (color.g * 255.0).round() & 0xFF;
    body[ofs + 2] = (color.b * 255.0).round() & 0xFF;
    body[ofs + 3] = 0;
  }

  void writeInt(int ofs, int value) {
    final ByteData bd = body.buffer.asByteData();
    bd.setInt32(ofs, value, Endian.little);
  }

  void writeBool(int ofs, bool value) {
    body[ofs] = value ? 1 : 0;
  }

  void writePascalString(int ofs, String value) {
    final List<int> units = value.codeUnits;
    final int len = units.length.clamp(0, 255);
    body[ofs] = len;
    for (int i = 0; i < len; i++) {
      body[ofs + 1 + i] = units[i] & 0xFF;
    }
  }

  writeColor(0, globals.bkColor);
  writeColor(4, globals.txtColor);
  writeColor(8, globals.blankColor);
  writeInt(12, globals.fontSize);
  writeInt(16, globals.titleSize);
  writeInt(20, globals.leftIndent);
  writeInt(24, globals.spacing100);
  writeInt(28, globals.hKey);
  writeInt(32, wordToHighlight);
  writeInt(36, globals.borderL);
  writeInt(40, globals.borderT);
  writeInt(44, globals.borderR);
  writeInt(48, globals.borderB);
  writePascalString(52, globals.fontName);
  writeBool(308, globals.isBlankPic);
  writeBool(309, globals.autoResize);
  writeBool(310, projecting);
  writeBool(311, globals.showBlankPic);
  writeBool(312, globals.hCenter);
  writeBool(313, globals.vCenter);
  writeBool(314, globals.scholaMode);
  writeBool(315, globals.useAkkord);
  writeBool(316, globals.useKotta);
  writeBool(317, globals.useTransitions);
  writeInt(318, endProgram ?? globals.endProgram);
  writeBool(322, globals.hideTitle);
  writeBool(323, globals.inverzKotta);
  writeInt(324, globals.bgMode);
  writeColor(328, globals.hiColor);
  writeInt(332, globals.kottaArany);
  writeInt(336, globals.akkordArany);
  writeInt(340, 0);
  writeInt(344, 0);
  writeBool(348, globals.boldText);
  return body;
}
