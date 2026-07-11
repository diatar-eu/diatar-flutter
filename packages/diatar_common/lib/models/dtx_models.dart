class DtxBook {
  const DtxBook({
    required this.fileName,
    required this.title,
    required this.songs,
    this.nick = '',
    this.group = '',
    this.order = 0,
    this.useSound = true,
  });

  final String fileName;
  final String title;
  final String nick;
  final String group;
  final int order;
  final List<DtxSong> songs;
  final bool useSound;

  String get displayName => nick.trim().isNotEmpty ? nick : title;
}

class DtxSong {
  const DtxSong({
    required this.title,
    required this.verses,
    this.separator = false,
    this.useSound = true,
  });

  final String title;
  final bool separator;
  final List<DtxVerse> verses;
  final bool useSound;
}

class DtxVerse {
  const DtxVerse({
    required this.name,
    required this.lines,
    this.diaId,
    this.soundFilePath,
    this.fotoFilePath,
    this.forwardMS = 0,
  });

  final String name;
  final List<String> lines;
  final String? diaId;
  final String? soundFilePath;
  final String? fotoFilePath;
  final int forwardMS;
}