#!/usr/bin/env bash

set -euo pipefail

WAIT_TIMEOUT="${WAIT_TIMEOUT:-60}"
WAIT_INTERVAL=2

wait_for_url() {
	local label="$1"
	local url="$2"
	local mode="${3:-body}"
	local elapsed=0

	echo "Checking ${label}..."
	while [[ "$elapsed" -lt "$WAIT_TIMEOUT" ]]; do
		if [[ "$mode" == "head" ]]; then
			if curl -fsSI "$url" >/dev/null 2>&1; then
				return 0
			fi
		else
			if curl -fsS "$url" >/dev/null 2>&1; then
				return 0
			fi
		fi
		sleep "$WAIT_INTERVAL"
		elapsed=$((elapsed + WAIT_INTERVAL))
	done

	echo "ERROR: ${label} did not become ready within ${WAIT_TIMEOUT}s (${url})"
	return 1
}

wait_for_url "API" "http://localhost:8000/leaderboard"

wait_for_url "Prometheus" "http://localhost:9090/-/ready"

wait_for_url "Grafana" "http://localhost:3000/login" "head"

echo "Docker stack looks healthy."
