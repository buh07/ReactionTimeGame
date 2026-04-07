from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func

from database import Base


class Score(Base):
    __tablename__ = "scores"

    id = Column(Integer, primary_key=True, index=True)
    player = Column(String(32), nullable=False, index=True)
    reaction_ms = Column(Integer, nullable=False)
    duel_id = Column(String(8), ForeignKey("duels.id"), nullable=True, index=True)
    created_at = Column(DateTime, server_default=func.now())


class Duel(Base):
    __tablename__ = "duels"

    id = Column(String(8), primary_key=True)
    player_a = Column(String(32), nullable=False)
    player_b = Column(String(32), nullable=True)
    score_a = Column(Integer, nullable=True)
    score_b = Column(Integer, nullable=True)
    winner = Column(String(32), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
