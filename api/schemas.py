from typing import Optional

from pydantic import BaseModel, Field


class ScoreIn(BaseModel):
    player: str = Field(..., min_length=1, max_length=32)
    reaction_ms: int = Field(..., gt=0, lt=5000)
    duel_id: Optional[str] = Field(None, max_length=8)


class ScoreOut(BaseModel):
    player: str
    best_ms: int
    attempts: int


class DuelCreate(BaseModel):
    player_a: str = Field(..., min_length=1, max_length=32)


class DuelJoin(BaseModel):
    player_b: str = Field(..., min_length=1, max_length=32)


class DuelOut(BaseModel):
    id: str
    player_a: str
    player_b: Optional[str]
    score_a: Optional[int]
    score_b: Optional[int]
    winner: Optional[str]
