# ReflectScan Dashboard

Next.js + react-leaflet dashboard that visualises retroreflectivity data
from the FastAPI backend. Built for the 6th NHAI Innovation Hackathon 2026.

## Setup

Requires Node 18+.

```bash
cd dashboard
npm install
npm run dev      # http://localhost:3000
```

The dev server proxies `/api/*` to `http://localhost:8000/api/*`, so make
sure the backend is running:

```bash
cd ../backend
source .venv/bin/activate
uvicorn main:app --reload
```

## What you see

- **Live map** (OpenStreetMap tiles, no API key needed) of all segments,
  colour-coded by status: green SAFE, amber WARNING, red CRITICAL, grey
  UNCAL.
- **KPI panel** (left): per-status counts, segment count, highway count.
  Auto-refreshes every 15 seconds.
- **Alert feed** (right): chronological list of WARNING and CRITICAL
  segments raised by the backend alert engine.

## Why Leaflet, not Mapbox

Leaflet + OSM tiles requires no API key and no billing setup, so the
dashboard works the moment you `npm run dev`. The same component layout
ports to Mapbox GL by replacing the `<MapContainer>` in `MapPane.jsx`
once an NHAI Mapbox token is provisioned.
