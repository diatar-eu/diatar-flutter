import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('merge title formatting', () {
    test('keeps shared book and song prefix once', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet: ének/vers1',
        'Kötet: ének/vers2',
      );

      expect(merged, 'Kötet: ének/vers1, vers2');
    });

    test('keeps shared book prefix and separates differing song/verse', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet: ének1/vers1',
        'Kötet: ének2/vers2',
      );

      expect(merged, 'Kötet: ének1/vers1, ének2/vers2');
    });

    test('falls back to comma-separated full labels when no shared prefix', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet1: ének1/Vers1',
        'kötet2: ének2/vers2',
      );

      expect(merged, 'Kötet1: ének1/Vers1, kötet2: ének2/vers2');
    });

    test('normalizes slash spacing before merge formatting', () {
      final String merged = DiatarMainController.formatMergedProjectionLabel(
        'Kötet: ének / vers1',
        'Kötet: ének/vers2',
      );

      expect(merged, 'Kötet: ének/vers1, vers2');
    });
  });
}
