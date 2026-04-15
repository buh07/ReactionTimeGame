# Reaction Duel

A full-stack BLE (Bluetooth Low Energy) reaction-time game built around the Nordic nRF52840 DK. Two players compete head-to-head: an LED fires at a random moment, each player smashes their button as fast as possible, and the fastest reaction time wins. Scores are relayed over BLE to a Python bridge process, which forwards them to a FastAPI backend. A live-updating web leaderboard displays rankings, personal bests, and duel results. The entire stack was deployed to Fly.io with CI/CD via GitHub Actions and monitored with Prometheus and Grafana.

## Architecture

```
┌──────────────┐  BLE notify   ┌──────────────┐  HTTP POST   ┌──────────────┐
│  nRF52840 DK │ ────────────> │ Python Bridge │ ───────────> │  FastAPI API  │
│  (Zephyr)    │               │  (Bleak)      │              │  (Uvicorn)    │
└──────────────┘               └──────────────┘              └──────┬───────┘
     button + LED                                                   │
                                                          ┌────────┴────────┐
                                                          │   PostgreSQL    │
                                                          └────────┬────────┘
                                                                   │
                                          ┌────────────────────────┼──────────────┐
                                          │                        │              │
                                   ┌──────┴──────┐         ┌──────┴──────┐  ┌────┴─────┐
                                   │ Leaderboard  │         │ Prometheus  │  │ Grafana  │
                                   │   (HTML/JS)  │         │  /metrics   │  │ Dashboard│
                                   └─────────────┘         └─────────────┘  └──────────┘
```

## Components

### Firmware (Zephyr RTOS / C)

The firmware runs on an **nRF52840 DK** using the Zephyr RTOS via the nRF Connect SDK. It implements:

- **GPIO handling** for the on-board button (`SW0` / P0.11) and LED (`LED0` / P0.13) using Zephyr's `gpio_dt_spec` API
- **BLE GATT service** with a custom 128-bit UUID and a notify-only characteristic that transmits reaction times as little-endian 32-bit integers
- **Game thread** that triggers the LED after a random 1.5 - 4.5 second delay, opens a 2-second reaction window, and measures press latency using `k_uptime_get_32()`
- **BLE thread** that drains a Zephyr message queue (`K_MSGQ_DEFINE`) and sends GATT notifications to subscribed clients
- **Interrupt-driven button handler** using `GPIO_INT_EDGE_TO_ACTIVE` for minimal latency between physical press and timestamp capture

The two threads communicate via a lock-free kernel message queue, ensuring the time-critical game loop is never blocked by BLE operations.

### Bridge (Python)

An async Python process that acts as the gateway between the BLE peripheral and the HTTP API:

