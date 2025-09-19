#!/usr/bin/env bash
set -euo pipefail

# Local CI runner to mimic GitHub Actions without consuming minutes.
# Produces artifacts under ./local-artifacts

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ART_DIR="$ROOT_DIR/local-artifacts"
API_DIR="$ROOT_DIR/jive-api"
FLUTTER_DIR="$ROOT_DIR/jive-flutter"

mkdir -p "$ART_DIR"

log() { printf "\033[1;34m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[warn] %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m[err] %s\033[0m\n" "$*"; }

# 1) Start local services via Docker (Postgres, Redis)
log "Starting local Postgres/Redis (docker compose)"
if command -v docker >/dev/null 2>&1 && command -v docker compose >/dev/null 2>&1; then
  docker compose -f "$API_DIR/docker-compose.db.yml" up -d postgres redis || true
else
  warn "Docker or docker compose not found. Skipping service startup. Ensure Postgres/Redis are available."
fi

# 2) Prepare database and SQLx cache validation
export DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5433/jive_money}"
log "Checking DB connectivity: $DATABASE_URL"
if command -v psql >/dev/null 2>&1; then
  if ! psql "$DATABASE_URL" -c 'SELECT 1' >/dev/null 2>&1; then
    warn "Cannot connect to DB at $DATABASE_URL. Ensure DB is up or adjust DATABASE_URL."
  fi
else
  warn "psql not found; skipping connectivity check."
fi

log "Running migrations (idempotent)"
chmod +x "$API_DIR/scripts/migrate_local.sh"
"$API_DIR/scripts/migrate_local.sh" --force || true

log "Validating SQLx offline cache (check-only)"
pushd "$API_DIR" >/dev/null
  if ! command -v cargo >/dev/null 2>&1; then err "cargo not found"; exit 1; fi
  cargo install sqlx-cli --no-default-features --features postgres >/dev/null 2>&1 || true
  SQLX_OFFLINE=true cargo sqlx prepare --check | tee "$ART_DIR/sqlx-check.txt"
popd >/dev/null

# 3) Rust tests (offline mode)
log "Running Rust tests (SQLX_OFFLINE=true)"
pushd "$API_DIR" >/dev/null
  export SQLX_OFFLINE=true
  export TEST_DATABASE_URL="${TEST_DATABASE_URL:-$DATABASE_URL}"
  export REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
  export JWT_SECRET="${JWT_SECRET:-local_test_secret}"
  export API_PORT="${API_PORT:-8012}"
  cargo test --all-features -- --nocapture | tee "$ART_DIR/rust-tests.txt"
  cargo clippy --all-features -- -D warnings | tee "$ART_DIR/rust-clippy.txt"
popd >/dev/null

# 4) Flutter analyze and tests
if [ -d "$FLUTTER_DIR" ]; then
  if command -v flutter >/dev/null 2>&1; then
    log "Flutter pub get + build_runner"
    pushd "$FLUTTER_DIR" >/dev/null
      flutter pub get
      flutter pub run build_runner build --delete-conflicting-outputs || true
      log "Flutter analyze (non-fatal warnings)"
      set -o pipefail
      # Make analyze non-blocking for local CI; we record output then continue
      flutter analyze 2>&1 | tee "$ART_DIR/flutter-analyze.txt" || true
      log "Flutter tests"
      flutter test --coverage | tee "$ART_DIR/flutter-tests.txt" || true
    popd >/dev/null
  else
    warn "flutter not found; skipping Flutter steps."
  fi
else
  warn "Flutter directory not found: $FLUTTER_DIR"
fi

log "Local CI complete. Artifacts in: $ART_DIR"
