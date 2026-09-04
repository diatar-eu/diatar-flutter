import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/export_import_service.dart';
import 'package:diatar_app/src/utils/file_system_provider.dart';

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

  test('exports the complete diatar directory to a temp file', () async {
    final Directory tempRoot =
        await FileSystemProvider.instance.systemTempDirectory.createTemp(
      'diatar_export_test_',
    );
    addTearDown(() async {
      try {
        await tempRoot.delete(recursive: true);
      } catch (_) {
        // Ignore cleanup failures.
      }
    });

    final ExportImportService diskService = ExportImportService(
      documentsDirectoryPathProvider: () async => tempRoot.path,
    );

    await FileSystemProvider.instance
        .file('${tempRoot.path}/diatar/DTXs/song.dtx')
        .create(recursive: true);
    await FileSystemProvider.instance
        .file('${tempRoot.path}/diatar/DTXs/song.dtx')
        .writeAsString('song');
    await FileSystemProvider.instance
        .directory('${tempRoot.path}/diatar/empty')
        .create();

    final List<double> progress = <double>[];
    final String zipPath = await diskService.createExportArchiveFile(
      onProgress: progress.add,
    );
    addTearDown(() async {
      try {
        await FileSystemProvider.instance.file(zipPath).parent.delete(
          recursive: true,
        );
      } catch (_) {
        // Ignore cleanup failures.
      }
    });

    final Uint8List bytes = await FileSystemProvider.instance
        .file(zipPath)
        .readAsBytes();
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
    expect(progress, isNotEmpty);
    expect(progress.last, 1);
  });

  test('overwrite policy replaces every existing file', () async {
    final first = fileSystem.file('/documents/diatar/first.txt');
    final second = fileSystem.file('/documents/diatar/second.txt');
    await first.create(recursive: true);
    await second.create(recursive: true);
    await first.writeAsString('old first');
    await second.writeAsString('old second');

    final List<double> progress = <double>[];
    final DiatarImportResult result = await service.importArchive(
      _zip(<String, List<int>>{
        'diatar/first.txt': utf8.encode('new first'),
        'diatar/second.txt': utf8.encode('new second'),
      }),
      onProgress: progress.add,
    );

    expect(await first.readAsString(), 'new first');
    expect(await second.readAsString(), 'new second');
    expect(result.importedFileCount, 2);
    expect(result.errors, isEmpty);
    expect(persistCount, 1);
    expect(progress, isNotEmpty);
    expect(progress.first, greaterThan(0));
    expect(progress.last, 1);
  });

  test('rejects path traversal without writing outside diatar', () async {
    final Uint8List bytes = _zip(<String, List<int>>{
      'diatar/../outside.txt': utf8.encode('unsafe'),
    });

    await expectLater(
      service.importArchive(
        bytes,
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
      service.importArchive(
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
