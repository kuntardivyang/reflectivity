export default function KpiPane({ stats, segmentCount }) {
  if (!stats) {
    return (
      <>
        <h2>Network KPIs</h2>
        <div className="empty-state">Loading…</div>
      </>
    );
  }

  const total = stats.total_points ?? 0;
  const cards = [
    {
      kind: 'safe',
      num: stats.safe_count ?? 0,
      lbl: 'SAFE points',
      sub: total > 0 ? `${pct(stats.safe_count, total)}% of total` : '—',
    },
    {
      kind: 'warn',
      num: stats.warning_count ?? 0,
      lbl: 'WARNING points',
      sub: total > 0 ? `${pct(stats.warning_count, total)}% of total` : '—',
    },
    {
      kind: 'crit',
      num: stats.critical_count ?? 0,
      lbl: 'CRITICAL points',
      sub: total > 0 ? `${pct(stats.critical_count, total)}% of total` : '—',
    },
    {
      kind: 'uncal',
      num: stats.uncal_count ?? 0,
      lbl: 'UNCAL points',
      sub: 'calibration pending',
    },
  ];

  return (
    <>
      <h2>Network KPIs</h2>
      {cards.map((c) => (
        <div key={c.kind} className={`kpi-card ${c.kind}`}>
          <div className="num">{c.num.toLocaleString('en-IN')}</div>
          <div className="lbl">{c.lbl}</div>
          <div className="sub">{c.sub}</div>
        </div>
      ))}

      <h2 style={{ marginTop: 24 }}>Coverage</h2>
      <div className="kpi-card">
        <div className="num">{segmentCount.toLocaleString('en-IN')}</div>
        <div className="lbl">Segments mapped</div>
        <div className="sub">100 m aggregation windows</div>
      </div>
      <div className="kpi-card">
        <div className="num">{(stats.total_km_surveyed ?? 0).toLocaleString('en-IN')}</div>
        <div className="lbl">Kilometres surveyed</div>
        <div className="sub">{(stats.total_points ?? 0).toLocaleString('en-IN')} raw captures total</div>
      </div>
      <div className="kpi-card">
        <div className="num">{(stats.active_alerts ?? 0).toLocaleString('en-IN')}</div>
        <div className="lbl">Active alerts</div>
        <div className="sub">unresolved WARNING / CRITICAL segments</div>
      </div>
    </>
  );
}

function pct(part, whole) {
  if (!whole) return 0;
  return Math.round((part / whole) * 100);
}
