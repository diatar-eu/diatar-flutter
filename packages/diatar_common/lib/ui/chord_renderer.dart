import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ChordPartStyle { root, normal, superscript }

/// How the quality of a chord is spelled on screen.
///
/// The three variants mirror the "Szimbólumos" / "Szöveges" / "Számjegyes"
/// columns of the Akkordok sheet. Each one falls back to the column on its
/// left when a modifier has no entry of its own, so numeric notation degrades
/// to textual and then to symbolic instead of rendering nothing.
enum ChordNotation {
  /// Symbols: C, Cm, C°, C△, Cø, C+7sus4 …
  symbolic,

  /// Words: Caug, Cdim, Cmaj, Cm7♭5 …
  textual,

  /// Numbers: C#5, Cm♭5, Cmmaj7♭5 …
  numeric,
}

class ChordPart {
  const ChordPart(this.text, this.style);

  final String text;
  final ChordPartStyle style;
}

/// Parses and renders Diatár's compact chord notation.
class DiatarChord {
  const DiatarChord._({
    required this.root,
    required this.accidental,
    required this.isMinor,
    required this.modifier,
    required this.bass,
    required this.bassAccidental,
  });

  static const List<String> _inputModifiers = <String>[
    '',
    '#',
    'o',
    '7',
    '7+',
    'o7',
    'o7-',
    'o7+',
    '#7',
    '#7+',
    '6',
    '79',
    '79-',
    '79+',
    '#79',
    '#79+',
    '7+9',
    '7+9+',
    '#7+9',
    '#7+9+',
    'o79',
    'o79-',
    '9',
    '9-',
    '9+',
    '#9',
    '#9+',
    'o9',
    'o9-',
    '4',
    '2',
    '47',
    '27',
    '49',
    '49-',
    '49+',
  ];

  /// Modifier tails for [ChordNotation.symbolic], indexed like
  /// [_inputModifiers]. A leading `^` marks the following character as a
  /// superscript, matching the sheet's own markup. Every entry is populated,
  /// so this column never needs a fallback.
  static const List<String> _symbolicModifiers = <String>[
    '', // (major)
    '^+', // #
    '°', // o
    '^7', // 7
    '^△', // 7+
    '^ø', // o7
    '°^7', // o7-
    '°^△', // o7+
    '^+^7', // #7
    '^+^△', // #7+
    '^6', // 6
    '^9', // 79
    '^♭^9', // 79-
    '^#^9', // 79+
    '^+^9', // #79
    '^+^#^9', // #79+
    '^△^9', // 7+9
    '^△^#^9', // 7+9+
    '^+^△^9', // #7+9
    '^+^△^#^9', // #7+9+
    '^ø^9', // o79
    '^ø^♭^9', // o79-
    '^a^d^d^9', // 9
    '^a^d^d^♭^9', // 9-
    '^a^d^d^#^9', // 9+
    '^+^a^d^d^9', // #9
    '^+^a^d^d^#^9', // #9+
    '°^a^d^d^9', // o9
    '°^a^d^d^♭^9', // o9-
    '^s^u^s^4', // 4
    '^s^u^s^2', // 2
    '^7^s^u^s^4', // 47
    '^7^s^u^s^2', // 27
    '^9^s^u^s^4', // 49
    '^♭^9^s^u^s^4', // 49-
    '^#^9^s^u^s^4', // 49+
  ];

  /// Modifier tails for [ChordNotation.textual]. An empty entry means the
  /// sheet has no textual spelling and the symbolic one is used instead.
  static const List<String> _textualModifiers = <String>[
    '', // (major)
    '^a^u^g', // #
    '^d^i^m', // o
    '', // 7
    '^m^a^j', // 7+
    'm^7^♭^5', // o7
    '^d^i^m^7', // o7-
    '^d^i^m^(^m^a^j^)', // o7+
    '^a^u^g^7', // #7
    '^a^u^g^(^m^a^j^)', // #7+
    '', // 6
    '', // 79
    '', // 79-
    '', // 79+
    '^a^u^g^9', // #79
    '^a^u^g^#^9', // #79+
    '^m^a^j^9', // 7+9
    '^m^a^j^#^9', // 7+9+
    '^a^u^g^(^m^a^j^9^)', // #7+9
    '^a^u^g^(^m^a^j^#^9^)', // #7+9+
    'm^9^♭^5', // o79
    'm^♭^9^♭^5', // o79-
    '', // 9
    '', // 9-
    '', // 9+
    '^a^u^g^(^a^d^d^9^)', // #9
    '^a^u^g^(^a^d^d^#^9^)', // #9+
    '^d^i^m^(^a^d^d^9^)', // o9
    '^d^i^m^(^a^d^d^♭^9^)', // o9-
    '', // 4
    '', // 2
    '', // 47
    '', // 27
    '', // 49
    '', // 49-
    '', // 49+
  ];

