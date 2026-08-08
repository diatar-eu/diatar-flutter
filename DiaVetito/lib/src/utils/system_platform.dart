import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform helpers backed by the native system MethodChannel.
class SystemPlatform {
  SystemPlatform._();

  static const MethodChannel _channel = MethodChannel(
    'com.polyjoe.diavetito/system',
  );

  /// Whether the device is an Android TV (leanback) box.
  ///
  /// Always false on web and non-Android platforms; gracefully falls back to
  /// false when the native side is unavailable (e.g. in tests).
  static Future<bool> isTv() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final bool? result = await _channel.invokeMethod<bool>('isTv');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
