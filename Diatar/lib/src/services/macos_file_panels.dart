import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS-on natív (`runModal`) fájlpárbeszédablakokat használ a file_selector
/// sheet-je helyett. A vezérlőablakhoz csatolt sheet (`beginSheetModal`) a
/// vetítőablak jelenlétében nem jelenik meg megbízhatóan; a modális panel
/// ettől függetlenül mindig a felszínre kerül. Más platformon a
/// file_selector alapműködését használjuk.
const MethodChannel _macosFilePanelsChannel =
    MethodChannel('diatar/macos_file_panels');

bool _useMacosNativePanels() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

XTypeGroup _typeGroupForExtensions(List<String> extensions) {
  if (extensions.isEmpty) {
    return const XTypeGroup(label: 'All files');
  }
  return XTypeGroup(label: 'Files', extensions: extensions);
}

/// Mentő párbeszédablakot nyit meg. Visszaadja a választott útvonalat,
/// vagy `null`-t, ha a felhasználó megszakította.
Future<FileSaveLocation?> showFileSavePanel({
  required String suggestedName,
  List<String> extensions = const <String>[],
  String? initialDirectory,
  String? confirmButtonText,
}) async {
  if (!_useMacosNativePanels()) {
    return getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[_typeGroupForExtensions(extensions)],
      initialDirectory: initialDirectory,
      suggestedName: suggestedName,
      confirmButtonText: confirmButtonText,
    );
  }
  try {
    final String? path = await _macosFilePanelsChannel.invokeMethod<String>(
      'savePanel',
      <String, Object?>{
        'suggestedName': suggestedName,
        'directoryPath': initialDirectory,
        'extensions': extensions,
        'prompt': confirmButtonText,
      },
    );
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
  if (!_useMacosNativePanels()) {
    final List<XTypeGroup> groups = <XTypeGroup>[_typeGroupForExtensions(extensions)];
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
  try {
    final Object? result = await _macosFilePanelsChannel.invokeMethod(
      'openPanel',
      <String, Object?>{
        'extensions': extensions,
        'multiple': multiple,
        'directoryPath': initialDirectory,
      },
    );
    final List<Object?>? paths = result as List<Object?>?;
    return paths == null
        ? <XFile>[]
        : paths
            .map((Object? path) => XFile(path! as String))
            .toList(growable: false);
  } on MissingPluginException {
    final List<XTypeGroup> groups = <XTypeGroup>[_typeGroupForExtensions(extensions)];
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
}

/// Mappaválasztó párbeszédablakot nyit meg. Visszaadja a választott mappa
/// útvonalát, vagy `null`-t, ha a felhasználó megszakította.
Future<String?> showDirectoryPicker({String? initialDirectory}) async {
  if (!_useMacosNativePanels()) {
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
