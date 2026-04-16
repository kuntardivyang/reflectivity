from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import measurements, segments, alerts, stats

app = FastAPI(
    title="ReflectScan API",
    description="Retroreflectivity measurement backend for national highway monitoring",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(measurements.router, prefix="/api/measurements", tags=["measurements"])
app.include_router(segments.router,    prefix="/api/segments",    tags=["segments"])
app.include_router(alerts.router,      prefix="/api/alerts",      tags=["alerts"])
app.include_router(stats.router,       prefix="/api/stats",       tags=["stats"])


@app.get("/health")
def health():
    return {"status": "ok"}
