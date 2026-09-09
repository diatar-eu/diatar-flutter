import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/file_system_provider.dart';

const MethodChannel _channel = MethodChannel('diatar.eu/zip_import');
const String _stagedFilePrefix = 'dtz_import_';

/// Selects a ZIP through Android's document provider and streams it to the
/// app cache natively. This avoids materializing large provider files in the
/// Flutter engine before the import starts.
Future<XFile?> pickAndroidZipImportFile() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  final String? path = await _channel.invokeMethod<String>('pickZipToCache');
  return path == null || path.isEmpty ? null : XFile(path);
}

Future<void> deleteAndroidZipImportFile(String path) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  final String normalized = path.replaceAll('\\', '/');
  if (!normalized.split('/').last.startsWith(_stagedFilePrefix)) {
    return;
  }
  final file = FileSystemProvider.instance.file(path);
  if (await file.exists()) {
    await file.delete();
  }
}
