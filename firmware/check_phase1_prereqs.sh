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
  nrfjprog --ids || true
fi

echo
if [[ "$missing" -eq 0 ]]; then
  echo "All required CLIs are present."
else
  echo "One or more CLIs are missing. Install missing tools and re-run."
  exit 1
fi
