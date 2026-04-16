from fastapi import APIRouter

router = APIRouter()


@router.get("")
async def get_stats():
    # TODO: aggregate from segments + alerts tables
    return {
        "total_km_surveyed": 0,
        "total_segments": 0,
        "safe_count": 0,
        "warning_count": 0,
        "critical_count": 0,
        "network_rl_avg": None,
        "active_alerts": 0,
    }
