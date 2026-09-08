// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diatar_common/diatar_common.dart';

import 'package:diavetito/src/app.dart';
import 'package:diavetito/src/services/web_mqtt_settings.dart';
import 'package:diavetito/src/ui/settings_sheet.dart';
import 'package:diavetito/src/utils/system_platform.dart';
import 'package:diavetito/l10n/generated/app_localizations.dart';

void main() {
  group('mqttUsernameFromWebUri', () {
    test('reads a simple MQTT username', () {
      expect(
        mqttUsernameFromWebUri(Uri.parse('https://vetito.example/?mqtt=Peter')),
        'Peter',
      );
    });

    testWidgets('only applies a registered MQTT sender from settings', (
      WidgetTester tester,
    ) async {
      AppSettings? appliedSettings;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsSheet(
              initialSettings: const AppSettings(),
              senderSuggestions: <String>['Hoze', 'hehalom', 'H.Kovacs'],
              onApply: (AppSettings settings) => appliedSettings = settings,
              onConnectInternetFromQr: (_) async => false,
              onRefreshUsers: () async {},
              onSenderFilterChanged: (_) {},
              registeredMqttUsername: (String username) {
                for (final String registered in <String>[
                  'Hoze',
                  'hehalom',
                  'H.Kovacs',
                ]) {
                  if (registered.toLowerCase() == username.toLowerCase()) {
                    return registered;
                  }
                }
                return null;
              },
              onExitRequested: () {},
              onShutdownRequested: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'hoz');
      await tester.pump();

      expect(find.text('Hoze'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(appliedSettings, isNull);
    });

    test('decodes and trims an MQTT username', () {
      expect(
        mqttUsernameFromWebUri(
          Uri.parse(
            'https://vetito.example/?mqtt=%20K%C3%B6zvet%C3%ADt%C5%91%20',
          ),
        ),
        'Közvetítő',
      );
    });

    test('ignores missing and blank MQTT usernames', () {
      expect(
        mqttUsernameFromWebUri(Uri.parse('https://vetito.example/')),
        isNull,
      );
      expect(
        mqttUsernameFromWebUri(
          Uri.parse('https://vetito.example/?mqtt=%20%20'),
        ),
        isNull,
      );
    });
  });

  testWidgets('app renders settings button', (WidgetTester tester) async {
    await tester.pumpWidget(const DiaVetitoApp());
    await tester.pumpAndSettle();

    final AppLocalizations hu = await AppLocalizations.delegate.load(
      const Locale('hu'),
    );
    final AppLocalizations en = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(
      find.text(hu.settingsTitleReceiver).evaluate().length +
          find.text(en.settingsTitleReceiver).evaluate().length,
      1,
    );
  });

  testWidgets('tap shows a quick exit button on native apps', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const MethodChannel systemChannel = MethodChannel(
      'com.polyjoe.diavetito/system',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      systemChannel,
      (MethodCall call) async {
        if (call.method == 'isTv') {
          return false;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        systemChannel,
        null,
      );
    });

    try {
      await tester.pumpWidget(const DiaVetitoApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      final AppLocalizations hu = await AppLocalizations.delegate.load(
        const Locale('hu'),
      );
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );

      expect(
        find.text(hu.exit).evaluate().length +
            find.text(en.exit).evaluate().length,
        1,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('OK (select) key opens settings on Android TV', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const MethodChannel systemChannel = MethodChannel(
      'com.polyjoe.diavetito/system',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      systemChannel,
      (MethodCall call) async {
        if (call.method == 'isTv') {
          return true;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        systemChannel,
        null,
      );
    });

    try {
      await tester.pumpWidget(const DiaVetitoApp());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      final AppLocalizations hu = await AppLocalizations.delegate.load(
        const Locale('hu'),
      );
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        find.text(hu.settingsTitleReceiver).evaluate().length +
            find.text(en.settingsTitleReceiver).evaluate().length,
        1,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('tvOS', () {
    void simulateTvOs() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SystemPlatform.debugSetTvOsOverride(true);
    }

    void resetTvOs() {
      debugDefaultTargetPlatformOverride = null;
      SystemPlatform.debugSetTvOsOverride(null);
    }

    testWidgets('shows the settings button and hides the QR scan button', (
      WidgetTester tester,
    ) async {
      simulateTvOs();
      const MethodChannel systemChannel = MethodChannel(
        'com.polyjoe.diavetito/system',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        systemChannel,
        (MethodCall call) async {
          if (call.method == 'isTv') {
            return false;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          systemChannel,
          null,
        );
      });

      try {
        await tester.pumpWidget(const DiaVetitoApp());
        await tester.pump();

        final AppLocalizations hu = await AppLocalizations.delegate.load(
          const Locale('hu'),
        );
        final AppLocalizations en = await AppLocalizations.delegate.load(
          const Locale('en'),
        );

        expect(
          find.text(hu.settingsTitleReceiver).evaluate().length +
              find.text(en.settingsTitleReceiver).evaluate().length,
          1,
        );
        expect(
          find.text(hu.qrScanButton).evaluate().length +
              find.text(en.qrScanButton).evaluate().length,
          0,
        );
      } finally {
        resetTvOs();
      }
    });

    testWidgets('settings button opens the settings sheet', (
      WidgetTester tester,
    ) async {
      simulateTvOs();

      try {
        await tester.pumpWidget(const DiaVetitoApp());
        await tester.pump();

        final AppLocalizations hu = await AppLocalizations.delegate.load(
          const Locale('hu'),
        );
        final AppLocalizations en = await AppLocalizations.delegate.load(
          const Locale('en'),
        );

        final Finder settingsButton = find.byWidgetPredicate(
          (Widget widget) => widget is FilledButton,
        );
        expect(settingsButton, findsOneWidget);
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        expect(find.byType(SettingsSheet), findsOneWidget);
        expect(
          find.text(hu.qrScanButton).evaluate().length +
              find.text(en.qrScanButton).evaluate().length,
          0,
        );
      } finally {
        resetTvOs();
      }
    });
  });
}
