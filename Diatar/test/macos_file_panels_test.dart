import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/services/macos_file_panels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('diatar/macos_file_panels');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return call.method == 'openPanel'
              ? <Object?>['/var/mobile/…/Inbox/olvasnivaló.dia']
              : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'on iOS the open panel goes through the native channel, not file_selector',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final List<XFile> files = await showFileOpenPanel(
        extensions: const <String>['dia'],
      );

      // A file_selector iOS implementációja a megnyitó választót az
      // `UIApplicationDelegate.window`-ból indulva jeleníti meg, ami a
      // `UISceneDelegate`-es életciklusban nincs beállítva — emiatt a
      // hívásnak a saját csatornánkon kell mennie.
      expect(calls.single.method, equals('openPanel'));
      expect(
        calls.single.arguments,
        equals(<String, Object?>{
          'extensions': <String>['dia'],
          'multiple': false,
          'directoryPath': null,
        }),
      );
      expect(files.single.path, equals('/var/mobile/…/Inbox/olvasnivaló.dia'));
    },
  );

  test('on iOS a cancelled native panel yields no files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return <Object?>[];
        });

    expect(await showFileOpenPanel(), isEmpty);
  });
}
