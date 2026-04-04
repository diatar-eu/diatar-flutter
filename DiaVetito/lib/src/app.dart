import 'package:flutter/material.dart';

import 'controllers/projection_controller.dart';
import 'ui/home_page.dart';

class DiaVetitoApp extends StatefulWidget {
  const DiaVetitoApp({super.key});

  @override
  State<DiaVetitoApp> createState() => _DiaVetitoAppState();
}

class _DiaVetitoAppState extends State<DiaVetitoApp> {
  final ProjectionController _controller = ProjectionController();

  @override
  void initState() {
    super.initState();
    _controller.init();
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
      title: 'DiaVetito',
      theme: ThemeData.dark(useMaterial3: true),
      home: HomePage(controller: _controller),
    );
  }
}
