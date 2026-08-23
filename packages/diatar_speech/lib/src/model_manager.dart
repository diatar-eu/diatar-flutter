import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String _kModelDirName =
    'sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-560ms-int8-2026-06-11';
const String _kModelDownloadUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$_kModelDirName.tar.bz2';

const List<String> _kRequiredFiles = <String>[
  'encoder.int8.onnx',
  'decoder.int8.onnx',
  'joiner.int8.onnx',
  'tokens.txt',
];

class ModelManager {
  Future<Directory> get _modelsDir async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory modelsDir = Directory(p.join(supportDir.path, 'models'));
    if (!modelsDir.existsSync()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<String> get modelDirPath async {
    final Directory dir = await _modelsDir;
    return p.join(dir.path, _kModelDirName);
  }

  Future<bool> isModelReady() async {
    final String dirPath = await modelDirPath;
    final Directory dir = Directory(dirPath);
    if (!dir.existsSync()) return false;
    for (final String file in _kRequiredFiles) {
      if (!File(p.join(dirPath, file)).existsSync()) return false;
    }
    return true;
  }

  Future<bool> debugCheckModel() async {
    final String dirPath = await modelDirPath;
    final Directory dir = Directory(dirPath);
    debugPrint('[Model] Dir: $dirPath');
    debugPrint('[Model] Dir exists: ${dir.existsSync()}');
    if (dir.existsSync()) {
      final List<String> contents = dir
          .listSync()
          .map((FileSystemEntity e) => p.basename(e.path))
          .toList();
      debugPrint('[Model] Contents: $contents');
      for (final String file in _kRequiredFiles) {
        final bool exists = File(p.join(dirPath, file)).existsSync();
        debugPrint('[Model]   $file: $exists');
      }
    }
    return isModelReady();
  }

  Future<String> getModelPath() async {
    if (!await isModelReady()) {
      throw StateError(
        'Model not downloaded. Call downloadModel() first.',
      );
    }
    return modelDirPath;
  }

  Future<void> downloadModel({
    void Function(double progress)? onProgress,
    Future<bool> Function()? onCancel,
  }) async {
    final String dirPath = await modelDirPath;

    if (await isModelReady()) {
      onProgress?.call(1.0);
      return;
    }

    final Directory modelsBase = await _modelsDir;
    final String tempPath = p.join(modelsBase.path, '${_kModelDirName}.tmp');
    final Directory tempDir = Directory(tempPath);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final String archivePath = p.join(tempPath, 'model.tar.bz2');

    try {
      final http.Client client = http.Client();
      final http.StreamedResponse response = await client.send(
        http.Request('GET', Uri.parse(_kModelDownloadUrl)),
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
        );
      }

      final int? totalBytes = response.contentLength;
      int receivedBytes = 0;

      final IOSink sink = File(archivePath).openWrite();
      final Completer<void> completer = Completer<void>();
      response.stream.listen(
        (List<int> chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes != null && totalBytes > 0) {
            onProgress?.call(receivedBytes / totalBytes * 0.9);
          }
        },
        onDone: () async {
          await sink.close();
          completer.complete();
        },
        onError: (Object error) {
          completer.completeError(error);
        },
      );
      await completer.future;
      client.close();

      onProgress?.call(0.9);

      await extractFileToDisk(archivePath, tempPath);

      final Directory finalDir = Directory(dirPath);
      if (finalDir.existsSync()) {
        await finalDir.delete(recursive: true);
      }

      final Directory extractedDir = Directory(p.join(tempPath, _kModelDirName));
      if (extractedDir.existsSync()) {
        await extractedDir.rename(dirPath);
      } else {
        // Archive may extract files directly into tempPath (no top-level dir).
        // Move all non-archive files into the target dir.
        await finalDir.create(recursive: true);
        final List<FileSystemEntity> items = tempDir
            .listSync()
            .where((FileSystemEntity e) => !e.path.endsWith('.tar.bz2'))
            .toList();
        for (final FileSystemEntity item in items) {
          final String destPath = p.join(dirPath, p.basename(item.path));
          if (item is File) {
            await item.rename(destPath);
          } else if (item is Directory) {
            await item.rename(destPath);
          }
        }
        if (!await isModelReady()) {
          throw Exception(
            'Archive extracted but required files not found in $dirPath',
          );
        }
      }

      onProgress?.call(1.0);
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
