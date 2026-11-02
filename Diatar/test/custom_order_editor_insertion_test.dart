import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/services/song_search_service.dart';
import 'package:diatar_app/src/ui/custom_order_editor_sheet.dart';
import 'package:diatar_app/src/ui/song_search_sheet.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final fromSearch in <bool>[false, true]) {
    testWidgets(
      'inserting verses ${fromSearch ? 'from search' : 'from the song picker'} '
      'selects the last verse and continues after it',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 900);
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
        });
        SharedPreferences.setMockInitialValues(<String, Object>{});
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
        final controller = DiatarMainController()
          ..books = const <DtxBook>[
            DtxBook(
              fileName: 'test.dtx',
              title: 'Test',
              songs: <DtxSong>[
                DtxSong(
                  title: '1',
                  verses: <DtxVerse>[
                    DtxVerse(name: '1', lines: <String>[]),
                    DtxVerse(name: '2', lines: <String>[]),
                    DtxVerse(name: '3', lines: <String>[]),
                  ],
                ),
              ],
            ),
          ];
        addTearDown(controller.dispose);
        await controller.applyCustomOrder(
          List<CustomOrderEntry>.generate(
            2,
            (_) => CustomOrderEntry(
              fileName: 'test.dtx',
              songIndex: 0,
              verseIndex: 0,
              label: controller.buildEntryLabel('test.dtx', 0, 0),
            ),
          ),
          activate: true,
          syncProjection: false,
        );
        controller.selectCustomOrderEntryForEditing(0);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('hu'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomOrderEditorPanel(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CustomOrderEditorPanel)),
        )!;

        Future<void> insertVerses() async {
          final button = find.byTooltip(
            fromSearch ? l10n.addSong : l10n.customOrderInsertVersesAction,
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          if (!fromSearch) {
            // The existing picker triggers this unrelated Flutter diagnostic.
            expect(
              tester.takeException(),
              anyOf(
                isNull,
                isA<AssertionError>().having(
                  (error) => error.toString(),
                  'message',
                  contains(
                    'ListTile background color or ink splashes may be invisible.',
                  ),
                ),
              ),
            );
          }
          if (fromSearch) {
            final sheet = tester.widget<SongSearchSheet>(
              find.byType(SongSearchSheet),
            );
            Navigator.of(tester.element(find.byType(SongSearchSheet))).pop();
            sheet.onSelected(
              const SongSearchResult(
                bookIndex: 0,
                songIndex: 0,
                verseIndex: 0,
                bookTitle: 'Test',
                songTitle: '1',
                verseName: '1',
                snippet: '',
                isLyricsMatch: false,
              ),
            );
          } else {
            await tester.tap(
              find.widgetWithText(
                FilledButton,
                l10n.customOrderInsertVersesAction,
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(FilledButton, l10n.apply));
          }
          await tester.pumpAndSettle();
        }

        await insertVerses();
        expect(controller.customOrderCursor, 3);
        expect(controller.customOrder.map((entry) => entry.verseIndex), <int>[
          0,
          0,
          1,
          2,
          0,
        ]);
        await insertVerses();
        expect(controller.customOrderCursor, 6);
        expect(controller.customOrder.map((entry) => entry.verseIndex), <int>[
          0,
          0,
          1,
          2,
          0,
          1,
          2,
          0,
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