  /// Modifier tails for [ChordNotation.numeric], with the same fallback rule
  /// as [_textualModifiers] plus one more step down to [_symbolicModifiers].
  static const List<String> _numericModifiers = <String>[
    '', // (major)
    '^#^5', // #
    'm^♭^5', // o
    '', // 7
    '', // 7+
    '', // o7
    '^♭^7^♭^5', // o7-
    'm^m^a^j^7^♭^5', // o7+
    '^7^#^5', // #7
    '^m^a^j^7^#^5', // #7+
    '', // 6
    '', // 79
    '', // 79-
    '', // 79+
    '^9^#^5', // #79
    '^#^9^#^5', // #79+
    '', // 7+9
    '', // 7+9+
    '^m^a^j^9^#^5', // #7+9
    '^m^a^j^#^9^#^5', // #7+9+
    '', // o79
    '', // o79-
    '', // 9
    '', // 9-
    '', // 9+
    '', // #9
    '', // #9+
    '', // o9
    '', // o9-
    '', // 4
    '', // 2
    '', // 47
    '', // 27
    '', // 49
    '', // 49-
    '', // 49+
  ];

  /// Modifiers whose spelling omits the seventh, so the optional "7" switch
  /// documented in the sheet's notes column can reveal it (C△7, Cmaj7, C°△7,
  /// Cdim(maj7), Caug(maj7)).
  static const Set<int> _optionalSeventhModifiers = <int>{4, 7, 9};

  /// Resolves the modifier tail for [notation], walking the sheet's columns
  /// from the requested one towards the symbolic one until a value is found.
  static String _modifierTemplate(ChordNotation notation, int index) {
    switch (notation) {
      case ChordNotation.symbolic:
        return _symbolicModifiers[index];
      case ChordNotation.textual:
        final String own = _textualModifiers[index];
        return own.isNotEmpty ? own : _symbolicModifiers[index];
      case ChordNotation.numeric:
        final String own = _numericModifiers[index];
        if (own.isNotEmpty) {
          return own;
        }
        final String textual = _textualModifiers[index];
        return textual.isNotEmpty ? textual : _symbolicModifiers[index];
    }
  }

  /// Expands a modifier tail into parts, turning `^x` runs into a single
  /// superscript part each.
  static List<ChordPart> _templateParts(String template) {
    final List<ChordPart> result = <ChordPart>[];
    bool superscriptNext = false;
    for (int i = 0; i < template.length; i++) {
      final String character = template[i];
      if (character == '^') {
        superscriptNext = true;
        continue;
      }
      final ChordPartStyle style = superscriptNext
          ? ChordPartStyle.superscript
          : ChordPartStyle.normal;
      superscriptNext = false;
      if (result.isNotEmpty && result.last.style == style) {
        final ChordPart last = result.removeLast();
        result.add(ChordPart(last.text + character, style));
      } else {
        result.add(ChordPart(character, style));
      }
    }
    return result;
  }

  /// Builds the quality tail of a chord for the requested notation, optionally
  /// revealing the seventh that the chosen spelling leaves implicit.
  static List<ChordPart> _modifierParts(
    int index,
    ChordNotation notation, {
    required bool optionalSeventh,
  }) {
    final String template = _modifierTemplate(notation, index);
    // A spelling that already writes the seventh out — such as the numeric
    // Cmmaj7♭5 — must not gain a second one.
    if (!optionalSeventh ||
        !_optionalSeventhModifiers.contains(index) ||
        template.contains('7')) {
      return _templateParts(template);
    }
    // The sheet keeps the seventh inside the parentheses of e.g. dim(maj7).
    final int insertAt = template.endsWith(')')
        ? template.length - 1
        : template.length;
    return <ChordPart>[
      ..._templateParts(template.substring(0, insertAt)),
      const ChordPart('7', ChordPartStyle.superscript),
      ..._templateParts(template.substring(insertAt)),
    ];
  }

