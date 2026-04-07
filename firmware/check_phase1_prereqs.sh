#!/usr/bin/env bash

set -euo pipefail

echo "Checking Phase 1 prerequisites..."

missing=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok] $cmd: $(command -v "$cmd")"
  else
    echo "[missing] $cmd"
    missing=1
  fi
}

check_cmd nrfutil
check_cmd west
check_cmd nrfjprog

if command -v nrfjprog >/dev/null 2>&1; then
  echo
  echo "Connected board IDs from nrfjprog --ids:"
  ids="$(nrfjprog --ids 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    echo "$ids"
  else
    echo "[missing] No board IDs detected from nrfjprog"
    missing=1
  fi
fi

if command -v nrfutil >/dev/null 2>&1 && nrfutil list 2>/dev/null | grep -q '^device'; then
  echo
  echo "Connected devices from nrfutil device list:"
  nrfutil device list --json-pretty || true
fi

echo
if [[ "$missing" -eq 0 ]]; then
  echo "All required CLIs are present and at least one board is detected."
else
  echo "CLI and/or board detection checks failed. Fix issues and re-run."
  exit 1
fi
