import '../../l10n/generated/app_localizations.dart';
import '../models/custom_order_entry.dart';

const List<String> _customEntryPrefixes = <String>[
  '[Szoveg]',
  '[Kep]',
  '[Kép]',
  'Dia:',
  'DIA:',
  'Kep:',
  'Kép:',
  'Slide:',
  'Image:',
];

String customTextEntryTitle(CustomOrderEntry entry) {
  final String explicit = (entry.customTextTitle ?? '').trim();
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final String stripped = _stripCustomEntryPrefix(entry.label);
  return stripped.isEmpty ? 'Dia' : stripped;
}

String customImageEntryName(CustomOrderEntry entry) {
  final String path = (entry.customImagePath ?? '').trim();
  if (path.isNotEmpty) {
    return _basename(path);
  }
  return _stripCustomEntryPrefix(entry.label);
}

String formatCustomTextEntryLabel(AppLocalizations l10n, String title) {
  final String normalized = title.trim();
  return l10n.customTextEntryLabel(normalized.isEmpty ? 'Dia' : normalized);
}

String formatCustomImageEntryLabel(AppLocalizations l10n, String name) {
  return l10n.customImageEntryLabel(name.trim());
}

String localizedCustomEntryLabel(
  AppLocalizations l10n,
  CustomOrderEntry entry,
) {
  if (entry.isCustomImage) {
    return formatCustomImageEntryLabel(l10n, customImageEntryName(entry));
  }
  if (entry.isCustomText) {
    return formatCustomTextEntryLabel(l10n, customTextEntryTitle(entry));
  }
  return entry.label;
}

String _stripCustomEntryPrefix(String label) {
  final String trimmed = label.trim();
  final String folded = trimmed.toLowerCase();
  for (final String prefix in _customEntryPrefixes) {
    if (folded.startsWith(prefix.toLowerCase())) {
      return trimmed.substring(prefix.length).trim();
    }
  }
  return trimmed;
}

String _basename(String path) {
  final String normalized = path.replaceAll('\\', '/');
  final List<String> parts = normalized
      .split('/')
      .where((String part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? normalized : parts.last;
}
