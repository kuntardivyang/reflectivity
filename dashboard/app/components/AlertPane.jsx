export default function AlertPane({ alerts }) {
  if (!alerts || alerts.length === 0) {
    return (
      <div className="empty-state">
        No active alerts. The network is either fully SAFE or no captures
        have been ingested yet.
      </div>
    );
  }

  return (
    <div>
      {alerts.map((a) => {
        const statusKey = (a.status ?? 'WARNING').toLowerCase().slice(0, 4);
        return (
          <div key={a.id} className="alert-row">
            <span className={`pill ${statusKey === 'crit' ? 'crit' : 'warn'}`}>
              {a.status ?? 'WARN'}
            </span>
            <div className="body">
              <div>
                <strong>{a.highway ?? 'Unknown highway'}</strong>
                {a.rl_value != null && (
                  <span style={{ color: 'var(--text-dim)' }}>
                    {' · '}{a.rl_value.toFixed(0)} mcd/m²/lx
                  </span>
                )}
              </div>
              <div className="meta">
                {a.triggered_at ? formatDt(a.triggered_at) : 'Just now'}
                {a.segment_id && ` · seg ${shortId(a.segment_id)}`}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function formatDt(iso) {
  try {
    const d = new Date(iso);
    return d.toLocaleString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: 'short',
    });
  } catch {
    return iso;
  }
}

function shortId(id) {
  return String(id).split('-')[0];
}
