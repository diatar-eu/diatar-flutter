# Copilot Instructions - Localization Required

These rules are mandatory for all AI edits in this repository.

## Source of truth
- All user-facing UI text must come from localization keys.
- Do not add hardcoded UI strings in Dart widgets, view models, services, or tests (except test-only assertions/messages).
- Only edit ARB source files for translations:
  - `Diatar/lib/l10n/app_en.arb`
  - `Diatar/lib/l10n/app_hu.arb`
  - `DiaVetito/lib/l10n/app_en.arb`
  - `DiaVetito/lib/l10n/app_hu.arb`

## Multi-language update rule
- When adding or changing a localization key, update that key in every language file in the same app.
- Current required languages for each app: `en` and `hu`.
- Do not leave missing keys between `app_en.arb` and `app_hu.arb`.

## Generated files
- Never manually edit generated localization output files under `lib/l10n/generated/`.
- After ARB changes, regenerate localization code using project tooling.

## Implementation pattern
- In code, use `AppLocalizations` accessors (for example: `l10n.someKey`) instead of string literals.
- If a new screen/dialog/button/title is added, first add localization keys, then use those keys in UI code.

## Version control
- Never run `git commit` or `git push` in this repository, not even for a single small fix. Leave the work in the working tree; the owner reviews and commits it by hand.
- Do not bump `version:` in either `pubspec.yaml`, and do not edit `release-notes/` — those belong to the owner's commit, not to the edit.
- Do not hand-edit `pubspec.lock`. If a lock looks wrong, the Flutter SDK is wrong; see [DEVELOPMENT.md](../DEVELOPMENT.md).

## Pull request expectations
- Every UI text change must include corresponding ARB updates.
- Every new/changed key must be present in both `en` and `hu` for the affected app.
