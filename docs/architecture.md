# ReflectScan — System Architecture

## Overview

ReflectScan is a two-component system for automated retroreflectivity measurement across national highway networks. A smartphone mounted on any patrol vehicle collects data while driving. A web dashboard gives highway authorities a real-time view of road marking health across the entire network.

---

## System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     PATROL VEHICLE                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 Flutter Mobile App                        │  │
│  │                                                           │  │
│  │  Camera Feed → YOLOv8n (TFLite) → Marking Detection      │  │
│  │       ↓                                                   │  │
│  │  LED Flash (40Hz sync) → Illuminated + Ambient Frames     │  │
│  │       ↓                                                   │  │
│  │  OECF Calibration → Luminance Delta → RL (mcd/m²/lux)    │  │
│  │       ↓                                                   │  │
│  │  GPS Tag → SQLite (offline) → Upload Queue               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────┬───────────────────────────────────┘
                              │ REST API (batch upload)
                              │ WiFi / 4G
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND SERVER                             │
│                                                                 │
│  FastAPI ──→ PostgreSQL + PostGIS                               │
│                                                                 │
│  • Ingest measurements                                          │
│  • Aggregate into 100m highway segments                         │
│  • Generate CRITICAL / WARNING alerts                           │
│  • Serve dashboard API                                          │
└─────────────────────────────┬───────────────────────────────────┘
                              │ REST API + WebSocket
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    WEB DASHBOARD                                │
│                                                                 │
│  Next.js + Mapbox GL JS + deck.gl                               │
│                                                                 │
│  • Highway map: segments colored green / yellow / red           │
│  • Heatmap of critical zones                                    │
│  • Alert feed (real-time)                                       │
│  • Segment detail + RL history chart                            │
│  • PDF / CSV export for maintenance teams                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component 1: Flutter Mobile App

### Responsibilities
- Capture road marking retroreflectivity while driving
- Run AI detection on-device (no internet required for detection)
- Store data offline and sync when connected

### Module Breakdown

```
mobile/
├── core/
│   ├── camera/
│   │   ├── camera_controller.dart      # Raw frame capture (CameraImage)
│   │   └── flash_controller.dart       # LED strobe at 40Hz via platform channel
│   ├── measurement/
│   │   ├── oecf_calibrator.dart        # Pixel → luminance (cd/m²) conversion
│   │   ├── luminance_analyzer.dart     # Illuminated frame minus ambient frame
│   │   └── rl_calculator.dart          # Luminance delta → mcd/m²/lux
│   ├── ai/
│   │   └── yolov8_detector.dart        # TFLite inference, bounding boxes
│   └── gps/
│       └── location_service.dart       # 1Hz GPS sampling, lat/lng/speed
├── data/
│   ├── local/
│   │   └── measurement_dao.dart        # SQLite via sqflite
│   └── remote/
│       └── upload_client.dart          # Batch POST to backend, retry logic
├── ui/
│   ├── survey/
│   │   ├── survey_screen.dart          # Camera preview + live RL overlay
│   │   └── session_manager.dart        # Start/stop survey, session metadata
│   └── history/
│       └── sessions_screen.dart        # Past surveys, upload status
└── main.dart
```

### Key Technical Decisions

| Decision | Choice | Reason |
|---|---|---|
| AI runtime | TFLite (FP16) | Official Ultralytics support, runs at ≥15 FPS on mid-range phones |
| Camera frames | `CameraImage` (YUV420) | Direct raw pixel access needed for luminance calculation |
| Flash sync | Platform channel → Android `CameraDevice` API | Only native API supports per-frame flash timing |
| Offline storage | SQLite (`sqflite`) | Works with zero connectivity on rural highways |
| State management | Riverpod | Predictable, testable, no boilerplate |

### Measurement Pipeline

```
Frame N (flash ON)  ─→ Detect markings (YOLO) ─→ Extract ROI pixels
Frame N+1 (flash OFF) ─→ Same ROI pixels (ambient)
                              ↓
                    Delta = Illuminated − Ambient
                              ↓
                    OECF lookup: pixel value → cd/m²
                              ↓
                    RL = (luminance × geometry_constant) / lux_input
                              ↓
                    Classify: >100 SAFE | 54–100 WARNING | <54 CRITICAL
```

---

## Component 2: FastAPI Backend

### Responsibilities
- Receive and store measurement data from mobile app
- Aggregate raw points into 100m highway segments
- Generate and store alerts when thresholds are crossed
- Serve all data to the web dashboard

### Module Breakdown

