import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ZsolozsmaDayPart {
  const ZsolozsmaDayPart({
    required this.title,
    required this.href,
  });

  final String title;
  final String href;
}

class ZsolozsmaDayPartsLoadResult {
  const ZsolozsmaDayPartsLoadResult({
    required this.parts,
    required this.diagnostics,
  });

  final List<ZsolozsmaDayPart> parts;
  final String diagnostics;
}

class ZsolozsmaDayPartHtmlResult {
  const ZsolozsmaDayPartHtmlResult({
    required this.html,
    required this.diagnostics,
  });

  final String? html;
  final String diagnostics;
}

class ZsolozsmaSyncResult {
  const ZsolozsmaSyncResult({
    required this.downloadedYears,
    required this.failedByYear,
  });

  final List<int> downloadedYears;
  final Map<int, String> failedByYear;

  int get failedCount => failedByYear.length;
}

class ZsolozsmaService {
  static const String _baseUrl = 'https://breviar.sk/download/';
  static const String _baseSiteUrl = 'https://breviar.sk';
  static const String _cgiUrl = 'https://breviar.sk/cgi-bin/l.cgi';

  Future<ZsolozsmaSyncResult> ensureYearArchives({
    required Directory storageDir,
    required int centerYear,
  }) async {
    await storageDir.create(recursive: true);

    final Set<int> requiredYears = <int>{
      centerYear - 1,
      centerYear,
      centerYear + 1,
    };

    final List<FileSystemEntity> children = storageDir.listSync();
    for (final FileSystemEntity entity in children) {
      if (entity is! File) {
        continue;
      }
      final String name = _fileName(entity.path);
      final bool looksZip =
          name.length == 8 &&
          name.toLowerCase().endsWith('.zip') &&
          int.tryParse(name.substring(0, 4)) != null;

      if (!looksZip) {
        await entity.delete();
        continue;
      }

      final int year = int.parse(name.substring(0, 4));
      if (!requiredYears.contains(year)) {
        await entity.delete();
      }
    }

    final List<int> ordered = <int>[centerYear, centerYear - 1, centerYear + 1];
    final List<int> downloadedYears = <int>[];
    final Map<int, String> failedByYear = <int, String>{};

    for (final int year in ordered) {
      final File localZip = File('${storageDir.path}/$year.zip');
      if (await localZip.exists()) {
        continue;
      }
      try {
        await _downloadYearZip(year: year, target: localZip);
        downloadedYears.add(year);
      } catch (e) {
        failedByYear[year] = '$e';
      }
    }

    return ZsolozsmaSyncResult(
      downloadedYears: downloadedYears,
      failedByYear: failedByYear,
    );
  }

  Future<List<ZsolozsmaDayPart>> listDayParts({
    required Directory storageDir,
    required DateTime date,
  }) async {
    final ZsolozsmaDayPartsLoadResult result = await listDayPartsWithDiagnostics(
      storageDir: storageDir,
      date: date,
    );
    return result.parts;
  }

