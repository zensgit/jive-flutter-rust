Title: PR2 Addendum – Migration notes and minimal tests

Scope
- Document migration behavior (020/021/022) and add minimal integration tests for uniqueness and position backfill.

Migration behavior
- 020_adjust_templates_schema.sql: additive columns and indexes on system_category_templates; idempotent updates and default version backfill.
- 021_extend_categories_for_user_features.sql: additive columns on categories; partial unique index uq_categories_ledger_name_ci (is_deleted=false); parent/position/usage indexes.
- 022_backfill_categories.sql: sets defaults (usage_count/is_deleted/source_type/template_version) and assigns dense positions per (ledger_id,parent_id); adds composite index (ledger_id,parent_id,position).

Rollback
- All three are additive/idempotent; rollback not required for schema safety. If needed, disable API routes to avoid using new fields.

Tests
- tests/integration/category_min_api_test.rs covers:
  - unique index enforces case-insensitive name uniqueness for active rows; allows reuse after soft delete.
  - backfill positions produce dense 0..N-1 ordering.

CI
- Run cargo test -p jive-api --tests or workspace default.
- Ensure database is available for integration tests (CI matrix provides Postgres service).

