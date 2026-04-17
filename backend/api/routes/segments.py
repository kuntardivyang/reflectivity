from fastapi import APIRouter, Depends, HTTPException
from geoalchemy2.shape import to_shape
from sqlalchemy.orm import Session

from db.models import Segment
from db.session import get_db

router = APIRouter()


@router.get("")
def get_segments(db: Session = Depends(get_db)):
    """Return all highway segments as a GeoJSON FeatureCollection."""
    segments = db.query(Segment).all()

    features = []
    for s in segments:
        line = to_shape(s.path)
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "LineString",
                "coordinates": [[pt[0], pt[1]] for pt in line.coords],
            },
            "properties": {
                "id":           str(s.id),
                "highway":      s.highway,
                "rl_avg":       round(s.rl_avg, 1) if s.rl_avg is not None else None,
                "rl_min":       round(s.rl_min, 1) if s.rl_min is not None else None,
                "rl_max":       round(s.rl_max, 1) if s.rl_max is not None else None,
                "status":       s.status,
                "point_count":  s.point_count,
                "last_updated": s.last_updated.isoformat() if s.last_updated else None,
            },
        })

    return {"type": "FeatureCollection", "features": features}


@router.get("/{segment_id}")
def get_segment(segment_id: str, db: Session = Depends(get_db)):
    """Return a single segment with its aggregated stats."""
    segment = db.query(Segment).filter(Segment.id == segment_id).first()
    if segment is None:
        raise HTTPException(status_code=404, detail="Segment not found")

    line = to_shape(segment.path)
    return {
        "id":           str(segment.id),
        "highway":      segment.highway,
        "coordinates":  [[pt[0], pt[1]] for pt in line.coords],
        "rl_avg":       round(segment.rl_avg, 1) if segment.rl_avg else None,
        "rl_min":       round(segment.rl_min, 1) if segment.rl_min else None,
        "rl_max":       round(segment.rl_max, 1) if segment.rl_max else None,
        "status":       segment.status,
        "point_count":  segment.point_count,
        "last_updated": segment.last_updated.isoformat() if segment.last_updated else None,
    }
