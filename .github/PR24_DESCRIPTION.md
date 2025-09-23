# PR: API CSV gating + currency fixes + SQLx diff artifact

## 1) Purpose
- Fix API compile errors spotted in CI (Option handling in currency modules).
- Gate CSV streaming export under `core_export` the same way as POST export, avoiding missing-local-helper errors when core path is active.
- Improve CI debuggability by uploading SQLx offline cache diff on prepare --check failure.

## 2) Approach
- Handlers
  - `jive-api/src/handlers/transactions.rs`: Stream CSV path now mirrors POST path.
    - `core_export` ON → `jive-core` `ExportService::generate_csv_simple`.
    - `core_export` OFF → local safe CSV writer (`csv_escape_cell`).
- Currency modules
  - `jive-api/src/services/currency_service.rs`: `base_currency` uses Option fallback; fixed `effective_date`/`created_at` mapping for history rows.
  - `jive-api/src/handlers/currency_handler_enhanced.rs`: handle optional `created_at` before `.naive_utc()`.
- CI
  - `.github/workflows/ci.yml`: on SQLx prepare --check failure, regenerate cache to a temp location, produce diff patch and tarballs, upload artifact `api-sqlx-diff`, then fail the job (remains strict).
- Docs/Tools
  - `AGENTS.md`: added “CSV export feature gating” notes.
  - `Makefile`: added `hooks` target to enable pre-commit (`make api-lint`).

## 3) Affected layers
- API only, plus CI workflow. No schema changes.

## 4) Testing evidence
- Local: `make api-lint` reaches SQLx check; build succeeds until cache check (expected to fail if `.sqlx` stale). Currency compile errors reproduced by CI are resolved locally.
- Feature note: we intentionally keep CI without `core_export` to avoid pulling unfinished `jive-core/db` modules.

## 5) Migration notes
- None. No changes under `migrations/`.

## 6) Rollback plan
- Revert this PR. No data migrations to undo.

## 7) Follow-ups
- If CI uploads `api-sqlx-diff`, apply the patch to `.sqlx/` and re-run.
- After 1–2 green runs, flip Rust API clippy to blocking (`-D warnings`).
- Consider later decoupling CSV generation in `jive-core` from `db` feature so `core_export` can be enabled in CI without DB modules.

---
Checklist
- [ ] CI run completed and artifacts reviewed
- [ ] Apply `api-sqlx-diff` if present, re-run CI
- [ ] Switch clippy to blocking after observation window
- [ ] Enable pre-commit locally: `make hooks`
