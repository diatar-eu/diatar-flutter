/// Splits [lines] into chunks of at most [maxWords] words, breaking at
/// sentence, clause or quotation boundaries when possible.
///
/// Returns a list of token lists where each token is either a word or the
/// sentinel `'\n'` representing a line break from the original source.
List<List<String>> chunkLinesByBoundary(List<String> lines, int maxWords) {
  final int limit = maxWords < 1 ? 1 : maxWords;
  if (lines.isEmpty) {
    return const <List<String>>[];
  }

  bool isSentenceEnd(String w) =>
      w.endsWith('.') ||
      w.endsWith('!') ||
      w.endsWith('?') ||
      w.endsWith('."') ||
      w.endsWith('!"') ||
      w.endsWith('?"') ||
      w.endsWith('."') ||
      w.endsWith('!"') ||
      w.endsWith('?"') ||
      w.endsWith('.»') ||
      w.endsWith('!"') ||
      w.endsWith('?»');

  bool isClauseBoundary(String w) =>
      w.endsWith(',') ||
      w.endsWith(';') ||
      w.endsWith(':') ||
      w.endsWith('–') ||
      w.endsWith('—') ||
      w.endsWith('",') ||
      w.endsWith('".') ||
      w.endsWith('»,') ||
      w.endsWith('».');

  bool isQuoteEdge(String w) =>
      w.startsWith('„') ||
      w.startsWith('»') ||
      w.startsWith('"') ||
      w.startsWith('"') ||
      w.endsWith('”') ||
      w.endsWith('«') ||
      w.endsWith('”') ||
      w.endsWith('"');

  final List<String> tokens = <String>[];
  for (int li = 0; li < lines.length; li++) {
    if (li > 0) {
      tokens.add('\n');
    }
    final List<String> words = lines[li]
        .split(RegExp(r'\s+'))
        .where((String w) => w.trim().isNotEmpty)
        .toList();
    tokens.addAll(words);
  }

  bool isBoundary(String w) =>
      isSentenceEnd(w) || isClauseBoundary(w) || isQuoteEdge(w);

  int indexAfterNthWord(List<String> toks, int n) {
    int c = 0;
    for (int k = 0; k < toks.length; k++) {
      if (toks[k] != '\n') {
        c++;
        if (c == n) {
          return k + 1;
        }
      }
    }
    return toks.length;
  }

  (int, int) scanOverflow(List<String> toks) {
    int c = 0;
    int lb = -1;
    for (int k = 0; k < toks.length; k++) {
      final String t = toks[k];
      if (t == '\n') {
        continue;
      }
      c++;
      if (c <= limit && isBoundary(t)) {
        lb = k;
      }
    }
    return (c, lb);
  }

  final List<List<String>> chunks = <List<String>>[];
  List<String> current = <String>[];
  int count = 0;
  int lastBoundaryIndex = -1;

  for (int i = 0; i < tokens.length; i++) {
    final String tok = tokens[i];
    if (tok == '\n') {
      current.add('\n');
      continue;
    }

    current.add(tok);
    count++;
    if (count <= limit && isBoundary(tok)) {
      lastBoundaryIndex = current.length - 1;
    }

    final bool atEnd = i == tokens.length - 1;

    if (atEnd || count > limit) {
      if (count > limit && lastBoundaryIndex >= 0) {
        final List<String> overflow = current.sublist(lastBoundaryIndex + 1);
        current = current.sublist(0, lastBoundaryIndex + 1);
        chunks.add(current);
        current = overflow;
      } else if (count > limit) {
        final int cut = indexAfterNthWord(current, limit);
        final List<String> overflow = current.sublist(cut);
        current = current.sublist(0, cut);
        chunks.add(current);
        current = overflow;
      } else {
        chunks.add(current);
        current = <String>[];
      }
      final (int nc, int nlb) = scanOverflow(current);
      count = nc;
      lastBoundaryIndex = nlb;
    }
  }

  if (current.isNotEmpty) {
    chunks.add(current);
  }
  return chunks;
}

/// Joins a token list (words and '\n' line-break sentinels) into a single
/// string where words on the same source line are space-joined and '\n'
/// tokens become real line breaks.
String tokensToText(List<String> tokens) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < tokens.length; i++) {
    final String tok = tokens[i];
    if (tok == '\n') {
      final String text = buffer.toString();
      if (text.endsWith('\n') || text.isEmpty) {
        continue;
      }
      buffer.write('\n');
    } else {
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
        buffer.write(' ');
      }
      buffer.write(tok);
    }
  }
  return buffer.toString().trim();
}
