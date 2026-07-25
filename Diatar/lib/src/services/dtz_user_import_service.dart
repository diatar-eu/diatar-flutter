import 'dart:convert';

import 'package:archive/archive.dart';

import '../utils/file_system_provider.dart';

/// Per-package import readiness.
enum DtzImportStatus {
  /// No media referenced, or all referenced files are present in the ZIPs.
  ok,
  /// Less than 5 % of referenced media files are missing – importable with warning.
  warning,
  /// Parse failure, or ≥ 5 % of referenced media files are missing.
  error,
}

/// Analysis of a single DTZ file and the media files the ZIPs supply for it.
class DtzImportPackageAnalysis {
  const DtzImportPackageAnalysis({
    required this.dtzFileName,
    required this.referencedFiles,
    required this.matchedFiles,
    required this.missingFiles,
    required this.status,
    this.errorReason,
  });

  final String dtzFileName;

  /// Relative paths (relative to the DTZs/ root) that this DTZ expects.
  final Set<String> referencedFiles;

  /// Subset of [referencedFiles] that are covered by the provided ZIPs.
  final Set<String> matchedFiles;

  /// Subset of [referencedFiles] that are NOT in any of the provided ZIPs.
  final Set<String> missingFiles;

  final DtzImportStatus status;

  /// Non-null when [status] is [DtzImportStatus.error] due to a parse failure.
  final String? errorReason;
}

/// Aggregate analysis for a batch of user-selected DTZ + ZIP files.
class DtzUserImportAnalysis {
  const DtzUserImportAnalysis({
    required this.packages,
    required this.orphanZipNames,
  });

  final List<DtzImportPackageAnalysis> packages;

  /// ZIP names that were selected but no DTZ was provided in the batch.
  final List<String> orphanZipNames;

  bool get hasImportable => packages.any(
    (DtzImportPackageAnalysis p) =>
        p.status == DtzImportStatus.ok || p.status == DtzImportStatus.warning,
  );
}

class DtzUserImportCommitResult {
  const DtzUserImportCommitResult({
    required this.importedDtzCount,
    required this.extractedFileCount,
    required this.failures,
  });

  final int importedDtzCount;
  final int extractedFileCount;
  final List<String> failures;
}

/// Handles user-initiated DTZ + ZIP import with validation and selective extraction.
///
/// Design principles:
/// - Analysis is pure / in-memory (no file-system writes).
/// - Commit writes only the DTZ files and the media files actually referenced
///   by the committed packages – no orphan content from ZIPs ends up on disk.
class DtzUserImportService {
  const DtzUserImportService();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Analyzes [dtzFiles] and [zipFiles] without touching the file system.
  /// 
  /// [availableDiaIds] is the set of dia-IDs that are already loaded from DTX
  /// files. DTZ packages that reference unknown dia-IDs will be marked as
  /// error or warning depending on the percentage of missing dia-IDs.
  DtzUserImportAnalysis analyze({
    required Map<String, List<int>> dtzFiles,
    required Map<String, List<int>> zipFiles,
    Set<String> availableDiaIds = const <String>{},
  }) {
    final Set<String> allProvidedFiles = _indexZipEntries(zipFiles);

    final List<DtzImportPackageAnalysis> packages = dtzFiles.entries
        .map(
          (MapEntry<String, List<int>> e) => _analyzeOneDtz(
            e.key,
            e.value,
            allProvidedFiles,
            availableDiaIds,
          ),
        )
        .toList();

    // If no DTZ was supplied the user probably made a mistake; all ZIPs are
    // orphans and no import is possible.
    final List<String> orphanZipNames =
        dtzFiles.isEmpty ? zipFiles.keys.toList() : const <String>[];

    return DtzUserImportAnalysis(
      packages: packages,
      orphanZipNames: orphanZipNames,
    );
  }

