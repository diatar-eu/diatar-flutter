import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/ui/custom_order_editor_sheet.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in <Size>[const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
        'text slide dialog fits $size in $brightness with and without the keyboard',
        (WidgetTester tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
            tester.view.resetViewInsets();
          });
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'),
            (_) async => null,
          );
          final controller = DiatarMainController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness, useMaterial3: true),
              locale: const Locale('hu'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                resizeToAvoidBottomInset: false,
                // Isolate dialog sizing from the underlying order panel's layout.
                body: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 800,
                  maxWidth: 800,
                  minHeight: 600,
                  maxHeight: 600,
                  child: CustomOrderEditorPanel(controller: controller),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CustomOrderEditorPanel)),
          )!;
          final addButton = find.byTooltip(l10n.addTextSlide);
          await tester.ensureVisible(addButton);
          await tester.tap(addButton);
          await tester.pumpAndSettle();
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();

          expect(find.text(l10n.textSlideDialogTitle), findsOneWidget);
          expect(tester.takeException(), isNull);
          final dialogRect = tester.getRect(find.byType(AlertDialog));
          for (final label in <String>[l10n.insertChord, l10n.insertKotta]) {
            final button = find.byTooltip(label);
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final buttonRect = tester.getRect(button);
            expect(dialogRect.contains(buttonRect.topLeft), isTrue);
            expect(dialogRect.contains(buttonRect.bottomRight), isTrue);
            expect(button.hitTestable(), findsOneWidget);
          }

          final bodyField = find.descendant(
            of: find.byType(InlineTextEditor),
            matching: find.byType(TextField),
          );
          expect(
            tester.widget<TextField>(bodyField).decoration?.labelText,
            isNull,
          );
          final fieldContext = tester.element(bodyField);
          final decoration = tester.widget<TextField>(bodyField).decoration!;
          final theme = Theme.of(fieldContext);
          expect(decoration.filled, isTrue);
          expect(
            decoration.fillColor,
            isNot(theme.colorScheme.surfaceContainerHigh),
          );
          final fieldSize = tester.getSize(bodyField);
          final editableSize = tester.getSize(
            find.descendant(of: bodyField, matching: find.byType(EditableText)),
          );
          await tester.ensureVisible(bodyField);
          await tester.enterText(
            bodyField,
            List.filled(8, l10n.textSlideDefaultTitle).join('\n'),
          );
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height > size.width ? 280 : 140,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await Scrollable.ensureVisible(
            tester.element(bodyField),
            alignment: 1,
          );
          await tester.pumpAndSettle();
          expect(
            bodyField.hitTestable(at: const Alignment(0, 0.9)),
            findsOneWidget,
          );
          final cancel = find.widgetWithText(TextButton, l10n.cancel);
          final apply = find.widgetWithText(FilledButton, l10n.apply);
          expect(cancel.hitTestable(), findsOneWidget);
          expect(apply.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(apply).bottom,
            lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
          );
          tester.view.resetViewInsets();
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness, useMaterial3: true),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: fieldSize.width,
                    child: const TextField(
                      decoration: InputDecoration(),
                      minLines: 4,
                      maxLines: 8,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byType(TextField)), fieldSize);
          expect(tester.getSize(find.byType(EditableText)), editableSize);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
