/// A latin ékezetes betűket az alapbetűjükre képezi (kisbetűs formában).
const Map<String, String> _accentMap = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a',
  'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'č': 'c', 'ċ': 'c',
  'ď': 'd', 'đ': 'd',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e',
  'ƒ': 'f', 'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
  'ĥ': 'h', 'ı': 'i',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'į': 'i',
  'ĵ': 'j',
  'ķ': 'k', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ł': 'l', 'ŀ': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n', 'ŉ': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
  'ŏ': 'o', 'ő': 'o',
  'œ': 'oe',
  'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
  'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ș': 's',
  'ť': 't', 'ţ': 't', 'ŧ': 't', 'ț': 't',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u',
  'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ŵ': 'w',
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// A dalok kereséséhez használt normalizáló.
///
/// A bemenetet kisbetűsíti, az ékezetes (latin) betűket az alapbetűjükre
/// vetíti, az írásjeleket és minden nem-alfanumerikus karaktert pedig
/// eltávolítja. Eredménye csak kisbetűs angol betűket és számjegyeket
/// tartalmaz.
///
/// A keresésnél ugyanezt kell alkalmazni mind a keresőindex (találat)
/// szövegére, mind a keresőkifejezésre, hogy az ékezet-, írásjel- és
/// kis-nagybetű-független egyezés biztosított legyen.
String normalizeSearchText(String text) {
  final String lower = text.toLowerCase();
  final StringBuffer sb = StringBuffer();
  for (final int r in lower.runes) {
    final String ch = String.fromCharCode(r);
    final String mapped = _accentMap[ch] ?? ch;
    sb.write(mapped);
  }
  return sb.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
