import 'package:flutter/foundation.dart';

/// Igaz, ha az alkalmazás iOS-en fut.
///
/// A [kIsWeb] ellenőrzés azért szükséges, mert weben a `defaultTargetPlatform`
/// értéke futási időben alapértelmezetten Androidként jelenik meg.
bool get isIosPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
