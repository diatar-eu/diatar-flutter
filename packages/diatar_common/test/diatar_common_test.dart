import 'dart:convert';
import 'dart:typed_data';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default app settings are valid', () {
    const AppSettings s = AppSettings();
    expect(s.port, 1024);
    expect(s.tcpEnabled, true);
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
    expect(startXs.first, 16);
    expect(startXs.skip(1), everyElement(32));
  });

  test('logo background stays green between fade in and fade out', () {
    final ProjectorPainter painter = ProjectorPainter(
      frame: const LogoFrame(0),
      globals: const ProjectionGlobals(),
      settings: const AppSettings(),
    );

    expect(
      painter.debugLogoBackgroundColorForPhase(31),
      const Color(0xFF46E887),
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
}
