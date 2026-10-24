import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';

/// A diasorokba illesztett egyedi képek belső tárolása.
///
/// iOS-en a megnyitó dokumentumválasztó (`UIDocumentPickerViewController`
/// `asCopy: true` módban) a fájlt a `Documents/Inbox` mappába másolja. Az a
/// mappa nem biztos, hogy megmarad: a rendszer alacsony tárhely esetén
/// kitakarítja. A diasor viszont hosszú távon tárolja az elérési utat, ezért a
/// képet a `diatar` adatmappába másoljuk, ami a biztonsági mentés része is —
/// a visszaállított mentésben így a kép is megmarad.
class PickedImageStore {
  PickedImageStore({
    FileSystem? fileSystem,
    Future<String> Function()? documentsPathProvider,
    DateTime Function()? clock,
  }) : _fileSystem = fileSystem ?? FileSystemProvider.instance,
       _documentsPathProvider =
           documentsPathProvider ?? PathHelper.getDocumentsDirectoryPath,
       _clock = clock ?? DateTime.now;

  final FileSystem _fileSystem;
  final Future<String> Function() _documentsPathProvider;
  final DateTime Function() _clock;

  /// A [sourcePath] fájlt a belső tárolóba másolja és visszaadja az új
  /// elérési utat.
  ///
  /// A célfájlnév időbélyeget kap, így több ugyanilyen nevű kép is egymás
  /// mellé kerülhet.
  Future<String> import(String sourcePath) async {
    final Directory root = _fileSystem.directory(await _rootPath());
    await root.create(recursive: true);
    final String target = _fileSystem.path.join(
      root.path,
      '${_clock().millisecondsSinceEpoch}_${baseName(sourcePath)}',
    );
    await _fileSystem.file(sourcePath).copy(target);
    return target;
  }

  /// A képeket tartalmazó belső mappa elérési útja.
  Future<String> _rootPath() async =>
      '${await _documentsPathProvider()}/diatar/picked-images';

  /// A [value] útvonal fájlnév része.
  static String baseName(String value) {
    final String name = value.trim();
    final int slash = name.lastIndexOf(RegExp(r'[/\\]'));
    final String last = slash >= 0 ? name.substring(slash + 1) : name;
    return last.isEmpty ? 'image' : last;
  }
}
