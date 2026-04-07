#!/usr/bin/env bash

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required on macOS. Install from https://brew.sh"
  exit 1
fi

echo "Installing nrfutil and west..."
brew install nrfutil west

echo "Installing nrfjprog/J-Link tools (may request local sudo password)..."
brew install --cask nordic-nrf-command-line-tools

echo
echo "Installed command paths:"
command -v nrfutil || true
command -v west || true
command -v nrfjprog || true
