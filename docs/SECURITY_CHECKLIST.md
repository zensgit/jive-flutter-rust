## Production Security Checklist

1. Secrets
   - Set strong `JWT_SECRET` (>=32 random bytes). Never use dev default.
2. Metrics Exposure
   - `ALLOW_PUBLIC_METRICS=0`
   - Restrict `METRICS_ALLOW_CIDRS` to monitoring network.
3. Rate Limiting
   - Tune `AUTH_RATE_LIMIT` (e.g. 20/60 or 50/300 based on traffic).
   - Keep `AUTH_RATE_LIMIT_HASH_EMAIL=1` to avoid leaking raw emails in memory keys.
4. TLS / Reverse Proxy
   - Terminate TLS at trusted proxy; strip untrusted `X-Forwarded-For`.
5. Logging
   - Ensure logs exclude plaintext passwords/tokens.
   - Monitor `auth_login_rate_limited_total` + `auth_login_fail_total` anomalies.
6. Password Migration
   - Track reduction of bcrypt via `password_hash_bcrypt_total` trend.
   - Investigate any spike in `jive_password_rehash_fail_breakdown_total{cause}`.
7. Export Controls
   - Consider pagination/stream for large exports; watch P95 latency panels.
8. Dependency Hygiene
   - Run `cargo deny` (already in CI) before release.
9. Database
   - Use least-privilege DB role for API.
10. Incident Response
   - Create alerts using `docs/ALERT_RULES_EXAMPLE.yaml` as baseline.

