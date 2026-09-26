import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'transaction.dart';
import '../loans/loan.dart';

class LocalLedger {
  Database? _db;

  Future<Database> get database async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'xerclerim_v1.db'),
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE ledger (
            id TEXT PRIMARY KEY, kind TEXT NOT NULL, amount_qepik INTEGER NOT NULL
            CHECK(amount_qepik > 0), category TEXT NOT NULL, note TEXT NOT NULL,
            occurred_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT 'pending',
            deleted_at TEXT
          )''');
          await db.execute('CREATE INDEX ledger_date ON ledger(occurred_at)');
          await _createLoans(db);
          await _createLoanPayments(db);
          await _createBudgets(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createLoans(db);
          if (oldVersion < 3) await _createLoanPayments(db);
          if (oldVersion < 4) await _createBudgets(db);
          if (oldVersion < 5) await db.execute('ALTER TABLE ledger ADD COLUMN deleted_at TEXT');
        },
      );

  static Future<void> _createLoans(Database db) => db.execute('''CREATE TABLE loans (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, principal_qepik INTEGER NOT NULL,
    annual_rate_bps INTEGER NOT NULL, months INTEGER NOT NULL, first_due_date TEXT NOT NULL
  )''');

  static Future<void> _createLoanPayments(Database db) => db.execute('''CREATE TABLE loan_payments (
    id TEXT PRIMARY KEY, loan_id TEXT NOT NULL, amount_qepik INTEGER NOT NULL
    CHECK(amount_qepik > 0), paid_at TEXT NOT NULL,
    FOREIGN KEY(loan_id) REFERENCES loans(id)
  )''');

  static Future<void> _createBudgets(Database db) => db.execute('''CREATE TABLE budgets (
    month TEXT NOT NULL, category TEXT NOT NULL, limit_qepik INTEGER NOT NULL
    CHECK(limit_qepik > 0), PRIMARY KEY(month, category)
  )''');

  Future<Map<String, int>> budgets(DateTime month) async {
    final rows = await (await database).query('budgets',
      where: 'month = ?', whereArgs: [_monthKey(month)]);
    return {for (final row in rows) row['category'] as String: row['limit_qepik'] as int};
  }

  Future<void> setBudget(DateTime month, String category, int limitQepik) async {
    if (limitQepik <= 0) throw const FormatException('Limit müsbət olmalıdır.');
    await (await database).insert('budgets', {
      'month': _monthKey(month), 'category': category, 'limit_qepik': limitQepik,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeBudget(DateTime month, String category) async {
    await (await database).delete('budgets', where: 'month = ? AND category = ?',
      whereArgs: [_monthKey(month), category]);
  }

  static String _monthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<void> addLoanPayment(LoanPayment payment) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.insert('loan_payments', {
        'id': payment.id, 'loan_id': payment.loanId,
        'amount_qepik': payment.amountQepik,
        'paid_at': payment.paidAt.toUtc().toIso8601String(),
      });
      await tx.insert('ledger', {
        'id': 'loan_${payment.id}', 'kind': EntryKind.expense.name,
        'amount_qepik': payment.amountQepik, 'category': 'Kredit ödənişi',
        'note': 'Kredit ödənişi',
        'occurred_at': payment.paidAt.toUtc().toIso8601String(),
        'sync_state': 'pending',
      });
    });
  }

  Future<List<LoanPayment>> loanPayments(String loanId) async {
    final rows = await (await database).query('loan_payments',
      where: 'loan_id = ?', whereArgs: [loanId], orderBy: 'paid_at DESC');
    return rows.map((row) => LoanPayment(
      id: row['id'] as String, loanId: row['loan_id'] as String,
      amountQepik: row['amount_qepik'] as int,
      paidAt: DateTime.parse(row['paid_at'] as String).toLocal(),
    )).toList();
  }

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

  Future<void> updateExpense(LedgerEntry entry) async {
    if (entry.kind != EntryKind.expense || entry.amountQepik <= 0 ||
        entry.id.startsWith('loan_')) throw const FormatException('Xərc dəyişdirilə bilməz.');
    final count = await (await database).update('ledger', {
      'amount_qepik': entry.amountQepik, 'category': entry.category,
      'note': entry.note, 'occurred_at': entry.occurredAt.toUtc().toIso8601String(),
      'sync_state': 'pending',
    }, where: 'id = ? AND kind = ? AND deleted_at IS NULL AND id NOT GLOB ?',
      whereArgs: [entry.id, EntryKind.expense.name, 'loan_*']);
    if (count != 1) throw const FormatException('Xərc dəyişdirilə bilmədi.');
  }

  Future<void> deleteExpense(String id) async {
    if (id.startsWith('loan_')) throw const FormatException('Kredit ödənişi bu bölmədən silinmir.');
    final count = await (await database).update('ledger', {
      'deleted_at': DateTime.now().toUtc().toIso8601String(), 'sync_state': 'pending',
    }, where: 'id = ? AND kind = ? AND deleted_at IS NULL AND id NOT GLOB ?',
      whereArgs: [id, EntryKind.expense.name, 'loan_*']);
    if (count != 1) throw const FormatException('Xərc silinə bilmədi.');
  }

  Future<List<LedgerEntry>> all() async {
    final rows = await (await database).query('ledger', where: 'deleted_at IS NULL', orderBy: 'occurred_at DESC');
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
