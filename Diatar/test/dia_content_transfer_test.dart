import 'dart:convert';

import 'package:diatar_app/l10n/generated/app_localizations.dart';
import 'package:diatar_app/src/controllers/diatar_main_controller.dart';
import 'package:diatar_app/src/core/dia/dia_embedded_image_codec.dart';
import 'package:diatar_app/src/core/dia/dia_ini_parser.dart';
import 'package:diatar_app/src/ui/custom_order_editor_sheet.dart';
import 'package:diatar_app/src/utils/file_system_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
  });

  test('imports picked content without opening its browser URL', () async {
    final controller = DiatarMainController();
    addTearDown(controller.dispose);
    await controller.createCustomOrderSet('Existing');

    final count = await controller.importCustomOrderFromDiaContent(
      '[main]\ndiaszam=1\nutf8=1\n\n'
      '[1]\ncaption=Áldás\nlines=1\nline0=Őrizz meg!\n',
      path: 'blob:https://example.invalid/picked-file',
      sourceFileName: 'Áldás.dia',
      activate: false,
    );

    expect(count, 1);
    expect(controller.customOrderSets, hasLength(2));
    expect(controller.customOrderSets.last.displayName, 'Áldás');
    expect(controller.customOrder.single.customTextBody, 'Őrizz meg!');

    await controller.importCustomOrderFromDiaContent(
      '[main]\ndiaszam=0\n',
      path: 'empty.dia',
      mode: CustomOrderImportMode.overwriteActive,
      activate: false,
    );
    expect(controller.customOrderSets, hasLength(2));
    expect(controller.customOrder, isEmpty);
    expect(controller.customOrderSets.last.displayName, 'empty');
  });

  test('creates downloadable UTF-8 bytes without writing a DIA file', () async {
    final controller = DiatarMainController();
    addTearDown(controller.dispose);
    await controller.importCustomOrderFromDiaContent(
      '[main]\ndiaszam=1\n\n'
      '[1]\ncaption=Áldás\nlines=1\nline0=Őrizz meg!\n',
      path: 'source.dia',
      activate: false,
    );

    final bytes = await controller.createCustomOrderDiaBytes(
      'unwritten-download.dia',
    );
    expect(
      await FileSystemProvider.instance.file('unwritten-download.dia').exists(),
      isFalse,
    );
    expect(controller.customOrderSets.single.diaFilePath, 'source.dia');

    final imported = DiatarMainController();
    addTearDown(imported.dispose);
    expect(
      await imported.importCustomOrderFromDiaContent(
        utf8.decode(bytes),
        path: 'download.dia',
        activate: false,
      ),
      1,
    );
    expect(imported.customOrder.single.customTextTitle, 'Áldás');
    expect(imported.customOrder.single.customTextBody, 'Őrizz meg!');
  });

  test(
    'restores and re-exports embedded images in the browser file system',
    () async {
      final box = await Hive.openBox('diatar_web_fs');
      addTearDown(() async {
        await box.clear();
        await box.close();
      });
      final controller = DiatarMainController();
      addTearDown(controller.dispose);
      final image = Uint8List.fromList(<int>[137, 80, 78, 71]);
      final embedded = const DiaEmbeddedImageCodec().encode(<String, Uint8List>{
        'C:/Pictures/image.png': image,
      });
      final content = StringBuffer(
        '[main]\ndiaszam=1\n\n[1]\nkep=C:/Pictures/image.png\n\n[Embedded]\n',
      );
      for (final field in embedded.entries) {
        content.writeln('${field.key}=${field.value}');
      }

      expect(
        await controller.importCustomOrderFromDiaContent(
          content.toString(),
          path: 'picked.dia',
          activate: false,
        ),
        1,
      );
      final file = FileSystemProvider.instance.file(
        controller.customOrder.single.customImagePath!,
      );
      addTearDown(() => file.parent.delete(recursive: true));
      expect(await file.readAsBytes(), image);

      final bytes = await controller.createCustomOrderDiaBytes(
        'download.dia',
        embedImages: true,
      );
      final sections = const DiaIniParser().parse(utf8.decode(bytes));
      final images = const DiaEmbeddedImageCodec().decode(sections['embedded']);
      expect(images.values.single, image);
    },
    skip: !kIsWeb,
  );

  testWidgets('web save asks only for a filename and starts the download', (
    tester,
  ) async {
    final controller = DiatarMainController();
    addTearDown(controller.dispose);
    await controller.createCustomOrderSet('Existing');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hu'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CustomOrderEditorPanel(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CustomOrderEditorPanel)),
    )!;
    await tester.tap(find.widgetWithText(OutlinedButton, l10n.saveDia));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byTooltip(l10n.fileChoose), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.customOrderDiaFileNameLabel),
      'Áldás.dia',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.saveDia));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.customOrderSets.single.displayName, 'Áldás');
    expect(controller.customOrderSets.single.isModified, isFalse);
    expect(find.text(l10n.savedPath('Áldás.dia')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !kIsWeb);
}
