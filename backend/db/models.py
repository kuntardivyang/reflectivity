import uuid
from datetime import datetime

from geoalchemy2 import Geometry
from sqlalchemy import Column, Float, ForeignKey, Integer, String, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, relationship
from sqlalchemy.sql import func


class Base(DeclarativeBase):
    pass


class Session(Base):
    __tablename__ = "sessions"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vehicle_id  = Column(String(50))
    surveyor    = Column(String(100))
    highway     = Column(String(20))
    started_at  = Column(TIMESTAMP(timezone=True))
    ended_at    = Column(TIMESTAMP(timezone=True))
    total_points = Column(Integer, default=0)

    measurements = relationship("Measurement", back_populates="session")


class Measurement(Base):
    __tablename__ = "measurements"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id  = Column(UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False)
    highway     = Column(String(20))
    location    = Column(Geometry("POINT", srid=4326), nullable=False)
    rl_value    = Column(Float, nullable=False)   # mcd/m²/lux
    status      = Column(String(10), nullable=False)  # SAFE | WARNING | CRITICAL
    speed_kmh   = Column(Float)
    captured_at = Column(TIMESTAMP(timezone=True), nullable=False)
    uploaded_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    session = relationship("Session", back_populates="measurements")


class Segment(Base):
    __tablename__ = "segments"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    highway     = Column(String(20), nullable=False)
    path        = Column(Geometry("LINESTRING", srid=4326), nullable=False)
    rl_avg      = Column(Float)
    rl_min      = Column(Float)
    rl_max      = Column(Float)
    status      = Column(String(10))   # dominant status across segment
    point_count = Column(Integer, default=0)
    last_updated = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    alerts = relationship("Alert", back_populates="segment")


class Alert(Base):
    __tablename__ = "alerts"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    segment_id   = Column(UUID(as_uuid=True), ForeignKey("segments.id"))
    highway      = Column(String(20))
    rl_value     = Column(Float, nullable=False)
    status       = Column(String(10), nullable=False)
    location     = Column(Geometry("POINT", srid=4326))
    triggered_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    resolved_at  = Column(TIMESTAMP(timezone=True), nullable=True)

    segment = relationship("Segment", back_populates="alerts")
