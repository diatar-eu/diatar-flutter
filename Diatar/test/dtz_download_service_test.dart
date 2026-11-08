import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diatar_app/src/services/dtz_download_service.dart';
import 'package:diatar_app/src/services/dtz_library_service.dart';
import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/l10n/dtz_download_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('DtzDownloadService', () {
    test('localizes extraction details and switches to writing', () async {
      final AppLocalizations hu = await AppLocalizations.delegate.load(
        const Locale('hu'),
      );
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      const DtzDownloadProgress extracting = DtzDownloadProgress(
        phase: DtzDownloadPhase.extracting,
        currentFile: 1,
        totalFiles: 1,
        fileName: 'SZVU201-306.zip',
        currentEntry: 24,
        totalEntries: 105,
        entryName: 'valami.png',
      );
      expect(
        localizeDtzDownloadProgress(hu, extracting),
        'Kicsomagolás 24/105',
      );
      expect(localizeDtzDownloadProgress(en, extracting), 'Extracting 24/105');
      expect(
        localizeDtzDownloadProgress(
          hu,
          const DtzDownloadProgress(
            phase: DtzDownloadPhase.writing,
            currentFile: 1,
            totalFiles: 1,
            fileName: 'song.dtz',
          ),
        ),
        'Beírás 1/1 song.dtz',
      );
    });

    for (final bool music in <bool>[false, true]) {
      test(
        'ZIP metadata survives deletion and detects updates: $music',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final Directory dir = await LocalFileSystem().systemTempDirectory
              .createTemp('dtz_zip_metadata_');
          addTearDown(() => dir.delete(recursive: true));
          final List<Uri> requests = <Uri>[];
          String dtzStamp = '20240101010101';
          String zipStamp = '20240101010102';
          int zipSize = 111;
          final String zipName = music ? 'song.zip' : 'cover.zip';
          final String prefix = music ? 'music_stamp_' : 'dtz_stamp_';
          final http.Client source = music
              ? _MusicHttpClient()
              : _DownloadingFakeDtzHttpClient();
          final MockClient client = MockClient((http.Request request) async {
            requests.add(request.url);
            final http.Response response = await source.get(request.url);
            if (request.url.path.endsWith('_list.php')) {
              return http.Response(
                response.body
                    .replaceAll('20240101010101', dtzStamp)
                    .replaceAll('20240101010102', zipStamp)
                    .replaceAll(',111,', ',$zipSize,'),
                200,
              );
            }
            return response;
          });
          addTearDown(client.close);
          final DtzDownloadService service = music
              ? DtzDownloadService.music(client: client)
              : DtzDownloadService(client: client);
          final List<DtzDownloadProgress> progress = <DtzDownloadProgress>[];
          await service.downloadUpdates(
            targetDir: dir,
            onProgress: progress.add,
          );
          expect(dir.childFile(zipName).existsSync(), isFalse);
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('${prefix}size_$zipName'), zipSize);
          expect(prefs.getString('$prefix$zipName'), zipStamp);
          expect(
            progress.map((DtzDownloadProgress p) => p.phase).toList(),
            containsAllInOrder(<DtzDownloadPhase>[
              DtzDownloadPhase.downloading,
              DtzDownloadPhase.extracting,
              DtzDownloadPhase.writing,
              DtzDownloadPhase.cleanup,
              DtzDownloadPhase.checking,
              DtzDownloadPhase.writing,
              DtzDownloadPhase.saving,
            ]),
          );
          final DtzDownloadProgress extracting = progress.firstWhere(
            (DtzDownloadProgress p) =>
                p.phase == DtzDownloadPhase.extracting &&
                p.entryName.isNotEmpty,
          );
          expect(extracting.fileName, zipName);
          expect(extracting.currentEntry, 1);
          expect(extracting.totalEntries, 1);
          expect(
            extracting.entryName,
            music ? 'music/song.mp3' : 'scores/song.png',
          );

          requests.clear();
          final DtzDownloadSummary repeated = await service.downloadUpdates(
            targetDir: dir,
          );
          expect(repeated.skipped, 1);
          expect(
            requests.where((Uri uri) => uri.path.endsWith('.zip')),
            isEmpty,
          );
          expect(
            (await service.listAll(targetDir: dir)).single.updateAvailable,
            isFalse,
          );

          dtzStamp = '20250101010101';
          requests.clear();
          await service.downloadUpdates(targetDir: dir);
          expect(
            requests.where((Uri uri) => uri.path.endsWith('.dtz')),
            hasLength(1),
          );
          expect(
            requests.where((Uri uri) => uri.path.endsWith('.zip')),
            isEmpty,
          );

          for (final bool changeSize in <bool>[true, false]) {
            if (changeSize) {
              zipSize++;
            } else {
              zipStamp = '20250101010102';
            }
            requests.clear();
            expect(
              (await service.listAll(targetDir: dir)).single.updateAvailable,
              isTrue,
            );
            await service.downloadUpdates(targetDir: dir);
            expect(
              requests.where((Uri uri) => uri.path.endsWith('.zip')),
              hasLength(1),
            );
            expect(prefs.getInt('${prefix}size_$zipName'), zipSize);
            expect(prefs.getString('$prefix$zipName'), zipStamp);
          }

          await prefs.remove('${prefix}size_$zipName');
          requests.clear();
          expect(
            (await service.listAll(targetDir: dir)).single.updateAvailable,
            isTrue,
          );
          await service.downloadUpdates(targetDir: dir);
          expect(
            requests.where((Uri uri) => uri.path.endsWith('.zip')),
            hasLength(1),
          );

          final List<DtzDownloadItem> items = await service.listAll(
            targetDir: dir,
          );
          await service.deletePackages(
            targetDir: dir,
            itemsToDelete: items,
            allItems: items,
          );
          expect(prefs.getInt('${prefix}size_$zipName'), isNull);
          expect(prefs.getString('$prefix$zipName'), isNull);
        },
      );
    }

    test('failed extraction does not mark ZIP as installed', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final Directory dir = await LocalFileSystem().systemTempDirectory
          .createTemp('dtz_failed_extract_');
      addTearDown(() => dir.delete(recursive: true));
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('.zip')) {
          return http.Response('not a zip', 200);
        }
        return _DownloadingFakeDtzHttpClient().get(request.url);
      });
      addTearDown(client.close);
      final DtzDownloadService service = DtzDownloadService(client: client);
      await expectLater(
        service.downloadUpdates(targetDir: dir),
        throwsA(isA<Exception>()),
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dtz_stamp_cover.zip'), isNull);
      expect(prefs.getInt('dtz_stamp_size_cover.zip'), isNull);
      expect(
        (await service.listAll(targetDir: dir)).single.updateAvailable,
        isTrue,
      );
    });

    for (final bool musicFirst in <bool>[true, false]) {
      test(
        'shared DTZ download and removal, music first: $musicFirst',
        () async {
          final Directory root = await LocalFileSystem().systemTempDirectory
              .createTemp('dtz_combined_download_');
          addTearDown(() => root.delete(recursive: true));
          const MethodChannel channel = MethodChannel(
            'plugins.flutter.io/path_provider',
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (_) async => root.path);
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          final DtzDownloadService scores = DtzDownloadService(
            client: _DownloadingFakeDtzHttpClient(),
          );
          final DtzDownloadService music = DtzDownloadService.music(
            client: _MusicHttpClient(),
          );
          for (final DtzDownloadService service
              in musicFirst
                  ? <DtzDownloadService>[music, scores]
                  : <DtzDownloadService>[scores, music]) {
            final Directory directory = await service.resolveDirectory();
            await service.downloadUpdates(targetDir: directory);
          }
          const DtzLibraryService library = DtzLibraryService();
          final combined = (await library.loadLibrary())['00000001']!;
          expect(combined.soundFilePath, isNotNull);
          expect(combined.fotoFilePath, isNotNull);
          expect(
            await LocalFileSystem().file(combined.soundFilePath!).exists(),
            isTrue,
          );
          expect(
            await LocalFileSystem().file(combined.fotoFilePath!).exists(),
            isTrue,
          );
          final Directory scoreDir = await scores.resolveDirectory();
          final items = await scores.listAll(targetDir: scoreDir);
          await scores.deletePackages(
            targetDir: scoreDir,
            itemsToDelete: items,
            allItems: items,
          );
          final musicOnly = (await library.loadLibrary())['00000001']!;
          expect(musicOnly.soundFilePath, combined.soundFilePath);
          expect(musicOnly.fotoFilePath, isNull);
        },
      );
    }

    test(
      'uses the dedicated DTZ list and still resolves zip dependencies',
      () async {
        final Directory dir = await LocalFileSystem().systemTempDirectory
            .createTemp('dtz_service_test_');

        final List<DtzDownloadItem> items =
            await DtzDownloadService(client: _FakeDtzHttpClient()).listAll(
              targetDir: dir,
              dtxTitles: const <String, String>{'song': 'Song title'},
            );

        expect(items, hasLength(1));
        expect(items.first.fileName, 'song.dtz');
        expect(items.first.timestamp, '20240101010101');
        expect(items.first.size, 42);
        expect(items.first.zips, <String>['cover.zip']);
        expect(items.first.title, 'Song title');
      },
    );

    test('deletes a package and its extracted score files', () async {
      final Directory dir = await LocalFileSystem().systemTempDirectory
          .createTemp('dtz_package_delete_test_');
      final DtzDownloadService service = DtzDownloadService(
        client: _DownloadingFakeDtzHttpClient(),
      );
      final List<DtzDownloadItem> items = await service.listAll(targetDir: dir);

      await service.downloadUpdates(targetDir: dir, selected: items);
      expect(dir.childFile('song.dtz').existsSync(), isTrue);
      expect(dir.childFile('scores/song.png').existsSync(), isTrue);
      final String local = await dir.childFile('song.dtz').readAsString();
      expect(local, contains('f00000001 scores/song.png'));
      expect(local, isNot(contains('.mp3')));
      expect(local, isNot(contains('legacy')));

      await service.deletePackages(
        targetDir: dir,
        itemsToDelete: items,
        allItems: items,
      );

      expect(dir.childFile('song.dtz').existsSync(), isFalse);
      expect(dir.childFile('scores/song.png').existsSync(), isFalse);
    });

    test('uses full GitHub URLs for music ZIP downloads', () async {
      final Directory dir = await LocalFileSystem().systemTempDirectory
          .createTemp('music_service_test_');
      final DtzDownloadService service = DtzDownloadService.music(
        client: _MusicHttpClient(),
      );

      final List<DtzDownloadItem> items = await service.listAll(
        targetDir: dir,
        dtxTitles: const <String, String>{'song': 'Song title'},
      );
      expect(items, hasLength(1));
      expect(items.first.zips, <String>['song.zip']);

      await service.downloadUpdates(targetDir: dir, selected: items);
      expect(dir.childFile('song.dtz').existsSync(), isTrue);
      expect(dir.childFile('music/song.mp3').existsSync(), isTrue);
      expect(dir.childFile('song.zip').existsSync(), isFalse);
      final String local = await dir.childFile('song.dtz').readAsString();
      expect(local, contains('Z00000001 music/song.mp3'));
      expect(local, isNot(contains('.png')));
      expect(local, isNot(contains('legacy')));
    });
  });
}

