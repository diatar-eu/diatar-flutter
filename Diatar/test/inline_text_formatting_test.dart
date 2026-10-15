import 'dart:ui' as ui;

import 'package:diatar_common/diatar_common.dart';
import 'package:diatar_app/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const InlineTextEditorLabels _editorLabels = InlineTextEditorLabels(
  bold: 'Bold',
  italic: 'Italic',
  underline: 'Underline',
  strikethrough: 'Strike',
  insertSpecialCharacter: 'Insert special',
  conditionalHyphen: 'Conditional hyphen',
  nonBreakingSpace: 'Non-breaking space',
  nonBreakingHyphen: 'Non-breaking hyphen',
  preferredLineBreak: 'Preferred break',
  insertChord: 'Insert chord',
  editChord: 'Edit chord',
  insertKotta: 'Insert notation',
  editKotta: 'Edit notation',
);

const ChordEditorLabels _chordLabels = ChordEditorLabels(
  insertTitle: 'Insert chord',
  editTitle: 'Edit chord',
  rootNote: 'Root note',
  quality: 'Quality',
  major: 'Major',
  minor: 'Minor',
  modifier: 'Chord type',
  bassNote: 'Bass note',
  none: 'None',
  preview: 'Preview',
  cancel: 'Cancel',
  apply: 'Apply',
);

final AppLocalizationsEn _l10n = AppLocalizationsEn();
final KottaEditorLabels _kottaLabels = KottaEditorLabels(
  insertTitle: _l10n.kottaEditorInsertTitle,
  editTitle: _l10n.kottaEditorEditTitle,
  clef: _l10n.kottaEditorClef,
  keySignature: _l10n.kottaEditorKeySignature,
  barlines: _l10n.kottaEditorBarlines,
  singleBarline: _l10n.kottaEditorSingleBarline,
  doubleBarline: _l10n.kottaEditorDoubleBarline,
  finalBarline: _l10n.kottaEditorFinalBarline,
  shortCaesura: _l10n.kottaEditorShortCaesura,
  longCaesura: _l10n.kottaEditorLongCaesura,
  openingRepeat: _l10n.kottaEditorOpeningRepeat,
  bidirectionalRepeat: _l10n.kottaEditorBidirectionalRepeat,
  closingRepeat: _l10n.kottaEditorClosingRepeat,
  meters: _l10n.kottaEditorMeters,
  meterSymbol: _l10n.kottaEditorMeterSymbol,
  meter44: _l10n.kottaEditorMeter44,
  meter24: _l10n.kottaEditorMeter24,
  meter34: _l10n.kottaEditorMeter34,
  meter38: _l10n.kottaEditorMeter38,
  meter68: _l10n.kottaEditorMeter68,
  meter22: _l10n.kottaEditorMeter22,
  meter32: _l10n.kottaEditorMeter32,
  meter54: _l10n.kottaEditorMeter54,
  meter64: _l10n.kottaEditorMeter64,
  rests: _l10n.kottaEditorRests,
  notes: _l10n.kottaEditorNotes,
  longa: _l10n.kottaEditorLonga,
  brevis: _l10n.kottaEditorBrevis,
  semibrevis: _l10n.kottaEditorSemibrevis,
  wholeNote: _l10n.kottaEditorWholeNote,
  halfNote: _l10n.kottaEditorHalfNote,
  quarterNote: _l10n.kottaEditorQuarterNote,
  eighthNote: _l10n.kottaEditorEighthNote,
  sixteenthNote: _l10n.kottaEditorSixteenthNote,
  wholeRest: _l10n.kottaEditorWholeRest,
  halfRest: _l10n.kottaEditorHalfRest,
  quarterRest: _l10n.kottaEditorQuarterRest,
  eighthRest: _l10n.kottaEditorEighthRest,
  sixteenthRest: _l10n.kottaEditorSixteenthRest,
  gClef: _l10n.kottaEditorGClef,
  fClef: _l10n.kottaEditorFClef,
  sopranoClef: _l10n.kottaEditorSopranoClef,
  mezzoSopranoClef: _l10n.kottaEditorMezzoSopranoClef,
  altoClef: _l10n.kottaEditorAltoClef,
  tenorClef: _l10n.kottaEditorTenorClef,
  baritoneClef: _l10n.kottaEditorBaritoneClef,
  doClefLine: _l10n.kottaEditorDoClefLine,
  doClefSpace: _l10n.kottaEditorDoClefSpace,
  flats: _l10n.kottaEditorFlats,
  sharps: _l10n.kottaEditorSharps,
  flatKeys: <String>[
    _l10n.kottaEditorFlatKey1,
    _l10n.kottaEditorFlatKey2,
    _l10n.kottaEditorFlatKey3,
    _l10n.kottaEditorFlatKey4,
    _l10n.kottaEditorFlatKey5,
    _l10n.kottaEditorFlatKey6,
    _l10n.kottaEditorFlatKey7,
  ],
  sharpKeys: <String>[
    _l10n.kottaEditorSharpKey1,
    _l10n.kottaEditorSharpKey2,
    _l10n.kottaEditorSharpKey3,
    _l10n.kottaEditorSharpKey4,
    _l10n.kottaEditorSharpKey5,
    _l10n.kottaEditorSharpKey6,
    _l10n.kottaEditorSharpKey7,
  ],
  cancel: _l10n.cancel,
  apply: _l10n.apply,
);

({Finder preview, ProjectorEditorCursorLayout layout}) _notationPreviewLayout(
  WidgetTester tester,
) {
  final Finder preview = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is ProjectorPainter,
  );
  final ProjectorPainter painter =
      tester.widget<CustomPaint>(preview).painter! as ProjectorPainter;
  ProjectorEditorCursorLayout? layout;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ProjectorPainter(
    frame: painter.frame,
    globals: painter.globals,
    settings: painter.settings,
    allowLineWrapping: painter.allowLineWrapping,
    editorCursorOverlay: painter.editorCursorOverlay,
    onEditorCursorLayout: (value) => layout = value,
  ).paint(Canvas(recorder), tester.getSize(preview));
  recorder.endRecording().dispose();
  return (preview: preview, layout: layout!);
}

ProjectorEditorCursorOverlay _notationOverlay(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_notationPreviewLayout(tester).preview).painter!
            as ProjectorPainter)
        .editorCursorOverlay!;

Future<void> _openNotationPreview(
  WidgetTester tester,
  InlineTextEditingController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InlineTextEditor(
          controller: controller,
          labels: _editorLabels,
          chordEditorLabels: _chordLabels,
          kottaEditorLabels: _kottaLabels,
          decoration: const InputDecoration(),
        ),
      ),
    ),
  );
  final Finder marker = find
      .byKey(const ValueKey<String>('inline-kotta-marker'))
      .first;
  await tester.tap(marker);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(marker);
  await tester.pumpAndSettle();
}

