import 'dart:io' as io;
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';

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

class DiatarImportResult {
  const DiatarImportResult({
    required this.importedFileCount,
    required this.errors,
  });

  final int importedFileCount;
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

  /// Streams the complete diatar directory into an uncompressed ZIP file on
  /// disk. Storing entries instead of deflating them avoids the archive
  /// package's per-entry compression buffer and keeps memory use bounded.
  ///
  /// Returns the path of the created temporary archive. The caller owns the
  /// returned file and its parent directory and must delete them when done.
  Future<String> createExportArchiveFile({
    void Function(double progress)? onProgress,
  }) async {
    final FileSystem fs = _fs;
    final String documentsPath = await _documentsDirectoryPathProvider();
    final Directory tempDir = await fs.systemTempDirectory.createTemp(
      'diatar_backup_',
    );
    final String targetPath = fs.path.join(tempDir.path, 'diatar-backup.zip'    );
    try {
      await _streamExportArchiveTo(
        documentsPath: documentsPath,
        targetPath: targetPath,
        onProgress: onProgress,
      );
      return targetPath;
    } catch (_) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Ignore temp cleanup failures.
      }
      rethrow;
    }
  }

  Future<DiatarImportResult> importArchive(
    Uint8List zipData, {
    void Function(double progress)? onProgress,
  }) async {
    final _ReadArchive read = _readArchiveFromBytes(zipData);
    try {
      return await _importValidatedArchive(
        _validateCentralDirectory(read.headers),
        onProgress: onProgress,
      );
    } finally {
      await read.close();
    }
  }

  Future<DiatarImportResult> importArchiveFile(
    String zipFilePath, {
    void Function(double progress)? onProgress,
  }) async {
    final _ReadArchive read = _readArchiveFromFilePath(zipFilePath);
    try {
      return await _importValidatedArchive(
        _validateCentralDirectory(read.headers),
        onProgress: onProgress,
      );
    } finally {
      await read.close();
    }
  }

  static const int _streamBufferSize = 256 * 1024;

  _ReadArchive _readArchiveFromBytes(Uint8List zipData) {
    final InputMemoryStream input = InputMemoryStream(zipData);
    return _readArchiveFromInput(input, close: input.close);
  }

  _ReadArchive _readArchiveFromFilePath(String zipFilePath) {
    final InputFileStream input = InputFileStream(
      zipFilePath,
      bufferSize: _streamBufferSize,
    );
    return _readArchiveFromInput(input, close: input.close);
  }

  /// Reads only the central directory of a ZIP archive (the end of central
  /// directory record, ZIP64 record and per-entry headers). No file content
  /// is read or decompressed, so memory usage stays proportional to the
  /// number of entries rather than the total uncompressed size.
  _ReadArchive _readArchiveFromInput(
    InputStream input, {
    required Future<void> Function() close,
  }) {
    try {
      final ZipDirectory directory = ZipDirectory();
      directory.read(input);
      if (directory.filePosition < 0) {
        throw const FormatException(
          'End of central directory record not found.',
        );
      }
      return _ReadArchive(headers: directory.fileHeaders, close: close);
    } catch (error) {
      input.closeSync();
      throw DiatarArchiveException(
        DiatarArchiveErrorCode.invalidArchive,
        error,
      );
    }
  }

  Future<DiatarImportResult> _importValidatedArchive(
    _ValidatedArchive archive, {
    void Function(double progress)? onProgress,
  }) async {
    final Directory targetDirectory = await resolveDiatarDirectory();
    await targetDirectory.create(recursive: true);

    int importedFileCount = 0;
    int completedFileCount = 0;
    int completedBytes = 0;
    final int totalBytes = archive.files.fold(
      0,
      (int total, _ValidatedFile file) =>
          total + file.header.uncompressedSize,
    );
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
        await target.parent.create(recursive: true);
        final ZipFile? entry = archivedFile.header.file;
        if (entry == null) {
          throw const FormatException('Archive entry could not be read.');
        }

        _FsOutputStream? output;
        Object? failure;
        try {
          output = _FsOutputStream(
            target,
            onBytesWritten: (int bytesWritten) {
              if (totalBytes > 0) {
                onProgress?.call(
                  ((completedBytes + bytesWritten) / totalBytes)
                      .clamp(0.0, 1.0)
                      .toDouble(),
                );
              }
            },
          );
          output.open();
          entry.decompress(output);
          final int computedCrc32 = output.crc32;
          final int expectedCrc32 = archivedFile.header.crc32;
          if (computedCrc32 != expectedCrc32) {
            throw FormatException(
              'CRC mismatch: expected $expectedCrc32, got $computedCrc32.',
            );
          }
        } catch (error) {
          failure = error;
        } finally {
          if (output != null) {
            await output.close();
          }
        }

        if (failure != null) {
          try {
            if (await target.exists()) {
              await target.delete();
            }
          } catch (_) {
            // Best effort cleanup of the partial file.
          }
          errors.add('${archivedFile.relativePath}: $failure');
        } else {
          importedFileCount++;
        }
      } catch (error) {
        errors.add('${archivedFile.relativePath}: $error');
      } finally {
        completedFileCount++;
        completedBytes += archivedFile.header.uncompressedSize;
        onProgress?.call(
          totalBytes > 0
              ? completedBytes / totalBytes
              : completedFileCount / archive.files.length,
        );
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
      errors: List<String>.unmodifiable(errors),
    );
  }

  _ValidatedArchive _validateCentralDirectory(List<ZipFileHeader> headers) {
    final List<_ValidatedFile> files = <_ValidatedFile>[];
    final Set<String> directories = <String>{};
    final Set<String> targets = <String>{};

    try {
      for (final ZipFileHeader header in headers) {
        final String archiveName = header.filename.replaceAll(r'\', '/');
        final int mode = header.externalFileAttributes >> 16;
        final bool isDirectory =
            archiveName.endsWith('/') || (mode & 0x4000) != 0;
        if (archiveName == 'diatar' || archiveName == 'diatar/') {
          if (!isDirectory) {
            throw const FormatException('The diatar root is not a directory.');
          }
          continue;
        }
        if (!archiveName.startsWith('diatar/')) {
          throw const FormatException('Unexpected archive root.');
        }
        if ((mode & 0xf000) == 0xa000) {
          throw const FormatException('Symbolic links are not supported.');
        }

        final String rawRelativePath = archiveName.substring('diatar/'.length);
        final String relativePath = _validateRelativePath(rawRelativePath);
        if (!targets.add(relativePath)) {
          throw const FormatException('Duplicate archive entry.');
        }

        if (isDirectory) {
          directories.add(relativePath);
        } else {
          files.add(
            _ValidatedFile(relativePath: relativePath, header: header),
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
  const _ValidatedFile({required this.relativePath, required this.header});

  final String relativePath;
  final ZipFileHeader header;
}

class _ReadArchive {
  const _ReadArchive({required this.headers, required this.close});

  final List<ZipFileHeader> headers;
  final Future<void> Function() close;
}

/// A streaming [OutputStream] that writes decompressed bytes directly to a
/// [File] through the injected [FileSystem] abstraction, keeping memory usage
/// bounded by a fixed chunk buffer instead of the uncompressed file size.
class _FsOutputStream extends OutputStream {
  static const int _chunkSize = 64 * 1024;

  _FsOutputStream(
    File file, {
    this.onBytesWritten,
  })
      : _file = file,
        super(byteOrder: ByteOrder.littleEndian);

  final File _file;
  final void Function(int bytesWritten)? onBytesWritten;
  final Uint8List _chunk = Uint8List(_chunkSize);
  io.RandomAccessFile? _handle;
  int _chunkLength = 0;
  int _length = 0;
  int _crc32 = 0;

  @override
  int get length => _length;

  /// CRC32 of all bytes written so far.
  int get crc32 => _crc32;

  /// Opens the underlying file for writing. Called before the first write so
  /// that empty entries still produce an (empty) file on disk.
  @override
  void open() {
    _handle ??= _file.openSync(mode: io.FileMode.write);
  }

  void _flushChunk() {
    if (_chunkLength == 0) {
      return;
    }
    final Uint8List bytes = Uint8List.sublistView(
      _chunk,
      0,
      _chunkLength,
    );
    _crc32 = getCrc32(bytes, _crc32);
    _handle!.writeFromSync(bytes);
    onBytesWritten?.call(_chunkLength);
    _chunkLength = 0;
  }

  @override
  void writeByte(int value) {
    _chunk[_chunkLength++] = value;
    _length++;
    if (_chunkLength == _chunk.length) {
      _flushChunk();
    }
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final int count = length ?? bytes.length;
    int offset = 0;
    int remaining = count;
    while (remaining > 0) {
      final int space = _chunk.length - _chunkLength;
      if (space == 0) {
        _flushChunk();
        continue;
      }
      final int take = remaining < space ? remaining : space;
      _chunk.setRange(_chunkLength, _chunkLength + take, bytes, offset);
      _chunkLength += take;
      offset += take;
      remaining -= take;
      _length += take;
    }
  }

  @override
  void writeStream(InputStream stream) {
    const int chunkSize = 1024 * 1024;
    var remaining = stream.length;
    while (remaining > 0) {
      final int take = remaining < chunkSize ? remaining : chunkSize;
      writeBytes(stream.readBytes(take).toUint8List());
      remaining -= take;
    }
  }

  @override
  void flush() {
    _flushChunk();
  }

  @override
  void clear() {
    _flushChunk();
  }

  @override
  Future<void> close() async {
    _flushChunk();
    _handle?.closeSync();
    _handle = null;
  }

  @override
  Uint8List subset(int start, [int? end]) {
    throw UnsupportedError(
      'Reading back from an output stream is not supported.',
    );
  }
}

Future<void> _streamExportArchiveTo({
  required String documentsPath,
  required String targetPath,
  void Function(double progress)? onProgress,
}) async {
  final ReceivePort receivePort = ReceivePort();
  final Completer<void> completed = Completer<void>();
  late final StreamSubscription<dynamic> subscription;
  subscription = receivePort.listen((dynamic message) {
    final _ExportArchiveUpdate update = message as _ExportArchiveUpdate;
    if (update.errorCode != null) {
      if (!completed.isCompleted) {
        completed.completeError(
          DiatarArchiveException(
            DiatarArchiveErrorCode.values.byName(update.errorCode!),
          ),
        );
      }
      return;
    }
    if (update.complete) {
      if (!completed.isCompleted) {
        completed.complete();
      }
      return;
    }
    onProgress?.call(update.progress);
  });
  try {
    await Isolate.spawn<_ExportArchiveRequest>(
      _streamExportArchiveInIsolate,
      _ExportArchiveRequest(
        documentsPath: documentsPath,
        targetPath: targetPath,
        sendPort: receivePort.sendPort,
      ),
    );
    await completed.future;
  } finally {
    await subscription.cancel();
    receivePort.close();
  }
}

class _ExportArchiveRequest {
  const _ExportArchiveRequest({
    required this.documentsPath,
    required this.targetPath,
    required this.sendPort,
  });

  final String documentsPath;
  final String targetPath;
  final SendPort sendPort;
}

class _ExportArchiveUpdate {
  const _ExportArchiveUpdate.progress(this.progress)
    : complete = false,
      errorCode = null;

  const _ExportArchiveUpdate.complete()
    : progress = 1,
      complete = true,
      errorCode = null;

  const _ExportArchiveUpdate.error(this.errorCode)
    : progress = 0,
      complete = false;

  final double progress;
  final bool complete;
  final String? errorCode;
}

Future<void> _streamExportArchiveInIsolate(
  _ExportArchiveRequest request,
) async {
  final io.Directory source = io.Directory(
    path.join(request.documentsPath, 'diatar'),
  );
  if (!await source.exists()) {
    request.sendPort.send(
      const _ExportArchiveUpdate.error('sourceDirectoryMissing'),
    );
    return;
  }

  try {
    final List<io.FileSystemEntity> entities = source.listSync(
      recursive: true,
      followLinks: false,
    );
    int totalBytes = 0;
    for (final io.FileSystemEntity entity in entities) {
      if (entity is io.File) {
        totalBytes += entity.lengthSync();
      }
    }
    final _FsOutputStream output = _FsOutputStream(
      FileSystemProvider.instance.file(request.targetPath),
    );
    output.open();
    final ZipEncoder encoder = ZipEncoder();
    encoder.startEncode(output);
    encoder.add(ArchiveFile.directory('diatar/'));
    int completedBytes = 0;
    try {
      for (final io.FileSystemEntity entity in entities) {
        final String relativePath = path.relative(entity.path, from: source.path);
        final String archivePath = path.posix.joinAll(<String>[
          'diatar',
          ...path.split(relativePath),
        ]);
        if (entity is io.Directory) {
          encoder.add(ArchiveFile.directory('$archivePath/'));
        } else if (entity is io.File) {
          final InputFileStream input = InputFileStream(
            entity.path,
            bufferSize: ExportImportService._streamBufferSize,
          );
          final ArchiveFile file = ArchiveFile.stream(archivePath, input)
            ..compression = CompressionType.none;
          encoder.add(file);
          await input.close();
          completedBytes += entity.lengthSync();
          request.sendPort.send(
            _ExportArchiveUpdate.progress(
              totalBytes > 0 ? completedBytes / totalBytes : 1,
            ),
          );
        }
      }
      encoder.endEncode();
      await output.close();
    } catch (_) {
      await output.close();
      rethrow;
    }
    request.sendPort.send(const _ExportArchiveUpdate.complete());
  } catch (_) {
    request.sendPort.send(const _ExportArchiveUpdate.error('invalidArchive'));
  }
}
