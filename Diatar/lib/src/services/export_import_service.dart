import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';

enum ExistingFilePolicy { overwrite, skip }

enum DiatarArchiveErrorCode { sourceDirectoryMissing, invalidArchive }

class DiatarArchiveException implements Exception {
  const DiatarArchiveException(this.code, [this.details]);

  final DiatarArchiveErrorCode code;
  final Object? details;

  @override
  String toString() {
    final String suffix = details == null ? '' : ': $details';
    return 'DiatarArchiveException(${code.name})$suffix';
  }
}

class DiatarImportPreview {
  const DiatarImportPreview({
    required this.fileCount,
    required this.conflictingFileCount,
  });

  final int fileCount;
  final int conflictingFileCount;
}

class DiatarImportResult {
  const DiatarImportResult({
    required this.importedFileCount,
    required this.skippedFileCount,
    required this.errors,
  });

  final int importedFileCount;
  final int skippedFileCount;
  final List<String> errors;

  bool get isSuccess => errors.isEmpty;
}

typedef DocumentsDirectoryPathProvider = Future<String> Function();
typedef FileSystemPersister = Future<void> Function();

class ExportImportService {
  ExportImportService({
    FileSystem? fileSystem,
    DocumentsDirectoryPathProvider? documentsDirectoryPathProvider,
    FileSystemPersister? persistFileSystem,
  }) : _fileSystem = fileSystem,
       _documentsDirectoryPathProvider =
           documentsDirectoryPathProvider ??
           PathHelper.getDocumentsDirectoryPath,
       _persistFileSystem =
           persistFileSystem ?? FileSystemProvider.persistWebFileSystem;

  final FileSystem? _fileSystem;
  final DocumentsDirectoryPathProvider _documentsDirectoryPathProvider;
  final FileSystemPersister _persistFileSystem;

  FileSystem get _fs => _fileSystem ?? FileSystemProvider.instance;

  Future<Directory> resolveDiatarDirectory() async {
    final String documentsPath = await _documentsDirectoryPathProvider();
    return _fs.directory(_fs.path.join(documentsPath, 'diatar'));
  }

  Future<Uint8List> createExportArchive() async {
    final Directory source = await resolveDiatarDirectory();
    if (!await source.exists()) {
      throw const DiatarArchiveException(
        DiatarArchiveErrorCode.sourceDirectoryMissing,
      );
    }

    final Archive archive = Archive()
      ..addFile(ArchiveFile.directory('diatar/'));
    final List<FileSystemEntity> entities =
        source.listSync(recursive: true, followLinks: false)..sort(
          (FileSystemEntity left, FileSystemEntity right) =>
              left.path.compareTo(right.path),
        );

    for (final FileSystemEntity entity in entities) {
      final String relativePath = _fs.path.relative(
        entity.path,
        from: source.path,
      );
      final String archivePath = path.posix.joinAll(<String>[
        'diatar',
        ..._fs.path.split(relativePath),
      ]);

      if (entity is Directory) {
        archive.addFile(ArchiveFile.directory('$archivePath/'));
      } else if (entity is File) {
        archive.addFile(
          ArchiveFile.bytes(archivePath, await entity.readAsBytes()),
        );
      }
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<DiatarImportPreview> inspectImportArchive(Uint8List zipData) async {
    final _ValidatedArchive archive = _decodeAndValidate(zipData);
    final Directory targetDirectory = await resolveDiatarDirectory();
    int conflictingFileCount = 0;

    for (final _ValidatedFile file in archive.files) {
      final File target = _targetFile(targetDirectory, file.relativePath);
      if (await target.exists()) {
        conflictingFileCount++;
      }
    }

    return DiatarImportPreview(
      fileCount: archive.files.length,
      conflictingFileCount: conflictingFileCount,
    );
  }

  Future<DiatarImportResult> importArchive(
    Uint8List zipData, {
    required ExistingFilePolicy existingFilePolicy,
  }) async {
    final _ValidatedArchive archive = _decodeAndValidate(zipData);
    final Directory targetDirectory = await resolveDiatarDirectory();
    await targetDirectory.create(recursive: true);

    int importedFileCount = 0;
    int skippedFileCount = 0;
    final List<String> errors = <String>[];

    final List<String> directories = List<String>.from(archive.directories)
      ..sort((String left, String right) {
        final int depthComparison = _pathDepth(
          left,
        ).compareTo(_pathDepth(right));
        return depthComparison != 0 ? depthComparison : left.compareTo(right);
      });

    for (final String relativePath in directories) {
      try {
        final Directory directory = _targetDirectory(
          targetDirectory,
          relativePath,
        );
        await directory.create(recursive: true);
      } catch (error) {
        errors.add('$relativePath: $error');
      }
    }

    for (final _ValidatedFile archivedFile in archive.files) {
      final File target = _targetFile(
        targetDirectory,
        archivedFile.relativePath,
      );
      try {
        if (await target.exists() &&
            existingFilePolicy == ExistingFilePolicy.skip) {
          skippedFileCount++;
          continue;
        }

        await target.parent.create(recursive: true);
        await target.writeAsBytes(archivedFile.bytes, flush: true);
        importedFileCount++;
      } catch (error) {
        errors.add('${archivedFile.relativePath}: $error');
      }
    }

    if (importedFileCount > 0) {
      try {
        await _persistFileSystem();
      } catch (error) {
        errors.add('persist: $error');
      }
    }

    return DiatarImportResult(
      importedFileCount: importedFileCount,
      skippedFileCount: skippedFileCount,
      errors: List<String>.unmodifiable(errors),
    );
  }

  _ValidatedArchive _decodeAndValidate(Uint8List zipData) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipData, verify: true);
    } catch (error) {
      throw DiatarArchiveException(
        DiatarArchiveErrorCode.invalidArchive,
        error,
      );
    }

