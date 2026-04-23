import os
from dotenv import load_dotenv

load_dotenv()

_raw = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://reflectscan:reflectscan@localhost:5432/reflectscan",
)
# Railway supplies postgres:// or postgresql:// without the driver qualifier.
if _raw.startswith("postgres://"):
    _raw = _raw.replace("postgres://", "postgresql+psycopg2://", 1)
elif _raw.startswith("postgresql://"):
    _raw = _raw.replace("postgresql://", "postgresql+psycopg2://", 1)

DATABASE_URL = _raw

RL_SAFE_THRESHOLD     = 100.0   # mcd/m²/lux
RL_WARNING_THRESHOLD  = 54.0
SEGMENT_LENGTH_METERS = 100

DEBUG = os.getenv("DEBUG", "false").lower() == "true"
