.PHONY: help phase1-install-cli phase1-install-sdk phase1-check firmware-build firmware-flash docker-build docker-up docker-check docker-down api-setup api-migrate api-test api-run api-smoke bridge-setup fly-whoami fly-deploy

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
	@cd api && /usr/local/bin/python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt pytest httpx

api-migrate:
	@cd api && . .venv/bin/activate && export DATABASE_URL=$${DATABASE_URL:-sqlite:///./app.db} && alembic upgrade head

api-test:
	@cd api && . .venv/bin/activate && export DATABASE_URL=sqlite:///./test.db && pytest tests -v

api-run:
	@cd api && . .venv/bin/activate && export DATABASE_URL=$${DATABASE_URL:-sqlite:///./app.db} && uvicorn main:app --host 127.0.0.1 --port 8000

api-smoke:
	@./scripts/api_smoke_test.sh

bridge-setup:
	@cd bridge && /usr/local/bin/python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt

fly-whoami:
	@fly auth whoami

fly-deploy:
	@cd api && fly deploy --remote-only
