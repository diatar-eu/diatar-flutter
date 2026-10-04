// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/services/web_diavetito_url.dart';
import 'package:diatar_app/src/app.dart';
import 'package:diatar_app/src/ui/home_page.dart';
import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('web DiaVetito link follows the MQTT username', () {
    expect(
      webDiaVetitoUrl('Közvetítő'),
      'https://web.diatar.eu/diavetito/?mqtt=K%C3%B6zvet%C3%ADt%C5%91',
    );
    expect(
      webDiaVetitoUrl('  Peter  '),
      'https://web.diatar.eu/diavetito/?mqtt=Peter',
    );
  });

  testWidgets('shows diatar navigation controls', (WidgetTester tester) async {
    await tester.pumpWidget(const DiatarApp());
    await tester.pump(const Duration(milliseconds: 200));

    final AppLocalizations hu = await AppLocalizations.delegate.load(
      const Locale('hu'),
    );
    final AppLocalizations en = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(
      find.text(hu.appTitle).evaluate().length +
          find.text(en.appTitle).evaluate().length,
      1,
    );
    expect(
      find.byTooltip(hu.songPrev).evaluate().length +
          find.byTooltip(en.songPrev).evaluate().length,
      1,
    );
    expect(
      find.byTooltip(hu.previous).evaluate().length +
          find.byTooltip(en.previous).evaluate().length,
      1,
    );
    expect(
      find.byTooltip(hu.next).evaluate().length +
          find.byTooltip(en.next).evaluate().length,
      1,
    );
    expect(
      find.byTooltip(hu.songNext).evaluate().length +
          find.byTooltip(en.songNext).evaluate().length,
      1,
    );
  });

  testWidgets(
    'books view handles a selected custom order omitted from the dropdown',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final DiatarMainController controller = DiatarMainController()
        ..books = const <DtxBook>[
          DtxBook(fileName: 'test.dtx', title: 'Test', songs: <DtxSong>[]),
        ];
      await controller.applyCustomOrder(
        const <CustomOrderEntry>[
          CustomOrderEntry(
            fileName: '',
            songIndex: -1,
            verseIndex: 0,
            label: 'Test slide',
            customTextTitle: 'Test slide',
            customTextBody: 'Test body',
          ),
        ],
        activate: true,
        syncProjection: false,
      );
      await controller.toggleCustomOrderSetEnabled(0);
      controller.selectDiaVirtualBook();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiatarHomePage(controller: controller),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
