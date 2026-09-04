import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/diatar_main_controller.dart';
import 'desktop_hotkey.dart';

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

    final Map<String, String> actionHotkeys =
        widget.controller.settings.desktopActionHotkeys;
    final String? actionId = desktopHotkeyActionForEvent(event, actionHotkeys);
    if (actionId != null) {
      widget.controller.runDesktopHotkeyAction(actionId);
      return KeyEventResult.handled;
    }

    final String combo = desktopHotkeyComboForEvent(event);
    if (combo.isEmpty) {
      return KeyEventResult.ignored;
    }

    final Map<String, String> songHotkeys =
        widget.controller.settings.desktopSongHotkeys;
    final String? songBinding = desktopHotkeyValueForCombo(
      combo,
      songHotkeys,
    );
    if (songBinding != null) {
      widget.controller.activateSongHotkeyBinding(songBinding);
      return KeyEventResult.handled;
    }

    final Map<String, String> orderSetHotkeys =
        widget.controller.settings.desktopOrderSetHotkeys;
    final String? orderSetId = desktopHotkeyValueForCombo(
      combo,
      orderSetHotkeys,
    );
    if (orderSetId != null) {
      unawaited(widget.controller.setActiveCustomOrderSetById(orderSetId));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
