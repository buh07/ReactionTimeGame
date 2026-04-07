# Reaction Duel

BLE reaction-time game with nRF52840 firmware, a Python BLE bridge, and a FastAPI backend.

## Current implementation status

- Repository scaffold completed.
- Firmware app scaffold and BLE notify service implemented.
- Bridge app implemented with retrying HTTP posts.
- API, duel endpoints, tests, migrations, CI, Docker compose, and monitoring config implemented.
- Fly deployment config added with Alembic release command.

## Quick start (software-only)

1. Create env files:

   cp .env.example .env
   cp bridge/.env.example bridge/.env

2. Setup and test API:

   make api-setup
   make api-migrate
   make api-test

3. Run API smoke test:

   make api-smoke

## Phase 1 hardware/toolchain checks

Run:

make phase1-check

Install CLI tools:

make phase1-install-cli

If `nrfjprog` is missing on macOS, install Nordic command line tools manually:

brew install --cask nordic-nrf-command-line-tools

This may request your local sudo password for the Segger J-Link package installer.

## SDK Manager notes (macOS)

- `nrfutil` + `sdk-manager` are installed.
- The sdk-manager install directory is configured to `/opt/nordic/ncs` as required by macOS policy.
- Install a specific SDK version with:

   make phase1-install-sdk

or:

  nrfutil sdk-manager install v3.1.1
