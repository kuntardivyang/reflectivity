"""
Alert engine.

Triggers an alert whenever a newly-aggregated segment falls below the
SAFE retroreflectivity threshold. Skips segments that already have an
unresolved alert to avoid duplicates.
"""
from geoalchemy2.shape import to_shape
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy.orm import Session

from db.models import Alert, Segment


def evaluate_segments(db: Session, segments: list[Segment]) -> list[Alert]:
    """Create Alert rows for WARNING or CRITICAL segments without an existing active alert."""
    new_alerts: list[Alert] = []

    for seg in segments:
        if seg.status == "SAFE":
            continue

        existing = (
            db.query(Alert)
            .filter(Alert.segment_id == seg.id, Alert.resolved_at.is_(None))
            .first()
        )
        if existing is not None:
            continue

        midpoint = _segment_midpoint(seg)
        alert = Alert(
            segment_id=seg.id,
            highway=seg.highway,
            rl_value=seg.rl_avg,
            status=seg.status,
            location=midpoint,
        )
        db.add(alert)
        new_alerts.append(alert)

    if new_alerts:
        db.flush()
    return new_alerts


def _segment_midpoint(segment: Segment):
    """Return the geographic midpoint of the segment's path as a PostGIS Point."""
    line = to_shape(segment.path)
    mid = line.interpolate(0.5, normalized=True)
    return from_shape(Point(mid.x, mid.y), srid=4326)
