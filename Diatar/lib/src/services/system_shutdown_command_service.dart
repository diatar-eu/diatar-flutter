import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the native Windows runner ready to execute the exit command when the
/// operating system terminates the session before Dart can finish shutdown.
class SystemShutdownCommandService {
  const SystemShutdownCommandService();

  static const MethodChannel _channel = MethodChannel('diatar/system_shutdown');

  Future<void> updateExitCommand(String command) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    await _channel.invokeMethod<void>('setExitCommand', command);
  }
}
