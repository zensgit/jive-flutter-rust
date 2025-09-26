# Metrics Deprecation Plan

This document tracks deprecation and removal timelines for legacy metrics exposed by the API.

## Principles
- Provide at least two released versions of overlap before removal.
- Never silently change a metric's semantic meaning; prefer adding a new metric.
- Document target removal version and migration path here + README.

## Deprecated Metrics
| Metric | Status | Replacement | First Deprecated | Target Removal | Notes |
|--------|--------|-------------|------------------|----------------|-------|
| `jive_password_hash_users` (labels: bcrypt_2a,bcrypt_2b,bcrypt_2y,argon2id) | Deprecated | `password_hash_bcrypt_variant`, `password_hash_bcrypt_total`, `password_hash_argon2id_total` | v1.0.0 | v1.2.0 | Keep until majority dashboards migrated |
| `jive_password_rehash_fail_total` | Deprecated (aggregate) | `jive_password_rehash_fail_breakdown_total{cause}` | v1.0.X | v1.3.0 | Remove once dashboards use breakdown |

## Active Canonical Metrics (Password Hash & Auth)
- `password_hash_bcrypt_total`
- `password_hash_argon2id_total`
- `password_hash_unknown_total`
- `password_hash_total_count`
- `password_hash_bcrypt_variant{variant="2a"|"2b"|"2y"}`
- `jive_password_rehash_total`
- `jive_password_rehash_fail_total`
- `auth_login_fail_total`
- `auth_login_inactive_total`

## Export Metrics
- `export_requests_buffered_total`
- `export_requests_stream_total`
- `export_rows_buffered_total`
- `export_rows_stream_total`
- `export_duration_buffered_seconds_*` (histogram buckets/sum/count)
- `export_duration_stream_seconds_*` (histogram buckets/sum/count)

## Build / Operational
- `jive_build_info{commit,time,rustc,version}` (value always 1)
- `process_uptime_seconds`

## Future Candidates
| Proposed | Description | Status |
|----------|-------------|--------|
| `auth_login_fail_total` | Count failed login attempts (unauthorized) | Planned |
| `export_duration_seconds` (histogram) | Latency of export operations | Planned |
| `process_uptime_seconds` | Seconds since process start | Implemented |

## Removal Procedure
1. Mark metric here and in README as DEPRECATED with target version.
2. Announce in release notes for two consecutive releases.
3. After reaching target version, remove metric exposition code; update this file.
4. Provide simple one-shot conversion guidance for dashboards.

## Changelog
- v1.0.0: Introduced canonical password hash metrics + export metrics; deprecated legacy `jive_password_hash_users`.
- v1.0.X: Added login fail/inactive counters; export duration histograms; uptime gauge.
