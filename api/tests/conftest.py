import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

API_DIR = Path(__file__).resolve().parents[1]
if str(API_DIR) not in sys.path:
    sys.path.insert(0, str(API_DIR))

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from database import Base, get_db
from main import app

TEST_DB_URL = "sqlite:///./test.db"
engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSession = sessionmaker(bind=engine)


@pytest.fixture(autouse=True)
def isolated_db():
    Base.metadata.create_all(bind=engine)
    db = TestSession()

    def override():
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override
    yield db
    Base.metadata.drop_all(bind=engine)
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)
