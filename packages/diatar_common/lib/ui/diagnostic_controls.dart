import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/diagnostic_log.dart';

class DiagnosticLabels {
  const DiagnosticLabels({
    required this.title,
    required this.hint,
    required this.share,
    required this.save,
    required this.clear,
    required this.cleared,
    required this.error,
    required this.retry,
    required this.empty,
    required this.shareUnavailable,
  });

  final String title;
  final String hint;
  final String share;
  final String save;
  final String clear;
  final String cleared;
  final String error;
  final String retry;
  final String empty;
  final String shareUnavailable;
}

class DiagnosticControls extends StatefulWidget {
  const DiagnosticControls({
    super.key,
    required this.app,
    required this.labels,
    this.log,
    this.sharingAvailable = true,
    this.exportLog,
  });

  final DiagnosticApp app;
  final DiagnosticLabels labels;
  final DiagnosticLog? log;
  final bool sharingAvailable;
  final Future<void> Function(String text, Rect origin)? exportLog;

  @override
  State<DiagnosticControls> createState() => _DiagnosticControlsState();
}

class _DiagnosticControlsState extends State<DiagnosticControls> {
  bool _busy = false;
  bool _actionFailed = false;
  bool _cleared = false;

  DiagnosticLog get _log => widget.log ?? DiagnosticLog.instance;
  bool get _saveToFile =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  Future<void> _run(Future<bool> Function() action) async {
    setState(() {
      _busy = true;
      _actionFailed = false;
      _cleared = false;
    });
    bool success;
    try {
      success = await action();
    } catch (error) {
      // Do not display or persist raw platform errors: they can contain paths.
      debugPrint('Diagnostic log export failed.');
      success = false;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _actionFailed = !success;
      });
    }
  }

  Future<bool> _share(BuildContext buttonContext) async {
    final RenderObject? renderObject = buttonContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      throw StateError('Diagnostic sharing anchor unavailable');
    }
    final Rect origin =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final String text = _log.exportText();
    unawaited(_log.flush());
    if (widget.exportLog case final exportLog?) {
      await exportLog(text, origin);
      return true;
    }
    const String name = 'diatar-diagnostics.txt';
    final XFile file = XFile.fromData(
      utf8.encode(text),
      mimeType: 'text/plain',
      name: name,
    );
    if (_saveToFile) {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(extensions: <String>['txt']),
        ],
      );
      if (location != null) {
        await file.saveTo(location.path);
      }
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[file],
          fileNameOverrides: const <String>[name],
          sharePositionOrigin: origin,
        ),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final DiagnosticLabels labels = widget.labels;
    return AnimatedBuilder(
      animation: _log,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(labels.title),
            subtitle: Text(labels.hint),
            value: _log.enabled,
            onChanged: _busy || !_log.initialized
                ? null
                : (value) => _run(() => _log.setEnabled(value)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed:
                      _busy || !_log.hasEntries || !widget.sharingAvailable
                      ? null
                      : () => _run(() => _share(buttonContext)),
                  icon: Icon(_saveToFile ? Icons.save_alt : Icons.share),
                  label: Text(_saveToFile ? labels.save : labels.share),
                ),
              ),
              TextButton.icon(
                onPressed: _busy || (!_log.hasEntries && !_log.failed)
                    ? null
                    : () => _run(() async {
                        final bool success = await _log.clear();
                        if (mounted && success) {
                          setState(() => _cleared = true);
                        }
                        return success;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: Text(labels.clear),
              ),
              if (_log.failed || _actionFailed)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => _log.initialized
                              ? _log.setEnabled(_log.enabled)
                              : _log.initialize(widget.app),
                        ),
                  child: Text(labels.retry),
                ),
            ],
          ),
          if (!widget.sharingAvailable) Text(labels.shareUnavailable),
          if (_log.failed || _actionFailed)
            Text(
              labels.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_cleared)
            Text(labels.cleared)
          else if (!_log.hasEntries)
            Text(labels.empty),
        ],
      ),
    );
  }
}