  Future<ZsolozsmaDayPartsLoadResult> listDayPartsWithDiagnostics({
    required Directory storageDir,
    required DateTime date,
  }) async {
    final StringBuffer diag = StringBuffer();
    diag.writeln('date=${_formatIsoDate(date)}');
    diag.writeln('storageDir=${storageDir.path}');

    final List<ZsolozsmaDayPart> webParts = await _listDayPartsFromWeb(date);
    diag.writeln('webListMatches=${webParts.length}');
    if (webParts.isNotEmpty) {
      return ZsolozsmaDayPartsLoadResult(
        parts: webParts,
        diagnostics: diag.toString().trimRight(),
      );
    }

    final File yearZip = File('${storageDir.path}/${date.year}.zip');
    if (!await yearZip.exists()) {
      diag.writeln('yearZip=${yearZip.path}');
      diag.writeln('yearZipExists=false');
      return ZsolozsmaDayPartsLoadResult(
        parts: const <ZsolozsmaDayPart>[],
        diagnostics: diag.toString().trimRight(),
      );
    }
    diag.writeln('yearZip=${yearZip.path}');
    diag.writeln('yearZipExists=true');

    final String yymmdd =
        '${(date.year % 100).toString().padLeft(2, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    final String daySuffix = '$yymmdd.HTM';
    diag.writeln('daySuffix=$daySuffix');

    Archive? archive;
    String? htmlFromExtracted;
    String? archiveDayFileName;
    String? extractedDayFilePath;
    bool extractedFallback = false;

    try {
      archive = _decodeArchive(await yearZip.readAsBytes());
      diag.writeln('archiveDecode=ok');
      diag.writeln('archiveEntries=${archive.files.length}');
    } catch (e) {
      diag.writeln('archiveDecode=error');
      diag.writeln('archiveDecodeError=$e');
      final _ExtractedDayHtml? extracted = await _loadDayHtmlViaExtraction(
        storageDir: storageDir,
        yearZip: yearZip,
        daySuffix: daySuffix,
      );
      if (extracted == null) {
        diag.writeln('extractFallback=failed');
        return ZsolozsmaDayPartsLoadResult(
          parts: const <ZsolozsmaDayPart>[],
          diagnostics: diag.toString().trimRight(),
        );
      }
      extractedFallback = true;
      htmlFromExtracted = extracted.html;
      extractedDayFilePath = extracted.dayFilePath;
      diag.writeln('extractFallback=ok');
      diag.writeln('extractDayFile=$extractedDayFilePath');
    }

    final String html;
    if (htmlFromExtracted != null) {
      html = htmlFromExtracted;
      diag.writeln('htmlSource=extracted');
    } else {
      ArchiveFile? dayFile;
      for (final ArchiveFile file in archive!.files) {
        if (!file.isFile) {
          continue;
        }
        if (file.name.toUpperCase().endsWith(daySuffix)) {
          dayFile = file;
          break;
        }
      }
      if (dayFile == null) {
        diag.writeln('archiveDayFile=not_found');
        return ZsolozsmaDayPartsLoadResult(
          parts: const <ZsolozsmaDayPart>[],
          diagnostics: diag.toString().trimRight(),
        );
      }
      archiveDayFileName = dayFile.name;
      diag.writeln('archiveDayFile=$archiveDayFileName');
      String decoded = _decodeBytes(dayFile.content);
      if (!_looksLikeHtml(decoded)) {
        diag.writeln('archiveDayLooksLikeHtml=false');
        final _ExtractedDayHtml? fallback = await _loadDayHtmlViaExtraction(
          storageDir: storageDir,
          yearZip: yearZip,
          daySuffix: daySuffix,
        );
        if (fallback == null) {
          diag.writeln('extractFallbackAfterDecode=failed');
          // Keep going so filename-based fallback can still produce dayparts.
          decoded = '';
        }
        if (fallback != null) {
          extractedFallback = true;
          extractedDayFilePath = fallback.dayFilePath;
          diag.writeln('extractFallbackAfterDecode=ok');
          diag.writeln('extractDayFile=$extractedDayFilePath');
          decoded = fallback.html;
        }
      } else {
        diag.writeln('archiveDayLooksLikeHtml=true');
      }
      html = decoded;
      diag.writeln('htmlSource=${extractedFallback ? 'archive+extracted' : 'archive'}');
    }

    final document = html_parser.parse(html);
    final List<ZsolozsmaDayPart> result = _extractDayPartsFromDocument(
      document: document,
      date: date,
      yymmdd: yymmdd,
    );
    diag.writeln('formsTotal=${document.querySelectorAll('form[action]').length}');
    diag.writeln('anchorsTotal=${document.querySelectorAll('a[href]').length}');
    diag.writeln('parsedMatches=${result.length}');

    if (result.isNotEmpty) {
      return ZsolozsmaDayPartsLoadResult(
        parts: result,
        diagnostics: diag.toString().trimRight(),
      );
    }

    if (archive != null) {
      final List<ZsolozsmaDayPart> byName = _listDayPartsFromArchiveNames(
        archive: archive,
        yymmdd: yymmdd,
      );
      diag.writeln('nameFallbackMatches=${byName.length}');
      if (byName.isNotEmpty) {
        return ZsolozsmaDayPartsLoadResult(
          parts: byName,
          diagnostics: diag.toString().trimRight(),
        );
      }
    } else {
      final List<ZsolozsmaDayPart> extractedOverview =
          await _listDayPartsFromExtractedOverview(
        storageDir: storageDir,
        date: date,
      );
      diag.writeln('extractedOverviewMatches=${extractedOverview.length}');
      if (extractedOverview.isNotEmpty) {
        return ZsolozsmaDayPartsLoadResult(
          parts: extractedOverview,
          diagnostics: diag.toString().trimRight(),
        );
      }

      final Directory? extractedYearDir = await _prepareExtractedYearDirectory(
        storageDir: storageDir,
        yearZip: yearZip,
      );
      if (extractedYearDir == null) {
        diag.writeln('nameFallbackSkipped=true');
      } else {
        final List<ZsolozsmaDayPart> byName = _listDayPartsFromExtractedNames(
          rootDir: extractedYearDir,
          yymmdd: yymmdd,
        );
        diag.writeln('nameFallbackExtractedMatches=${byName.length}');
        if (byName.isNotEmpty) {
          return ZsolozsmaDayPartsLoadResult(
            parts: byName,
            diagnostics: diag.toString().trimRight(),
          );
        }
      }
    }

    return ZsolozsmaDayPartsLoadResult(
      parts: const <ZsolozsmaDayPart>[],
      diagnostics: diag.toString().trimRight(),
    );
  }

