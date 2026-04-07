#!/usr/bin/env bash

set -euo pipefail

API_BASE="${1:-http://localhost:8000}"
DUEL_ID="${2:-}"
PLAYER_B="${3:-bob}"

if [[ -z "${DUEL_ID}" ]]; then
  echo "Usage: $0 <api_base> <duel_id> [player_b]"
  exit 1
fi

curl -fsS -X POST "${API_BASE}/duel/${DUEL_ID}/join" \
  -H 'Content-Type: application/json' \
  -d "{\"player_b\":\"${PLAYER_B}\"}"
echo
