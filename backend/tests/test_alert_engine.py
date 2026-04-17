"""Tests for the alert engine service."""
import uuid
from unittest.mock import MagicMock

from shapely.geometry import LineString
from geoalchemy2.shape import from_shape

from db.models import Segment
from services.alert_engine import evaluate_segments


def _segment(status: str, rl: float = 60.0) -> Segment:
    return Segment(
        id=uuid.uuid4(),
        highway="NH-48",
        path=from_shape(LineString([(77.0, 28.0), (77.01, 28.01)]), srid=4326),
        rl_avg=rl,
        rl_min=rl,
        rl_max=rl,
        status=status,
        point_count=5,
    )


def test_safe_segments_do_not_trigger_alerts():
    db = MagicMock()
    segments = [_segment("SAFE", 150)]
    alerts = evaluate_segments(db, segments)
    assert alerts == []


def test_warning_segment_creates_alert():
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None

    segments = [_segment("WARNING", 75)]
    alerts = evaluate_segments(db, segments)

    assert len(alerts) == 1
    assert alerts[0].status == "WARNING"
    assert alerts[0].rl_value == 75
    db.add.assert_called_once()


def test_critical_segment_creates_alert():
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None

    segments = [_segment("CRITICAL", 40)]
    alerts = evaluate_segments(db, segments)

    assert len(alerts) == 1
    assert alerts[0].status == "CRITICAL"


def test_duplicate_alert_is_skipped():
    db = MagicMock()
    existing = MagicMock(spec=["resolved_at"])
    db.query.return_value.filter.return_value.first.return_value = existing

    segments = [_segment("CRITICAL", 40)]
    alerts = evaluate_segments(db, segments)

    assert alerts == []
    db.add.assert_not_called()


def test_mixed_segments_only_alert_on_unsafe():
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None

    segments = [
        _segment("SAFE", 150),
        _segment("WARNING", 80),
        _segment("SAFE", 200),
        _segment("CRITICAL", 30),
    ]
    alerts = evaluate_segments(db, segments)
    assert len(alerts) == 2
    assert {a.status for a in alerts} == {"WARNING", "CRITICAL"}
