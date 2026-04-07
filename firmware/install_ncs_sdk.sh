#!/usr/bin/env bash

set -euo pipefail

SDK_VERSION="${1:-v3.1.1}"
INSTALL_DIR="/opt/nordic/ncs"

if ! command -v nrfutil >/dev/null 2>&1; then
  echo "nrfutil is required. Run firmware/install_cli_tools.sh first."
  exit 1
fi

if ! nrfutil list | grep -q '^sdk-manager'; then
  echo "Installing nrfutil sdk-manager plugin..."
  nrfutil install sdk-manager
fi

echo "Configuring SDK install directory: $INSTALL_DIR"
nrfutil sdk-manager config install-dir set "$INSTALL_DIR"

echo "Installing nRF Connect SDK $SDK_VERSION"
nrfutil sdk-manager install "$SDK_VERSION"

echo
echo "Installed SDKs:"
nrfutil sdk-manager list
