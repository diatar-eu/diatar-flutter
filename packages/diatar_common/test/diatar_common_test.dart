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
    final Uint8List payload = Uint8List.fromList(utf8.encode('header\rtitle\rline\r'));
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
    final Uint8List packet = encodeProjectionPacket(RecTypes.askSize, Uint8List(0));
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
}
