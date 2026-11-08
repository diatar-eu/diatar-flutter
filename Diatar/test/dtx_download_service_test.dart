import 'package:diatar_app/src/services/dtx_download_service.dart';
import 'package:file/local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'manual refresh overwrites a current book while automatic refresh skips it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final dir = await LocalFileSystem().systemTempDirectory.createTemp(
        'dtx_force_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dtx_stamp_book.dtx', '1');
      await dir.childFile('book.dtx').writeAsString('damaged');
      const item = DtxDownloadItem(
        fileName: 'book.dtx',
        timestamp: '1',
        size: 7,
        group: '',
        order: 0,
        longName: 'Book',
        shortName: '',
        isInstalled: true,
      );
      int requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response('correct', 200);
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        final service = DtxDownloadService();
        final skipped = await service.downloadUpdates(
          targetDir: dir,
          selected: <DtxDownloadItem>[item],
        );
        expect(skipped.skipped, 1);
        expect(requests, 0);
        final refreshed = await service.downloadUpdates(
          targetDir: dir,
          selected: <DtxDownloadItem>[item],
          force: true,
        );
        expect(refreshed.downloaded, 1);
        expect(requests, 1);
        expect(await dir.childFile('book.dtx').readAsString(), 'correct');
        await service.deleteLocalFiles(
          targetDir: dir,
          fileNames: <String>['book.dtx'],
        );
        expect(dir.childFile('book.dtx').existsSync(), isFalse);
        expect(prefs.getString('dtx_stamp_book.dtx'), isNull);
      }, () => client);
    },
  );
}
