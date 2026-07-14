import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

export 'package:file/file.dart' show Directory, File, FileSystemEntity, FileSystem;

/// A provider that returns a [FileSystem] implementation based on the platform.
class FileSystemProvider {
  static final FileSystem _local = LocalFileSystem();
  static final MemoryFileSystem _memory = MemoryFileSystem();
  static const String _hiveBoxName = 'diatar_web_fs';

  /// Returns the appropriate [FileSystem] for the current platform.
  static FileSystem get instance {
    if (kIsWeb) {
      return _memory;
    }
    return _local;
  }

  /// Initializes the web file system by loading stored files from Hive.
  /// This should be called during app startup.
  static Future<void> init() async {
    if (!kIsWeb) return;

    try {
      final box = await Hive.openBox(_hiveBoxName);
      final Map<String, List<int>> files = Map<String, List<int>>.from(box.toMap());
      
      for (final entry in files.entries) {
        final file = _memory.file(entry.key);
        final dir = file.parent;
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        await file.writeAsBytes(entry.value);
      }
    } catch (e) {
      debugPrint('Error initializing WebFileSystem: $e');
    }
  }

  /// Persists the current state of the web file system to Hive.
  static Future<void> persistWebFileSystem() async {
    if (!kIsWeb) return;

    try {
      final box = await Hive.openBox(_hiveBoxName);
      final Map<String, List<int>> files = {};
      
      // We need to traverse the memory file system and save all files.
      // This is a simplified approach.
      final List<FileSystemEntity> entities = _memory.directory('/').listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          files[entity.path] = await entity.readAsBytes();
        }
      }
      
      await box.clear();
      await box.putAll(files);
    } catch (e) {
      debugPrint('Error persisting WebFileSystem: $e');
    }
  }
}