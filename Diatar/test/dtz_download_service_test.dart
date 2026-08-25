import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diatar_app/src/services/dtz_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('DtzDownloadService', () {
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
      return http.Response.bytes(utf8.encode('song'), 200);
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
          utf8.encode('Z00000001 music/song.mp3'),
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
