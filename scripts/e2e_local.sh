#!/usr/bin/env bash

set -euo pipefail

API_BASE="${API_BASE:-http://localhost:8000}"
PLAYER_A="${PLAYER_A:-alice}"
PLAYER_B="${PLAYER_B:-bob}"
SCORE_A="${SCORE_A:-220}"
SCORE_B="${SCORE_B:-310}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-60}"
WAIT_INTERVAL=2

echo "Waiting for API at ${API_BASE}..."
elapsed=0
api_ready=0
while [[ "${elapsed}" -lt "${WAIT_TIMEOUT}" ]]; do
  if curl -fsS "${API_BASE}/leaderboard" >/dev/null 2>&1; then
    api_ready=1
    break
  fi
  sleep "${WAIT_INTERVAL}"
  elapsed=$((elapsed + WAIT_INTERVAL))
done

if [[ "${api_ready}" -ne 1 ]]; then
  echo "ERROR: API did not become ready at ${API_BASE}/leaderboard within ${WAIT_TIMEOUT}s."
  echo "Start the API first (for example: make api-run or docker compose up)."
  exit 1
fi

echo "Creating duel for ${PLAYER_A}..."
DUEL_JSON=$(curl -fsS -X POST "${API_BASE}/duel" \
  -H 'Content-Type: application/json' \
  -d "{\"player_a\":\"${PLAYER_A}\"}")
DUEL_ID=$(echo "${DUEL_JSON}" | sed -E 's/.*"id":"([^"]+)".*/\1/')

echo "Duel ID: ${DUEL_ID}"
echo "Joining duel as ${PLAYER_B}..."
curl -fsS -X POST "${API_BASE}/duel/${DUEL_ID}/join" \
  -H 'Content-Type: application/json' \
  -d "{\"player_b\":\"${PLAYER_B}\"}" >/dev/null

echo "Submitting scores ${PLAYER_A}=${SCORE_A}, ${PLAYER_B}=${SCORE_B}..."
curl -fsS -X POST "${API_BASE}/score" \
  -H 'Content-Type: application/json' \
  -d "{\"player\":\"${PLAYER_A}\",\"reaction_ms\":${SCORE_A},\"duel_id\":\"${DUEL_ID}\"}" >/dev/null

curl -fsS -X POST "${API_BASE}/score" \
  -H 'Content-Type: application/json' \
  -d "{\"player\":\"${PLAYER_B}\",\"reaction_ms\":${SCORE_B},\"duel_id\":\"${DUEL_ID}\"}" >/dev/null

DUEL_STATE=$(curl -fsS "${API_BASE}/duel/${DUEL_ID}")
echo "Duel state: ${DUEL_STATE}"

EXPECTED_WINNER="${PLAYER_A}"
if [[ "${SCORE_B}" -lt "${SCORE_A}" ]]; then
  EXPECTED_WINNER="${PLAYER_B}"
fi

if echo "${DUEL_STATE}" | grep -q "\"winner\":\"${EXPECTED_WINNER}\""; then
  echo "E2E local duel flow passed. Winner=${EXPECTED_WINNER}"
else
  echo "E2E local duel flow failed: expected winner ${EXPECTED_WINNER}"
  exit 1
fi
