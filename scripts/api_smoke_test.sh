#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT_DIR/api"

if [[ ! -d "$API_DIR/.venv" ]]; then
  echo "api/.venv not found. Run: make api-setup"
  exit 1
fi

source "$API_DIR/.venv/bin/activate"
export DATABASE_URL="${DATABASE_URL:-sqlite:///./app.db}"

pushd "$API_DIR" >/dev/null
uvicorn main:app --host 127.0.0.1 --port 8000 >/tmp/reaction_duel_api.log 2>&1 &
API_PID=$!

cleanup() {
  kill "$API_PID" >/dev/null 2>&1 || true
  wait "$API_PID" 2>/dev/null || true
  popd >/dev/null
}
trap cleanup EXIT

for _ in {1..30}; do
  if curl -sS http://127.0.0.1:8000/leaderboard >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "Posting score..."
curl -sS -X POST http://127.0.0.1:8000/score \
  -H 'Content-Type: application/json' \
  -d '{"player":"alice","reaction_ms":213}'
echo

echo "Reading leaderboard..."
curl -sS http://127.0.0.1:8000/leaderboard
echo

echo "Creating duel..."
DUEL_JSON=$(curl -sS -X POST http://127.0.0.1:8000/duel \
  -H 'Content-Type: application/json' \
  -d '{"player_a":"alice"}')
DUEL_ID=$(echo "$DUEL_JSON" | sed -E 's/.*"id":"([^"]+)".*/\1/')
echo "Duel ID: $DUEL_ID"

curl -sS -X POST "http://127.0.0.1:8000/duel/$DUEL_ID/join" \
  -H 'Content-Type: application/json' \
  -d '{"player_b":"bob"}'
echo

curl -sS -X POST http://127.0.0.1:8000/score \
  -H 'Content-Type: application/json' \
  -d '{"player":"alice","reaction_ms":220,"duel_id":"'"$DUEL_ID"'"}'
echo

curl -sS -X POST http://127.0.0.1:8000/score \
  -H 'Content-Type: application/json' \
  -d '{"player":"bob","reaction_ms":310,"duel_id":"'"$DUEL_ID"'"}'
echo

echo "Final duel state:"
curl -sS "http://127.0.0.1:8000/duel/$DUEL_ID"
echo

echo "Smoke test completed."
