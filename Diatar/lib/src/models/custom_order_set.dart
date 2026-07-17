import 'custom_order_entry.dart';

/// Egy betöltött énekrend (saját diasor) állapota.
///
/// Több énekrend is tartható meg párhuzamosan: mindegyik saját névvel,
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
  });

  final String id;
  final String name;
  final List<CustomOrderEntry> entries;
  final bool enabled;
  final String? baseName;
  final String? sourceType;
  final String? zsolozsmaLabel;
  final String? batyuLabel;

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
    return 'Énekrend';
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
    );
  }
}