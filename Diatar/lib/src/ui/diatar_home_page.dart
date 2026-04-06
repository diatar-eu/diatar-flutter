import 'dart:async';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';

import '../controllers/diatar_main_controller.dart';
import '../services/dtx_download_service.dart';
import 'diatar_settings_sheet.dart';

class DiatarHomePage extends StatelessWidget {
  const DiatarHomePage({super.key, required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diatar'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Beallitasok',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'Enekrendek',
            onPressed: () => _openSongbookOrder(context),
            icon: const Icon(Icons.playlist_play),
          ),
          IconButton(
            tooltip: 'Sajat sorrend',
            onPressed: () => _openCustomOrder(context),
            icon: const Icon(Icons.queue_music),
          ),
          IconButton(
            tooltip: 'Enektarak letoltese',
            onPressed: () => _downloadSongBooks(context),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            tooltip: 'Frissites',
            onPressed: controller.reloadBooks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData mq = MediaQuery.of(context);
          final int screenW = (mq.size.width * mq.devicePixelRatio).round();
          final int screenH = (mq.size.height * mq.devicePixelRatio).round();
          unawaited(controller.updateScreenSize(width: screenW, height: screenH));

          final DtxBook? book = controller.currentBook;
          final DtxSong? song = controller.currentSong;
          final DtxVerse? verse = controller.currentVerse;

          return Column(
            children: <Widget>[
              if (controller.loading) const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    _BookDropdown(controller: controller),
                    const SizedBox(height: 8),
                    _SongDropdown(controller: controller),
                    const SizedBox(height: 8),
                    _VerseDropdown(controller: controller),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: controller.prevSong,
                          icon: const Icon(Icons.keyboard_double_arrow_left),
                          label: const Text('Enek -'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.nextSong,
                          icon: const Icon(Icons.keyboard_double_arrow_right),
                          label: const Text('Enek +'),
                        ),
                        FilledButton.icon(
                          onPressed: controller.toggleShowing,
                          icon: Icon(controller.showing ? Icons.visibility : Icons.visibility_off),
                          label: Text(controller.showing ? 'Vetites BE' : 'Vetites KI'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.prevVerse,
                          icon: const Icon(Icons.skip_previous),
                          label: const Text('Elozo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.nextVerse,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Kovetkezo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: controller.highlightPrev,
                          child: const Text('Highlight -'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: controller.highlightNext,
                          child: const Text('Highlight +'),
                        ),
                        const SizedBox(width: 12),
                        Text('Pozicio: ${controller.highPos}/${controller.wordCount}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final String? path = await _askFilePath(
                              context,
                              title: 'Kep kuldese',
                              hint: '/teljes/utvonal/kep.jpg',
                              initialValue: controller.lastPicPath,
                            );
                            if (path != null) {
                              await controller.sendPicFromPath(path);
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Kep kuldes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final String? path = await _askFilePath(
                              context,
                              title: 'Blank kep beallitasa',
                              hint: '/teljes/utvonal/blank.png',
                              initialValue: controller.lastBlankPath,
                            );
                            if (path != null) {
                              await controller.sendBlankFromPath(path);
                            }
                          },
                          icon: const Icon(Icons.photo_size_select_actual_outlined),
                          label: const Text('Blank kep'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.clearBlankImage,
                          icon: const Icon(Icons.image_not_supported_outlined),
                          label: const Text('Blank torles'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => controller.sendStop(wantShutdown: false),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => controller.sendStop(wantShutdown: true),
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('Lezaras'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Statusz: ${controller.status}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kuldes (${controller.mqttActive ? 'MQTT' : 'TCP'}): ${controller.senderRunning ? 'aktív' : 'kikapcsolva'}, kliens: ${controller.senderConnected ? 'csatlakozva' : 'varakozik'}',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('TCP port: ${controller.settings.port}'),
                    ),
                    if (controller.downloadInProgress) ...<Widget>[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: controller.downloadCurrentFraction),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Letoltes: ${controller.downloadCurrentFile}/${controller.downloadTotalFiles} ${controller.downloadCurrentName}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  color: controller.globals.bkColor,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: book == null || song == null || verse == null
                        ? Text('Nincs betoltott dia.', style: TextStyle(color: controller.globals.txtColor))
                        : _VersePreview(controller: controller, song: song, verse: verse),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DiatarSettingsSheet(
          initialSettings: controller.settings,
          onApply: (AppSettings settings) {
            controller.applySettings(settings);
          },
        );
      },
    );
  }

  Future<void> _downloadSongBooks(BuildContext context) async {
    final List<DtxDownloadItem> updates = await controller.loadDownloadCandidates();
    if (!context.mounted) {
      return;
    }
    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nincs uj enektar frissites.')),
      );
      return;
    }

    final Set<int> selected = updates.asMap().keys.toSet();
    final List<DtxDownloadItem>? chosen = await showDialog<List<DtxDownloadItem>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: const Text('Enektar frissitesek'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: updates.asMap().entries.map((MapEntry<int, DtxDownloadItem> e) {
                      final int idx = e.key;
                      final DtxDownloadItem item = e.value;
                      return CheckboxListTile(
                        dense: true,
                        value: selected.contains(idx),
                        onChanged: (bool? v) {
                          setState(() {
                            if (v ?? false) {
                              selected.add(idx);
                            } else {
                              selected.remove(idx);
                            }
                          });
                        },
                        title: Text(item.fileName),
                        subtitle: Text('meret: ${_formatBytes(item.size)}'),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Megse'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          final List<int> picked = selected
                              .toList()
                            ..sort();
                          Navigator.of(context).pop(
                            picked.map((int i) => updates[i]).toList(),
                          );
                        },
                  child: const Text('Letoltes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosen == null || chosen.isEmpty) {
      return;
    }
    await controller.downloadSongBooks(selected: chosen);
  }

  Future<void> _openSongbookOrder(BuildContext context) async {
    final List<SongbookOrderItem> items = await controller.loadSongbookOrderItems();
    if (!context.mounted) {
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nincs elerheto enektar.')),
      );
      return;
    }

    final Map<String, bool> enabled = <String, bool>{
      for (final SongbookOrderItem item in items) item.fileName: item.enabled,
    };

    final Map<String, bool>? updated = await showDialog<Map<String, bool>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            final List<String> groups = items
                .map((SongbookOrderItem i) => i.group.trim().isEmpty ? '(nem csoportositott)' : i.group.trim())
                .toSet()
                .toList()
              ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));

            return AlertDialog(
              title: const Text('Enekrendek beallitasa'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (final SongbookOrderItem item in items) {
                                enabled[item.fileName] = true;
                              }
                            });
                          },
                          child: const Text('Mind'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (final SongbookOrderItem item in items) {
                                enabled[item.fileName] = false;
                              }
                            });
                          },
                          child: const Text('Egyik sem'),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: groups.map((String group) {
                            final List<SongbookOrderItem> inGroup = items.where((SongbookOrderItem item) {
                              final String g = item.group.trim().isEmpty ? '(nem csoportositott)' : item.group.trim();
                              return g == group;
                            }).toList();
                            final int checkedCount = inGroup
                                .where((SongbookOrderItem item) => enabled[item.fileName] ?? false)
                                .length;
                            final bool groupChecked = checkedCount == inGroup.length;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                CheckboxListTile(
                                  dense: true,
                                  value: groupChecked,
                                  tristate: checkedCount > 0 && !groupChecked,
                                  title: Text(group, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  onChanged: (bool? v) {
                                    final bool on = v ?? false;
                                    setState(() {
                                      for (final SongbookOrderItem item in inGroup) {
                                        enabled[item.fileName] = on;
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                                ...inGroup.map(
                                  (SongbookOrderItem item) => Padding(
                                    padding: const EdgeInsets.only(left: 26),
                                    child: CheckboxListTile(
                                      dense: true,
                                      value: enabled[item.fileName] ?? false,
                                      onChanged: (bool? v) {
                                        setState(() {
                                          enabled[item.fileName] = v ?? false;
                                        });
                                      },
                                      title: Text(item.title),
                                      subtitle: Text(item.fileName),
                                      controlAffinity: ListTileControlAffinity.leading,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Megse'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(Map<String, bool>.from(enabled)),
                  child: const Text('Ment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == null) {
      return;
    }
    await controller.applySongbookOrder(updated);
  }

  Future<void> _openCustomOrder(BuildContext context) async {
    final List<CustomOrderCandidate> candidates = controller.loadCustomOrderCandidates();
    final List<String> presetNames = await controller.listCustomOrderPresetNames();
    String? selectedPreset = presetNames.isNotEmpty ? presetNames.first : null;
    String searchText = '';
    String? selectedBookFileName;
    String? selectedCandidateKey;
    if (!context.mounted) {
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nincs elerheto enek a sajat sorrendhez.')),
      );
      return;
    }

    final List<CustomOrderEntry> plan = List<CustomOrderEntry>.from(controller.customOrder);
    bool activate = controller.customOrderActive;

    final ({List<CustomOrderEntry> entries, bool active})? result =
        await showDialog<({List<CustomOrderEntry> entries, bool active})>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: const Text('Sajat enek sorrend'),
              content: SizedBox(
                width: 860,
                height: 520,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Elerheto enekek', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Kereses szovegre',
                              hintText: 'pl. Alleluja vagy kotetcim',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (String value) {
                              setState(() {
                                searchText = value.trim();
                                selectedBookFileName = null;
                                selectedCandidateKey = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (BuildContext context) {
                              final String filter = searchText.toLowerCase();
                              final List<CustomOrderCandidate> filtered = candidates.where((CustomOrderCandidate c) {
                                if (filter.isEmpty) {
                                  return true;
                                }
                                return c.songTitle.toLowerCase().contains(filter) ||
                                    c.bookTitle.toLowerCase().contains(filter);
                              }).toList();
                              filtered.sort((CustomOrderCandidate a, CustomOrderCandidate b) {
                                final int byBook = a.bookTitle.toLowerCase().compareTo(b.bookTitle.toLowerCase());
                                if (byBook != 0) {
                                  return byBook;
                                }
                                return a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase());
                              });

                              String keyOf(CustomOrderCandidate c) => '${c.fileName}#${c.songIndex}';

                              if (filtered.isEmpty) {
                                return const Expanded(
                                  child: Center(
                                    child: Text('Nincs talalat a keresett szovegre.'),
                                  ),
                                );
                              }

                              final Map<String, String> bookByFile = <String, String>{};
                              for (final CustomOrderCandidate c in filtered) {
                                bookByFile[c.fileName] = c.bookTitle;
                              }
                              final List<MapEntry<String, String>> books = bookByFile.entries.toList()
                                ..sort((MapEntry<String, String> a, MapEntry<String, String> b) {
                                  return a.value.toLowerCase().compareTo(b.value.toLowerCase());
                                });

                              final Set<String> validBookFiles = books.map((MapEntry<String, String> e) => e.key).toSet();
                              if (selectedBookFileName == null || !validBookFiles.contains(selectedBookFileName)) {
                                selectedBookFileName = books.first.key;
                              }

                              final List<CustomOrderCandidate> songsInBook = filtered
                                  .where((CustomOrderCandidate c) => c.fileName == selectedBookFileName)
                                  .toList()
                                ..sort((CustomOrderCandidate a, CustomOrderCandidate b) {
                                  return a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase());
                                });

                              final Set<String> validSongKeys = songsInBook.map(keyOf).toSet();
                              if (selectedCandidateKey == null || !validSongKeys.contains(selectedCandidateKey)) {
                                selectedCandidateKey = keyOf(songsInBook.first);
                              }

                              final CustomOrderCandidate selected = songsInBook.firstWhere(
                                (CustomOrderCandidate c) => keyOf(c) == selectedCandidateKey,
                              );

                              return Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    DropdownButtonFormField<String>(
                                      value: selectedBookFileName,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Kotet kivalasztasa',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: books
                                          .map(
                                            (MapEntry<String, String> b) => DropdownMenuItem<String>(
                                              value: b.key,
                                              child: Text(b.value, overflow: TextOverflow.ellipsis),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (String? value) {
                                        setState(() {
                                          selectedBookFileName = value;
                                          selectedCandidateKey = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: selectedCandidateKey,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Enek kivalasztasa',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: songsInBook
                                          .map(
                                            (CustomOrderCandidate c) => DropdownMenuItem<String>(
                                              value: keyOf(c),
                                              child: Text(c.songTitle, overflow: TextOverflow.ellipsis),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (String? value) {
                                        setState(() {
                                          selectedCandidateKey = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Talalatok: ${filtered.length}'),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            plan.add(
                                              CustomOrderEntry(
                                                fileName: selected.fileName,
                                                songIndex: selected.songIndex,
                                                label: selected.label,
                                              ),
                                            );
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Hozzaadas a sorrendhez'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedPreset,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Mentett sorrend',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: presetNames
                                      .map(
                                        (String n) => DropdownMenuItem<String>(
                                          value: n,
                                          child: Text(n, overflow: TextOverflow.ellipsis),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: presetNames.isEmpty
                                      ? null
                                      : (String? value) {
                                          setState(() {
                                            selectedPreset = value;
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: selectedPreset == null
                                    ? null
                                    : () async {
                                        final List<CustomOrderEntry> loaded =
                                            await controller.readCustomOrderPreset(selectedPreset!);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        setState(() {
                                          plan
                                            ..clear()
                                            ..addAll(loaded);
                                          activate = loaded.isNotEmpty;
                                        });
                                      },
                                child: const Text('Betolt'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: selectedPreset == null
                                    ? null
                                    : () async {
                                        final String toDelete = selectedPreset!;
                                        await controller.deleteCustomOrderPreset(toDelete);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        setState(() {
                                          presetNames.remove(toDelete);
                                          selectedPreset = presetNames.isEmpty ? null : presetNames.first;
                                        });
                                      },
                                child: const Text('Torol'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final String? rawName = await _askPresetName(context);
                                final String name = (rawName ?? '').trim();
                                if (name.isEmpty) {
                                  return;
                                }
                                await controller.saveCustomOrderPreset(name, List<CustomOrderEntry>.from(plan));
                                if (!context.mounted) {
                                  return;
                                }
                                setState(() {
                                  if (!presetNames.contains(name)) {
                                    presetNames.add(name);
                                    presetNames.sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  }
                                  selectedPreset = name;
                                });
                              },
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Sorrend mentese'),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Aktivalt sajat sorrend'),
                            value: activate,
                            onChanged: (bool v) {
                              setState(() {
                                activate = v;
                              });
                            },
                          ),
                          const SizedBox(height: 4),
                          const Text('Osszeallitott sorrend', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: plan.isEmpty
                                ? const Center(child: Text('Meg nincs elem a sorrendben.'))
                                : ListView.builder(
                                    itemCount: plan.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final CustomOrderEntry e = plan[index];
                                      return ListTile(
                                        dense: true,
                                        leading: Text('${index + 1}.'),
                                        title: Text(e.label),
                                        trailing: Wrap(
                                          spacing: 2,
                                          children: <Widget>[
                                            IconButton(
                                              tooltip: 'Fel',
                                              onPressed: index == 0
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        final CustomOrderEntry tmp = plan[index - 1];
                                                        plan[index - 1] = plan[index];
                                                        plan[index] = tmp;
                                                      });
                                                    },
                                              icon: const Icon(Icons.arrow_upward),
                                            ),
                                            IconButton(
                                              tooltip: 'Le',
                                              onPressed: index == plan.length - 1
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        final CustomOrderEntry tmp = plan[index + 1];
                                                        plan[index + 1] = plan[index];
                                                        plan[index] = tmp;
                                                      });
                                                    },
                                              icon: const Icon(Icons.arrow_downward),
                                            ),
                                            IconButton(
                                              tooltip: 'Torles',
                                              onPressed: () {
                                                setState(() {
                                                  plan.removeAt(index);
                                                });
                                              },
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Megse'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop((entries: List<CustomOrderEntry>.from(plan), active: activate)),
                  child: const Text('Ment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await controller.applyCustomOrder(result.entries, activate: result.active);
  }

  Future<String?> _askPresetName(BuildContext context) {
    final TextEditingController input = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sorrend neve'),
          content: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Pl. Vasarnap reggel',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Megse'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(input.text),
              child: const Text('Ment'),
            ),
          ],
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return 'ismeretlen';
    }
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int idx = 0;
    while (value >= 1024 && idx < units.length - 1) {
      value /= 1024;
      idx++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[idx]}';
  }

  Future<String?> _askFilePath(
    BuildContext context, {
    required String title,
    required String hint,
    required String initialValue,
  }) {
    final TextEditingController input = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: input,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Megse'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(input.text),
              child: const Text('Kuldes'),
            ),
          ],
        );
      },
    );
  }
}

class _BookDropdown extends StatelessWidget {
  const _BookDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.books.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      value: controller.bookIndex,
      decoration: const InputDecoration(labelText: 'Kotet', border: OutlineInputBorder()),
      items: controller.books.asMap().entries.map((MapEntry<int, DtxBook> e) {
        final DtxBook book = e.value;
        final String groupPrefix = book.group.trim().isEmpty ? '' : '[${book.group}] ';
        return DropdownMenuItem<int>(value: e.key, child: Text('$groupPrefix${book.displayName}'));
      }).toList(),
      onChanged: (int? value) {
        if (value != null) {
          controller.setBookIndex(value);
        }
      },
    );
  }
}

class _SongDropdown extends StatelessWidget {
  const _SongDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    final DtxBook? b = controller.currentBook;
    final List<DtxSong> songs = b?.songs ?? const <DtxSong>[];
    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      value: controller.songIndex.clamp(0, songs.length - 1),
      decoration: const InputDecoration(labelText: 'Enek', border: OutlineInputBorder()),
      items: songs.asMap().entries.map((MapEntry<int, DtxSong> e) {
        final String title = e.value.separator ? '-- ${e.value.title} --' : e.value.title;
        return DropdownMenuItem<int>(value: e.key, child: Text(title));
      }).toList(),
      onChanged: (int? value) {
        if (value != null) {
          controller.setSongIndex(value);
        }
      },
    );
  }
}

class _VerseDropdown extends StatelessWidget {
  const _VerseDropdown({required this.controller});

  final DiatarMainController controller;

  @override
  Widget build(BuildContext context) {
    final DtxSong? s = controller.currentSong;
    final List<DtxVerse> verses = s?.verses ?? const <DtxVerse>[];
    if (verses.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int>(
      value: controller.verseIndex.clamp(0, verses.length - 1),
      decoration: const InputDecoration(labelText: 'Versszak', border: OutlineInputBorder()),
      items: verses.asMap().entries.map((MapEntry<int, DtxVerse> e) {
        return DropdownMenuItem<int>(value: e.key, child: Text(e.value.name));
      }).toList(),
      onChanged: (int? value) {
        if (value != null) {
          controller.setVerseIndex(value);
        }
      },
    );
  }
}

class _VersePreview extends StatelessWidget {
  const _VersePreview({required this.controller, required this.song, required this.verse});

  final DiatarMainController controller;
  final DtxSong song;
  final DtxVerse verse;

  @override
  Widget build(BuildContext context) {
    final RecTextRecord previewRecord = RecTextRecord(
      scholaLine: '',
      title: song.title,
      lines: verse.lines,
    );
    final ProjectionFrame frame = TextFrame(record: previewRecord);
    final ProjectionGlobals globals = controller.globals.copyWith(
      projecting: true,
      useKotta: true,
      wordToHighlight: controller.highPos,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite ? constraints.maxWidth : 800;
        final double minHeight = 280;
        final double estimated = _estimateCanvasHeight(globals: globals, frame: previewRecord, viewportWidth: width);
        final double canvasHeight = estimated < minHeight ? minHeight : estimated;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Versszak: ${verse.name}',
              style: TextStyle(color: controller.globals.txtColor.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: width,
              height: canvasHeight,
              child: CustomPaint(
                size: Size(width, canvasHeight),
                painter: ProjectorPainter(
                  frame: frame,
                  globals: globals,
                  settings: controller.settings,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _estimateCanvasHeight({
    required ProjectionGlobals globals,
    required RecTextRecord frame,
    required double viewportWidth,
  }) {
    final bool hasTitle = !globals.hideTitle && frame.title.isNotEmpty;
    final int logicalLines = frame.lines.length + (hasTitle ? 1 : 0);
    if (logicalLines <= 0) {
      return 280;
    }

    final double fontSize = globals.fontSize.toDouble();
    final double titleSize = (globals.titleSize.toDouble() * 2.5).clamp(8.0, 72.0);
    final double lineSpacing = globals.spacing100 / 100.0;

    final TextPainter normalProbe = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: globals.boldText ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: viewportWidth);

    final TextPainter titleProbe = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: viewportWidth);

    double estimated = 8;
    if (hasTitle) {
      estimated += titleProbe.height * lineSpacing;
    }
    estimated += normalProbe.height * lineSpacing * frame.lines.length;

    if (globals.useKotta) {
      estimated += frame.lines.length * (fontSize * (globals.kottaArany / 100.0) * 1.35);
    }

    return estimated * 1.25;
  }
}
