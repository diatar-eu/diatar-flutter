import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/export_import_service.dart';

void main() {
  late MemoryFileSystem fileSystem;
  late ExportImportService service;
  late int persistCount;

  setUp(() {
    fileSystem = MemoryFileSystem(style: FileSystemStyle.posix);
    persistCount = 0;
    service = ExportImportService(
      fileSystem: fileSystem,
      documentsDirectoryPathProvider: () async => '/documents',
      persistFileSystem: () async {
        persistCount++;
      },
    );
  });

  test('exports the complete diatar directory with its root', () async {
    await fileSystem
        .file('/documents/diatar/DTXs/song.dtx')
        .create(recursive: true);
    await fileSystem
        .file('/documents/diatar/DTXs/song.dtx')
        .writeAsString('song');
    await fileSystem.directory('/documents/diatar/empty').create();

    final Uint8List bytes = await service.createExportArchive();
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final Map<String, ArchiveFile> entries = <String, ArchiveFile>{
      for (final ArchiveFile entry in archive.files) entry.name: entry,
    };

    expect(entries, contains('diatar/'));
    expect(entries, contains('diatar/DTXs/'));
    expect(entries, contains('diatar/DTXs/song.dtx'));
    expect(entries, contains('diatar/empty/'));
    expect(
      utf8.decode(entries['diatar/DTXs/song.dtx']!.content),
      equals('song'),
    );
  });

  test('reports conflicts before importing', () async {
    await fileSystem
        .file('/documents/diatar/DTXs/existing.dtx')
        .create(recursive: true);

    final DiatarImportPreview preview = await service.inspectImportArchive(
      _zip(<String, List<int>>{
        'diatar/DTXs/existing.dtx': utf8.encode('new'),
        'diatar/DTXs/new.dtx': utf8.encode('new'),
      }),
    );

    expect(preview.fileCount, 2);
    expect(preview.conflictingFileCount, 1);
  });

  test('skip policy preserves every existing file', () async {
    final file = fileSystem.file('/documents/diatar/DTXs/existing.dtx');
    await file.create(recursive: true);
    await file.writeAsString('old');

    final DiatarImportResult result = await service.importArchive(
      _zip(<String, List<int>>{
        'diatar/DTXs/existing.dtx': utf8.encode('replacement'),
        'diatar/DTXs/new.dtx': utf8.encode('new'),
      }),
      existingFilePolicy: ExistingFilePolicy.skip,
    );

    expect(await file.readAsString(), 'old');
    expect(
      await fileSystem.file('/documents/diatar/DTXs/new.dtx').readAsString(),
      'new',
    );
    expect(result.importedFileCount, 1);
    expect(result.skippedFileCount, 1);
    expect(result.errors, isEmpty);
    expect(persistCount, 1);
  });

  test('overwrite policy replaces every existing file', () async {
    final first = fileSystem.file('/documents/diatar/first.txt');
    final second = fileSystem.file('/documents/diatar/second.txt');
    await first.create(recursive: true);
    await second.create(recursive: true);
    await first.writeAsString('old first');
    await second.writeAsString('old second');

    final DiatarImportResult result = await service.importArchive(
      _zip(<String, List<int>>{
        'diatar/first.txt': utf8.encode('new first'),
        'diatar/second.txt': utf8.encode('new second'),
      }),
      existingFilePolicy: ExistingFilePolicy.overwrite,
    );

    expect(await first.readAsString(), 'new first');
    expect(await second.readAsString(), 'new second');
    expect(result.importedFileCount, 2);
    expect(result.skippedFileCount, 0);
    expect(result.errors, isEmpty);
  });

  test('rejects path traversal without writing outside diatar', () async {
    final Uint8List bytes = _zip(<String, List<int>>{
      'diatar/../outside.txt': utf8.encode('unsafe'),
    });

    await expectLater(
      service.importArchive(
        bytes,
        existingFilePolicy: ExistingFilePolicy.overwrite,
      ),
      throwsA(
        isA<DiatarArchiveException>().having(
          (DiatarArchiveException error) => error.code,
          'code',
          DiatarArchiveErrorCode.invalidArchive,
        ),
      ),
    );
    expect(await fileSystem.file('/documents/outside.txt').exists(), isFalse);
  });

  test('rejects ZIP files that do not contain a diatar root', () async {
    await expectLater(
      service.inspectImportArchive(
        _zip(<String, List<int>>{'other/file.txt': utf8.encode('wrong root')}),
      ),
      throwsA(isA<DiatarArchiveException>()),
    );
  });

  test('records a CRC error and removes the partial file', () async {
    const String content = 'this is the original song content for the crc test';
    final Uint8List bytes = _storeZip(<String, List<int>>{
      'diatar/DTXs/song.dtx': utf8.encode(content),
    });

    final List<int> haystack = bytes;
    final List<int> needle = utf8.encode(content);
    int index = -1;
    for (int i = 0; i + needle.length <= haystack.length; i++) {
      if (haystack[i] == needle[0]) {
        bool matches = true;
        for (int j = 1; j < needle.length; j++) {
          if (haystack[i + j] != needle[j]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          index = i;
          break;
        }
      }
    }
    expect(index, greaterThanOrEqualTo(0));
    final Uint8List corrupted = Uint8List.fromList(bytes);
    corrupted[index + needle.length ~/ 2] ^= 0xff;

    final DiatarImportResult result = await service.importArchive(
      corrupted,
      existingFilePolicy: ExistingFilePolicy.overwrite,
    );

    expect(result.importedFileCount, 0);
    expect(result.errors, isNotEmpty);
    expect(
      await fileSystem.file('/documents/diatar/DTXs/song.dtx').exists(),
      isFalse,
    );
  });
}

Uint8List _zip(Map<String, List<int>> files) {
  final Archive archive = Archive()..addFile(ArchiveFile.directory('diatar/'));
  for (final MapEntry<String, List<int>> entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List _storeZip(Map<String, List<int>> files) {
  final Archive archive = Archive()..addFile(ArchiveFile.directory('diatar/'));
  for (final MapEntry<String, List<int>> entry in files.entries) {
    archive.addFile(
      ArchiveFile.bytes(entry.key, entry.value)
        ..compression = CompressionType.none,
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
