import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'package:diatar_common/diatar_common.dart';

import '../l10n/generated/app_localizations.dart';
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
      onGenerateTitle: (BuildContext context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(useMaterial3: true),
      home: HomePage(controller: _controller),
    );
  }
}
