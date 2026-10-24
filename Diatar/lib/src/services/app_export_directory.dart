import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';

/// Az app saját exportmappáját kezeli.
///
/// iOS-en nincs rendszer-mentőablak (a `file_selector` iOS implementációja a
/// `getSavePath`-ot nem valósítja meg), ezért az exportált biztonsági mentések
/// és diasorok a dokumentumok könyvtárának egy dedikált [folderName]
/// almappájába kerülnek. A mappa a Fájlok alkalmazásban a
/// „Saját iPhone → Diatár → export” útvonalon érhető el.
///
/// Az export mappa szándékosan a `diatar` adatmappán **kívül** van: a
/// biztonsági mentés a `diatar` mappát csomagolja, így a külön mappába tett
/// mentés nem kerül bele a saját következő mentésébe.
class AppExportDirectory {
  AppExportDirectory({
    FileSystem? fileSystem,
    Future<String> Function()? documentsPathProvider,
  }) : _fileSystem = fileSystem ?? FileSystemProvider.instance,
       _documentsPathProvider =
           documentsPathProvider ?? PathHelper.getDocumentsDirectoryPath;

  static const String folderName = 'export';

  final FileSystem _fileSystem;
  final Future<String> Function() _documentsPathProvider;

  /// Az export mappa elérési útja; létrehozza, ha még nem létezik.
  Future<String> resolve() async {
    final String documentsPath = await _documentsPathProvider();
    final Directory directory = _fileSystem.directory(
      _fileSystem.path.join(documentsPath, folderName),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  /// A [suggestedName] fájl teljes elérési útja az export mappában.
  ///
  /// A [extensions] első kiterjesztése kerül a fájlnév végére, ha a név még nem
  /// végződik egyiken sem; így a mentőpanel nélküli platformokon is a helyes
  /// kiterjesztéssel készül a fájl.
  Future<String> resolveFilePath({
    required String suggestedName,
    List<String> extensions = const <String>[],
  }) async {
    final String name = _effectiveFileName(suggestedName, extensions);
    return _fileSystem.path.join(await resolve(), name);
  }

  static String _effectiveFileName(
    String suggestedName,
    List<String> extensions,
  ) {
    final String trimmed = suggestedName.trim();
    final String name = trimmed.isEmpty ? 'diatar-export' : trimmed;
    final List<String> normalized = extensions
        .map(
          (String extension) =>
              extension.trim().replaceFirst('.', '').toLowerCase(),
        )
        .where((String extension) => extension.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return name;
    }
    final String lower = name.toLowerCase();
    final bool hasExtension = normalized.any(
      (String extension) => lower.endsWith('.$extension'),
    );
    return hasExtension ? name : '$name.${normalized.first}';
  }
}
