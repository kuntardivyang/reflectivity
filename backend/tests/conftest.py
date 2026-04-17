"""Pytest fixtures shared across the backend test suite."""
import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest

# Make the backend package importable without an install step.
BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))


@pytest.fixture
def mock_db_session():
    """A Session double that records calls and returns predictable queries."""
    session = MagicMock()
    session.query.return_value.all.return_value = []
    session.query.return_value.filter.return_value.first.return_value = None
    session.query.return_value.filter.return_value.all.return_value = []
    session.query.return_value.order_by.return_value.limit.return_value.all.return_value = []
    session.query.return_value.scalar.return_value = 0
    session.query.return_value.filter.return_value.scalar.return_value = 0
    session.query.return_value.group_by.return_value.all.return_value = []
    return session


@pytest.fixture
def client(mock_db_session):
    """FastAPI TestClient with the DB dependency overridden."""
    from fastapi.testclient import TestClient

    from db.session import get_db
    from main import app

    app.dependency_overrides[get_db] = lambda: mock_db_session
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
