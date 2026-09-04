import 'package:diatar_app/src/ui/desktop_hotkey.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('recognizes every default desktop action hotkey', () {
    final Map<LogicalKeyboardKey, String> expectedActions =
        <LogicalKeyboardKey, String>{
          LogicalKeyboardKey.pageUp: 'prevSong',
          LogicalKeyboardKey.arrowUp: 'prevVerse',
          LogicalKeyboardKey.escape: 'toggleProjection',
          LogicalKeyboardKey.arrowDown: 'nextVerse',
          LogicalKeyboardKey.pageDown: 'nextSong',
          LogicalKeyboardKey.arrowLeft: 'highlightPrev',
          LogicalKeyboardKey.arrowRight: 'highlightNext',
        };

    for (final MapEntry<LogicalKeyboardKey, String> entry
        in expectedActions.entries) {
      expect(
        desktopHotkeyActionForEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: entry.key,
            timeStamp: Duration.zero,
          ),
          defaultActionHotkeys,
        ),
        entry.value,
      );
    }
  });

  test('recognizes screen-mode action hotkeys when configured', () {
    const Map<String, String> homeModeHotkeys = <String, String>{
      'homeBooks': 'F1',
      'homeDialist': 'F2',
      'homePresentation': 'F3',
    };

    final Map<LogicalKeyboardKey, String> expectedActions =
        <LogicalKeyboardKey, String>{
          LogicalKeyboardKey.f1: 'homeBooks',
          LogicalKeyboardKey.f2: 'homeDialist',
          LogicalKeyboardKey.f3: 'homePresentation',
        };

    for (final MapEntry<LogicalKeyboardKey, String> entry
        in expectedActions.entries) {
      expect(
        desktopHotkeyActionForEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: entry.key,
            timeStamp: Duration.zero,
          ),
          homeModeHotkeys,
        ),
        entry.value,
      );
    }
  });

  test('recognizes hotkeys saved with spaced key names', () {
    const Map<String, String> actionHotkeys = <String, String>{
      'prevSong': 'Page Up',
      'nextSong': 'Page Down',
    };

    expect(
      desktopHotkeyActionForEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.pageUp,
          timeStamp: Duration.zero,
        ),
        actionHotkeys,
      ),
      'prevSong',
    );
    expect(
      desktopHotkeyValueForCombo('PageDown', <String, String>{
        'Page Down': 'next-song',
      }),
      'next-song',
    );
  });
}
