import 'dart:io' as io;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../utils/file_system_provider.dart';

enum StreamingZipErrorCode {
  sourceUnreadable,
  invalidArchive,
  tooManyEntries,
  entryTooLarge,
  totalTooLarge,
  cancelled,
  entryUnreadable,
  writeFailed,
}

class StreamingZipException implements Exception {
  const StreamingZipException(this.code, {this.entryName, this.cause});

  final StreamingZipErrorCode code;
  final String? entryName;
  final Object? cause;

  @override
  String toString() => 'StreamingZipException(${code.name})';
}

class StreamingZipLimits {
  const StreamingZipLimits({
    this.maxEntries = 10000,
    this.maxEntrySize = 256 * 1024 * 1024,
    this.maxTotalSize = 1024 * 1024 * 1024,
  });

  final int maxEntries;
  final int maxEntrySize;
  final int maxTotalSize;
}

class StreamingZipProgress {
  const StreamingZipProgress({
    required this.archivePath,
    required this.entryName,
    required this.completedEntries,
    required this.totalEntries,
    required this.writtenBytes,
    required this.totalBytes,
  });

  final String archivePath;
  final String entryName;
  final int completedEntries;
  final int totalEntries;
  final int writtenBytes;
  final int totalBytes;
}

/// Reads ZIP metadata and extracts files without retaining archive contents in
/// memory. ZIP input is read from disk and each entry is decompressed directly
/// into its destination file.
class StreamingZipService {
  static const int _bufferSize = 256 * 1024;

  const StreamingZipService();

