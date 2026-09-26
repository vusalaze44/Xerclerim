import 'package:flutter_test/flutter_test.dart';
import 'package:xerclerim/features/expenses/expense_report.dart';
import 'package:xerclerim/features/transactions/transaction.dart';

void main() {
  test('kredit ödənişi xərclərə daxildir, gəlir və başqa ay daxil deyil', () {
    LedgerEntry entry(String id, EntryKind kind, String category, int amount, DateTime at) =>
      LedgerEntry(id: id, kind: kind, amountQepik: amount, category: category, occurredAt: at);
    final report = ExpenseReport([
      entry('a', EntryKind.expense, 'Qida', 2500, DateTime(2026, 9, 1)),
      entry('b', EntryKind.expense, 'Qida', 1250, DateTime(2026, 9, 2)),
      entry('c', EntryKind.expense, 'Kredit ödənişi', 5000, DateTime(2026, 9, 3)),
      entry('d', EntryKind.income, 'Əməkhaqqı', 90000, DateTime(2026, 9, 3)),
      entry('e', EntryKind.expense, 'Qida', 6000, DateTime(2026, 8, 31)),
    ], DateTime(2026, 9));
    expect(report.totalQepik, 8750);
    expect(report.byCategory['Qida'], 3750);
    expect(report.filtered(category: 'Kredit ödənişi').length, 1);
    expect(report.filtered(query: 'qİDa').length, 2);
  });
}
