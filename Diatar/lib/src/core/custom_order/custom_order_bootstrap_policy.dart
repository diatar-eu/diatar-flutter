import '../../services/dtx_order_store.dart';
import '../../models/custom_order_entry.dart';
import 'custom_order_entry_mapper.dart';

class CustomOrderBootstrapState {
  const CustomOrderBootstrapState({
    required this.entries,
    required this.active,
    required this.baseName,
    required this.sourceType,
    required this.zsolozsmaLabel,
    required this.cursor,
    required this.diaVirtualBookSelected,
  });

  final List<CustomOrderEntry> entries;
  final bool active;
  final String? baseName;
  final String? sourceType;
  final String? zsolozsmaLabel;
  final int cursor;
  final bool diaVirtualBookSelected;
}

class CustomOrderBootstrapPolicy {
  const CustomOrderBootstrapPolicy({CustomOrderEntryMapper? mapper})
    : _mapper = mapper ?? const CustomOrderEntryMapper();

  final CustomOrderEntryMapper _mapper;

  CustomOrderBootstrapState fromStored(
    ({
      List<StoredCustomOrderEntry> entries,
      bool active,
      String? baseName,
      String? sourceType,
      String? zsolozsmaLabel,
    })
    stored,
  ) {
    final List<CustomOrderEntry> entries = stored.entries
        .map(_mapper.fromStored)
        .toList();
    final bool hasEntries = entries.isNotEmpty;
    final bool active = stored.active && hasEntries;
    return CustomOrderBootstrapState(
      entries: entries,
      active: active,
      baseName: hasEntries ? stored.baseName : null,
      sourceType: hasEntries ? stored.sourceType : null,
      zsolozsmaLabel: hasEntries ? stored.zsolozsmaLabel : null,
      cursor: active ? 0 : -1,
      diaVirtualBookSelected: hasEntries,
    );
  }
}
