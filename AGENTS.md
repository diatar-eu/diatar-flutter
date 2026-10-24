# Diatár — agent instructions

This file is what an AI agent reads when working in this repository. OpenCode
V2 loads `AGENTS.md` only; `CLAUDE.md` is kept for other tools and is **not**
loaded automatically, so anything an agent must obey is restated here.

**Read `CLAUDE.md` and `DEVELOPMENT.md` before your first change.**
`CLAUDE.md` has the architecture map and the reasoning behind the rules below;
`DEVELOPMENT.md` has the setup and the everyday commands. This file is the
subset that must never be missed.

## Non-negotiable

- **Never `git commit`. Never `git push`. Not even a tidy fixup commit.** The
  owner reviews and commits by hand. Leave changes in the working tree; a
  `git status` + `git diff` the owner can read is the deliverable. Also never
  `git rebase`, `git reset --hard`, `git commit --amend`, and never stash
  anything you did not create yourself.
- Do not edit `version:` in `Diatar/pubspec.yaml` or `DiaVetito/pubspec.yaml`,
  and do not touch `release-notes/`. Mention them in your report instead.
- Every user-facing string is a localization key. Edit only
  `Diatar/lib/l10n/app_hu.arb` and `app_en.arb` (Hungarian is the template
  language — add the `hu` key first). No string literals in widgets,
  controllers or services. `lib/l10n/generated/**` is gitignored; regenerate
  with `flutter gen-l10n` and never hand-edit or commit it.
- Do not edit generated or vendored build output, and do not touch the native
  (C++/Swift) sides of the plugins in `patches/` unless asked.

## Verify before reporting

From `Diatar/` (and each other package you touched):

```bash
flutter analyze     # must be 0 errors
flutter test        # must be fully green
```

A claim of "fixed" without those two commands run is not a result. New
business logic under `src/core/**` or `src/services/**` comes with a test in
`<app>/test/`; the suite runs without a device in seconds and is the primary
feedback loop.

If `pubspec.lock` churns in `git status` after `flutter pub get`, the SDK is
wrong — see `DEVELOPMENT.md` §1. The Flutter stable branch is *pinned*, not
merely current, and `flutter upgrade` silently downgrades five packages.

## Where code goes

- Business rules belong in small testable classes under `src/core/**`
  (`core/custom_order/`, `core/navigation/`, `core/dia/`, `core/hotkeys/`).
- I/O belongs in `src/services/**`.
- Do not add to `diatar_main_controller.dart`, `home_page.dart`,
  `settings_sheet.dart` or `custom_order_editor_sheet.dart` by default — each
  is already several thousand lines.
- Keep the `*_stub.dart` / `*_web.dart` / `*_native.dart` conditional-import
  split. DiaVetítő ships a web build, so shared code cannot import `dart:io`
  or FFI packages unconditionally.
- When a feature spans both apps, the wire format in
  `packages/diatar_common/lib/models/` must stay backward compatible: receivers
  update late or never, so prefer an existing record type over a new one.

## Language and docs

- Code, comments and these guides are English.
- `docs/`, `release-notes/` and UI strings are Hungarian.
- `docs/` is published to web.diatar.eu via mkdocs — user-visible behaviour
  changes need a `docs/` update in Hungarian.
- `HIDDEN.md` lists finished UI with no way to reach it. Check it before
  concluding something is unimplemented.
