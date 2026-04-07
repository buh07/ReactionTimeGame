#!/usr/bin/env bash

set -euo pipefail

API_BASE="${1:-http://localhost:8000}"
PLAYER_A="${2:-alice}"

curl -fsS -X POST "${API_BASE}/duel" \
  -H 'Content-Type: application/json' \
  -d "{\"player_a\":\"${PLAYER_A}\"}"
echo
