import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'create') {
        return <String, dynamic>{'playerId': 'mock-player'};
      }
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAll':
          return <String, dynamic>{};
        case 'setBool':
        case 'setDouble':
        case 'setInt':
        case 'setString':
        case 'setStringList':
        case 'remove':
          return true;
        default:
          return null;
      }
    },
  );

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

  group('custom order naming', () {
    test('updates the active set display name after a save-as rename', () async {
      final DiatarMainController controller = DiatarMainController();

      await controller.createCustomOrderSet('Régi név');
      await controller.markCustomOrderDiaExportSaved('C:/Temp/Új név.dia');

      expect(controller.customOrderSets, hasLength(1));
      expect(controller.customOrderSets.first.name, 'Új név');
      expect(controller.customOrderSets.first.baseName, 'Új név');
      expect(controller.customOrderSets.first.displayName, 'Új név');
      expect(controller.suggestedCustomOrderBaseName, 'Új név');
    });
  });
}
