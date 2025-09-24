# Repository Guidelines

This document provides concise, practical conventions for contributing to the **Jive Flutter–Rust** mono‑repo. Follow it to keep changes predictable and easy to review.

## Project Structure & Modules
Top-level key directories:
- `jive-core/` Rust core (domain, application, infrastructure, optional WASM)
- `jive-api/` Rust API + DB migrations under `migrations/`
- `jive-flutter/` Flutter client (web & mobile)
- `database/` SQL schema & reference scripts
- `Makefile` Unified developer commands; `start.sh` orchestration script
Rust layering (`jive-core/src`): `domain/` (entities, value objects) → `application/` (services, orchestration) → `infrastructure/` (adapters). Place new business rules in `domain`, cross‑aggregate workflows in `application`.

## Build, Run & Test
Primary commands (see `Makefile`):
- `make install` Install Rust & Flutter deps
- `make dev` Hot reload (backend + Flutter) where supported
- `make start` / `make stop` Launch or stop all services
- `make api-dev` Full API with relaxed CORS (`CORS_DEV=1` all origins/headers) for frontend debugging
- `make api-safe` Full API with whitelist + explicit headers (default secure mode)
- `make test` Run Rust + Flutter test suites
- `make build` Release build (Rust `--release` + `flutter build web`)
- `make format` / `make lint` Auto‑format & static analysis

CI required checks (main):
- `Flutter Tests`, `Rust API Tests`
- `Rust API Clippy (blocking)` (`-D warnings`)
- `Rustfmt Check` (blocking)
- `Cargo Deny Check`

SQLx offline policy:
- API jobs validate `.sqlx` strictly; on mismatch:
  - Uploads `api-sqlx-diff` artifact (old/new cache + patch)
  - Adds PR comment with first 80 lines of diff when PR originates from same repo
  - Fails the job to force cache refresh commit

Local helpers:
- `make api-lint` runs strict SQLx check + clippy
- `make api-sqlx-prepare-local` migrates DB (DB_PORT=5433) and refreshes `.sqlx`
- `make hooks` configures pre-commit hook to run `make api-lint`
- `make docker-up` / `make docker-down` Run via Docker Compose
Backend only: `cargo test -p jive-core`; Flutter only: `cd jive-flutter && flutter test`.

### CSV export feature gating
- API supports two CSV paths in `jive-api/src/handlers/transactions.rs`:
  - With feature `core_export`: delegates to `jive-core` `ExportService::generate_csv_simple`.
  - Without `core_export`: uses a local, safe CSV writer.
- Enabling `core_export` also activates `jive-core/db` (CSV helpers) via `jive-api/Cargo.toml`.

### SQLx Offline Metadata (Rust server+db tier)
- Goal: Verify SQL queries without depending on a live DB at compile time.
- CI flow (already enabled):
  1) Start PostgreSQL (health-checked) on 5432.
  2) Run migrations under `jive-api/migrations/`.
  3) Prepare SQLx metadata for `jive-core` server+db tier:
     - `cd jive-core && SQLX_OFFLINE=false cargo sqlx prepare -- --features "server,db"`
  4) Offline check server+db tier:
     - `SQLX_OFFLINE=true cargo check --features "server,db"`

- Local workflow tips:
  - If you change SQL or migrations, regenerate `.sqlx` locally using the same prepare command above.
  - Keep `.sqlx/` up to date in PRs to avoid CI drift; you may commit the updated files or let CI upload as artifacts (team preference).
  - If offline check fails with “no cached data for this query”, re-run the prepare step against a DB that has the latest migrations applied.

### Feature Tiers (Rust core)
- `default`: platform-agnostic core (no DB).
- `server`: runtime only; avoid DB-bound code.
- `server,db`: enables DB-related logic and queries; requires `.sqlx` metadata or online prepare.
- In-progress application modules may be gated behind features; avoid pulling unfinished modules into `default/server` builds.

Manager script shortcuts (`jive-manager.sh`):
- `./jive-manager.sh start all` secure full stack (DB/Redis/API/Web)
- `./jive-manager.sh start all-dev` full stack with relaxed CORS (API sets `CORS_DEV=1`)
- `./jive-manager.sh start api-dev` API only relaxed
- `./jive-manager.sh status` service status
- Status output shows API mode: `开发宽松` (CORS_DEV=1) vs `安全` (whitelist). Switch via `restart all-dev` or `restart all`.
- Mode switching shortcuts:
  - `./jive-manager.sh mode dev` switch/start API relaxed
  - `./jive-manager.sh mode safe` switch/start API secure

