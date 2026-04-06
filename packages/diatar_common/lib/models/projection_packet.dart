import 'dart:typed_data';

import 'records.dart';

class ProjectionPacket {
  const ProjectionPacket({required this.type, required this.body});

  final int type;
  final Uint8List body;
}

Uint8List encodeProjectionPacket(int type, Uint8List body) {
  final Uint8List packet = Uint8List(12 + body.length);
  packet[0] = RecordHeader.magic[0];
  packet[1] = RecordHeader.magic[1];
  packet[2] = RecordHeader.magic[2];
  packet[3] = RecordHeader.magic[3];
  packet[4] = type & 0xFF;

  final ByteData bd = packet.buffer.asByteData();
  bd.setInt32(8, body.length, Endian.little);

  if (body.isNotEmpty) {
    packet.setRange(12, 12 + body.length, body);
  }
  return packet;
}

class ProjectionPacketParser {
  ProjectionPacketParser({this.maxPacketSize = 100 * 1024 * 1024});

  final int maxPacketSize;
  final List<int> _buffer = <int>[];

  void clear() {
    _buffer.clear();
  }

  List<ProjectionPacket> addChunk(List<int> bytes) {
    if (bytes.isNotEmpty) {
      _buffer.addAll(bytes);
    }

    final List<ProjectionPacket> out = <ProjectionPacket>[];
    while (true) {
      final int ix = _findMagicIndex(_buffer);
      if (ix < 0) {
        // Keep only trailing bytes in case the next chunk completes magic.
        if (_buffer.length > 3) {
          _buffer.removeRange(0, _buffer.length - 3);
        }
        break;
      }

      if (ix > 0) {
        _buffer.removeRange(0, ix);
      }

      if (_buffer.length < 12) {
        break;
      }

      final int type = _buffer[4];
      final int size = _readIntLE(_buffer, 8);
      if (size < 0 || size > maxPacketSize) {
        _buffer.removeAt(0);
        continue;
      }

      final int total = 12 + size;
      if (_buffer.length < total) {
        break;
      }

      final Uint8List body = Uint8List.fromList(_buffer.sublist(12, total));
      _buffer.removeRange(0, total);
      out.add(ProjectionPacket(type: type, body: body));
    }

    return out;
  }

  int _findMagicIndex(List<int> data) {
    for (int i = 0; i <= data.length - 4; i++) {
      if (data[i] == RecordHeader.magic[0] &&
          data[i + 1] == RecordHeader.magic[1] &&
          data[i + 2] == RecordHeader.magic[2] &&
          data[i + 3] == RecordHeader.magic[3]) {
        return i;
      }
    }
    return -1;
  }

  int _readIntLE(List<int> data, int ofs) {
    return (data[ofs]) |
        (data[ofs + 1] << 8) |
        (data[ofs + 2] << 16) |
        (data[ofs + 3] << 24);
  }
}
