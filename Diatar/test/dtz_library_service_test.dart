import 'package:diatar_app/src/services/dtz_library_service.dart';
import 'package:diatar_app/src/core/dtz/dtz_media_paths.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory dtzDir;

  setUp(() async {
    root = await LocalFileSystem().systemTempDirectory.createTemp(
      'dtz_library_',
    );
    dtzDir = root.childDirectory('diatar').childDirectory('DTZs');
    await dtzDir.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await root.delete(recursive: true);
  });

  test(
    'stored paths can explicitly reference a nested Music directory',
    () async {
      final File sound = dtzDir.childFile('Music/audio/song.mp3');
      await sound.create(recursive: true);
      await dtzDir
          .childFile('imported.dtz')
          .writeAsString(
            '${DtzMediaPaths.localHeader}\nz1234 Music/audio/song.mp3\n',
          );
      final verse = (await const DtzLibraryService().loadLibrary())['1234']!;
      expect(
        verse.soundFilePath!.replaceAll('\\', '/'),
        sound.path.replaceAll('\\', '/'),
      );
    },
  );

  test(
    'legacy shared DTZs merge installed sounds and photos in either order',
    () async {
      const String content =
          'Bobsolete\\sounds\\\n'
          'Z1234 song.mp3\n'
          'bobsolete\\scores\\\n'
          'F1234 page.png\n'
          'i1234 2500\n';
      final Directory music = dtzDir.childDirectory('Music');
      await music.create(recursive: true);
      await music.childFile('book.dtz').writeAsString(content);
      final File sound = music.childFile('audio/song.mp3');
      await sound.create(recursive: true);
      final File photo = dtzDir.childFile('scores/page.png');
      await photo.create(recursive: true);
      const DtzLibraryService service = DtzLibraryService();

      final before = (await service.loadLibrary())['1234']!;
      expect(
        before.soundFilePath!.replaceAll('\\', '/'),
        sound.path.replaceAll('\\', '/'),
      );

      final File scoreDtz = dtzDir.childFile('book.dtz');
      await scoreDtz.writeAsString(content);
      for (final String name in <String>['book.dtz', '0book.dtz']) {
        if (name != 'book.dtz') await scoreDtz.rename('${dtzDir.path}/$name');
        final verse = (await service.loadLibrary())['1234']!;
        expect(
          verse.soundFilePath!.replaceAll('\\', '/'),
          sound.path.replaceAll('\\', '/'),
        );
        expect(verse.soundForSong, isTrue);
        expect(
          verse.fotoFilePath!.replaceAll('\\', '/'),
          photo.path.replaceAll('\\', '/'),
        );
        expect(verse.forwardMS, 2500);
      }

      await sound.delete();
      expect((await service.loadLibrary())['1234']!.soundFilePath, isNull);
    },
  );
}