  static const Set<int> _minorModifiers = <int>{
    0,
    3,
    4,
    10,
    11,
    12,
    16,
    22,
    23,
  };

  final String root;
  final String? accidental;
  final bool isMinor;
  final int modifier;
  final String? bass;
  final String? bassAccidental;

  static List<String> get supportedModifiers =>
      List<String>.unmodifiable(_inputModifiers);

  String get rootCode => '$root${accidental ?? ''}';

  String get modifierCode => _inputModifiers[modifier];

  String? get bassCode => bass == null ? null : '$bass${bassAccidental ?? ''}';

  static bool supportsModifier(String modifier, {required bool minor}) {
    final int index = _inputModifiers.indexOf(modifier);
    return index >= 0 && (!minor || _minorModifiers.contains(index));
  }

  String get source {
    final StringBuffer result = StringBuffer()
      ..write(root)
      ..write(accidental ?? '');
    if (isMinor) {
      result.write('m');
    }
    result.write(_inputModifiers[modifier]);
    if (bass != null) {
      result
        ..write('/')
        ..write(bass)
        ..write(bassAccidental ?? '');
    }
    return result.toString();
  }

  String transpose(int semitones) {
    final bool useFlats = accidental == '-';
    final String transposedRoot = _transposeNote(
      root,
      accidental,
      semitones,
      useFlats: useFlats,
    );
    final StringBuffer result = StringBuffer(transposedRoot);
    if (isMinor) {
      result.write('m');
    }
    result.write(_inputModifiers[modifier]);
    if (bass != null) {
      result
        ..write('/')
        ..write(
          _transposeNote(bass!, bassAccidental, semitones, useFlats: useFlats),
        );
    }
    return result.toString();
  }

  static DiatarChord? tryParse(String source) {
    if (source.isEmpty) {
      return null;
    }

    final _ChordNote? rootNote = _parseNote(source, 0, allowMinor: true);
    if (rootNote == null) {
      return null;
    }

    final int slashIndex = source.indexOf('/', rootNote.end);
    if (slashIndex != -1 && source.indexOf('/', slashIndex + 1) != -1) {
      return null;
    }
    final String modifierText = source.substring(
      rootNote.end,
      slashIndex == -1 ? source.length : slashIndex,
    );
    final int modifier = _inputModifiers.indexOf(modifierText);
    if (modifier == -1 ||
        (rootNote.isMinor && !_minorModifiers.contains(modifier))) {
      return null;
    }

    _ChordNote? bassNote;
    if (slashIndex != -1) {
      bassNote = _parseNote(source, slashIndex + 1, allowMinor: false);
      if (bassNote == null || bassNote.end != source.length) {
        return null;
      }
    }

    return DiatarChord._(
      root: rootNote.letter,
      accidental: rootNote.accidental,
      isMinor: rootNote.isMinor,
      modifier: modifier,
      bass: bassNote?.letter,
      bassAccidental: bassNote?.accidental,
    );
  }

  static _ChordNote? _parseNote(
    String source,
    int start, {
    required bool allowMinor,
  }) {
    if (start >= source.length) {
      return null;
    }

    String letter = source[start].toUpperCase();
    if (letter == 'B') {
      letter = 'H';
    }
    if (!'CDEFGAH'.contains(letter)) {
      return null;
    }

    int end = start + 1;
    String? accidental;
    if (end < source.length && '+-'.contains(source[end])) {
      accidental = source[end++];
    }
    bool isMinor = false;
    if (allowMinor && end < source.length && source[end] == 'm') {
      isMinor = true;
      end++;
    }
    return _ChordNote(
      letter: letter,
      accidental: accidental,
      isMinor: isMinor,
      end: end,
    );
  }