  Future<Set<String>> fileNames(
    String zipPath, {
    StreamingZipLimits limits = const StreamingZipLimits(),
  }) async {
    final _ZipDirectory directory = _readDirectory(zipPath);
    try {
      _validateHeaders(directory.headers, limits);
      return <String>{
        for (final ZipFileHeader header in directory.headers)
          if (!_isDirectory(header)) header.filename.replaceAll(r'\', '/'),
      };
    } finally {
      await directory.close();
    }
  }

  Future<List<String>> extract(
    String zipPath, {
    required Directory targetDirectory,
    Set<String>? only,
    StreamingZipLimits limits = const StreamingZipLimits(),
    void Function(StreamingZipProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (kIsWeb) {
      return _extractInMemory(
        zipPath,
        targetDirectory: targetDirectory,
        only: only,
        limits: limits,
        isCancelled: isCancelled,
      );
    }

    final _ZipDirectory directory = _readDirectory(zipPath);
    final List<String> extracted = <String>[];
    try {
      final _ZipMetadata metadata = _validateHeaders(directory.headers, limits);
      int writtenBytes = 0;
      int completedEntries = 0;
      for (final ZipFileHeader header in directory.headers) {
        if (isCancelled?.call() ?? false) {
          throw const StreamingZipException(StreamingZipErrorCode.cancelled);
        }
        if (_isDirectory(header)) {
          continue;
        }
        final String name = header.filename.replaceAll(r'\', '/');
        if (!_isSafePath(name) || (only != null && !only.contains(name))) {
          continue;
        }
        final ZipFile? file = header.file;
        if (file == null) {
          throw StreamingZipException(
            StreamingZipErrorCode.entryUnreadable,
            entryName: name,
          );
        }
        final File target = FileSystemProvider.instance.file(
          '${targetDirectory.path}/$name',
        );
        await target.parent.create(recursive: true);
        final _FileOutputStream output = _FileOutputStream(
          target,
          onBytesWritten: (int bytes) {
            writtenBytes += bytes;
            onProgress?.call(
              StreamingZipProgress(
                archivePath: zipPath,
                entryName: name,
                completedEntries: completedEntries,
                totalEntries: metadata.fileCount,
                writtenBytes: writtenBytes,
                totalBytes: metadata.totalSize,
              ),
            );
            if (isCancelled?.call() ?? false) {
              throw const StreamingZipException(StreamingZipErrorCode.cancelled);
            }
          },
        )..open();
        try {
          file.decompress(output);
        } on StreamingZipException {
          rethrow;
        } catch (error) {
          throw StreamingZipException(
            StreamingZipErrorCode.entryUnreadable,
            entryName: name,
            cause: error,
          );
        } finally {
          await output.close();
        }
        extracted.add(name);
        completedEntries++;
      }
    } on StreamingZipException {
      rethrow;
    } catch (error) {
      throw StreamingZipException(
        StreamingZipErrorCode.writeFailed,
        cause: error,
      );
    } finally {
      await directory.close();
    }
    return extracted;
  }

  Future<List<String>> _extractInMemory(
    String zipPath, {
    required Directory targetDirectory,
    Set<String>? only,
    required StreamingZipLimits limits,
    bool Function()? isCancelled,
  }) async {
    try {
      final File zipFile = FileSystemProvider.instance.file(zipPath);
      final Archive archive = ZipDecoder().decodeBytes(
        await zipFile.readAsBytes(),
      );
      int count = 0;
      int total = 0;
      final List<String> extracted = <String>[];
      for (final ArchiveFile entry in archive) {
        if (!entry.isFile || entry.isSymbolicLink) continue;
        count++;
        total += entry.size;
        if (count > limits.maxEntries) {
          throw const StreamingZipException(StreamingZipErrorCode.tooManyEntries);
        }
        if (entry.size > limits.maxEntrySize) {
          throw StreamingZipException(
            StreamingZipErrorCode.entryTooLarge,
            entryName: entry.name,
          );
        }
        if (total > limits.maxTotalSize) {
          throw const StreamingZipException(StreamingZipErrorCode.totalTooLarge);
        }
        if (isCancelled?.call() ?? false) {
          throw const StreamingZipException(StreamingZipErrorCode.cancelled);
        }
        final String name = entry.name.replaceAll(r'\', '/');
        if (!_isSafePath(name) || (only != null && !only.contains(name))) continue;
        final Uint8List? bytes = entry.readBytes();
        if (bytes == null) {
          throw StreamingZipException(
            StreamingZipErrorCode.entryUnreadable,
            entryName: name,
          );
        }
        final File target = FileSystemProvider.instance.file(
          '${targetDirectory.path}/$name',
        );
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes, flush: true);
        extracted.add(name);
      }
      return extracted;
    } on StreamingZipException {
      rethrow;
    } catch (error) {
      throw StreamingZipException(
        StreamingZipErrorCode.invalidArchive,
        cause: error,
      );
    }
  }

  _ZipDirectory _readDirectory(String zipPath) {
    final InputFileStream input;
    try {
      input = InputFileStream(zipPath, bufferSize: _bufferSize);
    } catch (error) {
      throw StreamingZipException(
        StreamingZipErrorCode.sourceUnreadable,
        cause: error,
      );
    }
    try {
      final ZipDirectory directory = ZipDirectory()..read(input);
      if (directory.filePosition < 0) {
        throw const FormatException(
          'End of central directory record not found.',
        );
      }
      return _ZipDirectory(directory.fileHeaders, input.close);
    } catch (error) {
      input.closeSync();
      throw StreamingZipException(
        StreamingZipErrorCode.invalidArchive,
        cause: error,
      );
    }
  }

  _ZipMetadata _validateHeaders(
    List<ZipFileHeader> headers,
    StreamingZipLimits limits,
  ) {
    int count = 0;
    int total = 0;
    for (final ZipFileHeader header in headers) {
      if (_isDirectory(header)) {
        continue;
      }
      count++;
      if (count > limits.maxEntries) {
        throw const StreamingZipException(StreamingZipErrorCode.tooManyEntries);
      }
      if (header.uncompressedSize > limits.maxEntrySize) {
        throw StreamingZipException(
          StreamingZipErrorCode.entryTooLarge,
          entryName: header.filename,
        );
      }
      total += header.uncompressedSize;
      if (total > limits.maxTotalSize) {
        throw const StreamingZipException(StreamingZipErrorCode.totalTooLarge);
      }
    }
    return _ZipMetadata(fileCount: count, totalSize: total);
  }

  bool _isDirectory(ZipFileHeader header) {
    final int mode = header.externalFileAttributes >> 16;
    return header.filename.endsWith('/') || (mode & 0x4000) != 0;
  }

  bool _isSafePath(String path) =>
      !path.startsWith('/') &&
      !path.startsWith('../') &&
      !path.contains('/../');
}

class _ZipDirectory {
  const _ZipDirectory(this.headers, this.close);

  final List<ZipFileHeader> headers;
  final Future<void> Function() close;
}

class _ZipMetadata {
  const _ZipMetadata({required this.fileCount, required this.totalSize});

  final int fileCount;
  final int totalSize;
}

class _FileOutputStream extends OutputStream {
  static const int _chunkSize = 64 * 1024;

  _FileOutputStream(this._file, {this.onBytesWritten})
    : super(byteOrder: ByteOrder.littleEndian);

  final File _file;
  final void Function(int bytes)? onBytesWritten;
  final Uint8List _chunk = Uint8List(_chunkSize);
  io.RandomAccessFile? _handle;
  int _length = 0;
  int _chunkLength = 0;

  @override
  int get length => _length;

  @override
  void open() {
    _handle ??= io.File(_file.path).openSync(mode: io.FileMode.write);
  }

  void _flushChunk() {
    if (_chunkLength == 0) {
      return;
    }
    _handle!.writeFromSync(Uint8List.sublistView(_chunk, 0, _chunkLength));
    _chunkLength = 0;
  }

  @override
  void writeByte(int value) {
    _chunk[_chunkLength++] = value;
    _length++;
    onBytesWritten?.call(1);
    if (_chunkLength == _chunk.length) {
      _flushChunk();
    }
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final int count = length ?? bytes.length;
    var offset = 0;
    var remaining = count;
    while (remaining > 0) {
      final int take = remaining < _chunk.length - _chunkLength
          ? remaining
          : _chunk.length - _chunkLength;
      _chunk.setRange(_chunkLength, _chunkLength + take, bytes, offset);
      _chunkLength += take;
      _length += take;
      onBytesWritten?.call(take);
      offset += take;
      remaining -= take;
      if (_chunkLength == _chunk.length) {
        _flushChunk();
      }
    }
  }

  @override
  void writeStream(InputStream stream) {
    while (stream.length > 0) {
      final int count = stream.length < _chunkSize ? stream.length : _chunkSize;
      writeBytes(stream.readBytes(count).toUint8List());
    }
  }

  @override
  void flush() => _flushChunk();

  @override
  void clear() => _flushChunk();

  @override
  Future<void> close() async {
    _flushChunk();
    _handle?.closeSync();
    _handle = null;
  }

  @override
  Uint8List subset(int start, [int? end]) =>
      throw UnsupportedError('Reading from an output stream is not supported.');
}
