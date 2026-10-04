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

    final AppSettings settings = widget.controller.settings;
    final DesktopHotkeyCommand? command = desktopHotkeyCommandForEvent(
      event,
      actionHotkeys: settings.desktopActionHotkeys,
      songHotkeys: settings.desktopSongHotkeys,
      orderSetHotkeys: settings.desktopOrderSetHotkeys,
    );
    if (command == null) {
      return false;
    }
    widget.controller.runDesktopHotkeyCommand(command);
    return true;
  }

  bool _isCurrentRoute() {
    if (!mounted) {
      return false;
    }
    return ModalRoute.of(context)?.isCurrent ?? true;
  }
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