class _FakeDtzHttpClient implements http.Client {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Response response = await get(request.url);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: request,
    );
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final String body;
    switch (url.toString()) {
      case 'https://diatar.eu/downloads/dtz/_list.php':
        body = 'song.dtz,42,20240101010101\n';
        break;
      case 'https://diatar.eu/downloads/kottak/_list.php':
        body = 'cover.zip,111,20240101010102\n';
        break;
      case 'https://diatar.eu/downloads/kottak/kottak.txt':
        body = 'song.dtz=cover.zip\n';
        break;
      default:
        throw UnsupportedError('Unexpected URL: $url');
    }

    return http.Response.bytes(utf8.encode(body), 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DownloadingFakeDtzHttpClient extends _FakeDtzHttpClient {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    if (url.toString() == 'https://diatar.eu/downloads/dtz/song.dtz') {
      return http.Response.bytes(
        utf8.encode(
          'Blegacy\\audio\\\nZ00000001 song.mp3\n'
          'blegacy\\scores\\\nf00000001 song.png\n',
        ),
        200,
      );
    }

    if (url.toString() == 'https://diatar.eu/downloads/kottak/cover.zip') {
      final Archive archive = Archive()
        ..addFile(ArchiveFile('scores/song.png', 4, <int>[1, 2, 3, 4]));
      return http.Response.bytes(ZipEncoder().encodeBytes(archive), 200);
    }
    return super.get(url, headers: headers);
  }
}

