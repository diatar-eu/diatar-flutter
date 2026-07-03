String removeEscapeSequences(String line) {
  String result = line;
  bool escaping = false;
  int index = 0;

  while (index < result.length) {
    final String character = result[index];
    if (escaping) {
      switch (character) {
        case 'B':
        case 'U':
        case 'I':
        case 'b':
        case 'u':
        case 'i':
        case 'S':
        case 's':
        case '(':
        case ')':
          result = result.replaceRange(index, index + 1, '');
          continue;
        case '.':
          result = result.replaceRange(index, index + 1, ' ');
          index++;
          break;
        case '_':
          result = result.replaceRange(index, index + 1, '-');
          index++;
          break;
        case 'G':
        case 'K':
        case '?':
          while (index < result.length && result[index] != ';') {
            result = result.replaceRange(index, index + 1, '');
          }
          if (index < result.length) {
            result = result.replaceRange(index, index + 1, '');
          }
          break;
        default:
          index++;
          break;
      }
      escaping = false;
      continue;
    }

    escaping = character == '\\';
    if (escaping) {
      result = result.replaceRange(index, index + 1, '');
    } else {
      index++;
    }
  }

  return result;
}

String firstMeaningfulLine(Iterable<String> lines) {
  for (final String rawLine in lines) {
    final String cleaned = removeEscapeSequences(rawLine).trim();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return '';
}

String firstMeaningfulLineFromText(String text) {
  return firstMeaningfulLine(text.split(RegExp(r'\r?\n')));
}
