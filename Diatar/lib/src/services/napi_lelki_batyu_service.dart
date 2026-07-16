import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/custom_order_entry.dart';

/// A single liturgical celebration (ünnep) of a day in the Napi Lelki Batyu data.
class NapiLelkiBatyuCelebration {
  const NapiLelkiBatyuCelebration({
    required this.key,
    required this.name,
    required this.title,
    required this.parts,
  });

  final int key;
  final String name;
  final String title;
  final List<Map<String, dynamic>> parts;

  /// Short secondary line shown under the title in the import dialog.
  ///
  /// Falls back to the celebration's [name] when no part provides a title.
  String? get subtitle {
    for (final Map<String, dynamic> part in parts) {
      final dynamic rawTitle = part['title'];
      if (rawTitle is String && rawTitle.trim().isNotEmpty) {
        return rawTitle.trim();
      }
    }
    return name.trim().isNotEmpty ? name.trim() : null;
  }
}

/// Service that downloads and parses the Napi Lelki Batyu JSON data.
///
/// The data is published at:
///   https://szentjozsefhackathon.github.io/napi-lelki-batyu/ÉVSZÁM.json        (full year)
///   https://szentjozsefhackathon.github.io/napi-lelki-batyu/ÉVSZÁM-HH-NN.json  (single day)
class NapiLelkiBatyuService {
  static const String _baseUrl =
      'https://szentjozsefhackathon.github.io/napi-lelki-batyu/';
  static const String _webProxyUrl = 'https://diatar.eu/batyu.php';

  /// Fetches the day JSON for [date]. Tries the single-day file first, then
  /// falls back to the full-year file and extracts the requested day.
  Future<Map<String, dynamic>> fetchDayJson(DateTime date) async {
    final String iso = _formatIsoDate(date);
    final String dayFile = '$_baseUrl$iso.json';
    final String yearFile = '$_baseUrl${date.year}.json';

    final Map<String, dynamic>? dayJson = await _tryParse(dayFile);
    if (dayJson != null && dayJson.containsKey('celebration')) {
      return _normalizeDay(iso, dayJson);
    }

    final Map<String, dynamic>? yearJson = await _tryParse(yearFile);
    if (yearJson != null && yearJson.containsKey(iso)) {
      final dynamic dayEntry = yearJson[iso];
      if (dayEntry is Map<String, dynamic>) {
        return _normalizeDay(iso, dayEntry);
      }
    }

    throw Exception('Napi lelki batyu adat nem érhető el: $iso');
  }

  Map<String, dynamic> _normalizeDay(
    String iso,
    Map<String, dynamic> raw,
  ) {
    // Ensure the date key is present for downstream consumers.
    final Map<String, dynamic> result = <String, dynamic>{...raw};
    result['ISO'] = iso;
    return result;
  }

