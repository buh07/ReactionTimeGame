def test_create_and_join_duel(client):
    r = client.post("/duel", json={"player_a": "alice"})
    assert r.status_code == 201
    duel_id = r.json()["id"]

    r2 = client.post(f"/duel/{duel_id}/join", json={"player_b": "bob"})
    assert r2.status_code == 200
    assert r2.json()["player_b"] == "bob"


def test_duel_winner_determined(client):
    duel_id = client.post("/duel", json={"player_a": "alice"}).json()["id"]
    client.post(f"/duel/{duel_id}/join", json={"player_b": "bob"})

    client.post(
        "/score", json={"player": "alice", "reaction_ms": 200, "duel_id": duel_id}
    )
    client.post(
        "/score", json={"player": "bob", "reaction_ms": 350, "duel_id": duel_id}
    )

    duel = client.get(f"/duel/{duel_id}").json()
    assert duel["winner"] == "alice"


def test_duel_winner_recomputed_when_scores_improve(client):
    duel_id = client.post("/duel", json={"player_a": "alice"}).json()["id"]
    client.post(f"/duel/{duel_id}/join", json={"player_b": "bob"})

    # Bob leads initially.
    client.post(
        "/score", json={"player": "alice", "reaction_ms": 350, "duel_id": duel_id}
    )
    client.post(
        "/score", json={"player": "bob", "reaction_ms": 300, "duel_id": duel_id}
    )
    duel = client.get(f"/duel/{duel_id}").json()
    assert duel["winner"] == "bob"

    # Alice later improves and should become winner.
    client.post(
        "/score", json={"player": "alice", "reaction_ms": 200, "duel_id": duel_id}
    )
    duel = client.get(f"/duel/{duel_id}").json()
    assert duel["winner"] == "alice"


def test_duel_not_found(client):
    r = client.get("/duel/NOPE99")
    assert r.status_code == 404


def test_duel_join_twice_rejected(client):
    duel_id = client.post("/duel", json={"player_a": "alice"}).json()["id"]
    client.post(f"/duel/{duel_id}/join", json={"player_b": "bob"})
    r = client.post(f"/duel/{duel_id}/join", json={"player_b": "carol"})
    assert r.status_code == 400
