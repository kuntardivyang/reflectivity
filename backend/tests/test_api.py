"""Smoke tests for FastAPI endpoints using a mocked DB session."""


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_get_segments_empty(client):
    r = client.get("/api/segments")
    assert r.status_code == 200
    body = r.json()
    assert body["type"] == "FeatureCollection"
    assert body["features"] == []


def test_get_alerts_empty(client):
    r = client.get("/api/alerts")
    assert r.status_code == 200
    body = r.json()
    assert body["alerts"] == []
    assert body["count"] == 0


def test_get_stats_zero(client):
    r = client.get("/api/stats")
    assert r.status_code == 200
    body = r.json()
    assert body["total_segments"] == 0
    assert body["safe_count"] == 0
    assert body["warning_count"] == 0
    assert body["critical_count"] == 0
    assert body["active_alerts"] == 0


def test_measurement_validation_rejects_bad_lat(client):
    r = client.post(
        "/api/measurements",
        json={
            "session_id": "00000000-0000-0000-0000-000000000000",
            "measurements": [{
                "lat":         999,            # out of range
                "lng":         77.0,
                "rl_value":    85.0,
                "status":      "WARNING",
                "captured_at": "2026-04-17T10:00:00Z",
            }],
        },
    )
    assert r.status_code == 422


def test_measurement_validation_rejects_bad_status(client):
    r = client.post(
        "/api/measurements",
        json={
            "session_id": "00000000-0000-0000-0000-000000000000",
            "measurements": [{
                "lat":         28.6,
                "lng":         77.2,
                "rl_value":    85.0,
                "status":      "DANGER",        # not in enum
                "captured_at": "2026-04-17T10:00:00Z",
            }],
        },
    )
    assert r.status_code == 422


def test_measurement_validation_rejects_empty_batch(client):
    r = client.post(
        "/api/measurements",
        json={
            "session_id":   "00000000-0000-0000-0000-000000000000",
            "measurements": [],
        },
    )
    assert r.status_code == 422
