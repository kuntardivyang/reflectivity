from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ── Inbound (mobile app → backend) ───────────────────────────────

class MeasurementIn(BaseModel):
    lat:         float = Field(..., ge=-90, le=90)
    lng:         float = Field(..., ge=-180, le=180)
    rl_value:    float = Field(..., ge=0, le=4000, description="mcd/m²/lux")
    status:      str   = Field(..., pattern="^(SAFE|WARNING|CRITICAL|UNCAL)$")
    speed_kmh:   Optional[float] = None
    highway:     Optional[str]   = None
    captured_at: datetime


class BatchUploadIn(BaseModel):
    session_id:   UUID
    measurements: List[MeasurementIn] = Field(..., min_length=1, max_length=500)


# ── Outbound (backend → dashboard) ───────────────────────────────

class SegmentProperties(BaseModel):
    id:           UUID
    highway:      str
    rl_avg:       Optional[float]
    rl_min:       Optional[float]
    rl_max:       Optional[float]
    status:       Optional[str]
    point_count:  int
    last_updated: Optional[datetime]


class GeoPoint(BaseModel):
    type:        str = "Point"
    coordinates: List[float]          # [lng, lat]


class GeoLineString(BaseModel):
    type:        str = "LineString"
    coordinates: List[List[float]]    # [[lng, lat], ...]


class SegmentFeature(BaseModel):
    type:       str = "Feature"
    geometry:   GeoLineString
    properties: SegmentProperties


class SegmentCollection(BaseModel):
    type:     str = "FeatureCollection"
    features: List[SegmentFeature]


class AlertOut(BaseModel):
    id:           UUID
    segment_id:   Optional[UUID]
    highway:      Optional[str]
    rl_value:     float
    status:       str
    lat:          Optional[float]
    lng:          Optional[float]
    triggered_at: datetime

    model_config = {"from_attributes": True}


class StatsOut(BaseModel):
    total_km_surveyed: float
    total_segments:    int
    safe_count:        int
    warning_count:     int
    critical_count:    int
    network_rl_avg:    Optional[float]
    active_alerts:     int
