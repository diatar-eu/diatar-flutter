import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_archive/flutter_archive.dart' as fa;
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
      diag.writeln('nameFallbackSkipped=true');
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
    final String href = part.href.trim();
    final String hrefBase = _fileName(href);
    final String? partCode = _extractPartCode(hrefBase);
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
        final ArchiveFile? file = _findArchiveFileByHref(
          archive: archive,
          href: href,
        );
        if (file == null) {
          diag.writeln('archiveHrefFile=not_found');
        } else {
          diag.writeln('archiveHrefFile=${file.name}');
          final String decoded = _decodeBytes(file.content);
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
    final String yearName = _fileName(yearZip.path).replaceAll('.zip', '');
    final Directory cacheRoot = Directory('${storageDir.path}/_unzipped');
    final Directory yearDir = Directory('${cacheRoot.path}/$yearName');

    final bool mustExtract =
        !await yearDir.exists() ||
        await _hasNewerZipThanExtraction(zipFile: yearZip, extractedDir: yearDir);

    if (mustExtract) {
      try {
        if (await yearDir.exists()) {
          await yearDir.delete(recursive: true);
        }
        await yearDir.create(recursive: true);
        await fa.ZipFile.extractToDirectory(
          zipFile: yearZip,
          destinationDir: yearDir,
        );
      } catch (_) {
        if (await yearDir.exists()) {
          await yearDir.delete(recursive: true);
        }
        return null;
      }
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
    return _ExtractedDayHtml(
      html: _decodeBytes(content),
      dayFilePath: dayFilePath,
    );
  }

  Future<_ExtractedDayHtml?> _loadHrefHtmlViaExtraction({
    required Directory storageDir,
    required File yearZip,
    required String href,
  }) async {
    final String yearName = _fileName(yearZip.path).replaceAll('.zip', '');
    final Directory cacheRoot = Directory('${storageDir.path}/_unzipped');
    final Directory yearDir = Directory('${cacheRoot.path}/$yearName');

    final bool mustExtract =
        !await yearDir.exists() ||
        await _hasNewerZipThanExtraction(zipFile: yearZip, extractedDir: yearDir);

    if (mustExtract) {
      try {
        if (await yearDir.exists()) {
          await yearDir.delete(recursive: true);
        }
        await yearDir.create(recursive: true);
        await fa.ZipFile.extractToDirectory(
          zipFile: yearZip,
          destinationDir: yearDir,
        );
      } catch (_) {
        if (await yearDir.exists()) {
          await yearDir.delete(recursive: true);
        }
        return null;
      }
    }

    final String? path = await _findExtractedFileByHref(
      rootDir: yearDir,
      href: href,
    );
    if (path == null) {
      return null;
    }
    final List<int> content = await File(path).readAsBytes();
    return _ExtractedDayHtml(
      html: _decodeBytes(content),
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

  String _decodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
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
    final List<ZsolozsmaDayPart> fromForms = <ZsolozsmaDayPart>[];
    final Set<String> seenForms = <String>{};

    for (final dom.Element form in document.querySelectorAll('form[action]')) {
      final String action = (form.attributes['action'] ?? '').trim();
      if (!_matchesDayPartTarget(rawTarget: action, date: date, yymmdd: yymmdd)) {
        continue;
      }

      final String href = _normalizeDayPartTarget(action);
      if (href.isEmpty || !seenForms.add(href)) {
        continue;
      }

      final dom.Element? input = form.querySelector('input[type="submit"]');
      final String title = _preferredDayPartTitle(
        primary: input?.attributes['title'],
        secondary: input?.attributes['value'],
        fallback: href,
      );
      fromForms.add(ZsolozsmaDayPart(title: title, href: href));
    }

    if (fromForms.isNotEmpty) {
      return fromForms;
    }

    final List<ZsolozsmaDayPart> fromAnchors = <ZsolozsmaDayPart>[];
    final Set<String> seenAnchors = <String>{};

    for (final dom.Element anchor in document.querySelectorAll('a[href]')) {
      final String href = (anchor.attributes['href'] ?? '').trim();
      if (!_matchesDayPartTarget(rawTarget: href, date: date, yymmdd: yymmdd)) {
        continue;
      }
      if (!seenAnchors.add(href)) {
        continue;
      }

      final String title = _preferredDayPartTitle(
        primary: anchor.attributes['title'],
        secondary: anchor.text,
        fallback: href,
      );
      fromAnchors.add(ZsolozsmaDayPart(title: title, href: href));
    }

    return fromAnchors;
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

  String _normalizeDayPartTarget(String rawTarget) {
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
      final String upper = baseName.toUpperCase();
      if (!upper.endsWith('.HTM')) {
        continue;
      }

      final String expectedPrefix = '${yymmdd.toUpperCase()}_';
      if (!upper.startsWith(expectedPrefix)) {
        continue;
      }

      if (!seen.add(baseName)) {
        continue;
      }

      result.add(ZsolozsmaDayPart(title: baseName, href: baseName));
    }

    result.sort((a, b) => a.href.compareTo(b.href));
    return result;
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