```
backend/
├── api/
│   ├── routes/
│   │   ├── measurements.py     # POST /measurements (batch ingest)
│   │   ├── segments.py         # GET /segments, GET /segments/{id}
│   │   ├── alerts.py           # GET /alerts
│   │   └── export.py           # GET /export/csv, GET /export/pdf
│   └── schemas/
│       ├── measurement.py      # Pydantic input model
│       ├── segment.py          # Pydantic output model
│       └── alert.py            # Pydantic alert model
├── services/
│   ├── aggregation.py          # Group points → 100m segments, compute avg/min/max RL
│   └── alert_engine.py         # Threshold check, create alert records
├── db/
│   ├── models.py               # SQLAlchemy ORM models
│   ├── session.py              # DB connection
│   └── migrations/             # Alembic migration files
└── main.py
```

### Database Schema

```sql
-- Raw measurement points from phone
CREATE TABLE measurements (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID NOT NULL,
    highway     VARCHAR(20),
    location    GEOMETRY(Point, 4326) NOT NULL,   -- PostGIS
    rl_value    FLOAT NOT NULL,                    -- mcd/m²/lux
    status      VARCHAR(10) NOT NULL,              -- SAFE | WARNING | CRITICAL
    speed_kmh   FLOAT,
    captured_at TIMESTAMPTZ NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Aggregated 100m highway segments
CREATE TABLE segments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    highway     VARCHAR(20) NOT NULL,
    path        GEOMETRY(LineString, 4326) NOT NULL,
    rl_avg      FLOAT,
    rl_min      FLOAT,
    rl_max      FLOAT,
    status      VARCHAR(10),                       -- dominant status
    point_count INT,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Alerts for critical/warning segments
CREATE TABLE alerts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_id  UUID REFERENCES segments(id),
    highway     VARCHAR(20),
    rl_value    FLOAT NOT NULL,
    status      VARCHAR(10) NOT NULL,
    location    GEOMETRY(Point, 4326),
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Survey sessions from mobile app
CREATE TABLE sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  VARCHAR(50),
    surveyor    VARCHAR(100),
    highway     VARCHAR(20),
    started_at  TIMESTAMPTZ,
    ended_at    TIMESTAMPTZ,
    total_points INT DEFAULT 0
);

CREATE INDEX ON measurements USING GIST(location);
CREATE INDEX ON segments USING GIST(path);
CREATE INDEX ON measurements(status);
CREATE INDEX ON alerts(triggered_at DESC);
```

### API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/measurements` | Batch upload from mobile app |
| `GET` | `/api/segments` | All segments with RL scores (GeoJSON) |
| `GET` | `/api/segments/{id}` | Single segment detail + history |
| `GET` | `/api/alerts` | Active alerts, sorted by severity |
| `GET` | `/api/stats` | Network-level summary KPIs |
| `GET` | `/api/export/csv` | Download CSV report |
| `GET` | `/api/export/pdf` | Download PDF maintenance report |

### Request / Response Shapes

```json
// POST /api/measurements
{
  "session_id": "uuid",
  "measurements": [
    {
      "lat": 28.6139,
      "lng": 77.2090,
      "rl_value": 87.3,
      "status": "WARNING",
      "speed_kmh": 72.4,
      "highway": "NH-48",
      "captured_at": "2026-04-17T10:30:00Z"
    }
  ]
}

// GET /api/segments
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[77.209, 28.613], [77.211, 28.614]]
      },
      "properties": {
        "id": "seg_001",
        "highway": "NH-48",
        "rl_avg": 87.3,
        "rl_min": 42.1,
        "rl_max": 134.5,
        "status": "WARNING",
        "last_updated": "2026-04-17T10:30:00Z"
      }
    }
  ]
}

// GET /api/alerts
{
  "alerts": [
    {
      "id": "alert_001",
      "segment_id": "seg_001",
      "highway": "NH-48",
      "rl_value": 42.1,
      "status": "CRITICAL",
      "lat": 28.613,
      "lng": 77.209,
      "triggered_at": "2026-04-17T10:30:00Z"
    }
  ]
}

// GET /api/stats
{
  "total_km_surveyed": 247.3,
  "segments": {
    "total": 2473,
    "safe": 1820,
    "warning": 412,
    "critical": 241
  },
  "network_rl_avg": 89.4,
  "active_alerts": 18
}
```

---

## Component 3: Web Dashboard

### Responsibilities
- Visualize highway network health on an interactive map
- Surface critical alerts in real-time
- Allow drill-down into individual segments
- Export reports for maintenance teams

