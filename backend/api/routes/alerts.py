from fastapi import APIRouter

router = APIRouter()


@router.get("")
async def get_alerts():
    # TODO: query alerts table, return active alerts sorted by triggered_at desc
    return {"alerts": []}
