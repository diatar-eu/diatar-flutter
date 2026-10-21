import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/services/app_export_directory.dart';
import 'package:diatar_app/src/services/picked_image_storage.dart';
import 'package:diatar_app/src/utils/friendly_path.dart';

void main() {
  late MemoryFileSystem fileSystem;

  setUp(() {
    fileSystem = MemoryFileSystem(style: FileSystemStyle.posix);
  });

  group('AppExportDirectory', () {
    AppExportDirectory store() => AppExportDirectory(
      fileSystem: fileSystem,
      documentsPathProvider: () async => '/documents',
    );

    test('resolves a folder next to the diatar data folder', () async {
      final String path = await store().resolve();

      expect(path, equals('/documents/export'));
      expect(await fileSystem.directory(path).exists(), isTrue);
      // A biztonsági mentés a diatar mappát csomagolja, ezért az export
      // mappa nem kerülhet bele.
      expect(path.startsWith('/documents/diatar'), isFalse);
    });

    test('appends the extension only when it is missing', () async {
      expect(
        await store().resolveFilePath(
          suggestedName: 'diatar-backup-20261021-1430',
          extensions: const <String>['zip'],
        ),
        equals('/documents/export/diatar-backup-20261021-1430.zip'),
      );
      expect(
        await store().resolveFilePath(
          suggestedName: 'diatar-backup.zip',
          extensions: const <String>['zip'],
        ),
        equals('/documents/export/diatar-backup.zip'),
      );
    });

    test(
      'keeps a longer matching extension instead of the first one',
      () async {
        expect(
          await store().resolveFilePath(
            suggestedName: 'előadás.jpeg',
            extensions: const <String>['jpg', 'jpeg'],
          ),
          equals('/documents/export/előadás.jpeg'),
        );
      },
    );

    test('falls back to a name when the suggestion is empty', () async {
      expect(
        await store().resolveFilePath(
          suggestedName: '   ',
          extensions: const <String>['dia'],
        ),
        equals('/documents/export/diatar-export.dia'),
      );
    });

    test('uses the name as-is without known extensions', () async {
      expect(
        await store().resolveFilePath(suggestedName: 'előadás'),
        equals('/documents/export/előadás'),
      );
    });
  });

  group('PickedImageStore', () {
    PickedImageStore store({DateTime Function()? clock}) => PickedImageStore(
      fileSystem: fileSystem,
      documentsPathProvider: () async => '/documents',
      clock: clock,
    );

    test('copies the picked file into the diatar data folder', () async {
      await fileSystem
          .file('/tmp/Inbox/olvasnivaló.png')
          .create(recursive: true);
      await fileSystem.file('/tmp/Inbox/olvasnivaló.png').writeAsString('kép');

      final String target = await store(
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
      ).import('/tmp/Inbox/olvasnivaló.png');

      expect(
        target,
        equals('/documents/diatar/picked-images/1000_olvasnivaló.png'),
      );
      expect(await fileSystem.file(target).readAsString(), equals('kép'));
    });

    test('does not overwrite an earlier import of the same name', () async {
      await fileSystem.file('/tmp/Inbox/kép.png').create(recursive: true);
      await fileSystem.file('/tmp/Inbox/kép.png').writeAsString('első');
      final String first = await store(
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
      ).import('/tmp/Inbox/kép.png');

      await fileSystem.file('/tmp/Inbox/kép.png').writeAsString('második');
      final String second = await store(
        clock: () => DateTime.fromMillisecondsSinceEpoch(2000),
      ).import('/tmp/Inbox/kép.png');

      expect(first, isNot(equals(second)));
      expect(await fileSystem.file(first).readAsString(), equals('első'));
      expect(await fileSystem.file(second).readAsString(), equals('második'));
    });

    test('uses the file name part of both posix and windows paths', () {
      expect(PickedImageStore.baseName('/a/b/c.png'), equals('c.png'));
      expect(PickedImageStore.baseName(r'C:\a\b\c.png'), equals('c.png'));
      expect(PickedImageStore.baseName('c.png'), equals('c.png'));
      expect(PickedImageStore.baseName(''), equals('image'));
    });
  });

  group('formatAppStoragePathLabel', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('hu'));
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('replaces the ios sandbox prefix with the Files app label', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(
        formatAppStoragePathLabel(
          '/var/mobile/Containers/Data/Application/'
          '6C0E7A1B-0000-0000-0000-000000000000/Documents/export/mentes.zip',
          l10n,
        ),
        equals('${l10n.appDocumentsFolderLabel}/export/mentes.zip'),
      );
    });

    test('keeps the regular friendly label on other platforms', () {
      expect(
        formatAppStoragePathLabel('/storage/emulated/0/Download/x.zip', l10n),
        equals(
          '${l10n.pathLabelInternalStorage}/${l10n.pathSegmentDownloads}/x.zip',
        ),
      );
    });

    test('is empty for an empty path', () {
      expect(formatAppStoragePathLabel('  ', l10n), equals(''));
    });
  });
}
