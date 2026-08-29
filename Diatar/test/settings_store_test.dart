import 'package:diatar_app/src/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Map<String, String> defaultActionHotkeys = <String, String>{
    'prevVerse': 'ArrowUp',
    'nextVerse': 'ArrowDown',
    'prevSong': 'PageUp',
    'nextSong': 'PageDown',
    'toggleProjection': 'Escape',
    'highlightPrev': 'ArrowLeft',
    'highlightNext': 'ArrowRight',
  };

  test('loads default desktop action hotkeys for new installations', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final settings = await SettingsStore().load();

    expect(settings.desktopActionHotkeys, defaultActionHotkeys);
  });

  test('migrates legacy empty desktop action hotkeys to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'DesktopActionHotkeys': <String>[],
    });

    final settings = await SettingsStore().load();
    final prefs = await SharedPreferences.getInstance();

    expect(settings.desktopActionHotkeys, defaultActionHotkeys);
    expect(
      prefs.getStringList('DesktopActionHotkeys'),
      containsAll(<String>[
        'prevSong\tPageUp',
        'prevVerse\tArrowUp',
        'toggleProjection\tEscape',
        'nextVerse\tArrowDown',
        'nextSong\tPageDown',
        'highlightPrev\tArrowLeft',
        'highlightNext\tArrowRight',
      ]),
    );
  });

  test('preserves intentionally cleared desktop action hotkeys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'DesktopActionHotkeys': <String>[],
      'DesktopActionHotkeysInitialized': true,
    });

    final settings = await SettingsStore().load();

    expect(settings.desktopActionHotkeys, isEmpty);
  });
}
