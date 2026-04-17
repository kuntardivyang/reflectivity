# ReflectScan

Smartphone-based retroreflectivity measurement for national highways.
Submission to the **6th NHAI Innovation Hackathon 2026**.

> Any patrol vehicle + any Android phone → live retroreflectivity data
> for the entire national highway network.

## Components

| Path           | Stack                                    | Status |
|----------------|------------------------------------------|--------|
| `backend/`     | FastAPI + PostgreSQL/PostGIS             | Working end-to-end, 27 tests passing |
| `mobile/`      | Flutter + TFLite + sqflite + geolocator  | Full pipeline wired |
| `dashboard/`   | Next.js + Mapbox + deck.gl               | Teammate's work |
| `docs/`        | Architecture, research, problem          | Complete |

## Quick Start

### 1. Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Postgres with PostGIS required. Local default:
#   DB:   reflectscan
#   user: reflectscan
#   pass: reflectscan

cp .env.example .env       # edit DATABASE_URL if needed
python -m db.init_db       # creates tables + enables postgis
python -m scripts.seed_nh48   # fills DB with Delhi→Mumbai demo data

uvicorn main:app --reload  # http://localhost:8000
```

Check: http://localhost:8000/health → `{"status":"ok"}`
Interactive docs: http://localhost:8000/docs

### 2. Backend Tests

```bash
cd backend
source .venv/bin/activate
pytest                     # 27 tests, <1s
```

### 3. Mobile — Android (Linux/Windows/Mac)

```bash
cd mobile
flutter create --platforms=android .   # one-time: generate android/ runtime files
flutter pub get
flutter run                            # with Android device plugged in
```

The `AndroidManifest.xml` with camera, location, and flash permissions
is already committed at `mobile/android/app/src/main/AndroidManifest.xml`.

**Point the app at your backend.** Edit `mobile/lib/core/config.dart`:
- Emulator: `http://10.0.2.2:8000` (default)
- Physical device: `http://<your-laptop-ip>:8000`

### 4. Mobile — iOS (Mac only)

```bash
cd mobile
flutter create --platforms=ios .
cd ios && pod install && cd ..
flutter run                            # with iPhone plugged in, signed in Xcode
```

The Info.plist with camera/location/motion permission strings is
already committed at `mobile/ios/Runner/Info.plist`.

Requirements: Xcode 15+, iOS 13+, physical iPhone (simulator has no
camera / GPS / flash).

### 5. Mobile Tests

```bash
cd mobile
flutter pub get
flutter test
```

### 6. TFLite Model

Place `yolov8n.tflite` in `mobile/assets/models/`. To export one:

```bash
pip install ultralytics
yolo export model=yolov8n.pt format=tflite half=True
# Grab yolov8n_saved_model/yolov8n_float16.tflite
# Rename to yolov8n.tflite and copy to mobile/assets/models/
```

For the hackathon demo you can fine-tune the model on a small road
marking dataset for better confidence, but the stock YOLOv8n weights
detect lane lines well enough to show the pipeline working.

## Architecture at a Glance

```
Patrol vehicle phone (Flutter)
  ↓ YOLOv8 detects markings, LED flash strobes at 40Hz
  ↓ Luminance delta → OECF → RL (mcd/m²/lux) → SAFE/WARNING/CRITICAL
  ↓ GPS-tagged, stored in SQLite, batch-uploaded
FastAPI backend
  ↓ Aggregates raw points into 100m highway segments
  ↓ Alert engine triggers on WARNING/CRITICAL
  ↓ Serves GeoJSON + alerts + stats
Next.js dashboard (teammate's work)
  → Mapbox + deck.gl map, green/yellow/red segments
  → Alert feed, KPI panel, CSV/PDF export
```

Full details in [`docs/architecture.md`](docs/architecture.md).

## Retroreflectivity Thresholds

| RL (mcd/m²/lux) | Status   | Action                |
|-----------------|----------|-----------------------|
| `> 100`         | SAFE     | No action             |
| `54 – 100`      | WARNING  | Schedule maintenance  |
| `< 54`          | CRITICAL | Immediate resurfacing |

Source: *Impact of Road Marking Retroreflectivity on Machine Vision
in Dry Conditions* (PMC8963044, 2022).

## Key API Endpoints

| Method | Path                  | Purpose                                |
|--------|-----------------------|----------------------------------------|
| GET    | `/health`             | Liveness probe                         |
| POST   | `/api/measurements`   | Batch ingest from mobile app           |
| GET    | `/api/segments`       | GeoJSON for dashboard map              |
| GET    | `/api/segments/{id}`  | Single segment detail                  |
| GET    | `/api/alerts`         | Active WARNING/CRITICAL alerts         |
| GET    | `/api/stats`          | Network-level KPI summary              |

## Repository Layout

```
reflectivity/
├── backend/                FastAPI + PostGIS API
│   ├── api/routes/         Endpoint handlers
│   ├── db/                 SQLAlchemy models + session
│   ├── services/           aggregation, alert engine
│   ├── scripts/seed_nh48.py  Delhi–Mumbai demo data
│   └── tests/              pytest suite (27 tests)
├── mobile/                 Flutter client
│   ├── lib/core/           camera, gps, measurement, ai
│   ├── lib/data/           models, local DB, API client
│   ├── lib/ui/survey/      live overlay screen + controller
│   ├── test/               Dart unit tests
│   └── assets/models/      yolov8n.tflite goes here
├── docs/
│   ├── problem_statement.md
│   ├── research_findings.md
│   ├── architecture.md
│   └── Additional_info_and_research.md
└── README.md
```

## Hackathon Context

- **Event:** 6th NHAI Innovation Hackathon 2026
- **Submission deadline:** April 23, 2026
- **Problem addressed:** retroreflectivity measurement of road
  markings and signboards across national highways
- **Innovation:** replaces ₹80L – ₹1.5Cr specialized vehicles with a
  smartphone mounted on any patrol vehicle

See [`docs/research_findings.md`](docs/research_findings.md) for
sources, competitive analysis, and the full feature list.