  /// Writes [toImport] packages (DTZ + their matched media) into [targetDir].
  ///
  /// Only the media files that the committed packages actually reference are
  /// extracted from the ZIPs.  Extra ZIP entries are discarded.
  Future<DtzUserImportCommitResult> commit({
    required List<DtzImportPackageAnalysis> toImport,
    required Map<String, List<int>> dtzFiles,
    required Map<String, List<int>> zipFiles,
    required Directory targetDir,
  }) async {
    await targetDir.create(recursive: true);

    final Set<String> neededFiles = toImport
        .expand((DtzImportPackageAnalysis p) => p.matchedFiles)
        .toSet();

    int importedDtzCount = 0;
    int extractedFileCount = 0;
    final List<String> failures = <String>[];

    // 1. Copy DTZ files.
    for (final DtzImportPackageAnalysis pkg in toImport) {
      final List<int>? bytes = dtzFiles[pkg.dtzFileName];
      if (bytes == null) continue;
      try {
        final File dtzFile = FileSystemProvider.instance.file(
          '${targetDir.path}/${pkg.dtzFileName}',
        );
        await dtzFile.writeAsBytes(bytes);
        importedDtzCount++;
      } catch (e) {
        failures.add('${pkg.dtzFileName}: $e');
      }
    }

    // 2. Extract only the referenced+matched files from each ZIP.
    for (final MapEntry<String, List<int>> entry in zipFiles.entries) {
      try {
        final Archive archive = ZipDecoder().decodeBytes(entry.value);
        for (final ArchiveFile f in archive) {
          if (!f.isFile) continue;
          final String normalized = f.name.replaceAll('\\', '/');
          if (!_isPathSafe(normalized)) continue;
          if (!neededFiles.contains(normalized)) continue;
          final File outFile = FileSystemProvider.instance.file(
            '${targetDir.path}/$normalized',
          );
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(f.content as List<int>);
          extractedFileCount++;
        }
      } catch (e) {
        failures.add('${entry.key}: $e');
      }
    }

    await FileSystemProvider.persistWebFileSystem();

    return DtzUserImportCommitResult(
      importedDtzCount: importedDtzCount,
      extractedFileCount: extractedFileCount,
      failures: failures,
    );
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Set<String> _indexZipEntries(Map<String, List<int>> zipFiles) {
    final Set<String> provided = <String>{};
    for (final List<int> bytes in zipFiles.values) {
      try {
        final Archive archive = ZipDecoder().decodeBytes(bytes);
        for (final ArchiveFile f in archive) {
          if (!f.isFile) continue;
          final String normalized = f.name.replaceAll('\\', '/');
          if (_isPathSafe(normalized)) {
            provided.add(normalized);
          }
        }
      } catch (_) {
        // Malformed ZIP – silently skip so it shows as providing 0 files.
      }
    }
    return provided;
  }

  DtzImportPackageAnalysis _analyzeOneDtz(
    String fileName,
    List<int> bytes,
    Set<String> allProvidedFiles,
    Set<String> availableDiaIds,
  ) {
    final Set<String> referencedFiles;
    final Set<String> referencedDiaIds;
    try {
      referencedFiles = _extractReferencedFiles(bytes);
      referencedDiaIds = _extractReferencedDiaIds(bytes);
    } catch (e) {
      return DtzImportPackageAnalysis(
        dtzFileName: fileName,
        referencedFiles: const <String>{},
        matchedFiles: const <String>{},
        missingFiles: const <String>{},
        status: DtzImportStatus.error,
        errorReason: e.toString(),
      );
    }

    // Compute media file status (existing logic).
    if (referencedFiles.isEmpty) {
      // No media files, but check for missing dia-IDs.
      if (referencedDiaIds.isNotEmpty &&
          !referencedDiaIds.every((String id) => availableDiaIds.contains(id))) {
        final Set<String> missing = referencedDiaIds
            .where((String id) => !availableDiaIds.contains(id))
            .toSet();
        final double ratio = missing.length / referencedDiaIds.length;
        final DtzImportStatus status = ratio < 0.05
            ? DtzImportStatus.warning
            : DtzImportStatus.error;
        return DtzImportPackageAnalysis(
          dtzFileName: fileName,
          referencedFiles: const <String>{},
          matchedFiles: const <String>{},
          missingFiles: const <String>{},
          status: status,
          errorReason: 'Missing dia-IDs: ${missing.toList().join(", ")}',
        );
      }
      return DtzImportPackageAnalysis(
        dtzFileName: fileName,
        referencedFiles: const <String>{},
        matchedFiles: const <String>{},
        missingFiles: const <String>{},
        status: DtzImportStatus.ok,
      );
    }

    final Set<String> matched = referencedFiles.intersection(allProvidedFiles);
    final Set<String> missing = referencedFiles.difference(allProvidedFiles);

    DtzImportStatus status;
    if (missing.isEmpty) {
      status = DtzImportStatus.ok;
    } else {
      final double ratio = missing.length / referencedFiles.length;
      status = ratio < 0.05 ? DtzImportStatus.warning : DtzImportStatus.error;
    }

    // Check dia-ID availability (elevate severity if media is OK but dia-IDs are not).
    if (referencedDiaIds.isNotEmpty &&
        !referencedDiaIds.every((String id) => availableDiaIds.contains(id))) {
      final Set<String> missingDiaIds = referencedDiaIds
          .where((String id) => !availableDiaIds.contains(id))
          .toSet();
      final double diaRatio = missingDiaIds.length / referencedDiaIds.length;
      final DtzImportStatus diaStatus = diaRatio < 0.05
          ? DtzImportStatus.warning
          : DtzImportStatus.error;
      // Use the worse status.
      if (diaStatus == DtzImportStatus.error) {
        status = DtzImportStatus.error;
      } else if (diaStatus == DtzImportStatus.warning &&
          status != DtzImportStatus.error) {
        status = DtzImportStatus.warning;
      }
      // Append dia-ID info to error reason if there's a problem.
      if (status != DtzImportStatus.ok) {
        final String diaInfo =
            'Missing dia-IDs: ${missingDiaIds.toList().take(3).join(", ")}'
            '${missingDiaIds.length > 3 ? " (+${missingDiaIds.length - 3} more)" : ""}';
        return DtzImportPackageAnalysis(
          dtzFileName: fileName,
          referencedFiles: referencedFiles,
          matchedFiles: matched,
          missingFiles: missing,
          status: status,
          errorReason: diaInfo,
        );
      }
    }

    return DtzImportPackageAnalysis(
      dtzFileName: fileName,
      referencedFiles: referencedFiles,
      matchedFiles: matched,
      missingFiles: missing,
      status: status,
    );
  }

  /// Parses a DTZ byte sequence and returns all referenced media paths
  /// relative to the DTZs/ root.
  Set<String> _extractReferencedFiles(List<int> bytes) {
    final String content = utf8.decode(bytes, allowMalformed: true);
    final List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
    String baseDir = '';
    final Set<String> refs = <String>{};

    for (final String raw in lines) {
      if (raw.isEmpty) continue;
      final String prefix = raw[0];
      final String rest = raw.substring(1).trim();

      if (prefix == 'b' || prefix == 'B') {
        baseDir = rest.replaceAll('\\', '/');
        if (baseDir.endsWith('/')) {
          baseDir = baseDir.substring(0, baseDir.length - 1);
        }
        continue;
      }

      // f/F = image, z/Z = sound – both are media references.
      if (prefix == 'f' || prefix == 'F' || prefix == 'z' || prefix == 'Z') {
        final int space = rest.indexOf(' ');
        if (space <= 0) continue;
        final String value =
            rest.substring(space + 1).trim().replaceAll('\\', '/');
        if (value.isEmpty) continue;
        final String full =
            baseDir.isEmpty ? value : '$baseDir/$value';
        refs.add(full);
      }
    }
    return refs;
  }

  /// Parses a DTZ byte sequence and returns all referenced dia-IDs.
  Set<String> _extractReferencedDiaIds(List<int> bytes) {
    final String content = utf8.decode(bytes, allowMalformed: true);
    final List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
    final Set<String> diaIds = <String>{};

    for (final String raw in lines) {
      if (raw.isEmpty) continue;
      final String prefix = raw[0];
      final String rest = raw.substring(1).trim();

      // f/F, z/Z, i/I lines all have diaId as first token.
      if (prefix == 'f' ||
          prefix == 'F' ||
          prefix == 'z' ||
          prefix == 'Z' ||
          prefix == 'i' ||
          prefix == 'I') {
        final int space = rest.indexOf(' ');
        if (space <= 0) continue;
        final String diaId = rest.substring(0, space).trim();
        if (diaId.isNotEmpty) {
          diaIds.add(diaId);
        }
      }
    }
    return diaIds;
  }

  bool _isPathSafe(String path) =>
      !path.startsWith('/') &&
      !path.startsWith('../') &&
      !path.contains('/../');
}
