import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class DtxDownloadItem {
  const DtxDownloadItem({
    required this.fileName,
    required this.timestamp,
    required this.size,
    required this.group,
    required this.order,
    required this.longName,
    required this.shortName,
    this.isInstalled = false,
    this.updateAvailable = false,
    this.isOfficial = true,
    this.isUserProvided = false,
  });

  final String fileName;
  final String timestamp;
  final int size;
  final String group;
  final int order;
  final String longName;
  final String shortName;
  final bool isInstalled;
  final bool updateAvailable;
  final bool isOfficial;
  final bool isUserProvided;
}

class DtxDownloadProgress {
  const DtxDownloadProgress({
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

class DtxDownloadSummary {
  const DtxDownloadSummary({
    required this.downloaded,
    required this.skipped,
  });

  final int downloaded;
  final int skipped;
}

class DtxDownloadService {
  static const String _listUrl = 'https://diatar.eu/downloads/enektarak/_list.php';
  static const String _baseUrl = 'https://diatar.eu/downloads/enektarak/';
  static const String _stampPrefix = 'dtx_stamp_';

  Future<List<DtxDownloadItem>> listUpdates({required Directory targetDir}) async {
    final List<DtxDownloadItem> all = await listAll(targetDir: targetDir);
    return all
        .where(
          (DtxDownloadItem item) => item.isOfficial && item.updateAvailable,
        )
        .toList();
  }

  Future<List<DtxDownloadItem>> listAll({required Directory targetDir}) async {
    await targetDir.create(recursive: true);

    final List<_RemoteDtx> remoteList = await _fetchRemoteList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<DtxDownloadItem> items = <DtxDownloadItem>[];

    final Map<String, File> localByName = <String, File>{};
    for (final FileSystemEntity entity in targetDir.listSync()) {
      if (entity is! File) {
        continue;
      }
      final String name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : entity.path;
      if (!name.toLowerCase().endsWith('.dtx')) {
        continue;
      }
      localByName[name] = entity;
    }

    for (final _RemoteDtx item in remoteList) {
      final File? local = localByName.remove(item.fileName);
      final bool installed = local != null;
      final String oldStamp =
          prefs.getString('$_stampPrefix${item.fileName}') ?? '';
      final bool upToDate = installed && oldStamp == item.timestamp;
      items.add(
        DtxDownloadItem(
          fileName: item.fileName,
          timestamp: item.timestamp,
          size: item.size,
          group: item.group,
          order: item.order,
          longName: item.longName,
          shortName: item.shortName,
          isInstalled: installed,
          updateAvailable: !upToDate,
          isOfficial: true,
          isUserProvided: false,
        ),
      );
    }

    for (final MapEntry<String, File> entry in localByName.entries) {
      final String fileName = entry.key;
      final int localSize = entry.value.existsSync()
          ? entry.value.lengthSync()
          : 0;
      items.add(
        DtxDownloadItem(
          fileName: fileName,
          timestamp: '',
          size: localSize,
          group: '',
          order: 0,
          longName: fileName,
          shortName: fileName,
          isInstalled: true,
          updateAvailable: false,
          isOfficial: false,
          isUserProvided: true,
        ),
      );
    }

    items.sort(_compareDownloadItems);
    return items;
  }

  int _compareDownloadItems(DtxDownloadItem a, DtxDownloadItem b) {
    final String aGroup = a.group.trim();
    final String bGroup = b.group.trim();
    final bool aEmpty = aGroup.isEmpty;
    final bool bEmpty = bGroup.isEmpty;
    if (aEmpty != bEmpty) {
      return aEmpty ? 1 : -1;
    }

    final int aGroupPriority = _preferredBookGroupPriority(aGroup);
    final int bGroupPriority = _preferredBookGroupPriority(bGroup);
    if (aGroupPriority != bGroupPriority) {
      return aGroupPriority.compareTo(bGroupPriority);
    }

    final int byGroup = aGroup.toLowerCase().compareTo(bGroup.toLowerCase());
    if (byGroup != 0) {
      return byGroup;
    }

    final int aOrder = a.order <= 0 ? 1 << 30 : a.order;
    final int bOrder = b.order <= 0 ? 1 << 30 : b.order;
    final int byOrder = aOrder.compareTo(bOrder);
    if (byOrder != 0) {
      return byOrder;
    }

    final int byLongName = a.longName.toLowerCase().compareTo(
      b.longName.toLowerCase(),
    );
    if (byLongName != 0) {
      return byLongName;
    }
    return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
  }

  int _preferredBookGroupPriority(String group) {
    switch (group.trim().toLowerCase()) {
      case 'népénekes könyvek':
        return 0;
      case 'mise és liturgia':
        return 1;
      default:
        return 2;
    }
  }

  Future<DtxDownloadSummary> downloadUpdates({
    required Directory targetDir,
    List<DtxDownloadItem>? selected,
    void Function(DtxDownloadProgress progress)? onProgress,
  }) async {
    await targetDir.create(recursive: true);

    final List<DtxDownloadItem> updates =
      (selected ?? await listUpdates(targetDir: targetDir))
        .where((DtxDownloadItem item) => item.isOfficial)
        .toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    int downloaded = 0;
    int skipped = 0;

    for (int i = 0; i < updates.length; i++) {
      final DtxDownloadItem item = updates[i];
      final File local = File('${targetDir.path}/${item.fileName}');
      final String oldStamp = prefs.getString('$_stampPrefix${item.fileName}') ?? '';
      final bool upToDate = local.existsSync() && oldStamp == item.timestamp;
      if (upToDate) {
        skipped++;
        continue;
      }

      await _downloadOne(
        item: _RemoteDtx(
          fileName: item.fileName,
          timestamp: item.timestamp,
          size: item.size,
          group: item.group,
          order: item.order,
          longName: item.longName,
          shortName: item.shortName,
        ),
        targetFile: local,
        currentFile: i + 1,
        totalFiles: updates.length,
        onProgress: onProgress,
      );
      await prefs.setString('$_stampPrefix${item.fileName}', item.timestamp);
      downloaded++;
    }

    return DtxDownloadSummary(downloaded: downloaded, skipped: skipped);
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
      final File local = File('${targetDir.path}/$name');
      if (await local.exists()) {
        await local.delete();
        deleted++;
      }
      await prefs.remove('$_stampPrefix$name');
    }
    return deleted;
  }

  Future<List<_RemoteDtx>> _fetchRemoteList() async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(_listUrl));
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} while loading DTX list');
      }

      final String content = await response.transform(utf8.decoder).join();
      final List<_RemoteDtx> result = <_RemoteDtx>[];
      for (final String line in const LineSplitter().convert(content)) {
        final _RemoteDtx? parsed = _parseListLine(line.trim());
        if (parsed != null) {
          result.add(parsed);
        }
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  _RemoteDtx? _parseListLine(String line) {
    if (line.isEmpty) {
      return null;
    }
    final List<String> cells = _splitCsv(line);
    if (cells.length < 3) {
      return null;
    }

    final String fileName = cells[0].trim();
    if (!fileName.toLowerCase().endsWith('.dtx')) {
      return null;
    }

    final int size = int.tryParse(cells[1].trim()) ?? 0;
    final String timestamp = cells[2].trim();
    if (timestamp.isEmpty) {
      return null;
    }

    final String group = cells.length > 3 ? cells[3].trim() : '';
    final int order = cells.length > 4 ? int.tryParse(cells[4].trim()) ?? 0 : 0;
    final String longName =
        cells.length > 5 && cells[5].trim().isNotEmpty
        ? cells[5].trim()
        : fileName;
    final String shortName = cells.length > 6 ? cells[6].trim() : '';

    return _RemoteDtx(
      fileName: fileName,
      timestamp: timestamp,
      size: size,
      group: group,
      order: order,
      longName: longName,
      shortName: shortName,
    );
  }

  List<String> _splitCsv(String line) {
    final List<String> out = <String>[];
    final StringBuffer cell = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && ch == ',') {
        out.add(cell.toString());
        cell.clear();
        continue;
      }
      cell.write(ch);
    }
    out.add(cell.toString());
    return out;
  }

  Future<void> _downloadOne({
    required _RemoteDtx item,
    required File targetFile,
    required int currentFile,
    required int totalFiles,
    void Function(DtxDownloadProgress progress)? onProgress,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl${item.fileName}');
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} while downloading ${item.fileName}');
      }

      final int totalBytes = response.contentLength > 0 ? response.contentLength : item.size;
      int received = 0;
      final File tmp = File('${targetFile.path}.tmp');
      final IOSink sink = tmp.openWrite();
      await for (final List<int> chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          DtxDownloadProgress(
            currentFile: currentFile,
            totalFiles: totalFiles,
            fileName: item.fileName,
            receivedBytes: received,
            totalBytes: totalBytes,
          ),
        );
      }
      await sink.close();

      if (targetFile.existsSync()) {
        await targetFile.delete();
      }
      await tmp.rename(targetFile.path);
    } finally {
      client.close(force: true);
    }
  }
}

class _RemoteDtx {
  const _RemoteDtx({
    required this.fileName,
    required this.timestamp,
    required this.size,
    required this.group,
    required this.order,
    required this.longName,
    required this.shortName,
  });

  final String fileName;
  final String timestamp;
  final int size;
  final String group;
  final int order;
  final String longName;
  final String shortName;
}
