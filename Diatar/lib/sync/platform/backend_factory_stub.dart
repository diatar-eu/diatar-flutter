import 'sync_backend.dart';

bool get isSyncSupported => false;

SyncBackend createSyncBackend() {
  throw UnsupportedError(
    'Ehhez a platformhoz nincs elérhető mappaszinkronizálás.',
  );
}
