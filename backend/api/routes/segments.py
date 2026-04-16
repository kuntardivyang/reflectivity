from fastapi import APIRouter

router = APIRouter()


@router.get("")
async def get_segments():
    # TODO: query PostGIS segments table, return GeoJSON FeatureCollection
    return {"type": "FeatureCollection", "features": []}


@router.get("/{segment_id}")
async def get_segment(segment_id: str):
    # TODO: return single segment with RL history
    return {}
