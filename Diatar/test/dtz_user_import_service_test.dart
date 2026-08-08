import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/dtz_user_import_service.dart';

List<int> _bytes(String content) =>
    Uint8List.fromList(utf8.encode(content.replaceAll('\r\n', '\n')));

List<int> _zip(Map<String, String> entries) {
  final Archive archive = Archive();
  entries.forEach(
    (String name, String content) =>
        archive.addFile(ArchiveFile.string(name, content)),
  );
  return ZipEncoder().encode(archive);
}

const String _dtzWithMedia = 'b foto\r\n'
    'f 3894733E kotta/01.jpg\r\n'
    'z 3894733E hang/01.mp3\r\n'
    'i B1E858E8 3000\r\n';

void main() {
  const DtzUserImportService service = DtzUserImportService();

  test('ok when every referenced dia-ID is available and media is provided',
      () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes(_dtzWithMedia),
      },
      zipFiles: <String, List<int>>{
        'media.zip': _zip(<String, String>{
          'foto/kotta/01.jpg': 'x',
          'foto/hang/01.mp3': 'y',
        }),
      },
      availableDiaIds: <String>{'3894733E', 'B1E858E8'},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.status, DtzImportStatus.ok);
    expect(pkg.errorReason, isNull);
    expect(pkg.matchedFiles, <String>{'foto/kotta/01.jpg', 'foto/hang/01.mp3'});
    expect(pkg.missingFiles, isEmpty);
  });

  test('error with Missing dia-IDs when an ID is not in the DTX books', () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes(_dtzWithMedia),
      },
      zipFiles: <String, List<int>>{},
      availableDiaIds: <String>{'3894733E'},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.status, DtzImportStatus.error);
    expect(pkg.errorReason, contains('Missing dia-IDs'));
    expect(pkg.errorReason, contains('B1E858E8'));
    expect(pkg.missingDiaIds, <String>{'B1E858E8'});
  });

  test('ok without media refs when all dia-IDs are available', () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes('i 3894733E 3000\r\n'),
      },
      zipFiles: <String, List<int>>{},
      availableDiaIds: <String>{'3894733E'},
    );

    expect(analysis.packages.single.status, DtzImportStatus.ok);
  });

  test('error without media refs when a dia-ID is missing', () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes('i 3894733E 3000\r\n'),
      },
      zipFiles: <String, List<int>>{},
      availableDiaIds: const <String>{},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.status, DtzImportStatus.error);
    expect(pkg.errorReason, contains('Missing dia-IDs'));
    expect(pkg.missingDiaIds, contains('3894733E'));
  });

  test('warning when only a small fraction of dia-IDs is missing', () {
    final List<String> knownIds = List<String>.generate(
      50,
      (int i) => (0x00010000 + i).toRadixString(16).toUpperCase(),
    );
    final String knownLines = knownIds
        .map((String id) => 'i $id 1000\r\n')
        .join();
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        // 1 of 51 missing -> ~2 % < 5 % => warning.
        'sample.dtz': _bytes('i 3894733E 3000\r\n'
            'i DEADBEEF 1000\r\n'
            '$knownLines'),
      },
      zipFiles: <String, List<int>>{},
      availableDiaIds: <String>{'3894733E', ...knownIds},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.status, DtzImportStatus.warning);
    expect(pkg.errorReason, contains('Missing dia-IDs'));
    expect(pkg.missingDiaIds, contains('DEADBEEF'));
  });

  test('elevates to error when media is fine but dia-IDs are missing', () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes(_dtzWithMedia),
      },
      zipFiles: <String, List<int>>{
        'media.zip': _zip(<String, String>{
          'foto/kotta/01.jpg': 'x',
          'foto/hang/01.mp3': 'y',
        }),
      },
      availableDiaIds: <String>{'3894733E'},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.status, DtzImportStatus.error);
    expect(pkg.errorReason, contains('Missing dia-IDs'));
    expect(pkg.missingDiaIds, <String>{'B1E858E8'});
  });

  test('missingFiles contains the full list of absent media files', () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes('b foto\r\n'
            'f 3894733E a/1.jpg\r\n'
            'f 3894733E a/2.jpg\r\n'
            'f 3894733E a/3.jpg\r\n'),
      },
      zipFiles: <String, List<int>>{
        'media.zip': _zip(<String, String>{'foto/a/1.jpg': 'x'}),
      },
      availableDiaIds: <String>{'3894733E'},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.missingFiles, <String>{'foto/a/2.jpg', 'foto/a/3.jpg'});
    expect(pkg.matchedFiles, <String>{'foto/a/1.jpg'});
    expect(pkg.missingDiaIds, isEmpty);
    expect(pkg.status, DtzImportStatus.error); // 2 of 3 missing -> 66 %.
  });
}
