"""
Seed the database with realistic NH-48 (Delhi-Mumbai) demo data.

Generates:
  - 1 survey session
  - ~500 measurements spanning Delhi → Mumbai waypoints
  - ~100 aggregated highway segments
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


# Approximate NH-48 waypoints Delhi → Mumbai (lng, lat)
NH48_WAYPOINTS = [
    (77.2090, 28.6139),  # Delhi
    (77.0266, 28.4595),  # Gurgaon
    (76.9600, 28.4000),
    (76.5000, 27.9000),
    (75.7873, 26.9124),  # Jaipur
    (74.6399, 26.4499),  # Ajmer
    (73.7125, 24.5854),  # Udaipur
    (73.0000, 23.5000),
    (72.5714, 23.0225),  # Ahmedabad
    (73.1812, 22.3072),  # Vadodara
    (72.8311, 21.1702),  # Surat
    (72.9000, 20.0000),
    (72.8777, 19.0760),  # Mumbai
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
    """Generate a realistic RL distribution: mostly safe, some warning, few critical."""
    r = random.random()
    if r < 0.65:
        return random.uniform(100, 250)     # SAFE
    elif r < 0.90:
        return random.uniform(54, 100)      # WARNING
    else:
        return random.uniform(20, 54)       # CRITICAL


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
        surveyor="Demo Driver",
        highway="NH-48",
        started_at=datetime.now(timezone.utc) - timedelta(hours=8),
        ended_at=datetime.now(timezone.utc) - timedelta(hours=1),
    )
    db.add(session)

    print("Generating measurement points...")
    points = interpolate_points(NH48_WAYPOINTS, n_per_segment=40)
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
            speed_kmh=random.uniform(60, 90),
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
            alerts.append(Alert(
                segment_id=seg.id,
                highway=seg.highway,
                rl_value=seg.rl_avg,
                status=seg.status,
                location=from_shape(Point(points[segments.index(seg) * chunk_size]), srid=4326),
            ))
    db.add_all(alerts)

    db.commit()
    print(f"✓ Seeded {len(measurements)} measurements, {len(segments)} segments, {len(alerts)} alerts")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        seed(db)
    finally:
        db.close()
