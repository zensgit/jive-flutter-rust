#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8012}"
EMAIL_BASE="obs_test_$RANDOM"
PASS="Wrong123!"

log() { echo "[verify] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

check_metric() {
  local name=$1
  grep -E "^${name}(\{|\s)" metrics.out >/dev/null || fail "Missing metric: $name"
}

log "Simulating failed logins..."
for i in 1 2; do
  curl -s -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' \
    -d "{\"email\":\"${EMAIL_BASE}${i}@example.com\",\"password\":\"$PASS\"}" \
    "$API_URL/api/v1/auth/login" || true
done

log "Triggering rate limit (using same email)..."
for i in 1 2 3 4; do
  curl -s -o /dev/null -H 'Content-Type: application/json' \
    -d "{\"email\":\"${EMAIL_BASE}-limit@example.com\",\"password\":\"$PASS\"}" \
    "$API_URL/api/v1/auth/login" || true
done

log "Fetching metrics..."
curl -s "$API_URL/metrics" > metrics.out || fail "Cannot fetch /metrics"

REQUIRED=( \
  auth_login_fail_total \
  auth_login_rate_limited_total \
  jive_password_rehash_fail_breakdown_total \
  export_duration_buffered_seconds_bucket \
  process_uptime_seconds \
)

for m in "${REQUIRED[@]}"; do
  check_metric "$m"
done

echo "PASS: Core observability metrics present." 
rm -f metrics.out
