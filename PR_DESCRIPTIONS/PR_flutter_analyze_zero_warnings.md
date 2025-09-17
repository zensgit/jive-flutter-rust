Title: CI: Enforce SQLx cache validation; Flutter: Analyzer zero warnings (print→debugPrint)

Summary
- Enforces strict SQLx offline cache validation in CI (no generation in CI, check-only).
- Tightens Flutter analyzer to fail on warnings and errors (`--fatal-warnings`).
- Replaces `print` with `debugPrint` across Flutter code to satisfy `avoid_print` and reduce noisy logs.
- Fixes field-compare workflow to correctly download analyzer artifact before re-upload.

Changes
- .github/workflows/ci.yml
  - Rust job: switch to check-only SQLx offline cache with `SQLX_OFFLINE=true cargo sqlx prepare --check`.
  - Remove runtime cache generation in CI.
  - Flutter job: use `flutter analyze --fatal-warnings` and tee output to artifact.
  - Field-compare: download `flutter-analyze-output` artifact before upload.
- jive-flutter/* (multiple files)
  - Replace `print(...)` with `debugPrint(...)` and add `import 'package:flutter/foundation.dart';` where needed.
- .gitignore
  - Allow tracking `jive-api/.sqlx` directory (committed offline cache).
- jive-api/docs/SQLX_OFFLINE.md
  - Add instructions on generating and committing SQLx offline cache.
- jive-api/.sqlx/.gitkeep
  - Placeholder to enable committing the cache directory.

Motivation
- Ensure CI reproducibility: SQLx offline cache is the contract; schema/query changes must update cache.
- Improve signal in CI: any analyzer warnings or SQLx cache drift turns CI red immediately.
- Reduce console noise and avoid `avoid_print` lint by using `debugPrint`.

Risk / Rollout
- SQLx cache must be generated and committed by developers when queries/migrations change.
- Flutter analyze will fail on warnings; teams should run `flutter analyze` locally before pushing.

Test Plan
- Local
  - Start DB: `docker compose -f jive-api/docker-compose.db.yml up -d postgres`.
  - Prepare SQLx cache: `(cd jive-api && ./prepare-sqlx.sh)`; commit resulting `.sqlx`.
  - Flutter: `(cd jive-flutter && flutter pub get && flutter analyze)` → zero warnings.
- CI
  - Rust job passes with `SQLX_OFFLINE=true` and check-only validation.
  - Flutter job fails if any warnings; currently green after print→debugPrint cleanup.
  - Field-compare step stable due to artifact fix.

Notes
- Generated code (freezed/*.g.dart) may carry `ignore` comments; these are acceptable.
- If additional lints appear, prefer code fixes over global suppression.

