import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/blank_image_storage.dart';

void main() {
  late MemoryFileSystem fileSystem;
  late BlankImageStore store;

  setUp(() {
    fileSystem = MemoryFileSystem(style: FileSystemStyle.posix);
    store = BlankImageStore(
      fileSystem: fileSystem,
      documentsPathProvider: () async => '/documents',
    );
  });

  test('import writes the bytes under <docs>/blank and returns the path',
      () async {
    final String path = await store.import(
      Uint8List.fromList(<int>[1, 2, 3]),
      'png',
    );
    expect(path, '/documents/blank/blank.png');
    expect(await fileSystem.file(path).exists(), isTrue);
    expect(await fileSystem.file(path).readAsBytes(), <int>[1, 2, 3]);
  });

  test('import with a different extension removes the previous file', () async {
    await store.import(Uint8List.fromList(<int>[1]), 'png');
    final String path = await store.import(Uint8List.fromList(<int>[2]), 'jpg');

    expect(path, '/documents/blank/blank.jpg');
    expect(await fileSystem.file('/documents/blank/blank.png').exists(), isFalse);
    expect(await fileSystem.file(path).exists(), isTrue);
  });

  test('import normalizes the extension and keeps a single file', () async {
    final String path = await store.import(
      Uint8List.fromList(<int>[1]),
      'PNG ',
    );
    expect(path, '/documents/blank/blank.png');
    final List<FileSystemEntity> entries =
        fileSystem.directory('/documents/blank').listSync();
    expect(entries.length, 1);
  });

  test('delete removes the stored file', () async {
    await store.import(Uint8List.fromList(<int>[1]), 'png');
    await store.delete();
    expect(
      await fileSystem.file('/documents/blank/blank.png').exists(),
      isFalse,
    );
  });

  test('delete is a no-op when nothing is stored', () async {
    await store.delete();
    expect(await fileSystem.directory('/documents/blank').exists(), isFalse);
  });

  test('resolveImageExtension uses the file name and falls back to the path',
      () {
    expect(
      BlankImageStore.resolveImageExtension(XFile('/data/img.PNG')),
      'png',
    );
    expect(
      BlankImageStore.resolveImageExtension(
        XFile.fromData(Uint8List(0), path: '/data/photo.JPG'),
      ),
      'jpg',
    );
    expect(
      BlankImageStore.resolveImageExtension(XFile('/data/img')),
      '',
    );
  });
}