  /// Splits the chord into the parts that [ChordLayout] paints.
  ///
  /// The root letter, its accidental and the minor marker are bold, matching
  /// the sheet where `C`, `C#`, `C♭` and `Cm` all share the strong style while
  /// the quality tail is superscripted.
  List<ChordPart> parts({
    ChordNotation notation = ChordNotation.symbolic,
    bool optionalSeventh = false,
    bool minorAsDash = false,
  }) {
    final List<ChordPart> result = <ChordPart>[
      ChordPart(_displayLetter(root, accidental), ChordPartStyle.root),
    ];
    final String rootAccidental = _accidentalSuffix(root, accidental);
    if (rootAccidental.isNotEmpty) {
      result.add(ChordPart(rootAccidental, ChordPartStyle.root));
    }
    if (isMinor) {
      result.add(ChordPart(minorAsDash ? '-' : 'm', ChordPartStyle.root));
    }
    result.addAll(
      _modifierParts(modifier, notation, optionalSeventh: optionalSeventh),
    );
    if (bass != null) {
      result.add(const ChordPart('/', ChordPartStyle.normal));
      result.add(
        ChordPart(_displayLetter(bass!, bassAccidental), ChordPartStyle.normal),
      );
      final String bassSuffix = _accidentalSuffix(bass!, bassAccidental);
      if (bassSuffix.isNotEmpty) {
        result.add(ChordPart(bassSuffix, ChordPartStyle.normal));
      }
    }
    return result;
  }

  /// `H` is spelled `B`; every other letter keeps its own name.
  static String _displayLetter(String letter, String? accidental) {
    return letter == 'H' && accidental == '-' ? 'B' : letter;
  }

  /// Accidentals use sharps and flats, not the Hungarian `is`/`es` suffixes.
  static String _accidentalSuffix(String letter, String? accidental) {
    if (accidental == '+') {
      return '#';
    }
    if (accidental == '-') {
      // Already carried by the `B` spelling of `H-`.
      return letter == 'H' ? '' : '♭';
    }
    return '';
  }

  static String _transposeNote(
    String letter,
    String? accidental,
    int semitones, {
    required bool useFlats,
  }) {
    const Map<String, int> naturalSemitones = <String, int>{
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'H': 11,
    };
    const List<String> sharps = <String>[
      'C',
      'C+',
      'D',
      'D+',
      'E',
      'F',
      'F+',
      'G',
      'G+',
      'A',
      'A+',
      'H',
    ];
    const List<String> flats = <String>[
      'C',
      'D-',
      'D',
      'E-',
      'E',
      'F',
      'G-',
      'G',
      'A-',
      'A',
      'H-',
      'H',
    ];

    int pitch = naturalSemitones[letter]!;
    if (accidental == '+') {
      pitch++;
    } else if (accidental == '-') {
      pitch--;
    }
    final int transposed = (pitch + semitones) % 12;
    return (useFlats ? flats : sharps)[transposed];
  }
}

class ChordDisplay extends StatelessWidget {
  const ChordDisplay({
    super.key,
    required this.source,
    required this.style,
    this.borderColor,
    this.backgroundColor = Colors.transparent,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.borderRadius = 3,
    this.notation = ChordNotation.symbolic,
    this.optionalSeventh = false,
    this.minorAsDash = false,
  });

