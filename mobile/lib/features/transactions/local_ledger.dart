import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'transaction.dart';

class LocalLedger {
  Database? _db;

  Future<Database> get database async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'xerclerim_v1.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE ledger (
            id TEXT PRIMARY KEY, kind TEXT NOT NULL, amount_qepik INTEGER NOT NULL
            CHECK(amount_qepik > 0), category TEXT NOT NULL, note TEXT NOT NULL,
            occurred_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT 'pending'
          )''');
          await db.execute('CREATE INDEX ledger_date ON ledger(occurred_at)');
        },
      );

  Future<void> add(LedgerEntry entry) async {
    final db = await database;
    await db.insert('ledger', {
      'id': entry.id, 'kind': entry.kind.name,
      'amount_qepik': entry.amountQepik, 'category': entry.category,
      'note': entry.note, 'occurred_at': entry.occurredAt.toUtc().toIso8601String(),
      'sync_state': 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<LedgerEntry>> all() async {
    final rows = await (await database).query('ledger', orderBy: 'occurred_at DESC');
    return rows.map((row) => LedgerEntry(
      id: row['id'] as String,
      kind: EntryKind.values.byName(row['kind'] as String),
      amountQepik: row['amount_qepik'] as int,
      category: row['category'] as String,
      note: row['note'] as String,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
    )).toList();
  }

  Future<void> close() async { await _db?.close(); _db = null; }
}
