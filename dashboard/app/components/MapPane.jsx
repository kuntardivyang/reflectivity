'use client';

import { MapContainer, TileLayer, GeoJSON, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { useMemo } from 'react';

// Default centre on Ahmedabad NH-48 corridor — same area as the
// pipeline-validation drive, so the map opens populated with the seed
// data instead of showing empty ocean. Real surveys will recentre the
// map on the bounding box of returned segments.
const DEFAULT_CENTER = [23.05, 72.58];
const DEFAULT_ZOOM = 11;

const STATUS_COLORS = {
  SAFE:     '#22c55e',
  WARNING:  '#fbbf24',
  CRITICAL: '#ef4444',
  UNCAL:    '#94a3b8',
};

export default function MapPane({ segments }) {
  const styleSegment = (feature) => {
    const status = feature.properties?.status ?? 'UNCAL';
    return {
      color: STATUS_COLORS[status] ?? STATUS_COLORS.UNCAL,
      weight: 5,
      opacity: 0.85,
    };
  };

  const onEachSegment = (feature, layer) => {
    const p = feature.properties ?? {};
    layer.bindPopup(`
      <strong>${p.highway ?? 'Unknown'}</strong><br>
      <span style="color:#94a3b8">Status:</span> <strong>${p.status ?? '—'}</strong><br>
      <span style="color:#94a3b8">RL avg:</span> ${p.rl_avg?.toFixed(1) ?? '—'} mcd/m²/lx<br>
      <span style="color:#94a3b8">Range:</span> ${p.rl_min?.toFixed(0) ?? '—'} – ${p.rl_max?.toFixed(0) ?? '—'}<br>
      <span style="color:#94a3b8">Points:</span> ${p.point_count ?? 0}
    `);
  };

  // Recompute geojson key whenever the feature count changes so Leaflet
  // re-mounts the layer with fresh data.
  const key = useMemo(() => `seg-${segments.features?.length ?? 0}`, [segments]);

  return (
    <MapContainer
      center={DEFAULT_CENTER}
      zoom={DEFAULT_ZOOM}
      className="map-container"
      scrollWheelZoom
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {segments.features?.length > 0 && (
        <GeoJSON key={key} data={segments} style={styleSegment} onEachFeature={onEachSegment} />
      )}
    </MapContainer>
  );
}