- **BLE scanning and connection** via the [Bleak](https://github.com/hbldh/bleak) library with automatic reconnection (retries every 5 seconds on disconnect)
- **Notification subscription** on the firmware's GATT characteristic, decoding 4-byte little-endian payloads into millisecond scores
- **Async HTTP posting** via [httpx](https://www.python-httpx.org/) with up to 3 retry attempts and exponential backoff (2s, 4s delays)
- **Duel support** via optional `DUEL_ID` environment variable, appended to score payloads when present
- **Decoupled architecture** using an `asyncio.Queue` so BLE callbacks are never blocked by network I/O

### API (FastAPI)

A Python web backend providing 6 REST endpoints and a server-rendered leaderboard page:

| Endpoint | Method | Description |
|---|---|---|
| `/score` | POST | Submit a reaction time (1-5000 ms). Optionally include a `duel_id` to tie the score to a duel. |
| `/leaderboard` | GET | Top 50 players ranked by personal best (minimum `reaction_ms`), with attempt counts. |
| `/duel` | POST | Create a new duel session. Returns a 6-character alphanumeric ID. |
| `/duel/{id}/join` | POST | Join an existing duel as the second player. Returns 404 if not found, 400 if already full. |
| `/duel/{id}` | GET | Fetch duel status including both players' best scores and the current winner. |
| `/` | GET | Serve the HTML leaderboard page with optional `?player=` query for personal highlighting. |

**Duel winner logic**: Each time a score is submitted for a duel, the API recomputes the winner by comparing each player's best (lowest) reaction time. The winner updates dynamically as players improve their scores.

**Data layer**:
- SQLAlchemy ORM with two models: `Score` (id, player, reaction_ms, duel_id FK, created_at) and `Duel` (id, player_a, player_b, score_a, score_b, winner, created_at)
- Alembic for schema migrations
- PostgreSQL in production (Docker / Fly.io), SQLite for local development and testing

**Observability**: Prometheus metrics are automatically exposed at `/metrics` via `prometheus-fastapi-instrumentator`, tracking request counts, latencies, and status codes.

### Web Leaderboard

A responsive, dark-themed single-page leaderboard served via Jinja2 templates:

- Auto-refreshes every 5 seconds via `fetch()` polling
- Displays world record, total player count, and aggregate attempt count
- Color-coded reaction speed bars (green < 250 ms, yellow 250-380 ms, orange > 380 ms)
- Medal badges for top 3 positions
- Personal best highlighting when accessed with `?player=<name>` query parameter

### Docker Compose Stack

Four services orchestrated for local development:

- **db**: PostgreSQL 16 with health checks (`pg_isready`)
- **api**: FastAPI app with automatic Alembic migration on startup
- **prometheus**: Scrapes the API's `/metrics` endpoint every 10 seconds
- **grafana**: Auto-provisioned Prometheus datasource and a dashboard with request rate and response latency panels

### CI/CD (GitHub Actions)

A three-stage pipeline defined in `.github/workflows/ci.yml`:

1. **Test**: Runs `pytest` against the API test suite with a SQLite backend
2. **Docker**: Builds the full compose stack to verify containerization
3. **Deploy**: On pushes to `main`, deploys to Fly.io via `fly deploy --remote-only`

### Monitoring

- **Prometheus** configuration scraping the API at 10-second intervals
- **Grafana** with auto-provisioned datasource and a pre-built dashboard containing:
  - HTTP request rate graph (`http_requests_total`)
  - Response latency graph (seconds)

## Testing

The project includes a comprehensive testing strategy across multiple layers:

### Unit / Integration Tests (pytest)

11 test cases covering the API endpoints with an isolated SQLite database:

**Score tests** (`api/tests/test_scores.py`):
- Valid score submission (201 response)
- Rejection of negative reaction times (422 validation error)
- Rejection of excessively slow times > 5000 ms (422 validation error)
- Leaderboard ordering by personal best
- Personal best tracking across multiple attempts
- Empty leaderboard handling

**Duel tests** (`api/tests/test_duels.py`):
- Duel creation and joining flow
- Winner determination after both players submit scores
- Winner recomputation when a player improves their score (e.g., Bob leads, then Alice beats him)
- 404 for nonexistent duels
- 400 rejection when a third player tries to join a full duel

### API Smoke Tests

`scripts/api_smoke_test.sh` starts the API server and exercises the complete flow end-to-end: score submission, leaderboard retrieval, duel creation, joining, score submission with duel context, and duel status verification.

### End-to-End Local Tests

`scripts/e2e_local.sh` validates the full duel lifecycle against a running stack: creates a duel, joins as a second player, submits scores for both, and asserts the winner calculation matches the expected outcome.

### Simulated Data Validation

`scripts/simulate_data.py` generates realistic synthetic traffic to validate the system under load:

- Configurable number of players (each with a randomized "skill level" between 185-390 ms base reaction time)
- Gaussian-distributed scores with a 7% chance of "slow reaction" outliers (+80-260 ms)
- Solo scores and duel sessions with multiple attempts per player
- Outputs CSV artifacts (scores, duels) and a JSON summary
- **Built-in consistency check**: verifies that computed duel winners match expected outcomes, exiting non-zero on mismatches

This simulated data was used to populate and validate the production deployment on Fly.io, ensuring the leaderboard, duel logic, and database performed correctly with realistic data volumes before the site went live.

### Full Stack Validation

The `make finish-simulated` target runs the complete validation pipeline: Docker build, stack startup, health checks, synthetic data generation, and end-to-end duel flow verification — all in a single command.

## Deployment

The API was previously hosted on **Fly.io** at `reactiontimegame.fly.dev`. The deployment configuration remains in the repository:

- `api/fly.toml` — Fly.io app config (app name `reactiontimegame`, region `iad`, HTTPS enforcement, auto-stop/start machines)
- `api/Dockerfile` — Production container image
- `.github/workflows/ci.yml` — Automated deploy-on-push-to-main via the `superfly/flyctl-actions` GitHub Action
- Alembic migrations run automatically as a [release command](https://fly.io/docs/reference/configuration/#release_command) before each deploy

The production site was populated with simulated data and fully tested before going live.

## Quick Start

### Software-only (no hardware required)

```bash
# 1. Configure environment
cp .env.example .env
cp bridge/.env.example bridge/.env

# 2. Set up and test the API
make api-setup
make api-migrate
make api-test

# 3. Run the full Docker stack
make docker-build
make docker-up
make docker-check

# 4. Generate simulated data
make simulate-data

# 5. Run end-to-end validation
make e2e-local
```

Services will be available at:
- **Leaderboard**: http://localhost:8000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000

Stop the stack with `make docker-down`.

### Hardware Setup (nRF52840 DK)

```bash
# Install Nordic CLI tools and SDK (macOS)
make phase1-install-cli
make phase1-install-sdk
make phase1-check

# Build and flash firmware
make firmware-build
make firmware-flash

# Set up and run the BLE bridge
make bridge-setup
cd bridge && . .venv/bin/activate
DEVICE_NAME=ReactionDuel CHAR_UUID=<uuid> API_URL=http://localhost:8000/score PLAYER_NAME=alice python main.py
```

### Duel Mode

```bash
# Player A creates a duel
make duel-create PLAYER_A=alice
# → returns DUEL_ID

# Player B joins
make duel-join DUEL_ID=ABC123 PLAYER_B=bob

# Check status
make duel-status DUEL_ID=ABC123
```

## Make Targets

| Target | Description |
|---|---|
| `phase1-install-cli` | Install nrfutil, west, and nRF command line tools |
| `phase1-install-sdk` | Install nRF Connect SDK (default v3.1.1) |
| `phase1-check` | Verify nRF/Zephyr CLI prerequisites |
| `firmware-build` | Build firmware for nrf52840dk/nrf52840 |
| `firmware-flash` | Flash most recent firmware build |
| `docker-build` | Build all compose services |
| `docker-up` | Start db/api/prometheus/grafana |
| `docker-check` | Verify local stack endpoints are healthy |
| `docker-down` | Stop local compose services |
| `api-setup` | Create API virtualenv and install dependencies |
| `api-migrate` | Run Alembic migration |
| `api-test` | Run pytest suite |
| `api-run` | Run API server on localhost:8000 |
| `api-smoke` | Execute API smoke test flow |
| `bridge-setup` | Create bridge virtualenv and install dependencies |
| `simulate-data` | Generate and post synthetic scores/duels |
| `finish-simulated` | Full stack build + health check + data + e2e |
| `duel-create` | Create a new duel |
| `duel-join` | Join an existing duel |
| `duel-status` | Fetch duel status |
| `e2e-local` | Run local duel flow validation |
| `fly-whoami` | Check Fly.io auth status |
| `fly-deploy` | Deploy API to Fly.io |

## Project Structure

```
reaction-duel/
├── firmware/                  # Zephyr RTOS firmware for nRF52840 DK
│   ├── CMakeLists.txt
│   ├── prj.conf
│   └── src/main.c
├── bridge/                    # Python BLE-to-HTTP gateway
│   ├── main.py
│   └── requirements.txt
├── api/                       # FastAPI backend
│   ├── main.py
│   ├── models.py
│   ├── schemas.py
│   ├── database.py
│   ├── templates/
│   │   └── leaderboard.html
│   ├── tests/
│   │   ├── conftest.py
│   │   ├── test_scores.py
│   │   └── test_duels.py
│   ├── alembic/
│   ├── Dockerfile
│   └── fly.toml
├── monitoring/
│   ├── prometheus.yml
│   └── grafana/provisioning/
├── scripts/                   # Build, test, simulation, and helper scripts
├── .github/workflows/ci.yml  # CI/CD pipeline
├── docker-compose.yml
├── Makefile
└── .env.example
```

## Tech Stack

- **Firmware**: C, Zephyr RTOS, nRF Connect SDK, BLE GATT
- **Bridge**: Python 3.12, Bleak (BLE), httpx (HTTP), asyncio
- **API**: FastAPI, SQLAlchemy, Alembic, Pydantic, Jinja2
- **Database**: PostgreSQL 16 (production), SQLite (dev/test)
- **Infrastructure**: Docker Compose, GitHub Actions, Fly.io
- **Monitoring**: Prometheus, Grafana
