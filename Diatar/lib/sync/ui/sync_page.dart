import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../src/l10n/l10n.dart';
import '../models/folder_selection.dart';
import '../models/sync_plan.dart';
import '../models/sync_progress.dart';
import '../models/sync_result.dart';
import '../platform/backend_factory.dart';
import '../platform/sync_backend.dart';

enum SyncDirection {
  localToUsb,
  usbToLocal,
}

class SyncPage extends StatefulWidget {
  const SyncPage({
    super.key,
    this.backend,
  });

  final SyncBackend? backend;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  late final SyncBackend _backend;
  bool _initialized = false;

  StreamSubscription<SyncProgress>?
      _progressSubscription;

  FolderSelection? _localFolder;
  FolderSelection? _usbFolder;

  SyncDirection _direction =
      SyncDirection.localToUsb;

  bool _mirrorMode = true;
  bool _dryRun = false;
  bool _syncRunning = false;

  int _percent = 0;
  int _processedFiles = 0;
  int _totalFiles = 0;

  String _statusText = '';
  String _currentFile = '';
  String _resultText = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _backend =
        widget.backend ??
        createSyncBackend(context.l10n);
    _statusText = context.l10n.syncWaiting;
    _progressSubscription =
        _backend.progress.listen(
      _handleProgress,
    );
    unawaited(_loadSavedFolders());
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  String get _localFolderTitle =>
      context.l10n.syncFolderTitle(
        _backend.localFolderName,
      );

  String get _localToUsbTitle =>
      context.l10n.syncDirectionLocalToUsb(
        _backend.localFolderName,
      );

