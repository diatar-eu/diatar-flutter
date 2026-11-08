import 'dart:convert';
import 'dart:io' show IOSink;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dtz/dtz_media_paths.dart';
import '../utils/file_system_provider.dart';
import '../utils/path_helper.dart';
import 'streaming_zip_service.dart';

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

enum DtzDownloadPhase {
  listing,
  downloading,
  extracting,
  checking,
  writing,
  deleting,
  cleanup,
  saving,
  loadingBooks,
  loadingLibrary,
  indexing,
  settings,
}

class DtzDownloadProgress {
  const DtzDownloadProgress({
    this.currentFile = 0,
    this.totalFiles = 0,
    this.fileName = '',
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.phase = DtzDownloadPhase.downloading,
    this.currentEntry = 0,
    this.totalEntries = 0,
    this.entryName = '',
  });

  final int currentFile;
  final int totalFiles;
  final String fileName;
  final int receivedBytes;
  final int totalBytes;
  final DtzDownloadPhase phase;
  final int currentEntry;
  final int totalEntries;
  final String entryName;

  bool get isDeterminate => switch (phase) {
    DtzDownloadPhase.downloading ||
    DtzDownloadPhase.extracting => totalBytes > 0,
    DtzDownloadPhase.checking => totalEntries > 0,
    _ => false,
  };

