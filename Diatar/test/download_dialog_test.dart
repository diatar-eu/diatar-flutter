import 'dart:async';

import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/services/dtx_download_service.dart';
import 'package:diatar_app/src/services/dtz_download_service.dart';
import 'package:diatar_app/src/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Controller extends DiatarMainController {
  _Controller({this.installed = false, this.outdated = false});

  final bool installed;
  final bool outdated;
  bool openDownload = true;
  final Map<String, ({Set<String> update, Set<String> exclude})> applied = {};
  Completer<List<DtzManageItem>>? pendingMusic;

  @override
  bool get shouldAutoOpenDownloadDialog => openDownload;

  @override
  void markStartupDownloadDialogHandled() => openDownload = false;

  @override
  Future<void> updateScreenSize({
    required int width,
    required int height,
  }) async {}

  @override
  Future<List<DtxManageItem>> loadDtxManagerItems() async => [
    DtxManageItem(
      item: DtxDownloadItem(
        fileName: 'book.dtx',
        timestamp: '1',
        size: 1,
        group: 'Books',
        order: 1,
        longName: 'Book',
        shortName: '',
        isInstalled: installed,
        updateAvailable: !installed || outdated,
      ),
      excluded: false,
    ),
  ];

  List<DtzManageItem> mediaItems(String title) => [
    DtzManageItem(
      item: DtzDownloadItem(
        fileName: '$title.dtz',
        timestamp: '1',
        size: 1,
        title: title,
        zips: const [],
        isInstalled: installed,
        updateAvailable: !installed || outdated,
      ),
      excluded: !installed,
    ),
  ];

  @override
  Future<List<DtzManageItem>> loadDtzManagerItems() async =>
      mediaItems('Score');

  @override
  Future<List<DtzManageItem>> loadMusicManagerItems() async =>
      pendingMusic == null ? mediaItems('Music') : await pendingMusic!.future;

  @override
  Future<void> applyDtxManagerSelection({
    required Set<String> downloadSelected,
    required Set<String> excludedSelected,
  }) async {
    applied['books'] = (update: downloadSelected, exclude: excludedSelected);
  }

  @override
  Future<void> applyDtzManagerSelection({
    required Set<String> downloadSelected,
    required Set<String> excludedSelected,
  }) async {
    applied['scores'] = (update: downloadSelected, exclude: excludedSelected);
  }

  @override
  Future<void> applyMusicManagerSelection({
    required Set<String> downloadSelected,
    required Set<String> excludedSelected,
  }) async {
    applied['music'] = (update: downloadSelected, exclude: excludedSelected);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          null,
        );
  });

  Future<AppLocalizations> open(
    WidgetTester tester,
    _Controller controller, {
    bool settle = true,
  }) async {
    addTearDown(controller.dispose);
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(AlertDialog), findsOneWidget);
    return AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
  }

  Finder rowCheckbox(String title, int column) {
    final row = find
        .ancestor(of: find.text(title), matching: find.byType(Row))
        .evaluate()
        .firstWhere(
          (element) =>
              find
                  .descendant(
                    of: find.byWidget(element.widget),
                    matching: find.byType(Checkbox),
                  )
                  .evaluate()
                  .length ==
              2,
        );
    return find
        .descendant(
          of: find.byWidget(row.widget),
          matching: find.byType(Checkbox),
        )
        .at(column);
  }

  testWidgets('fresh defaults are applied even for unopened media tabs', (
    tester,
  ) async {
    final controller = _Controller();
    final l10n = await open(tester, controller);
    await tester.tap(find.text(l10n.apply));
    await tester.pumpAndSettle();
    expect(controller.applied['books']!.update, {'book.dtx'});
    expect(controller.applied['books']!.exclude, isEmpty);
    expect(controller.applied['scores']!.update, isEmpty);
    expect(controller.applied['scores']!.exclude, {'Score.dtz'});
    expect(controller.applied['music']!.update, isEmpty);
    expect(controller.applied['music']!.exclude, {'Music.dtz'});
  });

  testWidgets('Apply waits for the unopened music tab to finish loading', (
    tester,
  ) async {
    final controller = _Controller()
      ..pendingMusic = Completer<List<DtzManageItem>>();
    final l10n = await open(tester, controller, settle: false);
    final apply = find.widgetWithText(FilledButton, l10n.apply);
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    controller.pendingMusic!.complete(controller.mediaItems('Music'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(controller.applied['music']!.exclude, {'Music.dtz'});
  });

  testWidgets('a failed unopened tab reports an error and blocks Apply', (
    tester,
  ) async {
    final controller = _Controller()
      ..pendingMusic = Completer<List<DtzManageItem>>();
    final l10n = await open(tester, controller, settle: false);
    controller.pendingMusic!.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.statusDownloadError('Exception: offline')),
      findsWidgets,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, l10n.apply))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'current packages stay unselected and allow manual refresh on every tab',
    (tester) async {
      final controller = _Controller(installed: true);
      final l10n = await open(tester, controller);
      await tester.tap(find.text('[Books]'));
      await tester.pumpAndSettle();
      for (final (String title, String? tab) in [
        ('Book', null),
        ('Score', l10n.downloadTabDtz),
        ('Music', l10n.downloadTabMusic),
      ]) {
        if (tab != null) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
        }
        expect(tester.widget<Checkbox>(rowCheckbox(title, 0)).value, isFalse);
        expect(tester.widget<Checkbox>(rowCheckbox(title, 1)).value, isFalse);
        expect(
          tester.widget<Checkbox>(rowCheckbox(title, 0)).onChanged,
          isNotNull,
        );
        await tester.tap(rowCheckbox(title, 0));
        await tester.pump();
        expect(tester.widget<Checkbox>(rowCheckbox(title, 0)).value, isTrue);
        await tester.tap(rowCheckbox(title, 1));
        await tester.pump();
        expect(tester.widget<Checkbox>(rowCheckbox(title, 0)).value, isFalse);
        await tester.tap(rowCheckbox(title, 0));
        await tester.pump();
        expect(tester.widget<Checkbox>(rowCheckbox(title, 1)).value, isFalse);
      }
      await tester.tap(find.text(l10n.apply));
      await tester.pumpAndSettle();
      expect(controller.applied['books']!.update, {'book.dtx'});
      expect(controller.applied['scores']!.update, {'Score.dtz'});
      expect(controller.applied['music']!.update, {'Music.dtz'});
      for (final selection in controller.applied.values) {
        expect(selection.exclude, isEmpty);
      }
    },
  );

  testWidgets(
    'installed updates are preselected on all tabs without visiting them',
    (tester) async {
      final controller = _Controller(installed: true, outdated: true);
      final l10n = await open(tester, controller);
      await tester.tap(find.text(l10n.apply));
      await tester.pumpAndSettle();
      expect(controller.applied['books']!.update, {'book.dtx'});
      expect(controller.applied['scores']!.update, {'Score.dtz'});
      expect(controller.applied['music']!.update, {'Music.dtz'});
    },
  );
}
