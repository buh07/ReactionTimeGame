import random
import string

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.templating import Jinja2Templates
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import Base, engine, get_db
from models import Duel, Score
from schemas import DuelCreate, DuelJoin, DuelOut, ScoreIn, ScoreOut

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Reaction Duel API")
Instrumentator().instrument(app).expose(app)
templates = Jinja2Templates(directory="templates")


def _short_id(n: int = 6) -> str:
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=n))


@app.post("/score", status_code=201)
def submit_score(payload: ScoreIn, db: Session = Depends(get_db)):
    db.add(
        Score(
            player=payload.player,
            reaction_ms=payload.reaction_ms,
            duel_id=payload.duel_id,
        )
    )
    db.commit()

    if payload.duel_id:
        _update_duel(payload.duel_id, payload.player, payload.reaction_ms, db)

    return {"ok": True}


@app.get("/leaderboard", response_model=list[ScoreOut])
def get_leaderboard(db: Session = Depends(get_db)):
    rows = (
        db.query(
            Score.player,
            func.min(Score.reaction_ms).label("best_ms"),
            func.count(Score.id).label("attempts"),
        )
        .group_by(Score.player)
        .order_by("best_ms")
        .limit(50)
        .all()
    )
    return [
        ScoreOut(player=r.player, best_ms=r.best_ms, attempts=r.attempts)
        for r in rows
    ]


@app.post("/duel", response_model=DuelOut, status_code=201)
def create_duel(payload: DuelCreate, db: Session = Depends(get_db)):
    duel = Duel(id=_short_id(), player_a=payload.player_a)
    db.add(duel)
    db.commit()
    db.refresh(duel)
    return duel


@app.post("/duel/{duel_id}/join", response_model=DuelOut)
def join_duel(duel_id: str, payload: DuelJoin, db: Session = Depends(get_db)):
    duel = db.get(Duel, duel_id)
    if not duel:
        raise HTTPException(404, "Duel not found")
    if duel.player_b:
        raise HTTPException(400, "Duel already has two players")

    duel.player_b = payload.player_b
    db.commit()
    db.refresh(duel)
    return duel


@app.get("/duel/{duel_id}", response_model=DuelOut)
def get_duel(duel_id: str, db: Session = Depends(get_db)):
    duel = db.get(Duel, duel_id)
    if not duel:
        raise HTTPException(404, "Duel not found")
    return duel


def _update_duel(duel_id: str, player: str, score_ms: int, db: Session) -> None:
    duel = db.get(Duel, duel_id)
    if not duel:
        return

    if player == duel.player_a and (duel.score_a is None or score_ms < duel.score_a):
        duel.score_a = score_ms
    elif player == duel.player_b and (duel.score_b is None or score_ms < duel.score_b):
        duel.score_b = score_ms

    if duel.score_a is not None and duel.score_b is not None and not duel.winner:
        duel.winner = duel.player_a if duel.score_a <= duel.score_b else duel.player_b

    db.commit()


@app.get("/")
def leaderboard_page(request: Request, player: str = ""):
    return templates.TemplateResponse(
        "leaderboard.html", {"request": request, "player": player}
    )
