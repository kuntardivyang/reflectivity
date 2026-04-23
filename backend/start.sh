#!/bin/bash
set -e

echo "Initialising database…"
python -m db.init_db

echo "Seeding demo data…"
python -m scripts.seed_nh48

echo "Starting API server…"
exec uvicorn main:app --host 0.0.0.0 --port "${PORT:-8000}"
