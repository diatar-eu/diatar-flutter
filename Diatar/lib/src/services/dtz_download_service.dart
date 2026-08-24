import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';

class DtzDownloadItem {
  const DtzDownloadItem({
    required this.fileName,
    required this.timestamp,
    required this.size,
    required this.title,
    required this.zips,
    this.isInstalled = false,
    this.updateAvailable = false,
    this.isOfficial = true,
  });

  final String fileName;
  final String timestamp;
  final int size;
  final String title;
  final List<String> zips;
  final bool isInstalled;
  final bool updateAvailable;
  final bool isOfficial;

  String get longName => fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

  List<String> get zipNames => zips;
}

class DtzDownloadProgress {
  const DtzDownloadProgress({
    required this.currentFile,
    required this.totalFiles,
    required this.fileName,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int currentFile;
  final int totalFiles;
  final String fileName;
  final int receivedBytes;
  final int totalBytes;

  double get fraction {
    if (totalBytes <= 0) {
      return 0;
    }
    return (receivedBytes / totalBytes).clamp(0, 1);
  }
}

class DtzDownloadSummary {
  const DtzDownloadSummary({required this.downloaded, required this.skipped});

  final int downloaded;
  final int skipped;
}

class DtzManageItem {
  const DtzManageItem({required this.item, required this.excluded});

  final DtzDownloadItem item;
  final bool excluded;
}

class DtzDownloadService {
  DtzDownloadService({http.Client? client})
    : _client = client ?? http.Client(),
      _zipListUrl = _scoreZipListUrl,
      _mediaMapUrl = _scoreMediaMapUrl,
      _directoryName = '',
      _stampPrefix = 'dtz_stamp_',
      _zipContentsPrefix = 'dtz_zip_contents_';

  DtzDownloadService.music({http.Client? client})
    : _client = client ?? http.Client(),
      _zipListUrl = _musicZipListUrl,
      _mediaMapUrl = _musicMediaMapUrl,
      _directoryName = 'Music',
      _stampPrefix = 'music_stamp_',
      _zipContentsPrefix = 'music_zip_contents_';

  final http.Client _client;

  static const String _dtzListUrl = 'https://diatar.eu/downloads/dtz/_list.php';
  static const String _dtzBaseUrl = 'https://diatar.eu/downloads/dtz/';
  static const String _scoreZipListUrl =
      'https://diatar.eu/downloads/kottak/_list.php';
  static const String _scoreZipBaseUrl = 'https://diatar.eu/downloads/kottak/';
  static const String _scoreMediaMapUrl =
      'https://diatar.eu/downloads/kottak/kottak.txt';
  static const String _musicZipListUrl =
      'https://diatar.eu/downloads/zene/_list.php';
  static const String _musicMediaMapUrl =
      'https://diatar.eu/downloads/zene/zenek.txt';
  final String _zipListUrl;
  final String _mediaMapUrl;
  final String _directoryName;
  final String _stampPrefix;
  final String _zipContentsPrefix;

  Future<Directory> resolveDirectory() async {
    final String docsPath = await PathHelper.getDocumentsDirectoryPath();
    final String basePath = '$docsPath/diatar/DTZs';
    return FileSystemProvider.instance.directory(
      _directoryName.isEmpty ? basePath : '$basePath/$_directoryName',
    );
  }

  Future<List<DtzDownloadItem>> listAll({
    required Directory targetDir,
    Map<String, String> dtxTitles = const <String, String>{},
  }) async {
    await targetDir.create(recursive: true);

    final List<_RemoteEntry> remoteDtzList = await _fetchRemoteList(
      _dtzListUrl,
    );
    final List<_RemoteEntry> remoteZipList = await _fetchRemoteList(
      _zipListUrl,
    );
    final Map<String, List<String>> kottakMap = await _fetchMediaMap();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final Map<String, _RemoteEntry> remoteByName = <String, _RemoteEntry>{
      for (final _RemoteEntry e in <_RemoteEntry>[
        ...remoteDtzList,
        ...remoteZipList,
      ])
        e.fileName: e,
    };

    final List<DtzDownloadItem> items = <DtzDownloadItem>[];

    for (final MapEntry<String, List<String>> entry in kottakMap.entries) {
      final String dtzName = entry.key;
      final _RemoteEntry? dtzEntry = remoteByName[dtzName];
      if (dtzEntry == null) {
        continue;
      }

      final List<String> zips = entry.value
          .where((String z) => remoteByName.containsKey(z))
          .toList();

      final File dtzFile = FileSystemProvider.instance.file(
        '${targetDir.path}/$dtzName',
      );
      final bool installed = await dtzFile.exists();

      final List<String> allFiles = <String>[dtzName, ...zips];
      bool upToDate = installed;
      for (final String name in allFiles) {
        final String oldStamp = prefs.getString('$_stampPrefix$name') ?? '';
        final _RemoteEntry entryForName = name == dtzName
            ? dtzEntry
            : remoteByName[name]!;
        if (oldStamp != entryForName.timestamp) {
          upToDate = false;
          break;
        }
      }

      final String baseName = dtzName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final String title = (dtxTitles[baseName] ?? baseName).trim();

      items.add(
        DtzDownloadItem(
          fileName: dtzName,
          timestamp: dtzEntry.timestamp,
          size: dtzEntry.size,
          title: title,
          zips: zips,
          isInstalled: installed,
          updateAvailable: !upToDate,
          isOfficial: true,
        ),
      );
    }

    items.sort(
      (DtzDownloadItem a, DtzDownloadItem b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return items;
  }

  Future<DtzDownloadSummary> downloadUpdates({
    required Directory targetDir,
    List<DtzDownloadItem>? selected,
    void Function(DtzDownloadProgress progress)? onProgress,
  }) async {
    await targetDir.create(recursive: true);

    final List<DtzDownloadItem> items =
        selected ?? await listAll(targetDir: targetDir);
    final List<DtzDownloadItem> toDownload = items
        .where((DtzDownloadItem i) => i.isOfficial)
        .toList();

    final List<_RemoteEntry> remoteDtzList = await _fetchRemoteList(
      _dtzListUrl,
    );
    final List<_RemoteEntry> remoteZipList = await _fetchRemoteList(
      _zipListUrl,
    );
    final Map<String, _RemoteEntry> remote = <String, _RemoteEntry>{
      for (final _RemoteEntry e in <_RemoteEntry>[
        ...remoteDtzList,
        ...remoteZipList,
      ])
        e.fileName: e,
    };
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    int downloaded = 0;
    int skipped = 0;
    final Set<String> handledZips = <String>{};
    final int total = toDownload.length;

    for (int i = 0; i < toDownload.length; i++) {
      final DtzDownloadItem item = toDownload[i];
      final int currentFile = i + 1;
      bool neededSomething = false;

      final File dtzFile = FileSystemProvider.instance.file(
        '${targetDir.path}/${item.fileName}',
      );
      if (await _needsDownload(dtzFile, item.fileName, item.timestamp, prefs)) {
        await _downloadOne(
          url: Uri.parse('$_dtzBaseUrl${item.fileName}'),
          fileName: item.fileName,
          targetFile: dtzFile,
          currentFile: currentFile,
          totalFiles: total,
          onProgress: onProgress,
        );
        await prefs.setString('$_stampPrefix${item.fileName}', item.timestamp);
        neededSomething = true;
      }

      for (final String zip in item.zips) {
        final _RemoteEntry? zipEntry = remote[zip];
        if (zipEntry == null) {
          continue;
        }
        if (handledZips.contains(zip)) {
          continue;
        }
        handledZips.add(zip);

        final File zipFile = FileSystemProvider.instance.file(
          '${targetDir.path}/$zip',
        );
        if (await _needsDownload(zipFile, zip, zipEntry.timestamp, prefs)) {
          await _downloadOne(
            url: zipEntry.url == null
                ? Uri.parse('$_scoreZipBaseUrl$zip')
                : Uri.parse(zipEntry.url!),
            fileName: zip,
            targetFile: zipFile,
            currentFile: currentFile,
            totalFiles: total,
            onProgress: onProgress,
          );
          final List<String> extractedFiles = await _extractZip(
            zipFile,
            targetDir,
          );
          await zipFile.delete();
          await prefs.setString('$_stampPrefix$zip', zipEntry.timestamp);
          await prefs.setStringList('$_zipContentsPrefix$zip', extractedFiles);
          neededSomething = true;
        }
      }

      if (neededSomething) {
        downloaded++;
      } else {
        skipped++;
      }
    }

    // Remove the downloaded zip archives after extraction to save disk space.
    // Only zips that were successfully extracted (have a stamp) are removed,
    // which also cleans up leftovers from previous runs.
    try {
      final List<FileSystemEntity> existing = await targetDir.list().toList();
      for (final FileSystemEntity entity in existing) {
        if (entity is! File) {
          continue;
        }
        final String name = entity.uri.pathSegments.lastWhere(
          (String s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (!name.toLowerCase().endsWith('.zip')) {
          continue;
        }
        final String stamp = prefs.getString('$_stampPrefix$name') ?? '';
        if (stamp.isNotEmpty) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Ignore cleanup errors; extracted content is already in place.
    }

    await FileSystemProvider.persistWebFileSystem();

    return DtzDownloadSummary(downloaded: downloaded, skipped: skipped);
  }

  Future<int> deleteLocalFiles({
    required Directory targetDir,
    required Iterable<String> fileNames,
  }) async {
    await targetDir.create(recursive: true);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int deleted = 0;
    final Set<String> uniqueNames = fileNames
        .map((String name) => name.trim())
        .where((String name) => name.isNotEmpty)
        .toSet();
    for (final String name in uniqueNames) {
      final File local = FileSystemProvider.instance.file(
        '${targetDir.path}/$name',
      );
      if (await local.exists()) {
        await local.delete();
        deleted++;
      }
      await prefs.remove('$_stampPrefix$name');
    }

    await FileSystemProvider.persistWebFileSystem();

    return deleted;
  }

  Future<int> deletePackages({
    required Directory targetDir,
    required Iterable<DtzDownloadItem> itemsToDelete,
    required Iterable<DtzDownloadItem> allItems,
  }) async {
    await targetDir.create(recursive: true);
    final Set<String> packageNames = itemsToDelete
        .map((DtzDownloadItem item) => item.fileName.trim())
        .where((String name) => name.isNotEmpty)
        .toSet();
    if (packageNames.isEmpty) {
      return 0;
    }

    final List<DtzDownloadItem> packages = allItems.toList();
    final Set<String> zipsStillUsed = packages
        .where((DtzDownloadItem item) => !packageNames.contains(item.fileName))
        .expand((DtzDownloadItem item) => item.zipNames)
        .toSet();
    final Set<String> zipsToDelete = packages
        .where((DtzDownloadItem item) => packageNames.contains(item.fileName))
        .expand((DtzDownloadItem item) => item.zipNames)
        .where((String zip) => !zipsStillUsed.contains(zip))
        .toSet();

    int deleted = await deleteLocalFiles(
      targetDir: targetDir,
      fileNames: <String>[...packageNames, ...zipsToDelete],
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String zip in zipsToDelete) {
      final List<String> extractedFiles =
          prefs.getStringList('$_zipContentsPrefix$zip') ?? const <String>[];
      for (final String relativePath in extractedFiles) {
        final File local = FileSystemProvider.instance.file(
          '${targetDir.path}/$relativePath',
        );
        if (await local.exists()) {
          await local.delete();
          deleted++;
        }
      }
      await prefs.remove('$_zipContentsPrefix$zip');
    }

    await FileSystemProvider.persistWebFileSystem();
    return deleted;
  }

  Future<bool> _needsDownload(
    File local,
    String name,
    String timestamp,
    SharedPreferences prefs,
  ) async {
    final String oldStamp = prefs.getString('$_stampPrefix$name') ?? '';
    return !(await local.exists() && oldStamp == timestamp);
  }

  Future<List<_RemoteEntry>> _fetchRemoteList(String url) async {
    final http.Response response = await _client.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode} while loading $url');
    }

    final String content = utf8.decode(response.bodyBytes);
    final List<_RemoteEntry> result = <_RemoteEntry>[];
    for (final String line in const LineSplitter().convert(content)) {
      final _RemoteEntry? parsed = _parseListLine(line.trim());
      if (parsed != null) {
        result.add(parsed);
      }
    }
    return result;
  }

  _RemoteEntry? _parseListLine(String line) {
    if (line.isEmpty) {
      return null;
    }
    final List<String> cells = line.split(',');
    if (cells.length < 3) {
      return null;
    }

    final String source = cells[0].trim();
    final Uri? sourceUri = Uri.tryParse(source);
    final String fileName = sourceUri != null && sourceUri.hasScheme
        ? sourceUri.pathSegments.lastOrNull ?? ''
        : source;
    if (!fileName.toLowerCase().endsWith('.dtz') &&
        !fileName.toLowerCase().endsWith('.zip')) {
      return null;
    }

    final int size = int.tryParse(cells[1].trim()) ?? 0;
    final String timestamp = cells[2].trim();
    if (timestamp.isEmpty) {
      return null;
    }

    return _RemoteEntry(
      fileName: fileName,
      size: size,
      timestamp: timestamp,
      url: sourceUri != null && sourceUri.hasScheme ? source : null,
    );
  }

  Future<Map<String, List<String>>> _fetchMediaMap() async {
    final http.Response response = await _client.get(Uri.parse(_mediaMapUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP ${response.statusCode} while loading $_mediaMapUrl',
      );
    }

    final String content = utf8.decode(response.bodyBytes);
    final Map<String, List<String>> map = <String, List<String>>{};

    for (final String line in const LineSplitter().convert(content)) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final int eq = trimmed.indexOf('=');
      final String dtz;
      final String rest;
      if (eq >= 0) {
        dtz = trimmed.substring(0, eq).trim();
        rest = trimmed.substring(eq + 1).trim();
      } else {
        dtz = trimmed;
        rest = '';
      }

      if (!dtz.toLowerCase().endsWith('.dtz')) {
        continue;
      }

      final List<String> zips = rest
          .split(',')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      map[dtz] = zips;
    }

    return map;
  }

  Future<void> _downloadOne({
    required Uri url,
    required String fileName,
    required File targetFile,
    required int currentFile,
    required int totalFiles,
    void Function(DtzDownloadProgress progress)? onProgress,
  }) async {
    final http.Response response = await _client.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP ${response.statusCode} while downloading $fileName',
      );
    }

    final int totalBytes =
        (response.contentLength != null && response.contentLength! > 0)
        ? response.contentLength!
        : 0;
    int received = 0;
    final List<int> bytes = response.bodyBytes;
    const int chunkSize = 64 * 1024;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      received += (i + chunkSize < bytes.length ? chunkSize : bytes.length - i);
      onProgress?.call(
        DtzDownloadProgress(
          currentFile: currentFile,
          totalFiles: totalFiles,
          fileName: fileName,
          receivedBytes: received,
          totalBytes: totalBytes,
        ),
      );
    }

    await targetFile.writeAsBytes(bytes);
  }

  Future<List<String>> _extractZip(File zipFile, Directory targetDir) async {
    final List<int> bytes = await zipFile.readAsBytes();
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final List<String> extractedFiles = <String>[];
    for (final ArchiveFile file in archive) {
      if (!file.isFile) {
        continue;
      }
      final String normalized = file.name.replaceAll('\\', '/');
      if (normalized.startsWith('/') ||
          normalized.startsWith('../') ||
          normalized.contains('/../')) {
        continue;
      }
      final File outFile = FileSystemProvider.instance.file(
        '${targetDir.path}/$normalized',
      );
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content);
      extractedFiles.add(normalized);
    }
    return extractedFiles;
  }
}

class _RemoteEntry {
  const _RemoteEntry({
    required this.fileName,
    required this.size,
    required this.timestamp,
    this.url,
  });

  final String fileName;
  final int size;
  final String timestamp;
  final String? url;
}
