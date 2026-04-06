# Diatar Flutter Refactor Status

This app is the Flutter target for refactoring `diatar-android/Diatar`.

## What was done

- Created a new Flutter app at `diatar-flutter/Diatar`.
- Created a shared package at `diatar-flutter/packages/diatar_common`.
- Moved shared projection/domain models from `DiaVetito` to `diatar_common`:
  - `AppSettings`
  - `MqttUser`
  - `Rec*` record models and helpers
  - `ProjectionFrame`
  - `ProjectionGlobals`
- Updated `DiaVetito` imports to consume shared models from `package:diatar_common/diatar_common.dart`.
- Removed duplicated local model files from `DiaVetito/lib/src/models`.

## Why this matters

This establishes a single source of truth for shared domain logic, so the upcoming Flutter `Diatar` implementation can reuse the same models without duplication.

## Next migration slices (recommended)

1. Port Android `Lines` parser logic into `diatar_common`.
2. Port Android `TxtSizer` layout rules into shared/service layer.
3. Implement `Diatar` sender-side transport and UI modules using shared models.
4. Expand `diatar_common` with protocol and command abstractions as they are ported.
