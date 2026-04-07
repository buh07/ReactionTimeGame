#!/usr/bin/env bash

set -euo pipefail

echo "Checking API..."
curl -fsS http://localhost:8000/leaderboard >/dev/null

echo "Checking Prometheus..."
curl -fsS http://localhost:9090/-/ready >/dev/null

echo "Checking Grafana..."
curl -fsSI http://localhost:3000/login >/dev/null

echo "Docker stack looks healthy."
