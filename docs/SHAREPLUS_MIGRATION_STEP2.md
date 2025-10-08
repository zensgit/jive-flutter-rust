# SharePlus Migration — Step 2 (Draft)

Purpose
- Upgrade `share_plus` to a version compatible with Flutter 3.35.x and migrate from deprecated static `Share.*` API to the instance API.

Scope
- Upgrade dependency in `jive-flutter/pubspec.yaml` (keep ecosystem compatible).
- Update call sites:
  - `jive-flutter/lib/services/share_service.dart`
  - `jive-flutter/lib/widgets/qr_code_generator.dart`
- Adapt to new signatures if required (e.g., `ShareParams`).

Validation
- `cd jive-flutter && flutter pub get`
- `flutter analyze` (no new errors)
- `flutter test` (remain green)
- Manual sanity: share text-only and files (QR capture path).

Rollback
- Revert `pubspec.yaml` bump and restore static `Share.*` calls.

Notes
- A spike showed instance API signatures differ in current env; this PR will pin a version exposing the expected instance API, or document constraints if we must stay on static API for now.
