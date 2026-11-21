import 'dart:io';

String get diagnosticOperatingSystem => Platform.operatingSystem;

String get diagnosticSystemVersion =>
    RegExp(
      r'\d+(?:\.\d+){1,4}',
    ).firstMatch(Platform.operatingSystemVersion)?.group(0) ??
    'unavailable';
