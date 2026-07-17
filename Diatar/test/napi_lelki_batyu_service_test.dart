import 'package:flutter_test/flutter_test.dart';

import 'package:diatar_app/src/models/custom_order_entry.dart';
import 'package:diatar_app/src/services/napi_lelki_batyu_service.dart';

void main() {
  group('NapiLelkiBatyuService text chunking', () {
    final NapiLelkiBatyuService service = NapiLelkiBatyuService();

    int wordCount(String body) => body
        .split(RegExp(r'\s+'))
        .where((String w) => w.trim().isNotEmpty)
        .length;

    test('breaks at the last boundary before the limit', () {
      // limit = 10. The only boundary inside the first part of the text is a
      // period at word 4, so the first slide must close there (not at the
      // limit, and certainly not mid-sentence).
      const String text = 'Egy kutya futott el. A macska pedig aludt egész '
          'nap a meleg ágyban és nem kelt fel soha.';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 1,
        name: 'Teszt',
        title: 'Teszt',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': text},
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 10);

      // The celebration title is no longer projected as its own slide, so the
      // entries are the text chunks directly.
      final List<CustomOrderEntry> textEntries = entries;
      expect(textEntries, isNotEmpty);

      final String first = textEntries.first.customTextBody ?? '';
      expect(wordCount(first), equals(4));
      expect(first.trim(), endsWith('.'));
      // The first slide must not contain words past the boundary.
      expect(first, isNot(contains('macska')));
    });

    test('hard-cuts at exactly the limit when no boundary exists', () {
      // limit = 10. There is no sentence/clause/quote boundary among the
      // first ten words, so the slide must close at exactly word 10 and must
      // never exceed the limit.
      const String text = 'Ez egy hosszú mondat amelyben nincs semmilyen '
          'írásjel egészen a végéig csak itt ér véget.';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 2,
        name: 'Teszt2',
        title: 'Teszt2',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': text},
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 10);

      final List<CustomOrderEntry> textEntries = entries;
      expect(textEntries.length, greaterThanOrEqualTo(2));

      final String first = textEntries.first.customTextBody ?? '';
      expect(wordCount(first), equals(10));
      // No chunk may exceed the limit.
      for (final CustomOrderEntry e in textEntries) {
        expect(wordCount(e.customTextBody ?? ''), lessThanOrEqualTo(10));
      }
    });

    test('no chunk exceeds the limit and non-final chunks end on a boundary',
        () {
      const String text = 'Az első mondat rövid. A második mondat hosszabb, '
          'tele van vesszőkkel, mégis ponttal zárul. A harmadik is rövid.';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 3,
        name: 'Teszt3',
        title: 'Teszt3',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': text},
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 5);

      final List<CustomOrderEntry> textEntries = entries;
      expect(textEntries.length, greaterThan(1));

      for (int i = 0; i < textEntries.length; i++) {
        final String body = textEntries[i].customTextBody ?? '';
        final int wc = wordCount(body);
        // Never exceed the limit.
        expect(wc, lessThanOrEqualTo(5),
            reason: 'chunk $i has $wc words (> limit)');

        if (i < textEntries.length - 1) {
          final String lastWord = body.trim().split(RegExp(r'\s+')).last;
          final bool endsOnBoundary = lastWord.endsWith('.') ||
              lastWord.endsWith(',') ||
              lastWord.endsWith('!') ||
              lastWord.endsWith('?') ||
              lastWord.endsWith(';') ||
              lastWord.endsWith(':') ||
              lastWord.endsWith('”') ||
              lastWord.endsWith('»');
          // A non-final chunk must either end on a semantic boundary or be
          // filled exactly to the limit (hard cut with no boundary available).
          expect(endsOnBoundary || wc == 5, isTrue,
              reason: 'chunk $i ("$lastWord") should end on a boundary or '
                  'be exactly at the limit');
        }
      }
    });
  });

  group('NapiLelkiBatyuService psalm and alleluia', () {
    final NapiLelkiBatyuService service = NapiLelkiBatyuService();

    test('psalm splits at Előénekes/E boundaries and omits zsoltár title', () {
      const String text = 'Válasz: <b>Az Úr nékem pásztorom, * ínséget nem kell '
          'látnom.</b> (9. tónus.)<br>Vagy: <b>Alleluja, alleluja, alleluja.</b> '
          '1. szám.<br><br>Előénekes: Az Úr nékem pásztorom: * ínséget nem kell '
          'látnom.<br>Zöldellő mezőkön terelget engem, * csendes vizekhez vezet és '
          'lelkemet felüdíti.<br>Hívek: Az Úr nékem pásztorom, * ínséget nem kell '
          'látnom.<br><br>Vagy: <b>Alleluja, alleluja, alleluja.</b><br><br>'
          'E: Az igazság ösvényén vezet engem, * ahogyan ő megígérte.<br>'
          'A halál sötét völgyében sem félek, mert ott vagy vélem, * biztonságot ad '
          'vessződ és pásztorbotod.<br>H: Az Úr nékem pásztorom, * ínséget nem kell '
          'látnom.<br><br>Vagy: <b>Alleluja, alleluja, alleluja.</b><br><br>'
          'E: Számomra asztalt terítettél, * hogy üldözőimet szégyen érje.<br>'
          'Fejemet megkened olajoddal, * serlegemet csordultig megtöltötted.<br>'
          'H: Az Úr nékem pásztorom, * ínséget nem kell látnom.<br><br>'
          'Vagy: <b>Alleluja, alleluja, alleluja.</b>';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 10,
        name: 'Zsoltár',
        title: 'Zsoltár',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{
            'short_title': 'zsoltár',
            'teaser': 'ZSOLTÁR 23',
            'text': text,
          },
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 30);

      final List<CustomOrderEntry> psalmEntries = entries;
      // Three cantor/faithful stanzas, each over the 30-word limit => 3 slides.
      expect(psalmEntries.length, equals(3));

      // The slide title carries the "Zsoltár" type name, but it is not in the
      // body text.
      for (final CustomOrderEntry e in psalmEntries) {
        expect(e.customTextTitle ?? '', startsWith('Zsoltár'));
      }

      // The combined body must not contain the word "zsoltár" anywhere.
      final String all = psalmEntries
          .map((CustomOrderEntry e) => e.customTextBody ?? '')
          .join('\n');
      expect(all.toLowerCase(), isNot(contains('zsoltár')));

      // Each slide starts at a semantic boundary: the first with the antiphon,
      // the others with a cantor verse ("E:").
      expect(psalmEntries[0].customTextBody ?? '', startsWith('Válasz:'));
      expect(psalmEntries[1].customTextBody ?? '', startsWith('E:'));
      expect(psalmEntries[2].customTextBody ?? '', startsWith('E:'));
    });

    test('psalm packs two stanzas onto one slide when they fit', () {
      // Two short stanzas; with a generous limit both fit on a single slide.
      const String text = 'Válasz: <b>Áldjad lelkem az Urat.</b><br>'
          'Előénekes: Áldjad lelkem az Urat, * dicsőítsed az Istent.<br>'
          'Hívek: Áldjad lelkem az Urat.<br>'
          'E: Az Úr megnyitja a vakok szemét, * és fölemeli azt, aki elesett.<br>'
          'H: Áldjad lelkem az Urat.';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 11,
        name: 'Zsoltár',
        title: 'Zsoltár',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{
            'short_title': 'zsoltár',
            'text': text,
          },
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 200);

      final List<CustomOrderEntry> psalmEntries = entries;
      // Both stanzas fit within the limit, so a single slide.
      expect(psalmEntries.length, equals(1));
      final String body = psalmEntries.first.customTextBody ?? '';
      expect(body, startsWith('Válasz:'));
      expect(body, contains('Előénekes:'));
      expect(body, contains('E:'));
    });

    test('alleluia is wrapped with Alleluja at the start and end', () {
      const String text = 'Válasz: <b>Az Ige emberré lett, * és itt élt '
          'közöttünk.</b> (7. tónus.)<br>Vagy: <b>Alleluja.</b> 7. szám<br><br>'
          'Előénekes: Dicsérd Uradat, Jeruzsálem, * magasztald, Sion, '
          'Istenedet.<br>Mert erőssé tette kapuid zárát, * és megáldotta benned '
          'fiaidat.<br>Hívek: <b>Az Ige emberré lett, * és itt élt '
          'közöttünk.</b><br>Vagy: <b>Alleluja.</b><br><br>'
          'E: Határaidon ő ad békét, * és jóllakat kövér búzával.<br>'
          'Elküldi szavát a földre, * az ő igéje gyorsan terjed.<br>'
          'H: <b>Az Ige emberré lett, * és itt élt közöttünk.</b><br>'
          'Vagy: <b>Alleluja.</b>';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 12,
        name: 'Alleluja',
        title: 'Alleluja',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{
            'short_title': 'alleluja',
            'teaser': 'Válasz: Az Ige emberré lett',
            'text': text,
          },
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 30);

      final List<CustomOrderEntry> alleluiaEntries = entries;
      expect(alleluiaEntries, isNotEmpty);

      for (final CustomOrderEntry e in alleluiaEntries) {
        // The slide title carries the "Alleluja" type name.
        expect(e.customTextTitle ?? '', startsWith('Alleluja'));
        final String body = e.customTextBody ?? '';
        expect(body, startsWith('Alleluja'));
        expect(body, endsWith('Alleluja'));
      }
    });

    test('array type includes every variant (vagy-vagy)', () {
      // Two gospel variants: a longer and a shorter ("vagy") form. Both must
      // be included as separate slides, not just the first one.
      const String longText = 'Ez az első hosszú változat, amely több szót '
          'tartalmaz a példában. A második mondat is itt van.';
      const String shortText = 'Ez a rövidebb változat, kevesebb szöveggel.';

      final NapiLelkiBatyuCelebration celebration = NapiLelkiBatyuCelebration(
        key: 13,
        name: 'Evangélium',
        title: 'Evangélium',
        parts: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'array',
            'content': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'object',
                'short_title': 'evangélium',
                'ref': 'Lk 2,22-40',
                'title': '† EVANGÉLIUM',
                'text': longText,
              },
              <String, dynamic>{
                'type': 'object',
                'short_title': 'evangélium',
                'ref': 'Lk 2,22-32',
                'title': '† EVANGÉLIUM',
                'text': shortText,
                'cause': 'Vagy rövidebb forma',
              },
            ],
          },
        ],
      );

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebration, wordsPerSlide: 30);

      final String all = entries
          .map((CustomOrderEntry e) => e.customTextBody ?? '')
          .join('\n');

      // Both variants are present in the output.
      expect(all, contains('Lk 2,22-40'));
      expect(all, contains('Lk 2,22-32'));
      expect(all, contains('Ez az első hosszú változat'));
      expect(all, contains('Ez a rövidebb változat'));

      // The two alternatives must carry distinct titles so the UI shows them
      // as separate selectable items (not as one continuous verse sequence).
      final List<String> titles = entries
          .map((CustomOrderEntry e) => e.customTextTitle ?? '')
          .where((String t) => t.isNotEmpty)
          .toList();
      expect(titles.any((String t) => t.contains('Vagy rövidebb forma')), isTrue);
      expect(titles.any((String t) => !t.contains('Vagy rövidebb forma')), isTrue);
    });

    test('bare-list part (single-day file) includes every variant', () {
      // In the single-day file the "vagy" part is a bare list of variant
      // dicts (not wrapped in {type: array, content: ...}). parseCelebrations
      // must normalize it so both variants end up in the slides.
      const String longText = 'Ez az első hosszú változat, amely több szót '
          'tartalmaz a példában. A második mondat is itt van.';
      const String shortText = 'Ez a rövidebb változat, kevesebb szöveggel.';

      final Map<String, dynamic> dayJson = <String, dynamic>{
        'ISO': '2026-07-17',
        'celebration': <Map<String, dynamic>>[
          <String, dynamic>{
            'celebrationKey': 0,
            'name': 'Evangélium',
            'title': 'Evangélium',
            'parts': <dynamic>[
              <String, dynamic>{
                'short_title': 'evangélium',
                'ref': 'Lk 2,22-40',
                'title': '† EVANGÉLIUM',
                'text': longText,
              },
              <String, dynamic>{
                'short_title': 'evangélium',
                'ref': 'Lk 2,22-32',
                'title': '† EVANGÉLIUM',
                'text': shortText,
                'cause': 'Vagy rövidebb forma',
              },
            ],
          },
        ],
      };

      final List<NapiLelkiBatyuCelebration> celebrations =
          service.parseCelebrations(dayJson);
      expect(celebrations, hasLength(1));

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebrations.first, wordsPerSlide: 30);

      final String all = entries
          .map((CustomOrderEntry e) => e.customTextBody ?? '')
          .join('\n');

      expect(all, contains('Lk 2,22-40'));
      expect(all, contains('Lk 2,22-32'));
      expect(all, contains('Ez az első hosszú változat'));
      expect(all, contains('Ez a rövidebb változat'));
    });

    test('parts2 sections are also imported after parts', () {
      // Some celebrations carry extra sections in `parts2` (same structure as
      // `parts`). Both must appear in the generated slides, in order.
      final Map<String, dynamic> dayJson = <String, dynamic>{
        'ISO': '2026-07-17',
        'celebration': <Map<String, dynamic>>[
          <String, dynamic>{
            'celebrationKey': 0,
            'name': 'Evangélium',
            'title': 'Evangélium',
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{
                'short_title': 'evangélium',
                'ref': 'Lk 2,22-40',
                'title': '† EVANGÉLIUM',
                'text': 'Ez az első rész szövege, amely az olvasmányt adja.',
              },
            ],
            'parts2': <Map<String, dynamic>>[
              <String, dynamic>{
                'short_title': 'evangélium',
                'ref': 'Jn 1,1-10',
                'title': '† EVANGÉLIUM',
                'text': 'Ez a második rész szövege, amely a parts2-ből jön.',
              },
            ],
          },
        ],
      };

      final List<NapiLelkiBatyuCelebration> celebrations =
          service.parseCelebrations(dayJson);
      expect(celebrations, hasLength(1));

      final List<CustomOrderEntry> entries =
          service.buildEntries(celebrations.first, wordsPerSlide: 30);

      final String all = entries
          .map((CustomOrderEntry e) => e.customTextBody ?? '')
          .join('\n');

      expect(all, contains('Lk 2,22-40'));
      expect(all, contains('Ez az első rész szövege'));
      expect(all, contains('Jn 1,1-10'));
      expect(all, contains('Ez a második rész szövege'));

      // The parts2 section must follow the parts section.
      final int firstIdx = all.indexOf('Ez az első rész szövege');
      final int secondIdx = all.indexOf('Ez a második rész szövege');
      expect(firstIdx, lessThan(secondIdx));
    });
  });
}
