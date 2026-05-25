import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WakelockPlus.enable();
  runApp(const DiaVetitoApp());
}
