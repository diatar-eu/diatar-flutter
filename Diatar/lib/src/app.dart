import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:diatar_common/diatar_common.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/generated/app_localizations.dart';
import 'controllers/diatar_main_controller.dart';
import 'ui/desktop_hotkeys_layer.dart';
import 'ui/home_page.dart';
import 'ui/onboarding_sheet.dart';
import 'utils/web_page_hide.dart';

class DiatarApp extends StatefulWidget {
  const DiatarApp({super.key});

  @override
  State<DiatarApp> createState() => _DiatarAppState();
}

class _DiatarAppState extends State<DiatarApp>
    with WidgetsBindingObserver, WindowListener {
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
    if (_isDesktopPlatform()) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
    }
    if (kIsWeb) {
      registerPageHideHandler(() {
        unawaited(_controller.clearRetainedBestEffort());
      });
    }
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
    if (_isDesktopPlatform()) {
      windowManager.removeListener(this);
    }
    _controller.dispose();
    super.dispose();
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// A vezérlő (fő) ablak bezárásakor (pl. a fejléc bezárás gombja) zárjuk be
  /// a vetítőablakot is, és lépünk ki a programból teljesen.
  @override
  void onWindowClose() async {
    await _controller.requestExit();
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

  /// Androidon a back gomb a [requestExit]-re fut, így a kilépés előtt még
  /// megtörténik a retained üzenetek törlése is.
  Widget _wrapExitGuard(Widget child) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return child;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_controller.requestExit());
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final int themeModeIndex = _controller.settings.appThemeMode.clamp(
          0,
          1,
        );
        final ThemeMode themeMode = themeModeIndex == 1
            ? ThemeMode.light
            : ThemeMode.dark;
        final Locale? appLocale = _resolveAppLocale(
          _controller.settings.appLanguage,
        );
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
          // A DesktopHotkeysLayer-t (gyorsbillentyűket kezelő Focus réteget)
          // mindig csatlakoztatjuk, hogy a billentyűk akkor is működjenek,
          // ha a vezérlő ablak el van rejtve. Ilyenkor csak az ablak
          // tartalma üres (és a kurzor el van rejtve), maga a réteg megmarad.
          home: _wrapExitGuard(
            DesktopHotkeysLayer(
              controller: _controller,
              child: _controller.controlWindowHidden
                  ? MouseRegion(
                      cursor: SystemMouseCursors.none,
                      child: const SizedBox.expand(),
                    )
                  : _controller.pendingOnboarding
                  ? OnboardingSheet(
                      onComplete: () {
                        unawaited(_controller.markOnboardingSeen());
                      },
                    )
                  : DiatarHomePage(controller: _controller),
            ),
          ),
        );
      },
    );
  }
}
