import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'transaction.dart';
import '../loans/loan.dart';

class LocalLedger {
  Database? _db;

  Future<Database> get database async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'xerclerim_v1.db'),
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE ledger (
            id TEXT PRIMARY KEY, kind TEXT NOT NULL, amount_qepik INTEGER NOT NULL
            CHECK(amount_qepik > 0), category TEXT NOT NULL, note TEXT NOT NULL,
            occurred_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT 'pending'
          )''');
          await db.execute('CREATE INDEX ledger_date ON ledger(occurred_at)');
          await _createLoans(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createLoans(db);
        },
      );

  static Future<void> _createLoans(Database db) => db.execute('''CREATE TABLE loans (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, principal_qepik INTEGER NOT NULL,
    annual_rate_bps INTEGER NOT NULL, months INTEGER NOT NULL, first_due_date TEXT NOT NULL
  )''');

  Future<void> addLoan(Loan loan) async {
    await (await database).insert('loans', {
      'id': loan.id, 'name': loan.name, 'principal_qepik': loan.principalQepik,
      'annual_rate_bps': loan.annualRateBps, 'months': loan.months,
      'first_due_date': loan.firstDueDate.toIso8601String(),
    });
  }

  Future<List<Loan>> loans() async {
    final rows = await (await database).query('loans', orderBy: 'first_due_date ASC');
    return rows.map((row) => Loan(
      id: row['id'] as String, name: row['name'] as String,
      principalQepik: row['principal_qepik'] as int,
      annualRateBps: row['annual_rate_bps'] as int, months: row['months'] as int,
      firstDueDate: DateTime.parse(row['first_due_date'] as String),
    )).toList();
  }

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
