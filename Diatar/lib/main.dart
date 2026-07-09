import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/services/desktop_projector_bridge.dart';
import 'src/ui/desktop_projector_window.dart';

bool _isDesktopPlatform() {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
}

Map<String, dynamic> _decodeArguments(String raw) {
  if (raw.trim().isEmpty) {
    return <String, dynamic>{};
  }
  final Object decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WakelockPlus.enable();
  if (_isDesktopPlatform()) {
    await windowManager.ensureInitialized();
    final WindowController windowController =
        await WindowController.fromCurrentEngine();
    final Map<String, dynamic> args = _decodeArguments(windowController.arguments);
    if (args['businessId'] == 'desktop_projector') {
      runApp(
        DesktopProjectorWindow(
          monitor: (args['monitor'] as int?) ?? -1,
        ),
      );
      return;
    }
    // Főablak: a vetítő ablakból érkező 'showControl' üzenetre
    // visszahozzuk és fókuszba helyezzük a vezérlő ablakot.
    const WindowMethodChannel controlChannel = WindowMethodChannel(
      'diatar/desktop_projector_control',
      mode: ChannelMode.bidirectional,
    );
    await controlChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'showControl') {
        await DesktopProjectorBridge.instance.showControlWindow();
      }
      return null;
    });
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const DiatarApp());
}
