import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/projection_frame.dart';
import '../models/projection_globals.dart';

import 'kotta_assets.dart';

class ProjectorPainter extends CustomPainter {
  ProjectorPainter({
    required this.frame,
    required this.globals,
    required this.settings,
    this.logoTitle = '',
    this.logoSubtitle = 'Flutter port',
  });

  final ProjectionFrame? frame;
  final ProjectionGlobals globals;
  final AppSettings settings;
  final String logoTitle;
  final String logoSubtitle;

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
    final double blockStartX = _kottaRowsStartX(rows, sizeWidth, horizontalPad);
    return <double>[
      for (int i = 0; i < rows.length; i++)
        blockStartX + _kottaContinuationIndent(i, horizontalPad),
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
    final List<_KottaRowPrefix> rowPrefixes = _resolveKottaRowPrefixes(
      rows,
      lines.first,
      _kottaLineGap(fontSize),
    );
    final double blockStartX = _kottaRowsStartX(rows, sizeWidth, horizontalPad);
    return <double>[
      for (int i = 0; i < rows.length; i++)
        rowPrefixes[i].kotta.isNotEmpty || rows[i].inlinePrefix.kotta.isNotEmpty
            ? blockStartX + _kottaContinuationIndent(i, horizontalPad)
            : _debugCenteredKottaStartX(
                rows[i],
                lines.first,
                fontSize,
                blockStartX + _kottaContinuationIndent(i, horizontalPad),
              ),
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
    final double blockStartX = _kottaRowsStartX(rows, sizeWidth, horizontalPad);
    return <double>[
      for (int i = 0; i < rows.length; i++)
        blockStartX +
            _kottaContinuationIndent(i, horizontalPad) +
            rowPrefixes[i].width +
            rows[i].inlinePrefix.width,
    ];
  }

  void _drawContent(Canvas canvas, Size size) {
    final ProjectionFrame? localFrame = frame;
    if (localFrame is LogoFrame) {
      _drawLogo(canvas, size, localFrame.phase);
      return;
    }

    if (localFrame is TextFrame) {
      _drawText(canvas, size, localFrame);
      return;
    }

    if (localFrame is ImageFrame) {
      _drawImage(canvas, size, localFrame, localFrame.bgMode);
      return;
    }

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

  void _drawText(Canvas canvas, Size size, TextFrame frame) {
    final Color bg = _colorWithTransparency(globals.bkColor, globals.backTrans);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    const double horizontalPad = 0;
    final double maxWidth = math.max(40, size.width);

    final bool hasTitleLine =
        !globals.hideTitle && frame.record.title.isNotEmpty;
    final List<String> sourceLines = <String>[
      if (hasTitleLine) frame.record.title,
      ...frame.record.lines,
    ];

    final List<_RenderLine> allLines = _parseRenderLines(sourceLines);

    double fontSize = globals.fontSize.toDouble();
    if (globals.autoResize) {
      while (fontSize > 8) {
        final double required = _measureTextRequiredHeightForFontSize(
          size,
          frame,
          fontSize,
        );
        if (required <= size.height * 0.95) {
          break;
        }
        fontSize -= 1;
      }
    }

    final double titleFontSize = (globals.titleSize.toDouble() * 2.5).clamp(
      8.0,
      72.0,
    );
    final double lineSpacing = globals.spacing100 / 100.0;

    final List<TextPainter> painters = <TextPainter>[];
    final List<List<bool>> highlightByLine = <List<bool>>[];
    final List<List<_TextRowLayout>> textRowsByLine = <List<_TextRowLayout>>[];
    final List<bool> hasKottaByLine = <bool>[];
    final List<double> chordBandByLine = <double>[];
    final List<List<_KottaRowLayout>> kottaRowsByLine =
        <List<_KottaRowLayout>>[];
    final _KottaDrawState carryKottaState = _KottaDrawState();
    int globalWordIndex = 0; // Track word index for highlighting (skips title)
    bool prevWordHadSpace = true;

    for (int lineIndex = 0; lineIndex < allLines.length; lineIndex++) {
      final _RenderLine baseLine = allLines[lineIndex];
      final bool isTitleLine = hasTitleLine && lineIndex == 0;
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      final bool hasKotta =
          !isTitleLine &&
          globals.useKotta &&
          settings.receiverUseKotta &&
          baseLine.words.any((w) => (w.kotta ?? '').isNotEmpty);
      final _RenderLine line = (!isTitleLine && !hasKotta)
          ? _applyChordPadding(baseLine, lineFontSize)
          : baseLine;
      allLines[lineIndex] = line;
      final double chordBand = (!isTitleLine && !hasKotta)
          ? _lineChordBandHeight(line, lineFontSize)
          : 0;
      final List<_KottaRowLayout> lineKottaRows = hasKotta
          ? _buildKottaRows(
              line,
              lineFontSize,
              maxWidth,
              inheritedState: carryKottaState,
            )
          : const <_KottaRowLayout>[];
      final List<_TextRowLayout> lineTextRows = (!isTitleLine && !hasKotta)
          ? _buildTextRows(line, lineFontSize, maxWidth)
          : const <_TextRowLayout>[];
      final List<bool> lineHighlights = <bool>[];

      final List<InlineSpan> spans = <InlineSpan>[];
      for (int i = 0; i < line.words.length; i++) {
        final _WordToken word = line.words[i];

        // Update word index only on real word boundaries (spaceAfter), not syllable breaks or line starts.
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
              fontSize: lineFontSize,
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
    }

    double totalHeight = 0;
    for (int i = 0; i < painters.length; i++) {
      final TextPainter tp = painters[i];
      final bool titleToKottaTransition =
          hasTitleLine && i == 1 && hasKottaByLine[i];
      if (titleToKottaTransition) {
        totalHeight += _titleToKottaTransitionGap(
          nextLineFontSize: fontSize,
          titleHeight: painters[i - 1].height,
          lineSpacing: lineSpacing,
        );
      }
      if (hasKottaByLine[i]) {
        final int rows = math.max(1, kottaRowsByLine[i].length);
        final bool isTitleLine = hasTitleLine && i == 0;
        final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
        final double rowBlockHeight = _kottaRowBlockHeight(lineFontSize);
        totalHeight += rows * rowBlockHeight;
      } else {
        final bool isTitleLine = hasTitleLine && i == 0;
        if (isTitleLine) {
          totalHeight += chordBandByLine[i] + tp.height * lineSpacing;
        } else {
          final double lineFontSize = fontSize;
          final double textRowHeight = _textRowHeight(lineFontSize);
          final List<_TextRowLayout> rows = textRowsByLine[i];
          for (final _TextRowLayout row in rows) {
            totalHeight +=
                _rowChordBandHeight(allLines[i], row, lineFontSize) +
                textRowHeight * lineSpacing;
          }
        }
      }
    }
    double y = globals.vCenter ? (size.height - totalHeight) / 2 : 8;

    for (int painterIndex = 0; painterIndex < painters.length; painterIndex++) {
      final TextPainter tp = painters[painterIndex];
      final _RenderLine rline = allLines[painterIndex];
      final bool isTitleLine = hasTitleLine && painterIndex == 0;
      final bool hasKotta = hasKottaByLine[painterIndex];
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      final List<_KottaRowLayout> lineKottaRows = kottaRowsByLine[painterIndex];
      final double chordBand = chordBandByLine[painterIndex];
      final double lineStep = tp.height * lineSpacing;
      final List<_TextRowLayout> lineTextRows = textRowsByLine[painterIndex];

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
        final double rowStep = _kottaRowBlockHeight(lineFontSize);
        final double continuationIndent = globals.hCenter
            ? 0
            : _textContinuationIndent(
                lineFontSize,
                TextPainter(textDirection: TextDirection.ltr),
              );
        final double firstTextY =
            y + ledgerReserve + staffHeight + staffToTextGap;
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
          final double kottaBlockX = _kottaRowsStartX(
            lineKottaRows,
            size.width,
            continuationIndent,
          );
          for (int rowIndex = 0; rowIndex < lineKottaRows.length; rowIndex++) {
            final _KottaRowLayout row = lineKottaRows[rowIndex];
            final _KottaRowPrefix rowPrefix = rowPrefixes[rowIndex];
            final double rowY = firstTextY + rowIndex * rowStep;
            final double rowX =
                kottaBlockX +
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
          final double chordY =
              firstTextY + (lineKottaRows.length - 1) * rowStep;
          final _KottaRowPrefix lastRowPrefix =
              rowPrefixes[lineKottaRows.length - 1];
          final _KottaRowLayout lastRow =
              lineKottaRows[lineKottaRows.length - 1];
          final double lastRowX =
              kottaBlockX +
              _kottaContinuationIndent(
                lineKottaRows.length - 1,
                continuationIndent,
              );
          _paintChords(
            canvas,
            rline,
            lastRowX + lastRowPrefix.width + lastRow.inlinePrefix.width,
            chordY,
            lineFontSize,
          );
          y += lineKottaRows.length * rowStep;
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

      final double rowHeight = _textRowHeight(lineFontSize);
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
          rowX,
          textY,
          lineFontSize,
        );
        _paintChords(canvas, rowLine, rowX, textY, lineFontSize);
        y += rowChordBand + rowHeight * lineSpacing;
      }
    }
  }

  double _measureTextRequiredHeight(Size size, TextFrame frame) {
    double fontSize = globals.fontSize.toDouble();
    if (globals.autoResize) {
      while (fontSize > 8) {
        final double required = _measureTextRequiredHeightForFontSize(
          size,
          frame,
          fontSize,
        );
        if (required <= size.height * 0.95) {
          break;
        }
        fontSize -= 1;
      }
    }

    return _measureTextRequiredHeightForFontSize(size, frame, fontSize);
  }

  double _measureTextRequiredHeightForFontSize(
    Size size,
    TextFrame frame,
    double fontSize,
  ) {
    final double maxWidth = math.max(40, size.width);

    final bool hasTitleLine =
        !globals.hideTitle && frame.record.title.isNotEmpty;
    final List<String> sourceLines = <String>[
      if (hasTitleLine) frame.record.title,
      ...frame.record.lines,
    ];

    final List<_RenderLine> allLines = _parseRenderLines(sourceLines);

    final double titleFontSize = (globals.titleSize.toDouble() * 2.5).clamp(
      8.0,
      72.0,
    );
    final double lineSpacing = globals.spacing100 / 100.0;

    final List<List<_TextRowLayout>> textRowsByLine = <List<_TextRowLayout>>[];
    final List<bool> hasKottaByLine = <bool>[];
    final List<double> chordBandByLine = <double>[];
    final List<List<_KottaRowLayout>> kottaRowsByLine =
        <List<_KottaRowLayout>>[];
    final List<double> lineHeightsByLine = <double>[];
    final _KottaDrawState carryKottaState = _KottaDrawState();

    for (int lineIndex = 0; lineIndex < allLines.length; lineIndex++) {
      final _RenderLine baseLine = allLines[lineIndex];
      final bool isTitleLine = hasTitleLine && lineIndex == 0;
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      final bool hasKotta =
          !isTitleLine &&
          globals.useKotta &&
          settings.receiverUseKotta &&
          baseLine.words.any((w) => (w.kotta ?? '').isNotEmpty);
      final _RenderLine line = (!isTitleLine && !hasKotta)
          ? _applyChordPadding(baseLine, lineFontSize)
          : baseLine;
      allLines[lineIndex] = line;

      final double chordBand = (!isTitleLine && !hasKotta)
          ? _lineChordBandHeight(line, lineFontSize)
          : 0;
      final List<_KottaRowLayout> lineKottaRows = hasKotta
          ? _buildKottaRows(
              line,
              lineFontSize,
              maxWidth,
              inheritedState: carryKottaState,
            )
          : const <_KottaRowLayout>[];
      final List<_TextRowLayout> lineTextRows = (!isTitleLine && !hasKotta)
          ? _buildTextRows(line, lineFontSize, maxWidth)
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

    double totalHeight = 0;
    for (int i = 0; i < allLines.length; i++) {
      final bool titleToKottaTransition =
          hasTitleLine && i == 1 && hasKottaByLine[i];
      if (titleToKottaTransition) {
        totalHeight += _titleToKottaTransitionGap(
          nextLineFontSize: fontSize,
          titleHeight: lineHeightsByLine[i - 1],
          lineSpacing: lineSpacing,
        );
      }

      if (hasKottaByLine[i]) {
        final int rows = math.max(1, kottaRowsByLine[i].length);
        final bool isTitleLine = hasTitleLine && i == 0;
        final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
        final double rowBlockHeight = _kottaRowBlockHeight(lineFontSize);
        totalHeight += rows * rowBlockHeight;
      } else {
        final bool isTitleLine = hasTitleLine && i == 0;
        if (isTitleLine) {
          totalHeight +=
              chordBandByLine[i] + lineHeightsByLine[i] * lineSpacing;
        } else {
          final double lineFontSize = fontSize;
          final List<_TextRowLayout> rows = textRowsByLine[i];
          for (final _TextRowLayout row in rows) {
            totalHeight +=
                _rowChordBandHeight(allLines[i], row, lineFontSize) +
                _measureTextRowHeight(allLines[i], lineFontSize) * lineSpacing;
          }
        }
      }
    }

    return totalHeight;
  }

  double _lineChordBandHeight(_RenderLine line, double fontSize) {
    if (!globals.useAkkord ||
        !settings.receiverUseAkkord ||
        !line.words.any((w) => (w.chord ?? '').isNotEmpty)) {
      return 0;
    }
    return _chordBandHeightForFont(fontSize);
  }

  double _chordBandHeightForFont(double fontSize) {
    final TextPainter chordMeasure = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: fontSize * (globals.akkordArany / 100.0),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return chordMeasure.height + 2;
  }

  double _rowChordBandHeight(
    _RenderLine line,
    _TextRowLayout row,
    double fontSize,
  ) {
    if (!globals.useAkkord || !settings.receiverUseAkkord) {
      return 0;
    }
    for (final int wi in row.wordIndices) {
      if (wi >= 0 &&
          wi < line.words.length &&
          (line.words[wi].chord ?? '').isNotEmpty) {
        return _chordBandHeightForFont(fontSize);
      }
    }
    return 0;
  }

  double _textRowHeight(double fontSize) {
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
    return measure.height;
  }

  double _measureTextRowHeight(_RenderLine line, double fontSize) {
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final _WordToken word in line.words) {
      final Color baseColor = word.color ?? globals.txtColor;
      spans.add(
        TextSpan(
          text: word.text + (word.spaceAfter ? ' ' : ''),
          style: TextStyle(
            color: baseColor,
            fontSize: fontSize,
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
    return tp.height;
  }

  void _paintTextRow(
    Canvas canvas,
    _RenderLine rowLine,
    List<bool> rowHighlights,
    double x,
    double y,
    double fontSize,
  ) {
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int i = 0; i < rowLine.words.length; i++) {
      final _WordToken word = rowLine.words[i];
      final bool highlighted = i < rowHighlights.length
          ? rowHighlights[i]
          : false;
      final Color baseColor = word.color ?? globals.txtColor;
      spans.add(
        TextSpan(
          text: word.text + (word.spaceAfter ? ' ' : ''),
          style: TextStyle(
            color: highlighted ? globals.hiColor : baseColor,
            fontSize: fontSize,
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
    tp.paint(canvas, Offset(x, y));
  }

  _RenderLine _applyChordPadding(_RenderLine line, double fontSize) {
    if (!globals.useAkkord ||
        !settings.receiverUseAkkord ||
        line.words.isEmpty) {
      return line;
    }

    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    bool changed = false;
    final List<_WordToken> padded = <_WordToken>[];

    for (final _WordToken word in line.words) {
      final String chordText = (word.chord ?? '').trim();
      if (chordText.isEmpty) {
        padded.add(word);
        continue;
      }

      measure.text = TextSpan(
        text: word.text + (word.spaceAfter ? ' ' : ''),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: (globals.boldText || word.bold)
              ? FontWeight.bold
              : FontWeight.normal,
          fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
        ),
      );
      measure.layout();
      double textWidth = measure.width;

      measure.text = TextSpan(
        text: chordText,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: fontSize * (globals.akkordArany / 100.0),
        ),
      );
      measure.layout();
      final double chordWidth = measure.width;

      if (textWidth + 1 >= chordWidth) {
        padded.add(word);
        continue;
      }

      String paddedText = word.text;
      int guard = 0;
      while (textWidth + 1 < chordWidth && guard < 24) {
        paddedText = '${paddedText}_';
        measure.text = TextSpan(
          text: paddedText + (word.spaceAfter ? ' ' : ''),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: (globals.boldText || word.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
          ),
        );
        measure.layout();
        textWidth = measure.width;
        guard++;
      }

      if (paddedText != word.text) {
        changed = true;
        padded.add(
          _WordToken(
            text: paddedText,
            bold: word.bold,
            italic: word.italic,
            underline: word.underline,
            strike: word.strike,
            color: word.color,
            chord: word.chord,
            kotta: word.kotta,
            spaceAfter: word.spaceAfter,
          ),
        );
      } else {
        padded.add(word);
      }
    }

    if (!changed) {
      return line;
    }
    return _RenderLine(words: padded);
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
      final String display = w.text + (w.spaceAfter ? ' ' : '');
      measure.text = TextSpan(
        text: display,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: (globals.boldText || w.bold)
              ? FontWeight.bold
              : FontWeight.normal,
          fontStyle: w.italic ? FontStyle.italic : FontStyle.normal,
        ),
      );
      measure.layout();
      if ((w.chord ?? '').isNotEmpty) {
        final TextPainter chord = TextPainter(
          text: TextSpan(
            text: w.chord,
            style: TextStyle(
              color: globals.txtColor,
              fontWeight: FontWeight.w600,
              fontSize: fontSize * (globals.akkordArany / 100),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        chord.paint(canvas, Offset(cx, y - chord.height - 2));
      }
      cx += measure.width;
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

    final Paint staffPaint = Paint()
      ..color = globals.txtColor
      ..strokeWidth = 1;

    final _KottaDrawState lineState = _KottaDrawState();
    lineState.deferFinalDoubleBarAtEnd = _lineEndsWithDoubleBar(line);
    final List<_KottaRowPrefix> rowPrefixes = _resolveKottaRowPrefixes(
      rows,
      line,
      lineGap,
    );
    final double blockStartX = _kottaRowsStartX(
      rows,
      sizeWidth,
      continuationIndent,
    );
    final double baseTop = firstTextY - staffHeight - staffToTextGap;
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final _KottaRowLayout row = rows[rowIndex];
      final _KottaRowPrefix rowPrefix = rowPrefixes[rowIndex];
      final double rowX =
          blockStartX + _kottaContinuationIndent(rowIndex, continuationIndent);
      final double rowTop = baseTop + rowIndex * rowStep;
      for (int i = 0; i < 5; i++) {
        final double ly = rowTop + i * lineGap;
        canvas.drawLine(
          Offset(rowX, ly),
          Offset(rowX + row.width, ly),
          staffPaint,
        );
      }

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
        }
        if (isFirstSlot && row.inlinePrefix.kotta.isNotEmpty) {
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
        cx += slot.slotWidth;
      }

      if (rowIndex < rows.length - 1) {
        _endBeam(canvas, lineState, lineGap);
        _endTuplet(canvas, lineState, lineGap);
        _endSlur(canvas, lineState, lineGap);
      }
    }

    if (lineState.deferFinalDoubleBarAtEnd) {
      final _KottaRowLayout last = rows.last;
      final double lastX =
          blockStartX +
          _kottaContinuationIndent(rows.length - 1, continuationIndent);
      final double lastTop = baseTop + (rows.length - 1) * rowStep;
      _drawForcedClosingBarline(canvas, lastX + last.width, lastTop, lineGap);
    }

    _endBeam(canvas, lineState, lineGap);
    _endTuplet(canvas, lineState, lineGap);
    _endSlur(canvas, lineState, lineGap);
  }

  double _kottaLineGap(double fontSize) {
    return (fontSize * 0.22 * (globals.kottaArany / 100.0)).clamp(2.0, 10.0);
  }

  double _kottaStaffHeight(double lineGap) {
    return lineGap * 4;
  }

  double _kottaLedgerReserve(double lineGap) {
    return lineGap * 2;
  }

  double _kottaStaffToTextGap(double lineGap) {
    return math.max(2.0, lineGap * 0.35);
  }

  double _kottaRowBlockHeight(double fontSize) {
    final double lineGap = _kottaLineGap(fontSize);
    return _kottaLedgerReserve(lineGap) +
        _kottaStaffHeight(lineGap) +
        _kottaStaffToTextGap(lineGap) +
        _kottaRowTextHeight(fontSize) +
        _kottaLedgerReserve(lineGap);
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
    return measure.height;
  }

  double _kottaRowStartX(
    double rowWidth,
    double sizeWidth,
    double horizontalPad,
  ) {
    if (!globals.hCenter) {
      return 0;
    }
    return (sizeWidth - rowWidth) / 2.0;
  }

  double _kottaRowsStartX(
    List<_KottaRowLayout> rows,
    double sizeWidth,
    double horizontalPad,
  ) {
    if (rows.isEmpty) {
      return _kottaRowStartX(0, sizeWidth, horizontalPad);
    }
    final double blockWidth = rows.fold<double>(
      0,
      (double maxWidth, _KottaRowLayout row) => math.max(maxWidth, row.width),
    );
    return _kottaRowStartX(blockWidth, sizeWidth, horizontalPad);
  }

  double _kottaContinuationIndent(int rowIndex, double horizontalPad) {
    if (rowIndex <= 0) {
      return 0;
    }
    return horizontalPad;
  }

  double _debugCenteredKottaStartX(
    _KottaRowLayout row,
    _RenderLine line,
    double fontSize,
    double rowX,
  ) {
    if (row.words.isEmpty) {
      return rowX;
    }
    final _KottaWordLayout firstSlot = row.words.first;
    final String kotta = (line.words[firstSlot.wordIndex].kotta ?? '').trim();
    if (kotta.isEmpty) {
      return rowX;
    }
    final double lineGap = _kottaLineGap(fontSize);
    final double rawWidth = _kottaRawWidth(kotta, lineGap, _KottaDrawState());
    return rowX + (firstSlot.slotWidth - rawWidth) / 2.0;
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
    for (int slotIndex = 0; slotIndex < row.words.length; slotIndex++) {
      final _KottaWordLayout slot = row.words[slotIndex];
      final _WordToken w = line.words[slot.wordIndex];
      final bool highlighted = slot.wordIndex < highlights.length
          ? highlights[slot.wordIndex]
          : false;
      final Color baseColor = w.color ?? globals.txtColor;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: w.text + (w.spaceAfter ? ' ' : ''),
          style: TextStyle(
            color: highlighted ? globals.hiColor : baseColor,
            fontSize: fontSize,
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
      final double inset = slotIndex == 0 ? leadingInset : 0;
      tp.paint(canvas, Offset(cx + inset, y));
      cx += slot.slotWidth + inset;
    }
  }

  List<_KottaRowLayout> _buildKottaRows(
    _RenderLine line,
    double fontSize,
    double maxWidth, {
    _KottaDrawState? inheritedState,
  }) {
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    final double lineGap = _kottaLineGap(fontSize);
    final double wrapWidth = math.max(8.0, maxWidth);
    final double continuationIndent = globals.hCenter
        ? 0
        : _textContinuationIndent(fontSize, measure);
    final _KottaDrawState state = inheritedState?.copy() ?? _KottaDrawState();
    state.deferFinalDoubleBarAtEnd = _lineEndsWithDoubleBar(line);

    final List<_KottaRowLayout> rows = <_KottaRowLayout>[];
    final List<_KottaWordLayout> currentWords = <_KottaWordLayout>[];
    final List<_KottaWordLayout> pendingWord = <_KottaWordLayout>[];
    _KottaRowPrefix currentPrefix = _lineRequestsCarryPrefix(line)
        ? _kottaRowPrefixForState(state, lineGap)
        : const _KottaRowPrefix.empty();
    _KottaDrawState? pendingWordStartState;
    double currentWidth = currentPrefix.width;
    double pendingWordWidth = 0;

    for (int i = 0; i < line.words.length; i++) {
      pendingWordStartState ??= state.copy();
      final _WordToken w = line.words[i];
      final double textWidth = _measureWordDisplayWidth(w, fontSize, measure);
      final String kotta = (w.kotta ?? '').trim();
      final double kottaWidth = kotta.isEmpty
          ? 0
          : _kottaRawWidth(kotta, lineGap, state);
      final double slotWidth = math.max(textWidth, kottaWidth);

      pendingWord.add(_KottaWordLayout(wordIndex: i, slotWidth: slotWidth));
      pendingWordWidth += slotWidth;

      final bool endsWord = w.spaceAfter || i == line.words.length - 1;
      if (!endsWord) {
        continue;
      }

      final double currentRowLimit = rows.isEmpty
          ? wrapWidth
          : math.max(8.0, wrapWidth - continuationIndent);
      if (currentWords.isNotEmpty &&
          (currentWidth + pendingWordWidth) > currentRowLimit) {
        rows.add(
          _KottaRowLayout(
            words: List<_KottaWordLayout>.from(currentWords),
            width: currentWidth,
            prefix: currentPrefix,
          ),
        );
        currentWords.clear();
        currentPrefix = _kottaRowPrefixForState(pendingWordStartState, lineGap);
        currentWidth = currentPrefix.width;
      }

      currentWords.addAll(pendingWord);
      currentWidth += pendingWordWidth;
      pendingWord.clear();
      pendingWordWidth = 0;
      pendingWordStartState = null;
    }

    if (currentWords.isNotEmpty) {
      rows.add(
        _KottaRowLayout(
          words: List<_KottaWordLayout>.from(currentWords),
          width: currentWidth,
          prefix: currentPrefix,
        ),
      );
    }

    return _applyKottaRowPrefixes(rows, line, lineGap, fontSize);
  }

  List<_KottaRowLayout> _applyKottaRowPrefixes(
    List<_KottaRowLayout> rows,
    _RenderLine line,
    double lineGap,
    double fontSize,
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

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final _KottaRowLayout row = rows[rowIndex];
      final _KottaRowPrefix prefix = prefixes[rowIndex];
      List<_KottaWordLayout> effectiveWords = row.words;
      _KottaRowPrefix inlinePrefix = const _KottaRowPrefix.empty();

      if (rowIndex == 0 && prefix.kotta.isEmpty && row.words.isNotEmpty) {
        final _KottaWordLayout firstSlot = row.words.first;
        final _WordToken firstWord = line.words[firstSlot.wordIndex];
        final String firstKotta = (firstWord.kotta ?? '').trim();
        final String leadingKotta = _leadingInlineKottaPrefix(firstKotta);
        if (leadingKotta.isNotEmpty) {
          final double fullKottaWidth = _kottaRawWidth(
            firstKotta,
            lineGap,
            _KottaDrawState(),
          );
          final double leadingWidth = _kottaRawWidth(
            leadingKotta,
            lineGap,
            _KottaDrawState(),
          );
          final double remainingKottaWidth = math.max(
            0,
            fullKottaWidth - leadingWidth,
          );
          final double textWidth = _measureWordDisplayWidth(
            firstWord,
            fontSize,
            measure,
          );
          final List<_KottaWordLayout> adjustedWords =
              List<_KottaWordLayout>.from(row.words);
          adjustedWords[0] = _KottaWordLayout(
            wordIndex: firstSlot.wordIndex,
            slotWidth: math.max(textWidth, remainingKottaWidth),
          );
          effectiveWords = adjustedWords;
          inlinePrefix = _KottaRowPrefix(
            kotta: leadingKotta,
            width: leadingWidth,
          );
        }
      }

      final double contentWidth = effectiveWords.fold<double>(
        0,
        (double sum, _KottaWordLayout slot) => sum + slot.slotWidth,
      );
      resolvedRows.add(
        _KottaRowLayout(
          words: effectiveWords,
          width: prefix.width + inlinePrefix.width + contentWidth,
          prefix: prefix,
          inlinePrefix: inlinePrefix,
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
    state.deferFinalDoubleBarAtEnd = _lineEndsWithDoubleBar(line);
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

  bool _lineRequestsCarryPrefix(_RenderLine line) {
    for (final _WordToken word in line.words) {
      final String kotta = (word.kotta ?? '').trim();
      if (kotta.isEmpty) {
        continue;
      }
      final List<String> cmds = _parseKottaCommands(kotta);
      if (cmds.isEmpty) {
        continue;
      }
      return cmds.first[0] == '-';
    }
    return false;
  }

  void _advanceKottaStateForLine(
    _RenderLine line,
    double lineGap,
    _KottaDrawState state,
  ) {
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
    double maxWidth,
  ) {
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
    double currentWidth = 0;

    for (int i = 0; i < line.words.length; i++) {
      final _WordToken w = line.words[i];
      final double slotWidth = _measureWordDisplayWidth(w, fontSize, measure);
      final double currentRowLimit = rows.isEmpty
          ? wrapWidth
          : math.max(8.0, wrapWidth - continuationIndent);
      if (currentWordIndices.isNotEmpty &&
          (currentWidth + slotWidth) > currentRowLimit) {
        rows.add(
          _TextRowLayout(
            wordIndices: List<int>.from(currentWordIndices),
            width: currentWidth,
            indentWidth: rows.isEmpty ? 0 : continuationIndent,
          ),
        );
        currentWordIndices.clear();
        currentWidth = 0;
      }

      currentWordIndices.add(i);
      currentWidth += slotWidth;
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
    final String display = word.text + (word.spaceAfter ? ' ' : '');
    measure.text = TextSpan(
      text: display,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: (globals.boldText || word.bold)
            ? FontWeight.bold
            : FontWeight.normal,
        fontStyle: word.italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
    measure.layout();
    return measure.width;
  }

  double _kottaRawWidth(String kotta, double lineGap, _KottaDrawState state) {
    double width = 0;
    for (final String cmd in _parseKottaCommands(kotta)) {
      width += _kottaWidthOf(cmd, lineGap, state);
    }
    return width;
  }

  bool _lineEndsWithDoubleBar(_RenderLine line) {
    for (int i = line.words.length - 1; i >= 0; i--) {
      final String kotta = (line.words[i].kotta ?? '').trim();
      if (kotta.isEmpty) {
        continue;
      }
      final List<String> cmds = _parseKottaCommands(kotta);
      if (cmds.isEmpty) {
        continue;
      }
      final String last = cmds.last;
      return last.length == 2 && last[0] == '|' && last[1] == '|';
    }
    return false;
  }

  void _drawForcedClosingBarline(
    Canvas canvas,
    double endX,
    double top,
    double lineGap,
  ) {
    final Paint thin = Paint()
      ..color = globals.txtColor
      ..strokeWidth = 1.2;
    final Paint thick = Paint()
      ..color = globals.txtColor
      ..strokeWidth = 2.2;

    final double y1 = top;
    final double y2 = top + lineGap * 4;
    final double xThin = endX + lineGap * 0.35;
    final double xThick = endX + lineGap * 0.65;

    canvas.drawLine(Offset(xThin, y1), Offset(xThin, y2), thin);
    canvas.drawLine(Offset(xThick, y1), Offset(xThick, y2), thick);
  }

  void _drawSimpleKotta(
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
      return;
    }

    final double lineGap = lineGapOverride ?? _kottaLineGap(fontSize);
    final double staffHeight = _kottaStaffHeight(lineGap);
    final double top = textTopY - staffHeight - _kottaStaffToTextGap(lineGap);
    final _KottaDrawState measureState = (state ?? _KottaDrawState()).copy();

    double rawWidth = 0.0;
    for (final String c in cmds) {
      rawWidth += _kottaWidthOf(c, lineGap, measureState);
    }
    if (rawWidth <= 0) {
      return;
    }
    const double scale = 1.0;
    final double startX = x + (wordWidth - rawWidth) / 2.0;
    final _KottaDrawState drawState = state ?? _KottaDrawState();

    if (drawStaff) {
      final Paint staffPaint = Paint()
        ..color = globals.txtColor
        ..strokeWidth = 1;
      for (int i = 0; i < 5; i++) {
        final double y = top + i * lineGap;
        canvas.drawLine(Offset(x, y), Offset(x + wordWidth, y), staffPaint);
      }
    }

    double cx = startX;
    for (final String c in cmds) {
      final _KottaDrawState widthState = drawState.copy();
      final double cw = _kottaWidthOf(c, lineGap, widthState) * scale;
      _drawKottaCommand(canvas, c, drawState, cx, top, lineGap, scale);
      cx += cw;
    }
    if (state == null) {
      _endBeam(canvas, drawState, lineGap);
      _endTuplet(canvas, drawState, lineGap);
      _endSlur(canvas, drawState, lineGap);
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
      return 0;
    }
    if (c1 == 'm') {
      state.modosito = c2;
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
      switch (state.ritmus) {
        case 'l':
          w += _kcHang0W * lineGap / (_kcHang0V2a - _kcHang0V2f);
          break;
        case 'b':
          w +=
              _kcHangBrevis1W *
              lineGap /
              (_kcHangBrevis1V2a - _kcHangBrevis1V2f);
          break;
        case 's':
          w +=
              _kcHangBrevis2W *
              lineGap /
              (_kcHangBrevis2V2a - _kcHangBrevis2V2f);
          break;
        case '1':
          w += _kcHang1W * lineGap / (_kcHang1V2a - _kcHang1V2f);
          break;
        case '2':
          w += _kcHang2W * lineGap / (_kcHang2V2a - _kcHang2V2f);
          break;
        default:
          w += _kcHang4W * lineGap / (_kcHang4V2a - _kcHang4V2f);
          break;
      }
      if (state.pontozott) {
        w +=
            (state.tomor ? 0.0 : minWidth / 8.0) +
            _kcPontW * lineGap / _kcPontV;
      }
      return w;
    }
    if (c1 == '|') {
      if (c2 == ':' || c2 == '<' || c2 == '>') {
        return minWidth * (c2 == ':' ? 3.0 : 2.0);
      }
      return minWidth;
    }
    return minWidth * 0.5;
  }

  double _kottaMinWidth(double lineGap) {
    return _kcHang4W * lineGap / (_kcHang4V2a - _kcHang4V2f);
  }

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
    double scale,
  ) {
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
      return;
    }

    if (c1 == 'k') {
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
          y0 = _linePos(top, lineGap, 6 - (int.parse(c2) - 1));
        } else if ('abcdefghi'.contains(c2)) {
          w = _kcDkulcsW;
          h = _kcDkulcsH;
          v1 = _kcDkulcsV1;
          v5 = _kcDkulcsV2;
          y0 =
              _linePos(top, lineGap, 7) -
              lineGap * 0.5 * (1 + ('abcdefghi'.indexOf(c2)));
        }
        final double rat = (lineGap * 4.0) / (v1 - v5);
        final double y1 = y0 - v5 * rat;
        final double x2 = x + w * rat;
        final double y2 = y1 + h * rat;
        _drawKottaAsset(canvas, clefName, Rect.fromLTRB(x, y1, x2, y2));
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
      _endBeam(canvas, state, lineGap);
      final String? meter = switch ('$c1$c2') {
        'u2' => 'u24',
        'u3' => 'u34',
        'u4' => 'u44',
        'u5' => 'u54',
        'u6' => 'u64',
        'U2' => 'u22',
        'U3' => 'u32',
        'U6' => 'u68',
        'U8' => 'u38',
        _ => null,
      };
      if (meter != null) {
        _drawKottaAsset(
          canvas,
          meter,
          Rect.fromLTWH(x + lineGap * 0.3, top, lineGap * 1.1, lineGap * 4.2),
        );
      }
      return;
    }
    if (c1 == 'm') {
      state.modosito = c2;
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
      double x1 = x + mw * 0.5;
      if (state.modosito != ' ') {
        final String? modName = switch (state.modosito) {
          '0' => 'feloldo',
          'k' => 'kereszt',
          'K' => 'kettoskereszt',
          'b' => 'be',
          'B' => 'bebe',
          _ => null,
        };
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
        if (modName != null) {
          _drawKottaAsset(canvas, modName, Rect.fromLTRB(x1, y1m, x2m, y2m));
        }
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
      final double nrat = lineGap / (nva - nvf);
      final double ny1 =
          _linePos(top, lineGap, l1) - ((l1 == l2) ? nvv : nva) * nrat;
      final double nx2 = x1 + nw * nrat;
      final double ny2 = ny1 + nh * nrat;
      final double nx = (x1 + nx2) / 2.0;
      final double cy = (ny1 + ny2) / 2.0;
      final double noteW = (nx2 - x1);

      final bool drewHead = _drawKottaAsset(
        canvas,
        noteName,
        Rect.fromLTRB(x1, ny1, nx2, ny2),
      );
      if (!drewHead) {
        final Paint notePaint = Paint()..color = globals.txtColor;
        canvas.drawOval(Rect.fromLTRB(x1, ny1, nx2, ny2), notePaint);
      }

      // Ledger lines for notes outside the 5-line staff.
      final Paint ledgerPaint = Paint()
        ..color = globals.txtColor
        ..strokeWidth = 1.0;
      final double lx1 = nx - noteW * 0.75;
      final double lx2 = nx + noteW * 0.75;
      if (pos.centerIndex >= 8.0) {
        for (double idx = 8.0; idx <= pos.centerIndex; idx += 1.0) {
          final double ly = top + (idx - 3.0) * lineGap;
          canvas.drawLine(Offset(lx1, ly), Offset(lx2, ly), ledgerPaint);
        }
      }
      if (pos.centerIndex <= 2.0) {
        for (double idx = 2.0; idx >= pos.centerIndex; idx -= 1.0) {
          final double ly = top + (idx - 3.0) * lineGap;
          canvas.drawLine(Offset(lx1, ly), Offset(lx2, ly), ledgerPaint);
        }
      }

      final bool stemDown = c2.toUpperCase() == c2;
      if (state.ritmus == '2' ||
          state.ritmus == '4' ||
          state.ritmus == '8' ||
          state.ritmus == '6') {
        final double stemX = stemDown ? x1 : nx2;
        final double stemY2 = stemDown
            ? cy + lineGap * 3.2
            : cy - lineGap * 3.2;
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
            ),
          );
        } else {
          final Paint stemPaint = Paint()
            ..color = globals.txtColor
            ..strokeWidth = 1.2;
          canvas.drawLine(Offset(stemX, cy), Offset(stemX, stemY2), stemPaint);
          if (state.ritmus == '8' || state.ritmus == '6') {
            final String flgName = stemDown
                ? (state.ritmus == '6' ? 'zaszlo16le' : 'zaszlo8le')
                : (state.ritmus == '6' ? 'zaszlo16fel' : 'zaszlo8fel');
            final Rect fr = _flagRect(
              stemX,
              stemY2,
              lineGap,
              stemDown,
              state.ritmus,
            );
            _drawKottaAsset(canvas, flgName, fr);
          }
        }
      }

      _trackSlurPoint(state, Offset(nx, cy));
      _trackTupletPoint(state, Offset(nx, cy), stemDown, lineGap);

      if (state.pontozott) {
        _drawKottaAsset(
          canvas,
          'pont',
          Rect.fromLTWH(
            nx2 + mw / 8.0,
            cy - lineGap * 0.16,
            lineGap * 0.32,
            lineGap * 0.32,
          ),
        );
      }

      state.modosito = ' ';
      return;
    }
    if (c1 == '|') {
      _endBeam(canvas, state, lineGap);
      if (c2 == '|' && state.deferFinalDoubleBarAtEnd) {
        return;
      }
      final Paint barPaint = Paint()
        ..color = globals.txtColor
        ..strokeWidth = 1.2;
      if (c2 == '1' || c2 == '|') {
        if (c2 == '|') {
          canvas.drawLine(
            Offset(x + lineGap * 0.8, top),
            Offset(x + lineGap * 0.8, top + lineGap * 4),
            barPaint,
          );
          canvas.drawLine(
            Offset(x + lineGap * 1.2, top),
            Offset(x + lineGap * 1.2, top + lineGap * 4),
            barPaint,
          );
        } else {
          canvas.drawLine(
            Offset(x + lineGap, top),
            Offset(x + lineGap, top + lineGap * 4),
            barPaint,
          );
        }
      } else if (c2 == '.') {
        canvas.drawLine(
          Offset(x + lineGap * 0.8, top),
          Offset(x + lineGap * 0.8, top + lineGap * 4),
          barPaint,
        );
        canvas.drawLine(
          Offset(x + lineGap * 1.2, top),
          Offset(x + lineGap * 1.2, top + lineGap * 4),
          barPaint..strokeWidth = 2.0,
        );
      } else if (c2 == "'") {
        final double x0 = x + lineGap;
        final double y1 = top - lineGap * 0.5;
        final double y2 = y1 + lineGap;
        canvas.drawLine(Offset(x0, y1), Offset(x0, y2), barPaint);
      } else {
        canvas.drawLine(
          Offset(x + lineGap, top),
          Offset(x + lineGap, top + lineGap * 4),
          barPaint,
        );
      }
      return;
    }
    if (c1 == 's' || c1 == 'S') {
      _endBeam(canvas, state, lineGap);
      final String? restName = switch (c2) {
        '1' => 'szunet1',
        '2' => 'szunet2',
        '4' => 'szunet4',
        '8' => 'szunet8',
        '6' => 'szunet16',
        _ => null,
      };
      if (restName != null) {
        _drawKottaAsset(
          canvas,
          restName,
          Rect.fromLTWH(
            x + lineGap * 0.3,
            top + lineGap * 0.6,
            lineGap * 1.4,
            lineGap * 2.6,
          ),
        );
        if (c1 == 'S') {
          _drawKottaAsset(
            canvas,
            'pont',
            Rect.fromLTWH(
              x + lineGap * 1.9,
              top + lineGap * 2.1,
              lineGap * 0.35,
              lineGap * 0.35,
            ),
          );
        }
      }
    }
  }

  void _trackSlurPoint(_KottaDrawState state, Offset noteCenter) {
    if (state.slurType != ' ') {
      state.slurEnd = noteCenter;
      return;
    }
    state.slurStart = noteCenter;
    state.slurEnd = noteCenter;
    if (state.slurNext != ' ') {
      state.slurType = state.slurNext;
      state.slurNext = ' ';
    }
  }

  void _endSlur(
    Canvas canvas,
    _KottaDrawState state,
    double lineGap, {
    String? forcedType,
  }) {
    final String t = forcedType ?? state.slurType;
    if (state.slurStart == null || state.slurEnd == null || t == ' ') {
      state.slurType = ' ';
      state.slurNext = ' ';
      return;
    }
    final Offset s = state.slurStart!;
    final Offset e = state.slurEnd!;
    final bool down = t.toLowerCase() == 'a';
    final double dy = down ? lineGap * 1.1 : -lineGap * 1.1;
    final Offset c1 = Offset((s.dx * 3 + e.dx) / 4, (s.dy + e.dy) / 2 + dy);
    final Offset c2 = Offset((s.dx + e.dx * 3) / 4, (s.dy + e.dy) / 2 + dy);
    final Path p = Path()
      ..moveTo(s.dx, s.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy)
      ..cubicTo(
        c2.dx,
        c2.dy + (down ? -lineGap * 0.25 : lineGap * 0.25),
        c1.dx,
        c1.dy + (down ? -lineGap * 0.25 : lineGap * 0.25),
        s.dx,
        s.dy,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = globals.txtColor);
    state.slurType = ' ';
    state.slurNext = ' ';
    state.slurStart = null;
    state.slurEnd = null;
  }

  void _trackTupletPoint(
    _KottaDrawState state,
    Offset noteCenter,
    bool stemDown,
    double lineGap,
  ) {
    if (state.triTipus != '3' && state.triTipus != '5') {
      return;
    }
    state.triLe = stemDown;
    final double y = stemDown
        ? noteCenter.dy + lineGap * 2.8
        : noteCenter.dy - lineGap * 2.8;
    state.triPos.add(Offset(noteCenter.dx, y));
  }

  void _endTuplet(Canvas canvas, _KottaDrawState state, double lineGap) {
    final bool tri = state.triTipus == '3';
    final bool pent = state.triTipus == '5';
    if (!tri && !pent) {
      return;
    }
    if (state.triPos.length < 2) {
      state.triTipus = ' ';
      state.triPos.clear();
      return;
    }
    final Offset lp = state.triPos.first;
    final Offset rp = state.triPos.last;
    final Paint p = Paint()
      ..color = globals.txtColor
      ..strokeWidth = 1.0;
    canvas.drawLine(lp, rp, p);
    final String img = tri ? 'triola' : 'pentola';
    final Offset m = Offset(
      (lp.dx + rp.dx) / 2,
      (lp.dy + rp.dy) / 2 + (state.triLe ? lineGap * 0.2 : -lineGap * 0.9),
    );
    _drawKottaAsset(
      canvas,
      img,
      Rect.fromCenter(center: m, width: lineGap * 0.9, height: lineGap * 1.2),
    );
    state.triTipus = ' ';
    state.triPos.clear();
  }

  void _endBeam(Canvas canvas, _KottaDrawState state, double lineGap) {
    if (state.beamStems.length < 2) {
      if (state.beamStems.length == 1) {
        final _BeamStem s = state.beamStems.first;
        canvas.drawLine(
          Offset(s.x, s.yHead),
          Offset(s.x, s.yTip),
          Paint()
            ..color = globals.txtColor
            ..strokeWidth = 1.2,
        );
        _drawStandaloneFlag(canvas, s, lineGap);
      }
      state.beamStems.clear();
      return;
    }
    final List<_BeamStem> stems = state.beamStems;
    final _BeamStem first = stems.first;
    final _BeamStem last = stems.last;
    final bool down = first.down;
    final double beamThickness = lineGap * 0.45;
    final Paint beamPaint = Paint()
      ..color = globals.txtColor
      ..strokeWidth = beamThickness;
    canvas.drawLine(
      Offset(first.x, first.yTip),
      Offset(last.x, last.yTip),
      beamPaint,
    );

    final double dx = last.x - first.x;
    for (final _BeamStem s in stems) {
      double yBeam = first.yTip;
      if (dx.abs() > 0.0001) {
        yBeam = first.yTip + (last.yTip - first.yTip) * ((s.x - first.x) / dx);
      }
      final double yEnd = down
          ? yBeam - beamThickness / 2
          : yBeam + beamThickness / 2;
      canvas.drawLine(
        Offset(s.x, s.yHead),
        Offset(s.x, yEnd),
        Paint()
          ..color = globals.txtColor
          ..strokeWidth = 1.2,
      );
    }

    final bool has16 = stems.any((s) => s.rhythm == '6');
    if (has16) {
      final double off = down ? lineGap * 0.55 : -lineGap * 0.55;
      canvas.drawLine(
        Offset(first.x, first.yTip + off),
        Offset(last.x, last.yTip + off),
        beamPaint,
      );
    }
    state.beamStems.clear();
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
    final double stemWidth = _kcZaszloSzel * rat;
    final bool is16 = rhythm == '6';
    if (down) {
      final double w = _kcZaszlo8leW * rat;
      final double h = (is16 ? _kcZaszlo16leH : _kcZaszlo8leH) * rat;
      // Android parity: lower stem uses stem tip as flag bottom anchor.
      return Rect.fromLTWH(stemX, stemYTip - h, w, h);
    }
    final double w = _kcZaszlo8felW * rat;
    final double h = (is16 ? _kcZaszlo16felH : _kcZaszlo8felH) * rat;
    // Android parity: upper stem starts one stem-width left, with flag top at stem tip.
    return Rect.fromLTWH(stemX - stemWidth, stemYTip, w, h);
  }

  bool _drawKottaAsset(Canvas canvas, String assetName, Rect dst) {
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
      ..colorFilter = ColorFilter.mode(globals.txtColor, BlendMode.srcIn);
    canvas.drawImageRect(img, src, dst, p);
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
    final List<_RenderLine> out = <_RenderLine>[];
    for (final String line in lines) {
      out.addAll(_parseOneLine(line));
    }
    return out;
  }

  List<_RenderLine> _parseOneLine(String src) {
    final List<_RenderLine> result = <_RenderLine>[];
    final List<_WordToken> words = <_WordToken>[];
    final _WordStyle style = _WordStyle();
    final StringBuffer sb = StringBuffer();
    String? pendingChord;
    String? pendingKotta;

    void attachPendingToPrevWord() {
      if (words.isEmpty) {
        return;
      }
      if ((pendingChord == null || pendingChord!.isEmpty) &&
          (pendingKotta == null || pendingKotta!.isEmpty)) {
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
          strike: last.strike,
          color: last.color,
          chord: mergedChord,
          kotta: mergedKotta,
          spaceAfter: last.spaceAfter,
        ),
      );
      pendingChord = null;
      pendingKotta = null;
    }

    void markPrevSpaceAfter() {
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
          strike: last.strike,
          color: last.color,
          chord: last.chord,
          kotta: last.kotta,
          spaceAfter: true,
        ),
      );
    }

    void flushWord({bool addSpaceAfter = false}) {
      final String txt = sb.toString();
      sb.clear();
      if (txt.trim().isEmpty) {
        return;
      }
      words.add(
        _WordToken(
          text: txt,
          bold: style.bold,
          italic: style.italic,
          underline: style.underline,
          strike: style.strike,
          color: style.color,
          chord: pendingChord,
          kotta: pendingKotta,
          spaceAfter: addSpaceAfter,
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
          case 'S':
            flushWord();
            style.strike = true;
            continue;
          case 's':
            flushWord();
            style.strike = false;
            continue;
          case '.':
            flushWord();
            result.add(_RenderLine(words: List<_WordToken>.from(words)));
            words.clear();
            continue;
          case '_':
            sb.write('-');
            continue;
          case ' ': // non-breaking space marker
            sb.write('-');
            continue;
          case 'G':
            flushWord();
            attachPendingToPrevWord();
            final int end = src.indexOf(';', i);
            if (end > i) {
              pendingChord = src.substring(i, end);
              i = end + 1;
            }
            continue;
          case 'K':
            flushWord();
            attachPendingToPrevWord();
            final int end = src.indexOf(';', i);
            if (end > i) {
              pendingKotta = src.substring(i, end);
              i = end + 1;
            }
            continue;
          case 'C':
            flushWord();
            attachPendingToPrevWord();
            final int end = src.indexOf(';', i);
            if (end > i) {
              style.color = _parseColor(src.substring(i, end));
              i = end + 1;
            }
            continue;
          case '?':
            flushWord();
            attachPendingToPrevWord();
            if (i < src.length) {
              final String sub = src[i];
              i++;
              final int end = src.indexOf(';', i);
              if (end > i) {
                final String payload = src.substring(i, end);
                if (sub == 'G') {
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
        if (sb.isNotEmpty) {
          flushWord(addSpaceAfter: true);
        } else {
          attachPendingToPrevWord();
          // Space can arrive right after an escaped control block (\K, \G, etc.).
          // In that case there is no buffered text, so mark the previous token.
          markPrevSpaceAfter();
        }
      } else {
        sb.write(ch);
      }
      i++;
    }

    flushWord();
    attachPendingToPrevWord();
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
    return oldDelegate.frame != frame ||
        oldDelegate.globals != globals ||
        oldDelegate.settings != settings;
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
    required this.strike,
    required this.color,
    this.chord,
    this.kotta,
    this.spaceAfter = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final Color? color;
  final String? chord;
  final String? kotta;
  final bool spaceAfter;

  bool get countAsWord => text.trim().isNotEmpty;
}

class _WordStyle {
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strike = false;
  Color? color;
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
  String slurType = ' ';
  String slurNext = ' ';
  Offset? slurStart;
  Offset? slurEnd;
  bool triLe = false;
  String triTipus = ' ';
  bool deferFinalDoubleBarAtEnd = false;
  final List<Offset> triPos = <Offset>[];
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
    c.slurType = slurType;
    c.slurNext = slurNext;
    c.slurStart = slurStart;
    c.slurEnd = slurEnd;
    c.triLe = triLe;
    c.triTipus = triTipus;
    c.deferFinalDoubleBarAtEnd = deferFinalDoubleBarAtEnd;
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

class _BeamStem {
  _BeamStem({
    required this.x,
    required this.yHead,
    required this.yTip,
    required this.down,
    required this.rhythm,
  });
  final double x;
  final double yHead;
  final double yTip;
  final bool down;
  final String rhythm;
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
  const _KottaWordLayout({required this.wordIndex, required this.slotWidth});
  final int wordIndex;
  final double slotWidth;
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
    this.prefix = const _KottaRowPrefix.empty(),
    this.inlinePrefix = const _KottaRowPrefix.empty(),
  });
  final List<_KottaWordLayout> words;
  final double width;
  final _KottaRowPrefix prefix;
  final _KottaRowPrefix inlinePrefix;
}

class _TextRowLayout {
  const _TextRowLayout({
    required this.wordIndices,
    required this.width,
    this.indentWidth = 0,
  });
  final List<int> wordIndices;
  final double width;
  final double indentWidth;
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
