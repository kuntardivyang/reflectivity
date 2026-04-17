from fastapi import APIRouter, Depends, status
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy.orm import Session

from api.schemas import BatchUploadIn
from db.models import Measurement
from db.session import get_db
from services.aggregation import aggregate_measurements
from services.alert_engine import evaluate_segments

router = APIRouter()


@router.post("", status_code=status.HTTP_202_ACCEPTED)
def ingest_measurements(payload: BatchUploadIn, db: Session = Depends(get_db)):
    """
    Receive a batch of retroreflectivity measurements from the mobile app.

    Pipeline:
      1. Persist each measurement with its PostGIS point geometry
      2. Aggregate the batch into ~100m highway segments
      3. Run the alert engine on newly-created WARNING/CRITICAL segments
    """
    measurements = [
        Measurement(
            session_id=payload.session_id,
            highway=m.highway,
            location=from_shape(Point(m.lng, m.lat), srid=4326),
            rl_value=m.rl_value,
            status=m.status,
            speed_kmh=m.speed_kmh,
            captured_at=m.captured_at,
        )
        for m in payload.measurements
    ]
    db.add_all(measurements)
    db.flush()

    measurements.sort(key=lambda m: m.captured_at)
    segments = aggregate_measurements(db, measurements)
    alerts   = evaluate_segments(db, segments)

    db.commit()

    return {
        "accepted":        len(measurements),
        "segments_created": len(segments),
        "alerts_created":   len(alerts),
        "session_id":      str(payload.session_id),
    }
