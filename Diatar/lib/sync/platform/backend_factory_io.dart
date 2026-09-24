import 'package:flutter/foundation.dart';

import 'android_sync_backend.dart';
import 'file_system_sync_backend.dart';
import 'sync_backend.dart';

bool get isSyncSupported {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

SyncBackend createSyncBackend() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSyncBackend();
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return FileSystemSyncBackend();
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      throw UnsupportedError(
        'Ehhez a platformhoz nincs elérhető mappaszinkronizálás.',
      );
  }
}
