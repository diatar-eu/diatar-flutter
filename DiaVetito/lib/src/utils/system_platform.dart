import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform helpers backed by the native system MethodChannel.
class SystemPlatform {
  SystemPlatform._();

  static bool? _tvOsOverride;

  static const MethodChannel _channel = MethodChannel(
    'com.polyjoe.diavetito/system',
  );

  /// Whether the device is an Android TV (leanback) box or an Android device
  /// without a touchscreen.
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

  /// Whether the app runs on tvOS (Apple TV).
  ///
  /// On tvOS [Platform.operatingSystem] reports `"tvos"` (the flutter-tvos
  /// embedder exposes the equivalent `Platform.isTvOS` getter, which stock
  /// Dart SDKs do not have — hence the portable string check). Synchronous so
  /// it can gate builds without an async window.
  static bool get isTvOs =>
      _tvOsOverride ?? (!kIsWeb && Platform.operatingSystem == 'tvos');

  /// Test-only override for simulating tvOS in widget tests.
  @visibleForTesting
  static void debugSetTvOsOverride(bool? value) {
    _tvOsOverride = value;
  }
}
