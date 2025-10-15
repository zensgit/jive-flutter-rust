## PR Security & Metrics Summary (Template)

### Overview
This PR strengthens API security and observability. Copy & adapt sections below for the final PR description.

### Key Changes
- Login rate limiting (IP + email key) with structured 429 JSON and `Retry-After` header.
- Metrics endpoint CIDR allow + deny lists (`ALLOW_PUBLIC_METRICS=0`, `METRICS_ALLOW_CIDRS`, `METRICS_DENY_CIDRS`).
- Password rehash failure breakdown: `jive_password_rehash_fail_breakdown_total{cause="hash"|"update"}`.
- Export performance histograms (buffered & streaming) and uptime metric.
- New security / monitoring docs: Grafana dashboard, alert rules, security checklist.
- Email-based rate limit key hashing (first 8 hex of SHA256) for privacy.

### New / Modified Environment Variables
| Variable | Purpose | Default |
|----------|---------|---------|
| `AUTH_RATE_LIMIT` | Login attempts per window (N/SECONDS) | `30/60` |
| `AUTH_RATE_LIMIT_HASH_EMAIL` | Hash email in key (privacy) | `1` |
| `ALLOW_PUBLIC_METRICS` | If `0`, restrict metrics by CIDR | `1` |
| `METRICS_ALLOW_CIDRS` | Comma CIDR whitelist | `127.0.0.1/32` |
| `METRICS_DENY_CIDRS` | Comma CIDR deny (priority) | (empty) |
| `METRICS_CACHE_TTL` | Metrics base cache seconds | `30` |

### Prometheus Metrics Added
| Metric | Type | Notes |
|--------|------|-------|
| `auth_login_rate_limited_total` | counter | Rate-limited login attempts |
| `jive_password_rehash_fail_breakdown_total{cause}` | counter | Split hash/update failures |
| `export_duration_buffered_seconds_*` | histogram | Export latency (buffered) |
| `export_duration_stream_seconds_*` | histogram | Export latency (stream) |
| `process_uptime_seconds` | gauge | Runtime age |

Deprecated (pending removal): `jive_password_rehash_fail_total` (aggregate).

### Quick Local Verification
Run stack (example):
```bash
ALLOW_PUBLIC_METRICS=1 AUTH_RATE_LIMIT=3/60 cargo run --bin jive-api &
sleep 2
./scripts/verify_observability.sh
```

Expect PASS output and non-zero counters for `auth_login_fail_total` after simulated attempts.

### Reviewer Checklist
- [ ] 429 login response includes `Retry-After` and JSON structure
- [ ] `/metrics` reachable only when expected (toggle ALLOW_PUBLIC_METRICS)
- [ ] Rehash breakdown metrics appear
- [ ] Export histogram buckets present
- [ ] Uptime metric increasing across scrapes
- [ ] Security checklist file present (`docs/SECURITY_CHECKLIST.md`)

### Follow-up (Optional / Tracked)
- Audit logging for repeated rate-limit triggers
- Global unified error response model
- Redis/distributed rate limiting for multi-instance scaling
- Remove deprecated rehash aggregate metric (target v1.3.0)

