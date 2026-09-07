import 'package:flutter/material.dart';

enum InlineTextStyle { bold, italic, underline, strike, tieUnderline }

const String inlineCommandPlaceholder = '\u25A3';

const List<InlineTextStyle> _styleOrder = <InlineTextStyle>[
  InlineTextStyle.bold,
  InlineTextStyle.italic,
  InlineTextStyle.underline,
  InlineTextStyle.strike,
  InlineTextStyle.tieUnderline,
];

extension on InlineTextStyle {
  String get enableMarker => switch (this) {
    InlineTextStyle.bold => r'\B',
    InlineTextStyle.italic => r'\I',
    InlineTextStyle.underline => r'\U',
    InlineTextStyle.strike => r'\S',
    InlineTextStyle.tieUnderline => r'\(',
  };

  String get disableMarker => switch (this) {
    InlineTextStyle.bold => r'\b',
    InlineTextStyle.italic => r'\i',
    InlineTextStyle.underline => r'\u',
    InlineTextStyle.strike => r'\s',
    InlineTextStyle.tieUnderline => r'\)',
  };
}

enum _InlineTextElementKind {
  text,
  nonBreakingSpace,
  softHyphen,
  nonBreakingHyphen,
  preferredLineBreak,
  command,
}

class _InlineTextElement {
  const _InlineTextElement({
    required this.kind,
    required this.styles,
    required this.visibleCharacter,
    this.rawCommand,
  });

  final _InlineTextElementKind kind;
  final Set<InlineTextStyle> styles;
  final String visibleCharacter;
  final String? rawCommand;

  bool get isCommand => kind == _InlineTextElementKind.command;

  _InlineTextElement copyWithStyles(Set<InlineTextStyle> newStyles) {
    return _InlineTextElement(
      kind: kind,
      styles: Set<InlineTextStyle>.unmodifiable(newStyles),
      visibleCharacter: visibleCharacter,
      rawCommand: rawCommand,
    );
  }
}

/// Editable logical representation of DIA inline formatting.
///
/// Every element has exactly one UTF-16 code unit in [visibleText]. This
/// matches [TextEditingController] selection offsets while keeping commands
/// that have no editable source representation as indivisible placeholders.
class InlineTextDocument {
  InlineTextDocument._(this._elements);

  factory InlineTextDocument.decode(String diaText) {
    final List<_InlineTextElement> elements = <_InlineTextElement>[];
    final Set<InlineTextStyle> activeStyles = <InlineTextStyle>{};

    void addElement(
      _InlineTextElementKind kind,
      String visibleCharacter, {
      String? rawCommand,
    }) {
      elements.add(
        _InlineTextElement(
          kind: kind,
          styles: Set<InlineTextStyle>.unmodifiable(activeStyles),
          visibleCharacter: visibleCharacter,
          rawCommand: rawCommand,
        ),
      );
    }

    for (int index = 0; index < diaText.length;) {
      if (diaText[index] != '\\' || index + 1 >= diaText.length) {
        addElement(_InlineTextElementKind.text, diaText[index]);
        index++;
        continue;
      }

      final String command = diaText[index + 1];
      final InlineTextStyle? style = switch (command) {
        'B' || 'b' => InlineTextStyle.bold,
        'I' || 'i' => InlineTextStyle.italic,
        'U' || 'u' => InlineTextStyle.underline,
        'S' || 's' => InlineTextStyle.strike,
        '(' || ')' => InlineTextStyle.tieUnderline,
        _ => null,
      };
      if (style != null) {
        if (command == style.enableMarker[1]) {
          activeStyles.add(style);
        } else {
          activeStyles.remove(style);
        }
        index += 2;
        continue;
      }

      switch (command) {
        case '\\':
          addElement(_InlineTextElementKind.text, '\\');
          index += 2;
        case ' ':
          addElement(_InlineTextElementKind.nonBreakingSpace, '\u00A0');
          index += 2;
        case '-':
          addElement(_InlineTextElementKind.softHyphen, '\u00AD');
          index += 2;
        case '_':
          addElement(_InlineTextElementKind.nonBreakingHyphen, '\u2011');
          index += 2;
        case '.':
          addElement(_InlineTextElementKind.preferredLineBreak, '\n');
          index += 2;
        case 'K':
        case 'G':
        case '?':
          final int end = diaText.indexOf(';', index + 2);
          if (end >= index + 2) {
            addElement(
              _InlineTextElementKind.command,
              inlineCommandPlaceholder,
              rawCommand: diaText.substring(index, end + 1),
            );
            index = end + 1;
          } else {
            addElement(_InlineTextElementKind.text, '\\');
            index++;
          }
        default:
          // Preserve unrecognised commands as atomic elements so newer DIA
          // markup cannot be split by an ordinary text edit.
          addElement(
            _InlineTextElementKind.command,
            inlineCommandPlaceholder,
            rawCommand: diaText.substring(index, index + 2),
          );
          index += 2;
      }
    }

    return InlineTextDocument._(elements);
  }

