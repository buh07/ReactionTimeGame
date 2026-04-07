#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_LINK="/tmp/reaction-duel"
SDK_VERSION="${SDK_VERSION:-v3.1.1}"
BOARD="${BOARD:-nrf52840dk/nrf52840}"
BUILD_DIR="${BUILD_DIR:-/opt/nordic/ncs/${SDK_VERSION}/build/reaction-duel}"

if ! command -v nrfutil >/dev/null 2>&1; then
  echo "nrfutil not found. Run firmware/install_cli_tools.sh first."
  exit 1
fi

if ! nrfutil sdk-manager list | grep -q "${SDK_VERSION}.*Installed"; then
  echo "SDK ${SDK_VERSION} is not installed. Run firmware/install_ncs_sdk.sh ${SDK_VERSION}."
  exit 1
fi

# Zephyr/NCS toolchain can fail when app paths contain spaces.
ln -sfn "$ROOT_DIR" "$APP_LINK"

nrfutil sdk-manager toolchain launch --ncs-version "$SDK_VERSION" \
  --chdir "/opt/nordic/ncs/${SDK_VERSION}" \
  -- west build -b "$BOARD" "$APP_LINK/firmware" \
       --pristine --build-dir "$BUILD_DIR" \
       -- -DCONFIG_LOG_DEFAULT_LEVEL=3

echo
echo "Build complete: ${BUILD_DIR}"
