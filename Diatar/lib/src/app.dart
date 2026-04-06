import 'package:flutter/material.dart';
import 'dart:async';
import 'package:diatar_common/diatar_common.dart';

import 'controllers/diatar_main_controller.dart';
import 'ui/diatar_home_page.dart';

class DiatarApp extends StatefulWidget {
  const DiatarApp({super.key});

  @override
  State<DiatarApp> createState() => _DiatarAppState();
}

class _DiatarAppState extends State<DiatarApp> {
  final DiatarMainController _controller = DiatarMainController();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.init());
    unawaited(KottaAssets.ensureLoaded().then((_) {
      if (mounted) {
        setState(() {});
      }
    }));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Diatar',
      theme: ThemeData.dark(useMaterial3: true),
      home: DiatarHomePage(controller: _controller),
    );
  }
}
