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

if ! command -v nrfjprog >/dev/null 2>&1; then
  user_nrfjprog="$HOME/Applications/Nordic Semiconductor/bin/nrfjprog"
  if [[ -x "$user_nrfjprog" ]]; then
    echo "Found user-scope nrfjprog at: $user_nrfjprog"
    if ln -sfn "$user_nrfjprog" /usr/local/bin/nrfjprog 2>/dev/null; then
      echo "Linked nrfjprog into /usr/local/bin"
    else
      echo "Could not write /usr/local/bin; add this to your shell profile:"
      echo "  export PATH=\"$HOME/Applications/Nordic Semiconductor/bin:\$PATH\""
    fi
  fi
fi

echo
echo "Installed command paths:"
command -v nrfutil || true
command -v west || true
command -v nrfjprog || true
