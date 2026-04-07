def test_submit_valid_score(client):
    r = client.post("/score", json={"player": "alice", "reaction_ms": 250})
    assert r.status_code == 201


def test_submit_invalid_score_negative(client):
    r = client.post("/score", json={"player": "bob", "reaction_ms": -5})
    assert r.status_code == 422


def test_submit_invalid_score_too_slow(client):
    r = client.post("/score", json={"player": "bob", "reaction_ms": 9999})
    assert r.status_code == 422


def test_leaderboard_ordering(client):
    client.post("/score", json={"player": "fast", "reaction_ms": 180})
    client.post("/score", json={"player": "slow", "reaction_ms": 400})
    data = client.get("/leaderboard").json()
    assert data[0]["player"] == "fast"


def test_leaderboard_keeps_personal_best(client):
    client.post("/score", json={"player": "alice", "reaction_ms": 250})
    client.post("/score", json={"player": "alice", "reaction_ms": 999})
    data = client.get("/leaderboard").json()
    alice = next(d for d in data if d["player"] == "alice")
    assert alice["best_ms"] == 250
    assert alice["attempts"] == 2


def test_leaderboard_empty(client):
    data = client.get("/leaderboard").json()
    assert data == []
