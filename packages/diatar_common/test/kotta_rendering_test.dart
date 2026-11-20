import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _NotationCanvas extends Fake implements Canvas {
  final List<({ui.Image image, Rect rect})> images = [];
  final List<({Offset start, Offset end, double width})> lines = [];
  final List<({Offset offset, double width})> paragraphs = [];
  final List<Object> operations = [];

  List<Rect> glyphs(String name) => images
      .where((glyph) => identical(glyph.image, KottaAssets.image(name)))
      .map((glyph) => glyph.rect)
      .toList();

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    images.add((image: image, rect: dst));
    operations.add((image, dst));
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((start: p1, end: p2, width: paint.strokeWidth));
    operations.add([p1.dx, p1.dy, p2.dx, p2.dy]);
  }

  @override
  void drawPath(Path path, Paint paint) => operations.add(path);

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    paragraphs.add((offset: offset, width: paragraph.maxIntrinsicWidth));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ProjectorPainter _painter(
  List<String> lines, {
  double fontSize = 34,
  int kottaRatio = 100,
}) {
  return ProjectorPainter(
    frame: TextFrame(
      record: RecTextRecord(scholaLine: '', title: '', lines: lines),
    ),
    globals: ProjectionGlobals(
      autoResize: false,
      fontSize: fontSize.round(),
      hCenter: false,
      hideTitle: true,
      useKotta: true,
      kottaArany: kottaRatio,
    ),
    settings: const AppSettings(receiverUseKotta: true),
    allowLineWrapping: false,
  );
}

_NotationCanvas _render(List<String> lines, {double fontSize = 34}) {
  final canvas = _NotationCanvas();
  _painter(lines, fontSize: fontSize).paint(canvas, const Size(2000, 1000));
  return canvas;
}

_NotationCanvas _commands(String commands) {
  final canvas = _NotationCanvas();
  _painter([]).debugPaintKottaCommands(canvas, [commands]);
  return canvas;
}

Iterable<({Offset start, Offset end, double width})> _stems(
  _NotationCanvas canvas,
) => canvas.lines.where(
  (line) =>
      line.start.dx == line.end.dx && (line.end.dy - line.start.dy).abs() > 10,
);

({Offset start, Offset end}) _tupletBracket(
  _NotationCanvas canvas,
  String glyph,
) {
  final int index = canvas.operations.indexWhere(
    (operation) =>
        operation is (ui.Image, Rect) &&
        identical(operation.$1, KottaAssets.image(glyph)),
  );
  expect(index, greaterThanOrEqualTo(0));
  final coords = canvas.operations[index + 1] as List<double>;
  return (
    start: Offset(coords[0], coords[1]),
    end: Offset(coords[2], coords[3]),
  );
}

