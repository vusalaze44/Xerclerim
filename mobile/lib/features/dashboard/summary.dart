import '../transactions/transaction.dart';

class MonthlySummary {
  const MonthlySummary(this.incomeQepik, this.expenseQepik);
  final int incomeQepik;
  final int expenseQepik;
  int get balanceQepik => incomeQepik - expenseQepik;

  factory MonthlySummary.from(List<LedgerEntry> entries, DateTime month) {
    var income = 0;
    var expense = 0;
    for (final entry in entries) {
      if (entry.occurredAt.year != month.year || entry.occurredAt.month != month.month) continue;
      if (entry.kind == EntryKind.income) { income += entry.amountQepik; }
      else { expense += entry.amountQepik; }
    }
    return MonthlySummary(income, expense);
  }
}
