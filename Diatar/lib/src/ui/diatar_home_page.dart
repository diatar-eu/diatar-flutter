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
                  color: Colors.black,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: book == null || song == null || verse == null
                        ? const Text('Nincs betoltott dia.', style: TextStyle(color: Colors.white))
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
    final List<InlineSpan> spans = <InlineSpan>[];
    int idx = 0;
    for (final String line in verse.lines) {
      final List<String> words = line.split(RegExp(r'\s+')).where((String w) => w.trim().isNotEmpty).toList();
      if (words.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      for (final String word in words) {
        idx++;
        final bool hi = idx <= controller.highPos;
        spans.add(
          TextSpan(
            text: '$word ',
            style: TextStyle(
              color: hi ? const Color(0xFF00FFFF) : Colors.white,
              fontSize: 28,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
      spans.add(const TextSpan(text: '\n'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          song.title,
          style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Versszak: ${verse.name}',
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 14),
        RichText(text: TextSpan(children: spans)),
      ],
    );
  }
}