    final List<_ValidatedFile> files = <_ValidatedFile>[];
    final Set<String> directories = <String>{};
    final Set<String> targets = <String>{};

    try {
      for (final ArchiveFile entry in archive.files) {
        final String archiveName = entry.name.replaceAll(r'\', '/');
        if (archiveName == 'diatar' || archiveName == 'diatar/') {
          if (entry.isFile) {
            throw const FormatException('The diatar root is not a directory.');
          }
          continue;
        }
        if (!archiveName.startsWith('diatar/')) {
          throw const FormatException('Unexpected archive root.');
        }
        if (entry.isSymbolicLink) {
          throw const FormatException('Symbolic links are not supported.');
        }

        final String rawRelativePath = archiveName.substring('diatar/'.length);
        final String relativePath = _validateRelativePath(rawRelativePath);
        if (!targets.add(relativePath)) {
          throw const FormatException('Duplicate archive entry.');
        }

        if (entry.isDirectory) {
          directories.add(relativePath);
        } else {
          files.add(
            _ValidatedFile(
              relativePath: relativePath,
              bytes: Uint8List.fromList(entry.content),
            ),
          );
        }
      }
    } catch (error) {
      throw DiatarArchiveException(
        DiatarArchiveErrorCode.invalidArchive,
        error,
      );
    }

    return _ValidatedArchive(
      files: List<_ValidatedFile>.unmodifiable(files),
      directories: Set<String>.unmodifiable(directories),
    );
  }

  String _validateRelativePath(String rawPath) {
    if (rawPath.isEmpty || rawPath.contains('\u0000')) {
      throw const FormatException('Empty or invalid archive path.');
    }

    final List<String> segments = rawPath
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty ||
        segments.any(
          (String segment) =>
              segment == '.' ||
              segment == '..' ||
              path.posix.isAbsolute(segment),
        )) {
      throw const FormatException('Unsafe archive path.');
    }

    final String normalized = path.posix.normalize(
      path.posix.joinAll(segments),
    );
    if (normalized == '..' ||
        normalized.startsWith('../') ||
        path.posix.isAbsolute(normalized)) {
      throw const FormatException('Unsafe archive path.');
    }
    return normalized;
  }

  File _targetFile(Directory root, String relativePath) {
    return _fs.file(_targetPath(root, relativePath));
  }

  Directory _targetDirectory(Directory root, String relativePath) {
    return _fs.directory(_targetPath(root, relativePath));
  }

  String _targetPath(Directory root, String relativePath) {
    final String target = _fs.path.normalize(
      _fs.path.joinAll(<String>[root.path, ...path.posix.split(relativePath)]),
    );
    final String normalizedRoot = _fs.path.normalize(root.path);
    if (target != normalizedRoot &&
        !_fs.path.isWithin(normalizedRoot, target)) {
      throw const DiatarArchiveException(DiatarArchiveErrorCode.invalidArchive);
    }
    return target;
  }

  int _pathDepth(String value) => path.posix.split(value).length;
}

class _ValidatedArchive {
  const _ValidatedArchive({required this.files, required this.directories});

  final List<_ValidatedFile> files;
  final Set<String> directories;
}

class _ValidatedFile {
  const _ValidatedFile({required this.relativePath, required this.bytes});

  final String relativePath;
  final Uint8List bytes;
}
