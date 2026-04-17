"""
Create all tables and enable PostGIS extension.
Run: python -m db.init_db
"""
from sqlalchemy import text

from db.models import Base
from db.session import engine


def init_db() -> None:
    with engine.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))

    Base.metadata.create_all(bind=engine)
    print(f"Created tables: {', '.join(Base.metadata.tables.keys())}")


if __name__ == "__main__":
    init_db()