  final String source;
  final TextStyle style;
  final Color? borderColor;
  final Color backgroundColor;
  final EdgeInsets padding;
  final double borderRadius;
  final ChordNotation notation;
  final bool optionalSeventh;
  final bool minorAsDash;

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveStyle = DefaultTextStyle.of(
      context,
    ).style.merge(style);
    final ChordLayout layout = ChordRenderer.layout(
      source,
      effectiveStyle,
      notation: notation,
      optionalSeventh: optionalSeventh,
      minorAsDash: minorAsDash,
    );
    final Size size = Size(
      layout.width + padding.horizontal,
      layout.height + padding.vertical,
    );
    final Color effectiveBorderColor =
        borderColor ??
        effectiveStyle.color ??
        Theme.of(context).colorScheme.outline;
    return Semantics(
      label: source,
      child: CustomPaint(
        size: size,
        painter: _ChordDisplayPainter(
          layout: layout,
          padding: padding,
          borderColor: effectiveBorderColor,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class _ChordDisplayPainter extends CustomPainter {
  const _ChordDisplayPainter({
    required this.layout,
    required this.padding,
    required this.borderColor,
    required this.backgroundColor,
    required this.borderRadius,
  });

  final ChordLayout layout;
  final EdgeInsets padding;
  final Color borderColor;
  final Color backgroundColor;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    if (backgroundColor.a > 0) {
      canvas.drawRRect(frame, Paint()..color = backgroundColor);
    }
    canvas.drawRRect(
      frame,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    layout.paint(canvas, Offset(padding.left, padding.top));
  }

  @override
  bool shouldRepaint(_ChordDisplayPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.padding != padding ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _ChordNote {
  const _ChordNote({
    required this.letter,
    required this.accidental,
    required this.isMinor,
    required this.end,
  });

  final String letter;
  final String? accidental;
  final bool isMinor;
  final int end;
}

/// Lays out a chord so every consumer uses the same notation and styling.
class ChordRenderer {
  static ChordLayout layout(
    String source,
    TextStyle style, {
    ChordNotation notation = ChordNotation.symbolic,
    bool optionalSeventh = false,
    bool minorAsDash = false,
  }) {
    final DiatarChord? chord = DiatarChord.tryParse(source);
    final List<ChordPart> parts =
        chord?.parts(
          notation: notation,
          optionalSeventh: optionalSeventh,
          minorAsDash: minorAsDash,
        ) ??
        <ChordPart>[ChordPart(source, ChordPartStyle.normal)];
    return ChordLayout._(parts, style);
  }
}

class ChordLayout {
  ChordLayout._(List<ChordPart> parts, TextStyle style) {
    final List<_ChordPartLayout> layouts = <_ChordPartLayout>[
      for (final ChordPart part in parts)
        _ChordPartLayout(
          style: part.style,
          painter: TextPainter(
            text: TextSpan(
              text: part.text,
              style: switch (part.style) {
                ChordPartStyle.root => style.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                ChordPartStyle.normal => style,
                ChordPartStyle.superscript => style.copyWith(
                  fontSize: (style.fontSize ?? 14) * 0.7,
                ),
              },
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        ),
    ];
    final double baseFontSize = style.fontSize ?? 14;
    final double normalBaseline = layouts
        .where(
          (_ChordPartLayout part) => part.style != ChordPartStyle.superscript,
        )
        .map((_ChordPartLayout part) => part.baseline)
        .fold(0, (double maximum, double value) => math.max(maximum, value));
    final double superscriptBaseline = normalBaseline - baseFontSize * 0.5;
    final List<double> rawTopOffsets = <double>[
      for (final _ChordPartLayout part in layouts)
        (part.style == ChordPartStyle.superscript
                ? superscriptBaseline
                : normalBaseline) -
            part.baseline,
    ];
    final double minTop = rawTopOffsets.fold(
      0,
      (double minimum, double value) => math.min(minimum, value),
    );
    _parts = <_ChordPartLayout>[
      for (int i = 0; i < layouts.length; i++)
        layouts[i].withTop(rawTopOffsets[i] - minTop),
    ];
  }

  late final List<_ChordPartLayout> _parts;

  double get width => _parts.fold(
    0,
    (double total, _ChordPartLayout part) => total + part.painter.width,
  );

  double get height => _parts.fold(
    0,
    (double maximum, _ChordPartLayout part) =>
        math.max(maximum, part.top + part.painter.height),
  );

  @visibleForTesting
  List<double> get debugPartTopOffsets =>
      _parts.map((_ChordPartLayout part) => part.top).toList();

  void paint(Canvas canvas, Offset offset) {
    double x = offset.dx;
    for (final _ChordPartLayout part in _parts) {
      part.painter.paint(canvas, Offset(x, offset.dy + part.top));
      x += part.painter.width;
    }
  }
}

class _ChordPartLayout {
  const _ChordPartLayout({
    required this.style,
    required this.painter,
    this.top = 0,
  });

  final ChordPartStyle style;
  final TextPainter painter;
  final double top;

  double get baseline {
    final List<ui.LineMetrics> metrics = painter.computeLineMetrics();
    return metrics.isEmpty ? painter.height : metrics.first.baseline;
  }

  _ChordPartLayout withTop(double value) {
    return _ChordPartLayout(style: style, painter: painter, top: value);
  }
}
