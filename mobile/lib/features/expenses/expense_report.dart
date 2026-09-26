import '../transactions/transaction.dart';

const expenseCategories = <String>[
  'Ev bazarlığı', 'Qida', 'Yanacaq', 'Kommunal', 'Kirayə', 'Təmir',
  'Nəqliyyat', 'Sağlamlıq', 'Təhsil', 'Əyləncə', 'Abunəlik',
  'Kredit ödənişi', 'Digər',
];

class ExpenseReport {
  ExpenseReport(List<LedgerEntry> entries, DateTime month)
      : expenses = entries.where((entry) => entry.kind == EntryKind.expense &&
          entry.occurredAt.year == month.year && entry.occurredAt.month == month.month).toList();

  final List<LedgerEntry> expenses;
  int get totalQepik => expenses.fold(0, (sum, entry) => sum + entry.amountQepik);

  Map<String, int> get byCategory {
    final totals = <String, int>{};
    for (final entry in expenses) {
      totals.update(entry.category, (value) => value + entry.amountQepik,
        ifAbsent: () => entry.amountQepik);
    }
    return Map.fromEntries(totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
  }

  List<LedgerEntry> filtered({String? category, String query = ''}) {
    final term = query.trim().toLowerCase();
    return expenses.where((entry) =>
      (category == null || entry.category == category) &&
      (term.isEmpty || entry.category.toLowerCase().contains(term) ||
        entry.note.toLowerCase().contains(term))).toList();
  }
}
