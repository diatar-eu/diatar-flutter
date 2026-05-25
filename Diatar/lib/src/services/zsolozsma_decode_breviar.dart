import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ZsolozsmaSlide {
  const ZsolozsmaSlide({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;
}

class ZsolozsmaBreviarDecoder {
  final List<ZsolozsmaSlide> _slides = <ZsolozsmaSlide>[];
  final Set<dom.Element> _consumed = <dom.Element>{};

  _SlideBuilder? _current;
  String _currentTitle = 'Ima';
  int _psalmState = 0;
  int _readingCount = 0;
  int _psalmCount = 0;
  int _hymnCount = 0;
  int _responsCount = 0;
  bool _isKonyorges = false;
  bool _afterHeading = false;

  List<ZsolozsmaSlide> decode(String html) {
    _slides.clear();
    _consumed.clear();
    _current = null;
    _currentTitle = 'Ima';
    _psalmState = 0;
    _readingCount = 0;
    _psalmCount = 0;
    _hymnCount = 0;
    _responsCount = 0;
    _isKonyorges = false;
    _afterHeading = false;

    final dom.Document doc = html_parser.parse(html);
    final List<dom.Element> elements = doc.querySelectorAll('*');

    for (final dom.Element element in elements) {
      if (_consumed.contains(element)) {
        continue;
      }
      final String cls = _classOf(element);

      if (!_afterHeading) {
        if (cls == 'tts_heading') {
          _afterHeading = true;
        }
        continue;
      }

      if (cls == 'respons') {
        _doRespons(element);
        _consume(element);
        continue;
      }

      if (cls == 'strong' || cls == 'par') {
        _doStrongs(element);
        _consume(element);
        continue;
      }

      if (cls == 'hymn') {
        _doHymn(element);
        _consume(element);
        continue;
      }

      if (cls.startsWith('antiphon')) {
        if (_psalmState < 2 || cls.contains('begin')) {
          _psalmState = 0;
        }
        _doAnt(element);
        _consume(element);
        continue;
      }

      if (cls.contains('psalm')) {
        if (_psalmState >= 2) {
          _psalmState = 0;
        }
        _doPsalm(element);
        _consume(element);
        continue;
      }

      if (cls == 'bibleref') {
        _doBibleref(element);
        _consume(element);
        continue;
      }

      if (cls == 'reading') {
        _doReading(element);
        _consume(element);
        continue;
      }

      if (cls == 'preces') {
        _doPreces(element);
        _consume(element);
        continue;
      }

      if (cls == 'ending') {
        // The ending container itself is just a wrapper; decode child paragraphs.
        continue;
      }

      if (cls == 'section-title') {
        final String folded = _asciiFold(_allText(element)).toUpperCase();
        if (folded == 'KONYORGES') {
          _isKonyorges = true;
        }
        continue;
      }

      if (cls.contains('red')) {
        final String txt = _cleanText(element.text);
        if (txt == 'KONYORGES' || txt == 'KONYORGES:') {
          _isKonyorges = true;
        }
        continue;
      }

      if (cls == 'tts_section') {
        _psalmState = 0;
        _isKonyorges = false;
        continue;
      }

      if (cls == 'rubric-always-display' ||
          cls == 'nav' ||
          cls == 'patka' ||
          cls == 'center rubric') {
        continue;
      }

      if (element.localName == 'a') {
        continue;
      }
    }

    _ensureClosingSlides(doc);
    _flushCurrent();

    if (_slides.isEmpty) {
      _startSlide('Ima');
      _addLine(_cleanText(doc.body?.text ?? doc.documentElement?.text ?? ''));
      _flushCurrent();
    }

    return List<ZsolozsmaSlide>.unmodifiable(_slides);
  }

  void _consume(dom.Element element) {
    _consumed.add(element);
    _consumed.addAll(element.querySelectorAll('*'));
  }

  String _classOf(dom.Element element) {
    return (element.attributes['class'] ?? '').trim();
  }

  String _cleanText(String raw) {
    return raw
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _asciiFold(String raw) {
    const Map<String, String> repl = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ö': 'o',
      'ő': 'o',
      'ú': 'u',
      'ü': 'u',
      'ű': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ö': 'O',
      'Ő': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ű': 'U',
    };
    final StringBuffer sb = StringBuffer();
    for (final int rune in raw.runes) {
      final String ch = String.fromCharCode(rune);
      sb.write(repl[ch] ?? ch);
    }
    return sb.toString();
  }

  void _startSlide(String title) {
    _flushCurrent();
    _currentTitle = title.trim().isEmpty ? 'Ima' : title.trim();
    _current = _SlideBuilder(title: _currentTitle);
  }

  void _startSectionSlide(int count, String title) {
    final String resolved = count > 1 ? '$count.$title' : title;
    _startSlide(resolved);
  }

  void _startVerse(String verseTitle) {
    if (_current == null) {
      _startSlide(_currentTitle);
    }
    if (_current!.lines.isNotEmpty) {
      _startSlide(_currentTitle);
    }
    _current!.subtitle = verseTitle;
  }

  void _addLine(String text) {
    final String clean = _cleanText(text);
    if (clean.isEmpty) {
      return;
    }
    if (_current == null) {
      _startSlide(_currentTitle);
    }
    _current!.lines.add(clean);
  }

  void _flushCurrent() {
    final _SlideBuilder? current = _current;
    if (current == null) {
      return;
    }
    final List<String> lines = current.lines
        .map(_cleanText)
        .where((String line) => line.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      final String title = current.subtitle == null
          ? current.title
          : '${current.title}/${current.subtitle!}';
      _slides.add(ZsolozsmaSlide(title: title, lines: lines));
    }
    _current = null;
  }

  Iterable<dom.Element> _paragraphs(dom.Element root) {
    return root.querySelectorAll('p');
  }

  String _allText(dom.Element element) {
    // Omit red instruction fragments and pause helpers from the projected text.
    final List<String> parts = <String>[];
    void collect(dom.Node node) {
      if (node is dom.Comment) {
        return;
      }
      if (node is dom.Element) {
        final String cls = _classOf(node);
        if (cls.startsWith('tts_pause') || cls.contains(' red')) {
          return;
        }
        for (final dom.Node child in node.nodes) {
          collect(child);
        }
        return;
      }
      final String txt = node.text ?? '';
      final String clean = _cleanText(txt);
      if (clean.isNotEmpty) {
        parts.add(clean);
      }
    }

    for (final dom.Node child in element.nodes) {
      collect(child);
    }

    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripPsalmLineNumber(String line) {
    final String trimmed = line.trimLeft();
    final String stripped = trimmed.replaceFirst(RegExp(r'^\d+\s*'), '');
    return stripped.isEmpty ? line : stripped;
  }

  String _expandHungarianDoxology(String text) {
    final String folded = _asciiFold(text).toLowerCase();
    final bool looksShort =
        folded.startsWith('dicsoseg az atyanak') &&
      folded.contains('mikeppen') &&
        !folded.contains('fiunak') &&
        !folded.contains('szentleleknek');
    if (!looksShort) {
      return text;
    }

    final bool hasAlleluja = folded.contains('alleluja');
    final String full =
        'Dicsőség az Atyának, a Fiúnak és a Szentléleknek. '
        'Miképpen kezdetben, most és mindörökké. Ámen.';
    if (!hasAlleluja) {
      return full;
    }
    return '$full Alleluja.';
  }

  void _doRespons(dom.Element root) {
    _startSectionSlide(++_responsCount, 'Responsorium');
    for (final dom.Element p in _paragraphs(root)) {
      final String cls = _classOf(p);
      String line = _allText(p);
      if (line.isEmpty) {
        continue;
      }
      if (cls == 'respV') {
        line = 'V: $line';
      } else if (cls == 'respF') {
        line = 'F: $line';
      }
      _addLine(line);
    }
  }

  void _doHymn(dom.Element root) {
    int verse = 1;
    int lineCountInVerse = 0;
    bool first = true;
    bool last = false;

    for (final dom.Element p in _paragraphs(root)) {
      final String cls = _classOf(p);
      if (cls.startsWith('rubric')) {
        if (verse > 1 || lineCountInVerse > 0) {
          _startSectionSlide(++_hymnCount, 'Himnusz');
        }
        first = true;
        last = false;
        verse = 1;
        lineCountInVerse = 0;
        continue;
      }

      if (first || lineCountInVerse >= 6) {
        if (!first) {
          verse++;
        }
        if (_hymnCount == 0 || lineCountInVerse == 0) {
          _startSectionSlide(++_hymnCount, 'Himnusz');
        }
        _startVerse('$verse');
        lineCountInVerse = 0;
      }

      if (cls.contains('first')) {
        if (!first) {
          verse++;
        }
        first = true;
      } else if (cls.contains('last')) {
        verse++;
        last = true;
      }

      final String line = _allText(p);
      if (line.isNotEmpty) {
        _addLine(line);
        lineCountInVerse++;
      }
      first = last;
      last = false;
    }
  }

  void _doAnt(dom.Element root) {
    if (_psalmState == 0) {
      _startSectionSlide(++_psalmCount, 'Zsoltar');
    }
    _psalmState = 1;
    _startVerse('Ant');
    final String txt = _allText(root);
    if (txt.isNotEmpty) {
      final String normalized = txt.replaceFirst(
        RegExp(r'^\s*(?:\d+\s*\.\s*)?ant\.?\s*', caseSensitive: false),
        '',
      );
      _addLine('Ant: ${normalized.isNotEmpty ? normalized : txt}');
    }
  }

  void _doPsalm(dom.Element root) {
    if (_psalmState == 0) {
      final String cls = _classOf(root);
      if (cls.startsWith('tedeum')) {
        _startSlide('Te Deum');
      } else {
        _startSectionSlide(++_psalmCount, 'Zsoltar');
      }
    }
    _psalmState = 2;

    int verse = 0;
    int lineCount = 9999;
    final List<dom.Element> children = root.querySelectorAll('p, div');
    for (final dom.Element el in children) {
      final String cls = _classOf(el);
      if (cls.contains('red') || cls == 'bibleref') {
        continue;
      }
      if (el.localName == 'p') {
        if (lineCount > 9 ||
            (cls.startsWith('verse') && cls.contains('start'))) {
          if (lineCount >= 4 || cls.contains('first')) {
            verse++;
            _startVerse('$verse');
            lineCount = 0;
          }
        }
        final String line = _allText(el);
        if (line.isNotEmpty) {
          _addLine(_stripPsalmLineNumber(line));
          lineCount++;
        }
      } else if (el.localName == 'div' && cls.startsWith('antiphon')) {
        _doAnt(el);
        _psalmState = 2;
        lineCount = 9999;
      }
    }
  }

  void _doBibleref(dom.Element root) {
    _startSlide('Rovid olvasmany');
    String line = '';

    // Java reference decoder uses the next tag after bibleref as the content.
    final dom.Element? sibling = root.nextElementSibling;
    if (sibling != null) {
      line = _allText(sibling);
      _consume(sibling);
    }

    if (line.isEmpty) {
      // Fallback when no usable sibling exists.
      line = _allText(root);
    }

    if (line.isNotEmpty) {
      _addLine(line);
    }
  }

  void _doStrongs(dom.Element root) {
    final String text = _allText(root);
    final String folded = _asciiFold(text);
    if (folded.startsWith('Dicsoseg az')) {
      _startSlide('Dicsoseg');
      _addLine(_expandHungarianDoxology(text));
      return;
    }

    if (folded.startsWith('Mondjunk aldast') ||
        folded.startsWith('Az Ur aldjon') ||
        folded.startsWith('A nyugodalmas')) {
      _startSlide('Aldas');
      _addLine(text);
      final dom.Element? n1 = root.nextElementSibling;
      if (n1 != null && _classOf(n1) == 'respF') {
        final String l = _allText(n1);
        if (l.isNotEmpty) {
          _addLine('F: $l');
        }
        _consume(n1);
      }
      return;
    }

    if (_isKonyorges ||
        folded.startsWith('Konyorogjunk') ||
        folded.startsWith('Istenunk') ||
        folded.startsWith('Kerunk')) {
      _startSlide('Konyorges');
      _addLine(text);
      final dom.Element? n1 = root.nextElementSibling;
      if (n1 != null) {
        final String l1 = _allText(n1);
        if (l1.isNotEmpty) {
          _addLine(l1);
        }
        final dom.Element? n2 = n1.nextElementSibling;
        if (n2 != null && _classOf(n2) == 'respF') {
          final String l2 = _allText(n2);
          if (l2.isNotEmpty) {
            _addLine('F: $l2');
          }
          _consume(n2);
        }
        _consume(n1);
      }
      return;
    }

    _startSlide('Ima');
    _addLine(text);
  }

  int _splitLongText(String text, int startPos, int verse) {
    const int maxLen = 300;
    final int effectiveStartPos = startPos < 0 ? 0 : startPos;
    if (effectiveStartPos + text.length <= maxLen) {
      _addLine(text);
      return verse;
    }

    final int pages = 1 + ((effectiveStartPos + text.length) ~/ maxLen);
    final int baseSplit = (text.length ~/ pages) - effectiveStartPos;
    int nearestSpace = 9999;
    int nearestStop = 9999;

    for (int i = 0; i <= 50; i++) {
      final int fwd = baseSplit + i;
      if (fwd >= 0 && fwd < text.length) {
        final String ch = text[fwd];
        if (ch == ' ' && nearestSpace == 9999) {
          nearestSpace = i;
        }
        if ('\n\r.,;?!'.contains(ch)) {
          nearestStop = i;
          break;
        }
      }
      final int back = baseSplit - i;
      if (back > 0 && back < text.length) {
        final String ch = text[back];
        if (ch == ' ' && nearestSpace == 9999) {
          nearestSpace = -i;
        }
        if ('\n\r.,;?!'.contains(ch)) {
          nearestStop = -i;
          break;
        }
      }
    }

    int splitDelta = nearestStop;
    if (splitDelta == 9999) {
      splitDelta = nearestSpace;
    }
    if (splitDelta == 9999) {
      splitDelta = 0;
    }

    final int splitAt = (baseSplit + splitDelta).clamp(0, text.length - 1);
    final String first = text.substring(0, splitAt).trim();
    if (first.isNotEmpty) {
      _addLine(first);
    }
    verse++;
    _startVerse('$verse');

    final int nextStart = (splitAt + 1).clamp(0, text.length);
    final String rest = text.substring(nextStart).trim();
    if (rest.isEmpty) {
      return verse;
    }
    return _splitLongText(rest, 0, verse);
  }

  void _doReading(dom.Element root) {
    _startSectionSlide(++_readingCount, 'Olvasmany');
    int verse = 0;
    String sectionPar = '';

    for (final dom.Element el in root.children) {
      final String cls = _classOf(el);
      if (cls == 'heading' ||
          cls == 'bibleref' ||
          cls == 'reading-title' ||
          cls == 'reading-source') {
        continue;
      }
      if (cls == 'resp') {
        _startVerse('Resp');
        continue;
      }
      if (cls == 'respV') {
        _addLine('V: ${_allText(el)}');
        continue;
      }
      if (cls == 'respF') {
        _addLine('F: ${_allText(el)}');
        continue;
      }
      if (cls == 'section par') {
        sectionPar = _allText(el);
        continue;
      }
      if (cls == 'par') {
        verse++;
        _startVerse('$verse');
        if (sectionPar.isNotEmpty) {
          verse = _splitLongText(sectionPar, 0, verse);
        }
        if (sectionPar.length > 20) {
          verse++;
          _startVerse('$verse');
          sectionPar = '';
        }
        verse = _splitLongText(_allText(el), sectionPar.length, verse);
        sectionPar = '';
      }
    }

    if (sectionPar.isNotEmpty) {
      verse++;
      _startVerse('$verse');
      _addLine(sectionPar);
    }
  }

  void _doPreces(dom.Element root) {
    _startSlide('Fohaszok');
    bool first = true;
    int verse = 0;

    for (final dom.Element el in root.children) {
      final String cls = _classOf(el);
      if (cls == 'intro') {
        _startVerse('Bev');
        first = false;
        _addLine(_allText(el));
        continue;
      }
      if (cls.contains('resp')) {
        if (first) {
          _startVerse('Valasz');
        }
        _addLine('F: ${_allText(el)}');
        first = true;
        continue;
      }
      if (first) {
        verse++;
        _startVerse('$verse');
        first = false;
      }
      if (cls == 'partR') {
        _addLine('R: ${_allText(el)}');
        continue;
      }
      if (cls == 'partV') {
        _addLine('V: ${_allText(el)}');
        continue;
      }
      _addLine(_allText(el));
    }
  }

  bool _hasSlideTitle(String title) {
    if (_current != null && _current!.title == title) {
      return true;
    }
    return _slides.any((ZsolozsmaSlide s) => s.title == title);
  }

  dom.Element? _findStrongByKeywords(
    List<List<String>> keywordGroups,
    dom.Document doc,
  ) {
    for (final dom.Element p in doc.querySelectorAll('p')) {
      if (_classOf(p) != 'strong') {
        continue;
      }
      final String text = _allText(p).toLowerCase();
      for (final List<String> group in keywordGroups) {
        bool ok = true;
        for (final String token in group) {
          if (!text.contains(token)) {
            ok = false;
            break;
          }
        }
        if (ok) {
          return p;
        }
      }
    }
    return null;
  }

  void _ensureClosingSlides(dom.Document doc) {
    if (!_hasSlideTitle('Konyorges')) {
      final dom.Element? kStrong = _findStrongByKeywords(
        <List<String>>[
          <String>['könyörögjünk'],
          <String>['konyorogjunk'],
          <String>['istenünk'],
          <String>['istenunk'],
          <String>['kérünk'],
          <String>['kerunk'],
        ],
        doc,
      );
      if (kStrong != null) {
        _startSlide('Konyorges');
        final String lead = _allText(kStrong);
        if (lead.isNotEmpty) {
          _addLine(lead);
        }

        final dom.Element? n1 = kStrong.nextElementSibling;
        if (n1 != null) {
          final String l1 = _allText(n1);
          if (l1.isNotEmpty) {
            _addLine(l1);
          }
          final dom.Element? n2 = n1.nextElementSibling;
          if (n2 != null && _classOf(n2) == 'respF') {
            final String l2 = _allText(n2);
            if (l2.isNotEmpty) {
              _addLine('F: $l2');
            }
          }
        }
      }
    }

    if (!_hasSlideTitle('Aldas')) {
      final dom.Element? aStrong = _findStrongByKeywords(
        <List<String>>[
          <String>['mondjunk', 'áldást'],
          <String>['mondjunk', 'aldast'],
          <String>['az úr áldjon'],
          <String>['az ur aldjon'],
          <String>['a nyugodalmas'],
        ],
        doc,
      );
      if (aStrong != null) {
        _startSlide('Aldas');
        final String lead = _allText(aStrong);
        if (lead.isNotEmpty) {
          _addLine(lead);
        }
        final dom.Element? n1 = aStrong.nextElementSibling;
        if (n1 != null && _classOf(n1) == 'respF') {
          final String l1 = _allText(n1);
          if (l1.isNotEmpty) {
            _addLine('F: $l1');
          }
        }

      }
    }
  }

}

class _SlideBuilder {
  _SlideBuilder({required this.title});

  final String title;
  String? subtitle;
  final List<String> lines = <String>[];
}
