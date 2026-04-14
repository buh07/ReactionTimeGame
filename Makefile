.PHONY: help phase1-install-cli phase1-install-sdk phase1-check firmware-build firmware-flash docker-build docker-up docker-check docker-down api-setup api-migrate api-test api-run api-smoke bridge-setup simulate-data finish-simulated duel-create duel-join duel-status e2e-local fly-whoami fly-deploy

API_BASE ?= http://localhost:8000
PLAYER_A ?= alice
PLAYER_B ?= bob
DUEL_ID ?=
PYTHON ?= python3
SIM_PLAYERS ?= 16
SIM_SOLO_SCORES ?= 240
SIM_DUELS ?= 40
SIM_ATTEMPTS_PER_PLAYER ?= 3
SIM_SEED ?= 20260414
SIM_OUTPUT_DIR ?= simulated_data

help:
	@echo "Targets:"
	@echo "  phase1-install-cli - Install nrfutil, west, and nRF command line tools"
	@echo "  phase1-install-sdk - Install nRF Connect SDK (default v3.1.1)"
	@echo "  phase1-check  - Check nRF/Zephyr CLI prerequisites"
	@echo "  firmware-build - Build firmware for nrf52840dk/nrf52840"
	@echo "  firmware-flash - Flash most recent firmware build"
	@echo "  docker-build   - Build all compose services"
	@echo "  docker-up      - Start db/api/prometheus/grafana"
	@echo "  docker-check   - Check local stack endpoints"
	@echo "  docker-down    - Stop local compose services"
	@echo "  api-setup     - Create api/.venv and install dependencies"
	@echo "  api-migrate   - Run Alembic upgrade head (sqlite app.db by default)"
	@echo "  api-test      - Run API test suite"
	@echo "  api-run       - Run API server on localhost:8000"
	@echo "  api-smoke     - Execute local API smoke test flow"
	@echo "  bridge-setup  - Create bridge/.venv and install dependencies"
	@echo "  simulate-data - Post synthetic scores/duels and save CSV/JSON artifacts"
	@echo "  finish-simulated - Bring stack up, run checks, simulate data, run e2e"
	@echo "  duel-create   - Create duel (API_BASE, PLAYER_A vars)"
	@echo "  duel-join     - Join duel (API_BASE, DUEL_ID, PLAYER_B vars)"
	@echo "  duel-status   - Fetch duel status (API_BASE, DUEL_ID vars)"
	@echo "  e2e-local     - Run full local duel flow validation"
	@echo "  fly-whoami    - Check Fly authentication status"
	@echo "  fly-deploy    - Deploy API using api/fly.toml"


phase1-install-cli:
	@./firmware/install_cli_tools.sh

phase1-install-sdk:
	@./firmware/install_ncs_sdk.sh

phase1-check:
	@./firmware/check_phase1_prereqs.sh

firmware-build:
	@./firmware/build_firmware.sh

firmware-flash:
	@./firmware/flash_firmware.sh

docker-build:
	@docker compose build

docker-up:
	@test -f .env || cp .env.example .env
	@docker compose up -d

docker-check:
	@./scripts/docker_stack_check.sh

docker-down:
	@docker compose down

api-setup:
	@command -v "$(PYTHON)" >/dev/null 2>&1 || { echo "Python executable '$(PYTHON)' not found in PATH"; exit 1; }
	@cd api && "$(PYTHON)" -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt pytest httpx

api-migrate:
	@cd api && . .venv/bin/activate && export DATABASE_URL=$${DATABASE_URL:-sqlite:///./app.db} && alembic upgrade head

api-test:
	@cd api && . .venv/bin/activate && export DATABASE_URL=sqlite:///./test.db && pytest tests -v

api-run:
	@cd api && . .venv/bin/activate && export DATABASE_URL=$${DATABASE_URL:-sqlite:///./app.db} && uvicorn main:app --host 127.0.0.1 --port 8000

api-smoke:
	@./scripts/api_smoke_test.sh

bridge-setup:
	@command -v "$(PYTHON)" >/dev/null 2>&1 || { echo "Python executable '$(PYTHON)' not found in PATH"; exit 1; }
	@cd bridge && "$(PYTHON)" -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt

simulate-data:
	@command -v "$(PYTHON)" >/dev/null 2>&1 || { echo "Python executable '$(PYTHON)' not found in PATH"; exit 1; }
	@"$(PYTHON)" ./scripts/simulate_data.py \
		--api-base "$(API_BASE)" \
		--players "$(SIM_PLAYERS)" \
		--solo-scores "$(SIM_SOLO_SCORES)" \
		--duels "$(SIM_DUELS)" \
		--attempts-per-player "$(SIM_ATTEMPTS_PER_PLAYER)" \
		--seed "$(SIM_SEED)" \
		--output-dir "$(SIM_OUTPUT_DIR)"

finish-simulated: docker-build docker-up docker-check simulate-data e2e-local
	@echo "Simulated completion flow finished successfully."

duel-create:
	@./scripts/duel_create.sh "$(API_BASE)" "$(PLAYER_A)"

duel-join:
	@./scripts/duel_join.sh "$(API_BASE)" "$(DUEL_ID)" "$(PLAYER_B)"

duel-status:
	@./scripts/duel_status.sh "$(API_BASE)" "$(DUEL_ID)"

e2e-local:
	@./scripts/e2e_local.sh

fly-whoami:
	@fly auth whoami

fly-deploy:
	@cd api && fly deploy --remote-only
