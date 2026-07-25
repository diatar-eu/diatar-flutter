class CustomOrderEntry {
  static const String separatorFileName = '__separator__';
  static const int separatorSongIndex = -3;

  const CustomOrderEntry({
    required this.fileName,
    required this.songIndex,
    required this.verseIndex,
    required this.label,
    this.mergeWithNext = false,
    this.customTextTitle,
    this.customTextBody,
    this.customImagePath,
    this.customType,
    this.customData = const <String, dynamic>{},
    this.storageExtras = const <String, dynamic>{},
  });

  final String fileName;
  final int songIndex;
  final int verseIndex;
  final String label;
  final bool mergeWithNext;
  final String? customTextTitle;
  final String? customTextBody;
  final String? customImagePath;
  final String? customType;
  final Map<String, dynamic> customData;
  final Map<String, dynamic> storageExtras;

  bool get isSeparator =>
      fileName == separatorFileName && songIndex == separatorSongIndex;
  bool get isCustomText =>
      customType == 'text' || customTextBody != null || customTextTitle != null;
  bool get isCustomImage => customType == 'image' || customImagePath != null;
  bool get isSongEntry => !isSeparator && songIndex >= 0;

  CustomOrderEntry copyWith({
    String? fileName,
    int? songIndex,
    int? verseIndex,
    String? label,
    bool? mergeWithNext,
    String? customTextTitle,
    String? customTextBody,
    String? customImagePath,
    String? customType,
    Map<String, dynamic>? customData,
    Map<String, dynamic>? storageExtras,
  }) {
    return CustomOrderEntry(
      fileName: fileName ?? this.fileName,
      songIndex: songIndex ?? this.songIndex,
      verseIndex: verseIndex ?? this.verseIndex,
      label: label ?? this.label,
      mergeWithNext: mergeWithNext ?? this.mergeWithNext,
      customTextTitle: customTextTitle ?? this.customTextTitle,
      customTextBody: customTextBody ?? this.customTextBody,
      customImagePath: customImagePath ?? this.customImagePath,
      customType: customType ?? this.customType,
      customData: customData ?? this.customData,
      storageExtras: storageExtras ?? this.storageExtras,
    );
  }
}
