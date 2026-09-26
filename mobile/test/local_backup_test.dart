import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xerclerim/features/transactions/local_ledger.dart';
import 'package:xerclerim/features/transactions/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('hesab üzrə snapshot bərpa olunur və uğursuz bərpa bazanı silmir', () async {
    final dir = await Directory.systemTemp.createTemp('xerclerim_backup_');
    final source = LocalLedger(databasePath: p.join(dir.path, 'source.db'));
    final target = LocalLedger(databasePath: p.join(dir.path, 'target.db'));
    try {
      await source.add(LedgerEntry(id: 'e1', kind: EntryKind.expense,
        amountQepik: 1250, category: 'Qida', occurredAt: DateTime(2026, 9, 26)));
      final snapshot = await source.exportSnapshot();
      await target.importSnapshot(snapshot, replaceExisting: false);
      expect((await target.all()).single.amountQepik, 1250);
      await expectLater(target.importSnapshot(snapshot, replaceExisting: false), throwsStateError);
      final broken = <String, dynamic>{
        'schemaVersion': 1,
        'tables': {...snapshot['tables'] as Map<String, dynamic>, 'goal_movements': [42]},
      };
      await expectLater(target.importSnapshot(broken, replaceExisting: true), throwsFormatException);
      expect((await target.all()).single.id, 'e1');
      expect((await source.all()).single.id, 'e1');
    } finally {
      await source.close();
      await target.close();
      await dir.delete(recursive: true);
    }
  });
}
