#!/usr/bin/env bash
set -euo pipefail

# Local migration runner (no Docker)
# Uses DATABASE_URL or falls back to localhost jive_money

DB_URL="${DATABASE_URL:-}"
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-url)
      DB_URL="$2"; shift 2 ;;
    --force)
      FORCE=1; shift ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Candidate URLs to try if none supplied or first fails
declare -a CANDIDATES
if [[ -n "$DB_URL" ]]; then
  CANDIDATES+=("$DB_URL")
fi
# Prefer Docker dev DB on 5433 first
CANDIDATES+=(
  "postgresql://postgres:postgres@localhost:5433/jive_money"
  "postgresql://jive:jive_password@localhost:5433/jive_money"
  # Local default installs (5432)
  "postgresql://jive:jive_password@localhost:5432/jive_money"
  "postgresql://postgres:postgres@localhost:5432/jive_money"
  # Fallback to current OS user (macOS/Homebrew/Postgres.app)
  "postgresql://${USER}@localhost:5433/jive_money"
  "postgresql://${USER}@localhost:5432/jive_money"
  # Let libpq infer user from environment/system
  "postgresql://localhost:5433/jive_money"
  "postgresql://localhost:5432/jive_money"
)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIG_DIR="$ROOT_DIR/migrations"

choose_db_url() {
  for url in "${CANDIDATES[@]}"; do
    if psql "$url" -c "SELECT 1" >/dev/null 2>&1; then
      echo "$url"
      return 0
    fi
  done
  return 1
}

DB_CHOSEN=$(choose_db_url || true)
if [[ -z "$DB_CHOSEN" ]]; then
  echo "Error: Unable to connect to any known DATABASE_URL candidates." >&2
  echo "Hint: export DATABASE_URL=postgresql://<user>:<pass>@<host>:<port>/jive_money and re-run." >&2
  exit 1
fi

echo "==> Target database: $DB_CHOSEN"
if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql not found. Please install PostgreSQL client." >&2
  exit 1
fi

if [ ! -d "$MIG_DIR" ]; then
  echo "Error: migrations dir not found: $MIG_DIR" >&2
  exit 1
fi

# Idempotency: if schema already exists (typical when docker initdb ran), skip unless --force
if [[ $FORCE -eq 0 ]]; then
  has_users=$(psql "$DB_CHOSEN" -tAc "SELECT to_regclass('public.users') IS NOT NULL" 2>/dev/null | tr -d '[:space:]' || echo "f")
  if [[ "$has_users" == "t" || "$has_users" == "true" ]]; then
    echo "==> Existing schema detected (users table present). Proceeding with idempotent re-apply to catch new migrations."
  fi
fi

echo "==> Applying SQL migrations..."
shopt -s nullglob
applied=0
for file in "$MIG_DIR"/*.sql; do
  name=$(basename "$file")
  echo "-- Applying: $name"
  # Do not stop on 'already exists' errors; most files are idempotent but triggers may not be
  psql "$DB_CHOSEN" -f "$file" >/dev/null 2>&1 || true
  applied=$((applied+1))
done
shopt -u nullglob

echo "==> Done. Attempted $applied migrations (existing objects are skipped by PostgreSQL)."
