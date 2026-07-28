import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/custom_order_entry.dart';
import '../utils/text_chunking.dart';

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
      final Uri uri = Uri.parse(url);
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
      // A celebration may carry its sections in `parts` and/or `parts2`; both
      // use the same structure and must be imported. `parts2` follows `parts`.
      final List<Map<String, dynamic>> typedParts = <Map<String, dynamic>>[
        ..._typedPartsFrom(raw['parts']),
        ..._typedPartsFrom(raw['parts2']),
      ];
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

  /// Normalizes a raw `parts`/`parts2` value into typed part maps.
  ///
  /// Each element is either a part dict or — for a "vagy" (either-or) section
  /// in the single-day file — a bare list of variant dicts. The latter is
  /// wrapped as `{type: 'array', content: [...]}` so the builder includes
  /// every variant.
  List<Map<String, dynamic>> _typedPartsFrom(dynamic rawParts) {
    final List<Map<String, dynamic>> typed = <Map<String, dynamic>>[];
    final List<dynamic>? parts = rawParts as List<dynamic>?;
    if (parts == null) {
      return typed;
    }
    for (final dynamic part in parts) {
      if (part is Map<String, dynamic>) {
        typed.add(part);
      } else if (part is List) {
        typed.add(<String, dynamic>{
          'type': 'array',
          'content': part,
        });
      }
    }
    return typed;
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

    // The celebration's own title is shown as the virtual book label, not as
    // a projected slide, so only the reading sections are turned into slides.
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

    // Array type: multiple variants (e.g. I. év / II. év, or a "vagy" either-or
    // form where a longer and a shorter reading are both offered). Every
    // variant is included as its own set of slides, so the user can choose
    // which one to project.
    if (type == 'array') {
      final List<dynamic>? content = part['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        final List<CustomOrderEntry> entries = <CustomOrderEntry>[];
        final int variantCount = content.length;
        for (int v = 0; v < variantCount; v++) {
          final dynamic item = content[v];
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final List<CustomOrderEntry> variantEntries =
              _entriesForPart(item, wordsPerSlide: wordsPerSlide);
          // When a part offers several alternatives (e.g. a longer and a
          // shorter "vagy" reading), each alternative must appear as its own
          // selectable item rather than being merged into one continuous
          // verse sequence. We tag every alternative with a distinguishing
          // suffix so the UI groups them separately, while a single
          // alternative's own split verses stay together.
          if (variantCount > 1) {
            final String cause = _stringOrEmpty(item['cause']);
            final String suffix =
                cause.isNotEmpty ? cause : 'változat ${v + 1}';
            entries.addAll(_tagVariantEntries(variantEntries, suffix));
          } else {
            entries.addAll(variantEntries);
          }
        }
        return entries;
      }
      return const <CustomOrderEntry>[];
    }

    final String shortTitle = _stringOrEmpty(part['short_title']);

    // Psalms are split along the cantor (Előénekes/E) and faithful (Hívek/H)
    // lines and are not labelled with the generic "zsoltár" title.
    if (shortTitle == 'zsoltár') {
      return _psalmEntries(part, wordsPerSlide: wordsPerSlide);
    }
    // The alleluia acclamation is wrapped with "Alleluja" at the start and end.
    if (shortTitle == 'alleluja') {
      return _allelujaEntries(part, wordsPerSlide: wordsPerSlide);
    }

    return _genericEntries(part, wordsPerSlide: wordsPerSlide);
  }

  /// Tags every entry of an array variant with [suffix] so the UI groups that
  /// alternative as its own selectable item instead of merging it with the
  /// other alternatives into one continuous verse sequence.
  ///
  /// The suffix is inserted before any "/N" verse number in the title (and the
  /// matching label), so a variant that is split across several slides keeps
  /// its own verses grouped together while still being distinct from the other
  /// alternatives.
  List<CustomOrderEntry> _tagVariantEntries(
    List<CustomOrderEntry> entries,
    String suffix,
  ) {
    if (suffix.isEmpty) {
      return entries;
    }
    final String tag = ' ($suffix)';
    return entries.map((CustomOrderEntry e) {
      final String title = e.customTextTitle ?? '';
      final int slashIdx = title.lastIndexOf('/');
      final String newTitle = slashIdx >= 0
          ? '${title.substring(0, slashIdx)}$tag${title.substring(slashIdx)}'
          : '$title$tag';
      final String newLabel =
          e.label.startsWith('[Batyu] ') ? '[Batyu] $newTitle' : newTitle;
      return e.copyWith(customTextTitle: newTitle, label: newLabel);
    }).toList();
  }

  /// Builds the body lines (HTML stripped) for a part, optionally prefixed with
  /// the [ref] line. Used by the specialized psalm/alleluia builders.
  List<String> _bodyLinesForPart(Map<String, dynamic> part, {String ref = ''}) {
    final List<String> lines = <String>[];
    if (ref.isNotEmpty) {
      lines.add(ref);
    }
    final String? text = part['text'] as String?;
    if (text != null && text.trim().isNotEmpty) {
      lines.addAll(_stripHtmlToLines(text));
    } else {
      final List<dynamic>? verses = part['verses'] as List<dynamic>?;
      if (verses != null && verses.isNotEmpty) {
        for (final dynamic verse in verses) {
          final String line = verse is String ? verse : '$verse';
          lines.addAll(_stripHtmlToLines(line));
        }
        final String answer = _stringOrEmpty(part['answer']);
        if (answer.isNotEmpty) {
          lines.add(_stripHtmlToWords(answer).join(' '));
        }
      }
    }
    return lines;
  }

  List<CustomOrderEntry> _genericEntries(
    Map<String, dynamic> part, {
    required int wordsPerSlide,
  }) {
    final String title = _stringOrEmpty(part['title']);
    final String shortTitle = _stringOrEmpty(part['short_title']);
    final String ref = _stringOrEmpty(part['ref']);

    final String slideTitle = title.isNotEmpty ? title : shortTitle;

    // Collect the raw body lines (HTML stripped) for this part. The title and
    // the reference (where to read from) are kept at the beginning; the
    // closing formula (ending) is intentionally dropped as it is not needed.
    // Line breaks from the source are preserved as visual line breaks inside
    // a slide, but they never force a new slide.
    final List<String> bodyLines = <String>[];
    if (slideTitle.isNotEmpty) {
      bodyLines.add(slideTitle);
    }
    if (ref.isNotEmpty) {
      bodyLines.add(ref);
    }
    bodyLines.addAll(_bodyLinesForPart(part));

    if (bodyLines.isEmpty) {
      return const <CustomOrderEntry>[];
    }

    final String effectiveTitle = slideTitle.isNotEmpty ? slideTitle : 'Olvasmány';

    // Split the body into multiple verses. We prefer to break at sentence,
    // clause or quotation boundaries, but never exceed [wordsPerSlide] words.
    // Each verse becomes a separate custom-text entry (songIndex = -1) so it
    // can be paged through like a song's verses. The title uses a "Title/N"
    // format so the order list groups them as one item with multiple verses
    // (not as separate songs). Original line breaks are kept inside a verse.
    final List<List<String>> chunks = chunkLinesByBoundary(
      bodyLines,
      wordsPerSlide,
    );
    final List<CustomOrderEntry> entries = <CustomOrderEntry>[];
    for (int i = 0; i < chunks.length; i++) {
      final String verseTitle = chunks.length > 1
          ? '$effectiveTitle/${i + 1}'
          : effectiveTitle;
      entries.add(
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: i,
          label: '[Batyu] $verseTitle',
          customTextTitle: verseTitle,
          customTextBody: tokensToText(chunks[i]),
          customType: 'text',
        ),
      );
    }
    return entries;
  }

  /// Builds the slides for a responsorial psalm.
  ///
  /// The psalm is split into cantor/faithful stanzas at every "Előénekes:"/"E:"
  /// line (the cantor's verse), keeping the leading antiphon with the first
  /// stanza. Consecutive stanzas are packed onto the same slide while the
  /// combined word count stays within [wordsPerSlide] (so two short stanzas may
  /// share a slide), but a single stanza is never split. The generic "zsoltár"
  /// label is intentionally omitted from the title.
  List<CustomOrderEntry> _psalmEntries(
    Map<String, dynamic> part, {
    required int wordsPerSlide,
  }) {
    final String ref = _stringOrEmpty(part['ref']);
    final List<String> lines = _bodyLinesForPart(part, ref: ref);

    if (lines.isEmpty) {
      return const <CustomOrderEntry>[];
    }

    final List<List<String>> stanzas = _splitPsalmStanzas(lines);
    final List<List<String>> slides = _packStanzas(stanzas, wordsPerSlide);

    final List<CustomOrderEntry> entries = <CustomOrderEntry>[];
    for (int i = 0; i < slides.length; i++) {
      entries.add(
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: i,
          label: '[Batyu] Zsoltár/${i + 1}',
          // The "Zsoltár" type name is shown as the slide title, but it is kept
          // out of the body text (the antiphon itself starts the slide).
          customTextTitle: slides.length > 1 ? 'Zsoltár/${i + 1}' : 'Zsoltár',
          customTextBody: slides[i].join('\n'),
          customType: 'text',
        ),
      );
    }
    return entries;
  }

  /// Builds the slides for the alleluia acclamation.
  ///
  /// The text is chunked by word count (with semantic boundaries) like any
  /// other reading, but every slide is wrapped with "Alleluja" at the start and
  /// at the end, as required for the acclamation.
  List<CustomOrderEntry> _allelujaEntries(
    Map<String, dynamic> part, {
    required int wordsPerSlide,
  }) {
    final String teaser = _stringOrEmpty(part['teaser']);
    final String ref = _stringOrEmpty(part['ref']);
    final List<String> lines = _bodyLinesForPart(part, ref: ref);

    if (lines.isEmpty) {
      // Even an empty alleluia shows the acclamation.
      return <CustomOrderEntry>[
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: 0,
          label: '[Batyu] Alleluja',
          customTextTitle: 'Alleluja',
          customTextBody: 'Alleluja\n\nAlleluja',
          customType: 'text',
        ),
      ];
    }

    final List<List<String>> chunks = chunkLinesByBoundary(lines, wordsPerSlide);
    final List<CustomOrderEntry> entries = <CustomOrderEntry>[];
    for (int i = 0; i < chunks.length; i++) {
      final String body = tokensToText(chunks[i]);
      final List<String> wrapped = <String>['Alleluja', body, 'Alleluja'];
      entries.add(
        CustomOrderEntry(
          fileName: '__custom_text__',
          songIndex: -1,
          verseIndex: i,
          label: '[Batyu] Alleluja/${i + 1}',
          // The "Alleluja" type name is shown as the slide title; the body is
          // wrapped with "Alleluja" at the start and end.
          customTextTitle: chunks.length > 1 ? 'Alleluja/${i + 1}' : 'Alleluja',
          customTextBody: wrapped.join('\n'),
          customType: 'text',
        ),
      );
    }
    return entries;
  }

  /// Splits psalm [lines] into stanzas. A new stanza begins at every line that
  /// starts with "Előénekes:" or "E:" (the cantor's verse), but only when the
  /// current stanza already contains a verse — so the leading antiphon lines
  /// before the first verse stay attached to the first stanza instead of
  /// becoming their own slide.
  List<List<String>> _splitPsalmStanzas(List<String> lines) {
    bool stanzaHasVerse(List<String> stanza) => stanza.any(
          (String l) {
            final String t = l.trim();
            return t.startsWith('Előénekes:') || t.startsWith('E:');
          },
        );

    final List<List<String>> stanzas = <List<String>>[];
    List<String> current = <String>[];
    for (final String line in lines) {
      final String trimmed = line.trim();
      final bool isVerseStart =
          trimmed.startsWith('Előénekes:') || trimmed.startsWith('E:');
      if (isVerseStart && stanzaHasVerse(current)) {
        stanzas.add(current);
        current = <String>[];
      }
      current.add(line);
    }
    if (current.isNotEmpty) {
      stanzas.add(current);
    }
    return stanzas;
  }

  /// Packs psalm [stanzas] into slides, combining consecutive stanzas while the
  /// combined word count stays within [maxWords]. A single stanza is never
  /// split, so each slide is a whole cantor/faithful unit (or two when they fit
  /// together). A blank line separates packed stanzas for readability.
  List<List<String>> _packStanzas(List<List<String>> stanzas, int maxWords) {
    final int limit = maxWords < 1 ? 1 : maxWords;
    final List<List<String>> slides = <List<String>>[];
    List<String> current = <String>[];
    int currentWords = 0;
    for (final List<String> stanza in stanzas) {
      final int stanzaWords = _countWordsInLines(stanza);
      if (current.isEmpty) {
        current = List<String>.from(stanza);
        currentWords = stanzaWords;
      } else if (currentWords + stanzaWords <= limit) {
        current.add('');
        current.addAll(stanza);
        currentWords += stanzaWords;
      } else {
        slides.add(current);
        current = List<String>.from(stanza);
        currentWords = stanzaWords;
      }
    }
    if (current.isNotEmpty) {
      slides.add(current);
    }
    return slides;
  }

  int _countWordsInLines(List<String> lines) {
    int count = 0;
    for (final String line in lines) {
      count += line
          .split(RegExp(r'\s+'))
          .where((String w) => w.trim().isNotEmpty)
          .length;
    }
    return count;
  }

  /// Converts an HTML-ish string into clean text lines.
  ///
  /// `<br>` and block-level closing tags become line breaks, inline tags such
  /// as `<b>` are removed, and HTML entities are decoded. The resulting lines
  /// preserve the original line structure (useful for keeping line breaks on
  /// the slide) but each line is a single string of space-joined words.
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

  /// Converts an HTML-ish string into a flat list of clean words.
  ///
  /// All tags are removed, HTML entities are decoded, and the text is split
  /// into individual words (whitespace-separated). Line structure is
  /// intentionally discarded so the caller can re-flow the text freely.
  List<String> _stripHtmlToWords(String html) {
    return _stripHtmlToLines(html)
        .expand((String line) => line.split(RegExp(r'\s+')))
        .where((String w) => w.trim().isNotEmpty)
        .toList();
  }

  /// Splits [lines] into chunks of at most [maxWords] words.
  ///
  /// The split prefers natural boundaries in this order:
  ///  1. sentence end (`.`, `!`, `?` possibly followed by `"`/`»`/`”`)
  ///  2. clause boundary (`,`, `;`, `:`, `–`, `—`)
  ///  3. quotation edge (`„`, `”`, `»`, `«`, `"`)
  ///  4. hard word limit as a last resort
  ///
  /// Once the word count reaches [maxWords], the chunk breaks at the *first*
  /// available boundary (so a slide ends at a sentence or clause rather than
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