  Future<ZsolozsmaDayPartHtmlResult> loadDayPartHtml({
    required Directory storageDir,
    required DateTime date,
    required ZsolozsmaDayPart part,
  }) async {
    final StringBuffer diag = StringBuffer();
    final String isoDate = _formatIsoDate(date);
    final String yymmdd =
      '${(date.year % 100).toString().padLeft(2, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
    final String href = part.href.trim();
    final String hrefBase = _fileName(href);
    final String? partCode = _extractPartCodeFromHref(href);
    diag.writeln('date=$isoDate');
    diag.writeln('storageDir=${storageDir.path}');
    diag.writeln('href=$href');
    diag.writeln('hrefBase=$hrefBase');
    diag.writeln('partCode=${partCode ?? '-'}');

    if (_isCgiHref(href)) {
      final String? cgiHtml = await _loadHtmlFromHref(href);
      if (cgiHtml != null) {
        diag.writeln('hrefDirectWeb=ok');
        if (_looksLikeValidPrayerHtml(cgiHtml)) {
          return ZsolozsmaDayPartHtmlResult(
            html: cgiHtml,
            diagnostics: diag.toString().trimRight(),
          );
        }
        diag.writeln('hrefDirectWeb=invalid_prayer_page');
      } else {
        diag.writeln('hrefDirectWeb=failed');
      }
    }

    if (partCode != null) {
      final String? webHtml = await _loadDayPartHtmlFromWeb(
        date: date,
        partCode: partCode,
      );
      if (webHtml != null && _looksLikeValidPrayerHtml(webHtml)) {
        diag.writeln('webFallback=ok');
        diag.writeln('webUrl=${_buildDayPartUri(date: date, partCode: partCode)}');
        return ZsolozsmaDayPartHtmlResult(
          html: webHtml,
          diagnostics: diag.toString().trimRight(),
        );
      }
      diag.writeln('webFallback=failed');
    } else {
      diag.writeln('webFallback=skipped_no_part_code');
    }

    final File yearZip = File('${storageDir.path}/${date.year}.zip');
    final bool yearZipExists = await yearZip.exists();
    if (!yearZipExists) {
      diag.writeln('yearZipExists=false');
    } else {
      diag.writeln('yearZipExists=true');
      diag.writeln('yearZip=${yearZip.path}');

      try {
        final Archive archive = _decodeArchive(await yearZip.readAsBytes());
        diag.writeln('archiveDecode=ok');
        ArchiveFile? file = _findArchiveFileByHref(
          archive: archive,
          href: href,
        );
        if (file == null && partCode != null) {
          file = _findArchiveFileByPartCode(
            archive: archive,
            yymmdd: yymmdd,
            partCode: partCode,
          );
          if (file != null) {
            diag.writeln('archivePartCodeFile=${file.name}');
          }
        }
        if (file == null) {
          diag.writeln('archiveHrefFile=not_found');
        } else {
          diag.writeln('archiveHrefFile=${file.name}');
          diag.writeln('archiveHrefCompression=${file.compression?.name ?? '-'}');
          diag.writeln('archiveHrefIsCompressed=${file.isCompressed}');
          diag.writeln('archiveHrefSize=${file.size}');
          String decoded = _decodeBytes(file.content);
          diag.writeln('archiveHrefDecodedLength=${decoded.length}');
          diag.writeln('archiveHrefDecodedHead=${_diagnosticHead(decoded)}');
          if (!_looksLikeHtml(decoded)) {
            final String? lzmaDecoded = _decodeZipMethod14Bytes(
              file.content,
              uncompressedSize: file.size,
            );
            if (lzmaDecoded != null) {
              decoded = lzmaDecoded;
              diag.writeln('archiveHrefLzmaFallback=ok');
              diag.writeln('archiveHrefDecodedLength=${decoded.length}');
              diag.writeln('archiveHrefDecodedHead=${_diagnosticHead(decoded)}');
            } else {
              diag.writeln('archiveHrefLzmaFallback=failed');
            }
          }
          if (_looksLikeHtml(decoded)) {
            diag.writeln('archiveHrefLooksLikeHtml=true');
            return ZsolozsmaDayPartHtmlResult(
              html: decoded,
              diagnostics: diag.toString().trimRight(),
            );
          }
          diag.writeln('archiveHrefLooksLikeHtml=false');
        }
      } catch (e) {
        diag.writeln('archiveDecode=error');
        diag.writeln('archiveDecodeError=$e');
      }

      try {
        final _ExtractedDayHtml? extracted = await _loadHrefHtmlViaExtraction(
          storageDir: storageDir,
          yearZip: yearZip,
          href: href,
        );
        if (extracted != null && _looksLikeHtml(extracted.html)) {
          diag.writeln('extractHref=ok');
          diag.writeln('extractHrefFile=${extracted.dayFilePath}');
          return ZsolozsmaDayPartHtmlResult(
            html: extracted.html,
            diagnostics: diag.toString().trimRight(),
          );
        }
        if (partCode != null) {
          final _ExtractedDayHtml? byCode = await _loadPartCodeHtmlViaExtraction(
            storageDir: storageDir,
            yearZip: yearZip,
            yymmdd: yymmdd,
            partCode: partCode,
          );
          if (byCode != null && _looksLikeHtml(byCode.html)) {
            diag.writeln('extractPartCode=ok');
            diag.writeln('extractPartCodeFile=${byCode.dayFilePath}');
            return ZsolozsmaDayPartHtmlResult(
              html: byCode.html,
              diagnostics: diag.toString().trimRight(),
            );
          }
          diag.writeln('extractPartCode=failed');
        }
        diag.writeln('extractHref=failed');
      } catch (e) {
        diag.writeln('extractHref=error');
        diag.writeln('extractHrefError=$e');
      }
    }

    return ZsolozsmaDayPartHtmlResult(
      html: null,
      diagnostics: diag.toString().trimRight(),
    );
  }

