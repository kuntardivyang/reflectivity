"""Tests for retroreflectivity safety classification thresholds."""
import pytest

from services.aggregation import classify


@pytest.mark.parametrize(
    "rl, expected",
    [
        (0,     "CRITICAL"),
        (30,    "CRITICAL"),
        (53.9,  "CRITICAL"),
        (54.0,  "CRITICAL"),   # boundary: > 54 required for WARNING
        (54.1,  "WARNING"),
        (75,    "WARNING"),
        (100.0, "WARNING"),    # boundary: > 100 required for SAFE
        (100.1, "SAFE"),
        (250,   "SAFE"),
        (4000,  "SAFE"),
    ],
)
def test_classify_thresholds(rl, expected):
    assert classify(rl) == expected
