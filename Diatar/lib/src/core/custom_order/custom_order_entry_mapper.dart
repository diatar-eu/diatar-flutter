import '../../models/custom_order_entry.dart';
import '../../services/dtx_order_store.dart';

class CustomOrderEntryMapper {
  const CustomOrderEntryMapper();

  CustomOrderEntry fromStored(StoredCustomOrderEntry entry) {
    return CustomOrderEntry(
      fileName: entry.fileName,
      songIndex: entry.songIndex,
      verseIndex: entry.verseIndex,
      label: entry.label,
      mergeWithNext: entry.mergeWithNext,
      skipped: entry.skipped,
      playSound: entry.playSound,
      advanceAfterSound: entry.advanceAfterSound,
      customTextTitle: entry.customTextTitle,
      customTextBody: entry.customTextBody,
      customImagePath: entry.customImagePath,
      customType: entry.customType,
      customData: entry.customData,
      storageExtras: entry.additionalFields,
    );
  }

  StoredCustomOrderEntry toStored(
    CustomOrderEntry entry, {
    required int verseIndex,
  }) {
    return StoredCustomOrderEntry(
      fileName: entry.fileName,
      songIndex: entry.songIndex,
      verseIndex: verseIndex,
      label: entry.label,
      mergeWithNext: entry.mergeWithNext,
      skipped: entry.skipped,
      playSound: entry.playSound,
      advanceAfterSound: entry.advanceAfterSound,
      customTextTitle: entry.customTextTitle,
      customTextBody: entry.customTextBody,
      customImagePath: entry.customImagePath,
      customType: entry.customType,
      customData: entry.customData,
      additionalFields: entry.storageExtras,
    );
  }
}
