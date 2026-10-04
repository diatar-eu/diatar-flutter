import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diatar_common/diatar_common.dart';
import 'package:diatar_common/utils/transposition_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Diatar chords split into a bold root and a superscripted quality', () {
    final DiatarChord chord = DiatarChord.tryParse('H-7+/C+')!;

    expect(chord.parts().map((ChordPart part) => part.text), <String>[
      'B',
      '△',
      '/',
      'C',
      '#',
    ]);
    expect(chord.parts().map((ChordPart part) => part.style), <ChordPartStyle>[
      ChordPartStyle.root,
      ChordPartStyle.superscript,
      ChordPartStyle.normal,
      ChordPartStyle.normal,
      ChordPartStyle.normal,
    ]);
  });

  test('Diatar chords spell flat and sharp notes consistently', () {
    expect(
      DiatarChord.tryParse('C-')!.parts().map((ChordPart part) => part.text),
      <String>['C', '♭'],
    );
    expect(
      DiatarChord.tryParse('A-')!.parts().map((ChordPart part) => part.text),
      <String>['A', '♭'],
    );
    expect(
      DiatarChord.tryParse('F+')!.parts().map((ChordPart part) => part.text),
      <String>['F', '#'],
    );
    expect(DiatarChord.tryParse('Cm#'), isNull);
  });

  test('root letter, accidental and minor marker are all bold', () {
    expect(
      DiatarChord.tryParse('D-')!.parts().map((ChordPart part) => part.style),
      <ChordPartStyle>[ChordPartStyle.root, ChordPartStyle.root],
    );
    expect(
      DiatarChord.tryParse('Cm')!.parts().map((ChordPart part) => part.style),
      <ChordPartStyle>[ChordPartStyle.root, ChordPartStyle.root],
    );
    expect(
      DiatarChord.tryParse('D-m7')!.parts().map((ChordPart part) => part.style),
      <ChordPartStyle>[
        ChordPartStyle.root,
        ChordPartStyle.root,
        ChordPartStyle.root,
        ChordPartStyle.superscript,
      ],
    );
  });

  test('the minor marker can be spelled as a dash', () {
    expect(
      DiatarChord.tryParse(
        'Cm7',
      )!.parts(minorAsDash: true).map((ChordPart part) => part.text),
      <String>['C', '-', '7'],
    );
    expect(
      DiatarChord.tryParse('Cm7')!.parts().map((ChordPart part) => part.text),
      <String>['C', 'm', '7'],
    );
  });

  test('symbolic notation renders every documented modifier', () {
    const Map<String, String> modifiers = <String, String>{
      '': 'C',
      '#': 'C+',
      'o': 'C°',
      '7': 'C7',
      '7+': 'C△',
      'o7': 'Cø',
      'o7-': 'C°7',
      'o7+': 'C°△',
      '#7': 'C+7',
      '#7+': 'C+△',
      '6': 'C6',
      '79': 'C9',
      '79-': 'C7♭9',
      '79+': 'C7#9',
      '#79': 'C+9',
      '#79+': 'C+7#9',
      '7+9': 'C△9',
      '7+9+': 'C△#9',
      '#7+9': 'C+△9',
      '#7+9+': 'C+△#9',
      'o79': 'Cø9',
      'o79-': 'Cø♭9',
      '9': 'Cadd9',
      '9-': 'Cadd♭9',
      '9+': 'Cadd#9',
      '#9': 'C+add9',
      '#9+': 'C+add#9',
      'o9': 'C°add9',
      'o9-': 'C°add♭9',
      '4': 'Csus4',
      '2': 'Csus2',
      '47': 'C7sus4',
      '27': 'C7sus2',
      '49': 'C9sus4',
      '49-': 'C♭9sus4',
      '49+': 'C#9sus4',
    };

    for (final MapEntry<String, String> modifier in modifiers.entries) {
      final DiatarChord? chord = DiatarChord.tryParse('C${modifier.key}');
      expect(chord, isNotNull, reason: 'C${modifier.key}');
      expect(
        chord!.parts().map((ChordPart part) => part.text).join(),
        modifier.value,
        reason: 'C${modifier.key}',
      );
    }
  });

  test('textual notation renders words and falls back to symbolic', () {
    const Map<String, String> own = <String, String>{
      '#': 'Caug',
      'o': 'Cdim',
      '7+': 'Cmaj',
      'o7': 'Cm7♭5',
      'o7-': 'Cdim7',
      'o7+': 'Cdim(maj)',
      '#7': 'Caug7',
      '#7+': 'Caug(maj)',
      '#79': 'Caug9',
      '#79+': 'Caug7#9',
      '7+9': 'Cmaj9',
      '7+9+': 'Cmaj#9',
      '#7+9': 'Caug(maj9)',
      '#7+9+': 'Caug(maj#9)',
      'o79': 'Cm9♭5',
      'o79-': 'Cm♭9♭5',
      '#9': 'Caug(add9)',
      '#9+': 'Caug(add#9)',
      'o9': 'Cdim(add9)',
      'o9-': 'Cdim(add♭9)',
    };
    // The sheet has no textual spelling for these, so the symbolic one stands.
    const Map<String, String> fallback = <String, String>{
      '7': 'C7',
      '6': 'C6',
      '79': 'C9',
      '79-': 'C7♭9',
      '79+': 'C7#9',
      '9': 'Cadd9',
      '9-': 'Cadd♭9',
      '9+': 'Cadd#9',
      '4': 'Csus4',
      '2': 'Csus2',
      '47': 'C7sus4',
      '27': 'C7sus2',
      '49': 'C9sus4',
      '49-': 'C♭9sus4',
      '49+': 'C#9sus4',
    };

    for (final MapEntry<String, String> modifier in own.entries) {
      expect(
        DiatarChord.tryParse('C${modifier.key}')!
            .parts(notation: ChordNotation.textual)
            .map((ChordPart part) => part.text)
            .join(),
        modifier.value,
        reason: 'C${modifier.key}',
      );
    }

    for (final MapEntry<String, String> modifier in fallback.entries) {
      expect(
        DiatarChord.tryParse('C${modifier.key}')!
            .parts(notation: ChordNotation.textual)
            .map((ChordPart part) => part.text)
            .join(),
        modifier.value,
        reason: 'C${modifier.key}',
      );
    }
  });

  test('numeric notation falls back to textual and then to symbolic', () {
    const Map<String, String> own = <String, String>{
      '#': 'C#5',
      'o': 'Cm♭5',
      'o7-': 'C♭7♭5',
      'o7+': 'Cmmaj7♭5',
      '#7': 'C7#5',
      '#7+': 'Cmaj7#5',
      '#79': 'C9#5',
      '#79+': 'C7#9#5',
      '#7+9': 'Cmaj9#5',
      '#7+9+': 'Cmaj#9#5',
    };
    // No numeric spelling: textual is used instead.
    const Map<String, String> textual = <String, String>{
      '7+': 'Cmaj',
      'o7': 'Cm7♭5',
      '7+9': 'Cmaj9',
      '7+9+': 'Cmaj#9',
      'o79': 'Cm9♭5',
      'o79-': 'Cm♭9♭5',
      '#9': 'Caug(add9)',
      '#9+': 'Caug(add#9)',
      'o9': 'Cdim(add9)',
      'o9-': 'Cdim(add♭9)',
    };
    // Neither numeric nor textual: symbolic is used.
    const Map<String, String> symbolic = <String, String>{
      '7': 'C7',
      '6': 'C6',
      '79': 'C9',
      '79-': 'C7♭9',
      '79+': 'C7#9',
      '9': 'Cadd9',
      '9-': 'Cadd♭9',
      '9+': 'Cadd#9',
      '4': 'Csus4',
      '2': 'Csus2',
      '47': 'C7sus4',
      '27': 'C7sus2',
      '49': 'C9sus4',
      '49-': 'C♭9sus4',
      '49+': 'C#9sus4',
    };

    for (final MapEntry<String, String> modifier in own.entries) {
      expect(
        DiatarChord.tryParse('C${modifier.key}')!
            .parts(notation: ChordNotation.numeric)
            .map((ChordPart part) => part.text)
            .join(),
        modifier.value,
        reason: 'C${modifier.key}',
      );
    }

    for (final MapEntry<String, String> modifier in textual.entries) {
      expect(
        DiatarChord.tryParse('C${modifier.key}')!
            .parts(notation: ChordNotation.numeric)
            .map((ChordPart part) => part.text)
            .join(),
        modifier.value,
        reason: 'C${modifier.key}',
      );
    }

    for (final MapEntry<String, String> modifier in symbolic.entries) {
      expect(
        DiatarChord.tryParse('C${modifier.key}')!
            .parts(notation: ChordNotation.numeric)
            .map((ChordPart part) => part.text)
            .join(),
        modifier.value,
        reason: 'C${modifier.key}',
      );
    }
  });

  test('the optional seventh reveals only the implicit sevens', () {
    String render(
      String source, {
      ChordNotation notation = ChordNotation.symbolic,
      bool optionalSeventh = true,
    }) {
      return DiatarChord.tryParse(source)!
          .parts(notation: notation, optionalSeventh: optionalSeventh)
          .map((ChordPart part) => part.text)
          .join();
    }

    expect(render('C7+'), 'C△7');
    expect(render('Cm7+'), 'Cm△7');
    expect(render('Co7+'), 'C°△7');
    expect(render('C#7+'), 'C+△7');

    expect(render('C7+', notation: ChordNotation.textual), 'Cmaj7');
    expect(render('Co7+', notation: ChordNotation.textual), 'Cdim(maj7)');
    expect(render('C#7+', notation: ChordNotation.textual), 'Caug(maj7)');

    // Numeric already spells the seventh out.
    expect(render('C7+', notation: ChordNotation.numeric), 'Cmaj7');
    expect(render('Co7+', notation: ChordNotation.numeric), 'Cmmaj7♭5');

    // The ninth chords leave the seventh out unless asked.
    expect(render('C79'), 'C79');
    expect(render('Cm79'), 'Cm79');
    expect(render('C#79'), 'C+79');
    expect(render('C7+9'), 'C△79');
    expect(render('Cm7+9'), 'Cm△79');
    expect(render('C7+9+'), 'C△7#9');
    expect(render('C#7+9'), 'C+△79');
    expect(render('C#7+9+'), 'C+△7#9');

    expect(
      render('C#79', notation: ChordNotation.textual),
      'Caug79',
    );
    expect(render('C7+9', notation: ChordNotation.textual), 'Cmaj79');
    expect(
      render('C7+9+', notation: ChordNotation.textual),
      'Cmaj7#9',
    );
    expect(
      render('C#7+9', notation: ChordNotation.textual),
      'Caug7(maj9)',
    );
    expect(
      render('C#7+9+', notation: ChordNotation.textual),
      'Caug7(maj#9)',
    );
    expect(render('C#79', notation: ChordNotation.numeric), 'C79#5');
    expect(render('C#7+9', notation: ChordNotation.numeric), 'Cmaj79#5');
    expect(
      render('C#7+9+', notation: ChordNotation.numeric),
      'Cmaj7#9#5',
    );

    // A bare ♭9 or #9 would be the added-ninth chord, so these keep the seventh.
    expect(render('C79-'), 'C7♭9');
    expect(render('Cm79-'), 'Cm7♭9');
    expect(render('C79+'), 'C7#9');
    expect(render('C#79+'), 'C+7#9');
    expect(render('C#79+', notation: ChordNotation.textual), 'Caug7#9');
    expect(render('C#79+', notation: ChordNotation.numeric), 'C7#9#5');
    expect(render('C79-', optionalSeventh: false), 'C7♭9');
    expect(render('C79+', optionalSeventh: false), 'C7#9');

    // Qualities that already show a seventh are untouched.
    expect(render('C7'), 'C7');
    expect(render('Co7'), 'Cø');
    expect(render('Co7-'), 'C°7');
    expect(render('C7+', optionalSeventh: false), 'C△');
    expect(render('C79', optionalSeventh: false), 'C9');
    expect(render('C#79', optionalSeventh: false), 'C+9');
    expect(render('C7+9', optionalSeventh: false), 'C△9');
    expect(render('C#7+9+', optionalSeventh: false), 'C+△#9');
  });

  test('diminished and half-diminished use the sheet glyphs', () {
    // The degree sign is already a small raised circle on the baseline, while
    // the slashed circle needs real superscript positioning.
    expect(
      DiatarChord.tryParse('Co')!.parts().map((ChordPart part) => part.style),
      <ChordPartStyle>[ChordPartStyle.root, ChordPartStyle.normal],
    );
    expect(
      DiatarChord.tryParse('Co7')!.parts().map((ChordPart part) => part.style),
      <ChordPartStyle>[ChordPartStyle.root, ChordPartStyle.superscript],
    );
  });

  test('Diatar chords accept only the documented minor combinations', () {
    const Set<String> accepted = <String>{
      '',
      '7',
      '7+',
      '6',
      '79',
      '79-',
      '7+9',
      '9',
      '9-',
    };
    const List<String> modifiers = <String>[
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

    for (final String modifier in modifiers) {
      expect(
        DiatarChord.tryParse('Cm$modifier'),
        accepted.contains(modifier) ? isNotNull : isNull,
        reason: 'Cm$modifier',
      );
    }
  });

  test('Diatar chord transposition handles compact accidentals and bass', () {
    expect(TranspositionUtils.transposeChord('C+', 1), 'D');
    expect(TranspositionUtils.transposeChord('H7', 1), 'C7');
    expect(TranspositionUtils.transposeChord('H-7', 2), 'C7');
    expect(TranspositionUtils.transposeChord('Cm7/G', 2), 'Dm7/A');
    expect(TranspositionUtils.transposeChord('C7/H', -1), 'H7/A+');
    expect(TranspositionUtils.transposeChord('C27/G', 2), 'D27/A');
  });

  test('Diatar chord transposition preserves modifiers and flat spelling', () {
    expect(TranspositionUtils.transposeChord('C#', 2), 'D#');
    expect(TranspositionUtils.transposeChord('E-7+/H-', 2), 'F7+/C');
    expect(TranspositionUtils.transposeChord('Dbmaj7', 2), 'Ebmaj7');
    expect(TranspositionUtils.transposeChord('not a chord', 3), 'not a chord');
  });

  test('line transposition updates Diatar chord roots and bass notes', () {
    expect(
      TranspositionUtils.transposeLine(r'\GC+7/H-;Szoveg', 1),
      r'\GD7/H;Szoveg',
    );
  });

  test('chord modifiers are vertically raised as superscripts', () {
    final ChordLayout layout = ChordRenderer.layout(
      'C7+',
      const TextStyle(fontSize: 32),
    );

    expect(layout.debugPartTopOffsets, hasLength(2));
    expect(
      layout.debugPartTopOffsets[1],
      lessThan(layout.debugPartTopOffsets[0]),
    );
  });

  test('chord widths participate in text row wrapping', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useAkkord: true),
      settings: const AppSettings(receiverUseAkkord: true),
    );
    const double maxWidth = 75;
    const String source = r'\GC7+;a \GC7+;b \GC7+;c';

    final List<double> widths = painter.debugTextWrappedRowWidthsForLine(
      source,
      fontSize: 24,
      maxWidth: maxWidth,
    );

    expect(widths.length, greaterThan(1));
    expect(widths, everyElement(lessThanOrEqualTo(maxWidth + 0.5)));
  });

  test('standalone chords receive visible layout slots', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useAkkord: true),
      settings: const AppSettings(receiverUseAkkord: true),
    );

    expect(painter.debugChordSourcesForLine(r'\GC;\GD7; \GAm;\GH7;'), <String>[
      'C',
      'D7',
      'Am',
      'H7',
    ]);
    expect(
      painter
          .debugTextWrappedRowWidthsForLine(
            r'\GC;\GD7; \GAm;\GH7;',
            fontSize: 24,
            maxWidth: 90,
          )
          .length,
      greaterThan(1),
    );
  });

  test('adjacent chords after text remain separate chord objects', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useAkkord: true),
      settings: const AppSettings(receiverUseAkkord: true),
    );

    expect(
      painter.debugChordSourcesForLine(
        r'a\GC;\GCm;\GC#;\GCo;\GC7;\GC7+; \GCm7+;',
      ),
      <String>['C', 'Cm', 'C#', 'Co', 'C7', 'C7+', 'Cm7+'],
    );
  });

  test('default app settings are valid', () {
    const AppSettings s = AppSettings();
    expect(s.maxCustomOrderSets, AppSettings.defaultMaxCustomOrderSets);
    expect(s.port, 1024);
    expect(s.tcpEnabled, false);
    expect(
      s.copyWith(tcpTargets: const <String>['127.0.0.1']).tcpEnabled,
      true,
    );
  });

  test('external command settings survive copy and map conversions', () {
    const AppSettings settings = AppSettings(
      externalCommandOnStart: 'start-command',
      externalCommandOnExit: 'exit-command',
      externalCommandOnProjectionOn: 'projection-on-command',
      externalCommandOnProjectionOff: 'projection-off-command',
    );

    final AppSettings copied = settings.copyWith();
    final AppSettings restored = AppSettings.fromMap(settings.toMap());

    expect(copied.externalCommandOnStart, 'start-command');
    expect(copied.externalCommandOnExit, 'exit-command');
    expect(restored.externalCommandOnProjectionOn, 'projection-on-command');
    expect(restored.externalCommandOnProjectionOff, 'projection-off-command');
  });

  test('music advance setting survives copy and map conversions', () {
    const AppSettings settings = AppSettings(advanceAfterMusic: true);

    expect(settings.copyWith().advanceAfterMusic, isTrue);
    expect(AppSettings.fromMap(settings.toMap()).advanceAfterMusic, isTrue);
  });

  // The projector window resolves hotkeys from the `settings` message while
  // the control window is hidden, so the three hotkey tables have to be part
  // of the wire format. Without them the projector always sees empty maps
  // and no hotkey ever resolves from there.
  test('desktop hotkey tables survive map conversions', () {
    const AppSettings settings = AppSettings(
      desktopActionHotkeys: <String, String>{'nextVerse': 'F1'},
      desktopSongHotkeys: <String, String>{'F2': 'konyv1.dtx::3'},
      desktopOrderSetHotkeys: <String, String>{'F3': 'order-set-7'},
    );

    final AppSettings restored = AppSettings.fromMap(settings.toMap());

    expect(restored.desktopActionHotkeys, settings.desktopActionHotkeys);
    expect(restored.desktopSongHotkeys, settings.desktopSongHotkeys);
    expect(restored.desktopOrderSetHotkeys, settings.desktopOrderSetHotkeys);
  });

  test('desktop hotkey tables read from a codec shaped map', () {
    final AppSettings restored = AppSettings.fromMap(<String, dynamic>{
      'desktopActionHotkeys': <Object?, Object?>{
        'nextVerse': 'F1',
        'bogus': 42,
      },
    });

    expect(restored.desktopActionHotkeys, <String, String>{'nextVerse': 'F1'});
    // A sender that predates the key must not break the projector.
    expect(
      AppSettings.fromMap(<String, dynamic>{}).desktopSongHotkeys,
      isEmpty,
    );
  });

  test('state record preserves background image visibility', () {
    const ProjectionGlobals globals = ProjectionGlobals(
      isBlankPic: true,
      showBlankPic: true,
    );

    final Uint8List bytes = encodeStateRecord(
      globals,
      projecting: false,
      wordToHighlight: 0,
    );
    final RecStateRecord state = RecStateRecord.fromBytes(bytes);

    expect(bytes[311], 1);
    expect(state.projecting, isFalse);
    expect(state.isBlankPic, isTrue);
    expect(state.showBlankPic, isTrue);
  });

  test('state record preserves inverse notation colors', () {
    const ProjectionGlobals globals = ProjectionGlobals(inverzKotta: true);

    final Uint8List bytes = encodeStateRecord(
      globals,
      projecting: false,
      wordToHighlight: 0,
    );
    final RecStateRecord state = RecStateRecord.fromBytes(bytes);

    expect(bytes[323], 1);
    expect(state.inverzKotta, isTrue);
  });

  test('chord display options survive copy and map conversions', () {
    const AppSettings settings = AppSettings(
      projAkkordNotation: 2,
      projAkkordOptionalSeventh: true,
      projAkkordMinorAsDash: true,
    );

    expect(settings.copyWith().projAkkordNotation, 2);
    expect(settings.copyWith().projAkkordOptionalSeventh, isTrue);
    expect(settings.copyWith().projAkkordMinorAsDash, isTrue);

    final AppSettings restored = AppSettings.fromMap(settings.toMap());
    expect(restored.projAkkordNotation, 2);
    expect(restored.projAkkordOptionalSeventh, isTrue);
    expect(restored.projAkkordMinorAsDash, isTrue);
  });

  test('an out of range chord notation in storage is clamped', () {
    expect(
      AppSettings.fromMap(
        const AppSettings(projAkkordNotation: 7).toMap(),
      ).projAkkordNotation,
      2,
    );
    expect(
      AppSettings.fromMap(
        const AppSettings(projAkkordNotation: -3).toMap(),
      ).projAkkordNotation,
      0,
    );
  });

  test('state record carries the chord display options to the receiver', () {
    const ProjectionGlobals globals = ProjectionGlobals(
      useAkkord: true,
      akkordNotation: 2,
      akkordOptionalSeventh: true,
      akkordMinorAsDash: true,
    );

    final Uint8List bytes = encodeStateRecord(
      globals,
      projecting: false,
      wordToHighlight: 0,
    );
    final RecStateRecord state = RecStateRecord.fromBytes(bytes);

    expect(state.akkordNotation, 2);
    expect(state.akkordOptionalSeventh, isTrue);
    expect(state.akkordMinorAsDash, isTrue);

    // And they reach the render globals the painter actually reads.
    final ProjectionGlobals restored = const ProjectionGlobals().fromState(
      state,
    );
    expect(restored.akkordNotation, 2);
    expect(restored.akkordOptionalSeventh, isTrue);
    expect(restored.akkordMinorAsDash, isTrue);
  });

  test('a legacy state record decodes with the chord options defaulted', () {
    // What a sender from before the chord options produced.
    final Uint8List bytes = encodeStateRecord(
      const ProjectionGlobals(useAkkord: true),
      projecting: false,
      wordToHighlight: 0,
    ).sublist(0, 349);

    final RecStateRecord state = RecStateRecord.fromBytes(bytes);

    expect(state.akkordNotation, 0);
    expect(state.akkordOptionalSeventh, isFalse);
    expect(state.akkordMinorAsDash, isFalse);
  });

  test('the notation storage codes round-trip and clamp', () {
    for (final ChordNotation notation in ChordNotation.values) {
      expect(
        chordNotationFromStorage(chordNotationToStorage(notation)),
        notation,
      );
    }
    expect(chordNotationFromStorage(-1), ChordNotation.symbolic);
    expect(chordNotationFromStorage(9), ChordNotation.symbolic);
  });

  test(
    'the projection renders chords in the notation from the state record',
    () {
      // Textual spells the diminished 'C°' as 'Cdim', and the test font gives
      // every character the same advance, so the row has to grow.
      const String source = r'\GCo;a';
      const AppSettings settings = AppSettings(receiverUseAkkord: true);

      double widthFor(int notation) {
        return ProjectorPainter(
          frame: null,
          globals: ProjectionGlobals(useAkkord: true, akkordNotation: notation),
          settings: settings,
        ).debugTextWrappedRowWidthsForLine(source, maxWidth: 100000).single;
      }

      expect(widthFor(1), greaterThan(widthFor(0)));
      // Numeric spells it 'Cm♭5', which is longer than 'C°' as well.
      expect(widthFor(2), greaterThan(widthFor(0)));
    },
  );

  test('the optional seventh switch widens the projection chords', () {
    // 'C△' gains a trailing '7', so the row has to grow.
    const String source = r'\GC7+;a';

    double widthFor(bool optionalSeventh) {
      return ProjectorPainter(
        frame: null,
        globals: ProjectionGlobals(
          useAkkord: true,
          akkordOptionalSeventh: optionalSeventh,
        ),
        settings: const AppSettings(receiverUseAkkord: true),
      ).debugTextWrappedRowWidthsForLine(source, maxWidth: 100000).single;
    }

    expect(widthFor(true), greaterThan(widthFor(false)));
  });

  test('packet parser rebuilds records from split chunks', () {
    final ProjectionPacketParser parser = ProjectionPacketParser();
    final Uint8List payload = Uint8List.fromList(
      utf8.encode('header\rtitle\rline\r'),
    );
    final Uint8List packet = encodeProjectionPacket(RecTypes.text, payload);

    final List<ProjectionPacket> first = parser.addChunk(packet.sublist(0, 5));
    expect(first, isEmpty);

    final List<ProjectionPacket> second = parser.addChunk(packet.sublist(5));
    expect(second.length, 1);
    expect(second.first.type, RecTypes.text);

    final RecTextRecord rec = RecTextRecord.fromBytes(second.first.body);
    expect(rec.title, 'title');
    expect(rec.lines, <String>['line']);
  });

  test('packet parser skips noise before magic', () {
    final ProjectionPacketParser parser = ProjectionPacketParser();
    final Uint8List packet = encodeProjectionPacket(
      RecTypes.askSize,
      Uint8List(0),
    );
    final Uint8List noisy = Uint8List.fromList(<int>[99, 98, 97, ...packet]);

    final List<ProjectionPacket> out = parser.addChunk(noisy);
    expect(out.length, 1);
    expect(out.first.type, RecTypes.askSize);
    expect(out.first.body, isEmpty);
  });

  test('dtx parser reads S/N/R/C metadata', () {
    const DtxParser parser = DtxParser();
    final DtxBook book = parser.parse(
      fileName: 'test.dtx',
      content: 'S12\nNBook Title\nRBook Nick\nCMain Group\n>Song\n/1\n line',
    );

    expect(book.order, 12);
    expect(book.title, 'Book Title');
    expect(book.nick, 'Book Nick');
    expect(book.group, 'Main Group');
    expect(book.displayName, 'Book Nick');
    expect(book.songs, isNotEmpty);
  });

  test('dtx parser keeps file defaults when metadata absent', () {
    const DtxParser parser = DtxParser();
    final DtxBook book = parser.parse(
      fileName: 'plain.dtx',
      content: '>Song\n/1\n line',
    );

    expect(book.title, 'plain.dtx');
    expect(book.nick, 'plain.dtx');
    expect(book.group, isEmpty);
    expect(book.order, 0);
  });

  test('dtx parser keeps chord and kotta directives at column 0', () {
    const DtxParser parser = DtxParser();
    final DtxBook book = parser.parse(
      fileName: 'akkord.dtx',
      content: '>Song\n/1\n\\GAm;Aldd Uram\n\\KkGu4;Aldd Uram',
    );

    final List<String> lines = book.songs.first.verses.first.lines;
    expect(lines, hasLength(2));
    expect(lines.first, r'\GAm;Aldd Uram');
    expect(lines.last, r'\KkGu4;Aldd Uram');
  });

  test('text layout reserves descent below its final line', () {
    const double fontSize = 32;
    const List<String> lines = <String>[
      'Adj nekem, adj nekem,',
      '',
      'Irantad buzgó bensoséget,',
      'Téged felismero világosságot!',
    ];
    final ProjectorPainter painter = ProjectorPainter(
      frame: const TextFrame(
        record: RecTextRecord(scholaLine: '', title: '', lines: lines),
      ),
      globals: const ProjectionGlobals(
        autoResize: false,
        fontSize: 32,
        hideTitle: true,
        useAkkord: false,
        useKotta: false,
      ),
      settings: const AppSettings(
        receiverUseAkkord: false,
        receiverUseKotta: false,
      ),
    );
    final TextPainter finalLinePainter = TextPainter(
      text: const TextSpan(
        text: 'Téged felismero világosságot!',
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double textHeight = lines
        .where((String line) => line.isNotEmpty)
        .map((String line) {
          final TextPainter linePainter = TextPainter(
            text: TextSpan(
              text: line,
              style: const TextStyle(fontSize: fontSize),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          return linePainter.height;
        })
        .fold(0, (double total, double height) => total + height);
    final double descent = finalLinePainter.computeLineMetrics().single.descent;

    expect(
      painter.measureRequiredHeight(const Size(1000, 600)),
      greaterThanOrEqualTo(textHeight + descent + 8),
    );
  });

  test('kotta rows repeat clef and key signature on every continuation row', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<String> prefixes = painter.debugKottaRowPrefixesForLine(
      r'\KkGE2r41a;Alfa \Kr41a;Beta \Kr41a;Gamma \Kr41a;Delta \Kr41a;Epszilon',
      fontSize: 24,
      maxWidth: 90,
    );

    expect(prefixes.length, greaterThanOrEqualTo(3));
    expect(prefixes.first, isEmpty);
    expect(prefixes.skip(1), everyElement('kGE2'));
  });

  test(r'preferred break after a kotta block still separates the words', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    // `\.` straight after a \K block leaves the text buffer empty, so the
    // break used to be dropped and the two words were glued together.
    const String source = r'P\KkGE2[?r81d;ange\K1d;\.l\K1d;ing\K1c]?1;ua';

    expect(
      painter.debugTextWrappedRowsForLine(
        source,
        fontSize: 24,
        maxWidth: 100000,
      ),
      <String>['Pange lingua'],
    );

    // The kotta payload must stay bound to the word it belongs to, so the
    // notation layout matches the plain-space spelling of the same text.
    expect(
      painter.debugKottaTextStartXsForLine(source, fontSize: 24, maxWidth: 120),
      painter.debugKottaTextStartXsForLine(
        r'P\KkGE2[?r81d;ange\K1d; l\K1d;ing\K1c]?1;ua',
        fontSize: 24,
        maxWidth: 120,
      ),
    );
  });

  test(r'preferred break after a chord block still separates the words', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useAkkord: true),
      settings: const AppSettings(receiverUseAkkord: true),
    );

    expect(
      painter.debugTextWrappedRowsForLine(
        'egy\\GC;\\.kettő',
        fontSize: 24,
        maxWidth: 100000,
      ),
      <String>['egy kettő'],
    );
  });

  test('kotta honors the initial staff line count command', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    expect(painter.debugKottaStaffLineCountForLine(r'\K-3r41a;Alfa'), 3);
    expect(painter.debugKottaStaffLineCountForLine(r'\Kr41a;Alfa'), 5);
  });

  test('real eneklo egyhaz sample repeats clef and key signature', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<String> prefixes = painter.debugKottaRowPrefixesForLine(
      r' \K-5kGE2[?r81f;Ki\K1d;ált\K1f]?;sunk, K\K[?2a;risz\K2a]?;tus \K[?2h;hí\K2g]?;ve\Kr42a|!;i:',
      fontSize: 24,
      maxWidth: 120,
    );

    expect(prefixes.length, greaterThanOrEqualTo(2));
    expect(prefixes.first, isEmpty);
    expect(prefixes.skip(1), everyElement('kGE2'));
  });

  test('real multi-line eneklo egyhaz sample carries clef and key across lines', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<List<String>>
    linePrefixes = painter.debugKottaRowPrefixesForLines(
      <String>[
        r' \K-5kGE2[?r81f;Ki\K1d;ált\K1f]?;sunk, K\K[?2a;risz\K2a]?;tus \K[?2h;hí\K2g]?;ve\Kr42a|!;i:',
        r' \K-5[?r82a;vi\K2h]?;lág S\K[?2g;zü\K2a;lő\K2g]?;je \K[?1f;add \K1e]?;keg\Kr41f;yed,\K|!;',
        r' m\K-5[?r82a]?;ely \K[?2g;ér\K1e;ez\K1f]?;zük, h\K[?2g]?;ogy \K[?1f;kö\K1e]?;ze\Kr41d;leg\K|!;,',
        r' s \K-5[?r81e;fog\K1f]?;add l\K[?2g;egs\K2a]?;zebb \K[?2g;dic\K1f;sé\K1e]?;ret\Kr41f;ünk!\K||;',
      ],
      fontSize: 24,
      maxWidth: 120,
    );

    expect(linePrefixes, hasLength(4));
    expect(linePrefixes.first.first, isEmpty);
    expect(linePrefixes[1].first, 'kGE2');
    expect(linePrefixes[2].first, 'kGE2');
    expect(linePrefixes[3].first, 'kGE2');
  });

  test('wrapped continuation rows keep carried clef and key signature', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<List<String>>
    linePrefixes = painter.debugKottaRowPrefixesForLines(
      <String>[
        r'\KkGE2r41a;Bevezeto',
        r'\K-5r41a;Alfa \Kr41a;Beta \Kr41a;Gamma \Kr41a;Delta \Kr41a;Epszilon',
      ],
      fontSize: 24,
      maxWidth: 90,
    );

    expect(linePrefixes, hasLength(2));
    expect(linePrefixes[1].length, greaterThanOrEqualTo(2));
    expect(linePrefixes[1], everyElement('kGE2'));
  });

  test('centered kotta continuation rows share the same left edge', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<double> startXs = painter.debugKottaRowStartXsForLine(
      r'\KkGE2r41a;Alfa \Kr41a;Beta \Kr41a;Gamma \Kr41a;Delta \Kr41a;Epszilon',
      fontSize: 24,
      maxWidth: 90,
      sizeWidth: 320,
      horizontalPad: 16,
    );

    expect(startXs.length, greaterThanOrEqualTo(2));
    expect(startXs.skip(2), everyElement(startXs[1]));
    expect(startXs[1] - startXs.first, 16);
  });

  test('continuation row prefixes start at the same visible x position', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<double> visibleStartXs = painter.debugKottaVisibleStartXsForLine(
      r'\KkGE2r41a;Alfa \Kr41a;Be \Kr41a;Sokkalhosszabb \Kr41a;Ko \Kr41a;Megegy',
      fontSize: 24,
      maxWidth: 95,
      sizeWidth: 320,
      horizontalPad: 16,
    );

    expect(visibleStartXs.length, greaterThanOrEqualTo(2));
    expect(visibleStartXs.skip(1), everyElement(visibleStartXs[1]));
  });

  test('first kotta row text starts after leading clef and key signature', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: false),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<double> rowStartXs = painter.debugKottaRowStartXsForLine(
      r'\KkGE2r41a;Alfa \Kr41a;Beta \Kr41a;Gamma',
      fontSize: 24,
      maxWidth: 320,
      sizeWidth: 360,
      horizontalPad: 16,
    );
    final List<double> textStartXs = painter.debugKottaTextStartXsForLine(
      r'\KkGE2r41a;Alfa \Kr41a;Beta \Kr41a;Gamma',
      fontSize: 24,
      maxWidth: 320,
      sizeWidth: 360,
      horizontalPad: 16,
    );

    expect(rowStartXs, isNotEmpty);
    expect(textStartXs, isNotEmpty);
    expect(textStartXs.first, greaterThan(rowStartXs.first));
  });

  test('kotta starts at the same position as its following lyric', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: false),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<double> kottaStartXs = painter.debugKottaVisibleStartXsForLine(
      r'\Kr41a;Alfa',
      fontSize: 24,
      maxWidth: 320,
      sizeWidth: 360,
      horizontalPad: 16,
    );
    final List<double> textStartXs = painter.debugKottaTextStartXsForLine(
      r'\Kr41a;Alfa',
      fontSize: 24,
      maxWidth: 320,
      sizeWidth: 360,
      horizontalPad: 16,
    );

    expect(kottaStartXs, hasLength(1));
    expect(textStartXs, hasLength(1));
    expect(kottaStartXs.single, textStartXs.single);
  });

  test('kotta-separated parts of a word receive a baseline connector', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true),
      settings: const AppSettings(receiverUseKotta: true),
    );

    expect(
      painter.debugKottaLetterConnectorCountForLine(
        r'\Kr41a1b1c1d1e;Ki\Kr41a;ált',
      ),
      1,
    );
    expect(
      painter.debugKottaLetterConnectorCountForLine(
        r'\Kr41a1b1c1d1e;Ki \Kr41a;ált',
      ),
      0,
    );
  });

  test('real sample first kotta row text starts after prefixed clef and key', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: false),
      settings: const AppSettings(receiverUseKotta: true),
    );

    const String source =
        r' \K-5kGE2[?r81f;Ki\K1d;ált\K1f]?;sunk, K\K[?2a;risz\K2a]?;tus \K[?2h;hí\K2g]?;ve\Kr42a|!;i:';

    final List<double> rowStartXs = painter.debugKottaRowStartXsForLine(
      source,
      fontSize: 24,
      maxWidth: 320,
      sizeWidth: 360,
      horizontalPad: 16,
    );
    final List<double> textStartXs = painter.debugKottaTextStartXsForLine(
      source,
      fontSize: 24,
      maxWidth: 320,
      sizeWidth: 360,
      horizontalPad: 16,
    );

    expect(rowStartXs, isNotEmpty);
    expect(textStartXs, isNotEmpty);
    expect(textStartXs.first, greaterThan(rowStartXs.first));
  });

  test('continuation rows are indented by the configured left margin', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: false),
      settings: const AppSettings(receiverUseKotta: true),
    );

    final List<double> startXs = painter.debugKottaRowStartXsForLine(
      r'\KkGE2r41a;Alfa \Kr41a;Beta \Kr41a;Gamma \Kr41a;Delta \Kr41a;Epszilon',
      fontSize: 24,
      maxWidth: 90,
      sizeWidth: 320,
      horizontalPad: 16,
    );

    expect(startXs.length, greaterThanOrEqualTo(2));
    expect(startXs.first, 0);
    expect(startXs.skip(1), everyElement(16));
  });

  test('tie underline continuations survive wrapped rows', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    final List<List<bool>> continuations = painter
        .debugTieUnderlineRowContinuationsForLine(
          r'pre \(aa bb cc dd ee ff gg hh ii jj kk ll\) post',
          fontSize: 24,
          maxWidth: 90,
        );

    expect(continuations.length, greaterThan(2));
    expect(continuations.first.first, false);
    expect(continuations.last.last, false);
    expect(continuations.any((List<bool> pair) => pair[0] && pair[1]), true);
  });

  test('tie underline ends before the trailing word space', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    final List<double> ends = painter.debugTieUnderlineEndAndDisplayXsForLine(
      r'\(word\) next',
    );

    expect(ends, hasLength(2));
    expect(ends[0], lessThan(ends[1]));
  });

  test('tie underline tips stay at or below the text baseline', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    expect(painter.debugTieUnderlineTipOffset(12), 0);
    expect(painter.debugTieUnderlineTipOffset(24), greaterThanOrEqualTo(1));
  });

  test('slur apex moves away from intermediate notes', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    final Offset apexWithoutMiddle = painter.debugSlurApexForPoints(
      <Offset>[const Offset(0, 10), const Offset(20, 10)],
      down: false,
      lineGap: 4,
    );
    final Offset apexWithMiddle = painter.debugSlurApexForPoints(
      <Offset>[const Offset(0, 10), const Offset(10, 4), const Offset(20, 10)],
      down: false,
      lineGap: 4,
    );

    expect(apexWithMiddle.dy, lessThan(apexWithoutMiddle.dy));
    expect(apexWithMiddle.dy, lessThan(4));
    expect(apexWithMiddle.dx, 10);
  });

  test('slur is translated by one staff space without reshaping', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    expect(painter.debugSlurYOffsetForDirection(down: false, lineGap: 4), -4);
    expect(painter.debugSlurYOffsetForDirection(down: true, lineGap: 4), 4);
  });

  test('kotta control sequences do not create intra-word wrap points', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      r' \\K-5kGE2[?r81f;Ki\\K1d;ált\\K1f]?;sunk, K\\K[?2a;risz\\K2a]?;tus \\K[?2h;hí\\K2g]?;ve\\Kr42a|!;i: m\\K-5[?r82a]?;ely \\K[?2g;ér\\K1e;ez\\K1f]?;zük, h\\K[?2g]?;ogy \\K[?1f;kö\\K1e]?;ze\\Kr41d;leg\\K|!;,',
      fontSize: 24,
      maxWidth: 130,
    );

    bool hasBadSplit(String leftSuffix, String rightPrefix) {
      for (int i = 0; i + 1 < rows.length; i++) {
        if (rows[i].endsWith(leftSuffix) &&
            rows[i + 1].startsWith(rightPrefix)) {
          return true;
        }
      }
      return false;
    }

    expect(hasBadSplit('Krisz', 'tus'), false);
    expect(hasBadSplit('h', 'ogy'), false);
  });

  test('single overlong word is shrunk instead of being split', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      'torvenyeinek',
      fontSize: 24,
      maxWidth: 95,
    );

    expect(rows.length, 1);
    expect(rows.first, 'torvenyeinek');
  });

  test('soft hyphen stays hidden when no wrap occurs', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      r'fo\-lyamatos szoveg',
      fontSize: 24,
      maxWidth: 400,
    );

    expect(rows, isNotEmpty);
    expect(rows.any((row) => row.contains('-')), false);
    expect(rows.join(' '), contains('folyamatos'));
  });

  test('soft hyphen is shown only when wrap occurs at that point', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      r'fo\-lyamatos',
      fontSize: 24,
      maxWidth: 45,
    );

    expect(rows.length, greaterThanOrEqualTo(2));
    expect(rows.first.endsWith('-'), true);
    expect(rows.join(''), 'fo-lyamatos');
  });

  test('escaped space is non-breaking inside word', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      r'ab\ cd ef',
      fontSize: 24,
      maxWidth: 60,
    );

    bool splitEscapedSpace = false;
    for (int i = 0; i + 1 < rows.length; i++) {
      if (rows[i].endsWith('ab') && rows[i + 1].startsWith('cd')) {
        splitEscapedSpace = true;
        break;
      }
    }
    expect(splitEscapedSpace, false);
  });

  test('preferred break marker does not force hard break when line fits', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      r'alfa\.beta',
      fontSize: 24,
      maxWidth: 400,
    );

    expect(rows, hasLength(1));
    expect(rows.first, contains('alfa'));
    expect(rows.first, contains('beta'));
  });

  test('preferred break marker is chosen when wrapping is needed', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      r'aa\.bb cc',
      fontSize: 24,
      maxWidth: 70,
    );

    expect(rows.length, greaterThanOrEqualTo(2));
    expect(rows.first, 'aa');
    expect(rows[1], startsWith('bb'));
  });

  test(
    'rows never overflow: each word moves to its own line when it cannot fit',
    () {
      final ProjectorPainter painter = ProjectorPainter(
        frame: null,
        globals: const ProjectionGlobals(useKotta: false, hCenter: false),
        settings: const AppSettings(receiverUseKotta: false),
      );

      final List<String> rows = painter.debugTextWrappedRowsForLine(
        r'minekünk\.véghetetlen kegyességében',
        fontSize: 24,
        maxWidth: 120,
      );

      expect(rows.length, greaterThanOrEqualTo(2));
      expect(rows.first, 'minekünk');
      expect(rows[1], 'véghetetlen');
      expect(rows.last, 'kegyességében');
    },
  );

  test('normal hyphen creates wrap opportunity like space', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: false),
      settings: const AppSettings(receiverUseKotta: false),
    );

    final List<String> rows = painter.debugTextWrappedRowsForLine(
      'ab-cd ef',
      fontSize: 24,
      maxWidth: 55,
    );

    expect(rows.length, greaterThanOrEqualTo(2));
    expect(rows.first.endsWith('-'), true);
    expect(rows[1].startsWith('cd'), true);
  });

  test(
    'fallback wrap breaks before the final word when no preferred break exists',
    () {
      final ProjectorPainter painter = ProjectorPainter(
        frame: null,
        globals: const ProjectionGlobals(useKotta: false, hCenter: false),
        settings: const AppSettings(receiverUseKotta: false),
      );

      final List<String> rows = painter.debugTextWrappedRowsForLine(
        'véghetetlen kegyességében',
        fontSize: 24,
        maxWidth: 110,
      );

      expect(rows.length, greaterThanOrEqualTo(2));
      expect(rows.first, contains('véghetetlen'));
      expect(rows[1], startsWith('kegyességében'));
    },
  );

  test('logo background stays green between fade in and fade out', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: const LogoFrame(0),
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    expect(
      painter.debugLogoBackgroundColorForPhase(31),
      const Color(0xFF46E08C),
    );
    expect(
      painter.debugLogoBackgroundColorForPhase(32),
      const Color(0xFF4BEF96),
    );
    expect(
      painter.debugLogoBackgroundColorForPhase(40),
      const Color(0xFF4BEF96),
    );
    expect(
      painter.debugLogoBackgroundColorForPhase(48),
      const Color(0xFF4BEF96),
    );
    expect(
      painter.debugLogoBackgroundColorForPhase(63),
      const Color(0xFF040E09),
    );
  });

  test('plain multiline text rows never extend past the container width', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: false, hCenter: true),
      settings: const AppSettings(receiverUseKotta: false),
    );
    const List<String> texts = <String>[
      'paradicsomkertben',
      'Megszentségteleníthetetlenségeskedéseitekert',
      'torvenyeinek egy masik szo ide',
      'SZVU 1/2 paradicsomkertben',
    ];
    for (final String text in texts) {
      for (final double width in <double>[60, 100, 180, 220, 300]) {
        final List<String> rows = painter.debugFullPipelineRowsForRecord(
          size: ui.Size(width, 800),
          record: RecTextRecord(
            scholaLine: '',
            title: '',
            lines: <String>[text],
          ),
        );
        for (final String row in rows) {
          final RegExpMatch? m = RegExp(r'T<([0-9.]+)/').firstMatch(row);
          if (m == null) {
            continue;
          }
          final double rowWidth = double.parse(m.group(1)!);
          expect(
            rowWidth,
            lessThanOrEqualTo(width + 1),
            reason: 'text row overflow: $row',
          );
        }
      }
    }
  });

  test('overlong kotta words are shrunk so no kotta row exceeds the width', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: null,
      globals: const ProjectionGlobals(useKotta: true, hCenter: false),
      settings: const AppSettings(receiverUseKotta: true),
    );
    for (final double width in <double>[300, 400, 500]) {
      final List<String> rows = painter.debugFullPipelineRowsForRecord(
        size: ui.Size(width, 640),
        record: RecTextRecord(
          scholaLine: '',
          title: '',
          lines: <String>[r'\Kr34a;paradicsomkertben hosszúvégződéssel szó'],
        ),
      );
      expect(rows, isNotEmpty, reason: 'expected at least one kotta row');
      for (final String row in rows) {
        final RegExpMatch? m = RegExp(r'K<([0-9.]+)>').firstMatch(row);
        if (m == null) {
          continue;
        }
        final double rowWidth = double.parse(m.group(1)!);
        expect(
          rowWidth,
          lessThanOrEqualTo(width + 1),
          reason: 'kotta row overflow: $row (container $width)',
        );
      }
      expect(rows.first.contains('paradicsomkertben'), isTrue);
    }
  });
}
