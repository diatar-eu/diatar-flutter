import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:diatar_common/diatar_common.dart';

import '../l10n/generated/app_localizations.dart';
import 'controllers/diatar_main_controller.dart';
import 'ui/home_page.dart';

class DiatarApp extends StatefulWidget {
  const DiatarApp({super.key});

  @override
  State<DiatarApp> createState() => _DiatarAppState();
}

class _DiatarAppState extends State<DiatarApp> with WidgetsBindingObserver {
  final DiatarMainController _controller = DiatarMainController();

  Locale? _resolveAppLocale(String languageCode) {
    if (languageCode.trim().isEmpty) {
      return null;
    }
    for (final Locale locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) {
        return locale;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enableImmersiveMode());
    unawaited(_controller.init());
    unawaited(
      KottaAssets.ensureLoaded().then((_) {
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enableImmersiveMode());
    }
  }

  Future<void> _enableImmersiveMode() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final int themeModeIndex = _controller.settings.appThemeMode.clamp(0, 1);
        final ThemeMode themeMode =
            themeModeIndex == 1 ? ThemeMode.light : ThemeMode.dark;
        final Locale? appLocale = _resolveAppLocale(_controller.settings.appLanguage);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: appLocale,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: themeMode,
          home: DiatarHomePage(controller: _controller),
        );
      },
    );
  }
}
