import 'custom_order_entry.dart';

/// Egy betöltött diasor (saját diasor) állapota.
///
/// Több diasor is tartható meg párhuzamosan: mindegyik saját névvel,
/// bejegyzéslistával és engedélyezési állapottal rendelkezik. A vezérlő
/// egyszerre mindig egyet tart aktívnak (ezt navigálja/vetíti), de a
/// betöltöttek közül bármelyik kiválasztható vagy letiltható.
class CustomOrderSet {
  const CustomOrderSet({
    required this.id,
    required this.name,
    required this.entries,
    this.enabled = true,
    this.baseName,
    this.sourceType,
    this.zsolozsmaLabel,
    this.batyuLabel,
    this.cursor = -1,
  });

  final String id;
  final String name;
  final List<CustomOrderEntry> entries;
  final bool enabled;
  final String? baseName;
  final String? sourceType;
  final String? zsolozsmaLabel;
  final String? batyuLabel;

  /// A diasor utoljára ismert kurzorpozíciója (a bejegyzéslistában).
  /// Diasorok közötti váltáskor ezt tároljuk el, hogy visszaváltáskor
  /// ugyanoda kerüljön a kurzor. Érvénytelen (üres lista) esetén -1.
  final int cursor;

  /// A felhasználói felületen megjelenítendő név.
  ///
  /// Előnyben részesíti a származtatott címkéket (zsolozsma/batyu), majd a
  /// fájlnévből származtatott alapnevet, végül magát a megadott nevet.
  String get displayName {
    final String? derived = zsolozsmaLabel ?? batyuLabel ?? baseName;
    final String trimmed = (derived ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final String named = name.trim();
    if (named.isNotEmpty) {
      return named;
    }
    return 'Diasor';
  }

  CustomOrderSet copyWith({
    String? id,
    String? name,
    List<CustomOrderEntry>? entries,
    bool? enabled,
    String? baseName,
    bool clearBaseName = false,
    String? sourceType,
    bool clearSourceType = false,
    String? zsolozsmaLabel,
    bool clearZsolozsmaLabel = false,
    String? batyuLabel,
    bool clearBatyuLabel = false,
    int? cursor,
    bool clearCursor = false,
  }) {
    return CustomOrderSet(
      id: id ?? this.id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
      enabled: enabled ?? this.enabled,
      baseName: clearBaseName ? null : (baseName ?? this.baseName),
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      zsolozsmaLabel:
          clearZsolozsmaLabel ? null : (zsolozsmaLabel ?? this.zsolozsmaLabel),
      batyuLabel: clearBatyuLabel ? null : (batyuLabel ?? this.batyuLabel),
      cursor: clearCursor ? -1 : (cursor ?? this.cursor),
    );
  }
}