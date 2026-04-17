from fastapi import APIRouter, Depends, Query
from geoalchemy2.shape import to_shape
from sqlalchemy.orm import Session

from db.models import Alert
from db.session import get_db

router = APIRouter()


@router.get("")
def get_alerts(
    db: Session = Depends(get_db),
    active_only: bool = Query(True, description="Return only unresolved alerts"),
    limit: int = Query(100, ge=1, le=1000),
):
    """Return alerts sorted by triggered_at descending (most recent first)."""
    query = db.query(Alert)
    if active_only:
        query = query.filter(Alert.resolved_at.is_(None))
    alerts = query.order_by(Alert.triggered_at.desc()).limit(limit).all()

    out = []
    for a in alerts:
        lng, lat = None, None
        if a.location is not None:
            point = to_shape(a.location)
            lng, lat = point.x, point.y

        out.append({
            "id":           str(a.id),
            "segment_id":   str(a.segment_id) if a.segment_id else None,
            "highway":      a.highway,
            "rl_value":     round(a.rl_value, 1),
            "status":       a.status,
            "lat":          lat,
            "lng":          lng,
            "triggered_at": a.triggered_at.isoformat() if a.triggered_at else None,
            "resolved_at":  a.resolved_at.isoformat() if a.resolved_at else None,
        })

    return {"alerts": out, "count": len(out)}
