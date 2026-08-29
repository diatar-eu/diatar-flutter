import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../utils/file_system_provider.dart';

/// Reads ZIP metadata and extracts files without retaining archive contents in
/// memory. ZIP input is read from disk and each entry is decompressed directly
/// into its destination file.
class StreamingZipService {
  static const int _bufferSize = 256 * 1024;

  const StreamingZipService();

  Future<Set<String>> fileNames(String zipPath) async {
    final _ZipDirectory directory = _readDirectory(zipPath);
    try {
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
  }) async {
    final _ZipDirectory directory = _readDirectory(zipPath);
    final List<String> extracted = <String>[];
    try {
      for (final ZipFileHeader header in directory.headers) {
        if (_isDirectory(header)) {
          continue;
        }
        final String name = header.filename.replaceAll(r'\', '/');
        if (!_isSafePath(name) || (only != null && !only.contains(name))) {
          continue;
        }
        final ZipFile? file = header.file;
        if (file == null) {
          throw const FormatException('Archive entry could not be read.');
        }
        final File target = FileSystemProvider.instance.file(
          '${targetDirectory.path}/$name',
        );
        await target.parent.create(recursive: true);
        final _FileOutputStream output = _FileOutputStream(target)..open();
        try {
          file.decompress(output);
        } finally {
          await output.close();
        }
        extracted.add(name);
      }
    } finally {
      await directory.close();
    }
    return extracted;
  }

  _ZipDirectory _readDirectory(String zipPath) {
    final InputFileStream input = InputFileStream(
      zipPath,
      bufferSize: _bufferSize,
    );
    try {
      final ZipDirectory directory = ZipDirectory()..read(input);
      if (directory.filePosition < 0) {
        throw const FormatException(
          'End of central directory record not found.',
        );
      }
      return _ZipDirectory(directory.fileHeaders, input.close);
    } catch (_) {
      input.closeSync();
      rethrow;
    }
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

class _FileOutputStream extends OutputStream {
  static const int _chunkSize = 64 * 1024;

  _FileOutputStream(this._file) : super(byteOrder: ByteOrder.littleEndian);

  final File _file;
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
