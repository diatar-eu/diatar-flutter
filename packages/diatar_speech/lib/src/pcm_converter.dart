import 'dart:typed_data';

Float32List convertPcm16ToFloat32(
  Uint8List bytes, [
  Endian endian = Endian.little,
]) {
  final int length = bytes.length ~/ 2;
  final Float32List values = Float32List(length);
  final ByteData data = ByteData.view(bytes.buffer);
  for (int i = 0; i < length; i++) {
    final int short = data.getInt16(i * 2, endian);
    values[i] = short / 32768.0;
  }
  return values;
}
