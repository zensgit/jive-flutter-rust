#!/usr/bin/env bash
set -euo pipefail

# One-shot helper: apply DB migrations locally and restart services
# Usage:
#   scripts/migrate_and_restart.sh [--db-url postgresql://user:pass@host:port/db]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DB_URL_ARG=""
if [[ "${1:-}" == "--db-url" && -n "${2:-}" ]]; then
  DB_URL_ARG="$2"
  export DATABASE_URL="$DB_URL_ARG"
  shift 2
fi

# Prefer Docker Postgres (dev) on localhost:5433 when no DATABASE_URL provided
if [[ -z "${DATABASE_URL:-}" ]]; then
  export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_money"
  echo "Using default Docker DB: $DATABASE_URL"
fi

echo "==> Running local DB migrations"
chmod +x "$ROOT_DIR/jive-api/scripts/migrate_local.sh"
"$ROOT_DIR/jive-api/scripts/migrate_local.sh" --db-url "$DATABASE_URL"

echo "==> Restarting API + Web services"
chmod +x "$ROOT_DIR/start-services.sh"
"$ROOT_DIR/start-services.sh" --rebuild

echo "==> Done. Visit http://localhost:3021"
