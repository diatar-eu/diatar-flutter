import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

class RecTypes {
  static const int state = 0;
  static const int scrSize = 1;
  static const int pic = 2;
  static const int blank = 3;
  static const int text = 4;
  static const int askSize = 5;
  static const int idle = 6;
}

class RecStateEndProgram {
  static const int stop = 0xADD00ADD;
  static const int shutdown = 0xDEAD80FF;
  static const int skipSerialOff = 0x11111111;
}

class RecBgMode {
  static const int center = 0;
  static const int zoom = 1;
  static const int full = 2;
  static const int cascade = 3;
  static const int mirror = 4;
}

class RecordHeader {
  const RecordHeader({required this.type, required this.size});

  final int type;
  final int size;

  static const List<int> magic = <int>[0xDA, 0x69, 0x70, 0x4A];
}

int _readIntLE(Uint8List data, int ofs) {
  if (ofs + 3 >= data.length) {
    return 0;
  }
  return (data[ofs]) |
      (data[ofs + 1] << 8) |
      (data[ofs + 2] << 16) |
      (data[ofs + 3] << 24);
}

bool _readBool(Uint8List data, int ofs) => ofs < data.length && data[ofs] != 0;

Color _readColor(Uint8List data, int ofs) {
  if (ofs + 2 >= data.length) {
    return const Color(0xFF000000);
  }
  final int argb = 0xFF000000 |
      (data[ofs] << 16) |
      (data[ofs + 1] << 8) |
      data[ofs + 2];
  return Color(argb);
}

String _readPascalString(Uint8List data, int ofs) {
  if (ofs >= data.length) {
    return '';
  }
  final int len = data[ofs];
  if (len <= 0 || ofs + 1 + len > data.length) {
    return '';
  }
  return String.fromCharCodes(data.sublist(ofs + 1, ofs + 1 + len));
}

class RecStateRecord {
  const RecStateRecord({
    required this.bkColor,
    required this.txtColor,
    required this.blankColor,
    required this.hiColor,
    required this.fontSize,
    required this.titleSize,
    required this.leftIndent,
    required this.spacing100,
    required this.hKey,
    required this.wordToHighlight,
    required this.borderL,
    required this.borderT,
    required this.borderR,
    required this.borderB,
    required this.fontName,
    required this.isBlankPic,
    required this.autoResize,
    required this.projecting,
    required this.showBlankPic,
    required this.hCenter,
    required this.vCenter,
    required this.scholaMode,
    required this.useAkkord,
    required this.useKotta,
    required this.useTransitions,
    required this.endProgram,
    required this.hideTitle,
    required this.inverzKotta,
    required this.bgMode,
    required this.kottaArany,
    required this.akkordArany,
    required this.boldText,
  });

  final Color bkColor;
  final Color txtColor;
  final Color blankColor;
  final Color hiColor;
  final int fontSize;
  final int titleSize;
  final int leftIndent;
  final int spacing100;
  final int hKey;
  final int wordToHighlight;
  final int borderL;
  final int borderT;
  final int borderR;
  final int borderB;
  final String fontName;
  final bool isBlankPic;
  final bool autoResize;
  final bool projecting;
  final bool showBlankPic;
  final bool hCenter;
  final bool vCenter;
  final bool scholaMode;
  final bool useAkkord;
  final bool useKotta;
  final bool useTransitions;
  final int endProgram;
  final bool hideTitle;
  final bool inverzKotta;
  final int bgMode;
  final int kottaArany;
  final int akkordArany;
  final bool boldText;

  static RecStateRecord fromBytes(Uint8List data) {
    return RecStateRecord(
      bkColor: _readColor(data, 0),
      txtColor: _readColor(data, 4),
      blankColor: _readColor(data, 8),
      hiColor: _readColor(data, 328),
      fontSize: _readIntLE(data, 12),
      titleSize: _readIntLE(data, 16),
      leftIndent: _readIntLE(data, 20),
      spacing100: _readIntLE(data, 24),
      hKey: _readIntLE(data, 28),
      wordToHighlight: _readIntLE(data, 32),
      borderL: _readIntLE(data, 36),
      borderT: _readIntLE(data, 40),
      borderR: _readIntLE(data, 44),
      borderB: _readIntLE(data, 48),
      fontName: _readPascalString(data, 52),
      isBlankPic: _readBool(data, 308),
      autoResize: _readBool(data, 309),
      projecting: _readBool(data, 310),
      showBlankPic: _readBool(data, 311),
      hCenter: _readBool(data, 312),
      vCenter: _readBool(data, 313),
      scholaMode: _readBool(data, 314),
      useAkkord: _readBool(data, 315),
      useKotta: _readBool(data, 316),
      useTransitions: _readBool(data, 317),
      endProgram: _readIntLE(data, 318),
      hideTitle: _readBool(data, 322),
      inverzKotta: _readBool(data, 323),
      bgMode: _readIntLE(data, 324),
      kottaArany: _readIntLE(data, 332),
      akkordArany: _readIntLE(data, 336),
      boldText: _readBool(data, 348),
    );
  }
}

class RecTextRecord {
  const RecTextRecord({
    required this.scholaLine,
    required this.title,
    required this.lines,
  });

  final String scholaLine;
  final String title;
  final List<String> lines;

  static RecTextRecord fromBytes(Uint8List data) {
    final String normalized = utf8
        .decode(data, allowMalformed: true)
        .replaceAll('\r\n', '\r')
        .replaceAll('\n', '\r');
    final List<String> parts = normalized.split('\r');
    final String schola = parts.isNotEmpty ? parts[0] : '';
    final String title = parts.length > 1 ? parts[1] : '';
    final List<String> body =
        parts.length > 2 ? parts.sublist(2).where((e) => e.isNotEmpty).toList() : <String>[];
    return RecTextRecord(scholaLine: schola, title: title, lines: body);
  }
}

class RecImageRecord {
  const RecImageRecord({required this.ext, required this.imageBytes});

  final String ext;
  final Uint8List imageBytes;

  static RecImageRecord fromBytes(Uint8List data) {
    final int extLen = data.isNotEmpty ? data[0].clamp(0, 7) : 0;
    final String ext = extLen > 0 && data.length >= 1 + extLen
        ? String.fromCharCodes(data.sublist(1, 1 + extLen))
        : '';
    final Uint8List bytes = data.length > 8
        ? Uint8List.fromList(data.sublist(8))
        : Uint8List(0);
    return RecImageRecord(ext: ext, imageBytes: bytes);
  }
}

Uint8List encodeScreenSizeRecord({
  required int width,
  required int height,
  required bool korusMode,
}) {
  final Uint8List body = Uint8List(9);
  final ByteData bd = body.buffer.asByteData();
  bd.setInt32(0, width, Endian.little);
  bd.setInt32(4, height, Endian.little);
  body[8] = korusMode ? 1 : 0;
  return body;
}

Uint8List encodeTextRecord({required String title, required List<String> lines}) {
  final List<int> bytes = <int>[13, ...utf8.encode(title)];
  for (final String line in lines) {
    bytes.add(13);
    bytes.addAll(utf8.encode(line));
  }
  return Uint8List.fromList(bytes);
}

Uint8List encodeImageRecord({required Uint8List bytes, required String ext}) {
  final List<int> out = <int>[ext.length.clamp(0, 7)];
  out.addAll(utf8.encode(ext).take(7));
  while (out.length < 8) {
    out.add(0);
  }
  out.addAll(bytes);
  return Uint8List.fromList(out);
}
