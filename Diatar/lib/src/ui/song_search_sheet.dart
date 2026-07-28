import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../controllers/diatar_main_controller.dart';
import '../services/song_search_service.dart';

class SongSearchSheet extends StatefulWidget {
  const SongSearchSheet({
    super.key,
    required this.controller,
    required this.onSelected,
  });

  final DiatarMainController controller;
  final ValueChanged<SongSearchResult> onSelected;

  @override
  State<SongSearchSheet> createState() => _SongSearchSheetState();
}

class _SongSearchSheetState extends State<SongSearchSheet> {
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;
  List<SongSearchResult> _results = const <SongSearchResult>[];
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
      final results = await widget.controller.searchSongs(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.searchLabel,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? ( _textController.text.isEmpty
                        ? const Center(child: Text('Kereséshez írjon valamit...'))
                        : Center(child: Text(l10n.noResults))
                    )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return ListTile(
                            title: Text(
                              result.songTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              result.isLyricsMatch
                                  ? '${result.bookTitle} \u2014 ${result.verseName} ${result.snippet}'
                                  : result.bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              widget.onSelected(result);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}