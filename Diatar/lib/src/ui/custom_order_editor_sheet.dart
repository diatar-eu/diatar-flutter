import 'dart:async';

import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/diatar_main_controller.dart';

class CustomOrderEditorPanel extends StatefulWidget {
  const CustomOrderEditorPanel({
    super.key,
    required this.controller,
    this.embedded = false,
    this.onClose,
  });

  final DiatarMainController controller;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<CustomOrderEditorPanel> createState() => _CustomOrderEditorPanelState();
}

class _CustomOrderEditorPanelState extends State<CustomOrderEditorPanel> {
  late List<CustomOrderEntry> _entries;
  late bool _active;
  String _searchQuery = '';
  bool _saving = false;

  int _safeEntryVerseIndex(CustomOrderEntry entry, {int fallback = 0}) {
    try {
      final dynamic value = (entry as dynamic).verseIndex;
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    } catch (_) {}
    return fallback;
  }

  DiatarMainController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _entries = List<CustomOrderEntry>.from(controller.customOrder);
    _active = controller.customOrderActive;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Material(
          color: widget.embedded ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Saját sorrend szerkesztése',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: _active,
                  onChanged: (bool v) => setState(() => _active = v),
                ),
                Text(_active ? 'Aktív' : 'Inaktív'),
                if (!widget.embedded) ...<Widget>[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Bezárás',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Ének hozzáadása',
                hintText: 'Kötet vagy énekcím',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          Expanded(
            child: _searchQuery.isNotEmpty ? _buildSearchResults() : _buildCurrentOrderList(),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _importDia,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Betöltés .DIA'),
                ),
                OutlinedButton.icon(
                  onPressed: _exportDia,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Mentés .DIA'),
                ),
                if (!widget.embedded)
                  OutlinedButton.icon(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Mégse'),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Mentés'),
                ),
              ],
            ),
          ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await controller.applyCustomOrder(_entries, activate: _active);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!widget.embedded) {
      widget.onClose?.call();
    }
  }

  Future<void> _exportDia() async {
    const XTypeGroup diaType = XTypeGroup(
      label: 'Diatar playlist',
      extensions: <String>['dia'],
    );
    final FileSaveLocation? target = await getSaveLocation(
      suggestedName: 'sorrend.dia',
      acceptedTypeGroups: <XTypeGroup>[diaType],
    );
    if (target == null) {
      return;
    }
    await controller.applyCustomOrder(_entries, activate: _active);
    final String outPath = await controller.exportCustomOrderToDia(target.path);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mentve: $outPath')),
    );
  }

  Future<void> _importDia() async {
    const XTypeGroup diaType = XTypeGroup(
      label: 'Diatar playlist',
      extensions: <String>['dia'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[diaType]);
    if (file == null) {
      return;
    }
    final int count = await controller.importCustomOrderFromDia(file.path, activate: _active);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
      _active = controller.customOrderActive;
      _searchQuery = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Betöltve: $count elem')),
    );
  }

  Widget _buildSearchResults() {
    final List<_SearchCandidate> candidates = <_SearchCandidate>[];
    for (final DtxBook book in controller.books) {
      for (int i = 0; i < book.songs.length; i++) {
        final DtxSong song = book.songs[i];
        if (song.separator) {
          continue;
        }
        candidates.add(
          _SearchCandidate(
            fileName: book.fileName,
            bookTitle: book.displayName,
            songIndex: i,
            songTitle: song.title,
          ),
        );
      }
    }

    final String filter = _searchQuery.toLowerCase();
    final List<_SearchCandidate> hits = candidates.where((_SearchCandidate c) {
      return c.bookTitle.toLowerCase().contains(filter) || c.songTitle.toLowerCase().contains(filter);
    }).toList()
      ..sort((_SearchCandidate a, _SearchCandidate b) {
        final int byBook = a.bookTitle.toLowerCase().compareTo(b.bookTitle.toLowerCase());
        return byBook != 0 ? byBook : a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase());
      });

    if (hits.isEmpty) {
      return const Center(child: Text('Nincs találat.'));
    }

    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (BuildContext context, int index) {
        final _SearchCandidate hit = hits[index];

        return ListTile(
          dense: true,
          title: Text(hit.songTitle),
          subtitle: Text(hit.bookTitle),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              setState(() {
                _entries.add(
                  CustomOrderEntry(
                    fileName: hit.fileName,
                    songIndex: hit.songIndex,
                    verseIndex: 0,
                    label: controller.buildEntryLabel(hit.fileName, hit.songIndex, 0),
                  ),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildCurrentOrderList() {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'A sorrend üres.\nKeresj énekeket a szerkesztéshez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: _entries.length,
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final CustomOrderEntry entry = _entries.removeAt(oldIndex);
          _entries.insert(newIndex, entry);
        });
      },
      itemBuilder: (BuildContext context, int index) {
        final CustomOrderEntry entry = _entries[index];
        return ListTile(
          key: ValueKey<String>('${entry.fileName}_${entry.songIndex}_$index'),
          selected: controller.isCustomOrderIndexCurrent(index),
          selectedTileColor: Colors.blue.withValues(alpha: 0.12),
          onTap: () => unawaited(controller.projectCustomOrderEntry(entry, preferredCursor: index)),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(entry.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Versszak',
                icon: const Icon(Icons.format_list_numbered),
                onPressed: () => _pickVerse(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() => _entries.removeAt(index));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickVerse(int index) async {
    final ({int start, int end}) group = _contiguousSongGroup(index);
    final List<CustomOrderEntry> groupEntries = _entries.sublist(group.start, group.end + 1);
    final CustomOrderEntry base = groupEntries.first;
    final List<DtxVerse> verses = controller.versesForEntry(base);
    if (verses.isEmpty) {
      return;
    }

    final Set<int> selectedSet = groupEntries.map(_safeEntryVerseIndex).toSet();
    if (selectedSet.isEmpty) {
      selectedSet.add(0);
    }
    final List<int> originalSelection = selectedSet.toList()..sort();
    final List<int>? selectedMany = await showModalBottomSheet<List<int>>(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, void Function(void Function()) setModalState) {
                return SafeArea(
                  child: Column(
                    children: <Widget>[
                      const ListTile(
                        title: Text('Kiválasztott versszakok', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Többet is kijelölhetsz.'),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: verses.length,
                          itemBuilder: (BuildContext context, int i) {
                            final bool selected = selectedSet.contains(i);
                            return CheckboxListTile(
                              value: selected,
                              title: Text(verses[i].name),
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedSet.add(i);
                                  } else {
                                    selectedSet.remove(i);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(null),
                                child: const Text('Mégse'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: selectedSet.isEmpty
                                    ? null
                                    : () {
                                        final List<int> out = selectedSet.toList()..sort();
                                        Navigator.of(context).pop(out);
                                      },
                                child: const Text('Alkalmaz'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

    if (selectedMany == null || selectedMany.isEmpty) {
      return;
    }

    final List<int> normalized = selectedMany.toList()..sort();
    if (listEquals(normalized, originalSelection)) {
      return;
    }

    setState(() {
      final List<CustomOrderEntry> replacements = normalized
          .map(
            (int v) => controller.normalizeEntry(
              base.copyWith(
                verseIndex: v,
                label: controller.buildEntryLabel(base.fileName, base.songIndex, v),
              ),
            ),
          )
          .toList();
      _entries.removeRange(group.start, group.end + 1);
      _entries.insertAll(group.start, replacements);
    });

    // Commit immediately so multi-verse selections are not lost if user
    // continues navigating without pressing the bottom save button yet.
    await controller.applyCustomOrder(_entries, activate: _active);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = List<CustomOrderEntry>.from(controller.customOrder);
    });
  }

  ({int start, int end}) _contiguousSongGroup(int index) {
    final CustomOrderEntry center = _entries[index];
    bool sameSong(CustomOrderEntry e) =>
        e.fileName == center.fileName && e.songIndex == center.songIndex;

    int start = index;
    while (start > 0 && sameSong(_entries[start - 1])) {
      start--;
    }
    int end = index;
    while (end + 1 < _entries.length && sameSong(_entries[end + 1])) {
      end++;
    }
    return (start: start, end: end);
  }
}

class CustomOrderEditorSheet extends StatelessWidget {
  const CustomOrderEditorSheet({
    super.key,
    required this.controller,
  });

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController _) {
        return CustomOrderEditorPanel(
          controller: controller,
          embedded: false,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

class _SearchCandidate {
  const _SearchCandidate({
    required this.fileName,
    required this.bookTitle,
    required this.songIndex,
    required this.songTitle,
  });

  final String fileName;
  final String bookTitle;
  final int songIndex;
  final String songTitle;
}
