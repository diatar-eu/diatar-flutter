import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_registry.dart';

class ModelManager {
  Future<Directory> get _modelsDir async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory modelsDir = Directory(p.join(supportDir.path, 'models'));
    if (!modelsDir.existsSync()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<String> modelDirPath(SpeechModelType type) async {
    final SpeechModelInfo info = getSpeechModel(type);
    final Directory dir = await _modelsDir;
    return p.join(dir.path, info.dirName);
  }

  Future<bool> isModelReady(SpeechModelType type) async {
    final SpeechModelInfo info = getSpeechModel(type);
    final String dirPath = await modelDirPath(type);
    final Directory dir = Directory(dirPath);
    if (!dir.existsSync()) return false;
    for (final String file in info.requiredFiles) {
      if (!File(p.join(dirPath, file)).existsSync()) return false;
    }
    return true;
  }

  Future<String> getModelPath(SpeechModelType type) async {
    if (!await isModelReady(type)) {
      throw StateError(
        'Model ${getSpeechModel(type).displayName} not downloaded. '
        'Call downloadModel() first.',
      );
    }
    return modelDirPath(type);
  }

  Future<bool> isVadModelReady() async {
    final Directory dir = await _modelsDir;
    return File(p.join(dir.path, kVadModelFileName)).existsSync();
  }

  Future<String> getVadModelPath() async {
    if (!await isVadModelReady()) {
      throw StateError(
        'VAD model not downloaded. Call downloadVadModel() first.',
      );
    }
    final Directory dir = await _modelsDir;
    return p.join(dir.path, kVadModelFileName);
  }

  Future<void> downloadVadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (await isVadModelReady()) {
      onProgress?.call(1.0);
      return;
    }

    final Directory dir = await _modelsDir;
    final String destPath = p.join(dir.path, '${kVadModelFileName}.tmp');
    final File tempFile = File(destPath);

    try {
      final http.Client client = http.Client();
      final http.StreamedResponse response = await client.send(
        http.Request('GET', Uri.parse(kVadModelUrl)),
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'VAD download failed with status ${response.statusCode}',
        );
      }

      final int? totalBytes = response.contentLength;
      int receivedBytes = 0;

      final IOSink sink = tempFile.openWrite();
      final Completer<void> completer = Completer<void>();
      response.stream.listen(
        (List<int> chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes != null && totalBytes > 0) {
            onProgress?.call(receivedBytes / totalBytes);
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

      await tempFile.rename(p.join(dir.path, kVadModelFileName));
      onProgress?.call(1.0);
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> downloadModel(
    SpeechModelType type, {
    void Function(double progress)? onProgress,
    Future<bool> Function()? onCancel,
  }) async {
    final SpeechModelInfo info = getSpeechModel(type);
    final String dirPath = await modelDirPath(type);

    if (await isModelReady(type)) {
      onProgress?.call(1.0);
      return;
    }

    final Directory modelsBase = await _modelsDir;
    final String tempPath = p.join(modelsBase.path, '${info.dirName}.tmp');
    final Directory tempDir = Directory(tempPath);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final String archivePath = p.join(tempPath, 'model.tar.bz2');

    try {
      final http.Client client = http.Client();
      final http.StreamedResponse response = await client.send(
        http.Request('GET', Uri.parse(info.downloadUrl)),
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

      final Directory extractedDir = Directory(p.join(tempPath, info.dirName));
      if (extractedDir.existsSync()) {
        await extractedDir.rename(dirPath);
      } else {
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
        if (!await isModelReady(type)) {
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

  Future<void> deleteModel(SpeechModelType type) async {
    final String dirPath = await modelDirPath(type);
    final Directory dir = Directory(dirPath);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<List<SpeechModelType>> listDownloadedModels() async {
    final List<SpeechModelType> downloaded = [];
    for (final SpeechModelType type in SpeechModelType.values) {
      if (await isModelReady(type)) {
        downloaded.add(type);
      }
    }
    return downloaded;
  }
}
