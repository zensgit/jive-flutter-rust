#!/usr/bin/env bash
set -euo pipefail

# Reset a Postgres database schema and re-apply migrations.
# Usage:
#   DATABASE_URL=postgresql://user:pass@localhost:5432/jive_money ./scripts/reset-db.sh
# or
#   TEST_DATABASE_URL=... ./scripts/reset-db.sh

DB_URL="${DATABASE_URL:-${TEST_DATABASE_URL:-}}"
if [[ -z "${DB_URL}" ]]; then
  echo "Error: set DATABASE_URL or TEST_DATABASE_URL" >&2
  exit 1
fi

echo "==> Resetting schema on ${DB_URL}"
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null

echo "==> Re-applying migrations"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DATABASE_URL="$DB_URL" "${ROOT_DIR}/scripts/migrate_local.sh" --force

echo "==> Done"

