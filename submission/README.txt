ReflectScan — NHAI 6th Innovation Hackathon 2026
================================================

Team Leader : Divyang Kuntar
Email       : divyangkuntar@gmail.com
Mobile      : 7016509214
Team Size   : 2

-------------------------------------------------
LIVE LINKS
-------------------------------------------------

GitHub Repository (full source code)
  https://github.com/kuntardivyang/reflectivity

Live Dashboard (Next.js + Leaflet, Vercel)
  https://reflectivity-3x1c.vercel.app

Live Backend API (FastAPI + PostGIS, Railway)
  https://reflectivity-production.up.railway.app

API Docs / OpenAPI Spec (Swagger UI)
  https://reflectivity-production.up.railway.app/docs

Google Drive Folder (screenshots, videos, APK)
  https://drive.google.com/drive/folders/1xpssEgShkJ3bRBdnN1gJgEUiT1i-ei5d

-------------------------------------------------
CONTENTS OF THIS ZIP
-------------------------------------------------

Proposal.pdf                          — main submission document
README.txt                            — this file
01_app_daytime_survey_gps_locked.jpeg — app running on real road, GPS locked
02_app_survey_history.jpeg            — survey history screen (NH-48 sessions)
03_app_session_detail_82points.jpeg   — session detail: 82 captured points
04_app_night_zebra_crossing_flash.jpeg— night survey, Flash OK, zebra crossing
05_app_night_road_flash_ok.jpeg       — night survey, Flash OK, road HUD

-------------------------------------------------
CONTENTS OF GOOGLE DRIVE FOLDER
-------------------------------------------------

Proposal.pdf         — main submission document
reflectscan.apk      — installable Android APK (Android 8+)
06_dashboard_demo.webm     — screen recording of live dashboard
07_app_android_clip.mp4    — 20-second Android app demo clip
(+ all 5 screenshots above)

-------------------------------------------------
QUICK START — VERIFY ANY CLAIM
-------------------------------------------------

Open dashboard now  : https://reflectivity-3x1c.vercel.app
Open API docs now   : https://reflectivity-production.up.railway.app/docs
Run backend locally :
    cd backend
    pip install -r requirements.txt
    python -m db.init_db && python -m scripts.seed_nh48
    uvicorn main:app --reload

Run tests           :
    cd backend && pytest          # 27 passing
    cd mobile  && flutter test    # 24 passing

Install APK         :
    adb install reflectscan.apk
    (or sideload from Google Drive on any Android 8+ device)