  final List<_InlineTextElement> _elements;

  String get visibleText =>
      _elements.map((element) => element.visibleCharacter).join();

  Set<InlineTextStyle> stylesForInsertionAt(int offset) {
    if (_elements.isEmpty) {
      return <InlineTextStyle>{};
    }
    final int clampedOffset = offset.clamp(0, _elements.length);
    final int elementIndex = clampedOffset == 0 ? 0 : clampedOffset - 1;
    return Set<InlineTextStyle>.from(_elements[elementIndex].styles);
  }

  bool isStyleActiveForRange(InlineTextStyle style, int start, int end) {
    final int rangeStart = start.clamp(0, _elements.length);
    final int rangeEnd = end.clamp(rangeStart, _elements.length);
    return rangeStart < rangeEnd &&
        _elements
            .sublist(rangeStart, rangeEnd)
            .every((element) => element.styles.contains(style));
  }

  void setStyle(
    InlineTextStyle style,
    int start,
    int end, {
    required bool enabled,
  }) {
    final int rangeStart = start.clamp(0, _elements.length);
    final int rangeEnd = end.clamp(rangeStart, _elements.length);
    for (int index = rangeStart; index < rangeEnd; index++) {
      final Set<InlineTextStyle> styles = Set<InlineTextStyle>.from(
        _elements[index].styles,
      );
      if (enabled) {
        styles.add(style);
      } else {
        styles.remove(style);
      }
      _elements[index] = _elements[index].copyWithStyles(styles);
    }
  }

  void replaceVisibleRange(
    int start,
    int end,
    String replacement, {
    required Set<InlineTextStyle> styles,
  }) {
    final int rangeStart = start.clamp(0, _elements.length);
    final int rangeEnd = end.clamp(rangeStart, _elements.length);
    _elements.replaceRange(
      rangeStart,
      rangeEnd,
      replacement.codeUnits.map(
        (int codeUnit) => _InlineTextElement(
          kind: _InlineTextElementKind.text,
          styles: Set<InlineTextStyle>.unmodifiable(styles),
          visibleCharacter: String.fromCharCode(codeUnit),
        ),
      ),
    );
  }

  /// Returns DIA markup with deterministic transitions and escaped literals.
  String encode() {
    final StringBuffer result = StringBuffer();
    final Set<InlineTextStyle> activeStyles = <InlineTextStyle>{};
    for (int index = 0; index < _elements.length; index++) {
      final _InlineTextElement element = _elements[index];
      if (element.isCommand) {
        _writeStyleTransition(result, activeStyles, element.styles);
        result.write(element.rawCommand);
        continue;
      }
      _writeStyleTransition(result, activeStyles, element.styles);
      result.write(switch (element.kind) {
        _InlineTextElementKind.text =>
          element.visibleCharacter == '\\' ? r'\\' : element.visibleCharacter,
        _InlineTextElementKind.nonBreakingSpace => r'\ ',
        _InlineTextElementKind.softHyphen => r'\-',
        _InlineTextElementKind.nonBreakingHyphen => r'\_',
        _InlineTextElementKind.preferredLineBreak => r'\.',
        _InlineTextElementKind.command => throw StateError('Unreachable'),
      });
    }
    _writeStyleTransition(result, activeStyles, const <InlineTextStyle>{});
    return result.toString();
  }
}

void _writeStyleTransition(
  StringBuffer result,
  Set<InlineTextStyle> activeStyles,
  Set<InlineTextStyle> targetStyles,
) {
  for (final InlineTextStyle style in _styleOrder) {
    if (activeStyles.contains(style) && !targetStyles.contains(style)) {
      result.write(style.disableMarker);
      activeStyles.remove(style);
    }
  }
  for (final InlineTextStyle style in _styleOrder) {
    if (!activeStyles.contains(style) && targetStyles.contains(style)) {
      result.write(style.enableMarker);
      activeStyles.add(style);
    }
  }
}

/// A [TextEditingController] whose text and selection use logical DIA text.
///
/// Its [text] never contains DIA markup: source commands are represented by
/// one visible placeholder character, making it impossible for a caret to
/// land inside an encoded command.
class InlineTextEditingController extends TextEditingController {
  factory InlineTextEditingController.fromDia(String diaText) {
    return InlineTextEditingController._(InlineTextDocument.decode(diaText));
  }

  InlineTextEditingController._(this._document)
    : _pendingStyles = _document.stylesForInsertionAt(0),
      super(text: _document.visibleText);

  final InlineTextDocument _document;
  Set<InlineTextStyle> _pendingStyles;
  bool _updatingValue = false;

