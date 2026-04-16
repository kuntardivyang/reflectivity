from fastapi import APIRouter, HTTPException, status

from api.schemas import BatchUploadIn

router = APIRouter()


@router.post("", status_code=status.HTTP_202_ACCEPTED)
async def ingest_measurements(payload: BatchUploadIn):
    """
    Receive a batch of retroreflectivity measurements from the mobile app.

    The mobile app sends up to 500 records per request after a survey session.
    Each record contains the RL value, GPS coordinates, and safety status.
    """
    # TODO: write to DB via repository layer (tomorrow)
    # TODO: trigger segment aggregation job
    # TODO: run alert engine on new critical measurements

    return {
        "accepted": len(payload.measurements),
        "session_id": str(payload.session_id),
    }
