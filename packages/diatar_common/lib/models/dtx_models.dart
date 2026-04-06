class DtxBook {
  const DtxBook({
    required this.fileName,
    required this.title,
    required this.songs,
    this.nick = '',
    this.group = '',
    this.order = 0,
  });

  final String fileName;
  final String title;
  final String nick;
  final String group;
  final int order;
  final List<DtxSong> songs;

  String get displayName => nick.trim().isNotEmpty ? nick : title;
}

class DtxSong {
  const DtxSong({
    required this.title,
    required this.verses,
    this.separator = false,
  });

  final String title;
  final bool separator;
  final List<DtxVerse> verses;
}

class DtxVerse {
  const DtxVerse({required this.name, required this.lines});

  final String name;
  final List<String> lines;
}