## Coding Style & Naming
Rust: Edition 2021, follow `rustfmt` (`make format`). Modules: `snake_case`; types: `PascalCase`; functions/fields: `snake_case`; constants: `SCREAMING_SNAKE_CASE`. Keep services cohesive: one responsibility per `*_service.rs` file. Avoid long parameter lists: introduce config structs.
Dart/Flutter: Follow `analysis_options.yaml` (Flutter lints). Widgets: `PascalCase`; files: `snake_case.dart`. Prefer `const` constructors. Keep widget build methods <150 lines; extract sub‑widgets.
General: Prefer explicit over implicit; avoid duplicating domain logic in the UI—call into Rust core or API.

## Testing Guidelines
Rust integration tests live in `jive-core/tests/` (async workflows). Add focused unit tests near code (`#[cfg(test)]` modules) for pure domain logic. Name tests `test_<behavior>()`. For new APIs: add scenario coverage (happy path + one failure). Flutter: write widget/state tests for providers; keep test file name `<target>_test.dart` in `test/` (create if absent). Aim to keep new feature PRs ≥70% coverage for added lines (informal target—justify exceptions in PR description).

## Commit & PR Guidelines
Commits: Present tense, imperative mood. Format: `<area>: <concise action>` (e.g. `core: add budget recurrence validation`). Group refactors separate from behavior changes. One logical change per commit when feasible.
PRs must include:
1. Purpose / problem statement
2. Summary of approach (mention affected layers)
3. Testing evidence (`make test` output snippet or screenshots for UI)
4. Migration notes (if touching `migrations/` or schema)
5. Rollback plan if risky
Link related issue IDs. Request review from a Rust + a Flutter reviewer for cross‑layer changes.

### Git Hooks
- Local pre-commit hook provided at `.githooks/pre-commit` runs `make api-lint` to enforce SQLx offline checks and Clippy.
- Enable hooks once per clone:
  - `git config core.hooksPath .githooks`
  - Then commit as usual; the hook will run automatically.

## Security & Configuration
Never commit real secrets—use `.env.example` for new vars. Run `make check` before pushing (ensures ports & env). Validate input at service boundary (API layer) and keep domain invariants enforced in constructors or smart methods. Log sensitive data only in anonymized form.

### CSV Export
- Transactions CSV endpoints accept `include_header` to control header row output.
  - POST `/api/v1/transactions/export` body: `{ "format":"csv", ..., "include_header": true|false }`
  - GET  `/api/v1/transactions/export.csv?include_header=true|false`
- Defaults to `true`. Clients can pass `include_header=false` for programmatic appends.

### CORS Modes
- Development: `make api-dev` (sets `CORS_DEV=1`) allows any origin/headers for rapid iteration.
- Secure: `make api-safe` enforces origin whitelist & explicit header list. Add new custom headers in `middleware/cors.rs`.

## Architecture Notes
Rust core is platform‑agnostic; API crate owns persistence & external IO. Flutter should treat the core/API as the single source of truth. Favor thin adapters over duplicating logic. When adding a feature, update corresponding design/status docs if impacted.

### Ports & Environments
- Local dev via Docker or manager scripts typically maps PostgreSQL to host 5433.
- CI and container-internal services use 5432.
- Migration helper script `jive-api/scripts/migrate_local.sh` auto-detects across 5433/5432; prefer 5433 locally, keep CI on 5432.

#### Port Overrides (Examples)
- Defaults: `DB_PORT=5433`, `API_PORT=8012` for local dev.
- Override per command:
  - `DB_PORT=5432 API_PORT=18012 ./jive-api/start-api.sh`
  - `DB_PORT=5432 make db-migrate`
- Environment-wide overrides in your shell profile if you always use a custom mapping.

#### API Developer Shortcuts
- `make api-sqlx-check` strict SQLx offline validation (requires up-to-date `.sqlx`).
- `make sqlx-prepare-api` generate `.sqlx` metadata (DB + migrations must be ready).
- `make api-clippy` run clippy with `SQLX_OFFLINE=true` and deny warnings locally.
- `make api-lint` runs both SQLx check and clippy for a quick pre-commit gate.

## Agent-Specific Instructions
When modifying files, respect this guide’s layering rules. Large automated refactors (format only) should be isolated. Do not adjust unrelated modules while implementing a focused change unless build breaks.

---
Questions or ambiguities: open a draft PR early for alignment.
