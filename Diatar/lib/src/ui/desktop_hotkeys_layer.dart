import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/diatar_main_controller.dart';

class DesktopHotkeysLayer extends StatefulWidget {
  const DesktopHotkeysLayer({
    super.key,
    required this.controller,
    required this.child,
  });

  final DiatarMainController controller;
  final Widget child;

  @override
  State<DesktopHotkeysLayer> createState() => _DesktopHotkeysLayerState();
}

class _DesktopHotkeysLayerState extends State<DesktopHotkeysLayer> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'desktop-hotkeys-layer');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktopPlatform()) {
      return widget.child;
    }

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_isTypingIntoTextField()) {
      return KeyEventResult.ignored;
    }

    final String combo = _eventToCombo(event);
    if (combo.isEmpty) {
      return KeyEventResult.ignored;
    }

    final Map<String, String> actionHotkeys =
        widget.controller.settings.desktopActionHotkeys;
    String? actionId;
    actionHotkeys.forEach((String action, String savedCombo) {
      if (savedCombo == combo) {
        actionId = action;
      }
    });
    if (actionId != null) {
      _runAction(actionId!);
      return KeyEventResult.handled;
    }

    final Map<String, String> songHotkeys =
        widget.controller.settings.desktopSongHotkeys;
    final String? songBinding = songHotkeys[combo];
    if (songBinding != null) {
      widget.controller.activateSongHotkeyBinding(songBinding);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isTypingIntoTextField() {
    final BuildContext? focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText;
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _runAction(String actionId) {
    switch (actionId) {
      case 'prevSong':
        widget.controller.prevSong();
        break;
      case 'prevVerse':
        widget.controller.prevVerse();
        break;
      case 'toggleProjection':
        widget.controller.toggleShowing();
        break;
      case 'nextVerse':
        widget.controller.nextVerse();
        break;
      case 'nextSong':
        widget.controller.nextSong();
        break;
      case 'highlightPrev':
        widget.controller.highlightPrev();
        break;
      case 'highlightNext':
        widget.controller.highlightNext();
        break;
    }
  }

  String _eventToCombo(KeyEvent event) {
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
    if (label.isNotEmpty) {
      if (label.length == 1) {
        return label.toUpperCase();
      }
      return _capitalize(label);
    }

    final String debugName = key.debugName ?? '';
    if (debugName.isEmpty) {
      return '';
    }
    if (debugName.startsWith('F')) {
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
}
