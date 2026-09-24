import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/folder_selection.dart';
import '../models/sync_plan.dart';
import '../models/sync_progress.dart';
import '../models/sync_result.dart';
import 'sync_backend.dart';

/// Shared synchronization backend for desktop filesystems.
///
/// Folder selection is provided by Flutter's platform plugin. Planning and
/// execution are pure Dart, so Windows, Linux and macOS use identical rules.
class FileSystemSyncBackend implements SyncBackend {
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  _PreparedSync? _prepared;

  @override
  String get localFolderName => 'Számítógép';

  @override
  bool get supportsUsbEject => false;

  @override
  Stream<SyncProgress> get progress => _progressController.stream;

  Future<File> get _settingsFile async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(
      path.join(supportDirectory.path, 'diatar_sync_folders.json'),
    );
  }

  @override
  Future<FolderSelection?> selectLocalFolder() =>
      _selectFolder('localFolder');

  @override
  Future<FolderSelection?> selectUsbFolder() =>
      _selectFolder('usbFolder');

  Future<FolderSelection?> _selectFolder(String settingsKey) async {
    final selectedPath = await getDirectoryPath(
      confirmButtonText: 'Mappa kiválasztása',
    );
    if (selectedPath == null) {
      return null;
    }

    final selection = FolderSelection(
      value: selectedPath,
      displayName: selectedPath,
    );
    await _saveFolder(settingsKey, selection);
    return selection;
  }

  @override
  Future<FolderSelection?> loadLocalFolder() => _loadFolder('localFolder');

  @override
  Future<FolderSelection?> loadUsbFolder() => _loadFolder('usbFolder');

  @override
  Future<bool> hasSyncState({
    required String source,
    required String target,
  }) async => true;

  Future<Map<String, dynamic>> _readSettings() async {
    try {
      final file = await _settingsFile;
      if (!await file.exists()) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveFolder(
    String key,
    FolderSelection selection,
  ) async {
    final settings = await _readSettings();
    settings[key] = <String, String>{
      'value': selection.value,
      'displayName': selection.displayName,
    };

    final file = await _settingsFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent(' ').convert(settings),
      flush: true,
    );
  }

  Future<FolderSelection?> _loadFolder(String key) async {
    final item = (await _readSettings())[key];
    if (item is! Map) {
      return null;
    }

    final value = item['value'];
    final displayName = item['displayName'];
    if (value is! String || value.isEmpty) {
      return null;
    }

    return FolderSelection(
      value: value,
      displayName: displayName is String && displayName.isNotEmpty
          ? displayName
          : value,
    );
  }

  @override
  Future<SyncPlan> prepare({
    required String source,
    required String target,
    required bool mirrorMode,
    required bool dryRun,
  }) async {
    _prepared = null;
    _progressController.add(const SyncProgress(
      percent: 0,
      processedFiles: 0,
      totalFiles: 0,
      currentFile: '',
      status: 'Felmérés...',
    ));

    final sourceRoot = _normalizedRoot(source);
    final targetRoot = _normalizedRoot(target);
    if (_pathsOverlap(sourceRoot, targetRoot)) {
      throw Exception(
        'A forrás és a cél mappa nem lehet azonos, '
        'és egyik sem lehet a másik almappája.',
      );
    }
    if (!await Directory(sourceRoot).exists()) {
      throw Exception('A forrás mappa nem létezik: $sourceRoot');
    }

    final sourceFiles = await _fileMap(sourceRoot);
    final targetFiles = await _fileMap(targetRoot);
    final copies = <_CopyOperation>[];
    final deletions = <_DeleteOperation>[];
    var newFiles = 0;
    var updatedFiles = 0;

    for (final entry in sourceFiles.entries) {
      final targetFile = targetFiles[entry.key];
      if (targetFile == null) {
        newFiles++;
        copies.add(_CopyOperation(
          entry.value,
          entry.value.relativePath,
          isNew: true,
        ));
      } else if (_needsCopy(entry.value, targetFile, mirrorMode)) {
        updatedFiles++;
        copies.add(_CopyOperation(
          entry.value,
          entry.value.relativePath,
          isNew: false,
        ));
      }
    }

    if (mirrorMode) {
      for (final entry in targetFiles.entries) {
        if (!sourceFiles.containsKey(entry.key)) {
          deletions.add(_DeleteOperation(entry.value));
        }
      }
    }

    final plan = SyncPlan(
      copyCount: copies.length,
      deleteCount: deletions.length,
      newFileCount: newFiles,
      updatedFileCount: updatedFiles,
      mirrorMode: mirrorMode,
      dryRun: dryRun,
    );
    _prepared = _PreparedSync(
      plan: plan,
      targetRoot: targetRoot,
      sourceFileCount: sourceFiles.length,
      copies: copies,
      deletions: deletions,
    );

    _progressController.add(SyncProgress(
      percent: 100,
      processedFiles: sourceFiles.length,
      totalFiles: sourceFiles.length,
      currentFile: '',
      status: 'Felmérés kész.',
    ));
    return plan;
  }

  @override
  Future<SyncResult> execute({
    required SyncPlan plan,
    required bool allowDelete,
  }) async {
    final prepared = _prepared;
    if (prepared == null || !identical(plan, prepared.plan)) {
      throw Exception('Nincs végrehajtható szinkronterv.');
    }
    if (plan.mirrorMode &&
        !plan.dryRun &&
        plan.deleteCount > 0 &&
        !allowDelete) {
      throw Exception(
        'A szinkronizálás ${plan.deleteCount} fájl törlését igényli.',
      );
    }

    try {
      if (plan.dryRun) {
        return SyncResult(
          newFiles: plan.newFileCount,
          updatedFiles: plan.updatedFileCount,
          deletedFiles: plan.deleteCount,
          unchangedFiles: prepared.unchangedFiles,
          errors: const <String>[],
          dryRun: true,
        );
      }

      await Directory(prepared.targetRoot).create(recursive: true);
      final errors = <String>[];
      var newFiles = 0;
      var updatedFiles = 0;
      var deleted = 0;
      var processed = 0;
      final total = prepared.copies.length + prepared.deletions.length;

      for (final operation in prepared.copies) {
        try {
          final destination = File(
            path.join(prepared.targetRoot, operation.relativePath),
          );
          await destination.parent.create(recursive: true);
          await operation.source.file.copy(destination.path);
          await destination.setLastModified(operation.source.modified);
          if (operation.isNew) {
            newFiles++;
          } else {
            updatedFiles++;
          }
        } catch (error) {
          errors.add('${operation.relativePath}: $error');
        }
        processed++;
        _reportProgress(processed, total, operation.relativePath);
      }

      for (final operation in prepared.deletions) {
        try {
          await operation.target.file.delete();
          deleted++;
        } catch (error) {
          errors.add('${operation.target.relativePath}: $error');
        }
        processed++;
        _reportProgress(processed, total, operation.target.relativePath);
      }

      if (plan.mirrorMode) {
        await _removeEmptyDirectories(prepared.targetRoot);
      }

      _progressController.add(SyncProgress(
        percent: 100,
        processedFiles: total,
        totalFiles: total,
        currentFile: '',
        status: errors.isEmpty
            ? 'Szinkronizálás kész.'
            : 'Szinkronizálás kész, hibákkal.',
      ));

      return SyncResult(
        newFiles: newFiles,
        updatedFiles: updatedFiles,
        deletedFiles: deleted,
        unchangedFiles: prepared.unchangedFiles,
        errors: errors,
        dryRun: false,
      );
    } finally {
      _prepared = null;
    }
  }

  void _reportProgress(int processed, int total, String currentFile) {
    _progressController.add(SyncProgress(
      percent: total == 0 ? 100 : ((processed * 100) ~/ total),
      processedFiles: processed,
      totalFiles: total,
      currentFile: currentFile,
      status: 'Szinkronizálás...',
    ));
  }

  Future<Map<String, _FileInfo>> _fileMap(String root) async {
    final directory = Directory(root);
    if (!await directory.exists()) {
      return <String, _FileInfo>{};
    }

    final result = <String, _FileInfo>{};
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final relativePath = path.relative(entity.path, from: root);
      final stat = await entity.stat();
      final key = Platform.isWindows ? relativePath.toLowerCase() : relativePath;
      result[key] = _FileInfo(
        file: entity,
        relativePath: relativePath,
        length: stat.size,
        modified: stat.modified.toUtc(),
      );
    }
    return result;
  }

  bool _needsCopy(_FileInfo source, _FileInfo target, bool mirrorMode) {
    final difference = source.modified.difference(target.modified).inMilliseconds;
    if (!mirrorMode && difference < -2000) {
      return false;
    }
    return source.length != target.length || difference.abs() > 2000;
  }

  String _normalizedRoot(String value) => path.normalize(path.absolute(value));

  bool _pathsOverlap(String first, String second) {
    final comparableFirst = Platform.isWindows ? first.toLowerCase() : first;
    final comparableSecond = Platform.isWindows ? second.toLowerCase() : second;
    return comparableFirst == comparableSecond ||
        path.isWithin(comparableFirst, comparableSecond) ||
        path.isWithin(comparableSecond, comparableFirst);
  }

  Future<void> _removeEmptyDirectories(String root) async {
    final directories = await Directory(root)
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in directories) {
      try {
        if (!await directory.list(followLinks: false).isEmpty) {
          continue;
        }
        await directory.delete();
      } catch (_) {
        // Empty-directory cleanup is secondary to file synchronization.
      }
    }
  }

  @override
  Future<bool> ejectUsb() async => false;

  void dispose() {
    _progressController.close();
  }
}

class _PreparedSync {
  const _PreparedSync({
    required this.plan,
    required this.targetRoot,
    required this.sourceFileCount,
    required this.copies,
    required this.deletions,
  });

  final SyncPlan plan;
  final String targetRoot;
  final int sourceFileCount;
  final List<_CopyOperation> copies;
  final List<_DeleteOperation> deletions;

  int get unchangedFiles =>
      sourceFileCount - plan.newFileCount - plan.updatedFileCount;
}

class _CopyOperation {
  const _CopyOperation(
    this.source,
    this.relativePath, {
    required this.isNew,
  });

  final _FileInfo source;
  final String relativePath;
  final bool isNew;
}

class _DeleteOperation {
  const _DeleteOperation(this.target);

  final _FileInfo target;
}

class _FileInfo {
  const _FileInfo({
    required this.file,
    required this.relativePath,
    required this.length,
    required this.modified,
  });

  final File file;
  final String relativePath;
  final int length;
  final DateTime modified;
}
