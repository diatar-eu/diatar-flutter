class DtxImportPolicy {
  const DtxImportPolicy();

  String displayNameForImportedPath({
    required String directName,
    required String path,
    required int index,
  }) {
    final String trimmedDirectName = directName.trim();
    if (trimmedDirectName.isNotEmpty) {
      return trimmedDirectName;
    }

    final Uri? parsed = Uri.tryParse(path);
    if (parsed != null && parsed.pathSegments.isNotEmpty) {
      final String last = Uri.decodeComponent(parsed.pathSegments.last).trim();
      if (last.isNotEmpty) {
        return last;
      }
    }

    final String normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isNotEmpty) {
      final List<String> segments = normalized.split('/');
      final String last = segments.isNotEmpty ? segments.last.trim() : '';
      if (last.isNotEmpty) {
        return last;
      }
    }

    return 'imported_${index + 1}.dtx';
  }

  String safeImportFileName(String value, int index) {
    String name = value.trim();
    if (name.isEmpty) {
      name = 'imported_${index + 1}.dtx';
    }
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!name.toLowerCase().endsWith('.dtx')) {
      name = '$name.dtx';
    }
    return name;
  }
}