  double get fraction {
    if (phase == DtzDownloadPhase.checking && totalEntries > 0) {
      return (currentEntry / totalEntries).clamp(0, 1);
    }
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
  static const StreamingZipService _zipService = StreamingZipService();

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
        if (oldStamp != entryForName.timestamp ||
            (name != dtzName && !_isZipCurrent(name, entryForName, prefs))) {
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
    bool force = false,
    void Function(DtzDownloadProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const DtzDownloadProgress(phase: DtzDownloadPhase.listing),
    );
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

    final Set<String> pendingDtzs = <String>{};
    final Set<String> pendingZips = <String>{};
    for (final DtzDownloadItem item in toDownload) {
      final File dtzFile = FileSystemProvider.instance.file(
        '${targetDir.path}/${item.fileName}',
      );
      if (force ||
          await _needsDownload(dtzFile, item.fileName, item.timestamp, prefs)) {
        pendingDtzs.add(item.fileName);
      }
      for (final String zip in item.zips) {
        final _RemoteEntry? entry = remote[zip];
        if (entry != null && (force || !_isZipCurrent(zip, entry, prefs))) {
          pendingZips.add(zip);
        }
      }
    }
    final int totalDownloads = pendingDtzs.length + pendingZips.length;
    int currentDownload = 0;
    int downloaded = 0;
    int skipped = 0;
    final Set<String> handledZips = <String>{};
    final int total = toDownload.length;

    for (int i = 0; i < toDownload.length; i++) {
      final DtzDownloadItem item = toDownload[i];
      final int currentFile = i + 1;
      bool neededSomething = false;
      final Set<String> installedFiles = <String>{};

      final File dtzFile = FileSystemProvider.instance.file(
        '${targetDir.path}/${item.fileName}',
      );
      if (pendingDtzs.remove(item.fileName)) {
        await prefs.remove('$_stampPrefix${item.fileName}');
        await _downloadOne(
          url: Uri.parse('$_dtzBaseUrl${item.fileName}'),
          fileName: item.fileName,
          targetFile: dtzFile,
          currentFile: ++currentDownload,
          totalFiles: totalDownloads,
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
          installedFiles.addAll(
            prefs.getStringList('$_zipContentsPrefix$zip') ?? const <String>[],
          );
          continue;
        }
        handledZips.add(zip);

        final File zipFile = FileSystemProvider.instance.file(
          '${targetDir.path}/$zip',
        );
        if (pendingZips.remove(zip)) {
          await prefs.remove('$_stampPrefix$zip');
          await _downloadOne(
            url: zipEntry.url == null
                ? Uri.parse('$_scoreZipBaseUrl$zip')
                : Uri.parse(zipEntry.url!),
            fileName: zip,
            targetFile: zipFile,
            currentFile: ++currentDownload,
            totalFiles: totalDownloads,
            onProgress: onProgress,
          );
          final Stopwatch progressClock = Stopwatch()..start();
          String lastEntry = '';
          onProgress?.call(
            DtzDownloadProgress(
              phase: DtzDownloadPhase.extracting,
              currentFile: currentFile,
              totalFiles: total,
              fileName: zip,
            ),
          );
          if (onProgress != null) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
          final List<String> extractedFiles = await _zipService.extract(
            zipFile.path,
            targetDirectory: targetDir,
            onProgress: (StreamingZipProgress progress) {
              if (progress.entryName == lastEntry &&
                  progressClock.elapsedMilliseconds < 100 &&
                  !progress.entryComplete &&
                  progress.writtenBytes < progress.totalBytes) {
                return;
              }
              lastEntry = progress.entryName;
              progressClock.reset();
              onProgress?.call(
                DtzDownloadProgress(
                  phase: DtzDownloadPhase.extracting,
                  currentFile: currentFile,
                  totalFiles: total,
                  fileName: zip,
                  currentEntry:
                      (progress.completedEntries +
                              (progress.entryComplete ? 0 : 1))
                          .clamp(0, progress.totalEntries),
                  totalEntries: progress.totalEntries,
                  entryName: progress.entryName,
                  receivedBytes: progress.writtenBytes,
                  totalBytes: progress.totalBytes,
                ),
              );
            },
          );
          onProgress?.call(
            DtzDownloadProgress(
              phase: DtzDownloadPhase.writing,
              currentFile: currentFile,
              totalFiles: total,
              fileName: zip,
            ),
          );
          if (onProgress != null) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
          await prefs.setStringList('$_zipContentsPrefix$zip', extractedFiles);
          await prefs.setInt('${_stampPrefix}size_$zip', zipEntry.size);
          await prefs.setString('$_stampPrefix$zip', zipEntry.timestamp);
          onProgress?.call(
            DtzDownloadProgress(
              phase: DtzDownloadPhase.cleanup,
              currentFile: currentFile,
              totalFiles: total,
              fileName: zip,
            ),
          );
          if (onProgress != null) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
          await zipFile.delete();
          neededSomething = true;
        }
        installedFiles.addAll(
          prefs.getStringList('$_zipContentsPrefix$zip') ?? const <String>[],
        );
      }

      final Set<String> existingFiles = <String>{};
      int checkedFiles = 0;
      final Stopwatch checkClock = Stopwatch()..start();
      onProgress?.call(
        DtzDownloadProgress(
          phase: DtzDownloadPhase.checking,
          currentFile: currentFile,
          totalFiles: total,
          fileName: item.fileName,
          totalEntries: installedFiles.length,
        ),
      );
      for (final String path in installedFiles) {
        if (DtzMediaPaths.isSafe(path) &&
            await FileSystemProvider.instance
                .file('${targetDir.path}/$path')
                .exists()) {
          existingFiles.add(path);
        }
        checkedFiles++;
        if (checkClock.elapsedMilliseconds >= 100 ||
            checkedFiles == installedFiles.length) {
          onProgress?.call(
            DtzDownloadProgress(
              phase: DtzDownloadPhase.checking,
              currentFile: currentFile,
              totalFiles: total,
              fileName: item.fileName,
              currentEntry: checkedFiles,
              totalEntries: installedFiles.length,
              entryName: path,
            ),
          );
          checkClock.reset();
          if (onProgress != null) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
        }
      }
      onProgress?.call(
        DtzDownloadProgress(
          phase: DtzDownloadPhase.writing,
          currentFile: currentFile,
          totalFiles: total,
          fileName: item.fileName,
        ),
      );
      if (onProgress != null) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      await dtzFile.writeAsString(
        DtzMediaPaths(existingFiles).localize(
          await dtzFile.readAsString(),
          music: _directoryName == 'Music',
        ),
      );

      if (neededSomething) {
        downloaded++;
      } else {
        skipped++;
      }
    }

    onProgress?.call(
      const DtzDownloadProgress(phase: DtzDownloadPhase.cleanup),
    );
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

    onProgress?.call(const DtzDownloadProgress(phase: DtzDownloadPhase.saving));
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
      await prefs.remove('${_stampPrefix}size_$name');
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
        .where(
          (DtzDownloadItem item) =>
              item.isInstalled && !packageNames.contains(item.fileName),
        )
        .expand((DtzDownloadItem item) => item.zipNames)
        .toSet();
    final Set<String> zipsToDelete = packages
        .where((DtzDownloadItem item) => packageNames.contains(item.fileName))
        .expand((DtzDownloadItem item) => item.zipNames)
        .where((String zip) => !zipsStillUsed.contains(zip))
        .toSet();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<File> localFiles =
        (await targetDir.list(recursive: true).toList())
            .whereType<File>()
            .toList();
    final DtzMediaPaths paths = DtzMediaPaths(
      localFiles.map(
        (File file) => file.path
            .replaceAll('\\', '/')
            .substring(targetDir.path.replaceAll('\\', '/').length + 1),
      ),
    );
    final Map<String, DtzMediaPaths> pathsByDirectory = <String, DtzMediaPaths>{
      targetDir.path: paths,
    };
    final Set<String> mediaToDelete = <String>{};
    final Set<String> mediaStillUsed = <String>{};
    for (final File file in localFiles) {
      if (!file.path.toLowerCase().endsWith('.dtz')) continue;
      final String name = file.uri.pathSegments.last;
      final String directory = file.parent.path.replaceAll('\\', '/');
      final String root = targetDir.path.replaceAll('\\', '/');
      final String relativeDirectory = directory == root
          ? ''
          : '${directory.substring(root.length + 1)}/';
      final DtzMediaPaths filePaths = pathsByDirectory.putIfAbsent(
        file.parent.path,
        () => DtzMediaPaths(
          localFiles
              .map((File file) => file.path.replaceAll('\\', '/'))
              .where((String path) => path.startsWith('$directory/'))
              .map((String path) => path.substring(directory.length + 1)),
        ),
      );
      final Set<String> references = filePaths
          .references(await file.readAsString())
          .map((String path) => '$relativeDirectory$path')
          .toSet();
      if (file.parent.path == targetDir.path && packageNames.contains(name)) {
        mediaToDelete.addAll(references);
      } else {
        mediaStillUsed.addAll(references);
      }
    }
    int deleted = await deleteLocalFiles(
      targetDir: targetDir,
      fileNames: <String>[...packageNames, ...zipsToDelete],
    );
    for (final String zip in zipsToDelete) {
      mediaToDelete.addAll(
        prefs.getStringList('$_zipContentsPrefix$zip') ?? const <String>[],
      );
      await prefs.remove('$_zipContentsPrefix$zip');
    }
    for (final String relativePath in mediaToDelete.difference(
      mediaStillUsed,
    )) {
      if (!DtzMediaPaths.isSafe(relativePath)) continue;
      final File local = FileSystemProvider.instance.file(
        '${targetDir.path}/$relativePath',
      );
      if (await local.exists()) {
        await local.delete();
        deleted++;
      }
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

  bool _isZipCurrent(
    String name,
    _RemoteEntry entry,
    SharedPreferences prefs,
  ) =>
      prefs.getString('$_stampPrefix$name') == entry.timestamp &&
      prefs.getInt('${_stampPrefix}size_$name') == entry.size &&
      prefs.getStringList('$_zipContentsPrefix$name') != null;

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
    onProgress?.call(
      DtzDownloadProgress(
        currentFile: currentFile,
        totalFiles: totalFiles,
        fileName: fileName,
      ),
    );
    final http.StreamedResponse response = await _client.send(
      http.Request('GET', url),
    );
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
    final IOSink sink = targetFile.openWrite();
    try {
      await for (final List<int> bytes in response.stream) {
        received += bytes.length;
        sink.add(bytes);
        await sink.flush();
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
    } finally {
      await sink.close();
    }
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