  String get _usbToLocalTitle =>
      context.l10n.syncDirectionUsbToLocal(
        _backend.localFolderName,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncButton),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 720,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.syncTitle,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    _localFolderTitle,
                  ),

                  const SizedBox(height: 5),

                  _folderText(
                    _localFolder,
                  ),

                  const SizedBox(height: 8),

                  FilledButton(
                    onPressed:
                        _syncRunning
                            ? null
                            : _selectLocalFolder,
                    child: Text(
                      l10n
                          .syncSelectFolderAction(
                            _localFolderTitle,
                          )
                          .toUpperCase(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionTitle(
                    l10n.syncUsbFolderTitle,
                  ),

                  const SizedBox(height: 5),

                  _folderText(
                    _usbFolder,
                  ),

                  const SizedBox(height: 8),

                  FilledButton(
                    onPressed:
                        _syncRunning
                            ? null
                            : _selectUsbFolder,
                    child: Text(
                      l10n
                          .syncSelectFolderAction(
                            l10n.syncUsbFolderTitle,
                          )
                          .toUpperCase(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  _sectionTitle(
                    l10n.syncDirectionTitle,
                  ),

                  RadioGroup<SyncDirection>(
                    groupValue: _direction,
                    onChanged: (value) {
                      if (
                          value != null &&
                          !_syncRunning
                      ) {
                        setState(() {
                          _direction = value;
                        });
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<SyncDirection>(
                          contentPadding:
                              EdgeInsets.zero,
                          title: Text(
                            _localToUsbTitle,
                          ),
                          value:
                              SyncDirection
                                  .localToUsb,
                          enabled:
                              !_syncRunning,
                        ),

                        RadioListTile<SyncDirection>(
                          contentPadding:
                              EdgeInsets.zero,
                          title: Text(
                            _usbToLocalTitle,
                          ),
                          value:
                              SyncDirection
                                  .usbToLocal,
                          enabled:
                              !_syncRunning,
                        ),
                      ],
                    ),
                  ),

                  CheckboxListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    controlAffinity:
                        ListTileControlAffinity
                            .leading,
                    title: Text(
                      l10n.syncMirrorMode,
                    ),
                    value: _mirrorMode,
                    onChanged:
                        _syncRunning
                            ? null
                            : (value) {
                                setState(() {
                                  _mirrorMode =
                                      value ??
                                      false;
                                });
                              },
                  ),

                  CheckboxListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    controlAffinity:
                        ListTileControlAffinity
                            .leading,
                    title: Text(
                      l10n.syncDryRun,
                    ),
                    value: _dryRun,
                    onChanged:
                        _syncRunning
                            ? null
                            : (value) {
                                setState(() {
                                  _dryRun =
                                      value ??
                                      false;
                                });
                              },
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 20),

                  Text(
                    _statusText,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  if (_currentFile.isNotEmpty) ...[
                    const SizedBox(height: 5),

                    Text(
                      _currentFile,
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  Text(
                    l10n.syncPercent(
                      _percent,
                    ),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  if (_totalFiles > 0)
                    Text(
                      l10n.syncFilesProgress(
                        _processedFiles,
                        _totalFiles,
                      ),
                    )
                  else if (_processedFiles > 0)
                    Text(
                      l10n.syncFilesScanned(
                        _processedFiles,
                      ),
                    ),

                  const SizedBox(height: 8),

                  LinearProgressIndicator(
                    value:
                        _percent / 100,
                    minHeight: 12,
                  ),

                  if (_resultText.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    Text(
                      _resultText,
                    ),
                  ],

                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed:
                        _syncRunning
                            ? null
                            : _startSync,
                    child: Text(
                      _syncRunning
                          ? l10n.syncStartInProgress
                          : _dryRun
                              ? l10n.syncStartDryRun
                              : l10n.syncStart,
                    ),
                  ),

                  if (_backend.supportsUsbEject) ...[
                    const SizedBox(height: 12),

                    OutlinedButton(
                      onPressed:
                          _syncRunning
                              ? null
                              : _ejectUsb,
                      child: Text(
                        l10n.syncEjectUsb,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String text,
  ) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight:
            FontWeight.bold,
      ),
    );
  }

  Widget _folderText(
    FolderSelection? folder,
  ) {
    return Text(
      folder?.displayName ??
          context.l10n.syncNotSelected,
      style: TextStyle(
        fontSize: 14,
        color:
            folder == null
                ? Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                : null,
      ),
    );
  }

  void _handleProgress(
    SyncProgress progress,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _percent = progress.percent;
      _processedFiles =
          progress.processedFiles;
      _totalFiles =
          progress.totalFiles;
      _currentFile =
          progress.currentFile;
      _statusText =
          _localizeSyncText(
            progress.status,
          );
    });
  }

  Future<void> _loadSavedFolders() async {
    try {
      final local =
          await _backend.loadLocalFolder();

      final usb =
          await _backend.loadUsbFolder();

      if (!mounted) {
        return;
      }

      setState(() {
        _localFolder = local;
        _usbFolder = usb;
      });
    } catch (_) {
      // A mentett beállítás hiánya vagy hibája
      // nem akadályozza az alkalmazás indulását.
    }
  }

  Future<void> _selectLocalFolder() async {
    try {
      final folder =
          await _backend.selectLocalFolder();

      if (
          folder == null ||
          !mounted
      ) {
        return;
      }

      setState(() {
        _localFolder = folder;
        _resetStatus();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText =
              context.l10n
                  .syncSelectFolderFailed;
        _resultText =
            _errorText(e);
      });
    }
  }

  Future<void> _selectUsbFolder() async {
    try {
      final folder =
          await _backend.selectUsbFolder();

      if (
          folder == null ||
          !mounted
      ) {
        return;
      }

      setState(() {
        _usbFolder = folder;
        _resetStatus();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText =
            context.l10n
                .syncSelectUsbFolderFailed;
        _resultText =
            _errorText(e);
      });
    }
  }

  Future<void> _startSync() async {
    final local =
        _localFolder;

    final usb =
        _usbFolder;

    if (local == null) {
      setState(() {
        _statusText =
            context.l10n
                .syncMissingLocalFolder;
      });
      return;
    }

    if (usb == null) {
      setState(() {
        _statusText =
            context.l10n
                .syncMissingUsbFolder;
      });
      return;
    }

    final source =
        _direction ==
                SyncDirection.localToUsb
            ? local.value
            : usb.value;

    final target =
        _direction ==
                SyncDirection.localToUsb
            ? usb.value
            : local.value;

    setState(() {
      _syncRunning = true;
      _percent = 0;
      _processedFiles = 0;
      _totalFiles = 0;
      _currentFile = '';
      _statusText =
          context.l10n.syncPreparing;
      _resultText = '';
    });

    try {
      final hasState =
          await _backend.hasSyncState(
        source: source,
        target: target,
      );

      if (
          !hasState &&
          !_dryRun
      ) {
        if (!mounted) {
          return;
        }

        final continueFirstSync =
            await _confirmFirstSync();

        if (!continueFirstSync) {
          if (!mounted) {
            return;
          }

          setState(() {
            _syncRunning = false;
            _statusText =
               context.l10n
                   .syncCancelled;
          });

          return;
        }
      }

      final plan =
          await _backend.prepare(
        source: source,
        target: target,
        mirrorMode: _mirrorMode,
        dryRun: _dryRun,
      );

      if (!mounted) {
        return;
      }

      var allowDelete = false;

      if (
          plan.mirrorMode &&
          !plan.dryRun &&
          plan.deleteCount > 0
      ) {
        final confirmed =
            await _confirmDeletion(
          plan,
        );

        if (!confirmed) {
          if (!mounted) {
            return;
          }

          setState(() {
            _syncRunning = false;
            _statusText =
                context.l10n
                    .syncCancelled;
            _resultText =
                context.l10n
                    .syncDeleteNotAllowed;
          });

          return;
        }

        allowDelete = true;
      }

      final result =
          await _backend.execute(
        plan: plan,
        allowDelete: allowDelete,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _syncRunning = false;
        _percent = 100;
        _currentFile = '';

        _statusText =
            result.errors.isEmpty
                ? result.dryRun
                    ? context.l10n
                        .syncDryRunComplete
                    : context.l10n
                        .syncComplete
                : context.l10n
                    .syncCompleteWithErrors;

        _resultText =
            _makeResultText(result);
      });

    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _syncRunning = false;
        _statusText =
            context.l10n.syncFailed;
        _resultText =
            _errorText(e);
      });
    }
  }

  Future<bool> _confirmFirstSync() async {
    final result =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.l10n.syncFirstTitle,
          ),
          content: Text(
            context.l10n.syncFirstMessage,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },
              child: Text(
                context.l10n.cancel,
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },
              child: Text(
                context.l10n.syncContinue,
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _confirmDeletion(
    SyncPlan plan,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.l10n.syncDeleteConfirmTitle,
          ),
          content: Text(
            context.l10n.syncDeleteConfirmMessage(
              plan.deleteCount,
              plan.copyCount,
              plan.newFileCount,
              plan.updatedFileCount,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },
              child: Text(
                context.l10n.cancel,
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },
              child: Text(
                context.l10n.syncDeleteAndContinue,
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String _makeResultText(
    SyncResult result,
  ) {
    final buffer =
        StringBuffer();

    if (result.dryRun) {
      buffer.writeln(
        context.l10n.syncDryRunSummary,
      );
      buffer.writeln();
    }

    buffer.writeln(
      context.l10n.syncResultNewFiles(
        result.newFiles,
      ),
    );

    buffer.writeln(
      context.l10n.syncResultUpdatedFiles(
        result.updatedFiles,
      ),
    );

    buffer.writeln(
      context.l10n.syncResultDeletedFiles(
        result.deletedFiles,
      ),
    );

    buffer.writeln(
      context.l10n.syncResultUnchangedFiles(
        result.unchangedFiles,
      ),
    );

    if (result.errors.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        context.l10n.syncResultErrors(
          result.errors.length,
        ),
      );

      for (final error in result.errors) {
        buffer.writeln(
          '• ${_localizeSyncText(error)}',
        );
      }
    }

    return buffer.toString().trim();
  }

  String _errorText(
    Object error,
  ) {
    if (error is PlatformException) {
      return _localizeSyncText(
        error.message ??
            error.code,
      );
    }

    return _localizeSyncText(
      error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        ),
    );
  }

  void _resetStatus() {
    _percent = 0;
    _processedFiles = 0;
    _totalFiles = 0;
    _currentFile = '';
    _statusText = context.l10n.syncWaiting;
    _resultText = '';
  }

  Future<void> _ejectUsb() async {
    final success =
        await _backend.ejectUsb();

    if (!mounted) {
      return;
    }

    setState(() {
      _statusText =
          success
              ? context.l10n
                  .syncEjectStarted
              : context.l10n
                  .syncEjectFailed;
    });
  }

  String _localizeSyncText(
    String text,
  ) {
    final l10n = context.l10n;
    switch (text) {
      case '':
        return text;
      case 'Várakozás...':
        return l10n.syncWaiting;
      case 'Felmérés...':
        return l10n.syncScanning;
      case 'Felmérés kész.':
        return l10n.syncScanComplete;
      case 'Forrás vizsgálata...':
        return l10n.syncSourceScanning;
      case 'Cél vizsgálata...':
        return l10n.syncTargetScanning;
      case 'Változások összehasonlítása...':
        return l10n.syncComparingChanges;
      case 'Nincs szinkronizálandó változás.':
        return l10n.syncNoChanges;
      case 'Próbaüzem – új fájl':
        return l10n.syncDryRunNewFile;
      case 'Próbaüzem – frissítendő':
        return l10n.syncDryRunUpdateFile;
      case 'Új fájl másolása':
        return l10n.syncCopyingNewFile;
      case 'Fájl frissítése':
        return l10n.syncUpdatingFile;
      case 'Hiba – folytatás...':
        return l10n.syncContinueAfterError;
      case 'Próbaüzem – törlendő':
        return l10n.syncDryRunDeleteFile;
      case 'Felesleges fájl törlése':
        return l10n.syncDeletingExtraFile;
      case 'Üres mappák ellenőrzése...':
        return l10n.syncCheckingEmptyFolders;
      case 'Próbaüzem kész.':
        return l10n.syncDryRunComplete;
      case 'Szinkronizálás kész.':
        return l10n.syncComplete;
      case 'Szinkronizálás kész, hibákkal.':
        return l10n.syncCompleteWithErrors;
      case 'A forrásmappa nem nyitható meg.':
        return l10n.syncSourceFolderOpenFailed;
      case 'A célmappa nem nyitható meg.':
        return l10n.syncTargetFolderOpenFailed;
      case 'A forrásmappa nem létezik.':
        return l10n.syncSourceFolderMissing;
      case 'A célmappa nem létezik.':
        return l10n.syncTargetFolderMissing;
      case 'A forrásmappa már nem érhető el.':
        return l10n.syncSourceFolderUnavailable;
      case 'A célmappa már nem érhető el.':
        return l10n.syncTargetFolderUnavailable;
      case 'A fájl nem törölhető.':
        return l10n.syncFileDeleteFailed;
      case 'A fájl nem olvasható.':
        return l10n.syncFileReadFailed;
      case 'Érvénytelen fájlnév.':
        return l10n.syncInvalidFileName;
      case 'A másolt fájl mérete hibás.':
        return l10n.syncCopiedSizeMismatch;
      case 'törlési hiba':
        return l10n.syncDeleteError;
    }
    const checkingEmptyFoldersPrefix =
        'Üres mappák ellenőrzése: ';
    if (text.startsWith(checkingEmptyFoldersPrefix)) {
      return l10n.syncCheckingEmptyFoldersProgress(
        text.substring(
          checkingEmptyFoldersPrefix.length,
        ),
      );
    }
    const sourceFolderMissingWithPathPrefix =
        'A forrás mappa nem létezik: ';
    if (text.startsWith(sourceFolderMissingWithPathPrefix)) {
      return l10n.syncSourceFolderMissingWithPath(
        text.substring(
          sourceFolderMissingWithPathPrefix.length,
        ),
      );
    }
    const oldTargetDeleteFailedPrefix =
        'A régi célfájl nem törölhető: ';
    if (text.startsWith(oldTargetDeleteFailedPrefix)) {
      return l10n.syncOldTargetDeleteFailed(
        text.substring(
          oldTargetDeleteFailedPrefix.length,
        ),
      );
    }
    const targetFileCreateFailedPrefix =
        'A célfájl nem hozható létre: ';
    if (text.startsWith(targetFileCreateFailedPrefix)) {
      return l10n.syncTargetFileCreateFailed(
        text.substring(
          targetFileCreateFailedPrefix.length,
        ),
      );
    }
    const sourceFileReadFailedPrefix =
        'A forrásfájl nem olvasható: ';
    if (text.startsWith(sourceFileReadFailedPrefix)) {
      return l10n.syncSourceFileReadFailed(
        text.substring(
          sourceFileReadFailedPrefix.length,
        ),
      );
    }
    const targetFileWriteFailedPrefix =
        'A célfájl nem írható: ';
    if (text.startsWith(targetFileWriteFailedPrefix)) {
      return l10n.syncTargetFileWriteFailed(
        text.substring(
          targetFileWriteFailedPrefix.length,
        ),
      );
    }
    const sameSourceTargetPrefix =
        'A forrás és a cél mappa nem lehet azonos.';
    if (text == sameSourceTargetPrefix) {
      return l10n.syncSameSourceTarget;
    }
    const robocopyErrorPrefix =
        'Robocopy hiba, exitcode=';
    if (text.startsWith(robocopyErrorPrefix)) {
      return l10n.syncRobocopyError(
        text.substring(
          robocopyErrorPrefix.length,
        ),
      );
    }
    return text;
  }
}