enum EntryKind { income, expense }

class LedgerEntry {
  const LedgerEntry({required this.id, required this.kind, required this.amountQepik,
    required this.category, required this.occurredAt, this.note = ''});
  final String id;
  final EntryKind kind;
  final int amountQepik;
  final String category;
  final DateTime occurredAt;
  final String note;
}
