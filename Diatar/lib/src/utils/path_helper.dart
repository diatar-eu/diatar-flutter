import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PathHelper {
  /// Returns the path to the application documents directory.
  /// On web, it returns a dummy path to avoid crashing, 
  /// as getApplicationDocumentsDirectory is not supported.
  static Future<String> getDocumentsDirectoryPath() async {
    if (kIsWeb) {
      return 'web_dummy_docs';
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }
}
