import 'dart:async';

import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/services/dtx_download_service.dart';
import 'package:diatar_app/src/services/dtz_download_service.dart';
import 'package:diatar_app/src/ui/home_page.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineController extends DiatarMainController {
  final pendingBooks = Completer<List<DtxManageItem>>();

  @override
  Future<void> updateScreenSize({
    required int width,
    required int height,
  }) async {}

  @override
  Future<List<DtxManageItem>> loadDtxManagerItems() => pendingBooks.future;

  @override
  Future<List<DtzManageItem>> loadDtzManagerItems() async => [];

  @override
  Future<List<DtzManageItem>> loadMusicManagerItems() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final audioEventChannels = <MethodChannel>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await LocalFileSystem().systemTempDirectory.createTemp(
      'startup_content_',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final playerId = (call.arguments as Map)['playerId'] as String;
          final channel = MethodChannel(
            'xyz.luan/audioplayers/events/$playerId',
          );
          audioEventChannels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      },
    );
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
    for (final channel in audioEventChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    audioEventChannels.clear();
    await root.delete(recursive: true);
  });

  testWidgets(
    'empty library opens once despite status changes and unavailable internet',
    (tester) async {
      final controller = _OfflineController();
      addTearDown(controller.dispose);
      await tester.runAsync(controller.reloadBooks);
      expect(controller.statusCode, 'statusNoDtxFiles');
      controller.statusCode = 'statusTcpSending';

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiatarHomePage(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);

      controller.pendingBooks.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      )!;
      expect(
        find.text(l10n.statusDownloadError('Exception: offline')),
        findsWidgets,
      );
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.runAsync(controller.reloadBooks);
      controller.statusCode = 'statusMqttSending';
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(controller.shouldAutoOpenDownloadDialog, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final bool enabled in [true, false]) {
    test(
      'installed songbooks do not request download: enabled=$enabled',
      () async {
        final file = root
            .childDirectory('diatar')
            .childDirectory('DTXs')
            .childFile('book.dtx');
        await file.create(recursive: true);
        await file.writeAsString('NBook\n>Song\n /1\n Text\n');
        final controller = DiatarMainController();
        addTearDown(controller.dispose);
        await controller.applySongbookOrder({'book.dtx': enabled});
        expect(
          controller.statusCode,
          enabled ? 'statusSongbooksLoaded' : 'statusAllSongbooksDisabled',
        );
        expect(controller.shouldAutoOpenDownloadDialog, isFalse);
      },
    );
  }

  test('finds only non-excluded installed DTX updates at startup', () {
    final DtxDownloadItem update = DtxDownloadItem(
      fileName: 'book.dtx',
      timestamp: '20260916100000',
      size: 1,
      group: '',
      order: 0,
      longName: 'Book',
      shortName: 'Book',
      isInstalled: true,
      updateAvailable: true,
    );

    expect(
      DiatarMainController.hasEligibleStartupDtxUpdate(<DtxManageItem>[
        DtxManageItem(item: update, excluded: true),
      ]),
      isFalse,
    );
    expect(
      DiatarMainController.hasEligibleStartupDtxUpdate(<DtxManageItem>[
        DtxManageItem(item: update, excluded: false),
      ]),
      isTrue,
    );
  });

  test(
    'finds only non-excluded installed score and music updates at startup',
    () {
      final DtzDownloadItem update = DtzDownloadItem(
        fileName: 'song.dtz',
        timestamp: '20260916100000',
        size: 1,
        title: 'Song',
        zips: const <String>[],
        isInstalled: true,
        updateAvailable: true,
      );

      expect(
        DiatarMainController.hasEligibleStartupDtzUpdate(<DtzManageItem>[
          DtzManageItem(item: update, excluded: true),
        ]),
        isFalse,
      );
      expect(
        DiatarMainController.hasEligibleStartupDtzUpdate(<DtzManageItem>[
          DtzManageItem(item: update, excluded: false),
        ]),
        isTrue,
      );
    },
  );
}
