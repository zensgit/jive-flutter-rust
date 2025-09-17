Title: Session Notes — Category Template Import, Preview, and CI updates
Date: 2025-09-17
Owner: @hua, Assistant

Overview
- Continued work on stabilizing CI and implementing the category template import flow from server templates to user categories, including UI enhancements and backend batch import.

What We Added Today
- Backend
  - POST /api/v1/categories/import: batch import from system templates with per-item overrides (name/color/icon/classification/parent_id) and conflict strategies (skip|rename|update).
  - Returns detailed per-item actions (imported/updated/renamed/skipped/failed) with reasons.
  - Added dry_run flag support for future use to preview without DB writes.
- Frontend (Flutter)
  - Category Management: added “Template Library” dialog with:
    - Search, classification/group filters, featured-only toggle.
    - Per-item overrides (name/color/icon/parent category).
    - Conflict strategy selection and preview screen with predicted actions.
    - Calls advanced import API and refreshes categories post import.
  - Converted many print(...) to debugPrint(...) to satisfy analyzer and CI.
  - Added a widget test for base currency selection.
- CI/Docs/Tools
  - CI now validates committed SQLx cache only (no generation in CI).
  - Added scripts/ci_local.sh to run local CI (DB, SQLx check, Rust/Flutter checks) without consuming Actions minutes.
  - README: documented local CI usage and SQLx strict policy.
  - Docs: SQLX_OFFLINE.md and PR description for “Flutter Analyze Zero Warnings”.

Open Items / Next
- Frontend: Show backend import details in a bottom sheet after import (copy/export JSON), and support true dry-run once backend enriches details.
- Backend: Enhance dry_run to return predicted rename target and existing category summary; add integration tests for skip/rename/update and overrides.
- Performance: Add pagination/ETag support to template listing; consider virtual scrolling in dialog.
- Advanced Category features: delete-with-reassign, merge, convert-to-tag, batch recategorize + revert (category_batch_operations).
- Analyzer: staged cleanup of warnings via flutter fix + targeted refactors.

Local Commands
- Local CI: chmod +x scripts/ci_local.sh && ./scripts/ci_local.sh
- Generate SQLx cache: (cd jive-api && ./prepare-sqlx.sh) then commit jive-api/.sqlx

