"""Unit tests for segment aggregation math (no DB required)."""
import math

from shapely.geometry import Point

from services.aggregation import _chunk_by_distance, haversine_m


def test_haversine_zero():
    p = Point(77.0, 28.0)
    assert haversine_m(p, p) == 0


def test_haversine_short_distance():
    # 1 degree latitude ≈ 111 km
    a = Point(77.0, 28.0)
    b = Point(77.0, 28.01)
    d = haversine_m(a, b)
    assert 1050 < d < 1150   # ~1110 m


def test_haversine_is_symmetric():
    a = Point(77.0, 28.0)
    b = Point(77.5, 28.5)
    assert math.isclose(haversine_m(a, b), haversine_m(b, a))


def test_chunk_by_distance_splits_at_threshold():
    # 10 points roughly 200m apart in latitude
    points = [Point(77.0, 28.0 + i * 0.0018) for i in range(10)]
    chunks = list(_chunk_by_distance(points, max_meters=100))
    # At 200m spacing with 100m threshold, every pair becomes its own chunk.
    assert len(chunks) >= 5
    for chunk in chunks:
        assert len(chunk) >= 2


def test_chunk_by_distance_short_path_single_chunk():
    # 3 points all within 10m of each other
    points = [
        Point(77.0, 28.0),
        Point(77.00001, 28.0),
        Point(77.00002, 28.0),
    ]
    chunks = list(_chunk_by_distance(points, max_meters=100))
    # No chunk boundary triggered, but the trailing remainder should flush.
    assert len(chunks) == 1
    assert chunks[0] == [0, 1, 2]
