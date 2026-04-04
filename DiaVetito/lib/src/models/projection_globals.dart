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
