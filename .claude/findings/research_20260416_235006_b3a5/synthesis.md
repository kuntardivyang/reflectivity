# Research Report: Best Solution for Retroreflectivity Hackathon (NHAI 2026)

## Executive Summary

After researching 13+ sources across mobile platforms, AI computer vision, existing road inspection tools, NHAI's digital strategy, and hackathon winning patterns, the clear conclusion is: **build a two-component system — a Flutter mobile app (data collector) + a React/Next.js web dashboard (analytics & visualization)**. This is not just a theoretical choice; it is the exact architecture used by every successful commercial road inspection startup (RoadMetrics, Roadly, Vialytics). The technical core is using the smartphone camera + LED flash as a calibrated retroreflectometer, with YOLOv8 detecting road markings and a luminance analysis algorithm estimating retroreflectivity in mcd/m²/lux. Data flows to a real-time GIS web dashboard with heatmaps showing the health of the entire highway network.

**The deadline for the 6th NHAI Innovation Hackathon 2026 is April 23** — urgency is critical.

## Key Findings

### Theme 1: Platform Architecture — Mobile + Web is the Market-Validated Winner
- Every successful commercial road inspection startup (RoadMetrics, Roadly, Vialytics) uses the SAME two-component architecture: mobile app for data collection, web GIS dashboard for analysis
- Mobile app handles: camera capture, GPS tagging, LED flash control, YOLOv8 on-device detection, data upload
- Web dashboard handles: GIS heatmaps, retroreflectivity scores by segment, alerts for critical sections, export reports
- PWA is eliminated — iOS cannot do background GPS, and camera control for calibrated flash measurement requires native APIs
- Flutter is best for mobile (single codebase Android+iOS, native camera/GPS/flash APIs, fast compilation)
- React + deck.gl + Mapbox is best for web dashboard (heatmaps at 60fps, stunning visuals for judges)

### Theme 2: The Core Technical Approach is Scientifically Validated
- Smartphone camera + LED flash can measure luminance in cd/m² using OECF calibration (proven in peer-reviewed research)
- YOLOv8 detects road markings in real-time; pixel brightness in detected region = relative retroreflectivity
- The 30-meter geometry standard (entrance angle 88.76°, observation angle 1.05°) can be simulated computationally using known vehicle/camera geometry
- Critical thresholds: >100 mcd/m²/lux = SAFE (green), 54-100 = WARNING (yellow), <54 = CRITICAL (red)
- SAAM-ReflectNet (2024 paper) proves AI can simultaneously detect signs + estimate retroreflectivity — cite this in your presentation
- HDR imaging technique enables daytime measurement with flash — no need for nighttime-only operation

### Theme 3: NHAI Context — You Are Solving Their Exact Problem
- NHAI explicitly lists "high-quality retroreflectivity measurement for road markings and signboards" as a hackathon problem statement
- NHAI already uses expensive Network Survey Vehicles (NSVs) with 3D lasers — your solution's advantage is COST (smartphone vs $80K-200K hardware)
- NHAI launched "Rajmarg Saathi" mobile app for patrol vehicles with AI video analytics — they are MOBILE-FIRST
- NHAI "ONE" app integrates road safety audits — they value unified digital tools
- NHAI-IIT Delhi partnership focuses on AI + data analytics for highways — AI approach aligns with their strategy
- Your solution fills the GAP: NSVs don't measure retroreflectivity specifically; handheld meters are unsafe and slow

### Theme 4: What Wins Hackathons (Especially Infrastructure Ones)
- Judges score: Innovation + Feasibility + Safety Impact + Presentation Quality
- A live real-time demo of the dashboard with data flowing beats slides every time
- Show a SKIT: person driving on highway → phone captures markings → app shows WARNING on segment → dashboard shows the dangerous stretch
- Solutions that address the EXACT problem statement win — retroreflectivity on national highways is the brief
- Practical deployment capability impresses more than complex theory
- Cost advantage is crucial: $80K hardware → free smartphone solution is a jaw-dropper

