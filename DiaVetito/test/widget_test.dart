// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:diavetito/src/app.dart';
import 'package:diavetito/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('app renders settings button', (WidgetTester tester) async {
    await tester.pumpWidget(const DiaVetitoApp());
    await tester.pumpAndSettle();

    final AppLocalizations hu = await AppLocalizations.delegate.load(
      const Locale('hu'),
    );
    final AppLocalizations en = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(
      find.text(hu.settingsTitleReceiver).evaluate().length +
          find.text(en.settingsTitleReceiver).evaluate().length,
      1,
    );
  });
}
