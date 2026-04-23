'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import KpiPane from './components/KpiPane';
import AlertPane from './components/AlertPane';

// Leaflet uses window directly so it cannot SSR.
const MapPane = dynamic(() => import('./components/MapPane'), {
  ssr: false,
  loading: () => <div className="map-container" />,
});

const REFRESH_MS = 15000;

export default function Dashboard() {
  const [segments, setSegments] = useState({ type: 'FeatureCollection', features: [] });
  const [alerts, setAlerts] = useState([]);
  const [stats, setStats] = useState(null);
  const [error, setError] = useState(null);
  const [lastFetch, setLastFetch] = useState(null);

  async function loadAll() {
    try {
      const [s, a, st] = await Promise.all([
        fetch('/api/segments').then((r) => r.json()),
        fetch('/api/alerts').then((r) => r.json()),
        fetch('/api/stats').then((r) => r.json()),
      ]);
      setSegments(s);
      setAlerts(a.alerts ?? a ?? []);
      setStats(st);
      setError(null);
      setLastFetch(new Date());
    } catch (e) {
      setError(`Could not reach backend (${e.message}). Is uvicorn running on :8000?`);
    }
  }

  useEffect(() => {
    loadAll();
    const id = setInterval(loadAll, REFRESH_MS);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="shell">
      <header className="header">
        <h1>ReflectScan</h1>
        <span className="tag">NHAI Hackathon 2026 — Prototype</span>
        <div className="right">
          <span><span className="live-dot" />Live</span>
          {lastFetch && (
            <span>Updated {lastFetch.toLocaleTimeString()}</span>
          )}
        </div>
      </header>

      <aside className="kpi-pane">
        {error && <div className="error-banner">{error}</div>}
        <KpiPane stats={stats} segmentCount={segments.features?.length ?? 0} />
      </aside>

      <main className="map-pane">
        <MapPane segments={segments} />
        <Legend />
      </main>

      <aside className="alert-pane">
        <h2>Active alerts</h2>
        <AlertPane alerts={alerts} />
      </aside>
    </div>
  );
}

function Legend() {
  return (
    <div className="legend">
      <div style={{ marginBottom: 6, fontWeight: 600 }}>Segment status</div>
      <div className="legend-row">
        <span className="legend-dot" style={{ background: 'var(--safe)' }} />
        SAFE &nbsp; &gt; 100 mcd/m²/lx
      </div>
      <div className="legend-row">
        <span className="legend-dot" style={{ background: 'var(--warn)' }} />
        WARNING &nbsp; 54 – 100
      </div>
      <div className="legend-row">
        <span className="legend-dot" style={{ background: 'var(--crit)' }} />
        CRITICAL &nbsp; &lt; 54
      </div>
      <div className="legend-row">
        <span className="legend-dot" style={{ background: 'var(--uncal)' }} />
        UNCAL &nbsp; calibration pending
      </div>
    </div>
  );
}
