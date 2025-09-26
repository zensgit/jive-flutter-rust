# Production Preflight Checklist

Use this list before promoting a build to production.

## 1. Configuration
- [ ] `JWT_SECRET` set (>=32 random bytes, not placeholder)
- [ ] Database URL / credentials use production secrets (no local `.env` leakage)
- [ ] `RUST_LOG` level appropriate (no `debug` in prod unless temporarily troubleshooting)

## 2. Database & Migrations
- [ ] All migrations applied up to latest (028 unique default ledger index)
- [ ] No duplicate default ledgers:
  ```sql
  SELECT family_id, COUNT(*) FILTER (WHERE is_default) AS defaults
  FROM ledgers GROUP BY family_id HAVING COUNT(*) FILTER (WHERE is_default) > 1;
  ```
- [ ] (Optional) Pending rehash plan for bcrypt users:
  ```sql
  SELECT COUNT(*) FROM users WHERE password_hash LIKE '$2%';
  ```

## 3. Security
- [ ] Superadmin password rotated from baseline (not `admin123` / `SuperAdmin@123`)
- [ ] No hardcoded tokens or secrets committed
- [ ] HTTPS termination configured (proxy / ingress)

## 4. Logging & Monitoring
- [ ] Sensitive data not logged (spot-check recent logs) 
- [ ] Health endpoint returns `status=healthy`
- [ ] Alerting / log retention configured (if applicable)

## 5. Features & Flags
- [ ] `export_stream` feature decision documented (enabled or deferred)
- [ ] `core_export` feature aligns with export requirements

## 6. Performance (Optional but Recommended)
- [ ] Benchmark run with expected production dataset size (see `scripts/benchmark_export_streaming.rs`)
- [ ] Latency and memory within targets

## 7. CI / CD
- [ ] Required checks enforced on protected branches
- [ ] Cargo Deny passes (no newly introduced high-severity advisories)

## 8. Backup & Recovery
- [ ] Automated DB backups configured & tested restore path
- [ ] Rollback plan documented for latest migrations

## 9. Documentation
- [ ] README environment section up to date
- [ ] Addendum report corrections merged (`PR_MERGE_REPORT_2025_09_25_ADDENDUM.md`)

## 10. Final Sanity
- [ ] Smoke test: register → login → create family → create transaction → export CSV
- [ ] Error rate in logs acceptable (< agreed threshold)

---
Status: Template ready for team adoption.

