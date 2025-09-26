#!/usr/bin/env bash
set -euo pipefail

API_URL=${API_URL:-http://localhost:8012}

health_json=$(curl -fsS "${API_URL}/health") || { echo "FAIL: cannot fetch /health" >&2; exit 1; }
metrics_text=$(curl -fsS "${API_URL}/metrics") || { echo "FAIL: cannot fetch /metrics" >&2; exit 1; }

health_bcrypt_sum=$(echo "$health_json" | jq '.metrics.hash_distribution.bcrypt | (."2a"+."2b"+."2y")')
metrics_bcrypt_total=$(grep '^password_hash_bcrypt_total ' <<<"$metrics_text" | awk '{print $2}')

if [[ -z "$metrics_bcrypt_total" ]]; then
  echo "FAIL: password_hash_bcrypt_total not present in /metrics" >&2
  exit 2
fi

if [[ "$health_bcrypt_sum" != "$metrics_bcrypt_total" ]]; then
  echo "FAIL: mismatch bcrypt total (health=$health_bcrypt_sum metrics=$metrics_bcrypt_total)" >&2
  exit 3
fi

echo "OK: bcrypt total consistent ($metrics_bcrypt_total)"
exit 0
