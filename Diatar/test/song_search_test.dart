import 'package:diatar_app/src/services/song_search_service.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeSearchText', () {
    test('lowercases and strips accents and punctuation', () {
      const Map<String, String> cases = <String, String>{
        'Betlehem': 'betlehem',
        'Belém': 'belem',
        'Belém, ó': 'belemo',
        'ÁRvíztűrő TÜKÖRFÚRÓgép': 'arvizturotukorfurogep',
        'Mélységben': 'melysegben',
        'Jézus': 'jezus',
        'Öröm, öröm': 'oromorom',
        'çüñé': 'cune',
        'ÆØÅ': 'aeoa',
        'Mi Atyánk!?': 'miatyank',
        'Károli 12.': 'karoli12',
      };
      cases.forEach((String input, String expected) {
        expect(normalizeSearchText(input), expected, reason: 'for "$input"');
      });
    });
  });

  group('SongSearchService', () {
    SongSearchService service() => SongSearchService();

    test('accent-insensitive title search', () async {
      final List<SongSearchSong> index = buildSearchIndex(<DtxBook>[
        DtxBook(
          fileName: 'a.dtx',
          title: 'Énekek',
          songs: <DtxSong>[
            DtxSong(
              title: 'Betlehem, tégy magasra',
              verses: <DtxVerse>[DtxVerse(name: 'V1', lines: <String>['Sor'])],
            ),
          ],
        ),
      ]);

      final List<SongSearchResult> results =
          await service().search(index: index, query: 'bétlèhèm');
      expect(results, hasLength(1));
      expect(results.first.songTitle, 'Betlehem, tégy magasra');
    });

    test('diacritic-insensitive lyrics search', () async {
      final List<SongSearchSong> index = buildSearchIndex(<DtxBook>[
        DtxBook(
          fileName: 'a.dtx',
          title: 'Énekek',
          songs: <DtxSong>[
            DtxSong(
              title: 'Második ember',
              verses: <DtxVerse>[
                DtxVerse(
                  name: '1',
                  lines: <String>['Mérték a szeretet mélységét'],
                ),
              ],
            ),
          ],
        ),
      ]);

      final List<SongSearchResult> results =
          await service().search(index: index, query: 'melyseget');
      expect(results, hasLength(1));
      expect(results.first.isLyricsMatch, isTrue);
    });

    test('punctuation-insensitive title search', () async {
      final List<SongSearchSong> index = buildSearchIndex(<DtxBook>[
        DtxBook(
          fileName: 'a.dtx',
          title: 'Énekek',
          songs: <DtxSong>[
            DtxSong(
              title: 'Uram, segíts!',
              verses: <DtxVerse>[DtxVerse(name: 'V1', lines: <String>['Sor'])],
            ),
          ],
        ),
      ]);

      final List<SongSearchResult> results =
          await service().search(index: index, query: 'uram segíts');
      expect(results, hasLength(1));
      expect(results.first.songTitle, 'Uram, segíts!');
    });
  });
}
