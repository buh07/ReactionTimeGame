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

## Firmware build/flash

Build firmware (uses sdk-manager toolchain launch and handles spaces in path):

make firmware-build

Flash firmware (board must be connected):

make firmware-flash

If flashing fails with "Unable to find a board", connect the nRF52840 DK over USB and retry.

## Docker stack

Build and run the local stack:

make docker-build
make docker-up
make docker-check

Services:

- API: [http://localhost:8000](http://localhost:8000)
- Prometheus: [http://localhost:9090](http://localhost:9090)
- Grafana: [http://localhost:3000](http://localhost:3000)

Stop stack:

make docker-down

## Fly deploy

Check login status:

make fly-whoami

Deploy API (uses api/fly.toml):

make fly-deploy

## Duel mode helpers

Create a duel:

make duel-create PLAYER_A=alice

Join a duel:

make duel-join DUEL_ID=ABC123 PLAYER_B=bob

Check duel status:

make duel-status DUEL_ID=ABC123

Run full local duel E2E check:

make e2e-local

## Synthetic data simulation

Generate realistic synthetic solo and duel traffic against the API:

make simulate-data

Useful overrides:

SIM_PLAYERS=24 SIM_SOLO_SCORES=600 SIM_DUELS=120 SIM_SEED=42 make simulate-data

Generated artifacts are written under simulated_data/:

- scores_*.csv
- duels_*.csv
- summary_*.json

By default, the simulator exits with a non-zero status if duel winner mismatches are detected.
This acts as a consistency check for duel winner update logic.

Run full simulated completion flow (stack up + health checks + synthetic data + e2e):

make finish-simulated
