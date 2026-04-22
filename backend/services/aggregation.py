"""
Segment aggregation service.

Groups raw measurement points into ~100m highway segments and computes
per-segment retroreflectivity statistics (avg, min, max, dominant status).
"""
import math
import uuid
from collections import Counter
from typing import Iterable

from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import LineString, Point
from sqlalchemy.orm import Session

from config import RL_SAFE_THRESHOLD, RL_WARNING_THRESHOLD, SEGMENT_LENGTH_METERS
from db.models import Measurement, Segment


def classify(rl: float) -> str:
    if rl > RL_SAFE_THRESHOLD:
        return "SAFE"
    if rl > RL_WARNING_THRESHOLD:
        return "WARNING"
    return "CRITICAL"


def haversine_m(p1: Point, p2: Point) -> float:
    """Great-circle distance between two lat/lng points in meters."""
    lat1, lng1 = math.radians(p1.y), math.radians(p1.x)
    lat2, lng2 = math.radians(p2.y), math.radians(p2.x)
    dlat, dlng = lat2 - lat1, lng2 - lng1
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    return 2 * 6_371_000 * math.asin(math.sqrt(a))


def _chunk_by_distance(points: list[Point], max_meters: float) -> Iterable[list[int]]:
    """Yield index-chunks of points accumulating up to max_meters of path length."""
    start = 0
    running = 0.0
    for i in range(1, len(points)):
        running += haversine_m(points[i - 1], points[i])
        if running >= max_meters:
            yield list(range(start, i + 1))
            start = i
            running = 0.0
    if start < len(points) - 1:
        yield list(range(start, len(points)))


def aggregate_measurements(db: Session, measurements: list[Measurement]) -> list[Segment]:
    """
    Build Segment rows from a contiguous sequence of measurements.
    Caller is responsible for ordering by captured_at.
    """
    if len(measurements) < 2:
        return []

    points = [to_shape(m.location) for m in measurements]
    segments: list[Segment] = []

    for idxs in _chunk_by_distance(points, SEGMENT_LENGTH_METERS):
        chunk = [measurements[i] for i in idxs]
        chunk_points = [points[i] for i in idxs]

        # Uncalibrated points (no flash differential available) still
        # contribute a GPS trace for the segment path but must not drag
        # the RL average down — their rl_value is a placeholder zero.
        calibrated = [m for m in chunk if m.status != "UNCAL"]
        rls = [m.rl_value for m in calibrated]

        if rls:
            rl_avg = sum(rls) / len(rls)
            rl_min = min(rls)
            rl_max = max(rls)
            dominant_status = Counter(
                m.status for m in calibrated
            ).most_common(1)[0][0]
        else:
            rl_avg = rl_min = rl_max = None
            dominant_status = "UNCAL"

        segment = Segment(
            id=uuid.uuid4(),
            highway=chunk[0].highway,
            path=from_shape(LineString([(p.x, p.y) for p in chunk_points]), srid=4326),
            rl_avg=rl_avg,
            rl_min=rl_min,
            rl_max=rl_max,
            status=dominant_status,
            point_count=len(chunk),
        )
        db.add(segment)
        segments.append(segment)

    db.flush()
    return segments
