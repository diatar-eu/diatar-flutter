import '../../utils/file_system_provider.dart';

class DiaPathPolicy {
  const DiaPathPolicy();

  String relativeDiaImagePath(String rawPath, Directory diaDir) {
    final String normalized = rawPath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '';
    }

    final bool looksWindowsAbs = RegExp(r'^[a-zA-Z]:/').hasMatch(normalized);
    final bool looksUnixAbs = normalized.startsWith('/');
    if (!looksWindowsAbs && !looksUnixAbs) {
      return normalized;
    }

    final String diaDirNorm = diaDir.path.replaceAll('\\', '/');
    final String diaPrefix = '$diaDirNorm/';
    if (normalized.startsWith(diaPrefix)) {
      return normalized.substring(diaPrefix.length);
    }

    try {
      final File imageFile = FileSystemProvider.instance.file(
        normalized.replaceAll('/', FileSystemProvider.instance.path.separator),
      );
      final File diaFile = FileSystemProvider.instance.file(diaDir.path);
      final String imagePath = imageFile.absolute.path.replaceAll('\\', '/');
      final String basePath = diaFile.absolute.path.replaceAll('\\', '/');

      if (imagePath.startsWith('$basePath/')) {
        return imagePath.substring(basePath.length + 1);
      }
    } catch (_) {}

    return normalized;
  }

  String resolveDiaImagePath(String diaPath, String relOrAbs) {
    final String normalized = relOrAbs.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '';
    }

    final bool looksWindowsAbs = RegExp(r'^[a-zA-Z]:/').hasMatch(normalized);
    final bool looksUnixAbs = normalized.startsWith('/');

    if (looksWindowsAbs || looksUnixAbs) {
      final File absFile = FileSystemProvider.instance.file(
        normalized.replaceAll('/', FileSystemProvider.instance.path.separator),
      );
      if (absFile.existsSync()) {
        return absFile.path;
      }

      final String fileName = fileNameFromPath(normalized);
      final Directory diaDir = FileSystemProvider.instance.file(diaPath).parent;
      final File fallbackFile = FileSystemProvider.instance.file(
        FileSystemProvider.instance.path.join(diaDir.path, fileName),
      );
      if (fallbackFile.existsSync()) {
        return fallbackFile.path;
      }

      return normalized;
    }

    final Directory parent = FileSystemProvider.instance.file(diaPath).parent;
    final String resolvedPath = FileSystemProvider.instance.path.join(
      parent.path,
      normalized.replaceAll('/', FileSystemProvider.instance.path.separator),
    );
    final File relFile = FileSystemProvider.instance.file(resolvedPath);
    if (relFile.existsSync()) {
      return relFile.path;
    }
    return resolvedPath;
  }

  String fileNameFromPath(String rawPath) {
    final String normalized = rawPath.replaceAll('\\', '/');
    final List<String> parts = normalized
        .split('/')
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return normalized;
    }
    return parts.last;
  }

  String stripFileExtension(String fileName) {
    final String trimmed = fileName.trim();
    final int dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0) {
      return trimmed;
    }
    return trimmed.substring(0, dotIndex);
  }
}
