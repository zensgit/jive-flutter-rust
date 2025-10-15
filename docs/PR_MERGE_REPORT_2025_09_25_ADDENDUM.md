## PR Merge Report Addendum (2025-09-25)

This addendum corrects and extends the original `PR_MERGE_REPORT_2025_09_25.md`.

### 1. Correction: Default Ledger Unique Index

Original report showed an example:
```sql
CREATE UNIQUE INDEX idx_family_ledgers_default_unique ON family_ledgers (family_id) WHERE is_default = true;
```

Actual merged migration (028):
```sql
-- File: jive-api/migrations/028_add_unique_default_ledger_index.sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_ledgers_one_default
    ON ledgers(family_id)
    WHERE is_default = true;
```

Key differences:
- Table name is `ledgers` (not `family_ledgers`).
- Index name: `idx_ledgers_one_default`.
- Uses `IF NOT EXISTS` to remain idempotent.

### 2. Streaming Export Feature Flag

- New cargo feature: `export_stream` (disabled by default).
- Enables incremental CSV response for `GET /api/v1/transactions/export.csv`.
- Activation example:
  ```bash
  cd jive-api
  cargo run --features export_stream --bin jive-api
  ```
- Fallback: Without the feature the endpoint buffers entire CSV in memory.

### 3. JWT Secret Management

Changes recap:
- Hardcoded secret removed; now resolved via environment variable `JWT_SECRET`.
- Dev/test fallback: `insecure-dev-jwt-secret-change-me` (warning logged unless tests).
- Production requirement: non-empty, high entropy (≥32 bytes random) value.

### 4. Added Negative & Integrity Tests

| Test File | Purpose |
|-----------|---------|
| `auth_login_negative_test.rs` | Wrong bcrypt password → 401; inactive user refresh → 403 |
| `family_default_ledger_test.rs` | Ensures only one default ledger; duplicate insert fails (migration enforced) |

### 5. Recommended Follow-up Benchmark

Suggested script (added separately) seeds N transactions and measures export latency for buffered vs streaming modes.

### 6. Production Preflight (See `PRODUCTION_PREFLIGHT_CHECKLIST.md`)

- One default ledger per family (query check)
- No bcrypt hashes remaining (or plan opportunistic rehash)
- `JWT_SECRET` set & not fallback
- Migrations up to 028 applied
- Optional: streaming feature withheld until benchmarks accepted

---
Status: All corrections applied. No further action required for already merged PRs.

