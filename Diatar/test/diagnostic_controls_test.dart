import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_common/services/diagnostic_log.dart';
import 'package:diatar_common/ui/diagnostic_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DiagnosticLog log;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> initializeLog() async {
    log = DiagnosticLog(
      metadataLoader: () async => const DiagnosticMetadata(
        version: '12.0.0',
        build: '158',
        os: 'ios',
        osVersion: '18.2',
      ),
    );
    await log.initialize(DiagnosticApp.sender);
  }

  tearDown(() {
    log.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> showControls(
    WidgetTester tester, {
    Future<void> Function(String, Rect)? exportLog,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final AppLocalizations l10n = AppLocalizations.of(context)!;
            return DiagnosticControls(
              app: DiagnosticApp.sender,
              log: log,
              exportLog: exportLog,
              labels: DiagnosticLabels(
                title: l10n.diagnosticsTitle,
                hint: l10n.diagnosticsHint,
                share: l10n.diagnosticsShare,
                save: l10n.diagnosticsSave,
                clear: l10n.diagnosticsClear,
                cleared: l10n.diagnosticsCleared,
                error: l10n.diagnosticsError,
                retry: l10n.diagnosticsRetry,
                empty: l10n.diagnosticsEmpty,
                shareUnavailable: l10n.diagnosticsShareUnavailable,
              ),
            );
          },
        ),
      ),
    ),
  );

  testWidgets('toggle persists immediately and clearing preserves opt-in', (
    tester,
  ) async {
    await initializeLog();
    await showControls(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(log.enabled, isTrue);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('diagnostics.enabled'), isTrue);

    await tester.tap(find.text('Clear log'));
    await tester.pumpAndSettle();
    expect(log.hasEntries, isFalse);
    expect(log.enabled, isTrue);
    expect(find.text('Stored log cleared.'), findsOneWidget);
    expect(prefs.getKeys(), <String>{'diagnostics.enabled'});
  });

  testWidgets(
    'iPad export receives the current log and a valid popover anchor',
    (tester) async {
      await initializeLog();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await log.setEnabled(true);
      log.record(DiagnosticEvent.mqttDisconnected);
      String? exported;
      Rect? anchor;
      await showControls(
        tester,
        exportLog: (text, origin) async {
          exported = text;
          anchor = origin;
        },
      );
      await tester.tap(find.text('Share log'));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(exported, contains('"event":"mqttDisconnected"'));
      expect(anchor, isNotNull);
      expect(anchor!.width, greaterThan(0));
      expect(anchor!.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('export errors are localized without revealing raw details', (
    tester,
  ) async {
    await initializeLog();
    await log.setEnabled(true);
    await showControls(
      tester,
      exportLog: (_, __) async {
        throw StateError('private-user private-password private-path');
      },
    );
    await tester.tap(find.text('Share log'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The diagnostic action failed.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-user'), findsNothing);
    expect(find.textContaining('private-password'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
