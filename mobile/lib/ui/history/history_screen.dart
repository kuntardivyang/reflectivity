import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/measurement/safety_classifier.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/database.dart';
import '../../data/models/survey_session.dart';
import '../survey/survey_controller.dart';

/// Lists past survey sessions stored in the on-device SQLite database.
/// Tapping a session shows its captured measurements.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(surveyControllerProvider.notifier).localDb;

    return Scaffold(
      appBar: AppBar(title: const Text('Survey History')),
      body: FutureBuilder<List<SurveySession>>(
        future: db.allSessions(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data ?? const [];
          if (sessions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No surveys recorded yet.\nStart one from the Survey screen.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _SessionTile(
              session: sessions[i],
              db: db,
            ),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SurveySession session;
  final LocalDatabase db;
  const _SessionTile({required this.session, required this.db});

  @override
  Widget build(BuildContext context) {
    final duration = session.endedAt?.difference(session.startedAt);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: session.endedAt == null
            ? Colors.orange
            : Theme.of(context).colorScheme.primary,
        child: Icon(
          session.endedAt == null ? Icons.pending : Icons.done,
          color: Colors.white,
          size: 18,
        ),
      ),
      title: Text(session.highway ?? 'Untagged highway'),
      subtitle: Text(
        '${formatTimestamp(session.startedAt)}'
        '${duration != null ? ' · ${formatDuration(duration)}' : ' · in progress'}'
        ' · ${session.totalPoints} points',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SessionDetailScreen(session: session, db: db),
          ),
        );
      },
    );
  }
}

class _SessionDetailScreen extends StatelessWidget {
  final SurveySession session;
  final LocalDatabase db;
  const _SessionDetailScreen({required this.session, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(session.highway ?? 'Session')),
      body: FutureBuilder<int>(
        future: db.countBySession(session.id),
        builder: (context, snap) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Session ID', session.id),
                _kv('Vehicle', session.vehicleId ?? '—'),
                _kv('Surveyor', session.surveyor ?? '—'),
                _kv('Started', formatTimestamp(session.startedAt)),
                _kv(
                  'Ended',
                  session.endedAt == null
                      ? 'In progress'
                      : formatTimestamp(session.endedAt!),
                ),
                _kv('Captured points', '${snap.data ?? session.totalPoints}'),
                const SizedBox(height: 24),
                const _LegendRow(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.white70))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _legendDot(SafetyStatus.safe, '> 100 SAFE'),
        const SizedBox(width: 16),
        _legendDot(SafetyStatus.warning, '54–100 WARNING'),
        const SizedBox(width: 16),
        _legendDot(SafetyStatus.critical, '< 54 CRITICAL'),
      ],
    );
  }

  Widget _legendDot(SafetyStatus s, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
