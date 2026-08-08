import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';

/// A háttérkép (blank) belső tárolása.
///
/// Weben és mobilon a kiválasztott képet nem külső elérési úton tároljuk
/// (az weben blob-URL, Androidon ideiglenes cache lenne), hanem importáljuk
/// a dokumentumok könyvtárába. A könyvtárban mindig legfeljebb egy fájl van.
class BlankImageStore {
  BlankImageStore({
    FileSystem? fileSystem,
    Future<String> Function()? documentsPathProvider,
  }) : _fileSystem = fileSystem ?? FileSystemProvider.instance,
       _documentsPathProvider =
           documentsPathProvider ?? PathHelper.getDocumentsDirectoryPath;

  final FileSystem _fileSystem;
  final Future<String> Function() _documentsPathProvider;

  /// Importálja a kép [bytes] tartalmát a belső tárolóba.
  ///
  /// A korábbi belső fájlt törli (így mindig legfeljebb egy létezik), a
  /// kiterjesztést megtartja. Visszaadja az elérési utat.
  Future<String> import(Uint8List bytes, String ext) async {
    final String root = await _rootPath();
    final Directory dir = _fileSystem.directory(root);
    await dir.create(recursive: true);
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is File) {
        await entity.delete();
      }
    }
    final String normalizedExt = ext.trim().toLowerCase();
    final String path = '$root/blank'
        '${normalizedExt.isEmpty ? '' : '.$normalizedExt'}';
    await _fileSystem.file(path).writeAsBytes(bytes);
    await FileSystemProvider.persistWebFileSystem();
    return path;
  }

  /// Törli a belső háttérképet. Ha nincs beállítva, csendben kihagyja.
  Future<void> delete() async {
    final String root = await _rootPath();
    final Directory dir = _fileSystem.directory(root);
    if (!await dir.exists()) {
      return;
    }
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is File) {
        await entity.delete();
      }
    }
    await FileSystemProvider.persistWebFileSystem();
  }

  /// Visszaadja a kiválasztott fájl képkiterjesztését.
  ///
  /// Androidon a tartalomszolgáltató néha lecsupaszítja a nevet, ezért
  /// fallback-ként a fájlútvonalat is megvizsgáljuk.
  static String resolveImageExtension(XFile file) {
    final String fromName = _extensionOf(file.name);
    if (fromName.isNotEmpty) {
      return fromName;
    }
    return _extensionOf(file.path);
  }

  static String _extensionOf(String value) {
    final String name = value.trim();
    final int dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) {
      return '';
    }
    final String ext = name.substring(dot + 1).toLowerCase();
    return ext.isEmpty ? '' : ext;
  }

  /// A blank fájlokat tartalmazó mappa elérési útja.
  Future<String> _rootPath() async =>
      '${await _documentsPathProvider()}/blank';
}
