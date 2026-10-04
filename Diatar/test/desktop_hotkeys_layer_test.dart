import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/ui/desktop_hotkeys_layer.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('handles hotkeys after focus leaves the layer subtree', (
    WidgetTester tester,
  ) async {
    final DiatarMainController controller = DiatarMainController()
      ..settings = const AppSettings(
        desktopActionHotkeys: <String, String>{'toggleProjection': 'Escape'},
      );
    final FocusNode outsideFocus = FocusNode();
    addTearDown(outsideFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              DesktopHotkeysLayer(
                controller: controller,
                child: const SizedBox.expand(),
              ),
              Focus(focusNode: outsideFocus, child: const SizedBox()),
            ],
          ),
        ),
      ),
    );

    outsideFocus.requestFocus();
    await tester.pump();
    expect(outsideFocus.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

    expect(controller.showing, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('does not handle hotkeys while typing', (
    WidgetTester tester,
  ) async {
    final DiatarMainController controller = DiatarMainController()
      ..settings = const AppSettings(
        desktopActionHotkeys: <String, String>{'toggleProjection': 'Escape'},
      );

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopHotkeysLayer(
          controller: controller,
          child: const Scaffold(body: TextField(autofocus: true)),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    expect(controller.showing, isFalse);
    expect(controller.showing, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
