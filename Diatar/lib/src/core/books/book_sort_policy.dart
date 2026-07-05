import 'package:diatar_common/diatar_common.dart';

class BookSortPolicy {
  const BookSortPolicy();

  int compare(DtxBook left, DtxBook right) {
    final String lGroup = left.group.trim();
    final String rGroup = right.group.trim();
    final bool lEmpty = lGroup.isEmpty;
    final bool rEmpty = rGroup.isEmpty;
    if (lEmpty != rEmpty) {
      return lEmpty ? 1 : -1;
    }
    final int lGroupPriority = preferredGroupPriority(lGroup);
    final int rGroupPriority = preferredGroupPriority(rGroup);
    if (lGroupPriority != rGroupPriority) {
      return lGroupPriority.compareTo(rGroupPriority);
    }
    final int groupCmp = lGroup.toLowerCase().compareTo(rGroup.toLowerCase());
    if (groupCmp != 0) {
      return groupCmp;
    }

    final int lOrder = left.order;
    final int rOrder = right.order;
    if (lOrder != 0) {
      if (rOrder != 0) {
        return lOrder.compareTo(rOrder);
      }
      return -1;
    }
    if (rOrder != 0) {
      return 1;
    }

    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  int preferredGroupPriority(String group) {
    switch (group.trim().toLowerCase()) {
      case 'népénekes könyvek':
        return 0;
      case 'mise és liturgia':
        return 1;
      default:
        return 2;
    }
  }
}