Offset _kottaPosition(
  WidgetTester tester,
  int position, {
  bool textRow = false,
}) {
  final preview = _notationPreviewLayout(tester);
  return tester.getTopLeft(preview.preview) +
      Offset(
        preview.layout.kottaPositions[position]! + 0.1,
        textRow
            ? preview.layout.textRect.center.dy
            : preview.layout.kottaRect.center.dy,
      );
}

void main() {
  test(
    'clef graphics contain glyphs at their encoded staff positions',
    () async {
      await KottaAssets.ensureLoaded();
      for (final String code in 'GF12345abcdefghi'.split('')) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        KottaClefPainter(
          command: 'k$code',
          color: Colors.black,
        ).paint(Canvas(recorder), const Size(48, 48));
        final ui.Picture picture = recorder.endRecording();
        final ui.Image image = await picture.toImage(48, 48);
        final pixels = (await image.toByteData())!;
        final List<int> glyphRows = <int>[];
        final Set<int> glyphColumns = <int>{};
        int glyphPixels = 0;
        for (int y = 0; y < 48; y++) {
          if (<int>[16, 20, 24, 28, 32].contains(y)) {
            continue;
          }
          for (int x = 0; x < 48; x++) {
            if (pixels.getUint8((y * 48 + x) * 4 + 3) > 128) {
              glyphRows.add(y);
              glyphColumns.add(x);
              glyphPixels++;
            }
          }
        }
        expect(
          glyphPixels,
          greaterThan(10),
          reason: 'Missing glyph for k$code',
        );
        if ('12345'.contains(code)) {
          final double center = (glyphRows.first + glyphRows.last) / 2;
          expect(
            center,
            closeTo(32 - (int.parse(code) - 1) * 4, 1.5),
            reason: 'C clef must be centered on its encoded staff line',
          );
        } else if ('abcdefghi'.contains(code)) {
          final double center = (glyphRows.first + glyphRows.last) / 2;
          expect(
            center,
            closeTo(32 - 'abcdefghi'.indexOf(code) * 2, 1),
            reason: 'Do clef must be centered on its encoded line or space',
          );
          expect(
            glyphColumns.length,
            greaterThanOrEqualTo(10),
            reason: 'Do clef must remain readable in a compact button',
          );
        }
        expect(glyphRows.first, greaterThan(0));
        expect(glyphRows.last, lessThan(47));
        image.dispose();
        picture.dispose();
      }
    },
  );

  test('removes empty and repeated inline style markers', () {
    expect(normalizeInlineTextFormattingMarkers(r'a\B\b\B\bsd\b\B\b'), 'asd');
  });

  test('preserves the rendered style while consolidating markers', () {
    expect(
      normalizeInlineTextFormattingMarkers(r'\Bbold\B\I italic\i\b'),
      r'\Bbold\I italic\b\i',
    );
  });

  test('does not alter other inline commands', () {
    expect(
      normalizeInlineTextFormattingMarkers(r'\Bword\b\GAm;'),
      r'\Bword\b\GAm;',
    );
  });

  test('decodes every supported DIA command into logical editor text', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'\Bbold\b\ \-\_\.\\\KkGu4;\GAm;\?Gminor;',
    );

    expect(
      document.visibleText,
      'bold\u00A0\u00AD\u2011\n\\'
      '$inlineCommandPlaceholder'
      '$inlineCommandPlaceholder'
      '$inlineCommandPlaceholder',
    );
    expect(document.encode(), r'\Bbold\b\ \-\_\.\\\KkGu4;\GAm;\?Gminor;');
  });

  test('round-trips every paired DIA style', () {
    expect(
      InlineTextDocument.decode(
        r'\Bbold\b\Uunder\u\Iitalic\i\Sstrike\s\(tied\)',
      ).encode(),
      r'\Bbold\b\Uunder\u\Iitalic\i\Sstrike\s\(tied\)',
    );
  });

  test('preserves variable commands as indivisible logical elements', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'ab\KkGu4;cd\GAm;\?Gminor;',
    );

    expect(
      document.visibleText,
      'ab'
      '$inlineCommandPlaceholder'
      'cd'
      '$inlineCommandPlaceholder'
      '$inlineCommandPlaceholder',
    );
    document.replaceVisibleRange(1, 1, 'X', styles: const <InlineTextStyle>{});

    expect(document.encode(), r'aXb\KkGu4;cd\GAm;\?Gminor;');
  });

  test('does not add style transitions around embedded commands', () {
    expect(
      InlineTextDocument.decode(r'\Bword\GAm;more\b').encode(),
      r'\Bword\GAm;more\b',
    );
  });

  test('serializes selected and pending styles without raw markup offsets', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('hello');
    controller.value = TextEditingValue(
      text: 'hello',
      selection: TextSelection(baseOffset: 1, extentOffset: 4),
    );

    controller.toggleStyle(InlineTextStyle.bold);
    expect(controller.text, 'hello');
    expect(controller.encodedText, r'h\Bell\bo');

    controller.value = TextEditingValue(
      text: 'hello',
      selection: TextSelection.collapsed(offset: 5),
    );
    controller.toggleStyle(InlineTextStyle.italic);
    controller.value = TextEditingValue(
      text: 'hello!',
      selection: TextSelection.collapsed(offset: 6),
    );

    expect(controller.text, 'hello!');
    expect(controller.encodedText, r'h\Bell\bo\I!\i');
    controller.dispose();
  });

  test('uses one visible controller character for an embedded command', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'a\KkGu4;b');

    expect(
      controller.text,
      'a$inlineCommandPlaceholder'
      'b',
    );
    controller.value = TextEditingValue(
      text: 'aXb',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(controller.encodedText, 'aXb');
    controller.dispose();
  });

  test('exposes an embedded chord as one editable object', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'a\GAm7/G;b');

    final InlineChordCommand chord = controller.chordAtOffset(1)!;
    expect(chord.source, 'Am7/G');
    expect(chord.chord, isNotNull);
    expect(controller.text, 'a${inlineCommandPlaceholder}b');

    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
    expect(controller.selectedChord?.source, 'Am7/G');
    controller.dispose();
  });

  test('inserts and replaces chords without exposing their markup', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('word');
    controller.selection = const TextSelection.collapsed(offset: 0);

    controller.insertChord('C27/G');
    expect(
      controller.text,
      '$inlineCommandPlaceholder'
      'word',
    );
    expect(controller.encodedText, r'\GC27/G;word');

    controller.replaceChordAt(0, 'H-7+');
    expect(
      controller.text,
      '$inlineCommandPlaceholder'
      'word',
    );
    expect(controller.encodedText, r'\GH-7+;word');
    controller.dispose();
  });

  test('exposes, inserts, and replaces notation as one right-bound object', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\?Kr41a;word');

    expect(controller.kottaAtOffset(0)?.source, 'r41a');
    expect(controller.kottaAtOffset(0)?.isConditional, isTrue);
    final KottaEditorInitialState editorState = controller.kottaEditorStateAt(
      0,
      editingExisting: true,
    );
    expect(editorState.elements.map((element) => element.command), <String>[
      'r4',
      '1a',
    ]);
    expect(editorState.elements, everyElement(isA<KottaEditorElement>()));
    expect(editorState.kottaCursor, 2);
    expect(editorState.textCursor, 0);
    expect(
      controller.previewLineForKottaEditor(0, editorState.elements),
      r'\?Kr41a;word',
    );

    controller.replaceKottaAt(0, 'r82a');
    expect(controller.encodedText, r'\?Kr82a;word');

    controller.selection = const TextSelection.collapsed(offset: 5);
    controller.insertKotta('r41c');
    expect(controller.encodedText, r'\?Kr82a;word\Kr41c;');
    controller.dispose();
  });

  test('notation preview contains the complete current DIA line', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(
          'first\n'
          r'before \GAm;\Kr41a;word \Kr42b;after'
          '\nlast',
        );

    final KottaEditorInitialState editorState = controller.kottaEditorStateAt(
      20,
      editingExisting: true,
    );
    expect(editorState.elements.map((element) => element.command), <String>[
      'r4',
      '1a',
      'r4',
      '2b',
    ]);
    expect(editorState.elements.map((element) => element.textOffset), <int>[
      7,
      7,
      12,
      12,
    ]);
    expect(editorState.kottaCursor, 4);
    expect(editorState.textCursor, 12);
    expect(
      controller.previewLineForKottaEditor(20, editorState.elements),
      r'before \GAm;\Kr41a;word \Kr42b;after',
    );
    controller.dispose();
  });

  test('graphical notation result moves its command to the text cursor', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\Kr41a;word');

    final KottaEditorInitialState state = controller.kottaEditorStateAt(
      0,
      editingExisting: true,
    );
    expect(state.textLength, 4);
    expect(state.textCursor, 0);

    controller.applyKottaEditorResult(
      0,
      KottaEditorResult(
        elements: <KottaEditorElement>[
          for (final KottaEditorElement element in state.elements)
            KottaEditorElement(
              command: element.command,
              textOffset: 2,
              isConditional: element.isConditional,
            ),
        ],
      ),
    );

    expect(controller.encodedText, r'wo\Kr41a;rd');
    controller.dispose();
  });

  test('copies a complete associated word together with its notation', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\Kr41a;word next');
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 5);

    expect(controller.selectedDocument.encode(), r'\Kr41a;word');
    expect(controller.selectedDocument.plainText, 'word');
    controller.dispose();
  });

  test('inserts notation before selected text without replacing the text', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('word');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);

    controller.insertKotta('r41a');

    expect(controller.encodedText, r'\Kr41a;word');
    controller.dispose();
  });

  test('deleting a complete associated word also removes its notation', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\Kr41a;word next');
    controller.value = const TextEditingValue(
      text: '$inlineCommandPlaceholder next',
      selection: TextSelection.collapsed(offset: 1),
    );

    expect(controller.text, ' next');
    expect(controller.encodedText, ' next');
    controller.dispose();
  });

  test('partially deleting associated text keeps its notation', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\Kr41a;word');
    controller.value = const TextEditingValue(
      text: '${inlineCommandPlaceholder}ord',
      selection: TextSelection.collapsed(offset: 1),
    );

    expect(controller.encodedText, r'\Kr41a;ord');
    controller.dispose();
  });

  test('uses readable chord names in external clipboard representations', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'Before \GAm7/G; after',
    );

    expect(document.plainText, 'Before Am7/G after');
    expect(InlineTextClipboard.toRtf(document), contains('Am7/G'));
    expect(InlineTextClipboard.toHtml(document), contains('>Am7/G</span>'));
  });

  test('pastes a copied chord as one atomic object', () {
    final InlineTextDocument copied = InlineTextDocument.decode(
      r'\GAm7/G;',
    ).copyRange(0, 1);
    final InlineTextEditingController target =
        InlineTextEditingController.fromDia('word');
    target.selection = const TextSelection.collapsed(offset: 2);

    target.replaceSelectionWithDocument(copied);

    expect(target.text, 'wo${inlineCommandPlaceholder}rd');
    expect(target.encodedText, r'wo\GAm7/G;rd');
    expect(target.chordAtOffset(2)?.source, 'Am7/G');
    target.dispose();
  });

  test('escapes typed backslashes instead of creating DIA commands', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('');
    controller.value = TextEditingValue(
      text: '\\B',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(controller.text, '\\B');
    expect(controller.encodedText, r'\\B');
    controller.dispose();
  });

  test('inserts special characters as one logical editor position', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('ab');
    controller.value = TextEditingValue(
      text: 'ab',
      selection: TextSelection.collapsed(offset: 1),
    );

    controller.insertSpecialCharacter(
      InlineTextSpecialCharacter.nonBreakingHyphen,
    );

    expect(controller.text, 'a\u2011b');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    expect(controller.encodedText, r'a\_b');
    controller.dispose();
  });

  test('copies a selected DIA range with its formatting and commands', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'a\Bbold\b\ \-\_\.\GAm;z',
    );

    expect(
      document.copyRange(1, document.visibleText.length - 1).encode(),
      r'\Bbold\b\ \-\_\.\GAm;',
    );
  });

  test(
    'round-trips formatting, special characters, and DIA commands in HTML',
    () {
      final InlineTextDocument document = InlineTextDocument.decode(
        r'\Bbold\b \Iitalic\i\ \-\_\.\GAm;',
      );

      expect(
        InlineTextClipboard.fromHtml(
          InlineTextClipboard.toHtml(document),
        ).encode(),
        document.encode(),
      );
    },
  );

  test('reads office HTML formatting and non-breaking characters', () {
    expect(
      InlineTextClipboard.fromHtml(
        '<p><strong>Bold</strong> <em>italic</em>&nbsp;<u>under</u><br>next</p>',
      ).encode(),
      '${r'\BBold\b \Iitalic\i\ \Uunder\u'}\nnext\n',
    );
  });

  test('ignores source indentation between Word HTML blocks', () {
    expect(
      InlineTextClipboard.fromHtml(
        '<p><strong>First</strong></p>\r\n  <p>Second</p>',
      ).encode(),
      '${r'\BFirst\b'}\nSecond\n',
    );
  });

  test('keeps Word paragraphs and line breaks as separate lines', () {
    expect(
      InlineTextClipboard.fromHtml(
        '<p class=MsoNormal>first<o:p></o:p></p>'
        '<p class=MsoNormal>second<br>\nthird<o:p></o:p></p>',
      ).visibleText,
      'first\nsecond\nthird\n',
    );
  });

  test('does not accept a platform paste while rich paste is in progress', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('before');
    controller.beginRichClipboardPaste();
    controller.value = const TextEditingValue(
      text: 'beplainfore',
      selection: TextSelection.collapsed(offset: 7),
    );

    expect(controller.text, 'before');
    controller.cancelRichClipboardPaste();
    controller.dispose();
  });

  test('round-trips formatting and special characters in RTF', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'\Bbold\b \Iitalic\i\ \-\_\.á',
    );

    expect(
      InlineTextClipboard.fromRtf(InlineTextClipboard.toRtf(document)).encode(),
      document.encode(),
    );
  });

  testWidgets('chord toolbar inserts an atomic chord', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert chord'));
    await tester.pumpAndSettle();
    expect(find.text('Insert chord'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\GC;');
    expect(find.byType(ChordDisplay), findsOneWidget);
    controller.dispose();
  });

  testWidgets('double-clicking a framed chord opens it for editing', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\GAm7;word');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    final Finder chord = find.byType(ChordDisplay);
    expect(chord, findsOneWidget);
    await tester.tap(chord);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(chord);
    await tester.pumpAndSettle();

    expect(find.text('Edit chord'), findsOneWidget);
    expect(controller.chordAtOffset(0)?.source, 'Am7');
    controller.dispose();
  });

  testWidgets('notation toolbar inserts an atomic notation command', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('word');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert notation'));
    await tester.pumpAndSettle();
    expect(find.text('Insert notation'), findsOneWidget);

    await tester.tap(find.byTooltip(_kottaLabels.gClef));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(controller.encodedText, r'\KkG;word');
    expect(controller.kottaAtOffset(0)?.source, 'kG');
    controller.dispose();
  });

  testWidgets('graphical clefs expose hints and insert all legacy clef codes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    KottaEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) =>
                      '\\K${elements.map((element) => element.command).join()};',
                  initialState: const KottaEditorInitialState(
                    elements: <KottaEditorElement>[],
                    textLength: 0,
                    kottaCursor: 0,
                    textCursor: 0,
                    isEditing: false,
                  ),
                );
              },
              child: Text(_kottaLabels.insertTitle),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(_kottaLabels.insertTitle));
    await tester.pumpAndSettle();

    final Map<String, String> clefs = <String, String>{
      'kG': _kottaLabels.gClef,
      'kF': _kottaLabels.fClef,
      'k1': _kottaLabels.sopranoClef,
      'k2': _kottaLabels.mezzoSopranoClef,
      'k3': _kottaLabels.altoClef,
      'k4': _kottaLabels.tenorClef,
      'k5': _kottaLabels.baritoneClef,
      for (int index = 0; index < 9; index++)
        'k${String.fromCharCode(97 + index)}': index.isEven
            ? _kottaLabels.doClefLine(index ~/ 2 + 1)
            : _kottaLabels.doClefSpace(index ~/ 2 + 1, index ~/ 2 + 2),
    };
    for (final MapEntry<String, String> clef in clefs.entries) {
      final Finder button = find.byTooltip(clef.value);
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.byType(Text)),
        findsNothing,
      );
      final CustomPaint image = tester.widget<CustomPaint>(
        find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is KottaClefPainter,
          ),
        ),
      );
      expect((image.painter! as KottaClefPainter).command, clef.key);
      expect(image.size, const Size(48, 48));
      expect(
        tester.getSize(
          find.descendant(of: button, matching: find.byType(OutlinedButton)),
        ),
        const Size(56, 56),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      if (clef.key == 'k1') {
        await tester.longPress(button);
        await tester.pump();
        expect(find.text(clef.value), findsOneWidget);
      }
      await tester.tap(button);
      await tester.pump();
    }
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(result!.elements.map((element) => element.command), clefs.keys);
    expect(tester.takeException(), isNull);
  });

  testWidgets('key signatures expose key hints and insert only supported codes', (
    WidgetTester tester,
  ) async {
    KottaEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) =>
                      '\\K${elements.map((element) => element.command).join()};',
                  initialState: const KottaEditorInitialState(
                    elements: <KottaEditorElement>[],
                    textLength: 0,
                    kottaCursor: 0,
                    textCursor: 0,
                    isEditing: false,
                  ),
                );
              },
              child: Text(_kottaLabels.insertTitle),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(_kottaLabels.insertTitle));
    await tester.pumpAndSettle();

    final Finder section = find
        .ancestor(
          of: find.text(_kottaLabels.keySignature),
          matching: find.byType(Column),
        )
        .first;
    expect(
      find.descendant(of: section, matching: find.byType(OutlinedButton)),
      findsNWidgets(14),
    );
    final List<String> commands = <String>[];
    for (final bool flats in <bool>[true, false]) {
      for (int count = 1; count <= 7; count++) {
        final String hint = (flats
            ? _kottaLabels.flatKeys
            : _kottaLabels.sharpKeys)[count - 1];
        final Finder button = find.byTooltip(hint);
        expect(button, findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.text(flats ? '$count\u266d' : '$count#'),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        if (flats && count == 1) {
          await tester.longPress(button);
          await tester.pump();
          expect(find.text(hint), findsOneWidget);
        }
        await tester.tap(button);
        await tester.pump();
        commands.add('${flats ? 'e' : 'E'}$count');
      }
    }
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(result!.elements.map((element) => element.command), commands);
    expect(tester.takeException(), isNull);
  });

  for (final bool notes in <bool>[false, true]) {
    testWidgets(
      'graphical ${notes ? 'notes' : 'rests'} insert legacy codes at the active cursor',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        KottaEditorResult? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () async {
                    result = await showKottaEditorDialog(
                      context: context,
                      labels: _kottaLabels,
                      previewLineBuilder: (elements) =>
                          '\\K${elements.map((element) => element.command).join()};',
                      initialState: const KottaEditorInitialState(
                        elements: <KottaEditorElement>[
                          KottaEditorElement(command: 'kG', textOffset: 0),
                          KottaEditorElement(command: '|1', textOffset: 0),
                        ],
                        textLength: 0,
                        kottaCursor: 1,
                        textCursor: 0,
                        isEditing: true,
                      ),
                    );
                  },
                  child: Text(_kottaLabels.editTitle),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(_kottaLabels.editTitle));
        await tester.pumpAndSettle();

        final List<(String, String, String)> rests = notes
            ? <(String, String, String)>[
                (_kottaLabels.longa, 'rl', 'editor_hang0'),
                (_kottaLabels.brevis, 'rb', 'editor_hangbrevis1'),
                (_kottaLabels.semibrevis, 'rs', 'editor_hangbrevis2'),
                (_kottaLabels.wholeNote, 'r1', 'editor_hang1'),
                (_kottaLabels.halfNote, 'r2', 'editor_hang2'),
                (_kottaLabels.quarterNote, 'r4', 'editor_hang4'),
                (_kottaLabels.eighthNote, 'r8', 'editor_hang8'),
                (_kottaLabels.sixteenthNote, 'r6', 'editor_hang16'),
              ]
            : <(String, String, String)>[
                (_kottaLabels.wholeRest, 's1', 'szunet1'),
                (_kottaLabels.halfRest, 's2', 'szunet2'),
                (_kottaLabels.quarterRest, 's4', 'szunet4'),
                (_kottaLabels.eighthRest, 's8', 'szunet8'),
                (_kottaLabels.sixteenthRest, 's6', 'szunet16'),
              ];
        final Finder section = find
            .ancestor(
              of: find.text(notes ? _kottaLabels.notes : _kottaLabels.rests),
              matching: find.byType(Column),
            )
            .first;
        expect(
          tester
              .widgetList<Tooltip>(
                find.descendant(of: section, matching: find.byType(Tooltip)),
              )
              .map((tooltip) => tooltip.message),
          rests.map((rest) => rest.$1),
        );
        for (final (String label, String _, String asset) in rests) {
          final Finder button = find.descendant(
            of: section,
            matching: find.byTooltip(label),
          );
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final Image image = tester.widget<Image>(
            find.descendant(of: button, matching: find.byType(Image)),
          );
          expect(
            (image.image as AssetImage).assetName,
            'assets/kotta/$asset.png',
          );
          expect(
            tester.getSize(
              find.descendant(of: button, matching: find.byType(Image)),
            ),
            const Size(24, 24),
          );
          expect(
            tester.getSize(
              find.descendant(
                of: button,
                matching: find.byType(OutlinedButton),
              ),
            ),
            const Size(56, 56),
          );
          expect(image.color, ThemeData.dark().colorScheme.onSurface);
          await tester.tap(button);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(result!.elements.map((element) => element.command), <String>[
          'kG',
          for (final rest in rests) ...<String>[rest.$2, if (notes) '2g'],
          '|1',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final testCase
      in <
        ({
          String name,
          List<String> initial,
          int cursor,
          List<String> rhythms,
          bool selectNext,
          List<String> expected,
        })
      >[
        (
          name: 'empty notation starts on 2g without redundant quarter rhythm',
          initial: <String>[],
          cursor: 0,
          rhythms: <String>['r4', 'r4'],
          selectNext: false,
          expected: <String>['2g', '2g'],
        ),
        (
          name: 'line start ignores later pitches and restores later rhythm',
          initial: <String>['3d'],
          cursor: 0,
          rhythms: <String>['r8'],
          selectNext: false,
          expected: <String>['r8', '2g', 'r4', '3d'],
        ),
        (
          name: 'notes inherit the preceding pitch across rests and controls',
          initial: <String>['r2', '1g', 's8', '|1', 'Rt'],
          cursor: 5,
          rhythms: <String>['r2'],
          selectNext: false,
          expected: <String>['r2', '1g', 's8', '|1', 'Rt', '1g'],
        ),
        (
          name: 'upper ledger pitch is inherited',
          initial: <String>['3d'],
          cursor: 1,
          rhythms: <String>['r6'],
          selectNext: false,
          expected: <String>['3d', 'r6', '3d'],
        ),
        (
          name: 'inserted pitch is lowercase without rewriting existing notes',
          initial: <String>['r2', '2G', '2A'],
          cursor: 2,
          rhythms: <String>['r8'],
          selectNext: false,
          expected: <String>['r2', '2G', 'r8', '2g', 'r2', '2A'],
        ),
        (
          name:
              'repeated middle insertion shares rhythm and restores following notes',
          initial: <String>['r2', '2a', '|1', '2h'],
          cursor: 2,
          rhythms: <String>['r8', 'r8'],
          selectNext: false,
          expected: <String>['r2', '2a', 'r8', '2a', '2a', 'r2', '|1', '2h'],
        ),
        (
          name: 'an explicit later rhythm needs no extra restoration',
          initial: <String>['2c', 's4', 'r2', '2d'],
          cursor: 1,
          rhythms: <String>['r8'],
          selectNext: false,
          expected: <String>['2c', 'r8', '2c', 's4', 'r2', '2d'],
        ),
        (
          name:
              'returning to the original rhythm removes redundant restoration',
          initial: <String>['r2', '2a', '2h'],
          cursor: 2,
          rhythms: <String>['r8', 'r2'],
          selectNext: false,
          expected: <String>['r2', '2a', 'r8', '2a', 'r2', '2a', '2h'],
        ),
        (
          name: 'dotted rhythm is restored exactly',
          initial: <String>['R4', '2e', 'rt', '2f'],
          cursor: 2,
          rhythms: <String>['r4'],
          selectNext: false,
          expected: <String>['R4', '2e', 'r4', '2e', 'R4', 'rt', '2f'],
        ),
        (
          name: 'replacing selection preserves the rhythm at its original end',
          initial: <String>['r4', '1a', 'r8', '2c', '3d'],
          cursor: 2,
          rhythms: <String>['r2'],
          selectNext: true,
          expected: <String>['r4', '1a', 'r2', '1a', 'r8', '3d'],
        ),
      ]) {
    testWidgets(testCase.name, (WidgetTester tester) async {
      KottaEditorResult? result;
      final List<KottaEditorElement> initial = <KottaEditorElement>[
        for (final String command in testCase.initial)
          KottaEditorElement(
            command: command,
            textOffset: 0,
            isConditional: true,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  result = await showKottaEditorDialog(
                    context: context,
                    labels: _kottaLabels,
                    previewLineBuilder: (elements) =>
                        '\\K${elements.map((element) => element.command).join()};',
                    initialState: KottaEditorInitialState(
                      elements: initial,
                      textLength: 0,
                      kottaCursor: testCase.cursor,
                      textCursor: 0,
                      isEditing: initial.isNotEmpty,
                    ),
                  );
                },
                child: Text(_kottaLabels.insertTitle),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_kottaLabels.insertTitle));
      await tester.pumpAndSettle();
      if (testCase.selectNext) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
      }
      final Map<String, String> labels = <String, String>{
        'r2': _kottaLabels.halfNote,
        'r4': _kottaLabels.quarterNote,
        'r8': _kottaLabels.eighthNote,
        'r6': _kottaLabels.sixteenthNote,
      };
      final Finder section = find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first;
      for (final String rhythm in testCase.rhythms) {
        final Finder button = find.descendant(
          of: section,
          matching: find.byTooltip(labels[rhythm]!),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(
        result!.elements.map((element) => element.command),
        testCase.expected,
      );
      final Iterable<KottaEditorElement> restored = result!.elements.where(
        (element) =>
            !initial.contains(element) &&
            (element.command.startsWith('r') ||
                element.command.startsWith('R')) &&
            !testCase.rhythms.contains(element.command),
      );
      expect(restored.every((element) => element.isConditional), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('graphical barlines show named hints and insert in legacy order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    KottaEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) =>
                      '\\K${elements.map((element) => element.command).join()};',
                  initialState: const KottaEditorInitialState(
                    elements: <KottaEditorElement>[],
                    textLength: 0,
                    kottaCursor: 0,
                    textCursor: 0,
                    isEditing: false,
                  ),
                );
              },
              child: Text(_kottaLabels.insertTitle),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(_kottaLabels.insertTitle));
    await tester.pumpAndSettle();

    final List<(String, String, String)> barlines = <(String, String, String)>[
      (_kottaLabels.singleBarline, '|1', 'utemjel'),
      (_kottaLabels.doubleBarline, '||', 'utemjel2'),
      (_kottaLabels.finalBarline, '|.', 'utemjelveg'),
      (_kottaLabels.shortCaesura, "|'", 'cezura1'),
      (_kottaLabels.longCaesura, '|!', 'cezura2'),
      (_kottaLabels.openingRepeat, '|>', 'ismjel2'),
      (_kottaLabels.bidirectionalRepeat, '|:', 'ismjel3'),
      (_kottaLabels.closingRepeat, '|<', 'ismjel1'),
    ];
    final Finder section = find
        .ancestor(
          of: find.text(_kottaLabels.barlines),
          matching: find.byType(Column),
        )
        .first;
    expect(
      tester
          .widgetList<Tooltip>(
            find.descendant(of: section, matching: find.byType(Tooltip)),
          )
          .map((tooltip) => tooltip.message),
      barlines.map((barline) => barline.$1),
    );
    for (final (String hint, String _, String asset) in barlines) {
      final Finder button = find.byTooltip(hint);
      expect(
        find.descendant(of: button, matching: find.byType(Text)),
        findsNothing,
      );
      final Image image = tester.widget<Image>(
        find.descendant(of: button, matching: find.byType(Image)),
      );
      expect((image.image as AssetImage).assetName, 'assets/kotta/$asset.png');
      expect(
        image.color,
        Theme.of(tester.element(button)).colorScheme.onSurface,
      );
      await tester.runAsync(() async {
        final ByteData data = await rootBundle.load('assets/kotta/$asset.png');
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final ui.Image glyph = (await codec.getNextFrame()).image;
        final ByteData pixels = (await glyph.toByteData())!;
        int visiblePixels = 0;
        for (int offset = 3; offset < pixels.lengthInBytes; offset += 4) {
          if (pixels.getUint8(offset) != 0) {
            visiblePixels++;
          }
        }
        expect(visiblePixels, greaterThan(0));
        expect(visiblePixels, lessThan(glyph.width * glyph.height));
        glyph.dispose();
        codec.dispose();
      });
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      if (asset == 'utemjel') {
        await tester.longPress(button);
        await tester.pump();
        expect(find.text(hint), findsOneWidget);
      }
      await tester.tap(button);
      await tester.pump();
    }
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(
      result!.elements.map((element) => element.command),
      barlines.map((barline) => barline.$2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('meters and rests coexist and preserve existing notation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const List<KottaEditorElement> existing = <KottaEditorElement>[
      KottaEditorElement(command: 'R4', textOffset: 0),
      KottaEditorElement(command: 'mk', textOffset: 0),
      KottaEditorElement(command: '1a', textOffset: 0),
      KottaEditorElement(command: 's4', textOffset: 0),
    ];
    KottaEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) =>
                      '\\K${elements.map((element) => element.command).join()};',
                  initialState: const KottaEditorInitialState(
                    elements: existing,
                    textLength: 0,
                    kottaCursor: 4,
                    textCursor: 0,
                    isEditing: true,
                  ),
                );
              },
              child: Text(_kottaLabels.editTitle),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(_kottaLabels.editTitle));
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(OutlinedButton), findsNWidgets(60));
    final Finder barlineSection = find
        .ancestor(
          of: find.text(_kottaLabels.barlines),
          matching: find.byType(Column),
        )
        .first;
    final Column sections = tester.widget<Column>(
      find.ancestor(of: barlineSection, matching: find.byType(Column)).first,
    );
    final List<String> headings = sections.children.map((section) {
      final Column content = find
          .descendant(of: find.byWidget(section), matching: find.byType(Column))
          .evaluate()
          .map((element) => element.widget)
          .whereType<Column>()
          .first;
      return (content.children.first as Text).data!;
    }).toList();
    expect(headings, <String>[
      _kottaLabels.clef,
      _kottaLabels.keySignature,
      _kottaLabels.barlines,
      _kottaLabels.meters,
      _kottaLabels.rests,
      _kottaLabels.notes,
    ]);

    final List<(String, String, String)> meters = <(String, String, String)>[
      (_kottaLabels.meter44, 'u4', 'u44'),
      (_kottaLabels.meter24, 'u2', 'u24'),
      (_kottaLabels.meter34, 'u3', 'u34'),
      (_kottaLabels.meter38, 'U8', 'u38'),
      (_kottaLabels.meter68, 'U6', 'u68'),
      (_kottaLabels.meter22, 'U2', 'u22'),
      (_kottaLabels.meter32, 'U3', 'u32'),
      (_kottaLabels.meter54, 'u5', 'u54'),
      (_kottaLabels.meter64, 'u6', 'u64'),
    ];
    final Finder meterSection = find
        .ancestor(
          of: find.text(_kottaLabels.meters),
          matching: find.byType(Column),
        )
        .first;
    expect(
      tester
          .widgetList<Tooltip>(
            find.descendant(of: meterSection, matching: find.byType(Tooltip)),
          )
          .map((tooltip) => tooltip.message),
      meters.map((meter) => meter.$1),
    );
    for (final (String hint, String _, String asset) in meters) {
      final Finder button = find.byTooltip(hint);
      expect(
        find.descendant(of: button, matching: find.byType(Image)),
        findsNothing,
      );
      final Finder symbolFinder = find.descendant(
        of: button,
        matching: find.byType(Text),
      );
      final Text symbol = tester.widget<Text>(symbolFinder);
      expect(symbol.data, '${asset[1]}\n${asset[2]}');
      expect(symbol.textAlign, TextAlign.center);
      expect(symbol.style!.fontWeight, FontWeight.w700);
      expect(symbol.style!.fontSize, lessThanOrEqualTo(20));
      expect(
        symbol.style!.color,
        Theme.of(tester.element(button)).colorScheme.onSurface,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(button).height,
        tester.getSize(find.byTooltip(_kottaLabels.singleBarline)).height,
      );
      final Size symbolSize = tester.getSize(symbolFinder);
      expect(symbolSize.height, greaterThan(symbolSize.width));
      if (asset == 'u44') {
        await tester.longPress(button);
        await tester.pump();
        expect(find.text(hint), findsOneWidget);
      }
      await tester.tap(button);
      await tester.pump();
    }
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(result!.elements.map((element) => element.command), <String>[
      ...existing.map((element) => element.command),
      ...meters.map((meter) => meter.$2),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notation preview exposes a draggable horizontal scrollbar', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(
          List<String>.filled(30, 'long preview text').join(' '),
        );
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert notation'));
    await tester.pumpAndSettle();

    final Scrollbar scrollbar = tester.widget<Scrollbar>(
      find.byType(Scrollbar),
    );
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.trackVisibility, isTrue);
    expect(scrollbar.interactive, isTrue);
    expect(scrollbar.scrollbarOrientation, ScrollbarOrientation.bottom);
    expect(scrollbar.controller!.position.maxScrollExtent, greaterThan(0));
    controller.dispose();
  });

  testWidgets('notation cursors move with Tab and arrow keys', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('word');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert notation'));
    await tester.pumpAndSettle();
    expect(find.text('Notation commands'), findsNothing);
    expect(find.text('Preview'), findsNothing);

    ProjectorPainter previewPainter() {
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<ProjectorPainter>()
          .single;
    }

    final ProjectorPainter initialPainter = previewPainter();
    final String initialLine =
        (initialPainter.frame! as TextFrame).record.lines.single;
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'kotta-editor');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(previewPainter().editorCursorOverlay!.textActive, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final ProjectorPainter movedPainter = previewPainter();
    expect(movedPainter.editorCursorOverlay!.textActive, isTrue);
    expect(movedPainter.editorCursorOverlay!.textPosition, 2);
    expect((movedPainter.frame! as TextFrame).record.lines.single, initialLine);

    final bool movedCaretVisibility =
        movedPainter.editorCursorOverlay!.activeVisible;
    await tester.pump(const Duration(milliseconds: 500));
    final ProjectorPainter blinkPainter = previewPainter();
    expect(
      blinkPainter.editorCursorOverlay!.activeVisible,
      isNot(movedCaretVisibility),
    );
    expect((blinkPainter.frame! as TextFrame).record.lines.single, initialLine);

    await tester.tap(find.byTooltip(_kottaLabels.gClef));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(controller.encodedText, r'wo\KkG;rd');
    controller.dispose();
  });

  testWidgets('notation button inserts at the active kotta cursor', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\KkGr41a;word');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    final Finder marker = find.byKey(
      const ValueKey<String>('inline-kotta-marker'),
    );
    await tester.tap(marker);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(marker);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.tap(find.byTooltip(_kottaLabels.fClef));
    await tester.pump();
    final ProjectorPainter painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ProjectorPainter>()
        .single;
    expect(painter.editorCursorOverlay!.kottaPosition, 2);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(controller.encodedText, r'\KkGkFr41a;word');
    controller.dispose();
  });

  testWidgets('mouse and touch place notation cursors and preserve insertion', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\KkGr41a;word \KkF;other');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    final Finder marker = find
        .byKey(const ValueKey<String>('inline-kotta-marker'))
        .first;
    await tester.tap(marker);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(marker);
    await tester.pumpAndSettle();

    ProjectorEditorCursorOverlay overlay() =>
        (tester
                    .widget<CustomPaint>(_notationPreviewLayout(tester).preview)
                    .painter!
                as ProjectorPainter)
            .editorCursorOverlay!;

    final initial = _notationPreviewLayout(tester);
    final Offset origin = tester.getTopLeft(initial.preview);
    await tester.tapAt(
      origin +
          Offset(
            initial.layout.kottaPositions[1]! + 0.1,
            initial.layout.kottaRect.center.dy,
          ),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(overlay().textActive, isFalse);
    expect(overlay().kottaPosition, 1);
    expect(overlay().textPosition, 0);
    expect(overlay().activeVisible, isTrue);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'kotta-editor');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(overlay().kottaPosition, 3);

    final next = _notationPreviewLayout(tester);
    final double left = next.layout.textPositions[1]!;
    final double right = next.layout.textPositions[2]!;
    await tester.tapAt(
      tester.getTopLeft(next.preview) +
          Offset(left + (right - left) * 0.7, next.layout.textRect.center.dy),
    );
    await tester.pump();
    expect(overlay().textActive, isTrue);
    expect(overlay().textPosition, 2);
    expect(overlay().kottaPosition, 3);

    await tester.tap(find.byTooltip(_kottaLabels.fClef));
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\KkGr41a;wo\KkF;rd \KkF;other');
    controller.dispose();
  });

  testWidgets('touch placement uses scrolled preview coordinates', (
    WidgetTester tester,
  ) async {
    final String text = List<String>.filled(20, 'word').join();
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(text);
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip(_editorLabels.insertKotta));
    await tester.pumpAndSettle();
    final initial = _notationPreviewLayout(tester);
    final ScrollController scroll = tester
        .widget<Scrollbar>(find.byType(Scrollbar))
        .controller!;
    scroll.jumpTo(initial.layout.textPositions[40]! - 100);
    await tester.pump();
    final scrolled = _notationPreviewLayout(tester);
    await tester.tapAt(
      tester.getTopLeft(scrolled.preview) +
          Offset(
            scrolled.layout.textPositions[42]! + 0.1,
            scrolled.layout.textRect.center.dy,
          ),
    );
    await tester.pump();
    final ProjectorPainter painter =
        tester.widget<CustomPaint>(scrolled.preview).painter!
            as ProjectorPainter;
    expect(painter.editorCursorOverlay!.textActive, isTrue);
    expect(painter.editorCursorOverlay!.textPosition, 42);
    expect(painter.editorCursorOverlay!.kottaPosition, 0);

    await tester.tap(find.byTooltip(_kottaLabels.gClef));
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(
      controller.encodedText,
      '${text.substring(0, 42)}\\KkG;${text.substring(42)}',
    );
    controller.dispose();
  });

  testWidgets('notation cursor skips commands attached to a visible element', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\Kr4mk1ar42b;word');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    final Finder marker = find.byKey(
      const ValueKey<String>('inline-kotta-marker'),
    );
    await tester.tap(marker);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(marker);
    await tester.pumpAndSettle();

    ProjectorEditorCursorOverlay overlay() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ProjectorPainter>()
        .single
        .editorCursorOverlay!;

    expect(overlay().kottaPosition, 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(overlay().kottaPosition, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(overlay().kottaPosition, 0);
    controller.dispose();
  });

  for (final button in <({String label, String command, bool tooltip})>[
    (label: _kottaLabels.fClef, command: 'kF', tooltip: true),
    (label: _kottaLabels.sharps(1), command: 'E1', tooltip: false),
    (label: _kottaLabels.singleBarline, command: '|1', tooltip: true),
    (label: _kottaLabels.meter44, command: 'u4', tooltip: true),
    (label: _kottaLabels.quarterRest, command: 's4', tooltip: true),
    (label: _kottaLabels.quarterNote, command: 'r4', tooltip: true),
  ]) {
    testWidgets('Shift selection is replaced by ${button.command}', (
      WidgetTester tester,
    ) async {
      final InlineTextEditingController controller =
          InlineTextEditingController.fromDia(r'\KkG;ab\Kr4mk1a;cd\Ke2|!;ef');
      await _openNotationPreview(tester, controller);
      await tester.tapAt(
        _kottaPosition(tester, 5),
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        _notationOverlay(tester).kottaSelection,
        const TextSelection(baseOffset: 5, extentOffset: 1),
      );
      expect(_notationOverlay(tester).textActive, isFalse);

      Finder finder = button.tooltip
          ? find.byTooltip(button.label)
          : find.text(button.label);
      if (button.command == 's4' || button.command == 'r4') {
        final Finder section = find
            .ancestor(
              of: find.text(
                button.command == 's4'
                    ? _kottaLabels.rests
                    : _kottaLabels.notes,
              ),
              matching: find.byType(Column),
            )
            .first;
        finder = find.descendant(of: section, matching: finder);
      }
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      expect(_notationOverlay(tester).kottaSelection, isNull);
      expect(_notationOverlay(tester).kottaPosition, 2);
      expect(_notationOverlay(tester).textPosition, 2);
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      final String inserted = button.command == 'r4' ? '2g' : button.command;
      expect(controller.encodedText, '\\KkG;ab\\K$inserted;cd\\K|!;ef');
      controller.dispose();
    });
  }

  testWidgets('Shift selection reverses and unmodified navigation clears it', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\KkGe2u4|1;word');
    await _openNotationPreview(tester, controller);
    await tester.tapAt(
      _kottaPosition(tester, 2),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      _notationOverlay(tester).kottaSelection,
      const TextSelection(baseOffset: 2, extentOffset: 1),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNull);
    expect(_notationOverlay(tester).kottaPosition, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNull);
    expect(_notationOverlay(tester).textActive, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNull);
    controller.dispose();
  });

  testWidgets('mouse drag selects notation in both directions, not lyrics', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\KkGr4mk1a;word \Ke2|!;other');
    await _openNotationPreview(tester, controller);
    final TestGesture reverse = await tester.startGesture(
      _kottaPosition(tester, 5),
      kind: ui.PointerDeviceKind.mouse,
    );
    await reverse.moveTo(_kottaPosition(tester, 1, textRow: true));
    await reverse.up();
    await tester.pump();
    expect(
      _notationOverlay(tester).kottaSelection,
      const TextSelection(baseOffset: 5, extentOffset: 1),
    );
    expect(_notationOverlay(tester).textActive, isFalse);
    await tester.tapAt(
      _kottaPosition(tester, 1),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNull);

    final TestGesture forward = await tester.startGesture(
      _kottaPosition(tester, 1),
      kind: ui.PointerDeviceKind.mouse,
    );
    await forward.moveTo(_kottaPosition(tester, 5));
    await forward.up();
    await tester.pump();
    expect(
      _notationOverlay(tester).kottaSelection,
      const TextSelection(baseOffset: 1, extentOffset: 5),
    );
    await tester.tap(find.byTooltip(_kottaLabels.fClef));
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\KkGkF;word \K|!;other');
    controller.dispose();
  });

  testWidgets('mouse selection keeps its anchor while the preview scrolls', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(
          List<String>.filled(40, r'\KkG;a').join(),
        );
    await _openNotationPreview(tester, controller);
    final initial = _notationPreviewLayout(tester);
    final ScrollController scroll = tester
        .widget<Scrollbar>(find.byType(Scrollbar))
        .controller!;
    scroll.jumpTo(initial.layout.kottaPositions[20]! - 100);
    await tester.pump();
    final double initialOffset = scroll.offset;
    final TestGesture drag = await tester.startGesture(
      _kottaPosition(tester, 20),
      kind: ui.PointerDeviceKind.mouse,
    );
    await drag.moveTo(_kottaPosition(tester, 38));
    await tester.pump();
    await tester.pump();
    expect(scroll.offset, greaterThan(initialOffset));
    await drag.moveTo(_kottaPosition(tester, 39));
    await drag.up();
    await tester.pump();
    expect(
      _notationOverlay(tester).kottaSelection,
      const TextSelection(baseOffset: 20, extentOffset: 39),
    );

    final selected = _notationPreviewLayout(tester);
    await tester.tapAt(
      tester.getTopLeft(selected.preview) +
          Offset(
            selected.layout.textPositions[38]!,
            selected.layout.textRect.center.dy,
          ),
    );
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, isNull);
    expect(_notationOverlay(tester).textActive, isTrue);
    controller.dispose();
  });

  testWidgets('held arrow key repeats notation cursor movement', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('word');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert notation'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final ProjectorPainter painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ProjectorPainter>()
        .single;
    expect(painter.editorCursorOverlay!.textPosition, 2);
    controller.dispose();
  });

  testWidgets('notation preview scrolls to keep the active cursor visible', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(
          List<String>.filled(20, 'word').join(),
        );
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert notation'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (int index = 0; index < 70; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.pump();
    await tester.pump();

    final Scrollbar scrollbar = tester.widget<Scrollbar>(
      find.byType(Scrollbar),
    );
    expect(scrollbar.controller!.offset, greaterThan(0));
    controller.dispose();
  });

  testWidgets('Ctrl+K opens the notation editor', (WidgetTester tester) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('word');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Insert notation'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('double-clicking a notation marker opens it for editing', (
    WidgetTester tester,
  ) async {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\Kr41a;word');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineTextEditor(
            controller: controller,
            labels: _editorLabels,
            chordEditorLabels: _chordLabels,
            kottaEditorLabels: _kottaLabels,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );

    final Finder marker = find.byKey(
      const ValueKey<String>('inline-kotta-marker'),
    );
    expect(marker, findsOneWidget);
    await tester.tap(marker);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(marker);
    await tester.pumpAndSettle();

    expect(find.text('Edit notation'), findsOneWidget);
    controller.dispose();
  });
}