### Theme 5: AI Model Stack
- YOLOv8n (nano): real-time marking detection on-device via TFLite (Android) or CoreML (iOS)
- Luminance analysis: OpenCV pixel intensity in detected ROI → RL score (mcd/m²/lux equivalent)
- Server-side: FastAPI + Python for calibration, scoring, and aggregation
- Calibration: one-time calibration against known reference panel gives absolute mcd/m²/lux values
- For hackathon: relative scores + pre-calibrated coefficients are sufficient for demo

## Recommendations

### What to Build: "ReflectScan" — Smartphone Retroreflectivity Intelligence System

**Component 1: Flutter Mobile App (Data Collector)**
- Camera feed with YOLOv8n running on-device (TFLite) to detect road markings in real-time
- LED flash controlled at specific frequency as measurement light source
- GPS tagging every frame with coordinate, speed, timestamp
- Luminance measurement from camera pixel values in detected marking regions
- Offline mode: store data locally when no signal, sync on connectivity
- Simple UI: start survey → drive → stop → auto-upload

**Component 2: Web Dashboard (React + Next.js + deck.gl + Mapbox)**
- Real-time GIS map showing highway segments color-coded by retroreflectivity
- Heatmap of problematic zones (red = critical, yellow = warning, green = safe)
- Per-segment detailed view with retroreflectivity values, photos, timestamps
- Alert system for segments below 54 mcd/m²/lux (CRITICAL threshold)
- Export: CSV/PDF reports for highway authority maintenance teams
- Analytics: trend over time, seasonal degradation patterns

**Why This Wins:**
1. Solves NHAI's exact problem statement
2. Reduces cost from $80K hardware to zero (any patrol vehicle smartphone)
3. Scales to entire national highway network without additional hardware
4. Real-time monitoring vs periodic manual inspection
5. Aligns with NHAI's mobile-first digital transformation strategy
6. Backed by peer-reviewed science (OECF calibration, SAAM-ReflectNet, RL thresholds)
7. Live demo is visually compelling for judges (heatmap dashboard + phone capture in action)

## Sources
1. [RoadMetrics AI](https://roadmetrics.ai/) - Mobile + web GIS architecture pattern
2. [Roadly AI](https://roadly.ai/) - SLAM + ML processing mobile-to-web pattern
3. [NHAI Digital Transformation](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2188705) - Rajmarg Saathi + NSV context
4. [NHAI Road Safety Hackathon](https://unstop.com/hackathons/road-safety-hackathon-national-highways-authority-of-india-1317882) - Exact problem statement
5. [6th NHAI Innovation Hackathon 2026](https://www.lawctopus.com/6th-nhai-innovation-hackathon-2026/) - April 23 deadline
6. [Smartphone Luminance Measurement](https://www.researchgate.net/publication/253692332_Low-Cost_Cell_Phone-based_Digital_Lux_Meter) - OECF camera calibration
7. [RL Thresholds for Machine Vision](https://pmc.ncbi.nlm.nih.gov/articles/PMC8963044/) - 100/54 mcd/m²/lux thresholds
8. [SAAM-ReflectNet](https://www.sciencedirect.com/science/article/abs/pii/S0957417425016240) - AI retroreflectivity estimation
9. [IIT Madras AI Hackathon](https://startuppoint.in/iit-madras-launches-ai-road-safety-hackathon/) - What judges look for
10. [HDR Retroreflectivity](https://transweb.sjsu.edu/research/1878-Remote-Measurement-Road-Reflectivity) - Daytime measurement approach
11. [Flutter vs PWA comparison](https://binmile.com/blog/flutter-vs-react-native-vs-pwa/) - Platform selection rationale
12. [Mapbox heatmaps](https://docs.mapbox.com/mapbox-gl-js/example/heatmap-layer/) - 60fps visualization
13. [deck.gl](https://deck.gl/) - Road network path layer visualization