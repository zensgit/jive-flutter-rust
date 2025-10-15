# jive-core Server+DB Roadmap (Track)

Goal: Bring `jive-core` server,db features to a compilable and CI-checkable state without impacting mainline CI.

Phases

1) Schema Alignment (blocking)
- Accounts table: add/confirm `family_id` column contract or adapt repositories to current API schema.
- Create `entries` table or adapt transaction repositories to API schema (naming/columns).
- Normalize integer types: prefer `i32` over `u32` at DB boundaries.

2) Repository Completeness
- Implement missing repositories:
  - `src/infrastructure/repositories/user_repository.rs`
  - `src/infrastructure/repositories/balance_repository.rs`
- Replace remaining `sqlx::query!`/`query_as!` macros in repositories with runtime `sqlx::query` + `Row::try_get` (or add `.sqlx` metadata and keep macros).

3) SQLx Metadata Path (choose one per module)
- A: Runtime queries (no `.sqlx` maintenance; consistent with API approach), or
- B: Prepare `.sqlx` with live DB in CI, then enable offline checks for core.

4) CI (non-blocking job)
- New workflow that:
  - Boots PostgreSQL and runs API migrations
  - Prepares core `.sqlx` (if path B) or does runtime-check only (path A)
  - Runs `SQLX_OFFLINE=true cargo check --features "server,db"`
  - Marked non-blocking (separate workflow)

5) Incremental Rehab
- Tackle repositories in order of surface area: accounts -> transactions -> users -> balances.
- Land small, focused PRs with test shards (unit tests where possible).

Status Tracker
- [ ] Accounts repository (runtime SQLx complete)
- [ ] Transactions repository (runtime SQLx or `.sqlx`)
- [ ] User repository implemented
- [ ] Balance repository implemented
- [ ] CI workflow added (dispatchable)
- [ ] First green run on branch

Notes
- Keep features gated: do not expose unfinished modules on default/server builds.
- Follow existing API migrations to avoid dual schema drift.
