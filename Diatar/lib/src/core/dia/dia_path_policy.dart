import 'dart:io';

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
      final File imageFile = File(
        normalized.replaceAll('/', Platform.pathSeparator),
      );
      final File diaFile = File(diaDir.path);
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
      final File absFile = File(
        normalized.replaceAll('/', Platform.pathSeparator),
      );
      if (absFile.existsSync()) {
        return absFile.path;
      }

      final String fileName = fileNameFromPath(normalized);
      final Directory diaDir = File(diaPath).parent;
      final File fallbackFile = File(
        '${diaDir.path}${Platform.pathSeparator}$fileName',
      );
      if (fallbackFile.existsSync()) {
        return fallbackFile.path;
      }

      return normalized;
    }

    final Directory parent = File(diaPath).parent;
    final String resolvedPath =
        '${parent.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
    final File relFile = File(resolvedPath);
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
