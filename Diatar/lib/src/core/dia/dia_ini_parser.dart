class DiaIniParser {
  const DiaIniParser();

  Map<String, Map<String, String>> parse(String content) {
    final Map<String, Map<String, String>> sections =
        <String, Map<String, String>>{};
    String current = 'main';
    sections[current] = <String, String>{};

    for (final String rawLine in content.split(RegExp(r'\r?\n'))) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        current = line.substring(1, line.length - 1).trim().toLowerCase();
        sections.putIfAbsent(current, () => <String, String>{});
        continue;
      }
      final int eq = line.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      final String key = line.substring(0, eq).trim().toLowerCase();
      final String value = line.substring(eq + 1).trim();
      sections[current]![key] = value;
    }

    return sections;
  }

  List<String> collectLines(Map<String, String> section, int declaredLines) {
    if (declaredLines > 0) {
      final List<String> lines = <String>[];
      for (int i = 0; i < declaredLines; i++) {
        lines.add((section['line$i'] ?? '').trimRight());
      }
      return lines;
    }

    final List<int> indexes =
        section.keys
            .where((String key) => key.startsWith('line'))
            .map((String key) => int.tryParse(key.substring(4)) ?? -1)
            .where((int value) => value >= 0)
            .toList()
          ..sort();
    return indexes
        .map((int i) => (section['line$i'] ?? '').trimRight())
        .toList();
  }
}
