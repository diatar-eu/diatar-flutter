import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/diatar_main_controller.dart';
import '../core/hotkeys/desktop_hotkey_dispatch.dart';

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
    if (!_supportsMainWindowHotkeys()) {
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

    final AppSettings settings = widget.controller.settings;
    final DesktopHotkeyCommand? command = desktopHotkeyCommandForEvent(
      event,
      actionHotkeys: settings.desktopActionHotkeys,
      songHotkeys: settings.desktopSongHotkeys,
      orderSetHotkeys: settings.desktopOrderSetHotkeys,
    );
    if (command == null) {
      return KeyEventResult.ignored;
    }
    widget.controller.runDesktopHotkeyCommand(command);
    return KeyEventResult.handled;
  }

  bool _isTypingIntoTextField() {
    final BuildContext? focusContext =
        FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText;
  }

  bool _supportsMainWindowHotkeys() {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}
