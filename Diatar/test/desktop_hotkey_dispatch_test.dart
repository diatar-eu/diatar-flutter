import 'package:diatar_app/src/core/hotkeys/desktop_hotkey_dispatch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Map<String, String> actionHotkeys = <String, String>{
    'nextVerse': 'F1',
  };
  const Map<String, String> songHotkeys = <String, String>{
    'F2': 'konyv1.dtx::3',
  };
  const Map<String, String> orderSetHotkeys = <String, String>{
    'F3': 'order-set-7',
  };

  test('resolves an action hotkey', () {
    expect(
      desktopHotkeyCommandForEvent(
        _down(LogicalKeyboardKey.f1),
        actionHotkeys: actionHotkeys,
        songHotkeys: songHotkeys,
        orderSetHotkeys: orderSetHotkeys,
      ),
      const DesktopHotkeyCommand(DesktopHotkeyKind.action, 'nextVerse'),
    );
  });

  test('resolves a song hotkey binding', () {
    expect(
      desktopHotkeyCommandForEvent(
        _down(LogicalKeyboardKey.f2),
        actionHotkeys: actionHotkeys,
        songHotkeys: songHotkeys,
        orderSetHotkeys: orderSetHotkeys,
      ),
      const DesktopHotkeyCommand(
        DesktopHotkeyKind.song,
        'konyv1.dtx::3',
      ),
    );
  });

  test('resolves an order set hotkey', () {
    expect(
      desktopHotkeyCommandForEvent(
        _down(LogicalKeyboardKey.f3),
        actionHotkeys: actionHotkeys,
        songHotkeys: songHotkeys,
        orderSetHotkeys: orderSetHotkeys,
      ),
      const DesktopHotkeyCommand(
        DesktopHotkeyKind.orderSet,
        'order-set-7',
      ),
    );
  });

  test('action hotkeys win over song and order set hotkeys', () {
    const Map<String, String> sharedSong = <String, String>{'F1': 'a.dtx::0'};
    const Map<String, String> sharedOrder = <String, String>{'F1': 'set-1'};
    expect(
      desktopHotkeyCommandForEvent(
        _down(LogicalKeyboardKey.f1),
        actionHotkeys: actionHotkeys,
        songHotkeys: sharedSong,
        orderSetHotkeys: sharedOrder,
      ),
      const DesktopHotkeyCommand(DesktopHotkeyKind.action, 'nextVerse'),
    );
  });

  test('ignores unbound keys and non key-down events', () {
    expect(
      desktopHotkeyCommandForEvent(
        _down(LogicalKeyboardKey.f9),
        actionHotkeys: actionHotkeys,
        songHotkeys: songHotkeys,
        orderSetHotkeys: orderSetHotkeys,
      ),
      isNull,
    );
    expect(
      desktopHotkeyCommandForEvent(
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.f1,
          timeStamp: Duration.zero,
        ),
        actionHotkeys: actionHotkeys,
        songHotkeys: songHotkeys,
        orderSetHotkeys: orderSetHotkeys,
      ),
      isNull,
    );
  });

  test('ignores bare modifier presses', () {
    expect(
      desktopHotkeyCommandForEvent(
        _down(LogicalKeyboardKey.shiftLeft),
        actionHotkeys: const <String, String>{'nextVerse': 'Shift'},
        songHotkeys: songHotkeys,
        orderSetHotkeys: orderSetHotkeys,
      ),
      isNull,
    );
  });

  test('command survives a channel round trip', () {
    const DesktopHotkeyCommand command = DesktopHotkeyCommand(
      DesktopHotkeyKind.orderSet,
      'order-set-7',
    );
    expect(
      DesktopHotkeyCommand.fromMap(command.toMap()),
      command,
    );
    expect(command.toMap(), <String, Object?>{
      'kind': 'orderSet',
      'value': 'order-set-7',
    });
  });

  test('rejects malformed command payloads', () {
    expect(DesktopHotkeyCommand.fromMap(null), isNull);
    expect(DesktopHotkeyCommand.fromMap('nextVerse'), isNull);
    expect(
      DesktopHotkeyCommand.fromMap(<String, Object?>{'kind': 'nope', 'value': 'x'}),
      isNull,
    );
    expect(
      DesktopHotkeyCommand.fromMap(<String, Object?>{'kind': 'action'}),
      isNull,
    );
    expect(
      DesktopHotkeyCommand.fromMap(<String, Object?>{
        'kind': 'action',
        'value': '',
      }),
      isNull,
    );
  });
}
