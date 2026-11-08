import '../../l10n/generated/app_localizations.dart';
import '../services/dtz_download_service.dart';

String localizeDtzDownloadProgress(
  AppLocalizations l10n,
  DtzDownloadProgress progress,
) => switch (progress.phase) {
  DtzDownloadPhase.listing => l10n.mediaProgressListing,
  DtzDownloadPhase.downloading => l10n.downloadProgress(
    progress.currentFile,
    progress.totalFiles,
    progress.fileName,
  ),
  DtzDownloadPhase.extracting => l10n.mediaProgressExtracting(
    progress.currentEntry,
    progress.totalEntries,
  ),
  DtzDownloadPhase.checking => l10n.mediaProgressChecking(
    progress.currentFile,
    progress.totalFiles,
    progress.fileName,
    progress.currentEntry,
    progress.totalEntries,
    progress.entryName,
  ),
  DtzDownloadPhase.writing => l10n.mediaProgressWriting(
    progress.currentFile,
    progress.totalFiles,
    progress.fileName,
  ),
  DtzDownloadPhase.deleting => l10n.mediaProgressDeleting,
  DtzDownloadPhase.cleanup => l10n.mediaProgressCleanup,
  DtzDownloadPhase.saving => l10n.mediaProgressSaving,
  DtzDownloadPhase.loadingBooks => l10n.mediaProgressBooks,
  DtzDownloadPhase.loadingLibrary => l10n.mediaProgressLibrary,
  DtzDownloadPhase.indexing => l10n.mediaProgressIndexing,
  DtzDownloadPhase.settings => l10n.mediaProgressSettings,
};
