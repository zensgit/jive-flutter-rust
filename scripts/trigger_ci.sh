#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_NAME="Core CI (Strict)"
BRANCH="${1:-main}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install from https://cli.github.com/"
  exit 1
fi

echo "Triggering workflow: ${WORKFLOW_NAME} on branch ${BRANCH}"
gh workflow run "${WORKFLOW_NAME}" -r "${BRANCH}"
echo "Done. Check Actions tab for progress."

