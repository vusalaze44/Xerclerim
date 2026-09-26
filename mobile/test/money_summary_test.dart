import 'package:flutter_test/flutter_test.dart';
import 'package:xerclerim/core/money.dart';
import 'package:xerclerim/features/dashboard/summary.dart';
import 'package:xerclerim/features/transactions/transaction.dart';

void main() {
  test('AZN qəpik dəqiqliyini saxlayır', () {
    expect(Money.parseAzN('12,05'), 1205);
    expect(Money.format(-1205), '-12.05 ₼');
    expect(() => Money.parseAzN('1.234'), throwsFormatException);
  });
  test('aylıq cəm yalnız həmin aya aid əməliyyatları sayır', () {
    LedgerEntry entry(String id, EntryKind kind, int amount, DateTime date) =>
      LedgerEntry(id: id, kind: kind, amountQepik: amount, category: 'Digər', occurredAt: date);
    final result = MonthlySummary.from([
      entry('a', EntryKind.income, 10000, DateTime(2026, 9, 1)),
      entry('b', EntryKind.expense, 3450, DateTime(2026, 9, 2)),
      entry('c', EntryKind.expense, 9000, DateTime(2026, 8, 31)),
    ], DateTime(2026, 9, 26));
    expect(result.balanceQepik, 6550);
  });
}
