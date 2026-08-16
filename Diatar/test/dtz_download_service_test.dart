import 'dart:convert';

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
    test('uses the dedicated DTZ list and still resolves zip dependencies', () async {
      final Directory dir = await LocalFileSystem().systemTempDirectory.createTemp(
        'dtz_service_test_',
      );

      final List<DtzDownloadItem> items = await DtzDownloadService(
        client: _FakeDtzHttpClient(),
      ).listAll(
        targetDir: dir,
        dtxTitles: const <String, String>{'song': 'Song title'},
      );

      expect(items, hasLength(1));
      expect(items.first.fileName, 'song.dtz');
      expect(items.first.timestamp, '20240101010101');
      expect(items.first.size, 42);
      expect(items.first.zips, <String>['cover.zip']);
      expect(items.first.title, 'Song title');
    });
  });
}

class _FakeDtzHttpClient implements http.Client {
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
