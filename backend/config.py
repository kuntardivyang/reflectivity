import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://reflectscan:reflectscan@localhost:5432/reflectscan",
)

RL_SAFE_THRESHOLD     = 100.0   # mcd/m²/lux
RL_WARNING_THRESHOLD  = 54.0
SEGMENT_LENGTH_METERS = 100

DEBUG = os.getenv("DEBUG", "false").lower() == "true"