void _registerAndroidLayoutTests() {
  final layoutReference =
      jsonDecode(
            File('test/fixtures/android_kotta_layout.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final entry in layoutReference['cases'] as List<dynamic>) {
    final data = entry as Map<String, dynamic>;
    test('Android text layout reference: ${data['name']}', () {
      final canvas = _NotationCanvas();
      ProjectorPainter(
        frame: TextFrame(
          record: RecTextRecord(
            scholaLine: '',
            title: '',
            lines: (data['rows'] as List<dynamic>).cast<String>(),
          ),
        ),
        globals: ProjectionGlobals(
          autoResize: false,
          fontSize: 34,
          hideTitle: true,
          useKotta: true,
          hCenter: data['center'] as bool,
          leftIndent: data['indent'] as int,
          spacing100: data['spacing'] as int,
          kottaArany: data['ratio'] as int,
        ),
        settings: const AppSettings(receiverUseKotta: true),
      ).paint(canvas, Size((data['width'] as num).toDouble(), 2000));
      final operations = (data['operations'] as List<dynamic>)
          .cast<List<dynamic>>();
      final texts = operations
          .where((op) => op[0] == 'text' && (op[1] as String).isNotEmpty)
          .toList();
      expect(canvas.paragraphs, hasLength(texts.length));
      final metrics = (TextPainter(
        text: const TextSpan(text: 'Ag', style: TextStyle(fontSize: 34)),
        textDirection: TextDirection.ltr,
      )..layout()).computeLineMetrics().single;
      for (int i = 0; i < texts.length; i++) {
        expect(
          canvas.paragraphs[i].offset.dx,
          closeTo((texts[i][2] as num).toDouble(), 0.001),
          reason: 'text $i: ${texts[i]}',
        );
        expect(
          canvas.paragraphs[i].offset.dy + metrics.baseline,
          closeTo((texts[i][3] as num).toDouble() + 8, 0.001),
          reason: 'text $i: ${texts[i]}',
        );
      }
      final glyphs = operations.where((op) => op[0] == 'glyph').toList();
      expect(canvas.images, hasLength(glyphs.length));
      for (int i = 0; i < glyphs.length; i++) {
        expect(
          identical(
            canvas.images[i].image,
            KottaAssets.image(glyphs[i][1] as String),
          ),
          isTrue,
        );
        final rect = canvas.images[i].rect;
        final coords = [rect.left, rect.top - 8, rect.right, rect.bottom - 8];
        for (int j = 0; j < 4; j++) {
          expect(
            coords[j],
            closeTo((glyphs[i][j + 2] as num).toDouble(), 1),
            reason: 'glyph $i: ${glyphs[i]}',
          );
        }
      }
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerAndroidLayoutTests();

  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final String key = const StringCodec().decodeMessage(message)!;
      final File asset = File.fromUri(
        Directory.current.uri.resolve('../../Diatar/$key'),
      );
      final Uint8List bytes = await asset.readAsBytes();
      return ByteData.sublistView(bytes);
    });
    await KottaAssets.ensureLoaded();
    messenger.setMockMessageHandler('flutter/assets', null);
    expect(KottaAssets.image('gkulcs'), isNotNull);
    expect(KottaAssets.image('hang4fej'), isNotNull);
  });

  final reference =
      jsonDecode(
            File(
              'test/fixtures/android_kotta_rendering.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final entry in reference['cases'] as List<dynamic>) {
    final data = entry as Map<String, dynamic>;
    test('Android drawing reference: ${data['name']}', () {
      final rows = (data['rows'] as List<dynamic>).cast<String>();
      final bool changedDecoration = rows.any(
        (row) => row.contains('[?') || row.contains('[3') || row.contains('[5'),
      );
      final canvas = _NotationCanvas();
      _painter([]).debugPaintKottaCommands(
        canvas,
        rows,
        lineGap: (data['gap'] as num).toDouble(),
      );
      final expected = data['operations'] as List<dynamic>;
      expect(canvas.operations, hasLength(expected.length));
      for (int i = 0; i < expected.length; i++) {
        final operation = expected[i] as List<dynamic>;
        final actual = canvas.operations[i];
        final String reason = '${data['name']}, operation $i: $operation';
        switch (operation.first) {
          case 'glyph':
            expect(actual, isA<(ui.Image, Rect)>(), reason: reason);
            final glyph = actual as (ui.Image, Rect);
            expect(
              identical(glyph.$1, KottaAssets.image(operation[1] as String)),
              isTrue,
              reason: reason,
            );
            final coords = [
              glyph.$2.left,
              glyph.$2.top,
              glyph.$2.right,
              glyph.$2.bottom,
            ];
            if (operation[1] == 'triola' || operation[1] == 'pentola') {
              expect(
                glyph.$2.width,
                closeTo(
                  (operation[4] as num).toDouble() -
                      (operation[2] as num).toDouble(),
                  1,
                ),
              );
              expect(
                glyph.$2.height,
                closeTo(
                  (operation[5] as num).toDouble() -
                      (operation[3] as num).toDouble(),
                  1,
                ),
              );
              continue;
            }
            for (int j = 0; j < 4; j++) {
              // Android uses float32 before truncating bitmap edges.
              expect(
                coords[j],
                closeTo((operation[j + 2] as num).toDouble(), 1),
                reason: reason,
              );
            }
          case 'line':
            expect(actual, isA<List<double>>(), reason: reason);
            final coords = actual as List<double>;
            // Stems, beams and tuplets intentionally differ now; their geometry
            // is covered below. Keep the original glyph and staff comparisons.
            if (changedDecoration &&
                !(operation[1] == 20 && operation[2] == operation[4])) {
              continue;
            }
            for (int j = 0; j < 4; j++) {
              expect(
                coords[j],
                closeTo((operation[j + 1] as num).toDouble(), 0.01),
                reason: reason,
              );
            }
          case 'path':
            expect(actual, isA<Path>(), reason: reason);
            final path = Path();
            for (final raw in operation[1] as List<dynamic>) {
              final part = raw as List<dynamic>;
              final coords = part
                  .skip(1)
                  .map((v) => (v as num).toDouble())
                  .toList();
              if (part.first == 'move') {
                path.moveTo(coords[0], coords[1]);
              } else {
                path.cubicTo(
                  coords[0],
                  coords[1],
                  coords[2],
                  coords[3],
                  coords[4],
                  coords[5],
                );
              }
            }
            final expectedMetric = path.computeMetrics().single;
            final actualMetric = (actual as Path).computeMetrics().single;
            expect(
              actualMetric.length,
              closeTo(expectedMetric.length, 0.003),
              reason: reason,
            );
            for (int sample = 0; sample < 50; sample++) {
              final double t = sample / 50;
              final p = expectedMetric
                  .getTangentForOffset(expectedMetric.length * t)!
                  .position;
              final q = actualMetric
                  .getTangentForOffset(actualMetric.length * t)!
                  .position;
              expect((p - q).distance, lessThan(0.003), reason: reason);
            }
          default:
            fail('Unknown reference operation: $operation');
        }
      }
    });
  }
  test(
    'beamed repeated notes have the same stem length as standalone notes',
    () {
      for (final pitch in ['2g', '2G']) {
        for (final rhythm in ['8', '6']) {
          final standalone = _stems(_commands('r$rhythm$pitch')).single;
          final double length = (standalone.end - standalone.start).distance;
          final beamed = _stems(_commands('[?r$rhythm$pitch$pitch$pitch]?'));
          expect(beamed, isNotEmpty);
          for (final stem in beamed) {
            expect((stem.end - stem.start).distance, closeTo(length, 0.001));
          }
        }
      }
    },
  );

  test('beamed pitch changes never shorten stems below standalone length', () {
    for (final notes in ['2g3c2a2g', '2G3C2A2G']) {
      final stems = _stems(_commands('[?r8$notes]?'));
      expect(stems, isNotEmpty);
      for (final stem in stems) {
        expect(
          (stem.end - stem.start).distance,
          greaterThanOrEqualTo(30 - 0.001),
        );
      }
    }
  });

  test(
    'level tuplets stay level with more than half a staff gap of clearance',
    () {
      for (final number in [3, 5]) {
        for (final pitch in ['2g', '2G']) {
          for (final beamed in [false, true]) {
            final notes = List.filled(number, pitch).join();
            final canvas = _commands(
              '[$number${beamed ? '[?' : ''}r8$notes${beamed ? ']?' : ''}]$number',
            );
            final bracket = _tupletBracket(
              canvas,
              number == 3 ? 'triola' : 'pentola',
            );
            expect(bracket.end.dy, closeTo(bracket.start.dy, 0.001));
            for (final stem in _stems(canvas)) {
              final double clearance = (bracket.start.dy - stem.end.dy).abs();
              expect(clearance, greaterThan(5));
              expect(clearance, lessThan(10));
            }
          }
        }
      }
    },
  );

  test('pitched tuplet brackets clear every actual stem tip', () {
    for (final notes in ['2g3c2a2h2c', '2G3C2A2H2C']) {
      final canvas = _commands('[5[?r8$notes]?]5');
      final bracket = _tupletBracket(canvas, 'pentola');
      final double slope =
          (bracket.end.dy - bracket.start.dy) /
          (bracket.end.dx - bracket.start.dx);
      for (final stem in _stems(canvas)) {
        final double bracketY =
            bracket.start.dy + (stem.end.dx - bracket.start.dx) * slope;
        final double clearance = notes.contains('G')
            ? bracketY - stem.end.dy
            : stem.end.dy - bracketY;
        expect(clearance, greaterThanOrEqualTo(7.5 - 0.001));
      }
    }
  });

  test(
    'compact melismas separate at lyric boundaries but not within a block',
    () {
      for (final fontSize in [34.0, 68.0]) {
        final canvas = _render([
          r'\KRtr82g2a2h2c2d2e;a\K2g2a2h2c2d2e;b',
        ], fontSize: fontSize);
        final heads = canvas.glyphs('hang4fej');
        expect(heads, hasLength(12));
        for (int i = 1; i < heads.length; i++) {
          final double gap = heads[i].left - heads[i - 1].right;
          if (i == 6) {
            expect(gap, greaterThanOrEqualTo(heads[i - 1].width - 1));
          } else {
            expect(gap, closeTo(0, 1));
          }
        }
      }
    },
  );

  test(
    'compact slot widths use the larger of lyrics and melody plus a head',
    () {
      final double melody = _painter([
        r'\KRtr82g2a2h2c2d2e;',
      ]).measureRequiredWidth();
      final double head = _painter([r'\KRtr82g;']).measureRequiredWidth();
      expect(
        _painter([r'\KRtr82g2a2h2c2d2e;a']).measureRequiredWidth(),
        closeTo(melody + head, 0.001),
      );
      expect(
        _painter([r'\KRtr82g2a;longword']).measureRequiredWidth(),
        _painter(['longword']).measureRequiredWidth(),
      );
    },
  );

  test('compact melisma separation participates in line wrapping', () {
    const source =
        r'\KRtr82g2a2h2c2d2e2g2a2h2c2d2e;a \K2g2a2h2c2d2e2g2a2h2c2d2e;b';
    final painter = _painter([source]);
    final double head = _painter([r'\KRtr82g;']).measureRequiredWidth();
    expect(
      painter.debugKottaRowWidthsForLine(
        source,
        fontSize: 34,
        maxWidth: painter.measureRequiredWidth() - head,
      ),
      hasLength(2),
    );
  });

  test('clef and key carry to source lines without a staff command', () {
    final canvas = _render([
      r'\KkGE2r82g;one',
      r'\Kr82a;two',
      r'\K-5r82h;three',
    ]);
    expect(canvas.glyphs('gkulcs'), hasLength(3));
    expect(canvas.glyphs('kereszt'), hasLength(6));
  });

  test(
    'source line starts with the carried clef before an explicit change',
    () {
      final canvas = _render([r'\KkGr82g;one', r'\K-5kFr82a;two']);
      expect(canvas.glyphs('gkulcs'), hasLength(2));
      expect(canvas.glyphs('fkulcs'), hasLength(1));
    },
  );

  test(
    'inline clefs and meters shift their own lyrics, not following slots',
    () {
      const source = r'\Kr82g;first \KkFu4r82a;second\K2h;end';
      final canvas = _render([source]);
      final heads = canvas.glyphs('hang4fej');
      expect(canvas.paragraphs, hasLength(3));
      for (int index = 0; index < heads.length; index++) {
        expect(
          canvas.paragraphs[index].offset.dx,
          closeTo(heads[index].left - heads[index].width / 2, 1),
        );
      }
      final lastText = canvas.paragraphs.last;
      expect(
        lastText.offset.dx + lastText.width,
        lessThanOrEqualTo(_painter([source]).measureRequiredWidth() + 0.001),
      );
    },
  );

  test('compact notes respect lyric spacing between notation blocks', () {
    final canvas = _render([r'\KRtr82g;longword\K2a;anotherlongword\K2h;end']);
    final heads = canvas.glyphs('hang4fej');
    expect(heads, hasLength(3));
    expect(heads[1].left - heads[0].right, greaterThan(heads[0].width));
    expect(heads[2].left - heads[1].right, greaterThan(heads[1].width));
  });

  test('beam and slur controls do not reserve horizontal space', () {
    double width(String commands) =>
        _painter(['\\K$commands;']).measureRequiredWidth();
    expect(width('[?r82g2a]?'), closeTo(width('r82g2a'), 0.001));
    expect(width('(fr82g2a)f'), closeTo(width('r82g2a'), 0.001));
  });

  test('an accidental is measured only for its next note', () {
    final canvas = _render([r'\Kmk2g2a;']);
    final heads = canvas.glyphs('hang4fej');
    expect(heads, hasLength(2));
    expect(canvas.glyphs('kereszt'), hasLength(1));
    final double noteAdvance = _painter([r'\K2a;']).measureRequiredWidth();
    final double expectedWidth =
        _painter([r'\Kmk2g;']).measureRequiredWidth() + noteAdvance;
    expect(
      _painter([r'\Kmk2g2a;']).measureRequiredWidth(),
      closeTo(expectedWidth, 0.001),
    );
    expect(heads[1].left - heads[0].left, closeTo(noteAdvance, 1));
  });

  test('zero-width rhythm commands still change the drawing state', () {
    final canvas = _render([r'\Kr8; \K2g;note']);
    expect(canvas.glyphs('zaszlo8fel'), hasLength(1));
  });

  test('compact mode and rhythm reset between source lines', () {
    final canvas = _render([r'\KRtr82g;one', r'\K2g2a;']);
    final heads = canvas.glyphs('hang4fej');
    expect(heads, hasLength(3));
    expect(canvas.glyphs('zaszlo8fel'), hasLength(1));
    expect(heads[2].left - heads[1].left, closeTo(heads[1].width * 2, 1));
    expect(
      _painter([r'\KRtr82g;', r'\K2g2a;']).measureRequiredWidth(),
      closeTo(_painter([r'\K2g2a;']).measureRequiredWidth(), 0.001),
    );
  });

  test('layout caches distinguish notation size ratios', () {
    const source = r'\Kr82g2a2h2c;';
    final double normal = _painter([source]).measureRequiredWidth();
    final double doubled = _painter([
      source,
    ], kottaRatio: 200).measureRequiredWidth();
    expect(doubled, closeTo(normal * 2, 0.001));
    expect(_painter([source]).measureRequiredWidth(), closeTo(normal, 0.001));
  });

  test('notation continues scaling above a ten pixel staff gap', () {
    final small = _render([r'\Kr82g;'], fontSize: 50);
    final large = _render([r'\Kr82g;'], fontSize: 100);
    expect(
      large.glyphs('hang4fej').single.width,
      closeTo(small.glyphs('hang4fej').single.width * 2, 1),
    );
  });

  test('reduced staff line count carries to the next source line', () {
    final canvas = _render([r'\K-3r42g;one', r'\Kr42a;two']);
    final staff = canvas.lines.where(
      (line) =>
          line.start.dy == line.end.dy && line.end.dx - line.start.dx > 50,
    );
    expect(staff, hasLength(6));
  });

  test('reduced staffs draw ledger lines above their highest line', () {
    final canvas = _render([r'\K-1r42h;word']);
    final head = canvas.glyphs('hang4fej').single;
    final ledgers = canvas.lines.where(
      (line) =>
          line.start.dy == line.end.dy &&
          (line.end.dx - line.start.dx - head.width * 1.5).abs() <= 2,
    );
    expect(ledgers, hasLength(2));
  });

  test(
    'reported double bar stays inline, inside the staff, before lyric end',
    () {
      const source = r's\K-5r82g;e f\K1f;ü f\Kr41e;ar-k\Kr21f||;a.**';
      List<double> bars(_NotationCanvas canvas) {
        final vertical = canvas.lines.where(
          (line) => line.start.dx == line.end.dx,
        );
        final double height = vertical
            .map((line) => (line.end.dy - line.start.dy).abs())
            .reduce((a, b) => a > b ? a : b);
        return vertical
            .where(
              (line) =>
                  ((line.end.dy - line.start.dy).abs() - height).abs() < 0.001,
            )
            .map((line) => line.start.dx)
            .toList();
      }

      final canvas = _render([source]);
      final barXs = bars(canvas);
      expect(barXs, hasLength(2));
      final longer = _render([source.replaceFirst('a.**', 'a.**********')]);
      expect(bars(longer), barXs);
      final lastText = canvas.paragraphs.last;
      expect(barXs.last, lessThan(lastText.offset.dx + lastText.width));
      final staffEnds = canvas.lines
          .where(
            (line) =>
                line.start.dy == line.end.dy &&
                line.end.dx - line.start.dx > 100,
          )
          .map((line) => line.end.dx);
      expect(staffEnds, hasLength(5));
      expect(
        staffEnds,
        everyElement(
          greaterThanOrEqualTo(lastText.offset.dx + lastText.width - 0.001),
        ),
      );
      expect(staffEnds, everyElement(greaterThan(barXs.last)));
    },
  );

  test('a final notation-only block follows the final lyric slot', () {
    final canvas = _render([r'\Kr42g;longword\K||;']);
    final text = canvas.paragraphs.single;
    final double end = text.offset.dx + text.width;
    final bars = canvas.lines.where(
      (line) => line.start.dx == line.end.dx && line.start.dx > end,
    );
    expect(bars, hasLength(2));
  });

  test(
    'all nonempty source lines reserve notation and repeat the active clef',
    () {
      final canvas = _render([r'\KkGr42g;one', 'two', r'\Kr42a;three']);
      expect(canvas.glyphs('gkulcs'), hasLength(3));
      final ys = canvas.paragraphs.map((p) => p.offset.dy).toList();
      expect(ys[1] - ys[0], closeTo(ys[2] - ys[1], 0.001));
    },
  );
}
