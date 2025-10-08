# Flutter: Migrate Share to SharePlus (Draft Plan)

Purpose
- Replace deprecated `Share`/`shareXFiles` usages with `share_plus` equivalents.
- Reduce analyzer `deprecated_member_use` noise without changing functionality.

Scope (initial)
- Files referencing `Share` or `shareXFiles` inside `lib/widgets/qr_code_generator.dart` and related helpers.
- Avoid broad refactors; migrate minimal surface to keep PR focused and low-risk.

API Mapping
- `Share.shareXFiles(List<XFile> files, ...)` -> `Share.shareXFiles(files, ...)` via `share_plus` (non-deprecated); or `Share.share(...)` depending on context.
- Prefer `Share.shareXFiles` for binary/image payloads; `Share.share` for text-only sharing.
- Ensure `XFile` inputs are correctly typed and platform-safe.

Validation
- Run `flutter analyze` to confirm `deprecated_member_use` removed for migrated sites.
- Run `flutter test` (10/10 passing baseline) to verify no regressions.
- Manual smoke test on share entry points (if feasible in CI/emulator) to confirm intent sheet opens.

Risks & Mitigations
- Platform-specific behavior differences: keep payloads and mime types identical; test on web/desktop if used.
- Dependency constraints: ensure `share_plus` version compatible with current Flutter SDK.

Rollout Plan
- Phase 1 (this PR): migrate `qr_code_generator.dart` share calls only; keep signatures intact.
- Phase 2: migrate remaining share call sites, one widget/module at a time, with tests.

Notes
- This PR is documentation-only draft to align on approach. Code migration will come in follow-up PR(s).
