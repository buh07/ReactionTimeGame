#!/usr/bin/env bash

set -euo pipefail

SDK_VERSION="${SDK_VERSION:-v3.1.1}"
BUILD_DIR="${BUILD_DIR:-/opt/nordic/ncs/${SDK_VERSION}/build/reaction-duel}"

if ! command -v nrfutil >/dev/null 2>&1; then
  echo "nrfutil not found. Run firmware/install_cli_tools.sh first."
  exit 1
fi

if [[ ! -f "${BUILD_DIR}/build.ninja" && ! -f "${BUILD_DIR}/zephyr/zephyr.hex" ]]; then
  echo "Build artifacts not found in '${BUILD_DIR}'."
  echo "Run: make firmware-build"
  echo "Or set BUILD_DIR to an existing west build directory before flashing."
  exit 1
fi

nrfutil sdk-manager toolchain launch --ncs-version "$SDK_VERSION" \
  --chdir "/opt/nordic/ncs/${SDK_VERSION}" \
  -- west flash --build-dir "$BUILD_DIR"
