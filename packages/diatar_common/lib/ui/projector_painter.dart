import 'dart:math' as math;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/projection_frame.dart';
import '../models/projection_globals.dart';
import '../models/records.dart';
import '../services/aretino/aretino_render_cache.dart';
import '../services/aretino/aretino_render_service.dart';
import '../services/aretino/aretino_source.dart';
import '../services/aretino/aretino_svg.dart';

import 'chord_renderer.dart';
import 'kotta_assets.dart';

class KottaClefPainter extends CustomPainter {
  const KottaClefPainter({required this.command, required this.color});

  final String command;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double lineGap = math.min(size.width, size.height) / 12;
    final double top = (size.height - lineGap * 4) / 2;
    final Paint staffPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (int index = 0; index < 5; index++) {
      final double y = top + index * lineGap;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), staffPaint);
    }
    final int doPosition = 'abcdefghi'.indexOf(command[1]);
    if (doPosition >= 0) {
      final double centerY = top + lineGap * (4 - doPosition / 2);
      final double centerX = size.width / 2;
      final Path glyph = Path()
        ..moveTo(-1.25, -1.5)
        ..lineTo(1.25, -1.5)
        ..lineTo(1.25, -0.5)
        ..lineTo(-0.25, -0.5)
        ..lineTo(-0.25, 0.5)
        ..lineTo(1.25, 0.5)
        ..lineTo(1.25, 1.5)
        ..lineTo(-1.25, 1.5)
        ..close();
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.scale(lineGap);
      canvas.drawPath(glyph, Paint()..color = color);
      canvas.restore();
      return;
    }
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: ProjectionGlobals(txtColor: color),
      settings: const AppSettings(),
    );
    final double width = painter._kottaWidthOf(
      command,
      lineGap,
      _KottaDrawState(),
    );
    painter._drawKottaCommand(
      canvas,
      command,
      _KottaDrawState(),
      (size.width - width) / 2,
      top,
      lineGap,
      1,
      clefFilterQuality: FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant KottaClefPainter oldDelegate) =>
      command != oldDelegate.command || color != oldDelegate.color;
}

class HighlightRenderState {
  const HighlightRenderState({
    required this.maxWordIndex,
    required this.isFullyHighlighted,
  });

  final int maxWordIndex;
  final bool isFullyHighlighted;
}

class ProjectorEditorCursorOverlay {
  const ProjectorEditorCursorOverlay({
    required this.kottaPosition,
    required this.textPosition,
    required this.textActive,
    required this.activeVisible,
    this.kottaSelection,
  });

  final int kottaPosition;
  final int textPosition;
  final bool textActive;
  final bool activeVisible;
  final TextSelection? kottaSelection;
}

class ProjectorEditorCursorLayout {
  const ProjectorEditorCursorLayout({
    required this.kottaRect,
    required this.textRect,
    required this.kottaPositions,
    required this.textPositions,
  });

  final Rect kottaRect;
  final Rect textRect;
  final Map<int, double> kottaPositions;
  final Map<int, double> textPositions;

  double? kottaXForPosition(int position) {
    int nearest = -1;
    double? x;
    for (final entry in kottaPositions.entries) {
      if (entry.key <= position && entry.key > nearest) {
        nearest = entry.key;
        x = entry.value;
      }
    }
    return x;
  }

  ({int position, bool textActive}) hitTest(Offset offset, {bool? textActive}) {
    double rowDistance(Rect rect) =>
        (offset.dy - offset.dy.clamp(rect.top, rect.bottom)).abs();
    final bool hitText =
        textActive ?? (rowDistance(textRect) <= rowDistance(kottaRect));
    final Map<int, double> positions = hitText ? textPositions : kottaPositions;
    int nearest = positions.keys.first;
    double distance = double.infinity;
    for (final MapEntry<int, double> entry in positions.entries) {
      final double candidateDistance = (entry.value - offset.dx).abs();
      if (candidateDistance < distance) {
        nearest = entry.key;
        distance = candidateDistance;
      }
    }
    return (position: nearest, textActive: hitText);
  }
}

class ProjectorPainter extends CustomPainter {
  static const int _layoutCacheLimit = 32;
  static const int _preparedLayoutCacheLimit = 16;
  static const int _wordMeasureCacheLimit = 2048;
  static const double _autoResizeBigStep = 0.05;
  static const double _autoResizeSmallStep = 0.005;
  static const double _minAutoFontSize = 8.0;
  static final LinkedHashMap<String, List<_TextRowLayout>> _textRowsCache =
      LinkedHashMap<String, List<_TextRowLayout>>();
  static final LinkedHashMap<String, List<_KottaRowLayout>> _kottaRowsCache =
      LinkedHashMap<String, List<_KottaRowLayout>>();
  static final LinkedHashMap<String, double> _textHeightCache =
      LinkedHashMap<String, double>();
  static final LinkedHashMap<String, _PreparedTextLayout> _preparedLayoutCache =
      LinkedHashMap<String, _PreparedTextLayout>();
  static final LinkedHashMap<String, List<_RenderLine>> _parsedLinesCache =
      LinkedHashMap<String, List<_RenderLine>>();
  static final LinkedHashMap<String, double> _wordWidthCache =
      LinkedHashMap<String, double>();

  ProjectorPainter({
    required this.frame,
    required this.globals,
    required this.settings,
    this.allowLineWrapping = true,
    this.editorCursorOverlay,
    this.onEditorCursorLayout,
    this.logoTitle = '',
    this.logoSubtitle = '',
    this.onHighlightRenderState,
    // An Aretino score is rendered off the paint path and arrives later, so
    // every projector surface repaints when one becomes ready. The notifier
    // only ever fires after a score render, so this costs nothing on a slide
    // that has no notation.
  }) : super(repaint: AretinoRenderCache.instance);

  final ProjectionFrame? frame;
  final ProjectionGlobals globals;
  final AppSettings settings;
  final bool allowLineWrapping;
  final ProjectorEditorCursorOverlay? editorCursorOverlay;
  final ValueChanged<ProjectorEditorCursorLayout>? onEditorCursorLayout;
  final String logoTitle;
  final String logoSubtitle;
  final ValueChanged<HighlightRenderState>? onHighlightRenderState;
  double? _editorKottaX;
  double? _editorKottaTop;
  double? _editorKottaBottom;
  double? _editorTextX;
  double? _editorTextTop;
  double? _editorTextBottom;
  int _editorKottaCommandIndex = 0;
  int _editorTextCharacterIndex = 0;
  final Map<int, double> _editorKottaPositions = <int, double>{};
  final Map<int, double> _editorTextPositions = <int, double>{};

  void _emitHighlightRenderState({
    required int maxWordIndex,
    required bool isFullyHighlighted,
  }) {
    onHighlightRenderState?.call(
      HighlightRenderState(
        maxWordIndex: maxWordIndex,
        isFullyHighlighted: isFullyHighlighted,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    canvas.drawRect(full, Paint()..color = Colors.black);

    final double l = settings.clipL;
    final double t = settings.clipT;
    final double r = settings.clipR;
    final double b = settings.clipB;

    final Rect drawRect = Rect.fromLTWH(
      l,
      t,
      math.max(0, size.width - l - r),
      math.max(0, size.height - t - b),
    );

    canvas.save();
    canvas.clipRect(drawRect);
    canvas.translate(drawRect.left, drawRect.top);

    if (settings.mirror) {
      canvas.translate(drawRect.width, 0);
      canvas.scale(-1, 1);
    }

    final int rot = settings.rotateQuarterTurns % 4;
    if (rot != 0) {
      canvas.translate(drawRect.width / 2, drawRect.height / 2);
      canvas.rotate(rot * math.pi / 2);
      canvas.translate(-drawRect.width / 2, -drawRect.height / 2);
    }

    _drawContent(canvas, Size(drawRect.width, drawRect.height));
    canvas.restore();
  }

  // Computes exact required canvas height using the same wrapping/chord/kotta rules as paint.
  double measureRequiredHeight(Size size) {
    final ProjectionFrame? localFrame = frame;
    if (localFrame is! TextFrame) {
      return size.height;
    }
    final double contentHeight = _measureTextRequiredHeight(size, localFrame);
    return globals.vCenter ? contentHeight : contentHeight + 8;
  }

  /// Computes the width needed to render text lines without wrapping.
  double measureRequiredWidth() {
    final ProjectionFrame? localFrame = frame;
    if (localFrame is! TextFrame) {
      return 0;
    }

    final double fontSize = globals.fontSize.toDouble();
    final List<String> sourceLines = <String>[
      if (!globals.hideTitle && localFrame.record.title.isNotEmpty)
        localFrame.record.title,
      ...localFrame.record.lines,
    ];
    final List<_RenderLine> lines = _parseRenderLines(sourceLines);
    final _KottaDrawState carryKottaState = _KottaDrawState();
    double requiredWidth = 0;

    for (int index = 0; index < lines.length; index++) {
      final _RenderLine line = lines[index];
      final bool isTitleLine =
          !globals.hideTitle &&
          localFrame.record.title.isNotEmpty &&
          index == 0;
      final bool hasKotta =
          !isTitleLine &&
          globals.useKotta &&
          settings.receiverUseKotta &&
          line.words.any((word) => (word.kotta ?? '').isNotEmpty);
      if (hasKotta) {
        final List<_KottaRowLayout> rows = _buildKottaRows(
          line,
          fontSize,
          double.maxFinite,
          inheritedState: carryKottaState,
        );
        for (final _KottaRowLayout row in rows) {
          requiredWidth = math.max(requiredWidth, row.width);
        }
        _advanceKottaStateForLine(
          line,
          _kottaLineGap(fontSize),
          carryKottaState,
        );
      } else {
        requiredWidth = math.max(
          requiredWidth,
          _buildTextRowMeasure(line, fontSize).width,
        );
      }
    }

    return requiredWidth;
  }

  List<String> debugKottaRowPrefixesForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <String>[];
    }
    final List<_KottaRowLayout> rows = _buildKottaRows(
      lines.first,
      fontSize,
      maxWidth,
      inheritedState: _KottaDrawState(),
    );
    return rows.map((row) => row.prefix.kotta).toList();
  }

