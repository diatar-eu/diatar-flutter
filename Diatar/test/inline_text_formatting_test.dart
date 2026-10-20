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
  cut: _l10n.kottaEditorCut,
  copy: _l10n.kottaEditorCopy,
  paste: _l10n.kottaEditorPaste,
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
  dotted: _l10n.kottaEditorDotted,
  stemDown: _l10n.kottaEditorStemDown,
  stemless: _l10n.kottaEditorStemless,
  compact: _l10n.kottaEditorCompact,
  lowerSlur: _l10n.kottaEditorLowerSlur,
  upperSlur: _l10n.kottaEditorUpperSlur,
  triplet: _l10n.kottaEditorTriplet,
  quintuplet: _l10n.kottaEditorQuintuplet,
  beaming: _l10n.kottaEditorBeaming,
  noteProperties: _l10n.kottaEditorNoteProperties,
  accidentals: _l10n.kottaEditorAccidentals,
  flat: _l10n.kottaEditorFlat,
  natural: _l10n.kottaEditorNatural,
  sharp: _l10n.kottaEditorSharp,
  doubleFlat: _l10n.kottaEditorDoubleFlat,
  doubleSharp: _l10n.kottaEditorDoubleSharp,
  agogics: _l10n.kottaEditorAgogics,
  tenuto: _l10n.kottaEditorTenuto,
  staccato: _l10n.kottaEditorStaccato,
  marcato: _l10n.kottaEditorMarcato,
  martellato: _l10n.kottaEditorMartellato,
  fermata: _l10n.kottaEditorFermata,
  trill: _l10n.kottaEditorTrill,
  lowerTrill: _l10n.kottaEditorLowerTrill,
  mordent: _l10n.kottaEditorMordent,
  lowerMordent: _l10n.kottaEditorLowerMordent,
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
  InlineTextEditingController controller, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
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

  for (final bool agogics in <bool>[false, true]) {
    group('notation ${agogics ? 'agogics' : 'accidentals'}', () {
      KottaEditorResult? result;
      final List<(String, String, String)> accidentals = agogics
          ? <(String, String, String)>[
              (_kottaLabels.tenuto, 'a-', 'tenuto'),
              (_kottaLabels.staccato, 'a.', 'pont'),
              (_kottaLabels.marcato, 'a>', 'marcato1'),
              (_kottaLabels.martellato, 'a^', 'marcato2'),
              (_kottaLabels.fermata, 'aK', 'koronale'),
              (_kottaLabels.trill, 'at', 'trilla1'),
              (_kottaLabels.lowerTrill, 'aT', 'trilla2'),
              (_kottaLabels.mordent, 'am', 'mordent1'),
              (_kottaLabels.lowerMordent, 'aM', 'mordent2'),
            ]
          : <(String, String, String)>[
              (_kottaLabels.flat, 'mb', 'be'),
              (_kottaLabels.natural, 'm0', 'feloldo'),
              (_kottaLabels.sharp, 'mk', 'kereszt'),
              (_kottaLabels.doubleFlat, 'mB', 'bebe'),
              (_kottaLabels.doubleSharp, 'mK', 'kettoskereszt'),
            ];

      Future<void> open(
        WidgetTester tester, {
        List<String> initial = const <String>[],
        int cursor = 0,
      }) async {
        result = null;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showKottaEditorDialog(
                    context: context,
                    labels: _kottaLabels,
                    previewLineBuilder: (elements) =>
                        '\\K${elements.map((element) => element.command).join()};',
                    initialState: KottaEditorInitialState(
                      elements: <KottaEditorElement>[
                        for (int index = 0; index < initial.length; index++)
                          KottaEditorElement(
                            command: initial[index],
                            textOffset: index,
                            isConditional: true,
                          ),
                      ],
                      textLength: initial.length,
                      kottaCursor: cursor,
                      textCursor: cursor,
                      isEditing: initial.isNotEmpty,
                    ),
                  );
                },
                child: Text(_kottaLabels.insertTitle),
              ),
            ),
          ),
        );
        await tester.tap(find.text(_kottaLabels.insertTitle));
        await tester.pumpAndSettle();
      }

      Future<void> tap(
        WidgetTester tester,
        String label, {
        String? section,
      }) async {
        final Finder button = section == null
            ? find.byTooltip(label)
            : find.descendant(
                of: find
                    .ancestor(
                      of: find.text(section),
                      matching: find.byType(Column),
                    )
                    .first,
                matching: find.byTooltip(label),
              );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }

      bool selected(WidgetTester tester, String label) => tester
          .widget<Semantics>(
            find.descendant(
              of: find.byTooltip(label),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.toggled != null,
              ),
            ),
          )
          .properties
          .toggled!;

      testWidgets(
        'icons, exclusive toggles and one-shot dotted note insertion',
        (tester) async {
          await open(tester);
          final Finder dottedNotes = find.descendant(
            of: find
                .ancestor(
                  of: find.text(_kottaLabels.notes),
                  matching: find.byType(Column),
                )
                .first,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == _kottaLabels.dotted,
            ),
          );
          await tester.ensureVisible(dottedNotes);
          await tester.tap(dottedNotes);
          await tester.pump();
          for (final (String label, String _, String asset) in accidentals) {
            await tap(tester, accidentals[0].$1);
            await tap(tester, accidentals[2].$1);
            if (label != accidentals[2].$1) {
              await tap(tester, label);
            }
            for (final other in accidentals) {
              expect(selected(tester, other.$1), other.$1 == label);
            }
            final Image image = tester.widget<Image>(
              find.descendant(
                of: find.byTooltip(label),
                matching: find.byType(Image),
              ),
            );
            expect(
              (image.image as AssetImage).assetName,
              'assets/kotta/$asset.png',
            );
            final double expectedSize = agogics
                ? (asset == 'pont' ? 5.6 : 16.8)
                : asset == 'kettoskereszt'
                ? 12
                : 24;
            expect(image.width, expectedSize);
            expect(image.height, expectedSize);
            expect(image.color, ThemeData.dark().colorScheme.onSurface);
            await tap(tester, label);
            expect(selected(tester, label), isFalse);
            await tap(tester, label);
            expect(result, isNull);
            if (label == accidentals.first.$1) {
              expect(
                tester
                    .widget<FilledButton>(find.byType(FilledButton))
                    .onPressed,
                isNull,
              );
              await tap(tester, _kottaLabels.gClef);
            }
            if (agogics) {
              await tap(tester, _kottaLabels.flat);
              expect(selected(tester, label), isTrue);
              expect(selected(tester, _kottaLabels.flat), isTrue);
            }
            await tap(
              tester,
              _kottaLabels.quarterRest,
              section: _kottaLabels.rests,
            );
            expect(selected(tester, label), isTrue);
            await tap(
              tester,
              _kottaLabels.quarterNote,
              section: _kottaLabels.notes,
            );
            expect(selected(tester, label), isFalse);
            if (agogics) {
              expect(selected(tester, _kottaLabels.flat), isFalse);
            }
            await tap(
              tester,
              _kottaLabels.quarterNote,
              section: _kottaLabels.notes,
            );
          }
          await tester.tap(find.text(_kottaLabels.apply));
          await tester.pumpAndSettle();
          expect(result!.elements.map((element) => element.command), <String>[
            'kG',
            for (
              int index = 0;
              index < accidentals.length;
              index++
            ) ...<String>[
              's4',
              if (index == 0) 'R4',
              if (agogics) 'mb',
              accidentals[index].$2,
              '2g',
              '2g',
            ],
          ]);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('selection changes preserve the other modifier group', (
        tester,
      ) async {
        await open(
          tester,
          initial: <String>[
            'mb',
            'a-',
            'r8',
            '2c',
            'mk',
            'a>',
            '2d',
            'aK',
            '2e',
          ],
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final String label = agogics
            ? _kottaLabels.lowerTrill
            : _kottaLabels.doubleFlat;
        await tap(tester, label);
        expect(selected(tester, label), isTrue);
        await tap(tester, label);
        expect(selected(tester, label), isFalse);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(
          result!.elements.map((element) => element.command),
          agogics
              ? <String>['mb', 'r8', '2c', 'mk', '2d', 'aK', '2e']
              : <String>['a-', 'r8', '2c', 'a>', '2d', 'aK', '2e'],
        );
        expect(tester.takeException(), isNull);
      });

      for (final testCase
          in <
            ({
              String name,
              List<String> initial,
              int cursor,
              int steps,
              int accidental,
              bool selected,
              List<String> expected,
            })
          >[
            (
              name:
                  'mixed notes replace modifiers and leave outside notes alone',
              initial: <String>['mb', '2c', 'mk', '2d', 's4', '2e', 'mK', '2f'],
              cursor: 0,
              steps: 4,
              accidental: 0,
              selected: false,
              expected: <String>[
                'mb',
                '2c',
                'mb',
                '2d',
                's4',
                'mb',
                '2e',
                'mK',
                '2f',
              ],
            ),
            (
              name:
                  'matching modifiers are removed across intervening commands',
              initial: <String>['mB', 'r8', '2c', 'mB', 'rt', '2d', 'mb', '2e'],
              cursor: 0,
              steps: 2,
              accidental: 3,
              selected: true,
              expected: <String>['r8', '2c', '2d', 'mb', '2e'],
            ),
            (
              name: 'reverse selection replaces multiple preceding modifiers',
              initial: <String>['m0', '2c', 'mb', 'mk', 'r2', '2d', 'mK', '2e'],
              cursor: 6,
              steps: -1,
              accidental: 4,
              selected: false,
              expected: <String>['m0', '2c', 'r2', 'mK', '2d', 'mK', '2e'],
            ),
            (
              name:
                  'pitch-only selection at the end replaces an outside modifier',
              initial: <String>['2c', 'mb', 'r2', '2D'],
              cursor: 3,
              steps: 1,
              accidental: 1,
              selected: false,
              expected: <String>['2c', 'r2', 'm0', '2D'],
            ),
            (
              name:
                  'rest-only selection does not modify or latch an accidental',
              initial: <String>['mb', 's4', 'mk', '2c'],
              cursor: 0,
              steps: 1,
              accidental: 2,
              selected: false,
              expected: <String>['mb', 's4', 'mk', '2c'],
            ),
            (
              name:
                  'rest consumes a pending modifier before an unmodified note',
              initial: <String>['mb', 's4', '2c', 'm0', '2d'],
              cursor: 2,
              steps: 1,
              accidental: 0,
              selected: false,
              expected: <String>['mb', 's4', 'mb', '2c', 'm0', '2d'],
            ),
          ]) {
        testWidgets(testCase.name, (tester) async {
          String commandForGroup(String command) {
            if (!agogics) {
              return command;
            }
            return switch (command) {
              'mb' => 'a-',
              'm0' => 'a.',
              'mk' => 'a>',
              'mB' => 'a^',
              'mK' => 'aK',
              _ => command,
            };
          }

          final bool acrossRest =
              agogics && testCase.name.startsWith('rest consumes');
          final bool initiallySelected = acrossRest || testCase.selected;
          final List<String> expected = acrossRest
              ? <String>['s4', '2c', 'a.', '2d']
              : testCase.expected.map(commandForGroup).toList();
          await open(
            tester,
            initial: testCase.initial.map(commandForGroup).toList(),
            cursor: testCase.cursor,
          );
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          for (int step = 0; step < testCase.steps.abs(); step++) {
            await tester.sendKeyEvent(
              testCase.steps > 0
                  ? LogicalKeyboardKey.arrowRight
                  : LogicalKeyboardKey.arrowLeft,
            );
          }
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();
          final String label = accidentals[testCase.accidental].$1;
          expect(selected(tester, label), initiallySelected);
          await tap(tester, label);
          expect(
            selected(tester, label),
            testCase.name.startsWith('rest-only') ? false : !initiallySelected,
          );
          final ProjectorPainter painter =
              tester
                      .widget<CustomPaint>(
                        find.byWidgetPredicate(
                          (widget) =>
                              widget is CustomPaint &&
                              widget.painter is ProjectorPainter,
                        ),
                      )
                      .painter!
                  as ProjectorPainter;
          final TextSelection selection =
              painter.editorCursorOverlay!.kottaSelection!;
          expect(
            selection.baseOffset < selection.extentOffset,
            testCase.steps > 0,
          );
          if (!testCase.name.startsWith('rest-only')) {
            await tap(tester, label);
            expect(selected(tester, label), initiallySelected);
            await tap(tester, label);
          }
          await tester.tap(find.text(_kottaLabels.apply));
          await tester.pumpAndSettle();
          expect(result!.elements.map((element) => element.command), expected);
          expect(
            result!.elements.every((element) => element.isConditional),
            isTrue,
          );
          for (int index = 0; index < result!.elements.length - 1; index++) {
            final KottaEditorElement element = result!.elements[index];
            if (element.command == accidentals[testCase.accidental].$2 &&
                index >= selection.start &&
                index < selection.end &&
                !testCase.name.startsWith('rest-only') &&
                !initiallySelected) {
              expect(
                element.textOffset,
                result!.elements[index + 1].textOffset,
              );
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('notation toggles keep their outline and ink in $brightness', (
      tester,
    ) async {
      final controller = InlineTextEditingController.fromDia(r'\K2g;word');
      final ThemeData theme = ThemeData(brightness: brightness);
      await _openNotationPreview(tester, controller, theme: theme);
      Finder section(String label) => find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first;
      final Finder stem = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == _kottaLabels.stemDown,
      );
      expect(
        find.descendant(of: section(_kottaLabels.notes), matching: stem),
        findsNothing,
      );
      expect(
        find.descendant(
          of: section(_kottaLabels.noteProperties),
          matching: stem,
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(_kottaLabels.noteProperties)).dy,
        greaterThan(tester.getTopLeft(find.text(_kottaLabels.notes)).dy),
      );
      for (final Finder button in <Finder>[
        for (final String label in <String>[
          _kottaLabels.rests,
          _kottaLabels.notes,
        ])
          find.descendant(
            of: section(label),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == _kottaLabels.dotted,
            ),
          ),
        stem,
        for (final String label in <String>[
          _kottaLabels.lowerSlur,
          _kottaLabels.upperSlur,
          _kottaLabels.triplet,
          _kottaLabels.quintuplet,
        ])
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == label,
          ),
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.compact,
        ),
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.stemless,
        ),
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.beaming,
        ),
      ]) {
        final CustomPainter? beforePainter = button == stem
            ? (tester.widget<IconButton>(button).icon as CustomPaint).painter
            : null;
        for (final bool selected in <bool>[false, true, false]) {
          if (tester.widget<IconButton>(button).isSelected != selected) {
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pump();
          }
          final IconButton widget = tester.widget<IconButton>(button);
          final Set<WidgetState> states = <WidgetState>{
            if (selected) WidgetState.selected,
          };
          expect(widget.isSelected, selected);
          expect(
            widget.style!.foregroundColor!.resolve(states),
            theme.colorScheme.onSurface,
          );
          expect(
            widget.style!.side!.resolve(states),
            BorderSide(color: theme.colorScheme.outline),
          );
          if (selected) {
            expect(
              widget.style!.backgroundColor!.resolve(states),
              theme.colorScheme.secondaryContainer,
            );
            if (beforePainter != null) {
              final CustomPainter painter =
                  (widget.icon as CustomPaint).painter!;
              expect(painter.shouldRepaint(beforePainter), isTrue);
            }
          }
        }
      }
      await tester.tap(find.text(_kottaLabels.cancel));
      await tester.pumpAndSettle();
      controller.dispose();
    });
  }

  testWidgets(
    'beaming follows the preceding note and resets on cursor movement',
    (tester) async {
      final controller = InlineTextEditingController.fromDia(
        r'\Kr8[?2g2a]?2h;word',
      );
      await _openNotationPreview(tester, controller);
      final Finder toggle = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == _kottaLabels.beaming,
      );
      bool beamed() => tester.widget<IconButton>(toggle).isSelected!;
      expect(beamed(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(beamed(), isTrue);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(beamed(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(beamed(), isTrue);
      final Finder eighth = find.descendant(
        of: find
            .ancestor(
              of: find.text(_kottaLabels.notes),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byTooltip(_kottaLabels.eighthNote),
      );
      await tester.ensureVisible(eighth);
      await tester.tap(eighth);
      await tester.pump();
      expect(beamed(), isTrue);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await tester.ensureVisible(eighth);
      await tester.tap(eighth);
      await tester.pump();
      expect(beamed(), isFalse);
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(controller.encodedText, r'\Kr8[?2g2a2a]?2a2h;word');
      controller.dispose();
    },
  );

  for (final bool forward in <bool>[false, true]) {
    for (final bool apply in <bool>[false, true]) {
      testWidgets('beaming ${apply ? 'enables' : 'disables'} only the '
          '${forward ? 'forward' : 'backward'} selection', (tester) async {
        final controller = InlineTextEditingController.fromDia(
          apply ? r'\?Kr82g2as42h2d;word' : r'\?Kr8[?2g2as42h2d]?;word',
        );
        await _openNotationPreview(tester, controller);
        // Select the middle two notes and the intervening rest.
        final int start = apply ? 2 : 3;
        final int end = apply ? 5 : 6;
        await tester.tapAt(
          _kottaPosition(tester, forward ? start : end),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int index = 0; index < 3; index++) {
          await tester.sendKeyEvent(
            forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final Finder toggle = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.beaming,
        );
        expect(tester.widget<IconButton>(toggle).isSelected, !apply);
        final bool wasForward =
            _notationOverlay(tester).kottaSelection!.baseOffset <
            _notationOverlay(tester).kottaSelection!.extentOffset;
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<IconButton>(toggle).isSelected, apply);
        final TextSelection selection = _notationOverlay(
          tester,
        ).kottaSelection!;
        expect(selection.baseOffset < selection.extentOffset, wasForward);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(
          controller.encodedText,
          apply ? r'\?Kr82g[?2as42h]?2d;word' : r'\?Kr8[?2g]?2as42h[?2d]?;word',
        );
        controller.dispose();
      });
    }
  }

  for (final (String source, String expected) in <(String, String)>[
    (r'\Kr8]?[0[?[?2g[?2a]?]?;word', r'\Kr8[0[?2g2a]?;word'),
    (r'\Kr8[?]?[?2g]?2a[?]?;word', r'\Kr8[?2g]?2a;word'),
    (r'\Kr8[?2g2a;word', r'\Kr8[?2g2a]?;word'),
    (r'\Kr8[?2g]?[?2a]?;word', r'\Kr8[?2g]?[?2a]?;word'),
    (r'\Kr8[?[32g]32a]?;word', r'\Kr8[?[32g]32a]?;word'),
  ]) {
    testWidgets('beaming normalizes $source without merging separate groups', (
      tester,
    ) async {
      final controller = InlineTextEditingController.fromDia(source);
      await _openNotationPreview(tester, controller);
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(controller.encodedText, expected);
      controller.dispose();
    });
  }

  testWidgets('beaming starts a group and extends it on repeated insertions', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(r'\Kr82g;word');
    await _openNotationPreview(tester, controller);
    final Finder toggle = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == _kottaLabels.beaming,
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    final Finder eighth = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.eighthNote),
    );
    for (int index = 0; index < 2; index++) {
      await tester.ensureVisible(eighth);
      await tester.tap(eighth);
      await tester.pump();
    }
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\Kr82g[?2g2g]?;word');
    controller.dispose();
  });

  testWidgets('replacing a beam end does not beam the following notes', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(
      r'\Kr8[?2g2a]?2h2d;word',
    );
    await _openNotationPreview(tester, controller);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection!.start, 5);
    final Finder eighth = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.eighthNote),
    );
    await tester.ensureVisible(eighth);
    await tester.tap(eighth);
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\Kr8[?2g2a]?2a2d;word');
    controller.dispose();
  });

  for (final (String source, String expected) in <(String, String)>[
    (r'\K[1[0[12g[0[1;word', r'\K2g;word'),
    (r'\K[0[02g[02a[1[12h[1;word', r'\K[02g2a[12h;word'),
    (r'\?K2g[0s4a.[1|12a[0;word', r'\?K2gs4a.|12a;word'),
    (r'\K[0[?r82g[02a[1[0]?2h[1[12d;word', r'\K[0r8[?2g2a]?2h[12d;word'),
    (r'\K[0[1[0;word', 'word'),
  ]) {
    testWidgets(
      'stem mode normalization is minimal and idempotent for $source',
      (tester) async {
        final controller = InlineTextEditingController.fromDia(source);
        for (int pass = 0; pass < 2; pass++) {
          await _openNotationPreview(tester, controller);
          await tester.tap(find.text(_kottaLabels.apply));
          await tester.pumpAndSettle();
          expect(controller.encodedText, expected);
          if (expected == 'word') {
            break;
          }
        }
        controller.dispose();
      },
    );
  }

  for (final bool forward in <bool>[false, true]) {
    testWidgets('repeated stemless toggles normalize the '
        '${forward ? 'forward' : 'backward'} selection without moving it', (
      tester,
    ) async {
      final controller = InlineTextEditingController.fromDia(
        r'\?K2g2a2h2d;word',
      );
      await _openNotationPreview(tester, controller);
      await tester.tapAt(
        _kottaPosition(tester, forward ? 1 : 3),
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (int index = 0; index < 2; index++) {
        await tester.sendKeyEvent(
          forward
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft,
        );
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final Finder toggle = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == _kottaLabels.stemless,
      );
      await tester.ensureVisible(toggle);
      for (int cycle = 0; cycle < 3; cycle++) {
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<IconButton>(toggle).isSelected, isTrue);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<IconButton>(toggle).isSelected, isFalse);
        expect(
          _notationOverlay(tester).kottaSelection,
          TextSelection(
            baseOffset: forward ? 1 : 3,
            extentOffset: forward ? 3 : 1,
          ),
        );
      }
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(controller.encodedText, r'\?K2g2a2h2d;word');
      controller.dispose();
    });
  }

  for (final (String source, String expected) in <(String, String)>[
    (r'\KrtRtrt2gRtrt;word', r'\K2g;word'),
    (r'\KRtRt2gRt2artrt2hrt;word', r'\KRt2g2art2h;word'),
    (r'\?K2gRts4a.rt|12aRt;word', r'\?K2gs4a.|12a;word'),
    (r'\K[0Rt[?r82gRt2artRt]?2hrt[12d;word', r'\K[0Rtr8[?2g2a]?2hrt[12d;word'),
  ]) {
    testWidgets('compact mode normalizes idempotently for $source', (
      tester,
    ) async {
      final controller = InlineTextEditingController.fromDia(source);
      for (int pass = 0; pass < 2; pass++) {
        await _openNotationPreview(tester, controller);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, expected);
      }
      controller.dispose();
    });
  }

  testWidgets('compact follows the cursor and isolates repeated insertions', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(
      r'\Kr8[0Rt2grt2a;word',
    );
    await _openNotationPreview(tester, controller);
    final Finder toggle = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == _kottaLabels.compact,
    );
    bool compact() => tester.widget<IconButton>(toggle).isSelected!;
    expect(compact(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(compact(), isTrue);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(compact(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(compact(), isTrue);
    final Finder quarter = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.quarterNote),
    );
    for (int index = 0; index < 2; index++) {
      await tester.ensureVisible(quarter);
      await tester.tap(quarter);
      await tester.pump();
      expect(compact(), isTrue);
    }
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    expect(compact(), isFalse);
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\Kr8[0Rt2gr42g2grt2gr82a;word');
    controller.dispose();
  });

  for (final bool forward in <bool>[false, true]) {
    for (final testCase
        in <
          ({
            String source,
            int start,
            int end,
            int steps,
            bool selected,
            String expected,
          })
        >[
          (
            source: r'\?K2g2as42h2d;word',
            start: 1,
            end: 4,
            steps: 3,
            selected: false,
            expected: r'\?K2gRt2as42hrt2d;word',
          ),
          (
            source: r'\?KRt2g2as42h2d;word',
            start: 2,
            end: 5,
            steps: 3,
            selected: true,
            expected: r'\?KRt2grt2as42hRt2d;word',
          ),
          (
            source: r'\?K[02gRt2art2h2d;word',
            start: 2,
            end: 6,
            steps: 2,
            selected: false,
            expected: r'\?K[02gRt2a2hrt2d;word',
          ),
          (
            source: r'\?KRt2gs42a;word',
            start: 2,
            end: 3,
            steps: 1,
            selected: false,
            expected: r'\?KRt2gs42a;word',
          ),
        ]) {
      testWidgets('compact isolates ${forward ? 'forward' : 'backward'} '
          'selection in ${testCase.source}', (tester) async {
        final controller = InlineTextEditingController.fromDia(testCase.source);
        await _openNotationPreview(tester, controller);
        await tester.tapAt(
          _kottaPosition(tester, forward ? testCase.start : testCase.end),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int index = 0; index < testCase.steps; index++) {
          await tester.sendKeyEvent(
            forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final Finder toggle = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.compact,
        );
        expect(tester.widget<IconButton>(toggle).isSelected, testCase.selected);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pump();
        final TextSelection selection = _notationOverlay(
          tester,
        ).kottaSelection!;
        expect(selection.baseOffset < selection.extentOffset, forward);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, testCase.expected);
        controller.dispose();
      });
    }
  }

  testWidgets('compact and stemless insertion overrides remain independent', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(r'\K2g2a;word');
    await _openNotationPreview(tester, controller);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    for (final String label in <String>[
      _kottaLabels.compact,
      _kottaLabels.stemless,
    ]) {
      final Finder toggle = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == label,
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }
    final Finder quarter = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.quarterNote),
    );
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\K2g[0Rt2grt[12a;word');
    controller.dispose();
  });

  for (final bool tuplets in <bool>[false, true]) {
    for (final String direction
        in tuplets ? <String>['3', '5'] : <String>['a', 'f']) {
      final String open = tuplets ? '[' : '(';
      final String close = tuplets ? ']' : ')';
      final String family = tuplets ? 'tuplet' : 'slur';
      final String label = tuplets
          ? (direction == '3' ? _kottaLabels.triplet : _kottaLabels.quintuplet)
          : direction == 'a'
          ? _kottaLabels.lowerSlur
          : _kottaLabels.upperSlur;
      final String otherLabel = tuplets
          ? (direction == '3' ? _kottaLabels.quintuplet : _kottaLabels.triplet)
          : direction == 'a'
          ? _kottaLabels.upperSlur
          : _kottaLabels.lowerSlur;
      final String other = tuplets
          ? (direction == '3' ? '5' : '3')
          : direction == 'a'
          ? 'f'
          : 'a';

      testWidgets(
        '$direction $family follows cursor and extends repeated insertions',
        (tester) async {
          final controller = InlineTextEditingController.fromDia(
            '\\Kr8$open$direction'
            '2g2a$close$direction'
            '2h;word',
          );
          await _openNotationPreview(tester, controller);
          Finder button(String tooltip) => find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tooltip,
          );
          bool selected(String tooltip) =>
              tester.widget<IconButton>(button(tooltip)).isSelected!;
          expect(selected(label), isFalse);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();
          expect(selected(label), isTrue);
          await tester.ensureVisible(button(otherLabel));
          await tester.tap(button(otherLabel));
          await tester.pump();
          expect(selected(otherLabel), isTrue);
          expect(selected(label), isFalse);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();
          expect(selected(label), isTrue);
          expect(selected(otherLabel), isFalse);
          final Finder eighth = find.descendant(
            of: find
                .ancestor(
                  of: find.text(_kottaLabels.notes),
                  matching: find.byType(Column),
                )
                .first,
            matching: find.byTooltip(_kottaLabels.eighthNote),
          );
          for (int index = 0; index < 2; index++) {
            await tester.ensureVisible(eighth);
            await tester.tap(eighth);
            await tester.pump();
            expect(selected(label), isTrue);
          }
          await tester.ensureVisible(button(label));
          await tester.tap(button(label));
          await tester.pump();
          expect(selected(label), isFalse);
          await tester.ensureVisible(eighth);
          await tester.tap(eighth);
          await tester.pump();
          await tester.tap(find.text(_kottaLabels.apply));
          await tester.pumpAndSettle();
          expect(
            controller.encodedText,
            '\\Kr8$open$direction'
            '2g2a2a2a$close$direction'
            '2a2h;word',
          );
          controller.dispose();
        },
      );

      for (final bool forward in <bool>[false, true]) {
        for (final String initial in <String>['', direction, other]) {
          testWidgets(
            '$direction $family edits ${forward ? 'forward' : 'backward'} '
            'selection with initial $initial $family',
            (tester) async {
              final bool existing = initial.isNotEmpty;
              final controller = InlineTextEditingController.fromDia(
                '\\?Kr8${existing ? '$open$initial' : ''}'
                '2g2as42h2d${existing ? '$close$initial' : ''};word',
              );
              await _openNotationPreview(tester, controller);
              final int start = existing ? 3 : 2;
              final int end = existing ? 6 : 5;
              await tester.tapAt(
                _kottaPosition(tester, forward ? start : end),
                kind: ui.PointerDeviceKind.mouse,
              );
              await tester.pump();
              await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
              for (int index = 0; index < 3; index++) {
                await tester.sendKeyEvent(
                  forward
                      ? LogicalKeyboardKey.arrowRight
                      : LogicalKeyboardKey.arrowLeft,
                );
              }
              await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
              await tester.pump();
              final Finder toggle = find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == label,
              );
              expect(
                tester.widget<IconButton>(toggle).isSelected,
                initial == direction,
              );
              await tester.ensureVisible(toggle);
              await tester.tap(toggle);
              await tester.pump();
              expect(
                tester.widget<IconButton>(toggle).isSelected,
                initial != direction,
              );
              final TextSelection selection = _notationOverlay(
                tester,
              ).kottaSelection!;
              expect(selection.baseOffset < selection.extentOffset, forward);
              await tester.tap(find.text(_kottaLabels.apply));
              await tester.pumpAndSettle();
              final String middle = initial == direction
                  ? '2as42h'
                  : '$open$direction'
                        '2as42h$close$direction';
              expect(
                controller.encodedText,
                '\\?Kr8${existing ? '$open$initial' : ''}2g'
                '${existing ? '$close$initial' : ''}$middle'
                '${existing ? '$open$initial' : ''}2d'
                '${existing ? '$close$initial' : ''};word',
              );
              controller.dispose();
            },
          );
        }
      }
    }
  }

  for (final (String source, String expected) in <(String, String)>[
    (r'\K]3[3[52g2a]5]5;word', r'\K[52g2a]5;word'),
    (r'\K[3]32g[5]5;word', r'\K2g;word'),
    (r'\K[32g2a;word', r'\K[32g2a]3;word'),
    (r'\K[32g]3[32a]3;word', r'\K[32g]3[32a]3;word'),
    (r'\K[32g[52a2h]3;word', r'\K[32g]3[52a2h]5;word'),
    (
      r'\Kr8Rt[0[?(a[32g2a]3)a]?rt[12h;word',
      r'\Kr8Rt[0[?(a[32g2a]3)a]?rt[12h;word',
    ),
  ]) {
    testWidgets('tuplet normalization is idempotent for $source', (
      tester,
    ) async {
      final controller = InlineTextEditingController.fromDia(source);
      for (int pass = 0; pass < 2; pass++) {
        await _openNotationPreview(tester, controller);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, expected);
      }
      controller.dispose();
    });
  }
  for (final (String source, String expected) in <(String, String)>[
    (r'\K)a(a(f2g2a)f)f;word', r'\K(f2g2a)f;word'),
    (r'\K(a)a2g(f)f;word', r'\K2g;word'),
    (r'\K(a2g2a;word', r'\K(a2g2a)a;word'),
    (r'\K(a2g)a(a2a)a;word', r'\K(a2g)a(a2a)a;word'),
    (r'\Kr8Rt[0[?(a2g2a)a]?rt[12h;word', r'\Kr8Rt[0[?(a2g2a)a]?rt[12h;word'),
  ]) {
    testWidgets('slur normalization is idempotent for $source', (tester) async {
      final controller = InlineTextEditingController.fromDia(source);
      for (int pass = 0; pass < 2; pass++) {
        await _openNotationPreview(tester, controller);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, expected);
      }
      controller.dispose();
    });
  }

  for (final bool tuplets in <bool>[false, true]) {
    final String open = tuplets ? '[3' : '(a';
    final String close = tuplets ? ']3' : ')a';
    final String family = tuplets ? 'tuplet' : 'slur';
    testWidgets(
      '$family selection replacement does not capture following notes',
      (tester) async {
        final controller = InlineTextEditingController.fromDia(
          '\\Kr8${open}2g2a${close}2h2d;word',
        );
        await _openNotationPreview(tester, controller);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final Finder eighth = find.descendant(
          of: find
              .ancestor(
                of: find.text(_kottaLabels.notes),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byTooltip(_kottaLabels.eighthNote),
        );
        await tester.ensureVisible(eighth);
        await tester.tap(eighth);
        await tester.pump();
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, '\\Kr8${open}2g2a${close}2a2d;word');
        controller.dispose();
      },
    );

    for (final (String source, int steps, String expected)
        in <(String, int, String)>[
          (
            '\\K${open}2g$close${tuplets ? '[5' : '(f'}2a${tuplets ? ']5' : ')f'}2h;word',
            2,
            '\\K${open}2g2a${close}2h;word',
          ),
          ('\\K${open}2g${close}2a2h;word', 2, '\\K${open}2g2a${close}2h;word'),
          (r'\Ks42g;word', 1, r'\Ks42g;word'),
          (r'\K2g2a;word', 2, '\\K${open}2g2a$close;word'),
        ]) {
      testWidgets('$family handles mixed and rest-only selections in $source', (
        tester,
      ) async {
        final controller = InlineTextEditingController.fromDia(source);
        await _openNotationPreview(tester, controller);
        for (int index = 0; index < 4; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int index = 0; index < steps; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final Finder lower = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip ==
                  (tuplets ? _kottaLabels.triplet : _kottaLabels.lowerSlur),
        );
        final Finder upper = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip ==
                  (tuplets ? _kottaLabels.quintuplet : _kottaLabels.upperSlur),
        );
        expect(tester.widget<IconButton>(lower).isSelected, isFalse);
        expect(tester.widget<IconButton>(upper).isSelected, isFalse);
        await tester.ensureVisible(lower);
        for (int cycle = 0; cycle < 3; cycle++) {
          await tester.tap(lower);
          await tester.pump();
          if (cycle < 2) {
            await tester.tap(lower);
            await tester.pump();
          }
        }
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, expected);
        controller.dispose();
      });
    }
  }

  testWidgets('tuplet and slur insertion overrides are independent', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(
      r'\Kr8[?2g2a]?;word',
    );
    await _openNotationPreview(tester, controller);
    for (final String label in <String>[
      _kottaLabels.lowerSlur,
      _kottaLabels.quintuplet,
    ]) {
      final Finder toggle = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == label,
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }
    final Finder eighth = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.eighthNote),
    );
    for (int index = 0; index < 2; index++) {
      await tester.ensureVisible(eighth);
      await tester.tap(eighth);
      await tester.pump();
    }
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\Kr8[?2g2a(a[52a2a]5)a]?;word');
    controller.dispose();
  });

  testWidgets('compact replacement preserves surrounding note modes', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(
      r'\K2gRt2a2hrt2d;word',
    );
    await _openNotationPreview(tester, controller);
    await tester.tapAt(
      _kottaPosition(tester, 1),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (int index = 0; index < 2; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    final Finder quarter = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.quarterNote),
    );
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\K2gRt2grt2d;word');
    controller.dispose();
  });

  testWidgets('stemless follows the preceding note and isolates insertions', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(r'\K[02g[12a;word');
    await _openNotationPreview(tester, controller);
    final Finder toggle = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == _kottaLabels.stemless,
    );
    bool stemless() => tester.widget<IconButton>(toggle).isSelected!;
    expect(stemless(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(stemless(), isTrue);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(stemless(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(stemless(), isTrue);
    final Finder quarter = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.quarterNote),
    );
    for (int index = 0; index < 2; index++) {
      await tester.ensureVisible(quarter);
      await tester.tap(quarter);
      await tester.pump();
      expect(stemless(), isTrue);
    }
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    expect(stemless(), isFalse);
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\K[02g2g2g[12g2a;word');
    controller.dispose();
  });

  for (final bool forward in <bool>[false, true]) {
    for (final testCase
        in <
          ({
            String source,
            int start,
            int end,
            int steps,
            bool selected,
            String expected,
          })
        >[
          (
            source: r'\?K2g2as42h2d;word',
            start: 1,
            end: 4,
            steps: 3,
            selected: false,
            expected: r'\?K2g[02as42h[12d;word',
          ),
          (
            source: r'\?K[02g2as42h2d;word',
            start: 2,
            end: 5,
            steps: 3,
            selected: true,
            expected: r'\?K[02g[12as42h[02d;word',
          ),
          (
            source: r'\?K2g[02a[12h2d;word',
            start: 1,
            end: 5,
            steps: 2,
            selected: false,
            expected: r'\?K2g[02a2h[12d;word',
          ),
          (
            source: r'\?K[02g[12a[02h2d;word',
            start: 2,
            end: 6,
            steps: 2,
            selected: false,
            expected: r'\?K[02g2a2h2d;word',
          ),
          (
            source: r'\?K[02gs42a;word',
            start: 2,
            end: 3,
            steps: 1,
            selected: false,
            expected: r'\?K[02gs42a;word',
          ),
          (
            source: r'\?K2g2a;word',
            start: 1,
            end: 2,
            steps: 1,
            selected: false,
            expected: r'\?K2g[02a;word',
          ),
        ]) {
      testWidgets('stemless isolates ${forward ? 'forward' : 'backward'} '
          'selection in ${testCase.source}', (tester) async {
        final controller = InlineTextEditingController.fromDia(testCase.source);
        await _openNotationPreview(tester, controller);
        await tester.tapAt(
          _kottaPosition(tester, forward ? testCase.start : testCase.end),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int index = 0; index < testCase.steps; index++) {
          await tester.sendKeyEvent(
            forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final Finder toggle = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.stemless,
        );
        expect(tester.widget<IconButton>(toggle).isSelected, testCase.selected);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pump();
        expect(
          tester.widget<IconButton>(toggle).isSelected,
          testCase.start == 2 && testCase.end == 3 ? false : !testCase.selected,
        );
        final TextSelection selection = _notationOverlay(
          tester,
        ).kottaSelection!;
        expect(selection.baseOffset < selection.extentOffset, forward);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, testCase.expected);
        controller.dispose();
      });
    }
  }

  testWidgets('stemless replacement preserves surrounding note modes', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(
      r'\K2g[02a2h[12d;word',
    );
    await _openNotationPreview(tester, controller);
    await tester.tapAt(
      _kottaPosition(tester, 1),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (int index = 0; index < 2; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    final Finder quarter = find.descendant(
      of: find
          .ancestor(
            of: find.text(_kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byTooltip(_kottaLabels.quarterNote),
    );
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\K2g[02g[12d;word');
    controller.dispose();
  });

  testWidgets('stem direction follows cursor and supports insertion override', (
    tester,
  ) async {
    final controller = InlineTextEditingController.fromDia(r'\K2G2a;word');
    await _openNotationPreview(tester, controller);
    final Finder toggle = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == _kottaLabels.stemDown,
    );
    bool down() => tester.widget<IconButton>(toggle).isSelected!;
    expect(down(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(down(), isTrue);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(down(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(down(), isTrue);
    final Finder notes = find
        .ancestor(
          of: find.text(_kottaLabels.notes),
          matching: find.byType(Column),
        )
        .first;
    final Finder quarter = find.descendant(
      of: notes,
      matching: find.byTooltip(_kottaLabels.quarterNote),
    );
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    expect(down(), isTrue);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pump();
    expect(down(), isFalse);
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\K2G2G2g2a;word');
    controller.dispose();
  });

  for (final bool forward in <bool>[false, true]) {
    testWidgets(
      'stem toggle edits ${forward ? 'forward' : 'backward'} mixed selection',
      (tester) async {
        final controller = InlineTextEditingController.fromDia(
          r'\?K2g2As42h2D;word',
        );
        await _openNotationPreview(tester, controller);
        await tester.tapAt(
          _kottaPosition(tester, forward ? 1 : 4),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int index = 0; index < 3; index++) {
          await tester.sendKeyEvent(
            forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final TextSelection selection = _notationOverlay(
          tester,
        ).kottaSelection!;
        expect(selection.start, 1);
        expect(selection.end, 4);
        final Finder toggle = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.stemDown,
        );
        expect(tester.widget<IconButton>(toggle).isSelected, isFalse);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<IconButton>(toggle).isSelected, isTrue);
        expect(_notationOverlay(tester).kottaSelection, selection);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<IconButton>(toggle).isSelected, isFalse);
        expect(_notationOverlay(tester).kottaSelection, selection);
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(controller.encodedText, r'\?K2g2as42h2D;word');
        controller.dispose();
      },
    );
  }

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
          <String>[...rests.map((rest) => rest.$1), _kottaLabels.dotted],
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

  for (final bool rests in <bool>[true, false]) {
    testWidgets('dotted ${rests ? 'rests' : 'notes'} latch for insertion', (
      WidgetTester tester,
    ) async {
      KottaEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
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
      );
      await tester.tap(find.text(_kottaLabels.insertTitle));
      await tester.pumpAndSettle();
      Finder section(bool forRests) => find
          .ancestor(
            of: find.text(forRests ? _kottaLabels.rests : _kottaLabels.notes),
            matching: find.byType(Column),
          )
          .first;
      Finder toggle(bool forRests) => find.descendant(
        of: section(forRests),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.dotted,
        ),
      );
      await tester.ensureVisible(toggle(rests));
      await tester.tap(toggle(rests));
      await tester.pump();
      expect(tester.widget<IconButton>(toggle(rests)).isSelected, isTrue);
      expect(tester.widget<IconButton>(toggle(!rests)).isSelected, isFalse);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final List<String> labels = rests
          ? <String>[
              _kottaLabels.wholeRest,
              _kottaLabels.halfRest,
              _kottaLabels.quarterRest,
              _kottaLabels.eighthRest,
              _kottaLabels.sixteenthRest,
            ]
          : <String>[
              _kottaLabels.wholeNote,
              _kottaLabels.halfNote,
              _kottaLabels.quarterNote,
              _kottaLabels.eighthNote,
              _kottaLabels.sixteenthNote,
              _kottaLabels.longa,
              _kottaLabels.brevis,
              _kottaLabels.semibrevis,
            ];
      for (final String label in labels) {
        final Finder button = find.descendant(
          of: section(rests),
          matching: find.byTooltip(label),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }
      await tester.ensureVisible(toggle(rests));
      await tester.tap(toggle(rests));
      await tester.pump();
      final Finder plain = find.descendant(
        of: section(rests),
        matching: find.byTooltip(
          rests ? _kottaLabels.quarterRest : _kottaLabels.quarterNote,
        ),
      );
      await tester.ensureVisible(plain);
      await tester.tap(plain);
      await tester.pump();
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(result!.elements.map((element) => element.command), <String>[
        for (final String duration in <String>[
          '1',
          '2',
          '4',
          '8',
          '6',
        ]) ...<String>['${rests ? 'S' : 'R'}$duration', if (!rests) '2g'],
        if (!rests)
          for (final String duration in <String>['l', 'b', 's']) ...<String>[
            'r$duration',
            '2g',
          ],
        '${rests ? 's' : 'r'}4',
        if (!rests) '2g',
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final testCase
      in <
        ({
          String name,
          List<String> initial,
          int cursor,
          int steps,
          bool rests,
          bool selected,
          List<String> expected,
        })
      >[
        (
          name: 'inherited note rhythm is isolated at both selection edges',
          initial: <String>['r8', '2c', '2d', 's4', '|1', 'rt', '2e'],
          cursor: 2,
          steps: 1,
          rests: false,
          selected: false,
          expected: <String>['r8', '2c', 'R8', '2d', 's4', '|1', 'r8', '2e'],
        ),
        (
          name: 'implicit default quarter rhythm is restored after selection',
          initial: <String>['2c', '2d'],
          cursor: 0,
          steps: 1,
          rests: false,
          selected: false,
          expected: <String>['R4', '2c', 'r4', '2d'],
        ),
        (
          name: 'undotting restores dotted following notes',
          initial: <String>['R4', '2c', '2d', '2e'],
          cursor: 2,
          steps: 1,
          rests: false,
          selected: true,
          expected: <String>['R4', '2c', 'r4', '2d', 'R4', '2e'],
        ),
        (
          name:
              'mixed notes become dotted with explicit later rhythm preserved',
          initial: <String>['R2', '2c', 'r8', '2d', 'r6', '2e'],
          cursor: 0,
          steps: 2,
          rests: false,
          selected: false,
          expected: <String>['R2', '2c', 'R8', '2d', 'r6', '2e'],
        ),
        (
          name: 'reverse selection preserves following implicit rhythm',
          initial: <String>['r2', '2c', '2d', '2e'],
          cursor: 3,
          steps: -1,
          rests: false,
          selected: false,
          expected: <String>['r2', '2c', 'R2', '2d', 'r2', '2e'],
        ),
        (
          name: 'all five note durations support dotting',
          initial: <String>[
            'r1',
            '2c',
            'r2',
            '2d',
            'r4',
            '2e',
            'r8',
            '2f',
            'r6',
            '2g',
          ],
          cursor: 0,
          steps: 5,
          rests: false,
          selected: false,
          expected: <String>[
            'R1',
            '2c',
            'R2',
            '2d',
            'R4',
            '2e',
            'R8',
            '2f',
            'R6',
            '2g',
          ],
        ),
        (
          name:
              'unsupported long notes stay lowercase and are ignored in state',
          initial: <String>['rl', '2c', 'rb', '2d', 'rs', '2e', 'R4', '2f'],
          cursor: 0,
          steps: 4,
          rests: false,
          selected: true,
          expected: <String>['rl', '2c', 'rb', '2d', 'rs', '2e', 'r4', '2f'],
        ),
        (
          name: 'rest-only selection does not change notes',
          initial: <String>['R4', '2c', 's4', '2d'],
          cursor: 2,
          steps: 1,
          rests: false,
          selected: false,
          expected: <String>['R4', '2c', 's4', '2d'],
        ),
        (
          name: 'mixed rests become dotted without changing notes',
          initial: <String>['s1', 'S2', 's4', 'S8', 's6', 'R4', '2c', 's4'],
          cursor: 0,
          steps: 6,
          rests: true,
          selected: false,
          expected: <String>['S1', 'S2', 'S4', 'S8', 'S6', 'R4', '2c', 's4'],
        ),
        (
          name: 'dotted rests become plain without changing outside rests',
          initial: <String>['S4', 'S8', 'S6'],
          cursor: 0,
          steps: 2,
          rests: true,
          selected: true,
          expected: <String>['s4', 's8', 'S6'],
        ),
      ]) {
    testWidgets('dotted selection: ${testCase.name}', (tester) async {
      KottaEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) =>
                      '\\K${elements.map((element) => element.command).join()};',
                  initialState: KottaEditorInitialState(
                    elements: <KottaEditorElement>[
                      for (final String command in testCase.initial)
                        KottaEditorElement(
                          command: command,
                          textOffset: 0,
                          isConditional: true,
                        ),
                    ],
                    textLength: 0,
                    kottaCursor: testCase.cursor,
                    textCursor: 0,
                    isEditing: true,
                  ),
                );
              },
              child: Text(_kottaLabels.editTitle),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_kottaLabels.editTitle));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (int step = 0; step < testCase.steps.abs(); step++) {
        await tester.sendKeyEvent(
          testCase.steps > 0
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft,
        );
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final Finder section = find
          .ancestor(
            of: find.text(
              testCase.rests ? _kottaLabels.rests : _kottaLabels.notes,
            ),
            matching: find.byType(Column),
          )
          .first;
      final Finder toggle = find.descendant(
        of: section,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == _kottaLabels.dotted,
        ),
      );
      expect(tester.widget<IconButton>(toggle).isSelected, testCase.selected);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester.widget<IconButton>(toggle).isSelected,
        testCase.name.startsWith('rest-only') ? false : !testCase.selected,
      );
      if (!testCase.name.startsWith('rest-only')) {
        for (final bool selected in <bool>[
          testCase.selected,
          !testCase.selected,
        ]) {
          await tester.tap(toggle);
          await tester.pump();
          expect(tester.widget<IconButton>(toggle).isSelected, selected);
        }
      }
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(
        result!.elements.map((element) => element.command),
        testCase.expected,
      );
      expect(
        result!.elements.every((element) => element.isConditional),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
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
          expected: <String>['r2', '1g', 's8', '|1', '1g'],
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
          name:
              'inserted pitch inherits stem direction without rewriting notes',
          initial: <String>['r2', '2G', '2A'],
          cursor: 2,
          rhythms: <String>['r8'],
          selectNext: false,
          expected: <String>['r2', '2G', 'r8', '2G', 'r2', '2A'],
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
          expected: <String>['R4', '2e', 'r4', '2e', 'R4', '2f'],
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

  for (final testCase
      in <
        ({
          String name,
          List<String> initial,
          int cursor,
          int selectionSteps,
          bool textActive,
          LogicalKeyboardKey key,
          List<String> expected,
        })
      >[
        (
          name: 'skips hidden controls and changes only the preceding note',
          initial: <String>['1F', '2h', ']?', 'r8', ')a', ']3', '[1', 'rt'],
          cursor: 8,
          selectionSteps: 0,
          textActive: false,
          key: LogicalKeyboardKey.arrowUp,
          expected: <String>['1F', '2c', ']?', 'r8', ')a', ']3', '[1', 'rt'],
        ),
        for (final String barrier in <String>['s4', '|1', 'kG'])
          (
            name: 'does not cross visible $barrier',
            initial: <String>['2c', barrier, 'r8', ')a'],
            cursor: 4,
            selectionSteps: 0,
            textActive: false,
            key: LogicalKeyboardKey.arrowDown,
            expected: <String>['2c', barrier, 'r8', ')a'],
          ),
        (
          name: 'does nothing at the beginning',
          initial: <String>['2c'],
          cursor: 0,
          selectionSteps: 0,
          textActive: false,
          key: LogicalKeyboardKey.arrowUp,
          expected: <String>['2c'],
        ),
        (
          name: 'does nothing without notes',
          initial: <String>['r8', '(a'],
          cursor: 2,
          selectionSteps: 0,
          textActive: false,
          key: LogicalKeyboardKey.arrowDown,
          expected: <String>['r8', '(a'],
        ),
        (
          name: 'changes all selected notes but not surrounding notes or signs',
          initial: <String>['1g', '1F', 's4', '|1', '2h', '3D', '2a'],
          cursor: 1,
          selectionSteps: 5,
          textActive: false,
          key: LogicalKeyboardKey.arrowUp,
          expected: <String>['1g', '2G', 's4', '|1', '2c', '3D', '2a'],
        ),
        (
          name: 'backward selection preserves stems and clamps the lower limit',
          initial: <String>['2g', '1G', '2G', '2c', '3g'],
          cursor: 4,
          selectionSteps: -3,
          textActive: false,
          key: LogicalKeyboardKey.arrowDown,
          expected: <String>['2g', '1G', '1F', '2h', '3g'],
        ),
        (
          name: 'also changes pitch with the text cursor active',
          initial: <String>['2c', '2e'],
          cursor: 1,
          selectionSteps: 0,
          textActive: true,
          key: LogicalKeyboardKey.arrowDown,
          expected: <String>['2h', '2e'],
        ),
      ]) {
    testWidgets('pitch arrows: ${testCase.name}', (tester) async {
      List<KottaEditorElement> preview = <KottaEditorElement>[];
      KottaEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) {
                    preview = List<KottaEditorElement>.of(elements);
                    return '\\K${elements.map((e) => e.command).join()};';
                  },
                  initialState: KottaEditorInitialState(
                    elements: <KottaEditorElement>[
                      for (int i = 0; i < testCase.initial.length; i++)
                        KottaEditorElement(
                          command: testCase.initial[i],
                          textOffset: i,
                          isConditional: i.isEven,
                        ),
                    ],
                    textLength: testCase.initial.length,
                    kottaCursor: testCase.cursor,
                    textCursor: testCase.cursor,
                    isEditing: true,
                  ),
                );
              },
              child: Text(_kottaLabels.editTitle),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_kottaLabels.editTitle));
      await tester.pumpAndSettle();
      if (testCase.textActive) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      if (testCase.selectionSteps != 0) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int i = 0; i < testCase.selectionSteps.abs(); i++) {
          await tester.sendKeyEvent(
            testCase.selectionSteps > 0
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.sendKeyEvent(testCase.key);
      await tester.pump();
      expect(preview.map((e) => e.command), testCase.expected);
      for (int i = 0; i < preview.length; i++) {
        expect(preview[i].textOffset, i);
        expect(preview[i].isConditional, i.isEven);
      }
      if (testCase.selectionSteps != 0) {
        await tester.sendKeyEvent(
          testCase.key == LogicalKeyboardKey.arrowUp
              ? LogicalKeyboardKey.arrowDown
              : LogicalKeyboardKey.arrowUp,
        );
        await tester.pump();
        expect(
          preview.map((e) => e.command),
          testCase.selectionSteps > 0
              ? <String>['1g', '1F', 's4', '|1', '2h', '3C', '2a']
              : <String>['2g', '1A', '2G', '2c', '3g'],
        );
      }
      final List<String> expectedPitches = preview
          .where((e) => RegExp(r'^[123][a-hA-H]$').hasMatch(e.command))
          .map((e) => e.command)
          .toList();
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(
        result!.elements
            .where((e) => RegExp(r'^[123][a-hA-H]$').hasMatch(e.command))
            .map((e) => e.command),
        expectedPitches,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final bool stemDown in <bool>[false, true]) {
    testWidgets(
      'pitch arrows repeat across the full range, stemDown=$stemDown',
      (tester) async {
        const List<String> pitches = <String>[
          '1g',
          '1a',
          '1h',
          '1c',
          '1d',
          '1e',
          '1f',
          '2g',
          '2a',
          '2h',
          '2c',
          '2d',
          '2e',
          '2f',
          '3g',
          '3a',
          '3h',
          '3c',
          '3d',
        ];
        final List<String> expected = pitches
            .map((pitch) => stemDown ? pitch.toUpperCase() : pitch)
            .toList();
        List<String> preview = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showKottaEditorDialog(
                  context: context,
                  labels: _kottaLabels,
                  previewLineBuilder: (elements) {
                    preview = elements.map((e) => e.command).toList();
                    return '\\K${preview.join()};';
                  },
                  initialState: KottaEditorInitialState(
                    elements: <KottaEditorElement>[
                      KottaEditorElement(
                        command: expected.first,
                        textOffset: 0,
                      ),
                      const KottaEditorElement(command: '2c', textOffset: 0),
                    ],
                    textLength: 0,
                    kottaCursor: 1,
                    textCursor: 0,
                    isEditing: true,
                  ),
                ),
                child: Text(_kottaLabels.editTitle),
              ),
            ),
          ),
        );
        await tester.tap(find.text(_kottaLabels.editTitle));
        await tester.pumpAndSettle();
        for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
        ]) {
          await tester.sendKeyDownEvent(key);
          for (int step = 1; step <= pitches.length + 1; step++) {
            if (step > 1) {
              await tester.sendKeyRepeatEvent(key);
            }
            await tester.pump();
            final int index = key == LogicalKeyboardKey.arrowUp
                ? step.clamp(0, pitches.length - 1)
                : (pitches.length - 1 - step).clamp(0, pitches.length - 1);
            expect(preview, <String>[expected[index], '2c']);
          }
          await tester.sendKeyUpEvent(key);
        }
        await tester.tap(find.text(_kottaLabels.apply));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
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
    expect(find.byType(OutlinedButton), findsNWidgets(74));
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
      _kottaLabels.noteProperties,
      _kottaLabels.accidentals,
      _kottaLabels.agogics,
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

  for (final bool shortcuts in <bool>[false, true]) {
    testWidgets('notation clipboard copies, cuts and pastes ($shortcuts)', (
      WidgetTester tester,
    ) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          } else if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboard};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final InlineTextEditingController controller =
          InlineTextEditingController.fromDia(r'\KkG;ab\Kr4mk1a;cd\Ke2|!;ef');
      await _openNotationPreview(tester, controller);

      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == tooltip,
        ),
      );
      expect(button(_kottaLabels.cut).onPressed, isNull);
      expect(button(_kottaLabels.copy).onPressed, isNull);
      expect(
        tester.getTopLeft(find.byTooltip(_kottaLabels.cut)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(_notationPreviewLayout(tester).preview).dy,
        ),
      );
      Future<void> action(String label, LogicalKeyboardKey key) async {
        if (shortcuts) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(key);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        } else {
          await tester.tap(find.byTooltip(label));
        }
        await tester.pump();
      }

      await action(_kottaLabels.copy, LogicalKeyboardKey.keyC);
      await action(_kottaLabels.cut, LogicalKeyboardKey.keyX);
      expect(clipboard, isNull);
      await tester.tapAt(_kottaPosition(tester, 5));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(button(_kottaLabels.cut).onPressed, isNotNull);
      expect(button(_kottaLabels.copy).onPressed, isNotNull);
      final TextSelection? selection = _notationOverlay(tester).kottaSelection;
      await action(_kottaLabels.copy, LogicalKeyboardKey.keyC);
      expect(clipboard, r'\Kr4;\Kmk;\K1a;\Ke2;');
      expect(_notationOverlay(tester).kottaSelection, selection);

      await action(_kottaLabels.cut, LogicalKeyboardKey.keyX);
      expect(_notationOverlay(tester).kottaPosition, 1);
      expect(_notationOverlay(tester).textPosition, 2);
      expect(_notationOverlay(tester).kottaSelection, isNull);
      expect(button(_kottaLabels.cut).onPressed, isNull);
      await action(_kottaLabels.paste, LogicalKeyboardKey.keyV);
      expect(_notationOverlay(tester).kottaPosition, 5);
      expect(_notationOverlay(tester).textPosition, 2);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await action(_kottaLabels.paste, LogicalKeyboardKey.keyV);
      expect(_notationOverlay(tester).kottaSelection, isNull);
      expect(_notationOverlay(tester).kottaPosition, 9);
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(controller.encodedText, r'\KkG;ab\Kr4mk1ae2;cd\Kr4mk1ae2;ef');
      controller.dispose();
    });
  }

  for (final (String opening, String closing) in <(String, String)>[
    ('(a', ')a'),
    ('(f', ')f'),
    ('[3', ']3'),
    ('[5', ']5'),
    ('[?', ']?'),
    ('[0', '[1'),
    ('Rt', 'rt'),
  ]) {
    testWidgets(
      'notation selection keeps attachments between $opening groups',
      (WidgetTester tester) async {
        final controller = InlineTextEditingController.fromDia(
          '\\Kr8${opening}2g${closing}r4mka-2a${opening}2h${closing}2c;word',
        );
        await _openNotationPreview(tester, controller);
        for (final bool forward in <bool>[true, false]) {
          await tester.tapAt(_kottaPosition(tester, forward ? 3 : 8));
          await tester.pump();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(
            forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();
          expect(
            _notationOverlay(tester).kottaSelection,
            TextSelection(
              baseOffset: forward ? 4 : 8,
              extentOffset: forward ? 8 : 4,
            ),
          );
        }
        await tester.tap(find.text(_kottaLabels.cancel));
        await tester.pumpAndSettle();
        controller.dispose();
      },
    );

    testWidgets('notation clipboard isolates inherited $opening groups', (
      WidgetTester tester,
    ) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          } else if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboard};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final controller = InlineTextEditingController.fromDia(
        '\\?Kr8${opening}2g2a2h${closing}r42c2d;word',
      );
      await _openNotationPreview(tester, controller);
      for (final (int cursor, String pitch) in <(int, String)>[
        (0, '2g'),
        (4, '2h'),
      ]) {
        await tester.tapAt(_kottaPosition(tester, cursor));
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        await tester.tap(find.byTooltip(_kottaLabels.copy));
        await tester.pump();
        expect(
          clipboard!.replaceAll(RegExp(r'\\\??K|;'), ''),
          'r8$opening$pitch$closing',
        );
      }
      await tester.tapAt(_kottaPosition(tester, 3));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final TextSelection? selection = _notationOverlay(tester).kottaSelection;
      await tester.tap(find.byTooltip(_kottaLabels.copy));
      await tester.pump();
      String commands() => clipboard!.replaceAll(RegExp(r'\\\??K|;'), '');
      expect(commands(), 'r8${opening}2a$closing');
      expect(clipboard, isNot(contains(r'\K')));
      expect(_notationOverlay(tester).kottaSelection, selection);
      await tester.tap(find.byTooltip(_kottaLabels.cut));
      await tester.pump();
      expect(commands(), 'r8${opening}2a$closing');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.tap(find.byTooltip(_kottaLabels.paste));
      await tester.pump();
      await tester.tap(find.text(_kottaLabels.apply));
      await tester.pumpAndSettle();
      expect(
        controller.encodedText,
        '\\?Kr8${opening}2g2h${closing}r42cr8${opening}2a${closing}r42d;word',
      );
      controller.dispose();
    });
  }

  testWidgets('mouse selection orders closing codes before note attachments', (
    WidgetTester tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = InlineTextEditingController.fromDia(
      r'\Kr8[?2gr4]?[0Rtmka-2a[1rt[?2h]?2c;word',
    );
    await _openNotationPreview(tester, controller);
    final Offset start = _kottaPosition(tester, 3);
    final Offset end = _kottaPosition(tester, 10);
    final TestGesture gesture = await tester.startGesture(
      start,
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pump();
    expect(
      _notationOverlay(tester).kottaSelection,
      const TextSelection(baseOffset: 4, extentOffset: 12),
    );
    await tester.tap(find.byTooltip(_kottaLabels.cut));
    await tester.pump();
    expect(clipboard!.replaceAll(RegExp(r'\\\??K|;'), ''), 'r4[0Rtmka-2a[1rt');
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\Kr8[?2g]?r4[?2h]?2c;word');
    controller.dispose();
  });

  testWidgets('cutting all notation can be saved without removing lyrics', (
    WidgetTester tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\KkG;ab\K1a;cd');
    await _openNotationPreview(tester, controller);
    await tester.tapAt(_kottaPosition(tester, 2));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.tap(find.byTooltip(_kottaLabels.cut));
    await tester.pump();
    expect(_notationOverlay(tester).kottaPosition, 0);
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, 'abcd');
    controller.dispose();
  });

  testWidgets('notation paste ignores unrelated text and keeps selection', (
    WidgetTester tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': r'lyrics\KkF;'}
          : null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'\KkG1a;word');
    await _openNotationPreview(tester, controller);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    final TextSelection? selection = _notationOverlay(tester).kottaSelection;
    await tester.tap(find.byTooltip(_kottaLabels.paste));
    await tester.pump();
    expect(_notationOverlay(tester).kottaSelection, selection);
    await tester.tap(find.text(_kottaLabels.apply));
    await tester.pumpAndSettle();
    expect(controller.encodedText, r'\KkG1a;word');
    controller.dispose();
  });

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
