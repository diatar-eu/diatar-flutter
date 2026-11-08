import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/dtz_user_import_service.dart';
import 'package:diatar_app/src/services/streaming_zip_service.dart';

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

const String _dtzWithMedia =
    'b foto\r\n'
    'f 3894733E kotta/01.jpg\r\n'
    'z 3894733E hang/01.mp3\r\n'
    'i B1E858E8 3000\r\n';

void main() {
  const DtzUserImportService service = DtzUserImportService();

  test(
    'ok when every referenced dia-ID is available and media is provided',
    () {
      final DtzUserImportAnalysis analysis = service.analyze(
        dtzFiles: <String, List<int>>{'sample.dtz': _bytes(_dtzWithMedia)},
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
      expect(pkg.matchedFiles, <String>{
        'foto/kotta/01.jpg',
        'foto/hang/01.mp3',
      });
      expect(pkg.missingFiles, isEmpty);
    },
  );

  test('error with Missing dia-IDs when an ID is not in the DTX books', () {
    final DtzUserImportAnalysis analysis = service.analyze(
      dtzFiles: <String, List<int>>{'sample.dtz': _bytes(_dtzWithMedia)},
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
        'sample.dtz': _bytes(
          'i 3894733E 3000\r\n'
          'i DEADBEEF 1000\r\n'
          '$knownLines',
        ),
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
      dtzFiles: <String, List<int>>{'sample.dtz': _bytes(_dtzWithMedia)},
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
        'sample.dtz': _bytes(
          'b foto\r\n'
          'f 3894733E a/1.jpg\r\n'
          'f 3894733E a/2.jpg\r\n'
          'f 3894733E a/3.jpg\r\n',
        ),
      },
      zipFiles: <String, List<int>>{
        'media.zip': _zip(<String, String>{'foto/a/1.jpg': 'x'}),
      },
      availableDiaIds: <String>{'3894733E'},
    );

    final DtzImportPackageAnalysis pkg = analysis.packages.single;
    expect(pkg.missingFiles, <String>{'a/2.jpg', 'a/3.jpg'});
    expect(pkg.matchedFiles, <String>{'foto/a/1.jpg'});
    expect(pkg.missingDiaIds, isEmpty);
    expect(pkg.status, DtzImportStatus.error); // 2 of 3 missing -> 66 %.
  });

  test('reads and extracts ZIP imports directly from a file', () async {
    final Directory tempDir = await LocalFileSystem().systemTempDirectory
        .createTemp('dtz_stream_import_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final File zipFile = tempDir.childFile('media.zip');
    await zipFile.writeAsBytes(
      _zip(<String, String>{'foto/kotta/01.jpg': 'image'}),
    );

    final DtzUserImportAnalysis analysis = await service.analyzeFiles(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes('b foto\r\nf 3894733E kotta/01.jpg\r\n'),
      },
      zipFilePaths: <String, String>{'media.zip': zipFile.path},
      availableDiaIds: <String>{'3894733E'},
    );
    expect(analysis.packages.single.status, DtzImportStatus.ok);

    final DtzUserImportCommitResult result = await service.commitFiles(
      toImport: analysis.packages,
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes('b foto\r\nf 3894733E kotta/01.jpg\r\n'),
      },
      zipFilePaths: <String, String>{'media.zip': zipFile.path},
      targetDir: tempDir.childDirectory('target'),
    );

    expect(result.failures, isEmpty);
    expect(result.extractedFileCount, 1);
    expect(
      await tempDir.childFile('target/foto/kotta/01.jpg').readAsString(),
      'image',
    );
    final String localDtz = await tempDir
        .childFile('target/sample.dtz')
        .readAsString();
    expect(localDtz, contains('f3894733E foto/kotta/01.jpg'));
    expect(localDtz, isNot(contains('b foto')));
  });

  test('memory import stores actual paths without applying B or b', () async {
    final Directory dir = await LocalFileSystem().systemTempDirectory
        .createTemp('dtz_memory_import_');
    addTearDown(() => dir.delete(recursive: true));
    final Map<String, List<int>> dtzFiles = <String, List<int>>{
      'sample.dtz': _bytes(
        'B C:\\legacy\\audio\\\nZ1234 song.mp3\n'
        'b D:\\legacy\\scores\\\nf1234 page.png\n',
      ),
    };
    final Map<String, List<int>> zipFiles = <String, List<int>>{
      'media.zip': _zip(<String, String>{
        'actual/audio/song.mp3': 'sound',
        'actual/scores/page.png': 'photo',
        'unused.txt': 'unused',
      }),
    };
    final analysis = service.analyze(
      dtzFiles: dtzFiles,
      zipFiles: zipFiles,
      availableDiaIds: <String>{'1234'},
    );
    expect(analysis.packages.single.status, DtzImportStatus.ok);
    final result = await service.commit(
      toImport: analysis.packages,
      dtzFiles: dtzFiles,
      zipFiles: zipFiles,
      targetDir: dir,
    );
    expect(result.failures, isEmpty);
    expect(result.importedDtzCount, 1);
    expect(result.extractedFileCount, 2);
    final local = await dir.childFile('sample.dtz').readAsString();
    expect(local, contains('Z1234 actual/audio/song.mp3'));
    expect(local, contains('f1234 actual/scores/page.png'));
    expect(local, isNot(contains('legacy')));
    expect(dir.childFile('unused.txt').existsSync(), isFalse);
  });

  test('ambiguous references are rejected during analysis', () {
    final analysis = service.analyze(
      dtzFiles: <String, List<int>>{'sample.dtz': _bytes('z1234 song.mp3\n')},
      zipFiles: <String, List<int>>{
        'media.zip': _zip(<String, String>{
          'first/song.mp3': 'first',
          'second/song.mp3': 'second',
        }),
      },
      availableDiaIds: <String>{'1234'},
    );
    expect(analysis.packages.single.status, DtzImportStatus.error);
    expect(analysis.packages.single.errorReason, contains('song.mp3'));
  });

  test('failed extraction does not publish an imported DTZ', () async {
    final Directory dir = await LocalFileSystem().systemTempDirectory
        .createTemp('dtz_failed_import_');
    addTearDown(() => dir.delete(recursive: true));
    final Map<String, List<int>> dtzFiles = <String, List<int>>{
      'sample.dtz': _bytes('z1234 song.mp3\n'),
    };
    final analysis = service.analyze(
      dtzFiles: dtzFiles,
      zipFiles: <String, List<int>>{
        'media.zip': _zip(<String, String>{'audio/song.mp3': 'audio'}),
      },
      availableDiaIds: <String>{'1234'},
    );
    final File broken = dir.childFile('broken.zip');
    await broken.writeAsString('not a zip');
    final result = await service.commitFiles(
      toImport: analysis.packages,
      dtzFiles: dtzFiles,
      zipFilePaths: <String, String>{'media.zip': broken.path},
      targetDir: dir,
    );
    expect(result.importedDtzCount, 0);
    expect(result.failures, isNotEmpty);
    expect(dir.childFile('sample.dtz').existsSync(), isFalse);
  });

  test('reports ZIP validation failures instead of hiding them', () async {
    final Directory tempDir = await LocalFileSystem().systemTempDirectory
        .createTemp('dtz_invalid_zip_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final File zipFile = tempDir.childFile('broken.zip');
    await zipFile.writeAsString('not a zip');

    final DtzUserImportAnalysis analysis = await service.analyzeFiles(
      dtzFiles: <String, List<int>>{
        'sample.dtz': _bytes('i 3894733E 3000\r\n'),
      },
      zipFilePaths: <String, String>{'broken.zip': zipFile.path},
      availableDiaIds: <String>{'3894733E'},
    );

    expect(analysis.zipFailures, hasLength(1));
    expect(
      analysis.zipFailures.single.error.code,
      StreamingZipErrorCode.invalidArchive,
    );
  });

  test('rejects archives exceeding configured extraction limits', () async {
    final Directory tempDir = await LocalFileSystem().systemTempDirectory
        .createTemp('dtz_zip_limit_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final File zipFile = tempDir.childFile('large-entry.zip');
    await zipFile.writeAsBytes(
      _zip(<String, String>{'foto/kotta/01.jpg': 'too large'}),
    );

    await expectLater(
      const StreamingZipService().fileNames(
        zipFile.path,
        limits: const StreamingZipLimits(maxEntrySize: 1),
      ),
      throwsA(
        isA<StreamingZipException>().having(
          (StreamingZipException error) => error.code,
          'code',
          StreamingZipErrorCode.entryTooLarge,
        ),
      ),
    );
  });

  test('ZIP progress identifies each entry before and after writing', () async {
    final Directory tempDir = await LocalFileSystem().systemTempDirectory
        .createTemp('dtz_zip_progress_');
    addTearDown(() => tempDir.delete(recursive: true));
    final File zipFile = tempDir.childFile('scores.zip');
    await zipFile.writeAsBytes(
      _zip(<String, String>{'scores/one.png': 'one', 'scores/two.png': 'two'}),
    );
    final List<StreamingZipProgress> progress = <StreamingZipProgress>[];
    await const StreamingZipService().extract(
      zipFile.path,
      targetDirectory: tempDir,
      onProgress: (StreamingZipProgress value) {
        if (!value.entryComplete && value.writtenBytes == 0) {
          expect(tempDir.childFile(value.entryName).existsSync(), isFalse);
        }
        progress.add(value);
      },
    );
    final List<StreamingZipProgress> completed = progress
        .where((StreamingZipProgress value) => value.entryComplete)
        .toList();
    expect(completed.map((StreamingZipProgress p) => p.entryName), <String>[
      'scores/one.png',
      'scores/two.png',
    ]);
    expect(completed.map((StreamingZipProgress p) => p.completedEntries), <int>[
      1,
      2,
    ]);
    expect(completed.last.totalEntries, 2);
    expect(completed.last.writtenBytes, completed.last.totalBytes);
  });
}
