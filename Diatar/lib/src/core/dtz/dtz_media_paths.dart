/// Resolves DTZ references against actual ZIP entries, without legacy bases.
class DtzMediaPaths {
  DtzMediaPaths(Iterable<String> files) {
    for (final String file in files) {
      final String path = file.replaceAll('\\', '/');
      if (!isSafe(path)) continue;
      _files.add(path);
      final List<String> parts = path.split('/');
      for (int i = 0; i < parts.length; i++) {
        final String suffix = parts.skip(i).join('/');
        if (_suffixes.containsKey(suffix) && _suffixes[suffix] != path) {
          _suffixes[suffix] = null;
        } else {
          _suffixes[suffix] = path;
        }
      }
    }
  }

  static const String localHeader = ';diatar-local-media-v1';
  final Set<String> _files = <String>{};
  final Map<String, String?> _suffixes = <String, String?>{};

  static bool isSafe(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains(':') &&
      !path.split('/').any((String part) => part == '..' || part == '.');

  String? resolve(String reference, {bool exact = false}) {
    final String path = reference.replaceAll('\\', '/');
    if (!isSafe(path)) return null;
    if (_files.contains(path)) return path;
    if (exact || !_suffixes.containsKey(path)) return null;
    final String? resolved = _suffixes[path];
    if (resolved == null) throw FormatException(path);
    return resolved;
  }

  /// Stores only installed media, relative to the local DTZ's directory.
  /// [music] restricts official packages to their independently managed media.
  String localize(String content, {bool? music}) {
    final List<String> lines = <String>[localHeader];
    final bool exact = content.startsWith(localHeader);
    for (final String line in content.replaceAll('\r\n', '\n').split('\n')) {
      if (line.isEmpty || line == localHeader) continue;
      final String prefix = line[0];
      if (prefix == 'B' || prefix == 'b') continue;
      final bool sound = prefix == 'Z' || prefix == 'z';
      final bool photo = prefix == 'F' || prefix == 'f';
      if (!sound && !photo) {
        lines.add(line);
        continue;
      }
      if (music != null && music != sound) continue;
      final String rest = line.substring(1).trim();
      final int space = rest.indexOf(' ');
      if (space <= 0) continue;
      final String? path = resolve(
        rest.substring(space + 1).trim(),
        exact: exact,
      );
      if (path != null) {
        lines.add('$prefix${rest.substring(0, space)} $path');
      }
    }
    return '${lines.join('\n')}\n';
  }
}
