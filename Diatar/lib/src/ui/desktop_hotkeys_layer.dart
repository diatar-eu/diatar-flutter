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
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  bool _onKeyEvent(KeyEvent event) {
    if (!_supportsMainWindowHotkeys() ||
        event is! KeyDownEvent ||
        !_isCurrentRoute() ||
        _isTypingIntoTextField()) {
      return false;
    }

    final Map<String, String> actionHotkeys =
        widget.controller.settings.desktopActionHotkeys;
    final String? actionId = desktopHotkeyActionForEvent(event, actionHotkeys);
    if (actionId != null) {
      widget.controller.runDesktopHotkeyAction(actionId);
      return true;
    }

    final String combo = desktopHotkeyComboForEvent(event);
    if (combo.isEmpty) {
      return false;
    }

    final Map<String, String> songHotkeys =
        widget.controller.settings.desktopSongHotkeys;
    final String? songBinding = desktopHotkeyValueForCombo(combo, songHotkeys);
    if (songBinding != null) {
      widget.controller.activateSongHotkeyBinding(songBinding);
      return true;
    }

    final Map<String, String> orderSetHotkeys =
        widget.controller.settings.desktopOrderSetHotkeys;
    final String? orderSetId = desktopHotkeyValueForCombo(
      combo,
      orderSetHotkeys,
    );
    if (orderSetId != null) {
      unawaited(widget.controller.setActiveCustomOrderSetById(orderSetId));
      return true;
    }

    return false;
  }

  bool _isCurrentRoute() {
    if (!mounted) {
      return false;
    }
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  bool _isTypingIntoTextField() {
    final BuildContext? focusContext =
        FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
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
