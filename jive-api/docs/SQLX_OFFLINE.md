SQLx Offline Cache (Committed)

Overview
- This project commits the SQLx offline cache (`jive-api/.sqlx`) to ensure reproducible, fully offline builds in CI and locally.

When to Update
- Any time you change queries or migrations that affect SQL shape.

How to Update
1) Ensure Postgres is running locally. You can use the provided docker-compose:
   - `docker compose -f jive-api/docker-compose.db.yml up -d postgres`
2) Run migrations and prepare cache:
   - `cd jive-api && ./prepare-sqlx.sh`
3) Verify cache files exist:
   - `ls .sqlx/*.json`
4) Commit changes:
   - `git add jive-api/.sqlx && git commit -m "chore(sqlx): update offline cache"`

CI Behavior
- CI uses SQLX_OFFLINE=true and validates with `cargo sqlx prepare --check`.
- If cache is stale, CI fails, prompting a refresh.

Notes
- Keep your local DATABASE_URL pointing to the same schema as CI when generating cache.
- If you lack a DB locally, use the docker service above or a remote Postgres.
