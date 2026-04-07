.PHONY: help phase1-check api-setup api-migrate api-test api-run api-smoke bridge-setup

help:
	@echo "Targets:"
	@echo "  phase1-check  - Check nRF/Zephyr CLI prerequisites"
	@echo "  api-setup     - Create api/.venv and install dependencies"
	@echo "  api-migrate   - Run Alembic upgrade head (sqlite app.db by default)"
	@echo "  api-test      - Run API test suite"
	@echo "  api-run       - Run API server on localhost:8000"
	@echo "  api-smoke     - Execute local API smoke test flow"
	@echo "  bridge-setup  - Create bridge/.venv and install dependencies"

phase1-check:
	@./firmware/check_phase1_prereqs.sh

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
