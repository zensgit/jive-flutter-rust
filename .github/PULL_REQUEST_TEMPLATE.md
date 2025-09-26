## PR Checklist

- [ ] SQLx offline cache up to date (`jive-api/.sqlx`)
- [ ] `make api-lint` passes locally (SQLx check + Clippy -D warnings)
- [ ] Tests relevant to this change pass locally
- [ ] Secrets not committed; new env vars documented in `.env.example`

## Purpose
Describe the problem and the high-level approach.

## Changes
- Files/areas touched and why
- Feature flags or conditional paths (if any)

## Testing
- Commands run and results
- Screenshots/logs (if UI/API visible behavior)

## Migration Notes (if any)
- DB migrations, data backfills, roll-forward/rollback steps

## Rollback Plan
- How to revert safely if issues arise
