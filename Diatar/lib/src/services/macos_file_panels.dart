import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_export_directory.dart';
import '../utils/ios_platform.dart';

/// Fájlpárbeszédablakok minden platformra.
///
/// macOS-en natív (`runModal`) párbeszédablakokat használ a file_selector
/// sheet-je helyett. A vezérlőablakhoz csatolt sheet (`beginSheetModal`) a
/// vetítőablak jelenlétében nem jelenik meg megbízhatóan; a modális panel
/// ettől függetlenül mindig a felszínre kerül.
///
/// iOS-en a `file_selector` a megnyitásra szolgáló `UIDocumentPickerViewController`
/// felülérvényesítőjét az `UIApplicationDelegate.window` alapján keresi. A
/// `UISceneDelegate`-es életciklusban (amit ez az app is használ) az nincs
/// beállítva, ezért a panelt itt, a szín (scene) gyökerének
/// root view kontrolleréből jelenítjük meg. Mentésre és mappaválasztásra
/// iOS-en nincs rendszerablak: a `file_selector` iOS implementációja a
/// `getSavePath`-ot és a `getDirectoryPath`-ot sem valósítja meg.
///
/// A két platform ugyanazt a csatornát és metódusneveket használja, ezért
/// [showFileOpenPanel] egyetlen helyen kezeli őket. A többi platformon a
/// file_selector alapműködését használjuk.
const MethodChannel _macosFilePanelsChannel = MethodChannel(
  'diatar/macos_file_panels',
);

bool _useNativePanels() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS);

XTypeGroup _typeGroupForExtensions(List<String> extensions) {
  if (extensions.isEmpty) {
    return const XTypeGroup(label: 'All files');
  }
  return XTypeGroup(label: 'Files', extensions: extensions);
}

/// Mentő párbeszédablakot nyit meg. Visszaadja a választott útvonalat,
/// vagy `null`-t, ha a felhasználó megszakította.
///
/// iOS-en nincs rendszer-mentőablak, ezért a fájl az app export mappájába
/// kerül ([AppExportDirectory]); a felhasználó a Fájlok alkalmazásban éri el.
Future<FileSaveLocation?> showFileSavePanel({
  required String suggestedName,
  List<String> extensions = const <String>[],
  String? initialDirectory,
  String? confirmButtonText,
}) async {
  if (isIosPlatform) {
    final String filePath = await AppExportDirectory().resolveFilePath(
      suggestedName: suggestedName,
      extensions: extensions,
    );
    return FileSaveLocation(filePath);
  }
  if (!_useNativePanels()) {
    return getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[_typeGroupForExtensions(extensions)],
      initialDirectory: initialDirectory,
      suggestedName: suggestedName,
      confirmButtonText: confirmButtonText,
    );
  }
  try {
    final String? path = await _macosFilePanelsChannel
        .invokeMethod<String>('savePanel', <String, Object?>{
          'suggestedName': suggestedName,
          'directoryPath': initialDirectory,
          'extensions': extensions,
          'prompt': confirmButtonText,
        });
    return path == null ? null : FileSaveLocation(path);
  } on MissingPluginException {
    return getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[_typeGroupForExtensions(extensions)],
      initialDirectory: initialDirectory,
      suggestedName: suggestedName,
      confirmButtonText: confirmButtonText,
    );
  }
}

/// Megnyitó párbeszédablakot nyit meg (egyszeres vagy többszörös kiválasztás).
Future<List<XFile>> showFileOpenPanel({
  List<String> extensions = const <String>[],
  bool multiple = false,
  String? initialDirectory,
}) async {
  if (_useNativePanels()) {
    try {
      final Object? result = await _macosFilePanelsChannel
          .invokeMethod('openPanel', <String, Object?>{
            'extensions': extensions,
            'multiple': multiple,
            'directoryPath': initialDirectory,
          });
      final List<Object?>? paths = result as List<Object?>?;
      return paths == null
          ? <XFile>[]
          : paths
                .map((Object? path) => XFile(path! as String))
                .toList(growable: false);
    } on MissingPluginException {
      if (isIosPlatform) {
        // iOS-en nincs tartalék: a file_selector megnyitója ugyanazt a
        // felülérvényesítőt keresi, ami miatt a saját panelünket használjuk.
        return <XFile>[];
      }
    }
  }
  final List<XTypeGroup> groups = <XTypeGroup>[
    _typeGroupForExtensions(extensions),
  ];
  if (multiple) {
    return openFiles(
      acceptedTypeGroups: groups,
      initialDirectory: initialDirectory,
    );
  }
  final XFile? file = await openFile(
    acceptedTypeGroups: groups,
    initialDirectory: initialDirectory,
  );
  return file == null ? <XFile>[] : <XFile>[file];
}

/// Mappaválasztó párbeszédablakot nyit meg. Visszaadja a választott mappa
/// útvonalát, vagy `null`-t, ha a felhasználó megszakította.
///
/// iOS-en a sandboxon belül nem választható ki másik mappa, ezért az app
/// export mappáját adjuk vissza.
Future<String?> showDirectoryPicker({String? initialDirectory}) async {
  if (isIosPlatform) {
    return AppExportDirectory().resolve();
  }
  if (!_useNativePanels()) {
    return getDirectoryPath(initialDirectory: initialDirectory);
  }
  try {
    return await _macosFilePanelsChannel.invokeMethod<String>(
      'directoryPanel',
      <String, Object?>{'directoryPath': initialDirectory},
    );
  } on MissingPluginException {
    return getDirectoryPath(initialDirectory: initialDirectory);
  }
}