  Future<Map<String, dynamic>?> _tryParse(String url) async {
    try {
      final Uri uri = _buildUri(url);
      final http.Response response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Uri _buildUri(String url) {
    if (!kIsWeb) {
      return Uri.parse(url);
    }
    // On the web we route through a proxy to avoid CORS issues.
    return Uri.parse(_webProxyUrl).replace(
      queryParameters: <String, String>{'url': url},
    );
  }

  /// Parses the celebrations (ünnepek) of a day JSON into a list.
  List<NapiLelkiBatyuCelebration> parseCelebrations(
    Map<String, dynamic> dayJson,
  ) {
    final List<dynamic>? celebrations = dayJson['celebration'] as List<dynamic>?;
    if (celebrations == null || celebrations.isEmpty) {
      return const <NapiLelkiBatyuCelebration>[];
    }

    final List<NapiLelkiBatyuCelebration> result =
        <NapiLelkiBatyuCelebration>[];
    for (int i = 0; i < celebrations.length; i++) {
      final dynamic raw = celebrations[i];
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String name = _stringOrEmpty(raw['name']);
      final String title = _stringOrEmpty(raw['title']).isNotEmpty
          ? _stringOrEmpty(raw['title'])
          : name;
      final List<dynamic>? parts = raw['parts'] as List<dynamic>?;
      final List<Map<String, dynamic>> typedParts =
          parts?.whereType<Map<String, dynamic>>().toList() ??
              const <Map<String, dynamic>>[];
      result.add(
        NapiLelkiBatyuCelebration(
          key: raw['celebrationKey'] is int ? raw['celebrationKey'] as int : i,
          name: name,
          title: title,
          parts: typedParts,
        ),
      );
    }
    return result;
  }

  /// Builds the custom-order text entries (diák) for a celebration.
  ///
  /// Each part of the celebration becomes one (or more) text slides. The
  /// structure mirrors how the Zsolozsma import builds [CustomOrderEntry]
  /// objects so the result can be loaded as a virtual book via
  /// [DiatarMainController.applyCustomOrder].
  ///
  /// [wordsPerSlide] controls how many words are kept on a single slide
  /// before the text is split into the next slide.
  List<CustomOrderEntry> buildEntries(
    NapiLelkiBatyuCelebration celebration, {
    int wordsPerSlide = 30,
  }) {
    final List<CustomOrderEntry> entries = <CustomOrderEntry>[];

    // A title slide for the celebration itself.
    if (celebration.title.trim().isNotEmpty) {
      entries.add(
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: 0,
          label: '[Batyu] ${celebration.title.trim()}',
          customTextTitle: celebration.title.trim(),
          customTextBody: celebration.name.trim().isEmpty
              ? celebration.title.trim()
              : celebration.name.trim(),
          customType: 'text',
        ),
      );
    }

    for (final Map<String, dynamic> part in celebration.parts) {
      entries.addAll(_entriesForPart(part, wordsPerSlide: wordsPerSlide));
    }

    return entries;
  }

  List<CustomOrderEntry> _entriesForPart(
    Map<String, dynamic> part, {
    required int wordsPerSlide,
  }) {
    final String type = _stringOrEmpty(part['type']);

    // Array type: multiple variants (e.g. I. év / II. év). Use the first one.
    if (type == 'array') {
      final List<dynamic>? content = part['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        final dynamic first = content.first;
        if (first is Map<String, dynamic>) {
          return _entriesForPart(first, wordsPerSlide: wordsPerSlide);
        }
      }
      return const <CustomOrderEntry>[];
    }

    final String shortTitle = _stringOrEmpty(part['short_title']);
    final String title = _stringOrEmpty(part['title']);
    final String ref = _stringOrEmpty(part['ref']);
    final String ending = _stringOrEmpty(part['ending']);

    final String slideTitle = title.isNotEmpty ? title : shortTitle;

    // Collect the raw body lines (HTML stripped) for this part.
    final List<String> bodyLines = <String>[];
    if (ref.isNotEmpty) {
      bodyLines.add(ref);
    }

    final String? text = part['text'] as String?;
    if (text != null && text.trim().isNotEmpty) {
      bodyLines.addAll(_stripHtmlToLines(text));
    } else {
      final List<dynamic>? verses = part['verses'] as List<dynamic>?;
      if (verses != null && verses.isNotEmpty) {
        for (final dynamic verse in verses) {
          final String line = verse is String ? verse : '$verse';
          final List<String> cleaned = _stripHtmlToLines(line);
          for (final String trimmed in cleaned) {
            if (trimmed.trim().isNotEmpty) {
              bodyLines.add(trimmed);
            }
          }
        }
        final String answer = _stringOrEmpty(part['answer']);
        if (answer.isNotEmpty) {
          bodyLines.add('');
          bodyLines.add(_stripHtmlToLines(answer).join(' '));
        }
      }
    }

    if (ending.isNotEmpty) {
      bodyLines.add('');
      bodyLines.add(_stripHtmlToLines(ending).join(' '));
    }

    if (bodyLines.isEmpty) {
      return const <CustomOrderEntry>[];
    }

    final String effectiveTitle = slideTitle.isNotEmpty ? slideTitle : 'Olvasmány';

    // Split the body into multiple slides by word count so each slide stays
    // readable (the projection would otherwise shrink a very long text).
    final List<List<String>> chunks = _chunkLinesByWords(
      bodyLines,
      wordsPerSlide,
    );
    final List<CustomOrderEntry> entries = <CustomOrderEntry>[];
    for (int i = 0; i < chunks.length; i++) {
      final String chunkTitle = chunks.length > 1
          ? '$effectiveTitle (${i + 1}/${chunks.length})'
          : effectiveTitle;
      entries.add(
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: 0,
          label: '[Batyu] $chunkTitle',
          customTextTitle: chunkTitle,
          customTextBody: chunks[i].join('\n'),
          customType: 'text',
        ),
      );
    }
    return entries;
  }

  /// Converts an HTML-ish string into clean text lines.
  ///
  /// `<br>` and `</p>`-like tags become line breaks, inline tags such as `<b>`
  /// are removed, and HTML entities are decoded.
  List<String> _stripHtmlToLines(String html) {
    String working = html;
    // Line breaks first so block elements separate into lines.
    working = working.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    working = working.replaceAll(
      RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false),
      '\n',
    );
    // Drop every remaining tag.
    working = working.replaceAll(RegExp(r'<[^>]+>'), '');
    // Decode the most common HTML entities. The ampersand-prefixed keys are
    // built at runtime to avoid writing literal entities in source.
    final String amp = '&';
    final Map<String, String> entities = <String, String>{
      '$amp''amp;': '&',
      '$amp''lt;': '<',
      '$amp''gt;': '>',
      '$amp''quot;': '"',
      '$amp''apos;': "'",
      '$amp''#39;': "'",
      '$amp''nbsp;': ' ',
    };
    for (final MapEntry<String, String> entry in entities.entries) {
      working = working.replaceAll(entry.key, entry.value);
    }
    return working
        .split('\n')
        .map((String l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((String l) => l.isNotEmpty)
        .toList();
  }

  /// Splits [lines] into chunks so that each chunk contains at most
  /// [wordsPerSlide] words. Lines are kept intact (a line is never split in
  /// the middle), so a chunk may slightly exceed the limit when a single line
  /// is longer than [wordsPerSlide].
  List<List<String>> _chunkLinesByWords(List<String> lines, int wordsPerSlide) {
    final int limit = wordsPerSlide < 1 ? 1 : wordsPerSlide;
    final List<List<String>> chunks = <List<String>>[];
    List<String> current = <String>[];
    int wordCount = 0;

    void flush() {
      if (current.isNotEmpty) {
        chunks.add(current);
        current = <String>[];
        wordCount = 0;
      }
    }

    for (final String line in lines) {
      final int lineWords = line
          .split(RegExp(r'\s+'))
          .where((String w) => w.trim().isNotEmpty)
          .length;
      if (current.isNotEmpty && wordCount + lineWords > limit) {
        flush();
      }
      current.add(line);
      wordCount += lineWords;
    }
    flush();
    return chunks;
  }

  String _stringOrEmpty(dynamic value) {
    if (value == null) {
      return '';
    }
    return '$value'.trim();
  }

  String _formatIsoDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}