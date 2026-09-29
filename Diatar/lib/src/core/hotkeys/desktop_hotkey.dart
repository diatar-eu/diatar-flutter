import 'package:flutter/services.dart';

String? desktopHotkeyActionForEvent(
  KeyEvent event,
  Map<String, String> actionHotkeys,
) {
  if (event is! KeyDownEvent) {
    return null;
  }

  final String combo = desktopHotkeyComboForEvent(event);
  if (combo.isEmpty) {
    return null;
  }

  final String normalizedCombo = _normalizeStoredCombo(combo);
  for (final MapEntry<String, String> entry in actionHotkeys.entries) {
    if (_normalizeStoredCombo(entry.value) == normalizedCombo) {
      return entry.key;
    }
  }
  return null;
}

String? desktopHotkeyValueForCombo(
  String combo,
  Map<String, String> hotkeys,
) {
  final String normalizedCombo = _normalizeStoredCombo(combo);
  for (final MapEntry<String, String> entry in hotkeys.entries) {
    if (_normalizeStoredCombo(entry.key) == normalizedCombo) {
      return entry.value;
    }
  }
  return null;
}

String desktopHotkeyComboForEvent(KeyEvent event) {
  final LogicalKeyboardKey key = event.logicalKey;
  if (_isModifierKey(key)) {
    return '';
  }

  final List<String> parts = <String>[];
  if (HardwareKeyboard.instance.isControlPressed) {
    parts.add('Ctrl');
  }
  if (HardwareKeyboard.instance.isAltPressed) {
    parts.add('Alt');
  }
  if (HardwareKeyboard.instance.isShiftPressed) {
    parts.add('Shift');
  }
  if (HardwareKeyboard.instance.isMetaPressed) {
    parts.add('Meta');
  }

  final String keyPart = _normalizeKeyPart(key);
  if (keyPart.isEmpty) {
    return '';
  }
  parts.add(keyPart);
  return parts.join('+');
}

bool _isModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;
}

String _normalizeKeyPart(LogicalKeyboardKey key) {
  final String label = key.keyLabel.trim();
  if (label.isNotEmpty && label.length == 1) {
    final int code = label.codeUnitAt(0);
    if ((code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x30 && code <= 0x39)) {
      return label.toUpperCase();
    }
  }

  final String debugName = key.debugName ?? '';
  if (debugName.isEmpty) {
    return label.isNotEmpty ? _capitalize(label) : '';
  }
  if (debugName.startsWith('F') && debugName.length <= 3) {
    return debugName.toUpperCase();
  }
  return _capitalize(debugName.replaceAll(' ', ''));
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

String _normalizeStoredCombo(String combo) {
  return combo.replaceAll(RegExp(r'\s+'), '');
}
