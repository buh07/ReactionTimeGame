#!/usr/bin/env bash

set -euo pipefail

API_BASE="${1:-http://localhost:8000}"
DUEL_ID="${2:-}"

if [[ -z "${DUEL_ID}" ]]; then
  echo "Usage: $0 <api_base> <duel_id>"
  exit 1
fi

curl -fsS "${API_BASE}/duel/${DUEL_ID}"
echo