  Future<void> _downloadYearZip({
    required int year,
    required File target,
  }) async {
    final HttpClient client = HttpClient();
    final String sourceName = '$year-hu-plain.zip';
    final Uri uri = Uri.parse('$_baseUrl$sourceName');
    final File tmp = File('${target.path}.tmp');
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} while downloading $sourceName');
      }

      final IOSink sink = tmp.openWrite();
      await for (final List<int> chunk in response) {
        sink.add(chunk);
      }
      await sink.close();

      if (await target.exists()) {
        await target.delete();
      }
      await tmp.rename(target.path);
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
      client.close(force: true);
    }
  }

  Archive _decodeArchive(List<int> bytes) {
    return ZipDecoder().decodeBytes(bytes, verify: false);
  }

  Future<_ExtractedDayHtml?> _loadDayHtmlViaExtraction({
    required Directory storageDir,
    required File yearZip,
    required String daySuffix,
  }) async {
    final Directory? yearDir = await _prepareExtractedYearDirectory(
      storageDir: storageDir,
      yearZip: yearZip,
    );
    if (yearDir == null) {
      return null;
    }

    final String? dayFilePath = await _findExtractedDayFile(
      rootDir: yearDir,
      daySuffix: daySuffix,
    );
    if (dayFilePath == null) {
      return null;
    }
    final File dayFile = File(dayFilePath);
    final List<int> content = await dayFile.readAsBytes();
    final int? uncompressedSize = await _findArchiveEntrySizeByName(
      yearZip: yearZip,
      entryName: _fileName(dayFilePath),
    );
    return _ExtractedDayHtml(
      html: _decodeArchiveTextBytes(
        content,
        uncompressedSize: uncompressedSize,
      ),
      dayFilePath: dayFilePath,
    );
  }

  Future<_ExtractedDayHtml?> _loadHrefHtmlViaExtraction({
    required Directory storageDir,
    required File yearZip,
    required String href,
  }) async {
    final Directory? yearDir = await _prepareExtractedYearDirectory(
      storageDir: storageDir,
      yearZip: yearZip,
    );
    if (yearDir == null) {
      return null;
    }

    final String? path = await _findExtractedFileByHref(
      rootDir: yearDir,
      href: href,
    );
    if (path == null) {
      return null;
    }
    final String html = await _loadAndResolveLocalHtml(
      rootDir: yearDir,
      filePath: path,
      yearZip: yearZip,
    );
    return _ExtractedDayHtml(
      html: html,
      dayFilePath: path,
    );
  }

  Future<_ExtractedDayHtml?> _loadPartCodeHtmlViaExtraction({
    required Directory storageDir,
    required File yearZip,
    required String yymmdd,
    required String partCode,
  }) async {
    final Directory? yearDir = await _prepareExtractedYearDirectory(
      storageDir: storageDir,
      yearZip: yearZip,
    );
    if (yearDir == null) {
      return null;
    }

    final String? path = await _findExtractedFileByPartCode(
      rootDir: yearDir,
      yymmdd: yymmdd,
      partCode: partCode,
    );
    if (path == null) {
      return null;
    }

    final String html = await _loadAndResolveLocalHtml(
      rootDir: yearDir,
      filePath: path,
      yearZip: yearZip,
    );
    return _ExtractedDayHtml(
      html: html,
      dayFilePath: path,
    );
  }

  Future<bool> _hasNewerZipThanExtraction({
    required File zipFile,
    required Directory extractedDir,
  }) async {
    final DateTime zipTime = await zipFile.lastModified();
    final DateTime extractedTime = (await extractedDir.stat()).modified;
    return zipTime.isAfter(extractedTime);
  }

  Future<Directory?> _prepareExtractedYearDirectory({
    required Directory storageDir,
    required File yearZip,
  }) async {
    final String yearName = _fileName(yearZip.path).replaceAll('.zip', '');
    final Directory cacheRoot = Directory('${storageDir.path}/_unzipped');
    final Directory yearDir = Directory('${cacheRoot.path}/$yearName');

    final bool mustExtract =
        !await yearDir.exists() ||
        await _hasNewerZipThanExtraction(zipFile: yearZip, extractedDir: yearDir);

    if (!mustExtract) {
      return yearDir;
    }

    try {
      if (await yearDir.exists()) {
        await yearDir.delete(recursive: true);
      }
      await yearDir.create(recursive: true);
      await extractFileToDisk(yearZip.path, yearDir.path);
      return yearDir;
    } catch (_) {
      if (await yearDir.exists()) {
        await yearDir.delete(recursive: true);
      }
      return null;
    }
  }

  Future<String?> _findExtractedDayFile({
    required Directory rootDir,
    required String daySuffix,
  }) async {
    await for (final FileSystemEntity entity in rootDir.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final String name = _fileName(entity.path).toUpperCase();
      if (name.endsWith(daySuffix)) {
        return entity.path;
      }
    }
    return null;
  }

  Future<String?> _findExtractedFileByHref({
    required Directory rootDir,
    required String href,
  }) async {
    final String normalizedHref = href.replaceAll('\\', '/').toUpperCase();
    final String hrefBase = _fileName(normalizedHref);
    await for (final FileSystemEntity entity in rootDir.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final String full = entity.path.replaceAll('\\', '/').toUpperCase();
      final String base = _fileName(full);
      if (full.endsWith('/$normalizedHref') || full.endsWith(normalizedHref)) {
        return entity.path;
      }
      if (base == hrefBase) {
        return entity.path;
      }
    }
    return null;
  }

  Future<String?> _findExtractedFileByPartCode({
    required Directory rootDir,
    required String yymmdd,
    required String partCode,
  }) async {
    final String expectedBase = '${yymmdd}_$partCode.htm'.toUpperCase();
    final String suffix = '_$partCode.HTM';
    await for (final FileSystemEntity entity in rootDir.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final String base = _fileName(entity.path).toUpperCase();
      if (base == expectedBase || base.endsWith(suffix)) {
        return entity.path;
      }
    }
    return null;
  }

  Future<List<ZsolozsmaDayPart>> _listDayPartsFromExtractedOverview({
    required Directory storageDir,
    required DateTime date,
  }) async {
    final File yearZip = File('${storageDir.path}/${date.year}.zip');
    final Directory? yearDir = await _prepareExtractedYearDirectory(
      storageDir: storageDir,
      yearZip: yearZip,
    );
    if (yearDir == null) {
      return const <ZsolozsmaDayPart>[];
    }

    final String yymmdd = _extractDayPrefixFromDate(date);
    final String? path = await _findExtractedDayFile(
      rootDir: yearDir,
      daySuffix: '$yymmdd.HTM',
    );
    if (path == null) {
      return const <ZsolozsmaDayPart>[];
    }

    final int? uncompressedSize = await _findArchiveEntrySizeByName(
      yearZip: yearZip,
      entryName: _fileName(path),
    );
    final String html = _decodeArchiveTextBytes(
      await File(path).readAsBytes(),
      uncompressedSize: uncompressedSize,
    );
    final dom.Document document = html_parser.parse(html);
    return _extractDayPartsFromDocument(
      document: document,
      date: date,
      yymmdd: yymmdd,
    );
  }

  Future<String> _loadAndResolveLocalHtml({
    required Directory rootDir,
    required String filePath,
    required File yearZip,
  }) async {
    String currentHtml = await _readArchiveTextFromExtractedPath(
      yearZip: yearZip,
      filePath: filePath,
    );
    String currentPath = filePath;
    final Set<String> visited = <String>{};

    for (int i = 0; i < 3; i++) {
      final String? preferredPath = await _findPreferredDisplayToggleLocalPath(
        html: currentHtml,
        rootDir: rootDir,
        currentPath: currentPath,
      );
      if (preferredPath == null) {
        break;
      }
      if (!visited.add(preferredPath)) {
        break;
      }

      final File preferredFile = File(preferredPath);
      if (!await preferredFile.exists()) {
        break;
      }

      final String preferredHtml = await _readArchiveTextFromExtractedPath(
        yearZip: yearZip,
        filePath: preferredPath,
      );
      if (!_looksLikeValidPrayerHtml(preferredHtml)) {
        break;
      }

      currentHtml = preferredHtml;
      currentPath = preferredPath;
    }

    return currentHtml;
  }

  Future<String?> _findPreferredDisplayToggleLocalPath({
    required String html,
    required Directory rootDir,
    required String currentPath,
  }) async {
    final dom.Document doc = html_parser.parse(html);
    String? endingPath;
    String? gloriaPath;

    for (final dom.Element anchor in doc.querySelectorAll('a[href]')) {
      final String text = _stripHtml(anchor.text).toLowerCase();
      final bool isDisplayLink =
          text.contains('megjelenites:') || text.contains('megjelenítés:');
      if (!isDisplayLink) {
        continue;
      }

      final String href = (anchor.attributes['href'] ?? '').trim();
      if (href.isEmpty) {
        continue;
      }

      final String? resolved = await _resolveLocalHrefTarget(
        rootDir: rootDir,
        currentPath: currentPath,
        href: href,
      );
      if (resolved == null) {
        continue;
      }

      final bool isEndingShowLink =
          (text.contains('imaora befejezesenek') ||
              text.contains('imaóra befejezésének')) &&
          (text.contains('megjelenites') || text.contains('megjelenítés'));
      if (isEndingShowLink) {
        endingPath ??= resolved;
        continue;
      }

      final bool isGloriaLink =
          text.contains('dicsoseg az atyanak') ||
          text.contains('dicsőség az atyának');
      if (isGloriaLink) {
        gloriaPath ??= resolved;
      }
    }

    return endingPath ?? gloriaPath;
  }

  Future<String?> _resolveLocalHrefTarget({
    required Directory rootDir,
    required String currentPath,
    required String href,
  }) async {
    final String trimmed = href.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final String qt = uri.queryParameters['qt'] ?? '';
      final String p = (uri.queryParameters['p'] ?? '').trim().toLowerCase();
      if (qt == 'pdt' && p.isNotEmpty && p != '*') {
        final String? dayPrefix = _extractDayPrefixFromPath(currentPath);
        if (dayPrefix != null) {
          final String? candidate = await _findExtractedFileByPartCode(
            rootDir: rootDir,
            yymmdd: dayPrefix,
            partCode: _canonicalDayPartCodeFromPart(p) ?? p,
          );
          if (candidate != null) {
            return candidate;
          }
        }
      }

      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return null;
      }
    }

    final Uri baseUri = Uri.file(currentPath);
    final Uri resolved = baseUri.resolve(trimmed);
    if (resolved.scheme == 'file') {
      return resolved.toFilePath();
    }

    final String localName = _fileName(resolved.toString()).toLowerCase();
    if (localName.isNotEmpty) {
      for (final FileSystemEntity entity in rootDir.listSync(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        if (_fileName(entity.path).toLowerCase() == localName) {
          return entity.path;
        }
      }
    }

    return null;
  }

  String? _extractDayPrefixFromPath(String path) {
    final String baseName = _fileName(path);
    final RegExpMatch? match = RegExp(
      r'^([0-9]{6})_',
      caseSensitive: false,
    ).firstMatch(baseName);
    return match?.group(1);
  }

  String _decodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _decodeArchiveTextBytes(
    List<int> bytes, {
    int? uncompressedSize,
  }) {
    final String decoded = _decodeBytes(bytes);
    if (_looksLikeHtml(decoded)) {
      return decoded;
    }

    final String? lzmaDecoded = _decodeZipMethod14Bytes(
      bytes,
      uncompressedSize: uncompressedSize,
    );
    if (lzmaDecoded != null) {
      return lzmaDecoded;
    }

    return decoded;
  }

  String? _decodeZipMethod14Bytes(
    List<int> bytes, {
    required int? uncompressedSize,
  }) {
    if (uncompressedSize == null || uncompressedSize <= 0 || bytes.length < 9) {
      return null;
    }

    final int propertiesSize = bytes[2] | (bytes[3] << 8);
    if (propertiesSize != 5 || bytes.length <= 4 + propertiesSize) {
      return null;
    }

    final List<int> properties = bytes.sublist(4, 4 + propertiesSize);
    final int packed = properties[0];
    final int positionBits = packed ~/ 45;
    final int remainder = packed - (positionBits * 45);
    final int literalPositionBits = remainder ~/ 9;
    final int literalContextBits = remainder - (literalPositionBits * 9);

    try {
      final LzmaDecoder decoder = LzmaDecoder();
      decoder.reset(
        positionBits: positionBits,
        literalPositionBits: literalPositionBits,
        literalContextBits: literalContextBits,
        resetDictionary: true,
      );
      final List<int> compressedBytes = bytes.sublist(4 + propertiesSize);
      final Uint8List decodedBytes = decoder.decode(
        InputMemoryStream(Uint8List.fromList(compressedBytes)),
        uncompressedSize,
      );
      return _decodeBytes(decodedBytes);
    } catch (_) {
      return null;
    }
  }

  Future<int?> _findArchiveEntrySizeByName({
    required File yearZip,
    required String entryName,
  }) async {
    try {
      final Archive archive = _decodeArchive(await yearZip.readAsBytes());
      final String targetName = _fileName(entryName).toUpperCase();
      for (final ArchiveFile file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        if (_fileName(file.name).toUpperCase() == targetName) {
          return file.size;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String> _readArchiveTextFromExtractedPath({
    required File yearZip,
    required String filePath,
  }) async {
    final int? uncompressedSize = await _findArchiveEntrySizeByName(
      yearZip: yearZip,
      entryName: _fileName(filePath),
    );
    return _decodeArchiveTextBytes(
      await File(filePath).readAsBytes(),
      uncompressedSize: uncompressedSize,
    );
  }

  String _diagnosticHead(String text, {int maxLength = 120}) {
    final String normalized = text.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return normalized.substring(0, maxLength);
  }

  String _stripHtml(String raw) {
    String text = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _looksLikeHtml(String text) {
    final String head = text.length > 512
        ? text.substring(0, 512).toLowerCase()
        : text.toLowerCase();
    return head.contains('<html') || head.contains('<body') || head.contains('<a ');
  }

  List<ZsolozsmaDayPart> _extractDayPartsFromDocument({
    required dom.Document document,
    required DateTime date,
    String? yymmdd,
  }) {
    final String dayPrefix = yymmdd ?? _extractDayPrefixFromDate(date);
    final Set<String> seenCodes = <String>{};
    final List<ZsolozsmaDayPart> fromForms = <ZsolozsmaDayPart>[];

    for (final dom.Element form in document.querySelectorAll('form[action]')) {
      final String action = (form.attributes['action'] ?? '').trim();
      final String? code = _canonicalDayPartCode(action);
      if (code == null || !_isSupportedDayPartCode(code) || !seenCodes.add(code)) {
        continue;
      }

      final dom.Element? input = form.querySelector('input[type="submit"]');
      final String title = _titleForPartCode(
        code: code,
        fallback: _preferredDayPartTitle(
        primary: input?.attributes['title'],
        secondary: input?.attributes['value'],
        fallback: code,
      ),
      );
      fromForms.add(ZsolozsmaDayPart(
        title: title,
        href: _normalizedDayPartHref(dayPrefix: dayPrefix, code: code),
      ));
    }

    if (fromForms.isNotEmpty) {
      fromForms.sort(_compareDayPartOrder);
      return fromForms;
    }

    final List<ZsolozsmaDayPart> fromAnchors = <ZsolozsmaDayPart>[];

    for (final dom.Element anchor in document.querySelectorAll('a[href]')) {
      final String href = (anchor.attributes['href'] ?? '').trim();
      final String? code = _canonicalDayPartCode(href);
      if (code == null || !_isSupportedDayPartCode(code) || !seenCodes.add(code)) {
        continue;
      }

      final String title = _titleForPartCode(
        code: code,
        fallback: _preferredDayPartTitle(
        primary: anchor.attributes['title'],
        secondary: anchor.text,
        fallback: code,
      ),
      );
      fromAnchors.add(ZsolozsmaDayPart(
        title: title,
        href: _normalizedDayPartHref(dayPrefix: dayPrefix, code: code),
      ));
    }

    fromAnchors.sort(_compareDayPartOrder);
    return fromAnchors;
  }

  String _extractDayPrefixFromDate(DateTime date) {
    return '${(date.year % 100).toString().padLeft(2, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _matchesDayPartTarget({
    required String rawTarget,
    required DateTime date,
    String? yymmdd,
  }) {
    final String target = rawTarget.trim();
    if (target.isEmpty) {
      return false;
    }

    final Uri? uri = Uri.tryParse(target);
    if (uri != null) {
      final String qt = uri.queryParameters['qt'] ?? '';
      final String p = uri.queryParameters['p'] ?? '';
      if (qt == 'pdt' && p.isNotEmpty && p != '*') {
        return _matchesQueryDate(uri: uri, date: date);
      }
    }

    return yymmdd != null && target.toUpperCase().contains(yymmdd.toUpperCase());
  }

  bool _matchesQueryDate({
    required Uri uri,
    required DateTime date,
  }) {
    final String day = uri.queryParameters['d'] ?? '';
    final String month = uri.queryParameters['m'] ?? '';
    final String year = uri.queryParameters['r'] ?? '';

    if (day.isEmpty || month.isEmpty || year.isEmpty) {
      return true;
    }

    return day == '${date.day}' &&
        month == '${date.month}' &&
        year == '${date.year}';
  }

  String _normalizeDayPartTarget(
    String rawTarget,
  ) {
    final String target = rawTarget.trim();
    final Uri? uri = Uri.tryParse(target);

    final bool isCgi =
        target.startsWith('/cgi-bin/l.cgi') ||
        target.contains('/cgi-bin/l.cgi') ||
        (uri != null && uri.path.endsWith('/cgi-bin/l.cgi'));
    if (isCgi) {
      return _normalizeHref(target);
    }
    return target;
  }

  String _normalizedDayPartHref({
    required String dayPrefix,
    required String code,
  }) {
    return '${dayPrefix}_$code.htm';
  }

  String? _canonicalDayPartCode(String rawTarget) {
    final String target = rawTarget.trim();
    if (target.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(target);
    if (uri != null) {
      final String qt = uri.queryParameters['qt'] ?? '';
      final String p = (uri.queryParameters['p'] ?? '').trim().toLowerCase();
      if (qt == 'pdt' && p.isNotEmpty && p != '*') {
        return _canonicalDayPartCodeFromPart(p);
      }
    }

    final String base = _fileName(target).toLowerCase();
    final RegExpMatch? match = RegExp(
      r'^[0-9]{6}_([0-9a-z]+)\.htm$',
      caseSensitive: false,
    ).firstMatch(base);
    if (match == null) {
      return null;
    }

    return _canonicalDayPartCodeFromPart(match.group(1)!);
  }

  String? _canonicalDayPartCodeFromPart(String partCode) {
    final String normalized = partCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.endsWith('d') && normalized.length > 1) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  bool _isSupportedDayPartCode(String code) {
    switch (code) {
      case '01':
      case '02':
      case '03':
      case '09':
      case '0c':
      case '0i':
      case '0k':
      case '0r':
        return true;
    }
    return false;
  }

  String _titleForPartCode({
    required String code,
    required String fallback,
  }) {
    switch (code) {
      case '01':
        return 'Imádságra hívás';
      case '02':
        return 'Olvasmányos imaóra';
      case '03':
        return 'Reggeli dicséret';
      case '09':
        return 'Délelőtt';
      case '0c':
        return 'Délben';
      case '0i':
        return 'Délután';
      case '0k':
        return 'Esti dicséret';
      case '0r':
        return 'Befejező imaóra';
    }
    return fallback;
  }

  String _preferredDayPartTitle({
    String? primary,
    String? secondary,
    required String fallback,
  }) {
    final String primaryText = _stripHtml(primary ?? '');
    if (primaryText.isNotEmpty) {
      return primaryText;
    }

    final String secondaryText = _stripHtml(secondary ?? '');
    if (secondaryText.isNotEmpty) {
      return secondaryText;
    }

    return fallback;
  }

  ArchiveFile? _findArchiveFileByHref({
    required Archive archive,
    required String href,
  }) {
    final String normalizedHref = href.replaceAll('\\', '/').toUpperCase();
    final String hrefBase = _fileName(normalizedHref);
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String name = file.name.replaceAll('\\', '/').toUpperCase();
      if (name == normalizedHref ||
          name.endsWith('/$normalizedHref') ||
          _fileName(name) == hrefBase) {
        return file;
      }
    }
    return null;
  }

  String? _extractPartCode(String hrefBase) {
    final RegExpMatch? match = RegExp(
      r'^[0-9]{6}_([0-9a-z]+)\.htm$',
      caseSensitive: false,
    ).firstMatch(hrefBase);
    return match?.group(1)?.toLowerCase();
  }

  String? _extractPartCodeFromHref(String href) {
    final Uri? uri = Uri.tryParse(href.trim());
    if (uri != null) {
      final String p = (uri.queryParameters['p'] ?? '').trim().toLowerCase();
      if (p.isNotEmpty && p != '*' && RegExp(r'^[0-9a-z]+$').hasMatch(p)) {
        return p;
      }
    }
    final String hrefBase = _fileName(href);
    return _extractPartCode(hrefBase);
  }

  ArchiveFile? _findArchiveFileByPartCode({
    required Archive archive,
    required String yymmdd,
    required String partCode,
  }) {
    final String expectedBase = '${yymmdd}_$partCode.htm'.toUpperCase();
    final String suffix = '_$partCode.HTM';
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String base = _fileName(file.name).toUpperCase();
      if (base == expectedBase || base.endsWith(suffix)) {
        return file;
      }
    }
    return null;
  }

  Uri _buildDayPartUri({
    required DateTime date,
    required String partCode,
  }) {
    return Uri.parse(_cgiUrl).replace(
      queryParameters: <String, String>{
        'qt': 'pdt',
        'j': 'hu',
        'd': '${date.day}',
        'm': '${date.month}',
        'r': '${date.year}',
        'p': partCode,
      },
    );
  }

  Future<String?> _loadDayPartHtmlFromWeb({
    required DateTime date,
    required String partCode,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final Uri uri = _buildDayPartUri(date: date, partCode: partCode);
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> out, List<int> chunk) {
          out.addAll(chunk);
          return out;
        },
      );
      final String html = _decodeBytes(bytes);
      return await _resolveFullTextPreference(
        html: html,
        baseUri: uri,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<ZsolozsmaDayPart>> _listDayPartsFromWeb(DateTime date) async {
    final HttpClient client = HttpClient();
    try {
      final Uri uri = _buildDayOverviewUri(date);
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <ZsolozsmaDayPart>[];
      }
      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> out, List<int> chunk) {
          out.addAll(chunk);
          return out;
        },
      );
      final String html = _decodeBytes(bytes);
      final document = html_parser.parse(html);
      return _extractDayPartsFromDocument(document: document, date: date);
    } catch (_) {
      return const <ZsolozsmaDayPart>[];
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildDayOverviewUri(DateTime date) {
    return Uri.parse(_cgiUrl).replace(
      queryParameters: <String, String>{
        'qt': 'pdt',
        'd': '${date.day}',
        'm': '${date.month}',
        'r': '${date.year}',
        'j': 'hu',
        'ds': '1',
        'o3': '8',
      },
    );
  }

  bool _isCgiHref(String href) {
    return href.contains('/cgi-bin/l.cgi') || href.startsWith('$_baseSiteUrl/cgi-bin/l.cgi');
  }

  String _normalizeHref(String href) {
    final String raw = href.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return '$_baseSiteUrl$raw';
    }
    return '$_baseSiteUrl/$raw';
  }

  Future<String?> _loadHtmlFromHref(String href) async {
    final HttpClient client = HttpClient();
    try {
      final Uri uri = Uri.parse(_normalizeHref(href));
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> out, List<int> chunk) {
          out.addAll(chunk);
          return out;
        },
      );
      final String html = _decodeBytes(bytes);
      return await _resolveFullTextPreference(
        html: html,
        baseUri: uri,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _resolveFullTextPreference({
    required String html,
    required Uri baseUri,
  }) async {
    String currentHtml = html;
    Uri currentBaseUri = baseUri;
    final Set<String> visited = <String>{};

    for (int i = 0; i < 3; i++) {
      final Uri? preferredUri = _findPreferredDisplayToggleUri(
        html: currentHtml,
        baseUri: currentBaseUri,
      );
      if (preferredUri == null) {
        break;
      }
      if (!visited.add(preferredUri.toString())) {
        break;
      }

      final HttpClient client = HttpClient();
      try {
        final HttpClientRequest request = await client.getUrl(preferredUri);
        final HttpClientResponse response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          break;
        }

        final List<int> bytes = await response.fold<List<int>>(
          <int>[],
          (List<int> out, List<int> chunk) {
            out.addAll(chunk);
            return out;
          },
        );
        final String preferredHtml = _decodeBytes(bytes);
        if (!_looksLikeValidPrayerHtml(preferredHtml)) {
          break;
        }

        currentHtml = preferredHtml;
        currentBaseUri = preferredUri;
      } catch (_) {
        break;
      } finally {
        client.close(force: true);
      }
    }

    return currentHtml;
  }

  Uri? _findPreferredDisplayToggleUri({
    required String html,
    required Uri baseUri,
  }) {
    final dom.Document doc = html_parser.parse(html);
    Uri? endingUri;
    Uri? gloriaUri;

    for (final dom.Element anchor in doc.querySelectorAll('a[href]')) {
      final String text = _stripHtml(anchor.text).toLowerCase();
      final bool isDisplayLink =
          text.contains('megjelenites:') || text.contains('megjelenítés:');
      if (!isDisplayLink) {
        continue;
      }

      final String href = (anchor.attributes['href'] ?? '').trim();
      if (href.isEmpty) {
        continue;
      }
      final Uri resolved = baseUri.resolve(href);

      final bool isEndingShowLink =
          (text.contains('imaora befejezesenek') ||
              text.contains('imaóra befejezésének')) &&
          (text.contains('megjelenites') || text.contains('megjelenítés'));
      if (isEndingShowLink) {
        endingUri ??= resolved;
        continue;
      }

      final bool isGloriaLink =
          text.contains('dicsoseg az atyanak') ||
          text.contains('dicsőség az atyának');
      if (isGloriaLink) {
        gloriaUri ??= resolved;
      }
    }

    return endingUri ?? gloriaUri;
  }

  bool _looksLikeValidPrayerHtml(String text) {
    final String lower = text.toLowerCase();
    if (!_looksLikeHtml(text)) {
      return false;
    }
    if (lower.contains('unknown prayer type')) {
      return false;
    }
    return lower.contains('tts_heading') ||
        lower.contains('prayer-title') ||
        lower.contains('class="hymn"') ||
        lower.contains('class="psalm"');
  }

  List<ZsolozsmaDayPart> _listDayPartsFromArchiveNames({
    required Archive archive,
    required String yymmdd,
  }) {
    final List<ZsolozsmaDayPart> result = <ZsolozsmaDayPart>[];
    final Set<String> seen = <String>{};

    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String baseName = _fileName(file.name);
      final String? code = _canonicalDayPartCode(baseName);
      if (code == null || !_isSupportedDayPartCode(code) || !seen.add(code)) {
        continue;
      }

      result.add(ZsolozsmaDayPart(
        title: _titleForPartCode(code: code, fallback: baseName),
        href: _normalizedDayPartHref(dayPrefix: yymmdd, code: code),
      ));
    }

    result.sort(_compareDayPartOrder);
    return result;
  }

  List<ZsolozsmaDayPart> _listDayPartsFromExtractedNames({
    required Directory rootDir,
    required String yymmdd,
  }) {
    final Set<String> seen = <String>{};
    final List<ZsolozsmaDayPart> result = <ZsolozsmaDayPart>[];

    for (final FileSystemEntity entity in rootDir.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final String baseName = _fileName(entity.path);
      final String? code = _canonicalDayPartCode(baseName);
      if (code == null || !_isSupportedDayPartCode(code) || !seen.add(code)) {
        continue;
      }
      result.add(ZsolozsmaDayPart(
        title: _titleForPartCode(code: code, fallback: baseName),
        href: _normalizedDayPartHref(dayPrefix: yymmdd, code: code),
      ));
    }

    result.sort(_compareDayPartOrder);
    return result;
  }

  int _compareDayPartOrder(ZsolozsmaDayPart left, ZsolozsmaDayPart right) {
    final int leftOrder = _dayPartOrderIndex(left.href);
    final int rightOrder = _dayPartOrderIndex(right.href);
    if (leftOrder != rightOrder) {
      return leftOrder.compareTo(rightOrder);
    }
    return left.href.compareTo(right.href);
  }

  int _dayPartOrderIndex(String href) {
    final String? code = _canonicalDayPartCode(href);
    switch (code) {
      case '01':
        return 0;
      case '02':
        return 1;
      case '03':
        return 2;
      case '09':
        return 3;
      case '0c':
        return 4;
      case '0i':
        return 5;
      case '0k':
        return 6;
      case '0r':
        return 7;
      default:
        return 999;
    }
  }

  String _fileName(String path) {
    final String normalized = path.replaceAll('\\', '/');
    final int idx = normalized.lastIndexOf('/');
    if (idx < 0) {
      return normalized;
    }
    return normalized.substring(idx + 1);
  }

  String _formatIsoDate(DateTime date) {
    final String yyyy = date.year.toString().padLeft(4, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}

class _ExtractedDayHtml {
  const _ExtractedDayHtml({
    required this.html,
    required this.dayFilePath,
  });

  final String html;
  final String dayFilePath;
}