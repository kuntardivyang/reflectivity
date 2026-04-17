import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/measurement.dart';
import '../models/survey_session.dart';

class LocalDatabase {
  static const _dbName = 'reflectscan.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, _dbName),
      version: _dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT,
        surveyor TEXT,
        highway TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        total_points INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        highway TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        rl_value REAL NOT NULL,
        status TEXT NOT NULL,
        speed_kmh REAL,
        captured_at TEXT NOT NULL,
        uploaded INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_measurements_uploaded ON measurements(uploaded)');
    await db.execute('CREATE INDEX idx_measurements_session ON measurements(session_id)');
  }

  // ─── sessions ───────────────────────────────────────────────────

  Future<void> insertSession(SurveySession s) async {
    final d = await db;
    await d.insert('sessions', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(SurveySession s) async {
    final d = await db;
    await d.update('sessions', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<List<SurveySession>> allSessions() async {
    final d = await db;
    final rows = await d.query('sessions', orderBy: 'started_at DESC');
    return rows.map(SurveySession.fromMap).toList();
  }

  // ─── measurements ───────────────────────────────────────────────

  Future<void> insertMeasurement(Measurement m) async {
    final d = await db;
    await d.insert('measurements', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertMeasurements(List<Measurement> items) async {
    if (items.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    for (final m in items) {
      batch.insert('measurements', m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Measurement>> pendingUploads({int limit = 500}) async {
    final d = await db;
    final rows = await d.query(
      'measurements',
      where: 'uploaded = 0',
      orderBy: 'captured_at ASC',
      limit: limit,
    );
    return rows.map(Measurement.fromMap).toList();
  }

  Future<void> markUploaded(List<String> ids) async {
    if (ids.isEmpty) return;
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await d.rawUpdate(
      'UPDATE measurements SET uploaded = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> countBySession(String sessionId) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM measurements WHERE session_id = ?',
      [sessionId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