class _MusicHttpClient implements http.Client {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Response response = await get(request.url);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: request,
    );
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    switch (url.toString()) {
      case 'https://diatar.eu/downloads/dtz/_list.php':
        return http.Response.bytes(
          utf8.encode('song.dtz,42,20240101010101\n'),
          200,
        );
      case 'https://diatar.eu/downloads/zene/_list.php':
        return http.Response.bytes(
          utf8.encode(
            'https://github.com/diatar-eu/diatar-web/releases/download/zene/song.zip,111,20240101010102\n'
            'zenek.txt,1,20240101010102\n',
          ),
          200,
        );
      case 'https://diatar.eu/downloads/zene/zenek.txt':
        return http.Response.bytes(utf8.encode('song.dtz=song.zip\n'), 200);
      case 'https://diatar.eu/downloads/dtz/song.dtz':
        return http.Response.bytes(
          utf8.encode(
            'Blegacy\\audio\\\nZ00000001 song.mp3\n'
            'blegacy\\scores\\\nf00000001 song.png\n',
          ),
          200,
        );
      case 'https://github.com/diatar-eu/diatar-web/releases/download/zene/song.zip':
        final Archive archive = Archive()
          ..addFile(ArchiveFile('music/song.mp3', 4, <int>[1, 2, 3, 4]));
        return http.Response.bytes(ZipEncoder().encodeBytes(archive), 200);
      default:
        throw UnsupportedError('Unexpected URL: $url');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
