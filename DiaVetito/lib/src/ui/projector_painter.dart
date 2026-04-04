import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/projection_frame.dart';
import '../models/projection_globals.dart';

class ProjectorPainter extends CustomPainter {
  ProjectorPainter({
    required this.frame,
    required this.globals,
    required this.settings,
  });

  final ProjectionFrame? frame;
  final ProjectionGlobals globals;
  final AppSettings settings;

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
      _drawImage(canvas, size, localFrame, globals.bkColor, localFrame.bgMode);
      return;
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = globals.blankColor);
  }

  void _drawLogo(Canvas canvas, Size size, int phase) {
    Color bk = Colors.black;
    if (phase >= 16 && phase < 32) {
      final int i = phase - 16;
      bk = Color.fromARGB(255, (0x4B * i ~/ 16), (0xEF * i ~/ 16), (0x96 * i ~/ 16));
    } else if (phase >= 48 && phase < 64) {
      final int i = 64 - phase;
      bk = Color.fromARGB(255, (0x4B * i ~/ 16), (0xEF * i ~/ 16), (0x96 * i ~/ 16));
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = bk);

    if (globals.hideTitle) {
      return;
    }

    const double titleFontSizeBase = 6.4;
    const double verFontSizeBase = 2.4;
    const double minFontSize = 8.0;

    final double titleFontSize = math.max(minFontSize, globals.titleSize * titleFontSizeBase).toDouble();
    final double verFontSize = math.max(minFontSize, globals.titleSize * verFontSizeBase).toDouble();

    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: 'Diatar Vetito',
        style: TextStyle(
          color: const Color(0xFF434ECE),
          fontSize: titleFontSize,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          shadows: const <Shadow>[Shadow(color: Color(0xFF404040), blurRadius: 10, offset: Offset(5, 5))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);

    final TextPainter verPainter = TextPainter(
      text: TextSpan(
        text: 'Flutter port',
        style: TextStyle(color: Colors.white70, fontSize: verFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);

    final Offset titlePos = Offset((size.width - titlePainter.width) / 2, size.height * 0.42);
    final Offset verPos = Offset((size.width - verPainter.width) / 2, titlePos.dy + titlePainter.height + 12);
    titlePainter.paint(canvas, titlePos);
    verPainter.paint(canvas, verPos);
  }

  void _drawText(Canvas canvas, Size size, TextFrame frame) {
    canvas.drawRect(Offset.zero & size, Paint()..color = globals.bkColor);

    final double horizontalPad = globals.leftIndent.toDouble() * 4;
    final double maxWidth = math.max(40, size.width - horizontalPad * 2);
    
    final bool hasTitleLine = !globals.hideTitle && frame.record.title.isNotEmpty;
    final List<String> sourceLines = <String>[
      if (hasTitleLine) frame.record.title,
      ...frame.record.lines,
    ];

    final List<_RenderLine> allLines = _parseRenderLines(sourceLines);

    double fontSize = globals.fontSize.toDouble();
    if (globals.autoResize) {
      while (fontSize > 8) {
        final double required = _measureTextHeight(allLines, maxWidth, fontSize);
        if (required <= size.height * 0.95) {
          break;
        }
        fontSize -= 1;
      }
    }

    final double titleFontSize = (globals.titleSize.toDouble() * 2.5).clamp(8.0, 72.0);
    final double lineSpacing = globals.spacing100 / 100.0;
    
    final List<TextPainter> painters = <TextPainter>[];
    int globalWordIndex = 0; // Track word index for highlighting (skips title)
    
    for (int lineIndex = 0; lineIndex < allLines.length; lineIndex++) {
      final _RenderLine line = allLines[lineIndex];
      final bool isTitleLine = hasTitleLine && lineIndex == 0;
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      
      final List<InlineSpan> spans = <InlineSpan>[];
      for (int i = 0; i < line.words.length; i++) {
        final _WordToken word = line.words[i];
        
        // Update word index for non-title lines
        if (!isTitleLine && word.countAsWord) {
          globalWordIndex++;
        }
        
        // Highlight if index is <= wordToHighlight (and not title)
        final bool highlighted = !isTitleLine && globals.wordToHighlight > 0 && globalWordIndex <= globals.wordToHighlight;
        final Color baseColor = word.color ?? globals.txtColor;
        
        spans.add(
          TextSpan(
            text: word.text + (i == line.words.length - 1 ? '' : ' '),
            style: TextStyle(
              color: highlighted ? globals.hiColor : baseColor,
              fontSize: lineFontSize,
              fontWeight: (globals.boldText || word.bold) ? FontWeight.bold : FontWeight.normal,
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
    }

    double totalHeight = 0;
    for (final TextPainter tp in painters) {
      totalHeight += tp.height * lineSpacing;
    }
    double y = globals.vCenter ? (size.height - totalHeight) / 2 : 8;

    for (int painterIndex = 0; painterIndex < painters.length; painterIndex++) {
      final TextPainter tp = painters[painterIndex];
      final double x = globals.hCenter ? (size.width - tp.width) / 2 : horizontalPad;
      tp.paint(canvas, Offset(x, y));

      final _RenderLine rline = allLines[painterIndex];
      final bool isTitleLine = hasTitleLine && painterIndex == 0;
      final double lineFontSize = isTitleLine ? titleFontSize : fontSize;
      _paintChords(canvas, rline, x, y, lineFontSize);
      y += tp.height * lineSpacing;
    }
  }

  void _paintChords(Canvas canvas, _RenderLine line, double x, double y, double fontSize) {
    if (line.words.isEmpty || !globals.useAkkord) {
      return;
    }
    final TextPainter measure = TextPainter(textDirection: TextDirection.ltr);
    double cx = x;
    for (int i = 0; i < line.words.length; i++) {
      final _WordToken w = line.words[i];
      final String display = w.text + (i == line.words.length - 1 ? '' : ' ');
      measure.text = TextSpan(
        text: display,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: (globals.boldText || w.bold) ? FontWeight.bold : FontWeight.normal,
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

  double _measureTextHeight(List<_RenderLine> lines, double maxWidth, double fontSize) {
    double h = 0;
    final double lineSpacing = globals.spacing100 / 100.0;
    for (final _RenderLine line in lines) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: line.words.map((w) => w.text).join(' '),
          style: TextStyle(fontSize: fontSize, fontWeight: globals.boldText ? FontWeight.bold : FontWeight.normal),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      h += tp.height * lineSpacing;
      if (globals.useAkkord && line.words.any((w) => (w.chord ?? '').isNotEmpty)) {
        h += tp.height * (globals.akkordArany / 200);
      }
    }
    return h;
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

    void flushWord() {
      final String txt = sb.toString();
      sb.clear();
      if (txt.trim().isEmpty) {
        return;
      }
      words.add(_WordToken(
        text: txt,
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        strike: style.strike,
        color: style.color,
        chord: pendingChord,
      ));
      pendingChord = null;
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
            final int end = src.indexOf(';', i);
            if (end > i) {
              pendingChord = src.substring(i, end);
              i = end + 1;
            }
            continue;
          case 'C':
            flushWord();
            final int end = src.indexOf(';', i);
            if (end > i) {
              style.color = _parseColor(src.substring(i, end));
              i = end + 1;
            }
            continue;
          case '?':
          case 'K':
            // Skip unsupported metadata block up to ';'.
            final int end = src.indexOf(';', i);
            if (end > i) {
              i = end + 1;
            }
            continue;
          default:
            sb.write(cmd);
            continue;
        }
      }

      if (ch == ' ') {
        flushWord();
      } else {
        sb.write(ch);
      }
      i++;
    }

    flushWord();
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

  void _drawImage(Canvas canvas, Size size, ImageFrame frame, Color bgColor, int mode) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);

    final ui.Image image = frame.image;
    final Rect src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    switch (mode) {
      case 0:
        final Offset pos = Offset((size.width - src.width) / 2, (size.height - src.height) / 2);
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
        final double scale = math.min(size.width / src.width, size.height / src.height);
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
    return oldDelegate.frame != frame || oldDelegate.globals != globals || oldDelegate.settings != settings;
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
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final Color? color;
  final String? chord;

  bool get countAsWord => text.trim().isNotEmpty;
}

class _WordStyle {
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strike = false;
  Color? color;
}
