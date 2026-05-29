import '../../l10n/generated/app_localizations.dart';

String formatFriendlyPathLabel(String rawPath, AppLocalizations l10n) {
  final String normalized = rawPath.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) {
    return '';
  }

  String remainder = normalized;
  String? rootLabel;

  if (normalized == '/storage/emulated/0') {
    return l10n.pathLabelInternalStorage;
  }

  if (normalized.startsWith('/storage/emulated/0/')) {
    rootLabel = l10n.pathLabelInternalStorage;
    remainder = normalized.substring('/storage/emulated/0/'.length);
  } else if (normalized.startsWith('/sdcard/')) {
    rootLabel = l10n.pathLabelInternalStorage;
    remainder = normalized.substring('/sdcard/'.length);
  }

  final List<String> mappedSegments = remainder
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .map((String segment) => _mapPathSegment(segment, l10n))
      .toList(growable: false);

  if (rootLabel != null) {
    if (mappedSegments.isEmpty) {
      return rootLabel;
    }
    return '$rootLabel/${mappedSegments.join('/')}';
  }

  if (normalized.startsWith('/')) {
    return '/${mappedSegments.join('/')}';
  }
  return mappedSegments.join('/');
}

String shortFriendlyPathLabel(
  String rawPath,
  AppLocalizations l10n, {
  int keepSegments = 2,
}) {
  final String friendly = formatFriendlyPathLabel(rawPath, l10n);
  if (friendly.isEmpty) {
    return '';
  }
  final List<String> segments = friendly
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.length <= keepSegments) {
    return friendly;
  }
  return '.../${segments.sublist(segments.length - keepSegments).join('/')}';
}

String _mapPathSegment(String segment, AppLocalizations l10n) {
  final String lower = segment.toLowerCase();
  switch (lower) {
    case 'documents':
    case 'document':
      return l10n.pathSegmentDocuments;
    case 'downloads':
    case 'download':
      return l10n.pathSegmentDownloads;
    case 'dcim':
      return l10n.pathSegmentCamera;
    case 'pictures':
    case 'picture':
      return l10n.pathSegmentPictures;
    case 'music':
      return l10n.pathSegmentMusic;
    case 'movies':
    case 'video':
    case 'videos':
      return l10n.pathSegmentMovies;
    default:
      return segment;
  }
}
