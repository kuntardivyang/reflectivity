from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from db.models import Alert, Segment
from db.session import get_db

router = APIRouter()


@router.get("")
def get_stats(db: Session = Depends(get_db)):
    """Network-level KPI summary for the dashboard stats panel."""
    total_segments = db.query(func.count(Segment.id)).scalar() or 0

    status_counts = dict(
        db.query(Segment.status, func.count(Segment.id)).group_by(Segment.status).all()
    )

    network_rl_avg = db.query(func.avg(Segment.rl_avg)).scalar()

    total_points = db.query(func.sum(Segment.point_count)).scalar() or 0

    active_alerts = (
        db.query(func.count(Alert.id)).filter(Alert.resolved_at.is_(None)).scalar() or 0
    )

    # Rough km estimate: each segment is ~100m
    total_km_surveyed = total_segments * 0.1

    return {
        "total_km_surveyed": round(total_km_surveyed, 1),
        "total_segments":    total_segments,
        "total_points":      total_points,
        "safe_count":        status_counts.get("SAFE", 0),
        "warning_count":     status_counts.get("WARNING", 0),
        "critical_count":    status_counts.get("CRITICAL", 0),
        "network_rl_avg":    round(network_rl_avg, 1) if network_rl_avg else None,
        "active_alerts":     active_alerts,
    }