### Module Breakdown

```
dashboard/
├── app/
│   ├── page.tsx                    # Root → redirects to /map
│   ├── map/
│   │   └── page.tsx                # Main map view
│   ├── alerts/
│   │   └── page.tsx                # Full alerts list
│   └── export/
│       └── page.tsx                # Report generation
├── components/
│   ├── map/
│   │   ├── HighwayMap.tsx          # Mapbox GL JS base map
│   │   ├── SegmentLayer.tsx        # deck.gl PathLayer (green/yellow/red)
│   │   └── HeatmapLayer.tsx        # deck.gl HeatmapLayer for density
│   ├── panels/
│   │   ├── AlertFeed.tsx           # Real-time alert list
│   │   ├── SegmentDetail.tsx       # Click segment → RL chart + photos
│   │   └── StatsPanel.tsx          # Network KPI summary
│   └── export/
│       └── ReportExport.tsx        # CSV / PDF download buttons
├── lib/
│   ├── api.ts                      # Typed fetch wrappers for backend
│   └── colors.ts                   # RL value → color mapping
└── hooks/
    ├── useSegments.ts              # SWR hook for segment GeoJSON
    └── useAlerts.ts               # SWR hook with 30s polling
```

### Color Coding

```typescript
// lib/colors.ts
export function rlToColor(rl: number): [number, number, number, number] {
  if (rl > 100) return [34, 197, 94, 220];    // green  — SAFE
  if (rl > 54)  return [251, 191, 36, 220];   // yellow — WARNING
  return [239, 68, 68, 220];                   // red    — CRITICAL
}
```

### Map Layer Stack (bottom to top)

```
1. Mapbox satellite base map
2. deck.gl HeatmapLayer     — density of measurements
3. deck.gl PathLayer        — highway segments colored by RL
4. Mapbox marker layer      — alert pin markers
5. React panel overlays     — stats, alert feed, segment detail
```

---

## Data Flow

### Survey Flow (Mobile → Backend)

```
Driver starts survey session
        ↓
Phone camera + flash running at 40Hz
        ↓
YOLOv8n detects road marking in frame
        ↓
Luminance analysis → RL value computed
        ↓
GPS coordinate attached
        ↓
Record saved to SQLite (works offline)
        ↓
[When WiFi/4G available]
        ↓
Batch upload → POST /api/measurements
        ↓
Backend aggregates into 100m segments
        ↓
Alert engine checks thresholds
        ↓
Dashboard updates via polling (30s)
```

### Dashboard View Flow

```
User opens dashboard
        ↓
GET /api/segments → GeoJSON loaded
        ↓
deck.gl PathLayer renders segments (color by RL)
        ↓
GET /api/alerts → Alert feed populated
        ↓
GET /api/stats → KPI panel updated
        ↓
User clicks segment
        ↓
GET /api/segments/{id} → Detail panel opens
        ↓
RL history chart + photos shown
```

---

## Technology Stack Summary

| Layer | Technology | Version |
|---|---|---|
| Mobile | Flutter | 3.x |
| Mobile AI | YOLOv8n → TFLite (FP16) | Ultralytics 8.x |
| Mobile state | Riverpod | 2.x |
| Mobile storage | sqflite (SQLite) | 2.x |
| Backend | FastAPI | 0.110+ |
| Backend ORM | SQLAlchemy + Alembic | 2.x |
| Database | PostgreSQL 16 + PostGIS 3 | — |
| Web framework | Next.js (App Router) | 14.x |
| Web map | Mapbox GL JS | 3.x |
| Web visualization | deck.gl | 9.x |
| Web styling | Tailwind CSS + ShadcnUI | — |
| Web data fetching | SWR | 2.x |

---

## RL Safety Thresholds

| RL Value (mcd/m²/lux) | Status | Color | Action |
|---|---|---|---|
| > 100 | SAFE | Green | No action |
| 54 – 100 | WARNING | Yellow | Schedule maintenance |
| < 54 | CRITICAL | Red | Immediate resurfacing |

Source: *Impact of Road Marking Retroreflectivity on Machine Vision* (PMC8963044, 2022)

---

## Deployment (Hackathon)

```
Mobile App      → APK sideloaded on Android demo phone
Backend         → Single VPS (2 vCPU, 4GB RAM) or Railway.app
Dashboard       → Vercel (free tier)
Database        → Supabase free tier (PostgreSQL + PostGIS)
Demo data       → NH-48 seed script pre-loaded
```