  String get encodedText => _document.encode();

  bool isStyleActiveForSelection(InlineTextStyle style) {
    final TextSelection currentSelection = selection;
    if (!currentSelection.isValid) {
      return false;
    }
    if (currentSelection.isCollapsed) {
      return _pendingStyles.contains(style);
    }
    return _document.isStyleActiveForRange(
      style,
      currentSelection.start,
      currentSelection.end,
    );
  }

  void toggleStyle(InlineTextStyle style) {
    final TextSelection currentSelection = selection;
    if (!currentSelection.isValid) {
      return;
    }

    if (currentSelection.isCollapsed) {
      final Set<InlineTextStyle> updated = Set<InlineTextStyle>.from(
        _pendingStyles,
      );
      if (!updated.add(style)) {
        updated.remove(style);
      }
      _pendingStyles = updated;
    } else {
      _document.setStyle(
        style,
        currentSelection.start,
        currentSelection.end,
        enabled: !_document.isStyleActiveForRange(
          style,
          currentSelection.start,
          currentSelection.end,
        ),
      );
    }
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    if (_updatingValue) {
      super.value = newValue;
      return;
    }

    final TextEditingValue oldValue = super.value;
    if (oldValue.text != newValue.text) {
      final _TextChange change = _TextChange.between(
        oldValue.text,
        newValue.text,
      );
      final Set<InlineTextStyle> insertionStyles =
          oldValue.selection.isCollapsed &&
              oldValue.selection.extentOffset == change.start
          ? _pendingStyles
          : _document.stylesForInsertionAt(change.start);
      _document.replaceVisibleRange(
        change.start,
        change.oldEnd,
        newValue.text.substring(change.start, change.newEnd),
        styles: insertionStyles,
      );
      _pendingStyles =
          newValue.text.substring(change.start, change.newEnd).isEmpty
          ? _document.stylesForInsertionAt(newValue.selection.extentOffset)
          : insertionStyles;
    } else if (newValue.selection.isValid &&
        oldValue.selection != newValue.selection) {
      _pendingStyles = _document.stylesForInsertionAt(
        newValue.selection.extentOffset,
      );
    }

    _updatingValue = true;
    try {
      super.value = newValue;
    } finally {
      _updatingValue = false;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle baseStyle = style ?? const TextStyle();
    final List<InlineSpan> spans = <InlineSpan>[];
    final StringBuffer textBuffer = StringBuffer();
    Set<InlineTextStyle> runStyles = const <InlineTextStyle>{};
    bool hasRunStyles = false;

    void flushText() {
      if (textBuffer.isEmpty) {
        return;
      }
      spans.add(
        TextSpan(
          text: textBuffer.toString(),
          style: baseStyle.copyWith(
            fontWeight: runStyles.contains(InlineTextStyle.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: runStyles.contains(InlineTextStyle.italic)
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: TextDecoration.combine(<TextDecoration>[
              if (runStyles.contains(InlineTextStyle.underline))
                TextDecoration.underline,
              if (runStyles.contains(InlineTextStyle.strike))
                TextDecoration.lineThrough,
              if (runStyles.contains(InlineTextStyle.tieUnderline))
                TextDecoration.underline,
            ]),
          ),
        ),
      );
      textBuffer.clear();
    }

    for (final _InlineTextElement element in _document._elements) {
      if (hasRunStyles && !_sameStyles(runStyles, element.styles)) {
        flushText();
      }
      runStyles = element.styles;
      hasRunStyles = true;
      textBuffer.write(element.visibleCharacter);
    }
    flushText();
    return TextSpan(style: baseStyle, children: spans);
  }
}

bool _sameStyles(Set<InlineTextStyle> first, Set<InlineTextStyle> second) {
  return first.length == second.length && first.containsAll(second);
}

class _TextChange {
  const _TextChange({
    required this.start,
    required this.oldEnd,
    required this.newEnd,
  });

  factory _TextChange.between(String oldText, String newText) {
    int prefixLength = 0;
    while (prefixLength < oldText.length &&
        prefixLength < newText.length &&
        oldText[prefixLength] == newText[prefixLength]) {
      prefixLength++;
    }

    int suffixLength = 0;
    while (suffixLength < oldText.length - prefixLength &&
        suffixLength < newText.length - prefixLength &&
        oldText[oldText.length - suffixLength - 1] ==
            newText[newText.length - suffixLength - 1]) {
      suffixLength++;
    }
    return _TextChange(
      start: prefixLength,
      oldEnd: oldText.length - suffixLength,
      newEnd: newText.length - suffixLength,
    );
  }

  final int start;
  final int oldEnd;
  final int newEnd;
}

/// Canonicalizes inline style markers while preserving every DIA command.
String normalizeInlineTextFormattingMarkers(String text) {
  return InlineTextDocument.decode(text).encode();
}
