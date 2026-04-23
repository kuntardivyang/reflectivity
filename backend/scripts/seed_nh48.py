"""
Seed the database with realistic Ahmedabad-area demo data.

The route follows the NH-48 corridor through and around Ahmedabad — the
same area where the prototype's pipeline-validation drive was conducted
on 22 April 2026 (test point ~23.0969 N, 72.5601 E). Plotting demo data
here means the dashboard the judges open shows segments around the same
neighbourhood as the screenshots, instead of an unrelated stretch
1000 km away.

Generates:
  - 1 survey session
  - ~520 measurements along the SG Highway / Sardar Patel Ring Road /
    NH-48 corridor entering and exiting Ahmedabad
  - ~100 aggregated 100-m segments
  - Alerts for all WARNING and CRITICAL segments

Usage: python -m scripts.seed_nh48
"""
import random
import uuid
from datetime import datetime, timedelta, timezone

from geoalchemy2.shape import from_shape
from shapely.geometry import LineString, Point
from sqlalchemy.orm import Session

from config import RL_SAFE_THRESHOLD, RL_WARNING_THRESHOLD
from db.models import Alert, Measurement, Segment
from db.models import Session as SurveySession
from db.session import SessionLocal


# Ahmedabad corridor waypoints (lng, lat) — a plausible patrol route along
# NH-48 and SG Highway through Ahmedabad city. The route deliberately
# passes through ~23.097 N / 72.560 E — the prototype test location near
# Sabarmati / Naranpura — so screenshots and dashboard line up.
AHMEDABAD_WAYPOINTS = [
    (72.6369, 23.2156),  # Gandhinagar (north end of corridor)
    (72.6160, 23.1820),  # Adalaj
    (72.5950, 23.1500),  # Chandkheda
    (72.5800, 23.1200),  # Motera
    (72.5700, 23.1050),  # Sabarmati Riverfront north
    (72.5601, 23.0969),  # Naranpura / Sabarmati  ← prototype test point
    (72.5550, 23.0820),  # Vijay Char Rasta
    (72.5500, 23.0600),  # Navrangpura
    (72.5450, 23.0400),  # Ashram Road / Town Hall
    (72.5500, 23.0200),  # Maninagar
    (72.5650, 23.0000),  # Vatva
    (72.5800, 22.9700),  # Aslali (NH-48 outbound)
    (72.6000, 22.9300),  # Bareja
    (72.6300, 22.8800),  # Kheda district approach
]


def interpolate_points(waypoints: list[tuple[float, float]], n_per_segment: int = 40) -> list[tuple[float, float]]:
    """Linearly interpolate between waypoints to get dense GPS points."""
    points = []
    for i in range(len(waypoints) - 1):
        lng1, lat1 = waypoints[i]
        lng2, lat2 = waypoints[i + 1]
        for step in range(n_per_segment):
            t = step / n_per_segment
            points.append((lng1 + (lng2 - lng1) * t, lat1 + (lat2 - lat1) * t))
    points.append(waypoints[-1])
    return points


def random_rl() -> float:
    """Generate a realistic RL distribution: mostly safe, some warning, few critical.

    Distribution chosen so that after 100-m segment averaging the dashboard
    consistently shows a handful of CRITICAL (red) and WARNING (amber)
    segments mixed into a mostly SAFE corridor — reflects what an
    operational NH actually looks like and gives the alert feed something
    to display for the demo.
    """
    r = random.random()
    if r < 0.55:
        return random.uniform(110, 250)     # SAFE
    elif r < 0.80:
        return random.uniform(56, 100)      # WARNING
    else:
        return random.uniform(15, 50)       # CRITICAL


def classify(rl: float) -> str:
    if rl > RL_SAFE_THRESHOLD:
        return "SAFE"
    if rl > RL_WARNING_THRESHOLD:
        return "WARNING"
    return "CRITICAL"


def seed(db: Session) -> None:
    print("Clearing existing data...")
    db.query(Alert).delete()
    db.query(Segment).delete()
    db.query(Measurement).delete()
    db.query(SurveySession).delete()
    db.commit()

    session = SurveySession(
        id=uuid.uuid4(),
        vehicle_id="NHAI-PATROL-042",
        surveyor="Demo Driver — Ahmedabad RO",
        highway="NH-48",
        started_at=datetime.now(timezone.utc) - timedelta(hours=8),
        ended_at=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db.add(session)

    print("Generating measurement points along Ahmedabad NH-48 corridor...")
    points = interpolate_points(AHMEDABAD_WAYPOINTS, n_per_segment=40)
    now = datetime.now(timezone.utc)

    measurements = []
    for i, (lng, lat) in enumerate(points):
        rl = random_rl()
        m = Measurement(
            session_id=session.id,
            highway="NH-48",
            location=from_shape(Point(lng, lat), srid=4326),
            rl_value=rl,
            status=classify(rl),
            speed_kmh=random.uniform(35, 65),
            captured_at=now - timedelta(minutes=len(points) - i),
        )
        measurements.append(m)
    db.add_all(measurements)
    session.total_points = len(measurements)

    print(f"Aggregating {len(measurements)} points into segments...")
    segments = []
    chunk_size = 5  # 5 measurements ≈ 1 segment
    for i in range(0, len(measurements) - chunk_size, chunk_size):
        chunk = measurements[i:i + chunk_size]
        rls = [m.rl_value for m in chunk]
        coords = [(points[i + j][0], points[i + j][1]) for j in range(len(chunk))]

        rl_avg = sum(rls) / len(rls)
        seg = Segment(
            highway="NH-48",
            path=from_shape(LineString(coords), srid=4326),
            rl_avg=rl_avg,
            rl_min=min(rls),
            rl_max=max(rls),
            status=classify(rl_avg),
            point_count=len(chunk),
        )
        segments.append(seg)
    db.add_all(segments)
    db.flush()

    print("Generating alerts for WARNING and CRITICAL segments...")
    alerts = []
    for seg in segments:
        if seg.status in ("WARNING", "CRITICAL"):
            anchor = points[segments.index(seg) * chunk_size]
            alerts.append(Alert(
                segment_id=seg.id,
                highway=seg.highway,
                rl_value=seg.rl_avg,
                status=seg.status,
                location=from_shape(Point(anchor[0], anchor[1]), srid=4326),
            ))
    db.add_all(alerts)

    db.commit()
    print(f"✓ Seeded {len(measurements)} measurements, {len(segments)} segments, {len(alerts)} alerts")
    print(f"✓ Route centred on Ahmedabad — open dashboard at http://localhost:3000 to view")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        seed(db)
    finally:
        db.close()
