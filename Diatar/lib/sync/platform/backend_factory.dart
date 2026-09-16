import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import 'android_sync_backend.dart';
import 'sync_backend.dart';
import 'windows_sync_backend.dart';

SyncBackend createSyncBackend(
  AppLocalizations l10n,
) {
  if (!kIsWeb) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return WindowsSyncBackend(
          l10n: l10n,
        );

      case TargetPlatform.android:
        return AndroidSyncBackend(
          l10n: l10n,
        );

      default:
        break;
    }
  }

  throw UnsupportedError(
    l10n.syncUnsupportedPlatform,
  );
}