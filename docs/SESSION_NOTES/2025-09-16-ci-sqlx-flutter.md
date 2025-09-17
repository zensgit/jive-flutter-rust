Title: Session Notes — CI stabilization (SQLx offline) and Flutter analyzer tightening
Date: 2025-09-16
Owner: @hua, Assistant

Overview
- Goal: Stabilize CI, fix login/currency issues, add Category/Tag UIs, align Category backend, and enforce consistent SQLx offline + Flutter analyzer policies.
- Result: CI passes with strict checks; PR2 merged; PR3 ready; CI tightened to fail on SQLx cache drift and Flutter warnings.

Key Outcomes
- SQLx: Adopt check-only in CI with committed offline cache (`jive-api/.sqlx`).
- Flutter: Analyzer runs with `--fatal-warnings`; replaced `print` with `debugPrint` across app.
- Field-compare: Workflow fixed to download analyzer artifact prior to reuse.

Files Added/Updated (high-level)
- .github/workflows/ci.yml — no generation of SQLx cache in CI; fatal Flutter analyzer; artifact fix.
- jive-api/docs/SQLX_OFFLINE.md — instructions for maintaining committed SQLx cache.
- jive-api/.sqlx/.gitkeep — enable cache dir versioning.
- PR_DESCRIPTIONS/PR_flutter_analyze_zero_warnings.md — ready-to-use PR description.
- Flutter print→debugPrint across multiple files (services, providers, screens, utils).

Current Status
- Backend (PR2) merged; login/currency fixes included in main.
- Frontend Category (PR3) is green and can be merged.
- Advanced Category features planned for PR4.

CI Strategy (finalized today)
- SQLx cache policy:
  - CI: Validate only — `SQLX_OFFLINE=true cargo sqlx prepare --check` must pass.
  - Dev flow: Generate cache locally after query/schema changes and commit `.sqlx`.
- Flutter analyzer:
  - Strict mode: `flutter analyze --fatal-warnings`.
  - Use `debugPrint` for diagnostics.

Local Commands (one-time to finalize cache)
1) Start DB
   docker compose -f jive-api/docker-compose.db.yml up -d postgres
2) Generate SQLx cache
   cd jive-api && ./prepare-sqlx.sh && cd ..
3) Commit cache
   git add jive-api/.sqlx && git commit -m "chore(sqlx): add offline cache" && git push

PR Steps
- Merge PR3 (Frontend Category)
  gh pr merge 3 --repo zensgit/jive-flutter-rust --merge
- Create new PR for CI + Flutter analyzer tightening and print cleanup
  Branch: pr/ci-flutter-analyze-zero-warnings
  Title: CI: Enforce SQLx cache validation; Flutter: Analyzer zero warnings (print→debugPrint)
  Body: PR_DESCRIPTIONS/PR_flutter_analyze_zero_warnings.md

Open TODOs / Next Session
- Generate and commit actual `.sqlx` cache (Owner: @hua)
- Merge PR3 (Owner: @hua)
- Open the CI+Flutter lint PR (Owner: @hua)
- Optional: Add Flutter widget test for base currency selection to prevent regressions (Owner: Assistant)
- Optional: Proceed with PR4 (Category advanced: delete with reassignment, merge + UI confirmations) after PR3

Quick Links
- CI Report: jive-api/CI_FINAL_SUCCESS_REPORT.md
- SQLx Guide: jive-api/docs/SQLX_OFFLINE.md
- PR Draft: PR_DESCRIPTIONS/PR_flutter_analyze_zero_warnings.md

Notes
- Generated code (freezed/*.g.dart) may include analyzer ignores; acceptable.
- If new warnings appear, prefer targeted fixes over global rule suppression.