  int debugKottaStaffLineCountForLine(String source) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return 5;
    }
    return _staffLineCountForLine(lines.first);
  }

  List<List<String>> debugKottaRowPrefixesForLines(
    List<String> sources, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    final _KottaDrawState carryState = _KottaDrawState();
    final List<List<String>> result = <List<String>>[];
    for (final String source in sources) {
      final List<_RenderLine> lines = _parseOneLine(source);
      if (lines.isEmpty) {
        result.add(const <String>[]);
        continue;
      }
      final List<_KottaRowLayout> rows = _buildKottaRows(
        lines.first,
        fontSize,
        maxWidth,
        inheritedState: carryState,
      );
      result.add(rows.map((row) => row.prefix.kotta).toList());
      _advanceKottaStateForLine(
        lines.first,
        _kottaLineGap(fontSize),
        carryState,
      );
    }
    return result;
  }

  List<List<bool>> debugTieUnderlineFlagsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <List<bool>>[];
    }

    final List<_TextRowLayout> rows = _buildTextRows(
      lines.first,
      fontSize,
      maxWidth,
    );
    return rows
        .map(
          (row) => row.wordIndices
              .map((int wordIndex) => lines.first.words[wordIndex].tieUnderline)
              .toList(),
        )
        .toList();
  }

  List<List<bool>> debugTieUnderlineRowContinuationsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <List<bool>>[];
    }

    final _RenderLine line = lines.first;
    final List<_TextRowLayout> rows = _buildTextRows(line, fontSize, maxWidth);
    return rows.map((row) {
      if (row.wordIndices.isEmpty) {
        return const <bool>[false, false];
      }
      final int firstWord = row.wordIndices.first;
      final int lastWord = row.wordIndices.last;
      final bool fromPrevious =
          firstWord > 0 &&
          line.words[firstWord].tieUnderline &&
          line.words[firstWord - 1].tieUnderline;
      final bool toNext =
          lastWord + 1 < line.words.length &&
          line.words[lastWord].tieUnderline &&
          line.words[lastWord + 1].tieUnderline;
      return <bool>[fromPrevious, toNext];
    }).toList();
  }

  @visibleForTesting
  List<double> debugTieUnderlineEndAndDisplayXsForLine(
    String source, {
    double fontSize = 24,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <double>[];
    }
    final _RenderLine line = lines.first;
    final _TextRowPaintLayout layout = _buildTextRowPaintLayout(
      line,
      List<bool>.filled(line.words.length, false),
      fontSize,
    );
    final int index = layout.wordLayouts.lastIndexWhere(
      (_TextWordLayout word) => word.tieUnderline,
    );
    if (index < 0) {
      return const <double>[];
    }
    final _TextWordLayout word = layout.wordLayouts[index];
    final List<ui.TextBox> tieBoxes = layout.painter.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    final int displayEnd = index + 1 < layout.wordLayouts.length
        ? layout.wordLayouts[index + 1].start
        : layout.painter.plainText.length;
    final List<ui.TextBox> displayBoxes = layout.painter.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: displayEnd),
    );
    if (tieBoxes.isEmpty || displayBoxes.isEmpty) {
      return const <double>[];
    }
    return <double>[tieBoxes.last.right, displayBoxes.last.right];
  }

  @visibleForTesting
  double debugTieUnderlineTipOffset(double fontSize) {
    return _tieUnderlineTipOffset(fontSize);
  }

  @visibleForTesting
  void debugPaintKottaCommands(
    Canvas canvas,
    List<String> rows, {
    double lineGap = 10,
  }) {
    final state = _KottaDrawState();
    for (int i = 0; i < rows.length; i++) {
      final double top = 50 + i * 120;
      state.rowStartX = 20;
      double x = 20;
      final prefix = _kottaRowPrefixForState(state, lineGap);
      if (prefix.kotta.isNotEmpty) {
        x = _drawSimpleKotta(
          canvas,
          prefix.kotta,
          x,
          top + 4 * lineGap + _kottaStaffToTextGap(lineGap),
          0,
          0,
          state: state,
          lineGapOverride: lineGap,
          drawStaff: false,
        );
        state.slurLeftX = x;
      }
      x = _drawSimpleKotta(
        canvas,
        rows[i],
        x,
        top + 4 * lineGap + _kottaStaffToTextGap(lineGap),
        0,
        0,
        state: state,
        lineGapOverride: lineGap,
        drawStaff: false,
      );
      _endKottaRow(canvas, state, top, lineGap, x);
    }
  }

  @visibleForTesting
  List<String> debugFullPipelineRowsForRecord({
    required Size size,
    required RecTextRecord record,
  }) {
    final TextFrame frame = TextFrame(record: record);
    final _AutoSizeResult auto = _resolveAutoSize(size, frame);
    final _PreparedTextLayout prepared = _prepareTextLayout(
      size,
      frame,
      auto.fontSize,
      preferPreferredBreaks: auto.preferPreferredBreaks,
    );
    final List<String> out = <String>[];
    for (int li = 0; li < prepared.lines.length; li++) {
      final _RenderLine line = prepared.lines[li];
      final bool hasKotta = prepared.hasKottaByLine[li];
      if (hasKotta) {
        for (final _KottaRowLayout r in prepared.kottaRowsByLine[li]) {
          out.add(
            'K<${r.width.toStringAsFixed(1)}> '
            '${r.words.map((w) => line.words[w.wordIndex].text + (line.words[w.wordIndex].spaceAfter ? ' ' : '')).join()}',
          );
        }
      } else {
        for (final _TextRowLayout r in prepared.textRowsByLine[li]) {
          out.add(
            'T<${r.width.toStringAsFixed(1)}/W${size.width.toStringAsFixed(1)}/F${auto.fontSize.toStringAsFixed(1)}> '
            '${r.wordIndices.map((int wi) => line.words[wi].text + (line.words[wi].spaceAfter ? ' ' : '')).join()}${r.endHyphen ? '-' : ''}',
          );
        }
      }
    }
    return out;
  }

  List<String> debugTextWrappedRowsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <String>[];
    }

    final List<_TextRowLayout> rows = _buildTextRows(
      lines.first,
      fontSize,
      maxWidth,
    );
    return rows
        .map(
          (row) =>
              row.wordIndices
                  .map((int wi) {
                    final _WordToken w = lines.first.words[wi];
                    return w.text + (w.spaceAfter ? ' ' : '');
                  })
                  .join()
                  .trimRight() +
              (row.endHyphen ? '-' : ''),
        )
        .toList();
  }

  @visibleForTesting
  List<double> debugTextWrappedRowWidthsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <double>[];
    }
    return _buildTextRows(
      lines.first,
      fontSize,
      maxWidth,
    ).map((_TextRowLayout row) => row.width).toList();
  }

  @visibleForTesting
  List<String> debugChordSourcesForLine(String source) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <String>[];
    }
    return <String>[
      for (final _WordToken word in lines.first.words)
        if ((word.chord ?? '').isNotEmpty) word.chord!,
    ];
  }

  @visibleForTesting
  List<double> debugKottaRowWidthsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
  }) {
    return _buildKottaRows(
      _parseOneLine(source).first,
      fontSize,
      maxWidth,
    ).map((row) => row.width).toList();
  }

  List<double> debugKottaRowStartXsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
    double sizeWidth = 400,
    double horizontalPad = 16,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <double>[];
    }
    final List<_KottaRowLayout> rows = _buildKottaRows(
      lines.first,
      fontSize,
      maxWidth,
      inheritedState: _KottaDrawState(),
    );
    if (rows.isEmpty) {
      return const <double>[];
    }
    return <double>[
      for (int i = 0; i < rows.length; i++)
        _kottaRowsStartX(rows, sizeWidth, horizontalPad, rowIndex: i) +
            _kottaContinuationIndent(i, horizontalPad),
    ];
  }

  List<double> debugKottaVisibleStartXsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
    double sizeWidth = 400,
    double horizontalPad = 16,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <double>[];
    }
    final List<_KottaRowLayout> rows = _buildKottaRows(
      lines.first,
      fontSize,
      maxWidth,
      inheritedState: _KottaDrawState(),
    );
    if (rows.isEmpty) {
      return const <double>[];
    }
    return <double>[
      for (int i = 0; i < rows.length; i++)
        _kottaRowsStartX(rows, sizeWidth, horizontalPad, rowIndex: i) +
            _kottaContinuationIndent(i, horizontalPad),
    ];
  }

  List<double> debugKottaTextStartXsForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 120,
    double sizeWidth = 400,
    double horizontalPad = 16,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return const <double>[];
    }
    final List<_KottaRowLayout> rows = _buildKottaRows(
      lines.first,
      fontSize,
      maxWidth,
      inheritedState: _KottaDrawState(),
    );
    if (rows.isEmpty) {
      return const <double>[];
    }
    final List<_KottaRowPrefix> rowPrefixes = _resolveKottaRowPrefixes(
      rows,
      lines.first,
      _kottaLineGap(fontSize),
    );
    return <double>[
      for (int i = 0; i < rows.length; i++)
        _kottaRowsStartX(rows, sizeWidth, horizontalPad, rowIndex: i) +
            _kottaContinuationIndent(i, horizontalPad) +
            rowPrefixes[i].width +
            rows[i].inlinePrefix.width +
            rows[i].words.first.textInset,
    ];
  }

  @visibleForTesting
  int debugKottaLetterConnectorCountForLine(
    String source, {
    double fontSize = 24,
    double maxWidth = 320,
  }) {
    final List<_RenderLine> lines = _parseOneLine(source);
    if (lines.isEmpty) {
      return 0;
    }

    final _RenderLine line = lines.first;
    final List<_KottaRowLayout> rows = _buildKottaRows(
      line,
      fontSize,
      maxWidth,
      inheritedState: _KottaDrawState(),
    );
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    int count = 0;

    for (final _KottaRowLayout row in rows) {
      for (int i = 1; i < row.words.length; i++) {
        final _KottaWordLayout previousSlot = row.words[i - 1];
        final _KottaWordLayout currentSlot = row.words[i];
        final _WordToken previous = line.words[previousSlot.wordIndex];
        final _WordToken current = line.words[currentSlot.wordIndex];
        final double previousTextWidth = _measureWordDisplayWidth(
          previous,
          fontSize,
          measure,
        );
        if (_shouldPaintKottaLetterConnector(
          previous: previous,
          current: current,
          gap:
              previousSlot.slotWidth -
              previousSlot.textInset -
              previousTextWidth +
              currentSlot.textInset,
        )) {
          count++;
        }
      }
    }

    return count;
  }

  void _drawContent(Canvas canvas, Size size) {
    final ProjectionFrame? localFrame = frame;
    if (localFrame is LogoFrame) {
      _emitHighlightRenderState(maxWordIndex: 0, isFullyHighlighted: false);
      _drawLogo(canvas, size, localFrame.phase);
      return;
    }

    if (localFrame is TextFrame) {
      _drawText(canvas, size, localFrame);
      return;
    }

    if (localFrame is ImageFrame) {
      _emitHighlightRenderState(maxWordIndex: 0, isFullyHighlighted: false);
      _drawImage(canvas, size, localFrame, localFrame.bgMode);
      return;
    }

    _emitHighlightRenderState(maxWordIndex: 0, isFullyHighlighted: false);

    final Color blank = _colorWithTransparency(
      globals.blankColor,
      globals.blankTrans,
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = blank);
  }

  void _drawLogo(Canvas canvas, Size size, int phase) {
    final Color bk = debugLogoBackgroundColorForPhase(phase);
    canvas.drawRect(Offset.zero & size, Paint()..color = bk);

    if (globals.hideTitle) {
      return;
    }

    const double titleFontSizeBase = 6.4;
    const double verFontSizeBase = 2.4;
    const double minFontSize = 8.0;

    final double titleFontSize = math
        .max(minFontSize, globals.titleSize * titleFontSizeBase)
        .toDouble();
    final double verFontSize = math
        .max(minFontSize, globals.titleSize * verFontSizeBase)
        .toDouble();

    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: logoTitle,
        style: TextStyle(
          color: const Color(0xFF434ECE),
          fontSize: titleFontSize,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xFF404040),
              blurRadius: 10,
              offset: Offset(5, 5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);

    final TextPainter verPainter = TextPainter(
      text: TextSpan(
        text: logoSubtitle,
        style: TextStyle(color: Colors.white70, fontSize: verFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);

    final Offset titlePos = Offset(
      (size.width - titlePainter.width) / 2,
      size.height * 0.42,
    );
    final Offset verPos = Offset(
      (size.width - verPainter.width) / 2,
      titlePos.dy + titlePainter.height + 12,
    );
    titlePainter.paint(canvas, titlePos);
    verPainter.paint(canvas, verPos);
  }

  Color debugLogoBackgroundColorForPhase(int phase) {
    const int maxRed = 0x4B;
    const int maxGreen = 0xEF;
    const int maxBlue = 0x96;

    int intensity;
    if (phase < 16 || phase >= 64) {
      intensity = 0;
    } else if (phase < 32) {
      intensity = phase - 16;
    } else if (phase < 48) {
      intensity = 16;
    } else {
      intensity = 64 - phase;
    }

    return Color.fromARGB(
      255,
      maxRed * intensity ~/ 16,
      maxGreen * intensity ~/ 16,
      maxBlue * intensity ~/ 16,
    );
  }

  /// Draws a Gregorian chant slide. The background is already painted.
  ///
  /// Nothing is rendered here: a prepared score is looked up in
  /// [AretinoRenderCache] and replayed, and a miss draws the words as plain
  /// text while the render runs (Decision 6). A projector never shows an empty
  /// screen waiting for JavaScript.
  void _drawAretino(Canvas canvas, Size size, TextFrame frame, String source) {
    _emitHighlightRenderState(maxWordIndex: 0, isFullyHighlighted: false);

    final double titleHeight = _drawAretinoTitle(canvas, size, frame);
    final Size target = Size(
      math.max(40, size.width),
      math.max(40, size.height - titleHeight),
    );

    final AretinoRenderKey key = AretinoRenderKey(
      source: source,
      width: target.width,
      height: target.height,
      style: AretinoStyle(lyricFontSize: globals.fontSize.toDouble()),
    );
    final AretinoRenderCache cache = AretinoRenderCache.instance;
    final AretinoRendering? rendering = cache.lookup(key);
    if (rendering == null) {
      cache.request(key);
      _drawAretinoLyrics(canvas, size, source, titleHeight);
      return;
    }

    final double contentHeight = rendering.height;
    double y =
        titleHeight +
        (globals.vCenter
            ? math.max(0, (target.height - contentHeight) / 2)
            : 0);
    for (int i = 0; i < rendering.rows.length; i++) {
      final AretinoPicture row = rendering.rows[i];
      final double x = globals.hCenter
          ? (size.width - row.size.width) / 2
          : globals.leftIndent.toDouble();
      canvas.save();
      // Horizontally each row keeps the width it was laid out against, so the
      // systems stay aligned with one another. Vertically they are stacked on
      // their ink, since the room the library reserves above a staff for notes
      // that may rise over it would otherwise show up as a gap under the
      // previous system's lyrics.
      canvas.translate(
        x - row.viewBox.left,
        y + rendering.rowTops[i] - row.inkBounds.top,
      );
      row.paint(canvas, inkColor: globals.txtColor);
      canvas.restore();
    }
  }

  /// Draws the slide title above a score, and returns the height it took.
  double _drawAretinoTitle(Canvas canvas, Size size, TextFrame frame) {
    if (globals.hideTitle || frame.record.title.trim().isEmpty) {
      return 0;
    }
    final double fontSize = (globals.titleSize.toDouble() * 2.5).clamp(
      8.0,
      72.0,
    );
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: frame.record.title,
        style: TextStyle(color: globals.txtColor, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: globals.hCenter ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: math.max(40, size.width));
    tp.paint(
      canvas,
      Offset(globals.hCenter ? (size.width - tp.width) / 2 : 0, 0),
    );
    final double height = tp.height;
    tp.dispose();
    return height;
  }

  /// The words of a chant, as plain text — what a slide shows while its score
  /// is still rendering, and what it falls back to if the render fails.
  void _drawAretinoLyrics(Canvas canvas, Size size, String source, double top) {
    final List<String> lines = AretinoSource.lyricLines(source);
    if (lines.isEmpty) {
      return;
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: lines.join('\n'),
        style: TextStyle(
          color: globals.txtColor,
          fontSize: globals.fontSize.toDouble(),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: globals.hCenter ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: math.max(40, size.width));
    final double available = math.max(0, size.height - top);
    tp.paint(
      canvas,
      Offset(
        globals.hCenter ? (size.width - tp.width) / 2 : 0,
        top + (globals.vCenter ? math.max(0, (available - tp.height) / 2) : 0),
      ),
    );
    tp.dispose();
  }

  void _drawText(Canvas canvas, Size size, TextFrame frame) {
    final Color bg = _colorWithTransparency(globals.bkColor, globals.backTrans);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // A verse whose first line carries the `\?A` marker is a Gregorian chant in
    // Aretino notation. It travels as ordinary verse text inside the same
    // `text` record as everything else, and is rendered here, at this canvas's
    // own size — which is what makes it reflow to whatever screen it lands on
    // (plans/aretino-projection-v1.md, Decision 1).
    final String? aretino = AretinoSource.extract(frame.record.lines);
    if (aretino != null) {
      _drawAretino(canvas, size, frame, aretino);
      return;
    }

    _resetEditorCursorCapture();
    const double horizontalPad = 0;
    final double maxWidth = allowLineWrapping
        ? math.max(40, size.width)
        : double.maxFinite;

    final _AutoSizeResult autoSize = _resolveAutoSize(size, frame);
    final double fontSize = autoSize.fontSize;
    final bool preferPreferredBreaks = autoSize.preferPreferredBreaks;

    final _PreparedTextLayout prepared = _prepareTextLayout(
      size,
      frame,
      fontSize,
      preferPreferredBreaks: preferPreferredBreaks,
    );
    final bool hasTitleLine = prepared.hasTitleLine;
    final List<_RenderLine> allLines = prepared.lines;
    final double titleFontSize = prepared.titleFontSize;
    final double lineSpacing = globals.spacing100 / 100.0;

    final List<TextPainter> painters = <TextPainter>[];
    final List<List<bool>> highlightByLine = <List<bool>>[];
    int globalWordIndex = 0; // Track word index for highlighting (skips title)
    bool prevWordHadSpace = true;

    for (int lineIndex = 0; lineIndex < allLines.length; lineIndex++) {
      final _RenderLine line = allLines[lineIndex];
      final bool isTitleLine = hasTitleLine && lineIndex == 0;
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      final List<bool> lineHighlights = <bool>[];

      // Reset at each line boundary so the first word of the new line always
      // gets a new word index, regardless of whether the previous line's last
      // word had a trailing space.
      if (!isTitleLine) {
        prevWordHadSpace = true;
      }

      final List<InlineSpan> spans = <InlineSpan>[];
      for (int i = 0; i < line.words.length; i++) {
        final _WordToken word = line.words[i];

        // Update word index only on real word boundaries (spaceAfter), not syllable breaks.
        if (!isTitleLine && word.countAsWord) {
          final bool startsNewWord = prevWordHadSpace;
          if (startsNewWord) {
            globalWordIndex++;
          }
          prevWordHadSpace = word.spaceAfter;
        }

        // Highlight if index is <= wordToHighlight (and not title)
        final bool highlighted =
            !isTitleLine &&
            globals.wordToHighlight > 0 &&
            globalWordIndex <= globals.wordToHighlight;
        lineHighlights.add(highlighted);
        final Color baseColor = word.color ?? globals.txtColor;

        spans.add(
          TextSpan(
            text: word.text + (word.spaceAfter ? ' ' : ''),
            style: TextStyle(
              color: highlighted ? globals.hiColor : baseColor,
              fontSize: _effectiveWordFontSize(word, lineFontSize),
              fontWeight: (globals.boldText || word.bold)
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
              decoration: TextDecoration.combine(<TextDecoration>[
                if (word.underline) TextDecoration.underline,
                if (word.strike) TextDecoration.lineThrough,
              ]),
            ),
          ),
        );
      }

      final TextPainter tp = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
        textAlign: globals.hCenter ? TextAlign.center : TextAlign.left,
      )..layout(maxWidth: maxWidth);
      painters.add(tp);
      highlightByLine.add(lineHighlights);
    }

    _emitHighlightRenderState(
      maxWordIndex: globalWordIndex,
      isFullyHighlighted:
          globalWordIndex > 0 && globals.wordToHighlight >= globalWordIndex,
    );

    double totalHeight = 0;
    for (int i = 0; i < painters.length; i++) {
      final TextPainter tp = painters[i];
      final bool titleToKottaTransition =
          hasTitleLine && i == 1 && prepared.hasKottaByLine[i];
      if (titleToKottaTransition) {
        totalHeight += _titleToKottaTransitionGap(
          nextLineFontSize: fontSize,
          titleHeight: painters[i - 1].height,
          lineSpacing: lineSpacing,
        );
      }
      if (prepared.hasKottaByLine[i]) {
        final int rows = math.max(1, prepared.kottaRowsByLine[i].length);
        final bool isTitleLine = hasTitleLine && i == 0;
        final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
        final double rowBlockHeight =
            _kottaRowBlockHeight(lineFontSize) + prepared.chordBandByLine[i];
        totalHeight +=
            rows * rowBlockHeight + _kottaSourceLineGap(lineFontSize);
      } else {
        final bool isTitleLine = hasTitleLine && i == 0;
        if (isTitleLine) {
          totalHeight += prepared.chordBandByLine[i] + tp.height * lineSpacing;
        } else {
          final double lineFontSize = fontSize;
          final double textRowHeight = prepared.lineHeightsByLine[i];
          final List<_TextRowLayout> rows = prepared.textRowsByLine[i];
          if (rows.isEmpty) {
            totalHeight +=
                prepared.chordBandByLine[i] + textRowHeight * lineSpacing;
          } else {
            for (final _TextRowLayout row in rows) {
              totalHeight +=
                  _rowChordBandHeight(allLines[i], row, lineFontSize) +
                  textRowHeight * lineSpacing;
            }
          }
        }
      }
    }
    totalHeight += prepared.bottomTextDescent;
    double y = globals.vCenter ? (size.height - totalHeight) / 2 : 8;

    for (int painterIndex = 0; painterIndex < painters.length; painterIndex++) {
      final TextPainter tp = painters[painterIndex];
      final _RenderLine rline = allLines[painterIndex];
      final bool isTitleLine = hasTitleLine && painterIndex == 0;
      final bool hasKotta = prepared.hasKottaByLine[painterIndex];
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      final List<_KottaRowLayout> lineKottaRows =
          prepared.kottaRowsByLine[painterIndex];
      final double chordBand = prepared.chordBandByLine[painterIndex];
      final double lineStep = tp.height * lineSpacing;
      final List<_TextRowLayout> lineTextRows =
          prepared.textRowsByLine[painterIndex];

      final bool titleToKottaTransition =
          hasTitleLine && painterIndex == 1 && hasKotta;
      if (titleToKottaTransition) {
        y += _titleToKottaTransitionGap(
          nextLineFontSize: lineFontSize,
          titleHeight: painters[painterIndex - 1].height,
          lineSpacing: lineSpacing,
        );
      }

      if (!isTitleLine) {
        final double lineGap = _kottaLineGap(lineFontSize);
        final double staffHeight = _kottaStaffHeight(lineGap);
        final double ledgerReserve = _kottaLedgerReserve(lineGap);
        final double staffToTextGap = _kottaStaffToTextGap(lineGap);
        final double rowStep = _kottaRowBlockHeight(lineFontSize) + chordBand;
        final double continuationIndent = _textContinuationIndent(
          lineFontSize,
          TextPainter(textDirection: TextDirection.ltr),
        );
        final double firstTextY =
            y +
            chordBand +
            ledgerReserve +
            staffHeight +
            staffToTextGap +
            _kottaTextMetrics(lineFontSize).ascent * (lineSpacing - 1);
        _paintKotta(
          canvas,
          rline,
          firstTextY,
          rowStep,
          lineFontSize,
          maxWidth,
          size.width,
          continuationIndent,
          lineKottaRows,
        );

        if (hasKotta && lineKottaRows.isNotEmpty) {
          final List<_KottaRowPrefix> rowPrefixes = _resolveKottaRowPrefixes(
            lineKottaRows,
            rline,
            _kottaLineGap(lineFontSize),
          );
          for (int rowIndex = 0; rowIndex < lineKottaRows.length; rowIndex++) {
            final _KottaRowLayout row = lineKottaRows[rowIndex];
            final _KottaRowPrefix rowPrefix = rowPrefixes[rowIndex];
            final double rowY = firstTextY + rowIndex * rowStep;
            final double rowX =
                _kottaRowsStartX(
                  lineKottaRows,
                  size.width,
                  continuationIndent,
                  rowIndex: rowIndex,
                ) +
                _kottaContinuationIndent(rowIndex, continuationIndent);
            _paintKottaAlignedTextRow(
              canvas,
              rline,
              highlightByLine[painterIndex],
              row,
              rowX,
              rowY,
              lineFontSize,
              leadingInset: rowPrefix.width + row.inlinePrefix.width,
            );
          }
          y +=
              lineKottaRows.length * rowStep +
              _kottaSourceLineGap(lineFontSize);
          continue;
        }
      }

      final double x = globals.hCenter
          ? (size.width - tp.width) / 2
          : horizontalPad;
      if (isTitleLine || lineTextRows.isEmpty) {
        final double textY = y + chordBand;
        tp.paint(canvas, Offset(x, textY));
        _paintChords(canvas, rline, x, textY, lineFontSize);
        y += chordBand + lineStep;
        continue;
      }

      final double rowHeight = prepared.lineHeightsByLine[painterIndex];
      for (final _TextRowLayout row in lineTextRows) {
        final List<_WordToken> rowWords = <_WordToken>[
          for (final int wi in row.wordIndices) rline.words[wi],
        ];
        final List<bool> rowHighlights = <bool>[
          for (final int wi in row.wordIndices)
            highlightByLine[painterIndex][wi],
        ];
        final _RenderLine rowLine = _RenderLine(words: rowWords);
        final double rowChordBand = _rowChordBandHeight(
          rline,
          row,
          lineFontSize,
        );
        final double rowX = globals.hCenter
            ? (size.width - row.width) / 2
            : horizontalPad + row.indentWidth;
        final double textY = y + rowChordBand;
        _paintTextRow(
          canvas,
          rowLine,
          rowHighlights,
          row.wordIndices,
          row.endHyphen,
          rowX,
          textY,
          lineFontSize,
        );
        _paintChords(canvas, rowLine, rowX, textY, lineFontSize);
        y += rowChordBand + rowHeight * lineSpacing;
      }
    }
    _paintEditorCursors(canvas);
  }

  double _measureTextRequiredHeight(Size size, TextFrame frame) {
    final _AutoSizeResult autoSize = _resolveAutoSize(size, frame);

    return _measureTextRequiredHeightForFontSize(
      size,
      frame,
      autoSize.fontSize,
      preferPreferredBreaks: autoSize.preferPreferredBreaks,
    );
  }

  _AutoSizeResult _resolveAutoSize(Size size, TextFrame frame) {
    final double baseFontSize = globals.fontSize.toDouble();
    if (!globals.autoResize || baseFontSize <= _minAutoFontSize) {
      return _AutoSizeResult(
        fontSize: baseFontSize,
        preferPreferredBreaks: true,
      );
    }

    final double fitHeight = size.height * 0.95;
    final int renderedLineCount = math.max(
      1,
      frame.record.lines.length +
          ((!globals.hideTitle && frame.record.title.isNotEmpty) ? 1 : 0),
    );
    final double theoreticalMaxFontSize = fitHeight / renderedLineCount;
    final double startFontSize = math
        .min(baseFontSize, theoreticalMaxFontSize)
        .clamp(_minAutoFontSize, baseFontSize);

    final double minScale = (_minAutoFontSize / startFontSize).clamp(0.01, 1.0);
    double sizeMul = 1.0;
    double step = _autoResizeBigStep;
    bool preferPreferredBreaks = true;

    int guard = 0;
    while (sizeMul >= minScale && guard++ < 300) {
      final double fontSize = (startFontSize * sizeMul).clamp(
        _minAutoFontSize,
        startFontSize,
      );

      final bool preferredFits =
          _measureTextRequiredHeightForFontSize(
            size,
            frame,
            fontSize,
            preferPreferredBreaks: true,
          ) <=
          fitHeight;
      final bool fallbackFits =
          preferredFits ||
          _measureTextRequiredHeightForFontSize(
                size,
                frame,
                fontSize,
                preferPreferredBreaks: false,
              ) <=
              fitHeight;

      if (preferredFits || fallbackFits) {
        preferPreferredBreaks = preferredFits;
        if (step == _autoResizeSmallStep) {
          return _AutoSizeResult(
            fontSize: fontSize,
            preferPreferredBreaks: preferPreferredBreaks,
          );
        }
        sizeMul += step;
        step = _autoResizeSmallStep;
      }

      sizeMul -= step;
    }

    final double fallbackFontSize = _minAutoFontSize.clamp(
      _minAutoFontSize,
      startFontSize,
    );
    final bool preferredFitsAtMin =
        _measureTextRequiredHeightForFontSize(
          size,
          frame,
          fallbackFontSize,
          preferPreferredBreaks: true,
        ) <=
        fitHeight;
    return _AutoSizeResult(
      fontSize: fallbackFontSize,
      preferPreferredBreaks: preferredFitsAtMin,
    );
  }

  _PreparedTextLayout _prepareTextLayout(
    Size size,
    TextFrame frame,
    double fontSize, {
    required bool preferPreferredBreaks,
  }) {
    final String cacheKey = _preparedTextLayoutCacheKey(
      size,
      frame,
      fontSize,
      preferPreferredBreaks,
    );
    final _PreparedTextLayout? cached = _preparedLayoutCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final double maxWidth = allowLineWrapping
        ? math.max(40, size.width)
        : double.maxFinite;
    final bool hasTitleLine =
        !globals.hideTitle && frame.record.title.isNotEmpty;
    final List<String> sourceLines = <String>[
      if (hasTitleLine) frame.record.title,
      ...frame.record.lines,
    ];
    final List<_RenderLine> allLines = _parseRenderLines(sourceLines);
    final bool songHasKotta = allLines
        .skip(hasTitleLine ? 1 : 0)
        .any((line) => line.words.any((word) => (word.kotta ?? '').isNotEmpty));
    final bool songHasChords =
        globals.useAkkord &&
        settings.receiverUseAkkord &&
        allLines.any(
          (line) => line.words.any((word) => (word.chord ?? '').isNotEmpty),
        );

    final double requestedTitleFontSize = (globals.titleSize.toDouble() * 2.5)
        .clamp(8.0, 72.0);
    final double titleFontSize = math
        .min(requestedTitleFontSize, fontSize)
        .clamp(8.0, 72.0);

    final List<List<_TextRowLayout>> textRowsByLine = <List<_TextRowLayout>>[];
    final List<bool> hasKottaByLine = <bool>[];
    final List<double> chordBandByLine = <double>[];
    final List<List<_KottaRowLayout>> kottaRowsByLine =
        <List<_KottaRowLayout>>[];
    final List<double> lineHeightsByLine = <double>[];
    final _KottaDrawState carryKottaState = _KottaDrawState();

    for (int lineIndex = 0; lineIndex < allLines.length; lineIndex++) {
      final bool isTitleLine = hasTitleLine && lineIndex == 0;
      final _RenderLine baseLine =
          allLines[lineIndex].words.isEmpty &&
              !isTitleLine &&
              (songHasKotta || editorCursorOverlay != null)
          ? _RenderLine(
              words: const [
                _WordToken(
                  text: '',
                  bold: false,
                  italic: false,
                  underline: false,
                  tieUnderline: false,
                  strike: false,
                  color: null,
                ),
              ],
            )
          : allLines[lineIndex];
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      final bool hasKotta =
          !isTitleLine &&
          globals.useKotta &&
          settings.receiverUseKotta &&
          (songHasKotta || editorCursorOverlay != null);
      final _RenderLine line;
      if (!isTitleLine && !hasKotta) {
        final double continuationIndent = globals.hCenter
            ? 0
            : _textContinuationIndent(
                lineFontSize,
                TextPainter(textDirection: TextDirection.ltr),
              );
        line = _splitOverlongWords(
          baseLine,
          lineFontSize,
          maxWidth,
          continuationIndent: continuationIndent,
        );
      } else {
        line = baseLine;
      }
      allLines[lineIndex] = line;

      final double chordBand = isTitleLine
          ? 0
          : hasKotta
          ? (songHasChords
                ? _kottaRowTextHeight(lineFontSize) * globals.akkordArany / 100
                : 0)
          : _lineChordBandHeight(line, lineFontSize);
      final List<_KottaRowLayout> lineKottaRows = hasKotta
          ? _buildKottaRows(
              line,
              lineFontSize,
              maxWidth,
              inheritedState: carryKottaState,
            )
          : const <_KottaRowLayout>[];
      final List<_TextRowLayout> lineTextRows = (!isTitleLine && !hasKotta)
          ? _buildTextRows(
              line,
              lineFontSize,
              maxWidth,
              preferPreferredBreaks: preferPreferredBreaks,
            )
          : const <_TextRowLayout>[];

      textRowsByLine.add(lineTextRows);
      hasKottaByLine.add(hasKotta);
      chordBandByLine.add(chordBand);
      kottaRowsByLine.add(lineKottaRows);
      if (hasKotta) {
        _advanceKottaStateForLine(
          line,
          _kottaLineGap(lineFontSize),
          carryKottaState,
        );
      }
      lineHeightsByLine.add(_measureTextRowHeight(line, lineFontSize));
    }

    final int lastLineIndex = allLines.length - 1;
    final double bottomTextDescent =
        lastLineIndex >= 0 &&
            !hasKottaByLine[lastLineIndex] &&
            !(hasTitleLine && lastLineIndex == 0)
        ? _measureTextRowDescent(allLines[lastLineIndex], fontSize)
        : 0;

    final _PreparedTextLayout prepared = _PreparedTextLayout(
      hasTitleLine: hasTitleLine,
      titleFontSize: titleFontSize,
      lines: List<_RenderLine>.unmodifiable(allLines),
      textRowsByLine: List<List<_TextRowLayout>>.unmodifiable(
        textRowsByLine.map((rows) => List<_TextRowLayout>.unmodifiable(rows)),
      ),
      hasKottaByLine: List<bool>.unmodifiable(hasKottaByLine),
      chordBandByLine: List<double>.unmodifiable(chordBandByLine),
      kottaRowsByLine: List<List<_KottaRowLayout>>.unmodifiable(
        kottaRowsByLine.map((rows) => List<_KottaRowLayout>.unmodifiable(rows)),
      ),
      lineHeightsByLine: List<double>.unmodifiable(lineHeightsByLine),
      bottomTextDescent: bottomTextDescent,
    );

    _preparedLayoutCache[cacheKey] = prepared;
    while (_preparedLayoutCache.length > _preparedLayoutCacheLimit) {
      _preparedLayoutCache.remove(_preparedLayoutCache.keys.first);
    }
    return prepared;
  }

  double _measureTextRequiredHeightForFontSize(
    Size size,
    TextFrame frame,
    double fontSize, {
    bool preferPreferredBreaks = true,
  }) {
    final String cacheKey = _measureTextHeightCacheKey(
      size,
      frame,
      fontSize,
      preferPreferredBreaks,
    );
    final double? cached = _textHeightCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final _PreparedTextLayout prepared = _prepareTextLayout(
      size,
      frame,
      fontSize,
      preferPreferredBreaks: preferPreferredBreaks,
    );

    final bool hasTitleLine = prepared.hasTitleLine;
    final List<_RenderLine> allLines = prepared.lines;
    final double titleFontSize = prepared.titleFontSize;
    final double lineSpacing = globals.spacing100 / 100.0;

    double totalHeight = 0;
    for (int i = 0; i < allLines.length; i++) {
      final bool titleToKottaTransition =
          hasTitleLine && i == 1 && prepared.hasKottaByLine[i];
      if (titleToKottaTransition) {
        totalHeight += _titleToKottaTransitionGap(
          nextLineFontSize: fontSize,
          titleHeight: prepared.lineHeightsByLine[i - 1],
          lineSpacing: lineSpacing,
        );
      }

      if (prepared.hasKottaByLine[i]) {
        final int rows = math.max(1, prepared.kottaRowsByLine[i].length);
        final bool isTitleLine = hasTitleLine && i == 0;
        final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
        final double rowBlockHeight =
            _kottaRowBlockHeight(lineFontSize) + prepared.chordBandByLine[i];
        totalHeight +=
            rows * rowBlockHeight + _kottaSourceLineGap(lineFontSize);
      } else {
        final bool isTitleLine = hasTitleLine && i == 0;
        if (isTitleLine) {
          totalHeight +=
              prepared.chordBandByLine[i] +
              prepared.lineHeightsByLine[i] * lineSpacing;
        } else {
          final double lineFontSize = fontSize;
          final List<_TextRowLayout> rows = prepared.textRowsByLine[i];
          final double lineTextHeight = prepared.lineHeightsByLine[i];
          if (rows.isEmpty) {
            totalHeight +=
                prepared.chordBandByLine[i] + lineTextHeight * lineSpacing;
          } else {
            for (final _TextRowLayout row in rows) {
              totalHeight +=
                  _rowChordBandHeight(allLines[i], row, lineFontSize) +
                  lineTextHeight * lineSpacing;
            }
          }
        }
      }
    }

    totalHeight += prepared.bottomTextDescent;
    _textHeightCache[cacheKey] = totalHeight;
    while (_textHeightCache.length > _layoutCacheLimit) {
      _textHeightCache.remove(_textHeightCache.keys.first);
    }
    return totalHeight;
  }

  double _lineChordBandHeight(_RenderLine line, double fontSize) {
    if (!globals.useAkkord || !settings.receiverUseAkkord) {
      return 0;
    }
    return _chordBandHeightForFont(
      fontSize,
      line.words
          .map((w) => w.chord ?? '')
          .where((String chord) => chord.isNotEmpty),
    );
  }

  /// Measures the tallest chord of [chords] in the selected notation, so the
  /// band tracks the actual spellings rather than one fixed sample.
  double _chordBandHeightForFont(double fontSize, Iterable<String> chords) {
    final TextStyle chordStyle = TextStyle(
      color: globals.txtColor,
      fontSize: fontSize * (globals.akkordArany / 100.0),
    );
    double tallest = 0;
    for (final String chord in chords) {
      final double height = _chordLayout(chord, chordStyle).height;
      if (height > tallest) {
        tallest = height;
      }
    }
    return tallest + 2;
  }

  double _rowChordBandHeight(
    _RenderLine line,
    _TextRowLayout row,
    double fontSize,
  ) {
    if (!globals.useAkkord || !settings.receiverUseAkkord) {
      return 0;
    }
    return _chordBandHeightForFont(
      fontSize,
      row.wordIndices
          .where((int wi) => wi >= 0 && wi < line.words.length)
          .map((int wi) => line.words[wi].chord ?? '')
          .where((String chord) => chord.isNotEmpty),
    );
  }

  double _measureTextRowHeight(_RenderLine line, double fontSize) {
    return _buildTextRowMeasure(line, fontSize).height;
  }

  double _measureTextRowDescent(_RenderLine line, double fontSize) {
    final TextPainter tp = _buildTextRowMeasure(line, fontSize);
    final List<ui.LineMetrics> metrics = tp.computeLineMetrics();
    return metrics.isEmpty ? 0 : metrics.last.descent;
  }

  TextPainter _buildTextRowMeasure(_RenderLine line, double fontSize) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    for (final _WordToken word in line.words) {
      final Color baseColor = word.color ?? globals.txtColor;
      spans.add(
        TextSpan(
          text: _wordLayoutDisplay(word, fontSize, measure),
          style: TextStyle(
            color: baseColor,
            fontSize: _effectiveWordFontSize(word, fontSize),
            fontWeight: (globals.boldText || word.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.combine(<TextDecoration>[
              if (word.underline) TextDecoration.underline,
              if (word.strike) TextDecoration.lineThrough,
            ]),
          ),
        ),
      );
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
      textAlign: globals.hCenter ? TextAlign.center : TextAlign.left,
    )..layout();
    return tp;
  }

  void _paintTextRow(
    Canvas canvas,
    _RenderLine rowLine,
    List<bool> rowHighlights,
    List<int> rowWordIndices,
    bool drawEndHyphen,
    double x,
    double y,
    double fontSize,
  ) {
    final _TextRowPaintLayout layout = _buildTextRowPaintLayout(
      rowLine,
      rowHighlights,
      fontSize,
    );
    layout.painter.paint(canvas, Offset(x, y));
    _paintTieUnderlines(
      canvas,
      layout,
      rowLine.words,
      rowWordIndices,
      x,
      y,
      fontSize,
    );
    if (drawEndHyphen && rowLine.words.isNotEmpty) {
      final _WordToken lastWord = rowLine.words.last;
      final bool highlighted = rowHighlights.isNotEmpty
          ? rowHighlights.last
          : false;
      final Color baseColor = lastWord.color ?? globals.txtColor;
      final TextPainter hyphen = TextPainter(
        text: TextSpan(
          text: '-',
          style: TextStyle(
            color: highlighted ? globals.hiColor : baseColor,
            fontSize: _effectiveWordFontSize(lastWord, fontSize),
            fontWeight: (globals.boldText || lastWord.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: lastWord.italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hyphen.paint(canvas, Offset(x + layout.painter.width, y));
    }
  }

  _TextRowPaintLayout _buildTextRowPaintLayout(
    _RenderLine rowLine,
    List<bool> rowHighlights,
    double fontSize,
  ) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final List<_TextWordLayout> wordLayouts = <_TextWordLayout>[];
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    int offset = 0;

    for (int i = 0; i < rowLine.words.length; i++) {
      final _WordToken word = rowLine.words[i];
      final bool highlighted = i < rowHighlights.length
          ? rowHighlights[i]
          : false;
      final String display = _wordLayoutDisplay(word, fontSize, measure);
      final Color baseColor = word.color ?? globals.txtColor;
      spans.add(
        TextSpan(
          text: display,
          style: TextStyle(
            color: highlighted ? globals.hiColor : baseColor,
            fontSize: _effectiveWordFontSize(word, fontSize),
            fontWeight: (globals.boldText || word.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.combine(<TextDecoration>[
              if (word.underline) TextDecoration.underline,
              if (word.strike) TextDecoration.lineThrough,
            ]),
          ),
        ),
      );
      wordLayouts.add(
        _TextWordLayout(
          start: offset,
          end: offset + word.text.length,
          tieUnderline: word.tieUnderline,
          color: baseColor,
        ),
      );
      offset += display.length;
    }

    final TextPainter painter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
      textAlign: globals.hCenter ? TextAlign.center : TextAlign.left,
    )..layout();
    return _TextRowPaintLayout(painter: painter, wordLayouts: wordLayouts);
  }

  void _paintTieUnderlines(
    Canvas canvas,
    _TextRowPaintLayout layout,
    List<_WordToken> rowWords,
    List<int> rowWordIndices,
    double x,
    double y,
    double fontSize,
  ) {
    final List<ui.LineMetrics> metrics = layout.painter.computeLineMetrics();
    if (metrics.isEmpty) {
      return;
    }

    final ui.LineMetrics metric = metrics.first;
    final double baselineY = y + metric.baseline;
    final double textBottomY = baselineY + metric.descent;

    int index = 0;
    while (index < layout.wordLayouts.length) {
      final _TextWordLayout startLayout = layout.wordLayouts[index];
      if (!startLayout.tieUnderline) {
        index++;
        continue;
      }

      int runEnd = index;
      while (runEnd + 1 < layout.wordLayouts.length &&
          layout.wordLayouts[runEnd + 1].tieUnderline) {
        runEnd++;
      }

      final _TextWordLayout endLayout = layout.wordLayouts[runEnd];
      final List<ui.TextBox> startBoxes = layout.painter.getBoxesForSelection(
        TextSelection(
          baseOffset: startLayout.start,
          extentOffset: startLayout.end,
        ),
      );
      final List<ui.TextBox> endBoxes = layout.painter.getBoxesForSelection(
        TextSelection(baseOffset: endLayout.start, extentOffset: endLayout.end),
      );
      if (startBoxes.isEmpty || endBoxes.isEmpty) {
        index = runEnd + 1;
        continue;
      }

      final int startWordIndex = rowWordIndices[index];
      final int endWordIndex = rowWordIndices[runEnd];
      final bool continuedFromPrevious =
          index == 0 &&
          startWordIndex > 0 &&
          rowWords[startWordIndex - 1].tieUnderline;
      final bool continuesToNext =
          runEnd + 1 == layout.wordLayouts.length &&
          endWordIndex + 1 < rowWords.length &&
          rowWords[endWordIndex + 1].tieUnderline;

      final double startX = x + startBoxes.first.left;
      final double endX = x + endBoxes.last.right;
      _paintTieUnderline(
        canvas,
        startX: startX,
        endX: endX,
        tipY: baselineY + _tieUnderlineTipOffset(fontSize),
        bottomY: textBottomY,
        color: startLayout.color,
        continuedFromPrevious: continuedFromPrevious,
        continuesToNext: continuesToNext,
      );

      index = runEnd + 1;
    }
  }

  void _paintKottaTieUnderlines(
    Canvas canvas, {
    required List<_WordToken> sourceWords,
    required List<_KottaTextSlotLayout> slots,
    required double y,
    required double fontSize,
  }) {
    if (slots.isEmpty) {
      return;
    }

    final TextPainter measure = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: globals.boldText ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ui.LineMetrics metric = measure.computeLineMetrics().first;
    final double baselineY = y + metric.baseline;
    final double textBottomY = baselineY + metric.descent;

    int index = 0;
    while (index < slots.length) {
      final _KottaTextSlotLayout startSlot = slots[index];
      if (!startSlot.tieUnderline) {
        index++;
        continue;
      }

      int runEnd = index;
      while (runEnd + 1 < slots.length && slots[runEnd + 1].tieUnderline) {
        runEnd++;
      }

      final _KottaTextSlotLayout endSlot = slots[runEnd];
      final bool continuedFromPrevious =
          index == 0 &&
          startSlot.wordIndex > 0 &&
          sourceWords[startSlot.wordIndex - 1].tieUnderline;
      final bool continuesToNext =
          runEnd + 1 == slots.length &&
          endSlot.wordIndex + 1 < sourceWords.length &&
          sourceWords[endSlot.wordIndex + 1].tieUnderline;

      final double startX = startSlot.left;
      final double endX = endSlot.tieRight;
      _paintTieUnderline(
        canvas,
        startX: startX,
        endX: endX,
        tipY: baselineY + _tieUnderlineTipOffset(fontSize),
        bottomY: textBottomY,
        color: startSlot.color,
        continuedFromPrevious: continuedFromPrevious,
        continuesToNext: continuesToNext,
      );

      index = runEnd + 1;
    }
  }

  double _tieUnderlineTipOffset(double fontSize) {
    final double underlineOffset = math.max(1.0, fontSize * 0.08);
    final double thickness = math.max(1.0, fontSize * 0.045);
    final double desiredOffset = math.max(0, (fontSize - 14) / 10);
    return math.min(
      desiredOffset,
      math.max(0, underlineOffset - thickness / 2),
    );
  }

  void _paintTieUnderline(
    Canvas canvas, {
    required double startX,
    required double endX,
    required double tipY,
    required double bottomY,
    required Color color,
    required bool continuedFromPrevious,
    required bool continuesToNext,
  }) {
    if (endX <= startX) {
      return;
    }

    final double depth = math.max(1.0, bottomY - tipY);
    final double topMiddleY = tipY + depth * 0.72;
    final double middleX = continuedFromPrevious
        ? startX
        : continuesToNext
        ? endX
        : (startX + endX) / 2;
    final Path path = Path();

    if (continuedFromPrevious) {
      path.moveTo(startX, bottomY);
    } else {
      final double control = math.min(depth, (middleX - startX) * 0.45);
      path
        ..moveTo(startX, tipY)
        ..cubicTo(
          startX + control,
          tipY + control,
          middleX - control,
          bottomY,
          middleX,
          bottomY,
        );
    }

    if (continuesToNext) {
      path.lineTo(endX, bottomY);
    } else {
      final double control = math.min(depth, (endX - middleX) * 0.45);
      path.cubicTo(
        middleX + control,
        bottomY,
        endX - control,
        tipY + control,
        endX,
        tipY,
      );
    }

    if (continuesToNext) {
      path.lineTo(endX, topMiddleY);
    } else {
      final double control = math.min(depth, (endX - middleX) * 0.45);
      path.cubicTo(
        endX - control,
        tipY + depth * 0.55,
        middleX + control,
        topMiddleY,
        middleX,
        topMiddleY,
      );
    }

    if (continuedFromPrevious) {
      path.lineTo(startX, topMiddleY);
    } else {
      final double control = math.min(depth, (middleX - startX) * 0.45);
      path.cubicTo(
        middleX - control,
        topMiddleY,
        startX + control,
        tipY + depth * 0.55,
        startX,
        tipY,
      );
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  _RenderLine _splitOverlongWords(
    _RenderLine line,
    double fontSize,
    double maxWidth, {
    required double continuationIndent,
  }) {
    if (line.words.isEmpty) {
      return line;
    }

    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    final double splitLimit = math.max(8.0, maxWidth - continuationIndent);
    const double minWordScale = 0.82;
    const double minWordScaleFallback = 0.62;
    bool changed = false;
    final List<_WordToken> words = <_WordToken>[];

    for (final _WordToken word in line.words) {
      final double width = _measureWordDisplayWidth(word, fontSize, measure);
      if (width <= splitLimit || word.text.characters.length <= 1) {
        words.add(word);
        continue;
      }

      final _WordToken? shrunk = _shrinkWordToFitWidth(
        word,
        fontSize,
        splitLimit,
        minWordScale,
        measure,
        currentWidth: width,
      );
      if (shrunk != null) {
        changed = true;
        words.add(shrunk);
        continue;
      }

      // Prefer per-word downsizing over forced word-splitting.
      final _WordToken? fallbackShrunk = _shrinkWordToFitWidth(
        word,
        fontSize,
        splitLimit,
        minWordScaleFallback,
        measure,
        currentWidth: width,
      );
      if (fallbackShrunk != null) {
        changed = true;
        words.add(fallbackShrunk);
        continue;
      }

      final List<_WordToken> chunks = _splitWordToFitWidth(
        word,
        fontSize,
        splitLimit,
        measure,
      );
      if (chunks.length <= 1) {
        words.add(word);
        continue;
      }

      changed = true;
      words.addAll(chunks);
    }

    return changed ? _RenderLine(words: words) : line;
  }

  _WordToken? _shrinkWordToFitWidth(
    _WordToken word,
    double fontSize,
    double maxWidth,
    double minWordScale,
    TextPainter measure, {
    required double currentWidth,
  }) {
    if ((word.chord ?? '').trim().isNotEmpty ||
        (word.kotta ?? '').trim().isNotEmpty) {
      return null;
    }
    if (word.fontScale <= minWordScale) {
      return null;
    }

    final double targetScale = (word.fontScale * (maxWidth / currentWidth))
        .clamp(minWordScale, 1.0);
    if ((word.fontScale - targetScale).abs() < 0.001) {
      return null;
    }

    final _WordToken scaled = _WordToken(
      text: word.text,
      bold: word.bold,
      italic: word.italic,
      underline: word.underline,
      tieUnderline: word.tieUnderline,
      strike: word.strike,
      color: word.color,
      chord: word.chord,
      kotta: word.kotta,
      spaceAfter: word.spaceAfter,
      breakAfter: word.breakAfter,
      preferredBreakAfter: word.preferredBreakAfter,
      softHyphenAfter: word.softHyphenAfter,
      fontScale: targetScale,
    );

    final double scaledWidth = _measureWordDisplayWidth(
      scaled,
      fontSize,
      measure,
    );
    return scaledWidth <= maxWidth + 0.5 ? scaled : null;
  }

  List<_WordToken> _splitWordToFitWidth(
    _WordToken word,
    double fontSize,
    double maxChunkWidth,
    TextPainter measure,
  ) {
    final List<String> graphemes = word.text.characters.toList();
    if (graphemes.length <= 1) {
      return <_WordToken>[word];
    }

    final List<_WordToken> parts = <_WordToken>[];
    int start = 0;
    while (start < graphemes.length) {
      int low = 1;
      int high = graphemes.length - start;
      int bestLen = 0;

      while (low <= high) {
        final int mid = (low + high) ~/ 2;
        final bool isLastCandidate = start + mid >= graphemes.length;
        final String chunk = graphemes.sublist(start, start + mid).join();

        measure.text = TextSpan(
          text: chunk + (isLastCandidate && word.spaceAfter ? ' ' : ''),
          style: TextStyle(
            fontSize: _effectiveWordFontSize(word, fontSize),
            fontWeight: (globals.boldText || word.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
          ),
        );
        measure.layout();

        if (measure.width <= maxChunkWidth) {
          bestLen = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      if (bestLen <= 0) {
        bestLen = 1;
      }

      double chunkScale = word.fontScale;
      if (bestLen == 1) {
        // A single grapheme already exceeds the chunk limit. Reduce the font
        // scale just enough that this lone grapheme no longer overflows.
        measure.text = TextSpan(
          text: graphemes[start].toString(),
          style: TextStyle(
            fontSize: _effectiveWordFontSize(word, fontSize),
            fontWeight: (globals.boldText || word.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
          ),
        );
        measure.layout();
        final double singleWidth = measure.width;
        if (singleWidth > maxChunkWidth + 0.5) {
          chunkScale = (chunkScale * (maxChunkWidth / singleWidth)).clamp(
            0.5,
            1.0,
          );
        }
      }

      final bool isLast = start + bestLen >= graphemes.length;
      parts.add(
        _WordToken(
          text: graphemes.sublist(start, start + bestLen).join(),
          bold: word.bold,
          italic: word.italic,
          underline: word.underline,
          tieUnderline: word.tieUnderline,
          strike: word.strike,
          color: word.color,
          chord: start == 0 ? word.chord : null,
          kotta: start == 0 ? word.kotta : null,
          spaceAfter: isLast ? word.spaceAfter : false,
          // Non-final chunks must be breakable; otherwise splitting has no effect.
          breakAfter: isLast ? word.breakAfter : true,
          preferredBreakAfter: isLast ? word.preferredBreakAfter : false,
          softHyphenAfter: isLast ? word.softHyphenAfter : false,
          fontScale: chunkScale,
        ),
      );

      start += bestLen;
    }

    return parts;
  }

  /// Lays out a chord with the notation the sender selected. The options ride
  /// along in the state record, so a receiver renders them without any
  /// settings of its own.
  ChordLayout _chordLayout(String source, TextStyle style) {
    return ChordRenderer.layout(
      source,
      style,
      notation: chordNotationFromStorage(globals.akkordNotation),
      optionalSeventh: globals.akkordOptionalSeventh,
      minorAsDash: globals.akkordMinorAsDash,
    );
  }

  void _paintChords(
    Canvas canvas,
    _RenderLine line,
    double x,
    double y,
    double fontSize,
  ) {
    if (line.words.isEmpty ||
        !globals.useAkkord ||
        !settings.receiverUseAkkord) {
      return;
    }
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    double cx = x;
    for (int i = 0; i < line.words.length; i++) {
      final _WordToken w = line.words[i];
      if ((w.chord ?? '').isNotEmpty) {
        final ChordLayout chord = _chordLayout(
          w.chord!,
          TextStyle(
            color: globals.txtColor,
            fontSize: fontSize * (globals.akkordArany / 100),
          ),
        );
        chord.paint(canvas, Offset(cx, y - chord.height - 2));
      }
      cx += _measureWordDisplayWidth(w, fontSize, measure);
    }
  }

  void _paintKotta(
    Canvas canvas,
    _RenderLine line,
    double firstTextY,
    double rowStep,
    double fontSize,
    double maxWidth,
    double sizeWidth,
    double continuationIndent,
    List<_KottaRowLayout>? precomputedRows,
  ) {
    if (line.words.isEmpty || !globals.useKotta) {
      return;
    }
    final double lineGap = _kottaLineGap(fontSize);
    final double staffHeight = _kottaStaffHeight(lineGap);
    final double staffToTextGap = _kottaStaffToTextGap(lineGap);
    final List<_KottaRowLayout> rows =
        precomputedRows ?? _buildKottaRows(line, fontSize, maxWidth);
    if (rows.isEmpty) {
      return;
    }

    final _KottaDrawState lineState = _KottaDrawState();
    final List<_KottaRowPrefix> rowPrefixes = _resolveKottaRowPrefixes(
      rows,
      line,
      lineGap,
    );
    final double baseTop = firstTextY - staffHeight - staffToTextGap;
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final _KottaRowLayout row = rows[rowIndex];
      final _KottaRowPrefix rowPrefix = rowPrefixes[rowIndex];
      final double rowX =
          _kottaRowsStartX(
            rows,
            sizeWidth,
            continuationIndent,
            rowIndex: rowIndex,
          ) +
          _kottaContinuationIndent(rowIndex, continuationIndent);
      final double rowTop = baseTop + rowIndex * rowStep;
      _editorKottaTop ??= rowTop - _kottaLedgerReserve(lineGap);
      _editorKottaBottom ??= rowTop + staffHeight + staffToTextGap;
      if (globals.inverzKotta) {
        canvas.drawRect(
          Rect.fromLTRB(
            rowX,
            rowTop - _kottaLedgerReserve(lineGap),
            rowX + row.width,
            rowTop + staffHeight + _kottaLedgerReserve(lineGap),
          ),
          Paint()..color = globals.txtColor,
        );
      }
      final int staffLineCount = row.staffLineCount;
      lineState.staffLineCount = staffLineCount;
      lineState.rowStartX = rowX;
      lineState.currentX = rowX;

      double cx = rowX;
      for (int slotIndex = 0; slotIndex < row.words.length; slotIndex++) {
        final _KottaWordLayout slot = row.words[slotIndex];
        final _WordToken w = line.words[slot.wordIndex];
        String kotta = (w.kotta ?? '').trim();
        final bool isFirstSlot = slotIndex == 0;
        if (isFirstSlot && rowPrefix.kotta.isNotEmpty) {
          _drawSimpleKotta(
            canvas,
            rowPrefix.kotta,
            cx,
            rowTop + staffHeight + staffToTextGap,
            rowPrefix.width,
            fontSize,
            state: lineState,
            lineGapOverride: lineGap,
            drawStaff: false,
          );
          cx += rowPrefix.width;
          lineState.slurLeftX = cx;
        }
        if (isFirstSlot && row.inlinePrefix.kotta.isNotEmpty) {
          _captureEditorKottaCursor(
            row.inlinePrefix.kotta,
            cx,
            lineGap,
            lineState,
          );
          _drawSimpleKotta(
            canvas,
            row.inlinePrefix.kotta,
            cx,
            rowTop + staffHeight + staffToTextGap,
            row.inlinePrefix.width,
            fontSize,
            state: lineState,
            lineGapOverride: lineGap,
            drawStaff: false,
          );
          cx += row.inlinePrefix.width;
          if (kotta.startsWith(row.inlinePrefix.kotta)) {
            kotta = kotta.substring(row.inlinePrefix.kotta.length);
          }
        }
        if (kotta.isNotEmpty) {
          _captureEditorKottaCursor(kotta, cx, lineGap, lineState);
          _drawSimpleKotta(
            canvas,
            kotta,
            cx,
            rowTop + staffHeight + staffToTextGap,
            slot.slotWidth,
            fontSize,
            state: lineState,
            lineGapOverride: lineGap,
            drawStaff: false,
          );
        }
        cx += slot.slotWidth + slot.groupGap;
      }

      _endKottaRow(canvas, lineState, rowTop, lineGap, cx);
    }
  }

  double _kottaLineGap(double fontSize) {
    final int ratio = globals.kottaArany;
    return _kottaRowTextHeight(fontSize) *
        0.2 *
        ((ratio < 10 || ratio > 200 ? 100 : ratio) / 100);
  }

  double _kottaStaffHeight(double lineGap) {
    return lineGap * 4;
  }

  int _staffLineCountForLine(_RenderLine line) {
    for (final _WordToken word in line.words) {
      final List<String> commands = _parseKottaCommands(
        (word.kotta ?? '').trim(),
      );
      if (commands.isEmpty) {
        continue;
      }
      final String first = commands.first;
      if (first[0] == '-') {
        return int.tryParse(first[1])?.clamp(0, 5).toInt() ?? 5;
      }
      return 5;
    }
    return 5;
  }

  double _kottaLedgerReserve(double lineGap) {
    return lineGap * 3;
  }

  Color get _kottaInkColor =>
      globals.inverzKotta ? globals.bkColor : globals.txtColor;

  double _kottaStaffToTextGap(double lineGap) {
    return lineGap * 3;
  }

  double _kottaRowBlockHeight(double fontSize) {
    final double lineGap = _kottaLineGap(fontSize);
    return 10 * lineGap +
        _kottaRowTextHeight(fontSize) * globals.spacing100 / 100;
  }

  double _titleToKottaGap(double fontSize) {
    return math.max(10.0, _kottaLineGap(fontSize) * 1.5);
  }

  double _titleToKottaTransitionGap({
    required double nextLineFontSize,
    required double titleHeight,
    required double lineSpacing,
  }) {
    final double compressedTitleOverlap = math.max(
      0.0,
      titleHeight - titleHeight * lineSpacing,
    );
    return _titleToKottaGap(nextLineFontSize) + compressedTitleOverlap;
  }

  double _kottaRowTextHeight(double fontSize) {
    final metrics = _kottaTextMetrics(fontSize);
    return metrics.ascent + metrics.descent;
  }

  double _kottaSourceLineGap(double fontSize) =>
      _kottaTextMetrics(fontSize).descent * globals.spacing100 / 100;

  ui.LineMetrics _kottaTextMetrics(double fontSize) {
    final TextPainter measure = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final metrics = measure.computeLineMetrics().single;
    measure.dispose();
    return metrics;
  }

  double _kottaRowStartX(
    double rowWidth,
    double sizeWidth,
    double horizontalPad,
  ) {
    if (!globals.hCenter) {
      return 0;
    }
    return math.max(0, (sizeWidth - rowWidth) / 2.0);
  }

  double _kottaRowsStartX(
    List<_KottaRowLayout> rows,
    double sizeWidth,
    double horizontalPad, {
    int rowIndex = 0,
  }) {
    if (rows.isEmpty) {
      return _kottaRowStartX(0, sizeWidth, horizontalPad);
    }
    return _kottaRowStartX(
      rows[rowIndex].centeringWidth ?? rows[rowIndex].width,
      sizeWidth,
      horizontalPad,
    );
  }

  double _kottaContinuationIndent(int rowIndex, double horizontalPad) {
    if (rowIndex <= 0) {
      return 0;
    }
    return horizontalPad;
  }

  void _paintKottaAlignedTextRow(
    Canvas canvas,
    _RenderLine line,
    List<bool> highlights,
    _KottaRowLayout row,
    double rowX,
    double y,
    double fontSize, {
    double leadingInset = 0,
  }) {
    double cx = rowX;
    final List<_KottaTextSlotLayout> slotLayouts = <_KottaTextSlotLayout>[];
    for (int slotIndex = 0; slotIndex < row.words.length; slotIndex++) {
      final _KottaWordLayout slot = row.words[slotIndex];
      final _WordToken w = line.words[slot.wordIndex];
      final bool highlighted = slot.wordIndex < highlights.length
          ? highlights[slot.wordIndex]
          : false;
      final Color baseColor = w.color ?? globals.txtColor;
      final String display =
          w.text + (w.spaceAfter && !w.preferredBreakAfter ? ' ' : '');
      final double rowInset = slotIndex == 0 ? leadingInset : 0;
      final double inset = rowInset + slot.textInset;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: display,
          style: TextStyle(
            color: highlighted ? globals.hiColor : baseColor,
            fontSize: _effectiveWordFontSize(w, fontSize),
            fontWeight: (globals.boldText || w.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: w.italic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.combine(<TextDecoration>[
              if (w.underline) TextDecoration.underline,
              if (w.strike) TextDecoration.lineThrough,
            ]),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double slotLeft = cx + inset;
      if (globals.useAkkord &&
          settings.receiverUseAkkord &&
          (w.chord ?? '').isNotEmpty) {
        final chord = _chordLayout(
          w.chord!,
          TextStyle(
            color: baseColor,
            fontSize: fontSize * globals.akkordArany / 100,
          ),
        );
        chord.paint(canvas, Offset(slotLeft, y - chord.height - 2));
      }
      if (display.isEmpty) {
        _captureEditorTextCursor(display, tp, slotLeft, y);
        cx += slot.slotWidth + slot.groupGap + rowInset;
        continue;
      }
      tp.paint(canvas, Offset(slotLeft, y));
      _captureEditorTextCursor(display, tp, slotLeft, y);
      final List<ui.TextBox> textBoxes = tp.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: w.text.length),
      );
      slotLayouts.add(
        _KottaTextSlotLayout(
          wordIndex: slot.wordIndex,
          left: slotLeft,
          right: slotLeft + tp.width,
          tieRight: slotLeft + (textBoxes.isEmpty ? 0 : textBoxes.last.right),
          baseline: y + tp.computeLineMetrics().first.baseline,
          tieUnderline: w.tieUnderline,
          color: baseColor,
          connectorColor: highlighted ? globals.hiColor : baseColor,
        ),
      );
      cx += slot.slotWidth + slot.groupGap + rowInset;
    }

    _paintKottaLetterConnectors(canvas, line.words, slotLayouts, fontSize);
    _paintKottaTieUnderlines(
      canvas,
      sourceWords: line.words,
      slots: slotLayouts,
      y: y,
      fontSize: fontSize,
    );

    if (row.endHyphen && row.words.isNotEmpty) {
      final _WordToken lastWord = line.words[row.words.last.wordIndex];
      final bool highlighted = row.words.last.wordIndex < highlights.length
          ? highlights[row.words.last.wordIndex]
          : false;
      final Color baseColor = lastWord.color ?? globals.txtColor;
      final double hyphenX = slotLayouts.isEmpty
          ? rowX
          : slotLayouts.last.right;
      final TextPainter hyphen = TextPainter(
        text: TextSpan(
          text: '-',
          style: TextStyle(
            color: highlighted ? globals.hiColor : baseColor,
            fontSize: _effectiveWordFontSize(lastWord, fontSize),
            fontWeight: (globals.boldText || lastWord.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: lastWord.italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hyphen.paint(canvas, Offset(hyphenX, y));
    }
  }

  void _resetEditorCursorCapture() {
    _editorKottaX = null;
    _editorKottaTop = null;
    _editorKottaBottom = null;
    _editorTextX = null;
    _editorTextTop = null;
    _editorTextBottom = null;
    _editorKottaCommandIndex = 0;
    _editorTextCharacterIndex = 0;
    _editorKottaPositions.clear();
    _editorTextPositions.clear();
  }

  void _captureEditorKottaCursor(
    String kotta,
    double startX,
    double lineGap,
    _KottaDrawState state,
  ) {
    final ProjectorEditorCursorOverlay? overlay = editorCursorOverlay;
    if (overlay == null) {
      return;
    }
    final List<String> commands = _parseKottaCommands(kotta);
    final int target = overlay.kottaPosition;
    final int startIndex = _editorKottaCommandIndex;
    final int endIndex = startIndex + commands.length;
    final _KottaDrawState measureState = state.copy();
    double x = startX;
    if (startIndex == 0) {
      _editorKottaPositions.putIfAbsent(0, () => x);
    }
    for (int index = 0; index < commands.length; index++) {
      if (startIndex + index == target) {
        _editorKottaX ??= x;
      }
      final double width = _kottaWidthOf(
        commands[index],
        lineGap,
        measureState,
      );
      x += width;
      if (width > 0) {
        _editorKottaPositions.putIfAbsent(startIndex + index + 1, () => x);
      }
    }
    if (target == endIndex) {
      _editorKottaX ??= x;
    }
    _editorKottaCommandIndex = endIndex;
  }

  void _captureEditorTextCursor(
    String display,
    TextPainter painter,
    double startX,
    double top,
  ) {
    final ProjectorEditorCursorOverlay? overlay = editorCursorOverlay;
    if (overlay == null) {
      return;
    }
    final int startIndex = _editorTextCharacterIndex;
    final int endIndex = startIndex + display.length;
    for (int index = 0; index <= display.length; index++) {
      _editorTextPositions[startIndex + index] =
          startX +
          painter.getOffsetForCaret(TextPosition(offset: index), Rect.zero).dx;
    }
    if (overlay.textPosition >= startIndex &&
        overlay.textPosition <= endIndex) {
      final int localOffset = overlay.textPosition - startIndex;
      _editorTextX =
          startX +
          painter
              .getOffsetForCaret(TextPosition(offset: localOffset), Rect.zero)
              .dx;
      _editorTextTop = top;
      _editorTextBottom = top + painter.height;
    }
    _editorTextCharacterIndex = endIndex;
  }

  void _paintEditorCursors(Canvas canvas) {
    final ProjectorEditorCursorOverlay? overlay = editorCursorOverlay;
    final double? textX = _editorTextX;
    final double? textTop = _editorTextTop;
    final double? textBottom = _editorTextBottom;
    final double? kottaTop = _editorKottaTop;
    final double? kottaBottom = _editorKottaBottom;
    if (overlay == null ||
        textX == null ||
        textTop == null ||
        textBottom == null ||
        kottaTop == null ||
        kottaBottom == null) {
      return;
    }

    final double kottaX = _editorKottaX ?? textX;
    if (_editorKottaPositions.isEmpty) {
      _editorKottaPositions[0] = textX;
    }
    final ProjectorEditorCursorLayout layout = ProjectorEditorCursorLayout(
      kottaRect: Rect.fromLTRB(kottaX, kottaTop, kottaX + 2, kottaBottom),
      textRect: Rect.fromLTRB(textX, textTop, textX + 2, textBottom),
      kottaPositions: Map<int, double>.unmodifiable(_editorKottaPositions),
      textPositions: Map<int, double>.unmodifiable(_editorTextPositions),
    );
    final TextSelection? selection = overlay.kottaSelection;
    if (selection != null && !selection.isCollapsed) {
      final double? startX = layout.kottaXForPosition(selection.start);
      final double? endX = layout.kottaXForPosition(selection.end);
      if (startX != null && endX != null) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(startX, endX),
            kottaTop,
            math.max(startX, endX),
            kottaBottom,
          ),
          Paint()..color = Colors.blue.withValues(alpha: 0.25),
        );
      }
    }
    onEditorCursorLayout?.call(layout);
    _paintEditorCursorLine(
      canvas,
      x: kottaX,
      top: kottaTop,
      bottom: kottaBottom,
      active: !overlay.textActive,
      visible: overlay.textActive || overlay.activeVisible,
    );
    _paintEditorCursorLine(
      canvas,
      x: textX,
      top: textTop,
      bottom: textBottom,
      active: overlay.textActive,
      visible: !overlay.textActive || overlay.activeVisible,
    );
  }

  void _paintEditorCursorLine(
    Canvas canvas, {
    required double x,
    required double top,
    required double bottom,
    required bool active,
    required bool visible,
  }) {
    if (!visible) {
      return;
    }
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = active ? globals.txtColor : Colors.red
        ..strokeWidth = active ? 2 : 1,
    );
  }

  bool _shouldPaintKottaLetterConnector({
    required _WordToken previous,
    required _WordToken current,
    required double gap,
  }) {
    return !previous.spaceAfter &&
        previous.text.isNotEmpty &&
        current.text.isNotEmpty &&
        gap > 0.5;
  }

  void _paintKottaLetterConnectors(
    Canvas canvas,
    List<_WordToken> sourceWords,
    List<_KottaTextSlotLayout> slots,
    double fontSize,
  ) {
    if (slots.length < 2) {
      return;
    }

    final Paint paint = Paint()
      ..strokeWidth = math.max(0.75, fontSize * 0.025)
      ..strokeCap = StrokeCap.butt;
    for (int i = 1; i < slots.length; i++) {
      final _KottaTextSlotLayout previousSlot = slots[i - 1];
      final _KottaTextSlotLayout currentSlot = slots[i];
      final _WordToken previous = sourceWords[previousSlot.wordIndex];
      final _WordToken current = sourceWords[currentSlot.wordIndex];
      final double gap = currentSlot.left - previousSlot.right;
      if (!_shouldPaintKottaLetterConnector(
        previous: previous,
        current: current,
        gap: gap,
      )) {
        continue;
      }

      paint.color = previousSlot.connectorColor;
      canvas.drawLine(
        Offset(previousSlot.right, previousSlot.baseline),
        Offset(currentSlot.left, previousSlot.baseline),
        paint,
      );
    }
  }

  List<_KottaRowLayout> _buildKottaRows(
    _RenderLine line,
    double fontSize,
    double maxWidth, {
    _KottaDrawState? inheritedState,
  }) {
    final String cacheKey = _kottaRowsCacheKey(
      line,
      fontSize,
      maxWidth,
      inheritedState,
    );
    final List<_KottaRowLayout>? cached = _kottaRowsCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    final double lineGap = _kottaLineGap(fontSize);
    final double wrapWidth = math.max(8.0, maxWidth);
    final double continuationIndent = _textContinuationIndent(
      fontSize,
      measure,
    );
    measure.text = TextSpan(
      text: ' ',
      style: TextStyle(fontSize: fontSize),
    );
    measure.layout();
    final double spaceWidth = measure.width;
    final _KottaDrawState state = inheritedState?.copy() ?? _KottaDrawState();
    state.resetTransient();
    final initialPrefix = _kottaRowPrefixForState(state, lineGap);
    final double inheritedSetupWidth = state.lastSetupWidth;
    final groups =
        <({List<_KottaWordLayout> words, double width, double setupWidth})>[];
    final List<_KottaWordLayout> pendingWord = <_KottaWordLayout>[];
    double pendingWordWidth = 0;
    double pendingSetupWidth = 0;

    for (int i = 0; i < line.words.length; i++) {
      final _WordToken w = line.words[i];
      final double textWidth =
          _measureWordDisplayWidth(w, fontSize, measure) -
          (w.preferredBreakAfter ? spaceWidth : 0);
      final String kotta = (w.kotta ?? '').trim();
      final melody = _measureKotta(kotta, lineGap, state);
      final double slotWidth = math.max(
        math.max(
          textWidth + melody.textInset,
          melody.width + (w.text.isNotEmpty ? melody.compactGap : 0),
        ),
        globals.useAkkord &&
                settings.receiverUseAkkord &&
                (w.chord ?? '').isNotEmpty
            ? _chordLayout(
                w.chord!,
                TextStyle(fontSize: fontSize * globals.akkordArany / 100),
              ).width
            : 0,
      );
      final double groupGap = w.spaceAfter ? spaceWidth : 0;
      if (melody.textInset > 0) pendingSetupWidth = melody.textInset;

      pendingWord.add(
        _KottaWordLayout(
          wordIndex: i,
          slotWidth: slotWidth,
          textInset: melody.textInset,
          groupGap: groupGap,
        ),
      );
      pendingWordWidth += slotWidth + groupGap;

      final bool endsWord =
          w.breakAfter || w.softHyphenAfter || i == line.words.length - 1;
      if (!endsWord) {
        continue;
      }
      groups.add((
        words: List<_KottaWordLayout>.from(pendingWord),
        width: pendingWordWidth - groupGap,
        setupWidth: pendingSetupWidth,
      ));
      pendingWord.clear();
      pendingWordWidth = 0;
      pendingSetupWidth = 0;
    }

    double hyphenWidth(int index) {
      final word = line.words[groups[index].words.last.wordIndex];
      return word.softHyphenAfter
          ? _measureHyphenDisplayWidth(word, fontSize, measure)
          : 0;
    }

    // Android carries the last setup inset, including meters, not only clefs.
    final breaks = List<bool>.filled(groups.length, false);
    double nextSetupWidth = inheritedSetupWidth;
    double startX = nextSetupWidth;
    int start = 0;
    int rowCount = 0;
    while (start < groups.length) {
      int end = start + 1;
      double x = startX;
      for (int i = start; i < groups.length; i++) {
        final group = groups[i];
        x += group.width;
        if (group.setupWidth > 0) nextSetupWidth = group.setupWidth;
        if (x + hyphenWidth(i) > wrapWidth) break;
        end = i + 1;
        x += group.words.last.groupGap;
      }
      breaks[end - 1] = true;
      rowCount++;
      start = end;
      startX = continuationIndent + nextSetupWidth;
    }

    if (rowCount > 1 && line.words.any((word) => word.preferredBreakAfter)) {
      final preferredBreaks = List<bool>.filled(groups.length, false);
      bool tryBreaks(int level, int pos) {
        int preferred = 0;
        int lastFit = pos;
        double width = continuationIndent;
        while (pos < groups.length) {
          preferredBreaks[pos] = false;
          final group = groups[pos];
          width += group.width;
          if (width + hyphenWidth(pos) > wrapWidth) break;
          if (line.words[group.words.last.wordIndex].preferredBreakAfter) {
            preferred = pos;
          }
          lastFit = pos;
          width += group.words.last.groupGap;
          pos++;
        }
        if (pos == groups.length) {
          preferredBreaks.last = true;
          return true;
        }
        if (level >= rowCount) return false;
        if (preferred > 0) {
          if (tryBreaks(level + 1, preferred + 1)) {
            preferredBreaks[preferred] = true;
            return true;
          }
          if (preferred == lastFit) return false;
        }
        preferredBreaks[lastFit] = true;
        return tryBreaks(level + 1, lastFit + 1);
      }

      if (tryBreaks(1, 0)) breaks.setAll(0, preferredBreaks);
    }

    final rows = <_KottaRowLayout>[];
    final currentWords = <_KottaWordLayout>[];
    double rowWidth = 0;
    double rowSetupWidth = inheritedSetupWidth;
    nextSetupWidth = inheritedSetupWidth;
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      currentWords.addAll(group.words);
      rowWidth += group.width;
      if (group.setupWidth > 0) nextSetupWidth = group.setupWidth;
      if (!breaks[i]) {
        rowWidth += group.words.last.groupGap;
        continue;
      }
      rows.add(
        _KottaRowLayout(
          words: List<_KottaWordLayout>.from(currentWords),
          width: rowWidth + hyphenWidth(i),
          centeringWidth: rowSetupWidth + rowWidth + hyphenWidth(i),
          prefix: rows.isEmpty ? initialPrefix : const _KottaRowPrefix.empty(),
          endHyphen: line.words[group.words.last.wordIndex].softHyphenAfter,
        ),
      );
      currentWords.clear();
      rowWidth = 0;
      rowSetupWidth = nextSetupWidth;
    }

    final List<_KottaRowLayout> resolved = _applyKottaRowPrefixes(
      rows,
      line,
      lineGap,
      fontSize,
      inheritedState,
    );
    _kottaRowsCache[cacheKey] = resolved;
    while (_kottaRowsCache.length > _layoutCacheLimit) {
      _kottaRowsCache.remove(_kottaRowsCache.keys.first);
    }
    return resolved;
  }

  List<_KottaRowLayout> _applyKottaRowPrefixes(
    List<_KottaRowLayout> rows,
    _RenderLine line,
    double lineGap,
    double fontSize,
    _KottaDrawState? inheritedState,
  ) {
    if (rows.isEmpty) {
      return rows;
    }

    final List<_KottaRowPrefix> prefixes = _resolveKottaRowPrefixes(
      rows,
      line,
      lineGap,
    );
    final List<_KottaRowLayout> resolvedRows = <_KottaRowLayout>[];
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    final _KottaDrawState state = inheritedState?.copy() ?? _KottaDrawState();
    state.resetTransient();

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final _KottaRowLayout row = rows[rowIndex];
      final _KottaRowPrefix prefix = prefixes[rowIndex];
      final int initialStaffLineCount = state.staffLineCount;
      for (final _KottaWordLayout slot in row.words) {
        _kottaRawWidth(line.words[slot.wordIndex].kotta ?? '', lineGap, state);
      }
      List<_KottaWordLayout> effectiveWords = row.words;
      _KottaRowPrefix inlinePrefix = const _KottaRowPrefix.empty();

      if (row.words.isNotEmpty) {
        final _KottaWordLayout firstSlot = row.words.first;
        final _WordToken firstWord = line.words[firstSlot.wordIndex];
        final String firstKotta = (firstWord.kotta ?? '').trim();
        final String leadingKotta = _leadingInlineKottaPrefix(firstKotta);
        if (leadingKotta.isNotEmpty) {
          final double leadingWidth = _kottaRawWidth(
            leadingKotta,
            lineGap,
            _KottaDrawState(),
          );
          final List<_KottaWordLayout> adjustedWords =
              List<_KottaWordLayout>.from(row.words);
          adjustedWords[0] = _KottaWordLayout(
            wordIndex: firstSlot.wordIndex,
            slotWidth: firstSlot.slotWidth - leadingWidth,
            textInset: math.max(0, firstSlot.textInset - leadingWidth),
            groupGap: firstSlot.groupGap,
          );
          effectiveWords = adjustedWords;
          inlinePrefix = _KottaRowPrefix(
            kotta: leadingKotta,
            width: leadingWidth,
          );
        }
      }

      if (effectiveWords.isNotEmpty && effectiveWords.last.groupGap != 0) {
        effectiveWords = List<_KottaWordLayout>.from(effectiveWords);
        final last = effectiveWords.last;
        effectiveWords[effectiveWords.length - 1] = _KottaWordLayout(
          wordIndex: last.wordIndex,
          slotWidth: last.slotWidth,
          textInset: last.textInset,
        );
      }
      final double contentWidth = effectiveWords.fold<double>(
        0,
        (double sum, _KottaWordLayout slot) =>
            sum + slot.slotWidth + slot.groupGap,
      );
      final double hyphenWidth = row.endHyphen
          ? _measureHyphenDisplayWidth(
              line.words[row.words.last.wordIndex],
              fontSize,
              measure,
            )
          : 0;
      resolvedRows.add(
        _KottaRowLayout(
          words: effectiveWords,
          width: prefix.width + inlinePrefix.width + contentWidth + hyphenWidth,
          centeringWidth: row.centeringWidth,
          prefix: prefix,
          inlinePrefix: inlinePrefix,
          endHyphen: row.endHyphen,
          staffLineCount: initialStaffLineCount,
        ),
      );
    }

    return resolvedRows;
  }

  String _leadingInlineKottaPrefix(String kotta) {
    final List<String> commands = _parseKottaCommands(kotta);
    if (commands.isEmpty) {
      return '';
    }

    final StringBuffer prefix = StringBuffer();
    bool sawVisiblePrefix = false;
    for (final String command in commands) {
      final String kind = command[0];
      if (_isLeadingKottaSetupCommand(kind)) {
        prefix.write(command);
        continue;
      }
      if (_isLeadingKottaVisiblePrefixCommand(kind)) {
        sawVisiblePrefix = true;
        prefix.write(command);
        continue;
      }
      break;
    }
    return sawVisiblePrefix ? prefix.toString() : '';
  }

  bool _isLeadingKottaSetupCommand(String kind) {
    return kind == '-' ||
        kind == 'r' ||
        kind == 'R' ||
        kind == 'm' ||
        kind == '[' ||
        kind == ']' ||
        kind == '(' ||
        kind == ')';
  }

  bool _isLeadingKottaVisiblePrefixCommand(String kind) {
    return kind == 'k' ||
        kind == 'e' ||
        kind == 'E' ||
        kind == 'u' ||
        kind == 'U';
  }

  List<_KottaRowPrefix> _resolveKottaRowPrefixes(
    List<_KottaRowLayout> rows,
    _RenderLine line,
    double lineGap,
  ) {
    final List<_KottaRowPrefix> prefixes = <_KottaRowPrefix>[];
    final _KottaDrawState state = _KottaDrawState();
    if (rows.isNotEmpty && rows.first.prefix.kotta.isNotEmpty) {
      _kottaRawWidth(rows.first.prefix.kotta, lineGap, state);
    }

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      prefixes.add(
        rowIndex == 0
            ? rows.first.prefix
            : _kottaRowPrefixForState(state, lineGap),
      );

      for (final _KottaWordLayout slot in rows[rowIndex].words) {
        final String kotta = (line.words[slot.wordIndex].kotta ?? '').trim();
        if (kotta.isNotEmpty) {
          _kottaRawWidth(kotta, lineGap, state);
        }
      }
    }

    return prefixes;
  }

  void _advanceKottaStateForLine(
    _RenderLine line,
    double lineGap,
    _KottaDrawState state,
  ) {
    state.resetTransient();
    for (final _WordToken word in line.words) {
      final String kotta = (word.kotta ?? '').trim();
      if (kotta.isNotEmpty) {
        _kottaRawWidth(kotta, lineGap, state);
      }
    }
  }

  List<_TextRowLayout> _buildTextRows(
    _RenderLine line,
    double fontSize,
    double maxWidth, {
    bool preferPreferredBreaks = true,
  }) {
    final String cacheKey = _textRowsCacheKey(
      line,
      fontSize,
      maxWidth,
      preferPreferredBreaks,
    );
    final List<_TextRowLayout>? cached = _textRowsCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    if (line.words.isEmpty) {
      return const <_TextRowLayout>[];
    }

    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    final double wrapWidth = math.max(8.0, maxWidth);
    final double continuationIndent = globals.hCenter
        ? 0
        : _textContinuationIndent(fontSize, measure);
    final List<_TextRowLayout> rows = <_TextRowLayout>[];
    final List<int> currentWordIndices = <int>[];
    final List<int> pendingWordIndices = <int>[];
    final List<double> slotWidths = List<double>.generate(
      line.words.length,
      (int index) =>
          _measureWordDisplayWidth(line.words[index], fontSize, measure),
      growable: false,
    );
    double currentWidth = 0;
    double pendingWordWidth = 0;

    for (int i = 0; i < line.words.length; i++) {
      final _WordToken w = line.words[i];
      final double slotWidth = slotWidths[i];
      pendingWordIndices.add(i);
      pendingWordWidth += slotWidth;

      final bool endsWord =
          w.breakAfter || w.softHyphenAfter || i == line.words.length - 1;
      if (!endsWord) {
        continue;
      }

      final double currentRowLimit = rows.isEmpty
          ? wrapWidth
          : math.max(8.0, wrapWidth - continuationIndent);

      if (currentWordIndices.isNotEmpty &&
          (currentWidth + pendingWordWidth) > currentRowLimit) {
        final List<int> combinedWordIndices = <int>[
          ...currentWordIndices,
          ...pendingWordIndices,
        ];

        int breakWordIndex = combinedWordIndices.last;
        int? preferredBreakIndex;
        if (preferPreferredBreaks) {
          for (int j = combinedWordIndices.length - 1; j >= 0; j--) {
            final int candidateIndex = combinedWordIndices[j];
            if (!line.words[candidateIndex].preferredBreakAfter) {
              continue;
            }

            double headWidth = 0;
            for (int k = 0; k <= j; k++) {
              headWidth += slotWidths[combinedWordIndices[k]];
            }
            double tailWidth = 0;
            for (int k = j + 1; k < combinedWordIndices.length; k++) {
              tailWidth += slotWidths[combinedWordIndices[k]];
            }

            if (headWidth <= currentRowLimit && tailWidth <= currentRowLimit) {
              preferredBreakIndex = candidateIndex;
              break;
            }
          }
        }
        if (preferredBreakIndex != null) {
          breakWordIndex = preferredBreakIndex;
        } else {
          for (int j = combinedWordIndices.length - 1; j >= 0; j--) {
            final int candidateIndex = combinedWordIndices[j];
            final _WordToken candidate = line.words[candidateIndex];
            final bool isRegularBreak =
                candidate.breakAfter || candidate.softHyphenAfter;
            if (!isRegularBreak && j != combinedWordIndices.length - 1) {
              continue;
            }

            double headWidth = 0;
            for (int k = 0; k <= j; k++) {
              headWidth += slotWidths[combinedWordIndices[k]];
            }
            double tailWidth = 0;
            for (int k = j + 1; k < combinedWordIndices.length; k++) {
              tailWidth += slotWidths[combinedWordIndices[k]];
            }

            if (headWidth <= currentRowLimit && tailWidth <= currentRowLimit) {
              breakWordIndex = candidateIndex;
              break;
            }
          }
        }

        // No preferred or regular break can place the final pending word on
        // the current row without overflowing. Instead of packing every word
        // onto one overflowing row, push the final word onto the next line so
        // the current row stays within its limit.
        if (breakWordIndex == combinedWordIndices.last &&
            combinedWordIndices.length >= 2) {
          breakWordIndex = combinedWordIndices[combinedWordIndices.length - 2];
        }

        final int breakPos = combinedWordIndices.indexOf(breakWordIndex);
        final List<int> rowWordIndices = List<int>.from(
          combinedWordIndices.take(breakPos + 1),
        );
        final List<int> carryWordIndices = List<int>.from(
          combinedWordIndices.skip(breakPos + 1),
        );

        double rowBaseWidth = 0;
        for (final int idx in rowWordIndices) {
          rowBaseWidth += slotWidths[idx];
        }
        double carryWordsWidth = 0;
        for (final int idx in carryWordIndices) {
          carryWordsWidth += slotWidths[idx];
        }

        final int lastWordIndex = breakWordIndex;
        final bool endHyphen = line.words[lastWordIndex].softHyphenAfter;
        final double hyphenWidth = endHyphen
            ? _measureHyphenDisplayWidth(
                line.words[lastWordIndex],
                fontSize,
                measure,
              )
            : 0;
        rows.add(
          _TextRowLayout(
            wordIndices: rowWordIndices,
            width: rowBaseWidth + hyphenWidth,
            indentWidth: rows.isEmpty ? 0 : continuationIndent,
            endHyphen: endHyphen,
          ),
        );
        currentWordIndices
          ..clear()
          ..addAll(carryWordIndices);
        currentWidth = carryWordsWidth;
        pendingWordIndices.clear();
        pendingWordWidth = 0;
        continue;
      }

      currentWordIndices.addAll(pendingWordIndices);
      currentWidth += pendingWordWidth;
      pendingWordIndices.clear();
      pendingWordWidth = 0;
    }

    if (currentWordIndices.isNotEmpty) {
      rows.add(
        _TextRowLayout(
          wordIndices: List<int>.from(currentWordIndices),
          width: currentWidth,
          indentWidth: rows.isEmpty ? 0 : continuationIndent,
        ),
      );
    }

    _textRowsCache[cacheKey] = rows;
    while (_textRowsCache.length > _layoutCacheLimit) {
      _textRowsCache.remove(_textRowsCache.keys.first);
    }
    return rows;
  }

  double _textContinuationIndent(double fontSize, TextPainter measure) {
    if (globals.leftIndent <= 0) {
      return 0;
    }

    measure.text = TextSpan(
      text: ' ' * globals.leftIndent,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: globals.boldText ? FontWeight.bold : FontWeight.normal,
      ),
    );
    measure.layout();
    return measure.width;
  }

  double _measureWordDisplayWidth(
    _WordToken word,
    double fontSize,
    TextPainter measure,
  ) {
    final String display = _wordLayoutDisplay(word, fontSize, measure);
    final String cacheKey = [
      'w',
      display,
      _effectiveWordFontSize(word, fontSize).toStringAsFixed(3),
      globals.boldText || word.bold,
      word.italic,
    ].join('|');
    final double? cached = _wordWidthCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    measure.text = TextSpan(
      text: display,
      style: TextStyle(
        fontSize: _effectiveWordFontSize(word, fontSize),
        fontWeight: (globals.boldText || word.bold)
            ? FontWeight.bold
            : FontWeight.normal,
        fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
    measure.layout();
    final double width = measure.width;
    _wordWidthCache[cacheKey] = width;
    while (_wordWidthCache.length > _wordMeasureCacheLimit) {
      _wordWidthCache.remove(_wordWidthCache.keys.first);
    }
    return width;
  }

  String _wordLayoutDisplay(
    _WordToken word,
    double fontSize,
    TextPainter measure,
  ) {
    String display = word.text + (word.spaceAfter ? ' ' : '');
    final String chordText = (word.chord ?? '').trim();
    if (!globals.useAkkord ||
        !settings.receiverUseAkkord ||
        chordText.isEmpty) {
      return display;
    }

    final TextStyle textStyle = TextStyle(
      fontSize: _effectiveWordFontSize(word, fontSize),
      fontWeight: (globals.boldText || word.bold)
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
    );
    measure.text = TextSpan(text: display, style: textStyle);
    measure.layout();
    final double textWidth = measure.width;
    final double chordWidth = _chordLayout(
      chordText,
      TextStyle(
        color: globals.txtColor,
        fontSize: fontSize * (globals.akkordArany / 100.0),
      ),
    ).width;
    if (textWidth + 0.5 >= chordWidth) {
      return display;
    }

    measure.text = TextSpan(text: '\u00A0', style: textStyle);
    measure.layout();
    final double spaceWidth = math.max(0.5, measure.width);
    final int spaceCount = ((chordWidth - textWidth) / spaceWidth).ceil();
    display += List<String>.filled(spaceCount, '\u00A0').join();
    measure.text = TextSpan(text: display, style: textStyle);
    measure.layout();
    while (measure.width + 0.5 < chordWidth) {
      display += '\u00A0';
      measure.text = TextSpan(text: display, style: textStyle);
      measure.layout();
    }
    return display;
  }

  double _measureHyphenDisplayWidth(
    _WordToken word,
    double fontSize,
    TextPainter measure,
  ) {
    final String cacheKey = [
      'h',
      _effectiveWordFontSize(word, fontSize).toStringAsFixed(3),
      globals.boldText || word.bold,
      word.italic,
    ].join('|');
    final double? cached = _wordWidthCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    measure.text = TextSpan(
      text: '-',
      style: TextStyle(
        fontSize: _effectiveWordFontSize(word, fontSize),
        fontWeight: (globals.boldText || word.bold)
            ? FontWeight.bold
            : FontWeight.normal,
        fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
    measure.layout();
    final double width = measure.width;
    _wordWidthCache[cacheKey] = width;
    while (_wordWidthCache.length > _wordMeasureCacheLimit) {
      _wordWidthCache.remove(_wordWidthCache.keys.first);
    }
    return width;
  }

  double _effectiveWordFontSize(_WordToken word, double baseFontSize) {
    return baseFontSize * word.fontScale.clamp(0.1, 1.0);
  }

  String _textRowsCacheKey(
    _RenderLine line,
    double fontSize,
    double maxWidth,
    bool preferPreferredBreaks,
  ) {
    return [
      'text',
      fontSize.toStringAsFixed(2),
      maxWidth.toStringAsFixed(2),
      preferPreferredBreaks,
      globals.hCenter,
      globals.leftIndent,
      globals.boldText,
      globals.useAkkord,
      globals.akkordArany,
      globals.akkordNotation,
      globals.akkordOptionalSeventh,
      globals.akkordMinorAsDash,
      settings.receiverUseAkkord,
      for (final _WordToken word in line.words)
        [
          word.text,
          word.chord,
          word.bold,
          word.italic,
          word.spaceAfter,
          word.breakAfter,
          word.preferredBreakAfter,
          word.softHyphenAfter,
          word.fontScale.toStringAsFixed(3),
        ].join(':'),
    ].join('|');
  }

  String _kottaRowsCacheKey(
    _RenderLine line,
    double fontSize,
    double maxWidth,
    _KottaDrawState? inheritedState,
  ) {
    return [
      'kotta',
      fontSize.toStringAsFixed(2),
      maxWidth.toStringAsFixed(2),
      globals.hCenter,
      globals.leftIndent,
      globals.boldText,
      globals.kottaArany,
      inheritedState == null ? '' : _kottaStateKey(inheritedState),
      for (final _WordToken word in line.words)
        [
          word.text,
          word.bold,
          word.italic,
          word.spaceAfter,
          word.breakAfter,
          word.preferredBreakAfter,
          word.softHyphenAfter,
          word.fontScale.toStringAsFixed(3),
          word.kotta ?? '',
        ].join(':'),
    ].join('|');
  }

  String _measureTextHeightCacheKey(
    Size size,
    TextFrame frame,
    double fontSize,
    bool preferPreferredBreaks,
  ) {
    return [
      'height',
      size.width.toStringAsFixed(2),
      size.height.toStringAsFixed(2),
      fontSize.toStringAsFixed(2),
      preferPreferredBreaks,
      globals.fontSize,
      globals.titleSize,
      globals.leftIndent,
      globals.spacing100,
      globals.hCenter,
      globals.useAkkord,
      globals.useKotta,
      globals.kottaArany,
      globals.hideTitle,
      allowLineWrapping,
      editorCursorOverlay != null,
      globals.akkordNotation,
      globals.akkordOptionalSeventh,
      globals.akkordMinorAsDash,
      settings.receiverUseAkkord,
      settings.receiverUseKotta,
      frame.record.title,
      ...frame.record.lines,
    ].join('|');
  }

  String _preparedTextLayoutCacheKey(
    Size size,
    TextFrame frame,
    double fontSize,
    bool preferPreferredBreaks,
  ) {
    return [
      'prepared',
      size.width.toStringAsFixed(2),
      fontSize.toStringAsFixed(2),
      preferPreferredBreaks,
      globals.titleSize,
      globals.leftIndent,
      globals.hCenter,
      globals.boldText,
      globals.useAkkord,
      globals.useKotta,
      globals.hideTitle,
      allowLineWrapping,
      editorCursorOverlay != null,
      globals.kottaArany,
      globals.akkordArany,
      globals.akkordNotation,
      globals.akkordOptionalSeventh,
      globals.akkordMinorAsDash,
      settings.receiverUseAkkord,
      settings.receiverUseKotta,
      frame.record.title,
      ...frame.record.lines,
    ].join('|');
  }

  String _kottaStateKey(_KottaDrawState state) {
    return [
      state.kulcs,
      state.elojegy,
      state.modosito,
      state.ritmus,
      state.pontozott,
      state.tomor,
      state.gerenda,
      state.szaaratlan,
      state.agogika,
      state.staffLineCount,
      state.lastSetupWidth,
      state.slurType,
      state.slurNext,
      state.triLe,
      state.triTipus,
      state.triPos.length,
      state.beamStems.length,
    ].join('|');
  }

  double _kottaRawWidth(String kotta, double lineGap, _KottaDrawState state) {
    return _measureKotta(kotta, lineGap, state).width;
  }

  ({double width, double textInset, double compactGap}) _measureKotta(
    String kotta,
    double lineGap,
    _KottaDrawState state,
  ) {
    double width = 0;
    double textInset = 0;
    double compactGap = 0;
    for (final String cmd in _parseKottaCommands(kotta)) {
      final double commandWidth = _kottaWidthOf(cmd, lineGap, state);
      width = _kottaFloat(width + commandWidth);
      if (commandWidth > 0) {
        compactGap =
            '123'.contains(cmd[0]) &&
                state.tomor &&
                'lbs12486'.contains(state.ritmus)
            ? _kottaHeadWidth(state.ritmus, lineGap)
            : 0;
      }
      if (_isLeadingKottaVisiblePrefixCommand(cmd[0])) {
        // Android's mPostX: lyrics follow the last clef, signature or meter.
        textInset = width;
      }
    }
    if (textInset > 0) state.lastSetupWidth = textInset;
    return (width: width, textInset: textInset, compactGap: compactGap);
  }

  double _drawSimpleKotta(
    Canvas canvas,
    String kotta,
    double x,
    double textTopY,
    double wordWidth,
    double fontSize, {
    _KottaDrawState? state,
    double? lineGapOverride,
    bool drawStaff = true,
  }) {
    final List<String> cmds = _parseKottaCommands(kotta);
    if (cmds.isEmpty) {
      return x;
    }

    final double lineGap = lineGapOverride ?? _kottaLineGap(fontSize);
    final double staffHeight = _kottaStaffHeight(lineGap);
    final double top = textTopY - staffHeight - _kottaStaffToTextGap(lineGap);
    const double scale = 1.0;
    final double startX = x;
    final _KottaDrawState drawState = state ?? _KottaDrawState();

    if (state == null) drawState.rowStartX = x;
    drawState.slurLeftX ??= x;
    double cx = startX;
    for (final String c in cmds) {
      final _KottaDrawState widthState = drawState.copy();
      final double cw = _kottaWidthOf(c, lineGap, widthState) * scale;
      drawState.currentX = cx;
      _drawKottaCommand(canvas, c, drawState, cx, top, lineGap, scale);
      cx = _kottaFloat(cx + cw);
      drawState.elojegy = widthState.elojegy;
      drawState.modosito = widthState.modosito;
    }
    drawState.currentX = cx;
    if (state == null) {
      _endKottaRow(
        canvas,
        drawState,
        top,
        lineGap,
        math.max(cx, x + wordWidth),
        drawStaff: drawStaff,
      );
    }
    return cx;
  }

  int _kottaLineWidth(double lineGap) =>
      (1 + _kcZaszloSzel * lineGap / (_kcHang4V2a - _kcHang4V2f)).toInt();

  void _endKottaRow(
    Canvas canvas,
    _KottaDrawState state,
    double top,
    double lineGap,
    double endX, {
    bool drawStaff = true,
  }) {
    state.currentX = math.max(state.currentX, endX);
    _endBeam(canvas, state, lineGap);
    _endTuplet(canvas, state, lineGap);
    _endSlur(canvas, state, lineGap);
    if (!drawStaff) return;
    for (int i = 0; i < state.staffLineCount; i++) {
      final double y = top + (4 - i) * lineGap;
      for (int j = 0; j < _kottaLineWidth(lineGap); j++) {
        canvas.drawLine(
          Offset(state.rowStartX, y + j),
          Offset(state.currentX, y + j),
          Paint()..color = _kottaInkColor,
        );
      }
    }
  }

  List<String> _parseKottaCommands(String kotta) {
    final List<String> out = <String>[];
    for (int i = 0; i + 1 < kotta.length; i += 2) {
      out.add(kotta.substring(i, i + 2));
    }
    return out;
  }

  double _kottaWidthOf(String cmd, double lineGap, _KottaDrawState state) {
    final String c1 = cmd[0];
    final String c2 = cmd[1];
    final double minWidth = _kottaMinWidth(lineGap);
    final double staffSpan = lineGap * 4.0;

    if (c1 == 'r' || c1 == 'R') {
      if (c2 == 't') {
        state.tomor = c1 == 'R';
      } else {
        state.ritmus = c2;
        state.pontozott = c1 == 'R';
      }
      return 0;
    }
    if (c1 == '-') {
      state.staffLineCount = int.tryParse(c2)?.clamp(0, 5).toInt() ?? 5;
      return 0;
    }
    if (c1 == 'm') {
      state.modosito = c2;
      return 0;
    }
    if (c1 == 'a') {
      state.agogika = c2;
      return 0;
    }
    if (c1 == 'k') {
      state.kulcs = c2;
      switch (c2) {
        case 'G':
          return minWidth +
              _kcGkulcsW * staffSpan / (_kcGkulcsV1 - _kcGkulcsV5);
        case 'F':
          return minWidth +
              _kcFkulcsW * staffSpan / (_kcFkulcsV1 - _kcFkulcsV5);
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
          return minWidth +
              _kcCkulcsW * staffSpan / (_kcCkulcsV1 - _kcCkulcsV5);
        default:
          if ('abcdefghi'.contains(c2)) {
            return minWidth +
                _kcDkulcsW * (lineGap) / (_kcDkulcsV1 - _kcDkulcsV2);
          }
          return 0;
      }
    }
    if (c1 == 'e') {
      state.elojegy = -((int.tryParse(c2) ?? 0).clamp(0, 7));
      return (1 + (int.tryParse(c2) ?? 0)) *
          _kcBeW *
          lineGap /
          (_kcBeV2a - _kcBeV2f) /
          1.5;
    }
    if (c1 == 'E') {
      state.elojegy = (int.tryParse(c2) ?? 0).clamp(0, 7);
      return (1 + (int.tryParse(c2) ?? 0)) *
          _kcKeresztW *
          lineGap /
          (_kcKeresztV2a - _kcKeresztV2f) /
          1.5;
    }
    if (c1 == 'u' || c1 == 'U') {
      return minWidth + _kcU22W * staffSpan / _kcU22H;
    }
    if (c1 == 's' || c1 == 'S') {
      state.modosito = ' ';
      switch (c2) {
        case '1':
          return (c1 == 'S' ? 1.5 * minWidth : minWidth) +
              _kcSzunet1W * lineGap / _kcSzunet1V;
        case '2':
          return (c1 == 'S' ? 1.5 * minWidth : minWidth) +
              _kcSzunet2W * lineGap / _kcSzunet2V;
        case '4':
          return (c1 == 'S' ? 1.5 * minWidth : minWidth) +
              _kcSzunet4W * (2 * lineGap) / (_kcSzunet4V2 - _kcSzunet4V4);
        case '8':
          return (c1 == 'S' ? 1.5 * minWidth : minWidth) +
              _kcSzunet8W * (2 * lineGap) / (_kcSzunet8V2 - _kcSzunet8V4);
        case '6':
          return (c1 == 'S' ? 1.5 * minWidth : minWidth) +
              _kcSzunet16W * (2 * lineGap) / (_kcSzunet16V2 - _kcSzunet16V4);
        default:
          return 0;
      }
    }
    if (c1 == '1' || c1 == '2' || c1 == '3') {
      double w = state.tomor ? 0.0 : minWidth;
      if (state.modosito != ' ') {
        switch (state.modosito) {
          case '0':
            w += 1.25 * _kcFeloldoW * lineGap / (_kcFeloldoV2a - _kcFeloldoV2f);
            break;
          case 'k':
            w += 1.25 * _kcKeresztW * lineGap / (_kcKeresztV2a - _kcKeresztV2f);
            break;
          case 'K':
            w +=
                1.25 *
                _kcKettosKeresztW *
                lineGap /
                (_kcKettosKeresztV2a - _kcKettosKeresztV2f);
            break;
          case 'b':
            w += 1.25 * _kcBeW * lineGap / (_kcBeV2a - _kcBeV2f);
            break;
          case 'B':
            w += 1.25 * _kcBeBeW * lineGap / (_kcBeBeV2a - _kcBeBeV2f);
            break;
        }
      }
      w = _kottaFloat(w + _kottaHeadWidth(state.ritmus, lineGap));
      if (state.pontozott) {
        w = _kottaFloat(w + (state.tomor ? 0.0 : minWidth / 8.0));
        w = _kottaFloat(w + _kottaFloat(_kcPontW * lineGap / _kcPontV));
      }
      state.modosito = ' ';
      return w;
    }
    if (c1 == '|') {
      if (c2 == ':' || c2 == '<' || c2 == '>') {
        return minWidth * (c2 == ':' ? 3.0 : 2.0);
      }
      return minWidth;
    }
    return 0;
  }

  double _kottaMinWidth(double lineGap) {
    return _kottaFloat(_kcHang4W * lineGap / (_kcHang4V2a - _kcHang4V2f));
  }

  double _kottaHeadWidth(String rhythm, double lineGap) {
    final (width, lower, upper) = switch (rhythm) {
      'l' => (_kcHang0W, _kcHang0V2a, _kcHang0V2f),
      'b' => (_kcHangBrevis1W, _kcHangBrevis1V2a, _kcHangBrevis1V2f),
      's' => (_kcHangBrevis2W, _kcHangBrevis2V2a, _kcHangBrevis2V2f),
      '1' => (_kcHang1W, _kcHang1V2a, _kcHang1V2f),
      '2' => (_kcHang2W, _kcHang2V2a, _kcHang2V2f),
      _ => (_kcHang4W, _kcHang4V2a, _kcHang4V2f),
    };
    return _kottaFloat(width * lineGap / (lower - upper));
  }

  // Exact head adjacency in Android depends on single-precision arithmetic.
  static final Float32List _kottaFloatBuffer = Float32List(1);
  static double _kottaFloat(double value) =>
      (_kottaFloatBuffer..[0] = value)[0];

  _KottaRowPrefix _kottaRowPrefixForState(
    _KottaDrawState state,
    double lineGap,
  ) {
    final StringBuffer sb = StringBuffer();
    if (state.kulcs != ' ') {
      sb.write('k');
      sb.write(state.kulcs);
    }
    if (state.elojegy < 0) {
      sb.write('e');
      sb.write((-state.elojegy).clamp(0, 7));
    } else if (state.elojegy > 0) {
      sb.write('E');
      sb.write(state.elojegy.clamp(0, 7));
    }
    final String prefixKotta = sb.toString();
    if (prefixKotta.isEmpty) {
      return const _KottaRowPrefix.empty();
    }
    final double prefixWidth = _kottaRawWidth(
      prefixKotta,
      lineGap,
      _KottaDrawState(),
    );
    return _KottaRowPrefix(kotta: prefixKotta, width: prefixWidth);
  }

  void _drawKottaCommand(
    Canvas canvas,
    String cmd,
    _KottaDrawState state,
    double x,
    double top,
    double lineGap,
    double scale, {
    FilterQuality clefFilterQuality = FilterQuality.none,
  }) {
    final String c1 = cmd[0];
    final String c2 = cmd[1];
    if (c1 == '[') {
      if (c2 == '0') {
        state.szaaratlan = true;
      } else if (c2 == '1') {
        state.szaaratlan = false;
      } else if (c2 == '3' || c2 == '5') {
        state.triTipus = c2;
        state.triPos.clear();
      } else {
        state.gerenda = true;
      }
      return;
    }
    if (c1 == ']') {
      _endBeam(canvas, state, lineGap);
      state.gerenda = false;
      if (c2 == '3' || c2 == '5') {
        _endTuplet(canvas, state, lineGap);
      }
      return;
    }
    if (c1 == '(') {
      state.slurNext = c2;
      return;
    }
    if (c1 == ')') {
      _endSlur(canvas, state, lineGap, forcedType: c2);
      return;
    }
    if (c1 == '-') {
      state.staffLineCount = int.tryParse(c2)?.clamp(0, 5).toInt() ?? 5;
      return;
    }

    if (c1 == 'k') {
      _endBeam(canvas, state, lineGap);
      state.kulcs = c2;
      final String? clefName = switch (c2) {
        'G' => 'gkulcs',
        'F' => 'fkulcs',
        '1' || '2' || '3' || '4' || '5' => 'ckulcs',
        'a' || 'b' || 'c' || 'd' || 'e' || 'f' || 'g' || 'h' || 'i' => 'dkulcs',
        _ => null,
      };
      if (clefName != null) {
        double w = _kcGkulcsW;
        double h = _kcGkulcsH;
        double v1 = _kcGkulcsV1;
        double v5 = _kcGkulcsV5;
        double y0 = _linePos(top, lineGap, 3);
        if (c2 == 'F') {
          w = _kcFkulcsW;
          h = _kcFkulcsH;
          v1 = _kcFkulcsV1;
          v5 = _kcFkulcsV5;
        } else if ('12345'.contains(c2)) {
          w = _kcCkulcsW;
          h = _kcCkulcsH;
          v1 = _kcCkulcsV1;
          v5 = _kcCkulcsV5;
          y0 = _linePos(top, lineGap, 5 - (int.parse(c2) - 1));
        } else if ('abcdefghi'.contains(c2)) {
          w = _kcDkulcsW;
          h = _kcDkulcsH;
          v1 = _kcDkulcsV1;
          v5 = _kcDkulcsV2;
          y0 =
              _linePos(top, lineGap, 7) -
              lineGap * 0.5 * (1 + ('abcdefghi'.indexOf(c2)));
        }
        final double rat = 'abcdefghi'.contains(c2)
            ? lineGap / (_kcDkulcsV1 - _kcDkulcsV2)
            : (lineGap * 4.0) / (v1 - v5);
        final double y1 = y0 - v5 * rat;
        final double x2 = x + w * rat;
        final double y2 = y1 + h * rat;
        _drawKottaAsset(
          canvas,
          clefName,
          Rect.fromLTRB(x, y1, x2, y2),
          filterQuality: clefFilterQuality,
        );
      }
      return;
    }
    if (c1 == 'e' || c1 == 'E') {
      _endBeam(canvas, state, lineGap);
      final bool flat = c1 == 'e';
      final int n = int.tryParse(c2) ?? 0;
      final int count = n.clamp(0, 7);
      final String sym = flat ? 'be' : 'kereszt';
      final String kulcs = state.kulcs;
      final String pattern = flat
          ? switch (kulcs) {
              'G' => '3-4=2=4-2-3=1=',
              'F' => '2-3=1=3-1-2=0=',
              '1' => '4-2-3=1=3-1-2=',
              '2' => '5-3-4=2=4-2-3=',
              '4' => '3=5-3-4=2=4-2-',
              '5' => '4=2=4-2-3=1=3-',
              _ => '2=4-2-3=1=3-1-',
            }
          : switch (kulcs) {
              'G' => '5-3=5=4-2=4=3-',
              'F' => '4-2=4=3-5-3=5=',
              '1' => '2=1-3-1=3=2-4-',
              '2' => '3=2-4-2=4=3-5-',
              '4' => '5=4-2=4=3-5-3=',
              '5' => '3-5-3=5=4-2=4=',
              _ => '4=3-5-3=5=4-2=',
            };
      final double rat = flat
          ? lineGap / (_kcBeV2a - _kcBeV2f)
          : lineGap / (_kcKeresztV2a - _kcKeresztV2f);
      final double w = flat ? _kcBeW : _kcKeresztW;
      final double h = flat ? _kcBeH : _kcKeresztH;
      final double v1 = flat ? _kcBeV1 : _kcKeresztV1;
      final double v2a = flat ? _kcBeV2a : _kcKeresztV2a;

      double x1 = x;
      int p = 0;
      for (int i = 0; i < count && p + 1 < pattern.length; i++) {
        final int? d = int.tryParse(pattern[p]);
        final String t2 = pattern[p + 1];
        p += 2;
        if (d == null) {
          continue;
        }
        final int lineIx = 7 - (d - 1);
        double y1 = _linePos(top, lineGap, lineIx);
        y1 -= (t2 == '-') ? v1 * rat : v2a * rat;
        final double x2 = x1 + w * rat;
        final double y2 = y1 + h * rat;
        _drawKottaAsset(canvas, sym, Rect.fromLTRB(x1, y1, x2, y2));
        x1 += w * rat / 1.5;
      }
      return;
    }
    if (c1 == 'u' || c1 == 'U') {
      final String? meter = switch ('$c1$c2') {
        'u2' => 'u24',
        'u3' => 'u34',
        'u4' => 'u44',
        'u5' => 'u54',
        'u6' => 'u64',
        'U2' => 'u22',
        'U3' => 'u32',
        'U4' => 'u44',
        'U5' => 'u54',
        'U6' => 'u68',
        'u8' => 'u38',
        'U8' => 'u38',
        _ => null,
      };
      if (meter != null) {
        _drawKottaAsset(
          canvas,
          meter,
          Rect.fromLTWH(x, top, _kcU22W * lineGap * 4 / _kcU22H, lineGap * 4),
        );
      }
      return;
    }
    if (c1 == 'm') {
      state.modosito = c2;
      return;
    }
    if (c1 == 'a') {
      state.agogika = c2;
      return;
    }
    if (c1 == 'r' || c1 == 'R') {
      if (c2 == 't') {
        state.tomor = c1 == 'R';
      } else {
        state.ritmus = c2;
        state.pontozott = c1 == 'R';
      }
      return;
    }
    if (c1 == '1' || c1 == '2' || c1 == '3') {
      final _KottaNotePos? pos = _notePos(c1, c2);
      if (pos == null) {
        return;
      }
      final int l1 = pos.l1;
      final int l2 = pos.l2;
      final double minWidth = _kottaMinWidth(lineGap);
      final double mw = state.tomor ? 0.0 : minWidth;
      double x1 = _kottaFloat(x + mw * 0.5);
      if (state.modosito != ' ') {
        final String? modName = switch (state.modosito) {
          '0' => 'feloldo',
          'k' => 'kereszt',
          'K' => 'kettoskereszt',
          'b' => 'be',
          'B' => 'bebe',
          _ => null,
        };
        if (modName == null) return;
        double mw0 = _kcFeloldoW,
            mh0 = _kcFeloldoH,
            mvv = _kcFeloldoV1,
            mva = _kcFeloldoV2a,
            mvf = _kcFeloldoV2f;
        if (state.modosito == 'k') {
          mw0 = _kcKeresztW;
          mh0 = _kcKeresztH;
          mvv = _kcKeresztV1;
          mva = _kcKeresztV2a;
          mvf = _kcKeresztV2f;
        } else if (state.modosito == 'K') {
          mw0 = _kcKettosKeresztW;
          mh0 = _kcKettosKeresztH;
          mvv = _kcKettosKeresztV1;
          mva = _kcKettosKeresztV2a;
          mvf = _kcKettosKeresztV2f;
        } else if (state.modosito == 'b') {
          mw0 = _kcBeW;
          mh0 = _kcBeH;
          mvv = _kcBeV1;
          mva = _kcBeV2a;
          mvf = _kcBeV2f;
        } else if (state.modosito == 'B') {
          mw0 = _kcBeBeW;
          mh0 = _kcBeBeH;
          mvv = _kcBeBeV1;
          mva = _kcBeBeV2a;
          mvf = _kcBeBeV2f;
        }
        final double rat = lineGap / (mva - mvf);
        final double y1m =
            _linePos(top, lineGap, l1) - ((l1 == l2) ? mvv : mva) * rat;
        final double x2m = x1 + mw0 * rat;
        final double y2m = y1m + mh0 * rat;
        _drawKottaAsset(canvas, modName, Rect.fromLTRB(x1, y1m, x2m, y2m));
        x1 = x2m + mw0 * rat * 0.25;
      }

      String noteName = switch (state.ritmus) {
        'l' => 'hang0',
        'b' => 'hangbrevis1',
        's' => 'hangbrevis2',
        '1' => 'hang1',
        '2' => 'hang2fej',
        _ => 'hang4fej',
      };
      if (!'lbs12486'.contains(state.ritmus)) return;
      double nw = _kcHang4W,
          nh = _kcHang4H,
          nvv = _kcHang4V1,
          nva = _kcHang4V2a,
          nvf = _kcHang4V2f;
      if (state.ritmus == 'l') {
        nw = _kcHang0W;
        nh = _kcHang0H;
        nvv = _kcHang0V1;
        nva = _kcHang0V2a;
        nvf = _kcHang0V2f;
      } else if (state.ritmus == 'b') {
        nw = _kcHangBrevis1W;
        nh = _kcHangBrevis1H;
        nvv = _kcHangBrevis1V1;
        nva = _kcHangBrevis1V2a;
        nvf = _kcHangBrevis1V2f;
      } else if (state.ritmus == 's') {
        nw = _kcHangBrevis2W;
        nh = _kcHangBrevis2H;
        nvv = _kcHangBrevis2V1;
        nva = _kcHangBrevis2V2a;
        nvf = _kcHangBrevis2V2f;
      } else if (state.ritmus == '1') {
        nw = _kcHang1W;
        nh = _kcHang1H;
        nvv = _kcHang1V1;
        nva = _kcHang1V2a;
        nvf = _kcHang1V2f;
      } else if (state.ritmus == '2') {
        nw = _kcHang2W;
        nh = _kcHang2H;
        nvv = _kcHang2V1;
        nva = _kcHang2V2a;
        nvf = _kcHang2V2f;
      }
      final double nrat = _kottaFloat(lineGap / (nva - nvf));
      final double ny1 =
          _linePos(top, lineGap, l1) - ((l1 == l2) ? nvv : nva) * nrat;
      final double nx2 = _kottaFloat(x1 + _kottaFloat(nw * nrat));
      final double ny2 = ny1 + nh * nrat;
      final double nx = (x1 + nx2) / 2.0;
      final double cy = (ny1 + ny2) / 2.0;
      final double noteW = (nx2 - x1);

      _drawKottaAsset(canvas, noteName, Rect.fromLTRB(x1, ny1, nx2, ny2));
      final bool stemDown = c2.toUpperCase() == c2;
      _trackTupletPoint(state, Offset(nx, cy), stemDown, lineGap, noteW);
      if (state.gerenda &&
          (state.szaaratlan || (state.ritmus != '8' && state.ritmus != '6'))) {
        _endBeam(canvas, state, lineGap);
      }

      if (!state.szaaratlan &&
          (state.ritmus == '2' ||
              state.ritmus == '4' ||
              state.ritmus == '8' ||
              state.ritmus == '6')) {
        final double stemWidth = _kcZaszloSzel * nrat;
        final double stemX = stemDown ? x1 : nx2 - stemWidth;
        final double stemY2 = stemDown ? cy + lineGap * 3 : cy - lineGap * 3;
        if (state.gerenda &&
            (state.ritmus == '8' || state.ritmus == '6') &&
            !state.szaaratlan) {
          state.beamStems.add(
            _BeamStem(
              x: stemX,
              yHead: cy,
              yTip: stemY2,
              down: stemDown,
              rhythm: state.ritmus,
              head: Rect.fromLTRB(x1, ny1, nx2, ny2),
            ),
          );
          if (state.beamStems.length == 4) {
            _endBeam(canvas, state, lineGap);
          }
        } else {
          _drawStandaloneStem(
            canvas,
            _BeamStem(
              x: stemX,
              yHead: cy,
              yTip: stemY2,
              down: stemDown,
              rhythm: state.ritmus,
              head: Rect.fromLTRB(x1, ny1, nx2, ny2),
            ),
            lineGap,
          );
        }
      }

      _trackSlurPoint(state, Offset(nx, cy));
      _drawCompactHeadConnector(
        canvas,
        state,
        headLeft: x1,
        headRight: nx2,
        headCenterY: cy,
      );
      final Paint ledgerPaint = Paint()..color = _kottaInkColor;
      final double lx1 = (x1 - noteW / 4).truncateToDouble();
      final double lx2 = (nx2 + noteW / 4).truncateToDouble();
      void ledger(int index) {
        final double y = _linePos(top, lineGap, index).truncateToDouble();
        canvas.drawLine(Offset(lx1, y), Offset(lx2, y), ledgerPaint);
      }

      if (l2 >= 8) {
        ledger(8);
        if (l2 >= 9) ledger(9);
      }
      for (int index = l1; index <= 7 - state.staffLineCount; index++) {
        ledger(index);
      }
      _drawAgogika(
        canvas,
        state,
        noteCenter: Offset(nx, cy),
        stemDown: stemDown,
        lineGap: lineGap,
        onLine: l1 == l2,
      );
      if (state.pontozott) {
        final double dotSize = lineGap * _kcPontW / _kcPontV;
        _drawKottaAsset(
          canvas,
          'pont',
          Rect.fromLTWH(
            nx2 + mw / 8.0,
            cy - (l1 == l2 ? dotSize : dotSize / 2),
            dotSize,
            dotSize,
          ),
        );
      }

      state.modosito = ' ';
      return;
    }
    if (c1 == '|') {
      _endBeam(canvas, state, lineGap);
      _drawKottaBar(canvas, c2, x, top, lineGap, state.staffLineCount);
      return;
    }
    if (c1 == 's' || c1 == 'S') {
      _endBeam(canvas, state, lineGap);
      state.modosito = ' ';
      final String? restName = switch (c2) {
        '1' => 'szunet1',
        '2' => 'szunet2',
        '4' => 'szunet4',
        '8' => 'szunet8',
        '6' => 'szunet16',
        _ => null,
      };
      if (restName != null) {
        final _KottaRestGeometry geometry = _kottaRestGeometry(c2, lineGap);
        final double restX =
            x +
            geometry.leftOffset -
            (c1 == 'S' ? _kottaMinWidth(lineGap) / 4 : 0);
        _drawKottaAsset(
          canvas,
          restName,
          Rect.fromLTWH(
            restX,
            top + geometry.topOffset,
            geometry.width,
            geometry.height,
          ),
        );
        if (c1 == 'S') {
          _drawKottaAsset(
            canvas,
            'pont',
            Rect.fromLTWH(
              restX + geometry.width + _kottaMinWidth(lineGap) / 2,
              top + lineGap * 1.5 - lineGap * _kcPontW / _kcPontV / 2,
              lineGap * _kcPontW / _kcPontV,
              lineGap * _kcPontW / _kcPontV,
            ),
          );
        }
      }
    }
  }

  _KottaBarBounds _kottaBarBounds(
    double top,
    double lineGap,
    int staffLineCount,
  ) {
    if (staffLineCount <= 1) {
      return _KottaBarBounds(top + lineGap * 3.5, top + lineGap * 4.5);
    }
    return _KottaBarBounds(
      top + (5 - staffLineCount) * lineGap,
      top + lineGap * 4,
    );
  }

  _KottaRestGeometry _kottaRestGeometry(String rhythm, double lineGap) {
    switch (rhythm) {
      case '1':
        final double scale = lineGap / _kcSzunet1V;
        return _KottaRestGeometry(
          leftOffset: _kcSzunet1W * scale / 2,
          topOffset: lineGap,
          width: _kcSzunet1W * scale,
          height: _kcSzunet1H * scale,
        );
      case '2':
        final double scale = lineGap / _kcSzunet2V;
        final double height = _kcSzunet2H * scale;
        return _KottaRestGeometry(
          leftOffset: _kcSzunet2W * scale / 2,
          topOffset: lineGap * 1.5,
          width: _kcSzunet2W * scale,
          height: height,
        );
      case '4':
        final double scale = 2 * lineGap / (_kcSzunet4V2 - _kcSzunet4V4);
        return _KottaRestGeometry(
          leftOffset: _kcSzunet4W * scale / 2,
          topOffset: lineGap - _kcSzunet4V4 * scale,
          width: _kcSzunet4W * scale,
          height: _kcSzunet4H * scale,
        );
      case '8':
        final double scale = 2 * lineGap / (_kcSzunet8V2 - _kcSzunet8V4);
        return _KottaRestGeometry(
          leftOffset: _kcSzunet8W * scale / 2,
          topOffset: lineGap - _kcSzunet8V4 * scale,
          width: _kcSzunet8W * scale,
          height: _kcSzunet8H * scale,
        );
      default:
        final double scale = 2 * lineGap / (_kcSzunet16V2 - _kcSzunet16V4);
        return _KottaRestGeometry(
          leftOffset: _kcSzunet16W * scale / 2,
          topOffset: lineGap - _kcSzunet16V4 * scale,
          width: _kcSzunet16W * scale,
          height: _kcSzunet16H * scale,
        );
    }
  }

  void _drawCompactHeadConnector(
    Canvas canvas,
    _KottaDrawState state, {
    required double headLeft,
    required double headRight,
    required double headCenterY,
  }) {
    if (state.lastCompactHeadRight != null &&
        state.lastCompactHeadCenterY != null &&
        state.lastCompactHeadRight == headLeft) {
      canvas.drawLine(
        Offset(headLeft, state.lastCompactHeadCenterY!),
        Offset(headLeft, headCenterY),
        Paint()..color = _kottaInkColor,
      );
    }
    state.lastCompactHeadRight = headRight;
    state.lastCompactHeadCenterY = headCenterY;
  }

  void _drawKottaBar(
    Canvas canvas,
    String kind,
    double x,
    double top,
    double lineGap,
    int staffLineCount,
  ) {
    final bounds = _kottaBarBounds(top, lineGap, staffLineCount);
    double y1 = bounds.top;
    double y2 = bounds.bottom;
    final double unit = math.max(_kottaMinWidth(lineGap) / 4, 2);
    double centerX = x + 2 * unit;
    final int thinWidth = _kottaLineWidth(lineGap);
    final Paint paint = Paint()..color = _kottaInkColor;
    void line(double lineX, int width) {
      for (int i = 0; i < width; i++) {
        canvas.drawLine(Offset(lineX + i, y1), Offset(lineX + i, y2), paint);
      }
    }

    void dots(double dotX) {
      final double size = _kcPontW * lineGap / _kcPontV;
      final double dotY = (y1 + y2 - lineGap - size) / 2;
      for (int i = 0; i < 2; i++) {
        _drawKottaAsset(
          canvas,
          'pont',
          Rect.fromLTWH(dotX - size / 2, dotY + i * lineGap, size, size),
        );
      }
    }

    switch (kind) {
      case '1':
        line(centerX, 1);
        break;
      case '|':
      case '.':
        centerX -= unit / 2;
        line(centerX, thinWidth);
        line(centerX + unit, kind == '.' ? unit.toInt() : thinWidth);
        break;
      case "'":
        y1 -= lineGap / 2;
        y2 = y1 + lineGap;
        line(centerX, thinWidth);
        break;
      case '!':
        y1 -= lineGap / 2;
        if (staffLineCount <= 2) y1 -= lineGap;
        y2 = y1 + 2 * lineGap;
        line(centerX, thinWidth);
        break;
      case '>':
        line(centerX, thinWidth);
        line(centerX - unit * 2, unit.toInt());
        dots(centerX + unit * 2);
        break;
      case ':':
        centerX -= unit / 2;
        line(centerX, unit.toInt());
        line(centerX - unit, thinWidth);
        line(centerX + unit * 2, thinWidth);
        dots(centerX - unit * 3);
        dots(centerX + unit * 4);
        break;
      case '<':
        line(centerX, thinWidth);
        line(centerX + unit, unit.toInt());
        dots(centerX - unit * 2);
        break;
    }
  }

  void _drawAgogika(
    Canvas canvas,
    _KottaDrawState state, {
    required Offset noteCenter,
    required bool stemDown,
    required double lineGap,
    required bool onLine,
  }) {
    final String? assetName = switch (state.agogika) {
      '-' => 'tenuto',
      '.' => 'pont',
      '>' => 'marcato1',
      '^' => 'marcato2',
      'K' => stemDown ? 'koronale' : 'koronafel',
      'm' => 'mordent1',
      'M' => 'mordent2',
      't' => 'trilla1',
      'T' => 'trilla2',
      _ => null,
    };
    if (assetName == null) {
      return;
    }

    final _AgogikaMetrics metrics = _agogikaMetrics(assetName);
    final double height = metrics.height * lineGap / metrics.lineGap;
    final double width = metrics.width * lineGap / metrics.lineGap;
    double y = noteCenter.dy + (stemDown ? -lineGap : lineGap);
    if (onLine && (state.agogika == '-' || state.agogika == '.')) {
      y += height;
    }
    _drawKottaAsset(
      canvas,
      assetName,
      Rect.fromCenter(
        center: Offset(noteCenter.dx, y),
        width: width,
        height: height,
      ),
    );
  }

  _AgogikaMetrics _agogikaMetrics(String assetName) {
    return switch (assetName) {
      'tenuto' => const _AgogikaMetrics(66, 13, 80),
      'pont' => const _AgogikaMetrics(25, 25, 80),
      'marcato1' => const _AgogikaMetrics(128, 130, 135),
      'marcato2' => const _AgogikaMetrics(112, 106, 111),
      'koronafel' => const _AgogikaMetrics(169, 95, 99),
      'koronale' => const _AgogikaMetrics(168, 93, 109),
      'mordent1' => const _AgogikaMetrics(165, 78, 103),
      'mordent2' => const _AgogikaMetrics(163, 107, 112),
      'trilla1' => const _AgogikaMetrics(88, 59, 83),
      'trilla2' => const _AgogikaMetrics(140, 107, 107),
      _ => const _AgogikaMetrics(1, 1, 1),
    };
  }

  void _trackSlurPoint(_KottaDrawState state, Offset noteCenter) {
    if (state.slurType != ' ') {
      state.slurEnd = noteCenter;
      if (state.slurType.toLowerCase() == 'a') {
        state.slurExtremeY = math.max(state.slurExtremeY, noteCenter.dy);
      } else {
        state.slurExtremeY = state.slurExtremeY < 0
            ? noteCenter.dy
            : math.min(state.slurExtremeY, noteCenter.dy);
        state.slurExtremeY = math.max(0, state.slurExtremeY);
      }
    } else {
      state.slurStart = noteCenter;
      state.slurExtremeY = noteCenter.dy;
    }
    state.slurType = state.slurNext;
  }

  void _endSlur(
    Canvas canvas,
    _KottaDrawState state,
    double lineGap, {
    String? forcedType,
  }) {
    final String endType = forcedType ?? '?';
    final bool hasStart = state.slurType == 'a' || state.slurType == 'f';
    final bool hasEnd = endType == 'a' || endType == 'f';
    if (state.slurLeftX == null ||
        state.slurExtremeY < 0 ||
        (!hasStart && !hasEnd)) {
      return;
    }
    final bool down = hasEnd ? endType == 'a' : state.slurType == 'a';
    final double signedGap = down ? lineGap : -lineGap;
    final Offset start =
        (hasStart
            ? state.slurStart
            : Offset(state.slurLeftX!, state.slurExtremeY)) +
        Offset(0, signedGap);
    final Offset end = state.slurEnd + Offset(0, signedGap);
    final Offset delta = end - start;
    final double length = delta.distance;
    if (length == 0) return;
    final Offset unit = delta / length;
    final Offset normal = Offset(-unit.dy, unit.dx);
    final Offset center = hasStart && hasEnd
        ? (start + end) / 2
        : Offset(hasEnd ? state.rowStartX : state.currentX, state.slurExtremeY);
    final Offset outer = center + normal * signedGap;
    final Offset inner = center + normal * (signedGap * 0.75);
    final Offset tangent = delta / 4;
    final Offset startOuter = start + unit * lineGap + normal * signedGap;
    final Offset endOuter = end - unit * lineGap + normal * signedGap;
    final Offset startInner =
        start + unit * lineGap + normal * (signedGap * 0.75);
    final Offset endInner = end - unit * lineGap + normal * (signedGap * 0.75);
    void cubic(Path path, Offset a, Offset b, Offset c) =>
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    final Path p = Path()
      ..moveTo(hasStart ? start.dx : outer.dx, hasStart ? start.dy : outer.dy);
    if (hasStart) cubic(p, startOuter, outer - tangent, outer);
    if (hasEnd) {
      cubic(p, outer + tangent, endOuter, end);
      cubic(p, endInner, inner + tangent, inner);
    } else {
      cubic(p, inner, outer, inner);
    }
    if (hasStart) {
      cubic(p, inner - tangent, startInner, start);
    } else {
      cubic(p, outer, inner, outer);
    }
    canvas.drawPath(p, Paint()..color = _kottaInkColor);
    state.slurType = hasEnd
        ? ' '
        : (state.slurType.toLowerCase() == 'a' ? 'A' : 'F');
    state.slurNext = state.slurType;
    state.slurStart = Offset.zero;
    state.slurEnd = Offset.zero;
    state.slurExtremeY = -1;
  }

  void _trackTupletPoint(
    _KottaDrawState state,
    Offset noteCenter,
    bool stemDown,
    double lineGap,
    double headWidth,
  ) {
    if (state.triTipus != '3' && state.triTipus != '5') {
      return;
    }
    if (state.triPos.isNotEmpty) stemDown = state.triLe;
    state.triLe = stemDown;
    final double y = stemDown
        ? noteCenter.dy + lineGap * 3
        : noteCenter.dy - lineGap * 3;
    state.triPos.add(
      _TupletPoint(
        x: noteCenter.dx + (stemDown ? -headWidth / 2 : headWidth / 2),
        y: y,
      ),
    );
  }

  void _endTuplet(Canvas canvas, _KottaDrawState state, double lineGap) {
    final bool tri = state.triTipus == '3';
    if (!tri && state.triTipus != '5') {
      return;
    }
    state.triTipus = ' ';
    if (state.triPos.length < 2) {
      state.triPos.clear();
      return;
    }
    final _TupletPoint lp = state.triPos.first;
    final _TupletPoint rp = state.triPos.last;
    final double dx = rp.x - lp.x;
    if (dx <= 0) {
      state.triPos.clear();
      return;
    }
    final double slope = (rp.y - lp.y) / dx;
    double shift = 0;
    for (final point in state.triPos) {
      final double difference = point.y - (lp.y + (point.x - lp.x) * slope);
      shift = state.triLe
          ? math.max(shift, difference)
          : math.min(shift, difference);
    }

    final double lineOffset = state.triLe ? lineGap * 0.75 : -lineGap * 0.75;
    final double leftX = lp.x - lineGap / 2;
    final double rightX = rp.x + lineGap / 2;
    final double leftY = lp.y + shift + lineOffset - slope * lineGap / 2;
    final double rightY = rp.y + shift + lineOffset + slope * lineGap / 2;
    final String img = tri ? 'triola' : 'pentola';
    final double numeralWidth = lineGap * (tri ? 39 / 84 : 38 / 85);
    _drawKottaAsset(
      canvas,
      img,
      Rect.fromLTWH(
        (leftX + rightX - numeralWidth) / 2,
        (leftY + rightY) / 2 + (state.triLe ? lineGap / 2 : -1.5 * lineGap),
        numeralWidth,
        lineGap,
      ),
    );
    final Paint paint = Paint()..color = _kottaInkColor;
    final double cap = state.triLe ? -lineGap / 2 : lineGap / 2;
    for (int i = 0; i < _kottaLineWidth(lineGap); i++) {
      canvas.drawLine(
        Offset(leftX, leftY + i),
        Offset(rightX, rightY + i),
        paint,
      );
      canvas.drawLine(
        Offset(leftX + i, leftY),
        Offset(leftX + i, leftY + cap),
        paint,
      );
      canvas.drawLine(
        Offset(rightX - i, rightY),
        Offset(rightX - i, rightY + cap),
        paint,
      );
    }
    state.triPos.clear();
  }

  void _adjustTuplet(
    _KottaDrawState state,
    List<_BeamStem> stems,
    List<double> xs,
    List<double> tips,
  ) {
    for (final point in state.triPos) {
      for (int i = 0; i < stems.length; i++) {
        final head = stems[i].head;
        final double anchor = state.triLe ? head.left : head.right;
        if ((point.x - anchor).abs() < 0.001) {
          point.x = xs[i];
          point.y = tips[i];
          break;
        }
      }
    }
  }

  void _endBeam(Canvas canvas, _KottaDrawState state, double lineGap) {
    if (state.beamStems.length < 2) {
      if (state.beamStems.length == 1) {
        _drawStandaloneStem(canvas, state.beamStems.first, lineGap);
      }
      state.beamStems.clear();
      return;
    }
    final List<_BeamStem> stems = state.beamStems;
    final _BeamStem first = stems.first;
    final double beamThickness = lineGap / 2;
    final double interbeamGap = beamThickness / 2;
    final double minLength = lineGap * 3;
    final double stemWidth =
        _kcZaszloSzel * first.head.height / (_kcHang4V2a - _kcHang4V2f);
    final xs = <double>[
      for (final stem in stems)
        stem.down ? stem.head.left : stem.head.right - stemWidth,
    ];
    final tips = <double>[
      for (final stem in stems)
        stem.yHead + (stem.down ? minLength : -minLength),
    ];
    final int last = stems.length - 1;
    final double dx = xs[last] - xs[0];
    if (dx == 0) {
      for (final stem in stems) {
        _drawStandaloneStem(canvas, stem, lineGap);
      }
      state.beamStems.clear();
      return;
    }
    int index = 1;
    for (int count = 0; count < 100 && index <= last; count++) {
      final double y =
          tips[0] + (xs[index] - xs[0]) * (tips[last] - tips[0]) / dx;
      final stem = stems[index];
      final double limit = stem.yHead + (stem.down ? minLength : -minLength);
      if (stem.down != first.down || (stem.down ? y >= limit : y <= limit)) {
        tips[index++] = y;
      } else {
        final double difference = limit - y;
        tips[0] += difference;
        tips[last] += difference;
        index = 1;
      }
    }
    final Paint paint = Paint()..color = _kottaInkColor;
    for (int i = 0; i <= last; i++) {
      for (double x = xs[i]; x < xs[i] + stemWidth; x++) {
        canvas.drawLine(Offset(x, stems[i].yHead), Offset(x, tips[i]), paint);
      }
    }
    _adjustTuplet(state, stems, xs, tips);
    void beam(double x1, double y1, double x2, double y2) {
      for (double offset = 0; offset < beamThickness; offset++) {
        canvas.drawLine(
          Offset(x1, y1 + offset),
          Offset(x2, y2 + offset),
          paint,
        );
      }
    }

    beam(
      xs[0],
      tips[0] - (first.down ? beamThickness : 0),
      xs[last],
      tips[last] - (stems.last.down ? beamThickness : 0),
    );
    final double halfHead = first.head.width / 2;
    bool previous16 = true;
    for (int index = 0; index < stems.length; index++) {
      if (stems[index].rhythm != '6') {
        previous16 = false;
        continue;
      }
      if (index == last && previous16) break;
      previous16 = index == last || stems[index + 1].rhythm == '6';
      if (index != last && stems[index].down != stems[index + 1].down) {
        previous16 = false;
      }
      final double x1 = previous16 || index == 0
          ? xs[index]
          : xs[index] - halfHead;
      final double x2 = previous16
          ? (index == last ? x1 - halfHead : xs[index + 1])
          : xs[index] + halfHead;
      final double offset = stems[index].down
          ? -2 * beamThickness - interbeamGap
          : beamThickness + interbeamGap;
      double y(double x) =>
          tips[0] + offset + (tips[last] - tips[0]) * (x - xs[0]) / dx;
      beam(x1, y(x1), x2, y(x2));
    }
    state.beamStems.clear();
  }

  void _drawStandaloneStem(Canvas canvas, _BeamStem stem, double lineGap) {
    if (stem.rhythm == '8' || stem.rhythm == '6') {
      _drawStandaloneFlag(canvas, stem, lineGap);
    }
    final double width = _kcZaszloSzel * lineGap / (_kcHang4V2a - _kcHang4V2f);
    final Paint paint = Paint()..color = _kottaInkColor;
    for (double x = stem.x; x < stem.x + width; x++) {
      canvas.drawLine(Offset(x, stem.yHead), Offset(x, stem.yTip), paint);
    }
  }

  void _drawStandaloneFlag(Canvas canvas, _BeamStem stem, double lineGap) {
    final String flgName = stem.down
        ? (stem.rhythm == '6' ? 'zaszlo16le' : 'zaszlo8le')
        : (stem.rhythm == '6' ? 'zaszlo16fel' : 'zaszlo8fel');
    final Rect fr = _flagRect(
      stem.x,
      stem.yTip,
      lineGap,
      stem.down,
      stem.rhythm,
    );
    _drawKottaAsset(canvas, flgName, fr);
  }

  Rect _flagRect(
    double stemX,
    double stemYTip,
    double lineGap,
    bool down,
    String rhythm,
  ) {
    final double rat = lineGap / (_kcHang4V2a - _kcHang4V2f);
    final bool is16 = rhythm == '6';
    if (down) {
      final double w = _kcZaszlo8leW * rat;
      final double h = (is16 ? _kcZaszlo16leH : _kcZaszlo8leH) * rat;
      // Android parity: lower stem uses stem tip as flag bottom anchor.
      return Rect.fromLTWH(stemX, stemYTip - h, w, h);
    }
    final double w = _kcZaszlo8felW * rat;
    final double h = (is16 ? _kcZaszlo16felH : _kcZaszlo8felH) * rat;
    // Both flags share the stem's left edge; upper flags start at its tip.
    return Rect.fromLTWH(stemX, stemYTip, w, h);
  }

  bool _drawKottaAsset(
    Canvas canvas,
    String assetName,
    Rect dst, {
    FilterQuality filterQuality = FilterQuality.none,
  }) {
    final ui.Image? img = KottaAssets.image(assetName);
    if (img == null) {
      return false;
    }
    final Rect src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final Paint p = Paint()
      ..filterQuality = filterQuality
      ..colorFilter = ColorFilter.mode(_kottaInkColor, BlendMode.srcIn);
    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTRB(
        dst.left.truncateToDouble(),
        dst.top.truncateToDouble(),
        dst.right.truncateToDouble(),
        dst.bottom.truncateToDouble(),
      ),
      p,
    );
    return true;
  }

  _KottaNotePos? _notePos(String oktav, String note) {
    int l1;
    int l2;
    switch (note.toLowerCase()) {
      case 'g':
        l1 = 10;
        l2 = 9;
        break;
      case 'a':
        l1 = 9;
        l2 = 9;
        break;
      case 'h':
        l1 = 9;
        l2 = 8;
        break;
      case 'c':
        l1 = 8;
        l2 = 8;
        break;
      case 'd':
        l1 = 8;
        l2 = 7;
        break;
      case 'e':
        l1 = 7;
        l2 = 7;
        break;
      case 'f':
        l1 = 7;
        l2 = 6;
        break;
      default:
        return null;
    }
    if (oktav == '2') {
      if (l1 == l2) {
        l1 -= 3;
        l2 -= 4;
      } else {
        l1 -= 4;
        l2 -= 3;
      }
    } else if (oktav == '3') {
      l1 -= 7;
      l2 -= 7;
      if (l1 <= 0) {
        return null;
      }
    }
    return _KottaNotePos(
      l1: l1,
      l2: l2,
      centerIndex: (l1 + l2) / 2.0,
      betweenLines: l1 != l2,
    );
  }

  double _linePos(double top, double lineGap, int lineIndex) {
    return top + (lineIndex - 3) * lineGap;
  }

  List<_RenderLine> _parseRenderLines(List<String> lines) {
    final String cacheKey = lines.join('\u0001');
    final List<_RenderLine>? cached = _parsedLinesCache[cacheKey];
    if (cached != null) {
      return List<_RenderLine>.from(cached);
    }
    final List<_RenderLine> out = <_RenderLine>[];
    for (final String line in lines) {
      out.addAll(_parseOneLine(line));
    }
    _parsedLinesCache[cacheKey] = List<_RenderLine>.unmodifiable(out);
    while (_parsedLinesCache.length > _layoutCacheLimit) {
      _parsedLinesCache.remove(_parsedLinesCache.keys.first);
    }
    return List<_RenderLine>.from(out);
  }

  List<_RenderLine> _parseOneLine(String src) {
    final List<_RenderLine> result = <_RenderLine>[];
    final List<_WordToken> words = <_WordToken>[];
    final _WordStyle style = _WordStyle();
    final StringBuffer sb = StringBuffer();
    String? pendingChord;
    String? pendingKotta;
    final bool notationLine = src.contains(r'\K') || src.contains(r'\?K');

    void flushPendingAsSpace() {
      if ((pendingChord == null || pendingChord!.isEmpty) &&
          (pendingKotta == null || pendingKotta!.isEmpty)) {
        return;
      }
      words.add(
        _WordToken(
          text: (pendingKotta ?? '').isNotEmpty ? '' : '\u00A0',
          bold: style.bold,
          italic: style.italic,
          underline: style.underline,
          tieUnderline: style.tieUnderline,
          strike: style.strike,
          color: style.color,
          chord: pendingChord,
          kotta: pendingKotta,
          breakAfter: true,
        ),
      );
      pendingChord = null;
      pendingKotta = null;
    }

    void attachPendingToPrevWord() {
      if (words.isEmpty) {
        return;
      }
      if ((pendingChord == null || pendingChord!.isEmpty) &&
          (pendingKotta == null || pendingKotta!.isEmpty)) {
        return;
      }
      if (words.last.isControlPlaceholder) {
        return;
      }
      final _WordToken last = words.removeLast();
      final String? mergedChord = (() {
        final String a = (last.chord ?? '');
        final String b = (pendingChord ?? '');
        if (a.isEmpty) {
          return b.isEmpty ? null : b;
        }
        if (b.isEmpty) {
          return a;
        }
        return '$a$b';
      })();
      final String? mergedKotta = (() {
        final String a = (last.kotta ?? '');
        final String b = (pendingKotta ?? '');
        if (a.isEmpty) {
          return b.isEmpty ? null : b;
        }
        if (b.isEmpty) {
          return a;
        }
        return '$a$b';
      })();
      words.add(
        _WordToken(
          text: last.text,
          bold: last.bold,
          italic: last.italic,
          underline: last.underline,
          tieUnderline: last.tieUnderline,
          strike: last.strike,
          color: last.color,
          chord: mergedChord,
          kotta: mergedKotta,
          spaceAfter: last.spaceAfter,
          breakAfter: last.breakAfter,
          preferredBreakAfter: last.preferredBreakAfter,
          softHyphenAfter: last.softHyphenAfter,
          fontScale: last.fontScale,
        ),
      );
      pendingChord = null;
      pendingKotta = null;
    }

    void markPrevSpaceAfter({bool addPreferredBreakAfter = false}) {
      if (words.isEmpty) {
        return;
      }
      final _WordToken last = words.removeLast();
      words.add(
        _WordToken(
          text: last.text,
          bold: last.bold,
          italic: last.italic,
          underline: last.underline,
          tieUnderline: last.tieUnderline,
          strike: last.strike,
          color: last.color,
          chord: last.chord,
          kotta: last.kotta,
          spaceAfter: true,
          breakAfter: true,
          preferredBreakAfter:
              addPreferredBreakAfter || last.preferredBreakAfter,
          softHyphenAfter: last.softHyphenAfter,
          fontScale: last.fontScale,
        ),
      );
    }

    void markPrevSoftHyphenAfter() {
      if (words.isEmpty) {
        return;
      }
      final _WordToken last = words.removeLast();
      words.add(
        _WordToken(
          text: last.text,
          bold: last.bold,
          italic: last.italic,
          underline: last.underline,
          tieUnderline: last.tieUnderline,
          strike: last.strike,
          color: last.color,
          chord: last.chord,
          kotta: last.kotta,
          spaceAfter: last.spaceAfter,
          breakAfter: true,
          preferredBreakAfter: last.preferredBreakAfter,
          softHyphenAfter: true,
          fontScale: last.fontScale,
        ),
      );
    }

    void flushWord({
      bool addSpaceAfter = false,
      bool addBreakAfter = false,
      bool addPreferredBreakAfter = false,
      bool addSoftHyphenAfter = false,
      bool keepEmpty = false,
    }) {
      final String txt = sb.toString();
      sb.clear();
      if (txt.trim().isEmpty && !keepEmpty) {
        return;
      }
      words.add(
        _WordToken(
          text: txt,
          bold: style.bold,
          italic: style.italic,
          underline: style.underline,
          tieUnderline: style.tieUnderline,
          strike: style.strike,
          color: style.color,
          chord: pendingChord,
          kotta: pendingKotta,
          spaceAfter: addSpaceAfter,
          breakAfter: addBreakAfter,
          preferredBreakAfter: addPreferredBreakAfter,
          softHyphenAfter: addSoftHyphenAfter,
          fontScale: 1,
        ),
      );
      pendingChord = null;
      pendingKotta = null;
    }

    int i = 0;
    while (i < src.length) {
      final String ch = src[i];
      if (ch == '\\' && i + 1 < src.length) {
        final String cmd = src[i + 1];
        i += 2;
        switch (cmd) {
          case 'B':
            flushWord();
            style.bold = true;
            continue;
          case 'b':
            flushWord();
            style.bold = false;
            continue;
          case 'I':
            flushWord();
            style.italic = true;
            continue;
          case 'i':
            flushWord();
            style.italic = false;
            continue;
          case 'U':
            flushWord();
            style.underline = true;
            continue;
          case 'u':
            flushWord();
            style.underline = false;
            continue;
          case '(':
            flushWord();
            style.tieUnderline = true;
            continue;
          case ')':
            flushWord();
            style.tieUnderline = false;
            continue;
          case 'S':
            flushWord();
            style.strike = true;
            continue;
          case 's':
            flushWord();
            style.strike = false;
            continue;
          case '.':
            if (sb.isNotEmpty || notationLine) {
              flushWord(
                addSpaceAfter: true,
                addBreakAfter: true,
                addPreferredBreakAfter: true,
                keepEmpty: notationLine,
              );
            } else {
              // `\.` can arrive straight after a control block (\K, \G, ?K,
              // ?G), which leaves the text buffer empty and only the pending
              // chord/kotta behind. flushWord() would bail out on the empty
              // buffer and drop the break, gluing the next word onto the
              // previous one ("Pange\K1d;\.lingua" -> "Pangelingua").
              // Mark the previous token instead and keep the pending
              // chord/kotta for the word that follows the break.
              markPrevSpaceAfter(addPreferredBreakAfter: true);
            }
            continue;
          case '_':
            sb.write('-');
            if (notationLine) flushWord();
            continue;
          case '-':
            if (sb.isNotEmpty || notationLine) {
              flushWord(addSoftHyphenAfter: true, keepEmpty: notationLine);
            } else {
              attachPendingToPrevWord();
              markPrevSoftHyphenAfter();
            }
            continue;
          case ' ': // non-breaking space marker
            sb.write('\u00A0');
            if (notationLine) flushWord(keepEmpty: true);
            continue;
          case 'G':
            flushWord();
            final int end = src.indexOf(';', i);
            if (end > i) {
              if (pendingChord != null && pendingChord!.isNotEmpty) {
                flushPendingAsSpace();
              }
              pendingChord = src.substring(i, end);
              i = end + 1;
            }
            continue;
          case 'K':
            flushWord();
            if (!notationLine) attachPendingToPrevWord();
            final int endK = src.indexOf(';', i);
            if (endK > i) {
              pendingKotta = src.substring(i, endK);
              i = endK + 1;
            }
            continue;
          case 'C':
            flushWord();
            if (!notationLine) attachPendingToPrevWord();
            final int endC = src.indexOf(';', i);
            if (endC > i) {
              style.color = _parseColor(src.substring(i, endC));
              i = endC + 1;
            }
            continue;
          case '?':
            flushWord();
            if (!notationLine) attachPendingToPrevWord();
            if (i < src.length) {
              final String sub = src[i];
              i++;
              final int end = src.indexOf(';', i);
              if (end > i) {
                final String payload = src.substring(i, end);
                if (sub == 'G') {
                  if (pendingChord != null && pendingChord!.isNotEmpty) {
                    flushPendingAsSpace();
                  }
                  pendingChord = payload;
                } else if (sub == 'K') {
                  pendingKotta = payload;
                } else if (sub == 'C') {
                  style.color = _parseColor(payload);
                }
                i = end + 1;
              }
            }
            continue;
          default:
            sb.write(cmd);
            continue;
        }
      }

      if (ch == ' ') {
        if (notationLine) {
          flushWord(addSpaceAfter: true, addBreakAfter: true, keepEmpty: true);
        } else if (sb.isNotEmpty) {
          flushWord(addSpaceAfter: true, addBreakAfter: true);
        } else if ((pendingChord ?? '').isNotEmpty ||
            (pendingKotta ?? '').isNotEmpty) {
          flushPendingAsSpace();
        } else {
          attachPendingToPrevWord();
          // Space can arrive right after an escaped control block (\K, \G, etc.).
          // In that case there is no buffered text, so mark the previous token.
          markPrevSpaceAfter();
        }
      } else if (ch == '-') {
        sb.write('-');
        if (!notationLine) {
          flushWord(addBreakAfter: true);
        }
      } else {
        sb.write(ch);
      }
      i++;
    }

    flushWord(keepEmpty: notationLine);
    flushPendingAsSpace();
    result.add(_RenderLine(words: List<_WordToken>.from(words)));
    return result;
  }

  Color? _parseColor(String hex) {
    final String h = hex.trim();
    if (h.isEmpty) {
      return null;
    }
    final int? v = int.tryParse(h, radix: 16);
    if (v == null) {
      return null;
    }
    return Color(0xFF000000 | v);
  }

  void _drawImage(Canvas canvas, Size size, ImageFrame frame, int mode) {
    final bool blankView =
        !globals.projecting || globals.showBlankPic || globals.isBlankPic;
    final Color fill = blankView
        ? _colorWithTransparency(globals.blankColor, globals.blankTrans)
        : _colorWithTransparency(globals.bkColor, globals.backTrans);
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);

    final ui.Image image = frame.image;
    final Rect src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    switch (mode) {
      case 0:
        final Offset pos = Offset(
          (size.width - src.width) / 2,
          (size.height - src.height) / 2,
        );
        canvas.drawImage(image, pos, Paint());
        return;
      case 2:
        final Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawImageRect(image, src, dst, Paint());
        return;
      case 3:
        for (double y = 0; y < size.height; y += src.height) {
          for (double x = 0; x < size.width; x += src.width) {
            canvas.drawImage(image, Offset(x, y), Paint());
          }
        }
        return;
      case 4:
        // Mirror-mode is approximated using repeated mirrored tiles.
        final Paint p = Paint();
        for (double y = 0, row = 0; y < size.height; y += src.height, row++) {
          for (double x = 0, col = 0; x < size.width; x += src.width, col++) {
            canvas.save();
            canvas.translate(x, y);
            final bool flipX = col.toInt().isOdd;
            final bool flipY = row.toInt().isOdd;
            if (flipX || flipY) {
              canvas.translate(flipX ? src.width : 0, flipY ? src.height : 0);
              canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
            }
            canvas.drawImage(image, Offset.zero, p);
            canvas.restore();
          }
        }
        return;
      case 1:
      default:
        final double scale = math.min(
          size.width / src.width,
          size.height / src.height,
        );
        final Size target = Size(src.width * scale, src.height * scale);
        final Rect dst = Rect.fromLTWH(
          (size.width - target.width) / 2,
          (size.height - target.height) / 2,
          target.width,
          target.height,
        );
        canvas.drawImageRect(image, src, dst, Paint());
        return;
    }
  }

  @override
  bool shouldRepaint(ProjectorPainter oldDelegate) {
    return !_sameFrame(oldDelegate.frame, frame) ||
        !_sameGlobals(oldDelegate.globals, globals) ||
        !_sameSettings(oldDelegate.settings, settings) ||
        oldDelegate.allowLineWrapping != allowLineWrapping ||
        !_sameEditorCursorOverlay(
          oldDelegate.editorCursorOverlay,
          editorCursorOverlay,
        ) ||
        oldDelegate.logoTitle != logoTitle ||
        oldDelegate.logoSubtitle != logoSubtitle;
  }

  bool _sameFrame(ProjectionFrame? a, ProjectionFrame? b) {
    if (identical(a, b)) {
      return true;
    }

    if (a == null || b == null || a.runtimeType != b.runtimeType) {
      return false;
    }

    if (a is LogoFrame && b is LogoFrame) {
      return a.phase == b.phase;
    }
    if (a is ImageFrame && b is ImageFrame) {
      return identical(a.image, b.image) && a.bgMode == b.bgMode;
    }
    if (a is TextFrame && b is TextFrame) {
      return _sameTextRecord(a.record, b.record);
    }
    return false;
  }

  bool _sameEditorCursorOverlay(
    ProjectorEditorCursorOverlay? a,
    ProjectorEditorCursorOverlay? b,
  ) {
    return a?.kottaPosition == b?.kottaPosition &&
        a?.textPosition == b?.textPosition &&
        a?.textActive == b?.textActive &&
        a?.activeVisible == b?.activeVisible &&
        a?.kottaSelection == b?.kottaSelection;
  }

  bool _sameTextRecord(dynamic a, dynamic b) {
    return a.scholaLine == b.scholaLine &&
        a.title == b.title &&
        listEquals(a.lines, b.lines);
  }

  bool _sameSettings(AppSettings a, AppSettings b) {
    return a.clipL == b.clipL &&
        a.clipT == b.clipT &&
        a.clipR == b.clipR &&
        a.clipB == b.clipB &&
        a.mirror == b.mirror &&
        a.rotateQuarterTurns == b.rotateQuarterTurns &&
        a.receiverUseAkkord == b.receiverUseAkkord &&
        a.receiverUseKotta == b.receiverUseKotta;
  }

  bool _sameGlobals(ProjectionGlobals a, ProjectionGlobals b) {
    return a.bkColor == b.bkColor &&
        a.txtColor == b.txtColor &&
        a.blankColor == b.blankColor &&
        a.hiColor == b.hiColor &&
        a.fontSize == b.fontSize &&
        a.titleSize == b.titleSize &&
        a.leftIndent == b.leftIndent &&
        a.spacing100 == b.spacing100 &&
        a.hKey == b.hKey &&
        a.wordToHighlight == b.wordToHighlight &&
        a.borderL == b.borderL &&
        a.borderT == b.borderT &&
        a.borderR == b.borderR &&
        a.borderB == b.borderB &&
        a.fontName == b.fontName &&
        a.isBlankPic == b.isBlankPic &&
        a.autoResize == b.autoResize &&
        a.projecting == b.projecting &&
        a.showBlankPic == b.showBlankPic &&
        a.hCenter == b.hCenter &&
        a.vCenter == b.vCenter &&
        a.scholaMode == b.scholaMode &&
        a.useAkkord == b.useAkkord &&
        a.useKotta == b.useKotta &&
        a.useTransitions == b.useTransitions &&
        a.endProgram == b.endProgram &&
        a.hideTitle == b.hideTitle &&
        a.inverzKotta == b.inverzKotta &&
        a.bgMode == b.bgMode &&
        a.kottaArany == b.kottaArany &&
        a.akkordArany == b.akkordArany &&
        a.akkordNotation == b.akkordNotation &&
        a.akkordOptionalSeventh == b.akkordOptionalSeventh &&
        a.akkordMinorAsDash == b.akkordMinorAsDash &&
        a.backTrans == b.backTrans &&
        a.blankTrans == b.blankTrans &&
        a.borderToClip == b.borderToClip &&
        a.boldText == b.boldText;
  }

  Color _colorWithTransparency(Color color, int transparencyPercent) {
    final int clamped = transparencyPercent.clamp(0, 100);
    final int alpha = ((100 - clamped) * 255 / 100).round().clamp(0, 255);
    return color.withAlpha(alpha);
  }
}

class _RenderLine {
  const _RenderLine({required this.words});
  final List<_WordToken> words;
}

class _WordToken {
  const _WordToken({
    required this.text,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.tieUnderline,
    required this.strike,
    required this.color,
    this.chord,
    this.kotta,
    this.spaceAfter = false,
    this.breakAfter = false,
    this.preferredBreakAfter = false,
    this.softHyphenAfter = false,
    this.fontScale = 1,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool tieUnderline;
  final bool strike;
  final Color? color;
  final String? chord;
  final String? kotta;
  final bool spaceAfter;
  final bool breakAfter;
  final bool preferredBreakAfter;
  final bool softHyphenAfter;
  final double fontScale;

  bool get countAsWord => text.trim().isNotEmpty;
  bool get isControlPlaceholder =>
      text == '\u00A0' &&
      ((chord ?? '').isNotEmpty || (kotta ?? '').isNotEmpty);
}

class _WordStyle {
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool tieUnderline = false;
  bool strike = false;
  Color? color;
}

class _AgogikaMetrics {
  const _AgogikaMetrics(this.width, this.height, this.lineGap);

  final double width;
  final double height;
  final double lineGap;
}

class _KottaBarBounds {
  const _KottaBarBounds(this.top, this.bottom);

  final double top;
  final double bottom;
}

class _KottaRestGeometry {
  const _KottaRestGeometry({
    required this.leftOffset,
    required this.topOffset,
    required this.width,
    required this.height,
  });

  final double leftOffset;
  final double topOffset;
  final double width;
  final double height;
}

class _KottaDrawState {
  String kulcs = ' ';
  int elojegy = 0;
  String modosito = ' ';
  String ritmus = '4';
  bool pontozott = false;
  bool tomor = false;
  bool gerenda = false;
  bool szaaratlan = false;
  double? lastCompactHeadRight;
  double? lastCompactHeadCenterY;
  String agogika = ' ';
  int staffLineCount = 5;
  double lastSetupWidth = 0;
  String slurType = ' ';
  String slurNext = ' ';
  Offset slurStart = Offset.zero;
  Offset slurEnd = Offset.zero;
  double? slurLeftX;
  double slurExtremeY = -1;
  double rowStartX = 0;
  double currentX = 0;
  bool triLe = false;
  String triTipus = ' ';
  final List<_TupletPoint> triPos = <_TupletPoint>[];
  final List<_BeamStem> beamStems = <_BeamStem>[];

  _KottaDrawState copy() {
    final _KottaDrawState c = _KottaDrawState();
    c.kulcs = kulcs;
    c.elojegy = elojegy;
    c.modosito = modosito;
    c.ritmus = ritmus;
    c.pontozott = pontozott;
    c.tomor = tomor;
    c.gerenda = gerenda;
    c.szaaratlan = szaaratlan;
    c.lastCompactHeadRight = lastCompactHeadRight;
    c.lastCompactHeadCenterY = lastCompactHeadCenterY;
    c.agogika = agogika;
    c.staffLineCount = staffLineCount;
    c.lastSetupWidth = lastSetupWidth;
    c.slurType = slurType;
    c.slurNext = slurNext;
    c.slurStart = slurStart;
    c.slurEnd = slurEnd;
    c.slurLeftX = slurLeftX;
    c.slurExtremeY = slurExtremeY;
    c.rowStartX = rowStartX;
    c.currentX = currentX;
    c.triLe = triLe;
    c.triTipus = triTipus;
    c.triPos.addAll(triPos);
    c.beamStems.addAll(beamStems);
    return c;
  }

  void resetTransient() {
    modosito = ' ';
    ritmus = '4';
    pontozott = false;
    tomor = false;
  }
}

class _TupletPoint {
  _TupletPoint({required this.x, required this.y});

  double x;
  double y;
}

class _BeamStem {
  _BeamStem({
    required this.x,
    required this.yHead,
    required this.yTip,
    required this.down,
    required this.rhythm,
    required this.head,
  });
  final double x;
  final double yHead;
  final double yTip;
  final bool down;
  final String rhythm;
  final Rect head;
}

class _KottaNotePos {
  const _KottaNotePos({
    required this.l1,
    required this.l2,
    required this.centerIndex,
    required this.betweenLines,
  });
  final int l1;
  final int l2;
  final double centerIndex;
  final bool betweenLines;
}

class _KottaWordLayout {
  const _KottaWordLayout({
    required this.wordIndex,
    required this.slotWidth,
    this.textInset = 0,
    this.groupGap = 0,
  });
  final int wordIndex;
  final double slotWidth;
  final double textInset;
  final double groupGap;
}

class _KottaRowPrefix {
  const _KottaRowPrefix({required this.kotta, required this.width});

  const _KottaRowPrefix.empty() : kotta = '', width = 0;

  final String kotta;
  final double width;
}

class _KottaRowLayout {
  const _KottaRowLayout({
    required this.words,
    required this.width,
    this.centeringWidth,
    this.prefix = const _KottaRowPrefix.empty(),
    this.inlinePrefix = const _KottaRowPrefix.empty(),
    this.endHyphen = false,
    this.staffLineCount = 5,
  });
  final List<_KottaWordLayout> words;
  final double width;
  final double? centeringWidth;
  final _KottaRowPrefix prefix;
  final _KottaRowPrefix inlinePrefix;
  final bool endHyphen;
  final int staffLineCount;
}

class _TextRowLayout {
  const _TextRowLayout({
    required this.wordIndices,
    required this.width,
    this.indentWidth = 0,
    this.endHyphen = false,
  });
  final List<int> wordIndices;
  final double width;
  final double indentWidth;
  final bool endHyphen;
}

class _TextRowPaintLayout {
  const _TextRowPaintLayout({required this.painter, required this.wordLayouts});

  final TextPainter painter;
  final List<_TextWordLayout> wordLayouts;
}

class _TextWordLayout {
  const _TextWordLayout({
    required this.start,
    required this.end,
    required this.tieUnderline,
    required this.color,
  });

  final int start;
  final int end;
  final bool tieUnderline;
  final Color color;
}

class _KottaTextSlotLayout {
  const _KottaTextSlotLayout({
    required this.wordIndex,
    required this.left,
    required this.right,
    required this.tieRight,
    required this.baseline,
    required this.tieUnderline,
    required this.color,
    required this.connectorColor,
  });

  final int wordIndex;
  final double left;
  final double right;
  final double tieRight;
  final double baseline;
  final bool tieUnderline;
  final Color color;
  final Color connectorColor;
}

class _PreparedTextLayout {
  const _PreparedTextLayout({
    required this.hasTitleLine,
    required this.titleFontSize,
    required this.lines,
    required this.textRowsByLine,
    required this.hasKottaByLine,
    required this.chordBandByLine,
    required this.kottaRowsByLine,
    required this.lineHeightsByLine,
    required this.bottomTextDescent,
  });

  final bool hasTitleLine;
  final double titleFontSize;
  final List<_RenderLine> lines;
  final List<List<_TextRowLayout>> textRowsByLine;
  final List<bool> hasKottaByLine;
  final List<double> chordBandByLine;
  final List<List<_KottaRowLayout>> kottaRowsByLine;
  final List<double> lineHeightsByLine;
  final double bottomTextDescent;
}

class _AutoSizeResult {
  const _AutoSizeResult({
    required this.fontSize,
    required this.preferPreferredBreaks,
  });

  final double fontSize;
  final bool preferPreferredBreaks;
}

const double _kcGkulcsW = 102.0;
const double _kcFkulcsW = 102.0;
const double _kcCkulcsW = 122.0;
const double _kcDkulcsW = 19.0;
const double _kcGkulcsH = 265.0;
const double _kcFkulcsH = 144.0;
const double _kcCkulcsH = 197.0;
const double _kcDkulcsH = 59.0;
const double _kcGkulcsV1 = 212.0;
const double _kcGkulcsV5 = 67.0;
const double _kcFkulcsV1 = 143.0;
const double _kcFkulcsV5 = 0.0;
const double _kcCkulcsV1 = 196.0;
const double _kcCkulcsV5 = 0.0;
const double _kcDkulcsV1 = 50.0;
const double _kcDkulcsV2 = 10.0;

const double _kcBeW = 43.0;
const double _kcBeBeW = 75.0;
const double _kcFeloldoW = 34.0;
const double _kcKeresztW = 50.0;
const double _kcKettosKeresztW = 58.0;
const double _kcBeH = 114.0;
const double _kcBeBeH = 114.0;
const double _kcFeloldoH = 106.0;
const double _kcKeresztH = 113.0;
const double _kcKettosKeresztH = 58.0;
const double _kcBeV1 = 83.0;
const double _kcBeV2a = 100.0;
const double _kcBeV2f = 67.0;
const double _kcBeBeV1 = 83.0;
const double _kcBeBeV2a = 100.0;
const double _kcBeBeV2f = 67.0;
const double _kcFeloldoV1 = 53.0;
const double _kcFeloldoV2a = 70.0;
const double _kcFeloldoV2f = 35.0;
const double _kcKeresztV1 = 55.0;
const double _kcKeresztV2a = 78.0;
const double _kcKeresztV2f = 35.0;
const double _kcKettosKeresztV1 = 29.0;
const double _kcKettosKeresztV2a = 49.0;
const double _kcKettosKeresztV2f = 7.0;

const double _kcHang0W = 106.0;
const double _kcHang1W = 92.0;
const double _kcHang2W = 67.0;
const double _kcHang4W = 67.0;
const double _kcHangBrevis1W = 119.0;
const double _kcHangBrevis2W = 154.0;
const double _kcHang0H = 79.0;
const double _kcHang1H = 58.0;
const double _kcHang2H = 54.0;
const double _kcHang4H = 54.0;
const double _kcHangBrevis1H = 56.0;
const double _kcHangBrevis2H = 56.0;
const double _kcHang0V1 = 40.0;
const double _kcHang0V2a = 73.0;
const double _kcHang0V2f = 6.0;
const double _kcHang1V1 = 29.0;
const double _kcHang1V2a = 57.0;
const double _kcHang1V2f = 0.0;
const double _kcHang2V1 = 26.0;
const double _kcHang2V2a = 53.0;
const double _kcHang2V2f = 0.0;
const double _kcHang4V1 = 26.0;
const double _kcHang4V2a = 53.0;
const double _kcHang4V2f = 0.0;
const double _kcHangBrevis1V1 = 28.0;
const double _kcHangBrevis1V2a = 55.0;
const double _kcHangBrevis1V2f = 0.0;
const double _kcHangBrevis2V1 = 28.0;
const double _kcHangBrevis2V2a = 55.0;
const double _kcHangBrevis2V2f = 0.0;

const double _kcPontW = 25.0;
const double _kcPontV = 80.0;
const double _kcU22W = 39.0;
const double _kcU22H = 170.0;

const double _kcSzunet1W = 110.0;
const double _kcSzunet2W = 125.0;
const double _kcSzunet4W = 81.0;
const double _kcSzunet8W = 58.0;
const double _kcSzunet16W = 77.0;
const double _kcSzunet1H = 33.0;
const double _kcSzunet2H = 33.0;
const double _kcSzunet4H = 202.0;
const double _kcSzunet8H = 122.0;
const double _kcSzunet16H = 141.0;
const double _kcSzunet1V = 60.0;
const double _kcSzunet2V = 60.0;
const double _kcSzunet4V2 = 175.0;
const double _kcSzunet4V4 = 54.0;
const double _kcSzunet8V2 = 122.0;
const double _kcSzunet8V4 = 0.0;
const double _kcSzunet16V2 = 141.0;
const double _kcSzunet16V4 = 0.0;

const double _kcZaszloSzel = 5.0;
const double _kcZaszlo8felW = 53.0;
const double _kcZaszlo8leW = 58.0;
const double _kcZaszlo16felH = 182.0;
const double _kcZaszlo16leH = 160.0;
const double _kcZaszlo8felH = 165.0;
const double _kcZaszlo8leH = 162.0;
