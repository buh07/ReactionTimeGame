#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
import random
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from http.client import RemoteDisconnected
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def api_request(api_base: str, method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
    url = f"{api_base.rstrip('/')}{path}"
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = Request(url=url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8")
            if not body:
                return None
            return json.loads(body)
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} {method} {path}: {body}") from exc
    except URLError as exc:
        raise RuntimeError(f"Network error {method} {path}: {exc}") from exc
    except RemoteDisconnected as exc:
        raise RuntimeError(f"Connection dropped {method} {path}: {exc}") from exc


def wait_for_api(api_base: str, timeout_seconds: int) -> None:
    start = time.time()
    while time.time() - start < timeout_seconds:
        try:
            api_request(api_base, "GET", "/leaderboard")
            return
        except RuntimeError:
            time.sleep(1)
    raise RuntimeError(f"API did not become ready within {timeout_seconds}s at {api_base}/leaderboard")


def build_player_names(count: int) -> list[str]:
    base = [
        "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel",
        "india", "juliet", "kilo", "lima", "mike", "november", "oscar", "papa",
        "quebec", "romeo", "sierra", "tango", "uniform", "victor", "whiskey", "xray",
        "yankee", "zulu",
    ]
    names: list[str] = []
    for i in range(count):
        token = base[i % len(base)]
        suffix = i // len(base)
        names.append(token if suffix == 0 else f"{token}{suffix}")
    return names


def simulated_reaction_ms(rng: random.Random, skill_ms: int) -> int:
    score = int(rng.gauss(skill_ms, 22.0))
    if rng.random() < 0.07:
        score += rng.randint(80, 260)
    return max(120, min(score, 1200))


def write_scores_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["timestamp_utc", "player", "reaction_ms", "duel_id", "mode"],
        )
        writer.writeheader()
        writer.writerows(rows)


def write_duels_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "duel_id",
                "player_a",
                "player_b",
                "expected_winner",
                "api_winner",
                "best_a",
                "best_b",
                "winner_match",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def run_simulation(
    api_base: str,
    players: int,
    solo_scores: int,
    duels: int,
    attempts_per_player: int,
    seed: int,
    output_dir: Path,
) -> dict[str, Any]:
    rng = random.Random(seed)
    wait_for_api(api_base, timeout_seconds=30)

    player_names = build_player_names(players)
    skill_by_player = {name: rng.randint(185, 390) for name in player_names}
    score_rows: list[dict[str, Any]] = []
    duel_rows: list[dict[str, Any]] = []

    now_iso = lambda: datetime.now(timezone.utc).isoformat()

    for _ in range(solo_scores):
        player = rng.choice(player_names)
        reaction = simulated_reaction_ms(rng, skill_by_player[player])
        api_request(api_base, "POST", "/score", {"player": player, "reaction_ms": reaction})
        score_rows.append(
            {
                "timestamp_utc": now_iso(),
                "player": player,
                "reaction_ms": reaction,
                "duel_id": "",
                "mode": "solo",
            }
        )

    for _ in range(duels):
        player_a, player_b = rng.sample(player_names, 2)
        duel = api_request(api_base, "POST", "/duel", {"player_a": player_a})
        duel_id = duel["id"]
        api_request(api_base, "POST", f"/duel/{duel_id}/join", {"player_b": player_b})

        a_scores: list[int] = []
        b_scores: list[int] = []

        for _round in range(attempts_per_player):
            a_score = simulated_reaction_ms(rng, skill_by_player[player_a])
            b_score = simulated_reaction_ms(rng, skill_by_player[player_b])
            a_scores.append(a_score)
            b_scores.append(b_score)

            api_request(
                api_base,
                "POST",
                "/score",
                {"player": player_a, "reaction_ms": a_score, "duel_id": duel_id},
            )
            api_request(
                api_base,
                "POST",
                "/score",
                {"player": player_b, "reaction_ms": b_score, "duel_id": duel_id},
            )

            score_rows.append(
                {
                    "timestamp_utc": now_iso(),
                    "player": player_a,
                    "reaction_ms": a_score,
                    "duel_id": duel_id,
                    "mode": "duel",
                }
            )
            score_rows.append(
                {
                    "timestamp_utc": now_iso(),
                    "player": player_b,
                    "reaction_ms": b_score,
                    "duel_id": duel_id,
                    "mode": "duel",
                }
            )

        best_a = min(a_scores)
        best_b = min(b_scores)
        expected_winner = player_a if best_a <= best_b else player_b

        duel_state = api_request(api_base, "GET", f"/duel/{duel_id}")
        api_winner = duel_state.get("winner")
        duel_rows.append(
            {
                "duel_id": duel_id,
                "player_a": player_a,
                "player_b": player_b,
                "expected_winner": expected_winner,
                "api_winner": api_winner,
                "best_a": best_a,
                "best_b": best_b,
                "winner_match": str(expected_winner == api_winner).lower(),
            }
        )

    leaderboard = api_request(api_base, "GET", "/leaderboard")
    top10 = leaderboard[:10]
    winner_mismatches = [row for row in duel_rows if row["winner_match"] != "true"]

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output_dir.mkdir(parents=True, exist_ok=True)
    scores_csv = output_dir / f"scores_{timestamp}.csv"
    duels_csv = output_dir / f"duels_{timestamp}.csv"
    summary_json = output_dir / f"summary_{timestamp}.json"

    write_scores_csv(scores_csv, score_rows)
    write_duels_csv(duels_csv, duel_rows)

    summary = {
        "seed": seed,
        "api_base": api_base,
        "players": players,
        "solo_scores_generated": solo_scores,
        "duels_generated": duels,
        "attempts_per_duel_player": attempts_per_player,
        "total_score_posts": len(score_rows),
        "duel_winner_mismatches": len(winner_mismatches),
        "leaderboard_top10": top10,
        "artifacts": {
            "scores_csv": str(scores_csv),
            "duels_csv": str(duels_csv),
            "summary_json": str(summary_json),
        },
    }

    summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and submit synthetic Reaction Duel score data")
    parser.add_argument("--api-base", default="http://localhost:8000")
    parser.add_argument("--players", type=int, default=16)
    parser.add_argument("--solo-scores", type=int, default=240)
    parser.add_argument("--duels", type=int, default=40)
    parser.add_argument("--attempts-per-player", type=int, default=3)
    parser.add_argument("--seed", type=int, default=20260414)
    parser.add_argument("--output-dir", default="simulated_data")
    parser.add_argument(
        "--allow-winner-mismatch",
        action="store_true",
        help="Do not fail when duel winner mismatches are detected",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = run_simulation(
        api_base=args.api_base,
        players=args.players,
        solo_scores=args.solo_scores,
        duels=args.duels,
        attempts_per_player=args.attempts_per_player,
        seed=args.seed,
        output_dir=Path(args.output_dir),
    )

    print("Simulation complete.")
    print(json.dumps(summary, indent=2))

    if summary["duel_winner_mismatches"] > 0 and not args.allow_winner_mismatch:
        print(
            f"Detected {summary['duel_winner_mismatches']} duel winner mismatches. "
            "Use --allow-winner-mismatch to bypass failure."
        )
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
