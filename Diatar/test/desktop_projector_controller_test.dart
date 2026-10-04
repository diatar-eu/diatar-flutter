import 'package:diatar_app/src/ui/desktop_projector_window.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

MethodCall _call(String method, [dynamic arguments]) =>
    MethodCall(method, arguments);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopProjectorController channel contract', () {
    late DesktopProjectorController controller;

    setUp(() {
      controller = DesktopProjectorController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('settings updates the settings and the monitor', () async {
      await controller.handleMethodCall(
        _call(
          'settings',
          const AppSettings().copyWith(desktopProjectorMonitor: 2).toMap(),
        ),
      );

      expect(controller.monitor, 2);
      expect(controller.settings.desktopProjectorMonitor, 2);
    });

    test('state drives the projecting flag and the shown frame', () async {
      expect(controller.activeFrame, isA<LogoFrame>());

      await controller.handleMethodCall(
        _call(
          'state',
          encodeStateRecord(
            const ProjectionGlobals(),
            projecting: false,
            wordToHighlight: 0,
          ),
        ),
      );

      expect(controller.globals.projecting, isFalse);
      expect(controller.activeFrame, isNull);

      await controller.handleMethodCall(
        _call(
          'state',
          encodeStateRecord(
            const ProjectionGlobals(),
            projecting: true,
            wordToHighlight: 3,
          ),
        ),
      );

      expect(controller.globals.projecting, isTrue);
      expect(controller.globals.wordToHighlight, 3);
      expect(controller.activeFrame, isA<LogoFrame>());
    });

    test('text replaces the projected frame', () async {
      await controller.handleMethodCall(
        _call('state', encodeStateRecord(
          const ProjectionGlobals(),
          projecting: true,
          wordToHighlight: 0,
        )),
      );
      await controller.handleMethodCall(
        _call(
          'text',
          encodeTextRecord(title: 'Ének 1', lines: <String>['1. sor']),
        ),
      );

      final ProjectionFrame frame = controller.activeFrame!;
      expect(frame, isA<TextFrame>());
      expect((frame as TextFrame).record.title, 'Ének 1');
      expect(frame.record.lines, <String>['1. sor']);
    });

    test('idle is accepted and does not change the frame', () async {
      await controller.handleMethodCall(_call('idle'));

      expect(controller.activeFrame, isA<LogoFrame>());
    });

    test('unknown methods are rejected', () {
      expect(
        () => controller.handleMethodCall(_call('nope')),
        throwsA(isA<MissingPluginException>()),
      );
    });

    // The projector window is hide-only on every platform: the bridge hides
    // it instead of closing it, so neither the per-window `window_close`
    // channel nor the `close` channel method has a sender any more. A close
    // request must therefore be rejected like any other unknown method, which
    // is what makes it visible here instead of silently doing nothing.
    test('there is no close door left on the projector', () {
      expect(
        () => controller.handleMethodCall(_call('close')),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}