import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ExternalCommandService {
  const ExternalCommandService();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> run(String command) async {
    if (!isSupported || command.trim().isEmpty) {
      return;
    }
    await Process.start(
      command,
      const <String>[],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
  }

  Future<ExternalCommandTestResult> test(String command) async {
    final Process process = await Process.start(
      command,
      const <String>[],
      runInShell: true,
    );
    final Future<String> errorOutput = process.stderr
        .transform(utf8.decoder)
        .join();
    unawaited(process.stdout.drain<void>());
    final int? exitCode = await process.exitCode
        .then<int?>((int value) => value)
        .timeout(const Duration(seconds: 2), onTimeout: () => null);

    return ExternalCommandTestResult(
      exitCode: exitCode,
      errorOutput: exitCode == null ? '' : await errorOutput,
    );
  }
}

class ExternalCommandTestResult {
  const ExternalCommandTestResult({
    required this.exitCode,
    required this.errorOutput,
  });

  final int? exitCode;
  final String errorOutput;

  bool get succeeded => exitCode == null || exitCode == 0;
}
