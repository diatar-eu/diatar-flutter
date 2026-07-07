import 'dart:convert';
import 'dart:io';

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import '../core/dtx/dtx_import_policy.dart';

class DtxLibraryImportResult {
  const DtxLibraryImportResult({
    required this.importedCount,
    required this.importedFileNames,
    required this.failures,
  });

  final int importedCount;
  final Set<String> importedFileNames;
  final List<String> failures;
}

class DtxLibraryService {
  const DtxLibraryService({
    required DtxParser parser,
    DtxImportPolicy importPolicy = const DtxImportPolicy(),
  }) : _parser = parser,
       _importPolicy = importPolicy;

  final DtxParser _parser;
  final DtxImportPolicy _importPolicy;

  Future<Directory> resolveDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/diatar/DTXs');
  }

  Future<List<DtxBook>> loadBooks() async {
    final Directory dtxDir = await resolveDirectory();
    final List<DtxBook> loaded = <DtxBook>[];

    if (!await dtxDir.exists()) {
      return loaded;
    }

    final List<FileSystemEntity> children = dtxDir.listSync();
    children.sort(
      (FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path),
    );
    for (final FileSystemEntity child in children) {
      if (child is! File || !child.path.toLowerCase().endsWith('.dtx')) {
        continue;
      }
      try {
        final String content = await child.readAsString();
        loaded.add(
          _parser.parse(
            fileName: child.uri.pathSegments.isNotEmpty
                ? child.uri.pathSegments.last
                : child.path,
            content: content,
          ),
        );
      } catch (_) {
        // Invalid dtx files are skipped to keep the app usable.
      }
    }
    return loaded;
  }

  Future<DtxLibraryImportResult> importFiles(List<XFile> files) async {
    final Directory dtxDir = await resolveDirectory();
    await dtxDir.create(recursive: true);
    final List<String> failures = <String>[];
    final Set<String> importedFileNames = <String>{};
    int importedCount = 0;

    for (int i = 0; i < files.length; i++) {
      final XFile file = files[i];
      final String originalName = _importPolicy.displayNameForImportedPath(
        directName: file.name,
        path: file.path,
        index: i,
      );
      final String targetName = _importPolicy.safeImportFileName(
        originalName,
        i,
      );
      try {
        final List<int> bytes = await file.readAsBytes();
        final String content = utf8.decode(bytes, allowMalformed: true);
        _parser.parse(fileName: targetName, content: content);
        await File('${dtxDir.path}/$targetName').writeAsBytes(bytes);
        importedFileNames.add(targetName);
        importedCount++;
      } catch (e) {
        failures.add('$originalName: $e');
      }
    }

    return DtxLibraryImportResult(
      importedCount: importedCount,
      importedFileNames: importedFileNames,
      failures: failures,
    );
  }
}